//
//  PlaybackStatsViewController.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import SnapKit
import UIKit

/// 播放统计详情视图控制器
class PlaybackStatsViewController: UIViewController {
    // MARK: - UI 组件

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let summaryView = StatsSummaryView()

    // MARK: - 数据

    private weak var plugin: PlaybackStatisticsPlugin?
    private var sessionStats: PlaybackSessionStats?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadData()
    }

    // MARK: - UI 设置

    private func setupUI() {
        title = "播放统计"
        view.backgroundColor = .darkGray

        // 导航栏
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissController)
        )

        // 滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // 摘要视图
        contentView.addSubview(summaryView)
        summaryView.backgroundColor = .lightGray
        summaryView.layer.cornerRadius = 8
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        summaryView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(50)
            make.height.equalTo(120)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    // MARK: - 数据配置

    func configure(with plugin: PlaybackStatisticsPlugin) {
        self.plugin = plugin
        loadData()
    }

    private func loadData() {
        guard let plugin = plugin else { return }
        sessionStats = plugin.getSessionStats()
        updateViews()
    }

    private func updateViews() {
        guard let stats = sessionStats else { return }
        summaryView.configure(with: stats)
    }

    // MARK: - 事件处理

    @objc private func dismissController() {
        dismiss(animated: true)
    }
}

// MARK: - 统计摘要视图

class StatsSummaryView: UIView {
    private let totalTimeLabel = UILabel()
    private let sessionsLabel = UILabel()
    private let successRateLabel = UILabel()
    private let bufferingRatioLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        let labels = [totalTimeLabel, sessionsLabel, successRateLabel, bufferingRatioLabel]

        for label in labels {
            addSubview(label)
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 2
        }

        totalTimeLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(16)
            make.width.equalToSuperview().dividedBy(4).offset(-12)
        }

        sessionsLabel.snp.makeConstraints { make in
            make.leading.equalTo(totalTimeLabel.snp.trailing).offset(12)
            make.top.bottom.equalTo(totalTimeLabel)
            make.width.equalTo(totalTimeLabel)
        }

        successRateLabel.snp.makeConstraints { make in
            make.leading.equalTo(sessionsLabel.snp.trailing).offset(12)
            make.top.bottom.equalTo(totalTimeLabel)
            make.width.equalTo(totalTimeLabel)
        }

        bufferingRatioLabel.snp.makeConstraints { make in
            make.leading.equalTo(successRateLabel.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalTo(totalTimeLabel)
            make.width.equalTo(totalTimeLabel)
        }
    }

    func configure(with stats: PlaybackSessionStats) {
        totalTimeLabel.text = "总播放时长\\n\\(formatDuration(stats.totalPlayTime))"
        sessionsLabel.text = "播放次数\\n\\(stats.totalSessions)"
        let successRate = String(format: "%.1f", stats.successRate * 100) + "%"
        successRateLabel.text = "成功率\\n\\(successRate)"
        let bufferingRate = String(format: "%.1f", stats.averageBufferingRatio * 100) + "%"
        bufferingRatioLabel.text = "缓冲率\\n\\(bufferingRate)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}
