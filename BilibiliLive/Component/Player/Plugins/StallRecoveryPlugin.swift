//
//  StallRecoveryPlugin.swift
//  BilibiliLive
//
//  Detects repeated playback stalls (buffer underruns) and asks the view model
//  to recover by capping quality to 1080p and reloading. Fires its callback at
//  most once per player session to avoid reload loops.
//

import AVKit
import UIKit

class StallRecoveryPlugin: NSObject, CommonPlayerPlugin {
    /// Invoked on the main thread when stalls cross the threshold. The view model
    /// decides whether a downgrade is actually possible/wanted.
    var onStallThresholdReached: (() -> Void)?

    private let threshold = 2
    private var stallCount = 0
    private var fired = false
    private var observer: NSObjectProtocol?

    func playerDidChange(player: AVPlayer) {
        // Re-arm against the new player. `fired`/`stallCount` persist for the
        // life of this plugin instance (one per fresh video), so a downgrade
        // reload won't re-trigger another downgrade.
        teardown()
        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            stallCount += 1
            Logger.info("[StallRecovery] playback stall #\(stallCount)")
            guard !fired, stallCount >= threshold else { return }
            fired = true
            onStallThresholdReached?()
        }
    }

    func playerDidCleanUp(player: AVPlayer) { teardown() }
    func playerDidDismiss(playerVC: AVPlayerViewController) { teardown() }
    deinit { teardown() }

    private func teardown() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
