//
//  NewVideoPlayerViewModel.swift
//  BilibiliLive
//
//  Created by yicheng on 2024/5/23.
//

import AVFoundation
import CocoaLumberjackSwift
import Combine
import UIKit

struct PlayerDetailData {
    let aid: Int
    let cid: Int
    let epid: Int? // 港澳台解锁需要
    let isBangumi: Bool

    var playerStartPos: Int?
    var detail: VideoDetail?
    var clips: [VideoPlayURLInfo.ClipInfo]?
    var playerInfo: PlayerInfo?
    var videoPlayURLInfo: VideoPlayURLInfo
}

class VideoPlayerViewModel {
    var onPluginReady = PassthroughSubject<[CommonPlayerPlugin], String>()
    var onPluginRemove = PassthroughSubject<CommonPlayerPlugin, Never>()
    var onExit: (() -> Void)?
    var nextProvider: VideoNextProvider?

    private var playInfo: PlayInfo
    private let danmuProvider = VideoDanmuProvider(enableDanmuFilter: Settings.enableDanmuFilter,
                                                   enableDanmuRemoveDup: Settings.enableDanmuRemoveDup)
    private var videoDetail: VideoDetail?
    private var cancellable = Set<AnyCancellable>()
    private var playPlugin: CommonPlayerPlugin?
    private var autoPlayPlugin: AutoPlayPromptPlugin?

    init(playInfo: PlayInfo) {
        self.playInfo = playInfo
        setupQualityAdaptationListener()
    }

