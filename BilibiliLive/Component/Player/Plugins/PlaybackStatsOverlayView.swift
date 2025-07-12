//
//  PlaybackStatsOverlayView.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import SnapKit
import UIKit

/// 播放统计覆盖层视图
class PlaybackStatsOverlayView: UIView {
    // MARK: - UI 组件

    private let containerView = UIView()
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

    private let watchedTimeLabel = UILabel()
    private let bufferingTimeLabel = UILabel()
    private let sessionCountLabel = UILabel()
    private let averageLengthLabel = UILabel()

    private let titleLabel = UILabel()
    private let toggleButton = UIButton(type: .system)

    // MARK: - 状态

    private weak var plugin: PlaybackStatisticsPlugin?
    private var isExpanded = false

    // MARK: - 初始化

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        setupGestures()
    }

    // MARK: - UI 设置

    private func setupUI() {
        // 背景
        addSubview(backgroundView)
        backgroundView.layer.cornerRadius = 8
        backgroundView.clipsToBounds = true
        backgroundView.alpha = 0.9

        // 容器
        backgroundView.contentView.addSubview(containerView)

        // 标题
        containerView.addSubview(titleLabel)
        titleLabel.text = "播放统计"
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        // 切换按钮
        containerView.addSubview(toggleButton)
        toggleButton.setTitle("⚙️", for: .normal)
        toggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        toggleButton.tintColor = .white

        // 统计标签
        setupStatLabels()

        // 初始状态为折叠
        updateDisplayMode()
    }

    private func setupStatLabels() {
        let labels = [watchedTimeLabel, bufferingTimeLabel, sessionCountLabel, averageLengthLabel]

        for label in labels {
            containerView.addSubview(label)
            label.font = UIFont.systemFont(ofSize: 10)
            label.textColor = .lightGray
            label.textAlignment = .center
            label.numberOfLines = 2
        }

        watchedTimeLabel.text = "观看时长\\n0:00"
        bufferingTimeLabel.text = "缓冲时长\\n0:00"
        sessionCountLabel.text = "今日播放\\n0"
        averageLengthLabel.text = "平均时长\\n0:00"
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.trailing.equalTo(toggleButton.snp.leading).offset(-4)
        }

        toggleButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.size.equalTo(20)
        }

        // 设置详细统计标签的约束
        setupDetailedConstraints()

        // 设置整体大小
        updateSizeConstraints()
    }

    private func setupDetailedConstraints() {
        watchedTimeLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview()
            make.width.equalToSuperview().dividedBy(4)
        }

        bufferingTimeLabel.snp.makeConstraints { make in
            make.top.equalTo(watchedTimeLabel)
            make.leading.equalTo(watchedTimeLabel.snp.trailing)
            make.width.equalTo(watchedTimeLabel)
        }

        sessionCountLabel.snp.makeConstraints { make in
            make.top.equalTo(watchedTimeLabel)
            make.leading.equalTo(bufferingTimeLabel.snp.trailing)
            make.width.equalTo(watchedTimeLabel)
        }

        averageLengthLabel.snp.makeConstraints { make in
            make.top.equalTo(watchedTimeLabel)
            make.leading.equalTo(sessionCountLabel.snp.trailing)
            make.trailing.equalToSuperview()
            make.width.equalTo(watchedTimeLabel)
        }
    }

    private func updateSizeConstraints() {
        if isExpanded {
            snp.remakeConstraints { make in
                make.width.equalTo(240)
                make.height.equalTo(70)
            }
        } else {
            snp.remakeConstraints { make in
                make.width.equalTo(80)
                make.height.equalTo(30)
            }
        }
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        addGestureRecognizer(tapGesture)

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(showDetailedStats))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)

        toggleButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
    }

    // MARK: - 配置

    func configure(plugin: PlaybackStatisticsPlugin) {
        self.plugin = plugin
    }

    // MARK: - 统计更新

    func updateStats(watchedTime: TimeInterval, bufferingTime: TimeInterval, sessionCount: Int, averageLength: TimeInterval) {
        watchedTimeLabel.text = "观看时长\\n\\(formatTime(watchedTime))"
        bufferingTimeLabel.text = "缓冲时长\\n\\(formatTime(bufferingTime))"
        sessionCountLabel.text = "今日播放\\n\\(sessionCount)"
        averageLengthLabel.text = "平均时长\\n\\(formatTime(averageLength))"

        // 更新颜色指示器
        updateColorIndicators(watchedTime: watchedTime, bufferingTime: bufferingTime)
    }

    private func updateColorIndicators(watchedTime: TimeInterval, bufferingTime: TimeInterval) {
        // 根据缓冲比例调整背景颜色
        let bufferingRatio = watchedTime > 0 ? bufferingTime / watchedTime : 0

        if bufferingRatio > 0.1 {
            backgroundView.contentView.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        } else if bufferingRatio > 0.05 {
            backgroundView.contentView.backgroundColor = UIColor.orange.withAlphaComponent(0.1)
        } else {
            backgroundView.contentView.backgroundColor = UIColor.green.withAlphaComponent(0.1)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - 展开/折叠

    @objc private func toggleExpanded() {
        isExpanded.toggle()
        updateDisplayMode()

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.updateSizeConstraints()
            self.superview?.layoutIfNeeded()
        }
    }

    private func updateDisplayMode() {
        let labels = [watchedTimeLabel, bufferingTimeLabel, sessionCountLabel, averageLengthLabel]

        if isExpanded {
            titleLabel.isHidden = false
            toggleButton.isHidden = false
            labels.forEach { $0.isHidden = false }
        } else {
            titleLabel.isHidden = false
            toggleButton.isHidden = true
            labels.forEach { $0.isHidden = true }

            // 在折叠模式下，标题显示简化信息
            if let plugin = plugin, let session = plugin.currentSession {
                titleLabel.text = "📊 \\(formatTime(session.watchedDuration))"
            } else {
                titleLabel.text = "📊"
            }
        }
    }

    // MARK: - 事件处理

    @objc private func showDetailedStats() {
        guard let plugin = plugin else { return }
        plugin.showDetailedStats()
    }

    @objc private func showSettings() {
        let alert = UIAlertController(title: "统计设置", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "显示详细统计", style: .default) { [weak self] _ in
            self?.showDetailedStats()
        })

        alert.addAction(UIAlertAction(title: "隐藏统计显示", style: .default) { [weak self] _ in
            self?.plugin?.toggleStatsDisplay()
        })

        alert.addAction(UIAlertAction(title: "导出统计数据", style: .default) { [weak self] _ in
            self?.exportStats()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // 在tvOS上调整alert显示
        if let presentingViewController = UIApplication.shared.keyWindow?.rootViewController {
            presentingViewController.present(alert, animated: true)
        }
    }

    private func exportStats() {
        guard let plugin = plugin else { return }
        let statsText = plugin.exportStats()

        // 在tvOS上显示统计信息
        let alert = UIAlertController(title: "播放统计", message: statsText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))

        if let presentingViewController = UIApplication.shared.keyWindow?.rootViewController {
            presentingViewController.present(alert, animated: true)
        }
    }

    // MARK: - 显示控制

    func show(animated: Bool = true) {
        isHidden = false
        if animated {
            alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.alpha = 1.0
            }
        }
    }

    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.alpha = 0
            } completion: { _ in
                self.isHidden = true
            }
        } else {
            isHidden = true
        }
    }
}
