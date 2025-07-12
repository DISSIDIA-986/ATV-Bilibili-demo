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
    private let chartView = StatsChartView()
    private let sessionsTableView = UITableView(frame: .zero, style: .grouped)

    // MARK: - 数据

    private weak var plugin: PlaybackStatisticsPlugin?
    private var sessionStats: PlaybackSessionStats?
    private var recentSessions: [PlaybackSession] = []

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
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

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "导出",
            style: .plain,
            target: self,
            action: #selector(exportStats)
        )

        // 滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // 摘要视图
        contentView.addSubview(summaryView)
        summaryView.backgroundColor = .lightGray
        summaryView.layer.cornerRadius = 8

        // 图表视图
        contentView.addSubview(chartView)
        chartView.backgroundColor = .lightGray
        chartView.layer.cornerRadius = 8

        // 会话表格
        contentView.addSubview(sessionsTableView)
        sessionsTableView.delegate = self
        sessionsTableView.dataSource = self
        sessionsTableView.register(SessionTableViewCell.self, forCellReuseIdentifier: "SessionCell")
        sessionsTableView.backgroundColor = .lightGray
        sessionsTableView.layer.cornerRadius = 8

        // 添加分区标签
        let summaryLabel = createSectionLabel("播放概览")
        let chartLabel = createSectionLabel("质量分布")
        let sessionLabel = createSectionLabel("最近播放")

        contentView.addSubview(summaryLabel)
        contentView.addSubview(chartLabel)
        contentView.addSubview(sessionLabel)

        // 设置标签约束
        summaryLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(16)
        }

        chartLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(summaryView.snp.bottom).offset(20)
        }

        sessionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(chartView.snp.bottom).offset(20)
        }
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
        }

        chartView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(summaryView.snp.bottom).offset(50)
            make.height.equalTo(200)
        }

        sessionsTableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(chartView.snp.bottom).offset(50)
            make.height.equalTo(300)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    private func createSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }

    // MARK: - 数据配置

    func configure(with plugin: PlaybackStatisticsPlugin) {
        self.plugin = plugin
        loadData()
    }

    private func loadData() {
        guard let plugin = plugin else { return }
        sessionStats = plugin.getSessionStats()
        recentSessions = sessionStats?.recentSessions ?? []
        updateViews()
    }

    private func refreshData() {
        loadData()
    }

    private func updateViews() {
        guard let stats = sessionStats else { return }

        summaryView.configure(with: stats)
        chartView.configure(with: stats.qualityDistribution)

        DispatchQueue.main.async {
            self.sessionsTableView.reloadData()
        }
    }

    // MARK: - 事件处理

    @objc private func dismissController() {
        dismiss(animated: true)
    }

    @objc private func exportStats() {
        guard let plugin = plugin else { return }
        let statsText = plugin.exportStats()

        let alert = UIAlertController(title: "统计报告", message: statsText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension PlaybackStatsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentSessions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell", for: indexPath) as! SessionTableViewCell
        cell.configure(with: recentSessions[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "最近播放记录"
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
        successRateLabel.text = "成功率\\n\\(String(format: "%.1f %% ", stats.successRate * 100))"
        bufferingRatioLabel.text = "缓冲率\\n\\(String(format: "%.1f %% ", stats.averageBufferingRatio * 100))"
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

// MARK: - 统计图表视图

class StatsChartView: UIView {
    private var qualityDistribution: [MediaQualityEnum: Double] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(with distribution: [MediaQualityEnum: Double]) {
        qualityDistribution = distribution
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        let barWidth: CGFloat = 60
        let barSpacing: CGFloat = 20
        let maxHeight = rect.height - 60

        var x: CGFloat = 20

        for quality in MediaQualityEnum.allCases {
            let percentage = qualityDistribution[quality] ?? 0
            let barHeight = maxHeight * CGFloat(percentage)

            // 绘制柱状图
            let barRect = CGRect(x: x, y: rect.height - 40 - barHeight, width: barWidth, height: barHeight)

            switch quality {
            case .quality_1080p:
                context.setFillColor(UIColor.blue.cgColor)
            case .quality_2160p:
                context.setFillColor(UIColor.orange.cgColor)
            case .quality_hdr_dolby:
                context.setFillColor(UIColor.red.cgColor)
            }

            context.fill(barRect)

            // 绘制标签
            let label = quality.desp
            let labelSize = label.size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
            let labelRect = CGRect(
                x: x + (barWidth - labelSize.width) / 2,
                y: rect.height - 30,
                width: labelSize.width,
                height: labelSize.height
            )

            label.draw(in: labelRect, withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.white,
            ])

            // 绘制百分比
            let percentText = String(format: "%.1f%%", percentage * 100)
            let percentSize = percentText.size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
            let percentRect = CGRect(
                x: x + (barWidth - percentSize.width) / 2,
                y: rect.height - 40 - barHeight - 20,
                width: percentSize.width,
                height: percentSize.height
            )

            percentText.draw(in: percentRect, withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white,
            ])

            x += barWidth + barSpacing
        }
    }
}

// MARK: - 会话表格单元格

class SessionTableViewCell: UITableViewCell {
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()
    private let qualityLabel = UILabel()
    private let statusIndicator = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(timeLabel)
        contentView.addSubview(durationLabel)
        contentView.addSubview(qualityLabel)
        contentView.addSubview(statusIndicator)

        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = .white

        durationLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = .white

        qualityLabel.font = UIFont.systemFont(ofSize: 12)
        qualityLabel.textColor = .lightGray

        statusIndicator.layer.cornerRadius = 4

        setupConstraints()
    }

    private func setupConstraints() {
        statusIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(8)
        }

        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(statusIndicator.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(8)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        durationLabel.snp.makeConstraints { make in
            make.leading.equalTo(timeLabel)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        qualityLabel.snp.makeConstraints { make in
            make.leading.equalTo(timeLabel)
            make.bottom.equalToSuperview().offset(-8)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
    }

    func configure(with session: PlaybackSession) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        timeLabel.text = formatter.string(from: session.startTime)

        let minutes = Int(session.watchedDuration) / 60
        let seconds = Int(session.watchedDuration) % 60
        durationLabel.text = String(format: "%dm %ds", minutes, seconds)

        qualityLabel.text = "画质: \\(session.averageQuality.desp) • 完成率: \\(String(format: "%.1f %% ", session.completionRate * 100))"

        statusIndicator.backgroundColor = session.successful ? .green : .red
    }
}