    private func setupQualityAdaptationListener() {
        NotificationCenter.default.publisher(for: .init("QualityAdaptationRequested"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleQualityAdaptation(notification: notification)
            }
            .store(in: &cancellable)
    }

    private func handleQualityAdaptation(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let targetQuality = userInfo["targetQuality"] as? MediaQualityEnum,
              let currentTime = userInfo["currentTime"] as? CMTime
        else {
            Logger.warn("画质自适应通知缺少必要参数")
            return
        }

        Logger.info("收到画质自适应请求，切换到: \(targetQuality.desp)")

        Task {
            do {
                // 保存当前播放时间
                let savedTime = currentTime

                // 重新加载视频数据
                let data = try await loadVideoInfo()

                // 创建新的播放插件
                let player = BVideoPlayPlugin(detailData: data)

                // 移除旧插件
                if let playPlugin = playPlugin {
                    onPluginRemove.send(playPlugin)
                }

                // 更新当前插件引用
                playPlugin = player

                // 发送新插件（只发送播放器插件进行替换）
                onPluginReady.send([player])

                Logger.info("画质自适应完成")

            } catch {
                Logger.error("画质自适应失败: \(error)")
                onPluginReady.send(completion: .failure("画质切换失败: \(error.localizedDescription)"))
            }
        }
    }

    func load() async {
        do {
            let data = try await loadVideoInfo()
            let plugin = await generatePlayerPlugin(data)
            onPluginReady.send(plugin)
        } catch let err {
            onPluginReady.send(completion: .failure(err.localizedDescription))
        }
    }

    private func loadVideoInfo() async throws -> PlayerDetailData {
        try await initPlayInfo()
        let data = try await fetchVideoData()
        await danmuProvider.initVideo(cid: data.cid, startPos: data.playerStartPos ?? 0)
        return data
    }

    private func initPlayInfo() async throws {
        if !playInfo.isCidVaild {
            playInfo.cid = try await WebRequest.requestCid(aid: playInfo.aid)
        }
        BiliBiliUpnpDMR.shared.sendVideoSwitch(aid: playInfo.aid, cid: playInfo.cid ?? 0)
    }

    private func updateVideoDetailIfNeeded() async {
        if videoDetail == nil {
            videoDetail = try? await WebRequest.requestDetailVideo(aid: playInfo.aid)
        }
    }

    private func fetchVideoData() async throws -> PlayerDetailData {
        assert(playInfo.isCidVaild)
        let aid = playInfo.aid
        let cid = playInfo.cid!
        async let infoReq = try? WebRequest.requestPlayerInfo(aid: aid, cid: cid)
        async let detailUpdate: () = updateVideoDetailIfNeeded()
        do {
            let playData: VideoPlayURLInfo
            var clipInfos: [VideoPlayURLInfo.ClipInfo]?

            if playInfo.isBangumi {
                do {
                    playData = try await WebRequest.requestPcgPlayUrl(aid: aid, cid: cid)
                } catch let err as RequestError {
                    if case let .statusFail(code, _) = err,
                       code == -404 || code == -10403,
                       let data = try await fetchAreaLimitPcgVideoData()
                    {
                        playData = data
                    } else {
                        throw err
                    }
                }

                clipInfos = playData.clip_info_list
            } else {
                playData = try await WebRequest.requestPlayUrl(aid: aid, cid: cid)
            }

            let info = await infoReq
            _ = await detailUpdate

            var detail = PlayerDetailData(aid: playInfo.aid, cid: playInfo.cid!, epid: playInfo.epid, isBangumi: playInfo.isBangumi, detail: videoDetail, clips: clipInfos, playerInfo: info, videoPlayURLInfo: playData)

            if let info, info.last_play_cid == cid, playData.dash.duration - info.playTimeInSecond > 5, Settings.continuePlay {
                detail.playerStartPos = info.playTimeInSecond
            }

            return detail

        } catch let err {
            if case let .statusFail(code, message) = err as? RequestError {
                throw "\(code) \(message)，可能需要大会员"
            } else if await infoReq?.is_upower_exclusive == true {
                throw "该视频为充电专属视频 \(err)"
            } else {
                throw err
            }
        }
    }

    private func playNext(newPlayInfo: PlayInfo) {
        playInfo = newPlayInfo
        if let playPlugin {
            onPluginRemove.send(playPlugin)
        }
        Task {
            do {
                let data = try await loadVideoInfo()
                let player = BVideoPlayPlugin(detailData: data)
                onPluginReady.send([player])
            } catch let err {
                onPluginReady.send(completion: .failure(err.localizedDescription))
            }
        }
    }

    @MainActor private func generatePlayerPlugin(_ data: PlayerDetailData) async -> [CommonPlayerPlugin] {
        let player = BVideoPlayPlugin(detailData: data)
        let danmu = DanmuViewPlugin(provider: danmuProvider)
        let upnp = BUpnpPlugin(duration: data.detail?.View.duration)
        let debug = DebugPlugin()
        let playSpeed = SpeedChangerPlugin()
        playSpeed.$currentPlaySpeed.sink { [weak danmu] speed in
            danmu?.danMuView.playingSpeed = speed.value
        }.store(in: &cancellable)

        let playlist = VideoPlayListPlugin(nextProvider: nextProvider)
        playlist.onPlayEnd = { [weak self] in
            self?.handleVideoEnd()
        }
        playlist.onPlayNextWithInfo = {
            [weak self] info in
            guard let self else { return }
            playNext(newPlayInfo: info)
        }

        // 创建自动播放插件
        let autoPlayPlugin = AutoPlayPromptPlugin()
        autoPlayPlugin.onAutoPlay = { [weak self] playInfo in
            guard let self else { return }
            playNext(newPlayInfo: playInfo)
        }
        autoPlayPlugin.onCancel = { [weak self] in
            // 用户取消自动播放
            self?.onExit?()
        }
        autoPlayPlugin.onFetchNextVideo = { [weak self] () async -> (PlayInfo, String?)? in
            guard let self, let currentVideoDetail = videoDetail else { return nil }
            return await self.fetchNextAutoPlayVideoWithTitle(for: currentVideoDetail)
        }

        playPlugin = player
        self.autoPlayPlugin = autoPlayPlugin

        // 添加画质自适应插件
        let qualityAdapter = QualityAdapterPlugin()

        // 添加网络状态监控插件
        let networkMonitor = NetworkMonitorPlugin()

        // 添加播放统计插件
        let playbackStats = PlaybackStatisticsPlugin()

        var plugins: [CommonPlayerPlugin] = [player, danmu, playSpeed, upnp, debug, playlist, autoPlayPlugin, qualityAdapter, networkMonitor, playbackStats]

        if let clips = data.clips {
            let clip = BVideoClipsPlugin(clipInfos: clips)
            plugins.append(clip)
        }

        if Settings.enableSponsorBlock != .none, let bvid = data.detail?.View.bvid, let duration = data.detail?.View.duration {
            let sponsor = SponsorSkipPlugin(bvid: bvid, duration: duration)
            plugins.append(sponsor)
        }

        if Settings.danmuMask {
            if let mask = data.playerInfo?.dm_mask,
               let video = data.videoPlayURLInfo.dash.video.first,
               mask.fps > 0
            {
                let maskProvider = BMaskProvider(info: mask, videoSize: CGSize(width: video.width ?? 0, height: video.height ?? 0))
                plugins.append(MaskViewPugin(maskView: danmu.danMuView, maskProvider: maskProvider))
            } else if Settings.vnMask {
                let maskProvider = VMaskProvider()
                plugins.append(MaskViewPugin(maskView: danmu.danMuView, maskProvider: maskProvider))
            }
        }

        if let detail = data.detail {
            let info = BVideoInfoPlugin(title: detail.title, subTitle: detail.ownerName, desp: detail.View.desc, pic: detail.pic, viewPoints: data.playerInfo?.view_points)
            plugins.append(info)
        }

        return plugins
    }
}

// 港澳台解锁
extension VideoPlayerViewModel {
    private func fetchAreaLimitPcgVideoData() async throws -> VideoPlayURLInfo? {
        guard Settings.areaLimitUnlock else { return nil }
        guard let epid = playInfo.epid, epid > 0 else { return nil }

        let season = try await WebRequest.requestBangumiSeasonView(epid: epid)
        let checkTitle = season.title.contains("僅") ? season.title : season.series_title
        let checkAreaList = parseAreaByTitle(title: checkTitle)
        guard !checkAreaList.isEmpty else { return nil }

        let playData = try await requestAreaLimitPcgPlayUrl(epid: epid, cid: playInfo.cid!, areaList: checkAreaList)
        return playData
    }

