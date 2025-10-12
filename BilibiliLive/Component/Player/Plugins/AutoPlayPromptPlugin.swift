//
//  AutoPlayPromptPlugin.swift
//  BilibiliLive
//
//  Created by AI Assistant
//

import AVKit
import UIKit

/// 自动播放提示插件 - 用于在视频播放结束时提示用户自动播放下一个相似视频
class AutoPlayPromptPlugin: NSObject, CommonPlayerPlugin {
    // MARK: - Properties

    private var countdownTimer: Timer?
    private var countdown: Int = 8 {
        didSet {
            countdownLabel?.text = "\(countdown)秒"
            if countdown <= 0 {
                autoPlayNextVideo()
            }
        }
    }

    private var nextVideoInfo: PlayInfo?
    var onCancel: (() -> Void)?
    var onAutoPlay: ((PlayInfo) -> Void)?

    // UI元素
    private var containerView: UIView?
    private var promptView: UIView?
    private var titleLabel: UILabel?
    private var videoTitleLabel: UILabel?
    private var countdownLabel: UILabel?
    private var playNowButton: UIButton?
    private var cancelButton: UIButton?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - CommonPlayerPlugin Protocol

    func addViewToPlayerOverlay(container: UIView) {
        containerView = container
        setupAutoPlayView(in: container)
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        let autoPlayImage = UIImage(systemName: "play.circle")
        let autoPlayAction = UIAction(
            title: "自动播放下一个",
            image: autoPlayImage,
            state: Settings.autoPlayEnabled ? .on : .off
        ) { [weak self] action in
            action.state = (action.state == .off) ? .on : .off
            Settings.autoPlayEnabled = action.state == .on
            if action.state == .off {
                self?.hideAutoPlayPrompt()
            }
        }

        if let setting = current.compactMap({ $0 as? UIMenu })
            .first(where: { $0.identifier == UIMenu.Identifier(rawValue: "setting") })
        {
            var child = setting.children
            child.append(autoPlayAction)
            if let index = current.firstIndex(of: setting) {
                current[index] = setting.replacingChildren(child)
            }
            return []
        }
        return [autoPlayAction]
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {}
    func playerDidDismiss(playerVC: AVPlayerViewController) {}
    func playerDidChange(player: AVPlayer) {}
    func playerItemDidChange(playerItem: AVPlayerItem) {}
    func playerWillStart(player: AVPlayer) {}
    func playerDidStart(player: AVPlayer) {}
    func playerDidPause(player: AVPlayer) {}
    func playerDidFail(player: AVPlayer) {}

    func playerDidEnd(player: AVPlayer) {
        // 播放结束时不在此处触发，由ViewModel统一管理
    }

    func playerDidCleanUp(player: AVPlayer) {
        countdownTimer?.invalidate()
        hideAutoPlayPrompt()
    }

    // MARK: - UI Setup

    private func setupAutoPlayView(in containerView: UIView) {
        // 创建自动播放提示视图
        let promptView = UIView()
        promptView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        promptView.layer.cornerRadius = 16
        promptView.translatesAutoresizingMaskIntoConstraints = false
        promptView.isHidden = true
        containerView.addSubview(promptView)
        self.promptView = promptView

        // 设置约束 - 居中显示
        NSLayoutConstraint.activate([
            promptView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            promptView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            promptView.widthAnchor.constraint(equalToConstant: 800),
            promptView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        // 标题标签
        let titleLabel = UILabel()
        titleLabel.text = "即将播放下一个视频"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        promptView.addSubview(titleLabel)
        self.titleLabel = titleLabel

        // 视频标题标签
        let videoTitleLabel = UILabel()
        videoTitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        videoTitleLabel.font = UIFont.systemFont(ofSize: 24)
        videoTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        videoTitleLabel.textAlignment = .center
        videoTitleLabel.numberOfLines = 2
        promptView.addSubview(videoTitleLabel)
        self.videoTitleLabel = videoTitleLabel

        // 倒计时标签
        let countdownLabel = UILabel()
        countdownLabel.text = "\(countdown)秒"
        countdownLabel.textColor = .white
        countdownLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .medium)
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.textAlignment = .center
        promptView.addSubview(countdownLabel)
        self.countdownLabel = countdownLabel

        // 按钮容器
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 20
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        promptView.addSubview(buttonStack)

        // 立即播放按钮
        let playNowButton = createFocusableButton(title: "立即播放", isPrimary: true)
        playNowButton.addTarget(self, action: #selector(playNowTapped), for: .primaryActionTriggered)
        self.playNowButton = playNowButton

        // 取消按钮
        let cancelButton = createFocusableButton(title: "取消", isPrimary: false)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .primaryActionTriggered)
        self.cancelButton = cancelButton

        buttonStack.addArrangedSubview(playNowButton)
        buttonStack.addArrangedSubview(cancelButton)

        // 设置约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: promptView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: promptView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: promptView.trailingAnchor, constant: -40),

            videoTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            videoTitleLabel.leadingAnchor.constraint(equalTo: promptView.leadingAnchor, constant: 40),
            videoTitleLabel.trailingAnchor.constraint(equalTo: promptView.trailingAnchor, constant: -40),

            countdownLabel.topAnchor.constraint(equalTo: videoTitleLabel.bottomAnchor, constant: 20),
            countdownLabel.centerXAnchor.constraint(equalTo: promptView.centerXAnchor),

            buttonStack.topAnchor.constraint(equalTo: countdownLabel.bottomAnchor, constant: 30),
            buttonStack.leadingAnchor.constraint(equalTo: promptView.leadingAnchor, constant: 150),
            buttonStack.trailingAnchor.constraint(equalTo: promptView.trailingAnchor, constant: -150),
            buttonStack.bottomAnchor.constraint(equalTo: promptView.bottomAnchor, constant: -30),
            buttonStack.heightAnchor.constraint(equalToConstant: 66),
        ])
    }

