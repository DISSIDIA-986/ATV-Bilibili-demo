import Foundation
import UIKit

private extension ApiRequest.FeedResp.Items {
    func toFeaturedFeedFlowItem(durationLimit: FeaturedDurationLimit) -> FeedFlowItem? {
        guard goto == "av", can_play == 1 else { return nil }

        let aidValue = Int(param) ?? player_args?.aid ?? 0
        let cidValue = player_args?.cid ?? 0
        let durationValue = player_args?.duration ?? 0
        guard aidValue > 0, cidValue > 0, durationValue > 0 else { return nil }
        if let maxDuration = durationLimit.maxDuration, durationValue > maxDuration {
            return nil
        }

        return FeedFlowItem(aid: aidValue,
                            cid: cidValue,
                            title: title,
                            ownerName: ownerName,
                            coverURL: pic,
                            avatarURL: avatar,
                            duration: durationValue,
                            durationText: cover_right_text ?? TimeInterval(durationValue).timeString(),
                            viewCountText: cover_left_text_1 ?? "",
                            danmakuCountText: cover_left_text_2 ?? "",
                            reasonText: top_rcmd_reason ?? bottom_rcmd_reason)
    }
}

final class FeaturedBrowserViewController: FeedFlowBrowserViewController {
    init() {
        super.init(dataSource: FeaturedFeedFlowDataSource())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FeaturedFeedFlowDataSource: FeedFlowDataSource {
    let title = "推荐"
    let defaultPreviewHintText = "停留后自动预览，按确认键进入短视频流"
    let loadingHintText = "正在加载沉浸式推荐..."
    let emptyStateText = "当前可播放的短视频较少，请稍后重试"
    let emptyHintText = "可以在设置里调整沉浸式视频时长上限"
    let loadFailureText = "推荐加载失败，请稍后重试"

    var reloadToken: String { Settings.featuredDurationLimit.title }

    private var durationLimit = Settings.featuredDurationLimit
    private var lastSourceIdx: Int?
    private var seenItemKeys = Set<String>()

    func reset() {
        durationLimit = Settings.featuredDurationLimit
        lastSourceIdx = nil
        seenItemKeys = []
    }

    func refreshFromStart(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        let requestDurationLimit = durationLimit
        var loadedItems = [FeedFlowItem]()
        var nextSourceIdx: Int?
        var pagesScanned = 0
        var seenKeys = Set<String>()

        while loadedItems.count < targetCount, pagesScanned < maxSourcePages {
            try Task.checkCancellation()
            let requestedSourceIdx = nextSourceIdx
            let sourceItems: [ApiRequest.FeedResp.Items]
            if let nextSourceIdx {
                sourceItems = try await ApiRequest.getFeeds(lastIdx: nextSourceIdx)
            } else {
                sourceItems = try await ApiRequest.getFeeds()
            }
            try Task.checkCancellation()
            pagesScanned += 1
            nextSourceIdx = sourceItems.last?.idx
            loadedItems.append(contentsOf: sourceItems
                .compactMap { $0.toFeaturedFeedFlowItem(durationLimit: requestDurationLimit) }
                .filter { seenKeys.insert($0.identityKey).inserted })
            if sourceItems.isEmpty || nextSourceIdx == requestedSourceIdx {
                break
            }
        }

        try Task.checkCancellation()
        lastSourceIdx = nextSourceIdx
        seenItemKeys = seenKeys
        return loadedItems
    }

    func loadMoreItems(targetCount: Int, maxSourcePages: Int) async throws -> [FeedFlowItem] {
        let requestDurationLimit = durationLimit
        var accepted = [FeedFlowItem]()
        var pagesScanned = 0
        var nextSourceIdx = lastSourceIdx
        var seenKeys = seenItemKeys

        while accepted.count < targetCount, pagesScanned < maxSourcePages {
            try Task.checkCancellation()
            let requestedSourceIdx = nextSourceIdx
            let sourceItems = try await ApiRequest.getFeeds(lastIdx: nextSourceIdx ?? 0)
            try Task.checkCancellation()
            pagesScanned += 1
            nextSourceIdx = sourceItems.last?.idx
            accepted.append(contentsOf: sourceItems
                .compactMap { $0.toFeaturedFeedFlowItem(durationLimit: requestDurationLimit) }
                .filter { seenKeys.insert($0.identityKey).inserted })
            if sourceItems.isEmpty || nextSourceIdx == requestedSourceIdx {
                break
            }
        }

        try Task.checkCancellation()
        lastSourceIdx = nextSourceIdx
        seenItemKeys = seenKeys
        return accepted
    }
}