    private func requestAreaLimitPcgPlayUrl(epid: Int, cid: Int, areaList: [String]) async throws -> VideoPlayURLInfo? {
        // 优先使用智能代理选择
        if Settings.proxySmartSelection {
            for area in areaList {
                do {
                    Logger.info("尝试使用智能代理访问地区限制内容 - 地区: \(area)")
                    return try await WebRequest.requestAreaLimitPcgPlayUrlSmart(epid: epid, cid: cid, area: area)
                } catch let err {
                    Logger.warn("智能代理访问失败 - 地区: \(area), 错误: \(err)")

                    // 如果启用了自动故障转移，尝试下一个地区
                    if Settings.proxyAutoFailover && area != areaList.last {
                        continue
                    }

                    // 如果是最后一个地区或未启用故障转移，回退到传统方式
                    if area == areaList.last {
                        Logger.info("所有地区的智能代理都失败，回退到传统代理方式")
                        return try await fallbackToLegacyProxy(epid: epid, cid: cid, areaList: areaList)
                    }
                }
            }
        } else {
            // 使用传统的单一代理服务器方式
            return try await fallbackToLegacyProxy(epid: epid, cid: cid, areaList: areaList)
        }

        return nil
    }

    /// 回退到传统代理方式
    private func fallbackToLegacyProxy(epid: Int, cid: Int, areaList: [String]) async throws -> VideoPlayURLInfo? {
        for area in areaList {
            do {
                return try await WebRequest.requestAreaLimitPcgPlayUrl(epid: epid, cid: cid, area: area)
            } catch let err {
                if area == areaList.last {
                    throw err
                } else {
                    Logger.warn("传统代理访问失败 - 地区: \(area), 错误: \(err)")
                }
            }
        }
        return nil
    }

    private func parseAreaByTitle(title: String) -> [String] {
        if title.isMatch(pattern: "[仅|僅].*[东南亚|其他]") {
            // TODO: 未支持
            return []
        }

        var areas: [String] = []
        if title.isMatch(pattern: "僅.*台") {
            areas.append("tw")
        }
        if title.isMatch(pattern: "僅.*港") {
            areas.append("hk")
        }

        if areas.isEmpty {
            // 标题没有地区限制信息,返回尝试检测的区域
            return ["tw", "hk"]
        } else {
            return areas
        }
    }
}

// MARK: - Auto Play Next Video

extension VideoPlayerViewModel {
    /// 处理视频播放结束
    private func handleVideoEnd() {
        Task {
            if let currentVideoDetail = videoDetail,
               Settings.autoPlayEnabled,
               let nextVideo = await fetchNextAutoPlayVideo(for: currentVideoDetail)
            {
                // 获取视频详情以显示标题
                if let detail = try? await WebRequest.requestDetailVideo(aid: nextVideo.aid) {
                    // 在主线程显示自动播放提示
                    await MainActor.run {
                        autoPlayPlugin?.showAutoPlayPrompt(for: nextVideo, title: detail.View.title)
                    }
                } else {
                    // 如果获取详情失败，使用默认提示
                    await MainActor.run {
                        autoPlayPlugin?.showAutoPlayPrompt(for: nextVideo)
                    }
                }
            } else {
                // 如果没有下一个视频或自动播放已禁用,执行现有逻辑
                DispatchQueue.main.async { [weak self] in
                    self?.nextProvider?.reset()
                    if let nextInfo = self?.nextProvider?.getNext() {
                        self?.playNext(newPlayInfo: nextInfo)
                    } else {
                        self?.onExit?()
                    }
                }
            }
        }
    }

