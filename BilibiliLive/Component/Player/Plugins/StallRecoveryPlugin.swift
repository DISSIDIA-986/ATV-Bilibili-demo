//
//  StallRecoveryPlugin.swift
//  BilibiliLive
//
//  Playback-health watchdog. Polls the player once a second and drives recovery
//  for three distinct failure modes seen on-device for an overseas user:
//
//  1. HARD STALL  — timeControlStatus == .waitingToPlayAtSpecifiedRate with
//     reason .toMinimizeStalls held for `stallTriggerSeconds`. The CDN node may
//     be bad, so recovery escapes it (blacklist host + cap 1080p + reload).
//
//  2. SLOW DRAIN  — still .playing but isPlaybackLikelyToKeepUp == false for
//     `drainTriggerSeconds`: throughput can't feed the selected bitrate and the
//     forward buffer is bleeding down (confirmed on Dolby Vision over a ~1.5 Mbps
//     overseas path). The host is fine; the fix is LESS bitrate, applied LIVE and
//     progressively via preferredPeakBitRate (no reload) so AVPlayer rides a
//     lower DASH rep. Only when the live ladder is exhausted do we reload at a
//     capped quality to reach sub-DV reps.
//
//  3. FREEZE      — timeControlStatus == .paused with an empty buffer, but ONLY
//     when a slow drain was active moments earlier. That chain means the pause is
//     the terminal state of a starvation wedge (a tvOS-26 AVPlayer bug: it stops
//     at .paused instead of .waitingToPlayAtSpecifiedRate and ignores play()),
//     NOT a user pause — a user pauses from a HEALTHY buffer, which never
//     satisfies this, so we won't auto-resume content the user paused on purpose.
//
//  Why poll timeControlStatus instead of counting .AVPlayerItemPlaybackStalled:
//  that notification fires only ONCE per stall, so a single long freeze would
//  never reach a count threshold.
//

import AVKit
import UIKit

/// What the view model should do to recover. The plugin decides the trigger; the
/// view model owns how to act (it holds the play/quality plugins and reload).
enum PlaybackRecoveryAction {
    /// Lower the peak bitrate on the CURRENT item, live, no reload. Cheapest fix
    /// for a slow drain — AVPlayer downshifts to a lower rep within the manifest.
    case lowerPeakBitrate(Double)
    /// Reload to escape a possibly-bad CDN host (blacklist current host + cap).
    case reloadEscapeHost
    /// Reload at capped quality + low peak, WITHOUT blacklisting — the host is
    /// fine, the pipe is just too small (or the player wedged and needs a fresh
    /// AVPlayerItem).
    case reloadLowBandwidth
}

class StallRecoveryPlugin: NSObject, CommonPlayerPlugin {
    /// Invoked on the main thread when recovery is warranted. The view model
    /// decides how to satisfy the requested action.
    var onRecover: ((PlaybackRecoveryAction) -> Void)?

    private weak var player: AVPlayer?
    private var timer: Timer?

    // per-player counters (reset each playerDidChange / reload)
    private var hasPlayed = false
    private var stalledSeconds = 0
    private var drainSeconds = 0
    private var frozenSeconds = 0
    private var healthySeconds = 0

    // session counters (persist across reloads so retries stay bounded)
    private var reloadAttempts = 0
    private var peakLadderIndex = 0
    private var elapsedTicks = 0
    private var lastReloadTick = Int.min / 2
    /// Tick of the most recent slow-drain observation, used to prove a later
    /// .paused freeze is an involuntary starvation wedge and not a user pause.
    private var lastDrainTick = Int.min / 2

    private let stallTriggerSeconds = 6
    private let drainTriggerSeconds = 10
    private let freezeTriggerSeconds = 12
    /// A freeze only counts as involuntary if a drain was active THIS recently
    /// (kept tight so a user pause a few seconds after a drain blip is not
    /// mistaken for a starvation wedge).
    private let drainToFreezeGraceSeconds = 3
    /// After a reload, ignore drain for this long so the fresh item's own ABR
    /// ramp-up (isPlaybackLikelyToKeepUp briefly false) isn't counted as a drain.
    private let drainReloadGraceSeconds = 15
    private let maxReloadAttempts = 3
    private let reloadCooldownSeconds = 60
    private let healthyResetSeconds = 60
    /// Progressive live peak-bitrate steps for a slow drain, applied one per drain
    /// window before falling back to a reload. Tuned for a ~1.5 Mbps overseas pipe.
    private let peakLadder: [Double] = [2_500_000, 1_500_000, 1_000_000]

