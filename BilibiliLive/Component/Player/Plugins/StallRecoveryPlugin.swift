//
//  StallRecoveryPlugin.swift
//  BilibiliLive
//
//  Detects a SUSTAINED playback stall (a buffer underrun that isn't recovering
//  on its own) and asks the view model to recover: cap quality to 1080p and
//  reload, which also re-fetches playurl and lands on a fresh CDN node.
//
//  Why poll timeControlStatus instead of counting .AVPlayerItemPlaybackStalled:
//  that notification fires only ONCE per stall, so a single long freeze (the
//  worst case, observed on-device as a 30s+ stall with throughput collapsing to
//  0) would never reach a "2 stalls" threshold. Polling the wait reason catches
//  both a single long stall and repeated short ones.
//

import AVKit
import UIKit

class StallRecoveryPlugin: NSObject, CommonPlayerPlugin {
    /// Invoked on the main thread when a sustained stall is detected. The view
    /// model decides how to recover (cap to 1080p + reload).
    var onSustainedStall: (() -> Void)?

    private weak var player: AVPlayer?
    private var timer: Timer?
    private var stalledSeconds = 0
    private var hasPlayed = false
    private var attempts = 0

    private let stallTriggerSeconds = 6
    private let maxAttempts = 3

    func playerDidChange(player: AVPlayer) {
        self.player = player
        // Re-arm against the (possibly new) player. stalledSeconds/hasPlayed
        // reset per player so the recovery reload's own initial buffering isn't
        // mistaken for a stall; `attempts` persists across reloads to cap retries.
        timer?.invalidate()
        stalledSeconds = 0
        hasPlayed = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            hasPlayed = true
            stalledSeconds = 0
            return
        }
        // ignore everything before the first frame plays (initial buffering) and
        // explicit pauses (.paused has no waiting reason)
        guard hasPlayed,
              player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
              player.reasonForWaitingToPlay == .toMinimizeStalls
        else {
            stalledSeconds = 0
            return
        }
        stalledSeconds += 1
        guard stalledSeconds >= stallTriggerSeconds, attempts < maxAttempts else { return }
        attempts += 1
        stalledSeconds = 0
        Logger.info("[StallRecovery] sustained stall \(stallTriggerSeconds)s -> recovery attempt \(attempts)/\(maxAttempts)")
        onSustainedStall?()
    }

    func playerDidCleanUp(player: AVPlayer) { teardown() }
    func playerDidDismiss(playerVC: AVPlayerViewController) { teardown() }
    deinit { teardown() }

    private func teardown() {
        timer?.invalidate()
        timer = nil
    }
}
