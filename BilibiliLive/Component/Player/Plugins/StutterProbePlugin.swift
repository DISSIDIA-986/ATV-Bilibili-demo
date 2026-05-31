//
//  StutterProbePlugin.swift
//  BilibiliLive
//
//  Temporary diagnostic probe for locating playback stutter ("卡顿") root cause.
//  Logs AVPlayer access-log metrics (stalls / dropped frames / bitrate / CDN ip)
//  plus a main-thread hitch watchdog every few seconds, tagged "[StutterProbe]".
//  Pull with:  log collect --device --last 30m  (then grep StutterProbe)
//  Remove this file + its registration once the root cause is confirmed.
//

import AVKit
import QuartzCore
import UIKit

class StutterProbePlugin: NSObject, CommonPlayerPlugin {
    private weak var player: AVPlayer?
    private var logTimer: Timer?
    private var displayLink: CADisplayLink?

    // access-log running totals (for per-interval deltas)
    private var lastStalls = 0
    private var lastDropped = 0

    // main-thread hitch accounting (reset each interval)
    private var lastFrameTs: CFTimeInterval = 0
    private var hitchCount = 0
    private var worstFrameMs: Double = 0
    private var frameCount = 0

    // file sink in app Documents container; pulled via `devicectl device copy from`
    private static let logURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("stutter-probe.log")
    }()

    // off-main so the file write never contaminates the main-thread hitch watchdog
    private static let ioQueue = DispatchQueue(label: "stutterprobe.io", qos: .utility)

    private func record(_ line: String) {
        Logger.info("\(line)")
        let stamped = "\(Date()) \(line)\n"
        Self.ioQueue.async {
            guard let data = stamped.data(using: .utf8) else { return }
            let url = Self.logURL
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? stamped.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func playerDidChange(player: AVPlayer) {
        self.player = player
        startWatchdog()
        logTimer?.invalidate()
        logTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.sample()
        }
        record("[StutterProbe] === START danmu=\(Defaults.shared.showDanmu) mask=\(Settings.danmuMask) quality=\(Settings.mediaQuality.qn)/fnval\(Settings.mediaQuality.fnval) preferAvc=\(Settings.preferAvc)")
    }

    func playerDidCleanUp(player: AVPlayer) {
        teardown()
    }

    func playerDidDismiss(playerVC: AVPlayerViewController) {
        teardown()
    }

    deinit { teardown() }

    private func teardown() {
        logTimer?.invalidate(); logTimer = nil
        displayLink?.invalidate(); displayLink = nil
    }

    private func startWatchdog() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastFrameTs = 0
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastFrameTs == 0 { lastFrameTs = link.timestamp; return }
        let deltaMs = (link.timestamp - lastFrameTs) * 1000.0
        lastFrameTs = link.timestamp
        frameCount += 1
        // expected frame budget; CADisplayLink.duration is per-frame target
        let budgetMs = (link.duration > 0 ? link.duration : 1.0 / 60.0) * 1000.0
        if deltaMs > budgetMs * 1.8 { hitchCount += 1 }
        if deltaMs > worstFrameMs { worstFrameMs = deltaMs }
    }

    private func sample() {
        guard let player else { return }
        let tcs = player.timeControlStatus.rawValue // 0=paused 1=waiting(buffering) 2=playing
        let waiting = player.reasonForWaitingToPlay?.rawValue ?? ""

        // main-thread hitch summary for this interval, then reset
        let hitches = hitchCount
        let worst = worstFrameMs
        let frames = frameCount
        hitchCount = 0; worstFrameMs = 0; frameCount = 0

        guard let log = player.currentItem?.accessLog(), let last = log.events.last else {
            record("[StutterProbe] tcs=\(tcs) wait=\(waiting) hitches=\(hitches)/\(frames)f worstFrame=\(String(format: "%.0f", worst))ms (no accessLog yet)")
            return
        }

        // cumulative stalls / dropped across all events (ignore -1 = unknown)
        let totalStalls = log.events.reduce(0) { $0 + max(0, $1.numberOfStalls) }
        let totalDropped = log.events.reduce(0) { $0 + max(0, $1.numberOfDroppedVideoFrames) }
        // clamp: access log can reset on quality reload, making totals shrink
        let dStalls = max(0, totalStalls - lastStalls)
        let dDropped = max(0, totalDropped - lastDropped)
        lastStalls = totalStalls; lastDropped = totalDropped

        let obs = last.observedBitrate / 1_000_000.0
        let ind = last.indicatedBitrate / 1_000_000.0
        // serverAddress is the real connected CDN IP (reliable). uri may be the
        // atv:// custom-scheme placeholder, so log its host:port raw rather than
        // guessing a pcdn flag — judge PCDN later from the actual host/ip.
        let ip = last.serverAddress ?? "?"
        let changes = last.numberOfServerAddressChanges
        let comp = URLComponents(string: last.uri ?? "")
        let uriHost = "\(comp?.host ?? "?"):\(comp?.port.map(String.init) ?? "-")"

        record("[StutterProbe] tcs=\(tcs) wait=\(waiting) | dStalls=\(dStalls) dDrop=\(dDropped) | obs=\(String(format: "%.2f", obs))/ind=\(String(format: "%.2f", ind))Mbps | hitches=\(hitches)/\(frames)f worst=\(String(format: "%.0f", worst))ms | ip=\(ip) ipChg=\(changes) uriHost=\(uriHost)")
    }
}