    private func createFocusableButton(title: String, isPrimary: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = isPrimary ? UIColor.systemBlue : UIColor.systemGray
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false

        #if os(tvOS)
            // tvOS特有: 添加焦点效果
            button.layer.shadowColor = UIColor.white.cgColor
            button.layer.shadowOpacity = 0
            button.layer.shadowRadius = 8
            button.layer.shadowOffset = CGSize(width: 0, height: 4)

            // 添加焦点时的动画效果
            button.addTarget(self, action: #selector(buttonDidUpdateFocus(_:)), for: .primaryActionTriggered)
        #endif

        return button
    }

    #if os(tvOS)
        @objc private func buttonDidUpdateFocus(_ sender: UIButton) {
            // Focus动画效果已由tvOS系统自动处理
        }
    #endif

    // MARK: - Public Methods

    /// 显示自动播放提示
    func showAutoPlayPrompt(for nextVideo: PlayInfo, title: String? = nil) {
        guard Settings.autoPlayEnabled else { return }

        nextVideoInfo = nextVideo

        // 更新UI
        videoTitleLabel?.text = title ?? "正在加载..."

        // 重置倒计时
        countdown = Settings.autoPlayCountdownDuration

        // 显示视图
        promptView?.isHidden = false

        #if os(tvOS)
            // tvOS: 设置初始焦点到"立即播放"按钮
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self, let playButton = self.playNowButton else { return }
                playButton.setNeedsFocusUpdate()
                UIView.animate(withDuration: 0.2) {
                    playButton.transform = CGAffineTransform.identity
                }
            }
        #endif

        // 开始倒计时
        startCountdown()
    }

    /// 隐藏自动播放提示
    func hideAutoPlayPrompt() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        promptView?.isHidden = true
    }

    // MARK: - Private Methods

    private func startCountdown() {
        countdownTimer?.invalidate()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.countdown -= 1

            if self.countdown <= 0 {
                timer.invalidate()
            }
        }
    }

    @objc private func playNowTapped() {
        countdownTimer?.invalidate()
        autoPlayNextVideo()
    }

    @objc private func cancelTapped() {
        countdownTimer?.invalidate()
        hideAutoPlayPrompt()
        onCancel?()
    }

    private func autoPlayNextVideo() {
        hideAutoPlayPrompt()
        if let nextVideoInfo = nextVideoInfo {
            onAutoPlay?(nextVideoInfo)
        }
    }
}

// MARK: - Settings Extension

extension Settings {
    @UserDefault("Settings.autoPlayEnabled", defaultValue: true)
    static var autoPlayEnabled: Bool

    @UserDefault("Settings.autoPlayCountdownDuration", defaultValue: 8)
    static var autoPlayCountdownDuration: Int
}
