//
//  NetworkDetailsViewController.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import SnapKit
import UIKit

/// 网络详情视图控制器
class NetworkDetailsViewController: UIViewController {
    // MARK: - UI 组件

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let statusHeaderView = NetworkStatusHeaderView()
    private let metricsTableView = UITableView(frame: .zero, style: .grouped)
    private let historyTableView = UITableView(frame: .zero, style: .grouped)

    // MARK: - 数据

    private var statistics: NetworkStatistics?
    private var metricsData: [(String, String)] = []
    private var historyData: [NetworkEvent] = []

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        updateData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 订阅网络监控更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NSNotification.Name("NetworkMonitorStatusChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkMetricsUpdated),
            name: NSNotification.Name("NetworkMonitorMetricsUpdated"),
            object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 设置

    private func setupUI() {
        title = "网络状态"
        view.backgroundColor = .darkGray

        // 导航栏
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissController)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "刷新",
            style: .plain,
            target: self,
            action: #selector(refreshData)
        )

        // 滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // 状态头部
        contentView.addSubview(statusHeaderView)

        // 指标表格
        contentView.addSubview(metricsTableView)
        metricsTableView.delegate = self
        metricsTableView.dataSource = self
        metricsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "MetricsCell")
        metricsTableView.isScrollEnabled = false

        // 历史表格
        contentView.addSubview(historyTableView)
        historyTableView.delegate = self
        historyTableView.dataSource = self
        historyTableView.register(NetworkEventTableViewCell.self, forCellReuseIdentifier: "EventCell")
        historyTableView.isScrollEnabled = false

        // 添加标题标签
        let metricsLabel = createSectionLabel("网络指标")
        let historyLabel = createSectionLabel("连接历史")

        contentView.addSubview(metricsLabel)
        contentView.addSubview(historyLabel)

        // 设置标签约束
        metricsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(statusHeaderView.snp.bottom).offset(20)
        }

        historyLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(metricsTableView.snp.bottom).offset(20)
        }

        // 更新表格约束
        metricsTableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(metricsLabel.snp.bottom).offset(8)
            make.height.equalTo(280) // 约7行
        }

        historyTableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(historyLabel.snp.bottom).offset(8)
            make.height.equalTo(300) // 约6行
            make.bottom.equalToSuperview().offset(-20)
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

        statusHeaderView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(120)
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

    func configure(with statistics: NetworkStatistics) {
        self.statistics = statistics
        updateData()
    }

    private func updateData() {
        guard let statistics = statistics else { return }

        // 更新状态头部
        statusHeaderView.configure(with: statistics)

        // 更新指标数据
        metricsData = [
            ("连接状态", statistics.connectionStatus.rawValue),
            ("网络类型", statistics.networkType.rawValue),
            ("网络质量", statistics.qualityLevel.description),
            ("带宽等级", statistics.bandwidth.rawValue),
            ("延迟", String(format: "%.0f ms", statistics.latency * 1000)),
            ("丢包率", String(format: "%.2f%%", statistics.packetLoss * 100)),
            ("成功率", String(format: "%.1f%%", statistics.successRate * 100)),
            ("数据用量", statistics.formattedDataUsage),
            ("连接时长", formatDuration(statistics.connectionDuration)),
            ("请求总数", "\\(statistics.requestCount)"),
            ("失败次数", "\\(statistics.failedRequestCount)"),
        ]

        // 更新历史数据（最近10条）
        historyData = Array(statistics.connectionHistory.suffix(10).reversed())

        DispatchQueue.main.async {
            self.metricsTableView.reloadData()
            self.historyTableView.reloadData()
            self.updateTableViewHeights()
        }
    }

    private func updateTableViewHeights() {
        // 动态调整表格高度
        let metricsHeight = CGFloat(metricsData.count) * 44 + 40 // 加上section header/footer
        let historyHeight = CGFloat(min(historyData.count, 6)) * 60 + 40

        metricsTableView.snp.updateConstraints { make in
            make.height.equalTo(metricsHeight)
        }

        historyTableView.snp.updateConstraints { make in
            make.height.equalTo(historyHeight)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    // MARK: - 事件处理

    @objc private func dismissController() {
        dismiss(animated: true)
    }

    @objc private func refreshData() {
        // 触发网络质量检测
        NetworkQualityDetector.shared.triggerDetection()

        // 更新数据
        if let plugin = findNetworkMonitorPlugin() {
            configure(with: plugin.getNetworkStatistics())
        }
    }

    @objc private func networkStatusChanged() {
        refreshData()
    }

    @objc private func networkMetricsUpdated() {
        refreshData()
    }

    private func findNetworkMonitorPlugin() -> NetworkMonitorPlugin? {
        // 这里需要通过某种方式获取到NetworkMonitorPlugin实例
        // 可以通过通知的object参数或者其他方式
        return nil
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension NetworkDetailsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == metricsTableView {
            return metricsData.count
        } else {
            return historyData.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == metricsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MetricsCell", for: indexPath)
            let metric = metricsData[indexPath.row]
            cell.textLabel?.text = metric.0
            cell.detailTextLabel?.text = metric.1
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as! NetworkEventTableViewCell
            cell.configure(with: historyData[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == metricsTableView {
            return 44
        } else {
            return 60
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == metricsTableView {
            return "当前指标"
        } else {
            return "最近事件"
        }
    }
}

// MARK: - 状态头部视图

class NetworkStatusHeaderView: UIView {
    private let statusIconView = UIImageView()
    private let statusLabel = UILabel()
    private let qualityIndicator = UIView()
    private let qualityLabel = UILabel()
    private let summaryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .lightGray

        addSubview(statusIconView)
        addSubview(statusLabel)
        addSubview(qualityIndicator)
        addSubview(qualityLabel)
        addSubview(summaryLabel)

        statusIconView.contentMode = .scaleAspectFit
        statusIconView.tintColor = .blue

        statusLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        statusLabel.textColor = .white

        qualityIndicator.layer.cornerRadius = 8
        qualityIndicator.backgroundColor = .gray

        qualityLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        qualityLabel.textColor = .white
        qualityLabel.textAlignment = .center

        summaryLabel.font = UIFont.systemFont(ofSize: 14)
        summaryLabel.textColor = .lightGray
        summaryLabel.numberOfLines = 0

        setupConstraints()
    }

    private func setupConstraints() {
        statusIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(20)
            make.size.equalTo(32)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(statusIconView.snp.trailing).offset(12)
            make.centerY.equalTo(statusIconView)
            make.trailing.lessThanOrEqualTo(qualityIndicator.snp.leading).offset(-12)
        }

        qualityIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(statusIconView)
            make.width.equalTo(60)
            make.height.equalTo(24)
        }

        qualityLabel.snp.makeConstraints { make in
            make.edges.equalTo(qualityIndicator)
        }

        summaryLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(statusIconView.snp.bottom).offset(16)
            make.bottom.equalToSuperview().offset(-20)
        }
    }

    func configure(with statistics: NetworkStatistics) {
        statusIconView.image = UIImage(systemName: statistics.networkType.icon)
        statusIconView.tintColor = statistics.connectionStatus.color
        statusLabel.text = "\\(statistics.connectionStatus.rawValue) (\\(statistics.networkType.rawValue))"

        qualityIndicator.backgroundColor = UIColor(hexString: statistics.qualityLevel.color)
        qualityLabel.text = statistics.qualityLevel.description

        let latencyText = String(format: "%.0f ms", statistics.latency * 1000)
        let lossText = String(format: "%.1f%%", statistics.packetLoss * 100)
        let successText = String(format: "%.1f%%", statistics.successRate * 100)

        summaryLabel.text = "延迟: \\(latencyText) • 丢包: \\(lossText) • 成功率: \\(successText)\\n数据用量: \\(statistics.formattedDataUsage) • 带宽: \\(statistics.bandwidth.rawValue)"
    }
}

// MARK: - 事件表格单元格

class NetworkEventTableViewCell: UITableViewCell {
    private let eventIconView = UIImageView()
    private let eventLabel = UILabel()
    private let timeLabel = UILabel()

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

        contentView.addSubview(eventIconView)
        contentView.addSubview(eventLabel)
        contentView.addSubview(timeLabel)

        eventIconView.contentMode = .scaleAspectFit
        eventIconView.tintColor = .blue

        eventLabel.font = UIFont.systemFont(ofSize: 14)
        eventLabel.textColor = .white

        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = .lightGray

        eventIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }

        eventLabel.snp.makeConstraints { make in
            make.leading.equalTo(eventIconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(8)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(eventLabel)
            make.top.equalTo(eventLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-8)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
    }

    func configure(with event: NetworkEvent) {
        eventLabel.text = event.description

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        timeLabel.text = formatter.string(from: event.timestamp)

        let iconName: String
        switch event {
        case .connected:
            iconName = "wifi"
            eventIconView.tintColor = .systemGreen
        case .disconnected:
            iconName = "wifi.slash"
            eventIconView.tintColor = .systemRed
        case .playbackStarted:
            iconName = "play.circle"
            eventIconView.tintColor = .blue
        case .playbackPaused:
            iconName = "pause.circle"
            eventIconView.tintColor = .systemOrange
        case .playbackStopped:
            iconName = "stop.circle"
            eventIconView.tintColor = .systemGray
        case .playbackFailed:
            iconName = "exclamationmark.triangle"
            eventIconView.tintColor = .systemRed
        case .qualityChanged:
            iconName = "arrow.up.arrow.down.circle"
            eventIconView.tintColor = .systemPurple
        }

        eventIconView.image = UIImage(systemName: iconName)
    }
}