    /// 获取下一个自动播放视频
    private func fetchNextAutoPlayVideo(for currentVideo: VideoDetail) async -> PlayInfo? {
        do {
            // 通过B站API获取相似视频
            let relatedVideos = try await WebRequest.requestRelatedVideo(aid: currentVideo.View.aid)

            // 过滤出有效的视频信息
            for video in relatedVideos {
                if video.aid != currentVideo.View.aid { // 确保不是当前视频
                    return PlayInfo(aid: video.aid, cid: video.cid) // 使用返回的cid
                }
            }
        } catch {
            Logger.warn("获取相似视频失败: \(error)")
        }

        // 如果API获取失败,尝试使用现有nextProvider
        return nextProvider?.getNext()
    }

    /// 获取下一个自动播放视频及其标题(供AutoPlayPromptPlugin使用)
    private func fetchNextAutoPlayVideoWithTitle(for currentVideo: VideoDetail) async -> (PlayInfo, String?)? {
        do {
            // 通过B站API获取相似视频
            let relatedVideos = try await WebRequest.requestRelatedVideo(aid: currentVideo.View.aid)

            // 过滤出有效的视频信息
            for video in relatedVideos {
                if video.aid != currentVideo.View.aid {
                    // 返回PlayInfo和标题
                    return (PlayInfo(aid: video.aid, cid: video.cid), video.title)
                }
            }
        } catch {
            Logger.warn("获取相似视频失败: \(error)")
        }

        // 如果API获取失败,尝试使用现有nextProvider
        if let nextInfo = nextProvider?.getNext() {
            // 尝试获取详情以获得标题
            if let detail = try? await WebRequest.requestDetailVideo(aid: nextInfo.aid) {
                return (nextInfo, detail.View.title)
            }
            return (nextInfo, nil)
        }

        return nil
    }
}

// MARK: - CloudTV Casting Integration

extension VideoPlayerViewModel {
    /// 显示CloudTV设备选择界面
    func showCloudTVDeviceSelection(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let selectionVC = CloudTVSelectionViewController()

        selectionVC.onDeviceSelected = { [weak self] device in
            self?.connectAndCastToCloudTV(device: device, completion: completion)
        }

        selectionVC.onCancel = {
            completion(false)
        }

        selectionVC.modalPresentationStyle = .overFullScreen
        selectionVC.modalTransitionStyle = .crossDissolve

        viewController.present(selectionVC, animated: true)
    }

    /// 连接并投屏到CloudTV设备
    private func connectAndCastToCloudTV(device: BilibiliTVDevice, completion: @escaping (Bool) -> Void) {
        BiliBiliUpnpDMR.shared.connectToCloudTVDevice(device) { [weak self] result in
            switch result {
            case .success:
                Logger.info("Successfully connected to CloudTV device")
                self?.startCastingToCloudTV(completion: completion)

            case let .failure(error):
                Logger.error("Failed to connect to CloudTV: \(error)")
                completion(false)
            }
        }
    }

    /// 开始投屏到CloudTV
    private func startCastingToCloudTV(completion: @escaping (Bool) -> Void) {
        guard let videoDetail = videoDetail else {
            completion(false)
            return
        }

        // Build video URL
        // Note: In production, you would get the actual play URL from VideoPlayURLInfo
        let videoURL = "https://bilibili.com/video/av\(playInfo.aid)"

        // Create metadata
        let metadata = VideoMetadata(
            aid: playInfo.aid,
            cid: playInfo.cid ?? 0,
            title: videoDetail.View.title,
            upName: videoDetail.ownerName,
            coverUrl: videoDetail.pic?.absoluteString,
            duration: videoDetail.View.duration,
            currentPosition: 0,
            danmakuEnabled: Defaults.shared.showDanmu
        )

        // Send play command to CloudTV
        BiliBiliUpnpDMR.shared.playVideoOnCloudTV(
            url: videoURL,
            title: videoDetail.View.title,
            metadata: metadata
        ) { result in
            switch result {
            case .success:
                Logger.info("Successfully started casting to CloudTV")
                completion(true)

            case let .failure(error):
                Logger.error("Failed to cast to CloudTV: \(error)")
                completion(false)
            }
        }
    }

    /// 检查是否已连接CloudTV设备
    func isCloudTVConnected() -> Bool {
        BiliBiliUpnpDMR.shared.isCloudTVConnected()
    }

    /// 断开CloudTV连接
    func disconnectCloudTV() {
        BiliBiliUpnpDMR.shared.disconnectCloudTVDevice()
    }
}