    func playerDidChange(player: AVPlayer) {
        self.player = player
        // Re-arm against the (possibly new) player. Per-player counters reset so a
        // reload's own initial buffering isn't mistaken for a stall/drain/freeze
        // or counted as healthy. Session counters (reloadAttempts, peakLadderIndex,
        // elapsedTicks, lastReloadTick, lastDrainTick) persist across reloads.
        timer?.invalidate()
        hasPlayed = false
        stalledSeconds = 0
        drainSeconds = 0
        frozenSeconds = 0
        healthySeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let player, let item = player.currentItem else { return }
        elapsedTicks += 1
        let tcs = player.timeControlStatus

        // --- playing: track health, refund budget, watch for a slow drain -------
        if tcs == .playing {
            hasPlayed = true
            stalledSeconds = 0
            frozenSeconds = 0
            healthySeconds += 1
            if healthySeconds >= healthyResetSeconds {
                // sustained clean playback: refund the reload budget so a long
                // (>1h) video isn't left unrecoverable after a few early stalls.
                // Keep peakLadderIndex where it settled — don't oscillate quality
                // back up only to drain again.
                if reloadAttempts > 0 {
                    Logger.info("[StallRecovery] \(healthySeconds)s healthy -> refund reload budget (\(reloadAttempts)->0)")
                }
                reloadAttempts = 0
                healthySeconds = 0
            }
            // Skip drain accounting during the post-reload grace so a fresh
            // item's own ABR ramp-up isn't mistaken for a drain.
            if item.isPlaybackLikelyToKeepUp || elapsedTicks - lastReloadTick < drainReloadGraceSeconds {
                drainSeconds = 0
            } else {
                drainSeconds += 1
                lastDrainTick = elapsedTicks
                if drainSeconds >= drainTriggerSeconds {
                    drainSeconds = 0
                    handleSlowDrain()
                }
            }
            return
        }

        healthySeconds = 0
        drainSeconds = 0

        // --- paused: only an involuntary starvation wedge, never a user pause ---
        if tcs == .paused {
            stalledSeconds = 0
            guard hasPlayed,
                  item.isPlaybackBufferEmpty,
                  elapsedTicks - lastDrainTick <= drainToFreezeGraceSeconds
            else {
                frozenSeconds = 0
                return
            }
            frozenSeconds += 1
            guard frozenSeconds >= freezeTriggerSeconds else { return }
            frozenSeconds = 0
            reloadIfAllowed(.reloadLowBandwidth, label: "frozen \(freezeTriggerSeconds)s (involuntary wedge)")
            return
        }

        // --- waiting to minimize stalls: hard stall, host may be bad -----------
        frozenSeconds = 0
        guard hasPlayed,
              tcs == .waitingToPlayAtSpecifiedRate,
              player.reasonForWaitingToPlay == .toMinimizeStalls
        else {
            stalledSeconds = 0
            return
        }
        stalledSeconds += 1
        guard stalledSeconds >= stallTriggerSeconds else { return }
        stalledSeconds = 0
        reloadIfAllowed(.reloadEscapeHost, label: "sustained stall \(stallTriggerSeconds)s")
    }

    /// Slow drain: prefer a live peak-bitrate step (seamless, no reload). Only
    /// after the ladder is exhausted do we escalate to a capped reload.
    private func handleSlowDrain() {
        if peakLadderIndex < peakLadder.count {
            let peak = peakLadder[peakLadderIndex]
            peakLadderIndex += 1
            Logger.info("[StallRecovery] slow drain -> lower peak bitrate to \(peak) (step \(peakLadderIndex)/\(peakLadder.count), live)")
            onRecover?(.lowerPeakBitrate(peak))
            return
        }
        reloadIfAllowed(.reloadLowBandwidth, label: "slow drain (peak floor reached)")
    }

    /// A reload is the expensive path: gate it by the attempt budget and the
    /// wall-clock cooldown so a stream that simply can't stream can't loop.
    private func reloadIfAllowed(_ action: PlaybackRecoveryAction, label: String) {
        guard reloadAttempts < maxReloadAttempts else { return }
        guard elapsedTicks - lastReloadTick >= reloadCooldownSeconds else { return }
        reloadAttempts += 1
        lastReloadTick = elapsedTicks
        Logger.info("[StallRecovery] \(label) -> reload attempt \(reloadAttempts)/\(maxReloadAttempts)")
        onRecover?(action)
    }

    func playerDidCleanUp(player: AVPlayer) { teardown() }
    func playerDidDismiss(playerVC: AVPlayerViewController) { teardown() }
    deinit { teardown() }

    private func teardown() {
        timer?.invalidate()
        timer = nil
    }
}
