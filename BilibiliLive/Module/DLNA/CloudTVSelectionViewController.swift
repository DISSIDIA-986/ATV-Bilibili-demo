//
//  CloudTVSelectionViewController.swift
//  BilibiliLive
//
//  Created by AI Assistant
//

import SnapKit
import UIKit

/// 云视听小电视设备选择视图控制器
class CloudTVSelectionViewController: UIViewController {
    // MARK: - Properties

    private var devices: [BilibiliTVDevice] = []
    private var isDiscovering = false
    var onDeviceSelected: ((BilibiliTVDevice) -> Void)?
    var onCancel: (() -> Void)?

    // UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "选择投屏设备"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "正在搜索云视听小电视设备..."
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        return label
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        #if !os(tvOS)
            table.separatorStyle = .none
        #endif
        table.delegate = self
        table.dataSource = self
        table.register(CloudTVDeviceCell.self, forCellReuseIdentifier: "CloudTVDeviceCell")
        table.remembersLastFocusedIndexPath = true
        return table
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var refreshButton: UIButton = {
        let button = createFocusableButton(title: "刷新")
        button.addTarget(self, action: #selector(refreshTapped), for: .primaryActionTriggered)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = createFocusableButton(title: "取消")
        button.backgroundColor = UIColor.systemGray
        button.addTarget(self, action: #selector(cancelTapped), for: .primaryActionTriggered)
        return button
    }()

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "未找到可用设备\n请确保设备在同一网络"
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startDiscovery()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Set initial focus to table if devices exist, otherwise to refresh button
        if !devices.isEmpty {
            setNeedsFocusUpdate()
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(tableView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(emptyStateLabel)
        containerView.addSubview(refreshButton)
        containerView.addSubview(cancelButton)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(1200)
            make.height.equalTo(800)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.left.right.equalToSuperview().inset(40)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.left.right.equalToSuperview().inset(40)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(40)
            make.height.equalTo(450)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }

        refreshButton.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom).offset(30)
            make.left.equalToSuperview().offset(150)
            make.right.equalTo(containerView.snp.centerX).offset(-10)
            make.height.equalTo(66)
        }

        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom).offset(30)
            make.left.equalTo(containerView.snp.centerX).offset(10)
            make.right.equalToSuperview().offset(-150)
            make.height.equalTo(66)
        }
    }

    private func createFocusableButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)

        #if os(tvOS)
            button.layer.shadowColor = UIColor.white.cgColor
            button.layer.shadowOpacity = 0
            button.layer.shadowRadius = 8
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
        #endif

        return button
    }

    // MARK: - Device Discovery

    private func startDiscovery() {
        guard !isDiscovering else { return }

        isDiscovering = true
        devices.removeAll()
        tableView.reloadData()
        emptyStateLabel.isHidden = true
        activityIndicator.startAnimating()
        subtitleLabel.text = "正在搜索云视听小电视设备..."

        BiliBiliUpnpDMR.shared.discoverCloudTVDevices(timeout: 5.0) { [weak self] discoveredDevices in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isDiscovering = false
                self.activityIndicator.stopAnimating()
                self.devices = discoveredDevices

                if discoveredDevices.isEmpty {
                    self.subtitleLabel.text = "未找到设备"
                    self.emptyStateLabel.isHidden = false
                } else {
                    self.subtitleLabel.text = "找到 \(discoveredDevices.count) 个设备"
                    self.emptyStateLabel.isHidden = true
                }

                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Actions

    @objc private func refreshTapped() {
        startDiscovery()
    }

    @objc private func cancelTapped() {
        onCancel?()
        dismiss(animated: true)
    }

    // MARK: - Focus Engine

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if !devices.isEmpty {
            return [tableView]
        } else {
            return [refreshButton]
        }
    }
}

// MARK: - UITableViewDataSource

extension CloudTVSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CloudTVDeviceCell", for: indexPath) as? CloudTVDeviceCell else {
            return UITableViewCell()
        }

        let device = devices[indexPath.row]
        cell.configure(with: device)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension CloudTVSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        100
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = devices[indexPath.row]
        onDeviceSelected?(device)
        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        true
    }
}

// MARK: - CloudTV Device Cell

class CloudTVDeviceCell: UITableViewCell {
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        return view
    }()

    private lazy var deviceIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "tv")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var deviceNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        return label
    }()

    private lazy var deviceInfoLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.font = UIFont.systemFont(ofSize: 20)
        return label
    }()

    private lazy var statusIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 6
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        #if !os(tvOS)
            selectionStyle = .none
        #endif

        contentView.addSubview(containerView)
        containerView.addSubview(deviceIconView)
        containerView.addSubview(deviceNameLabel)
        containerView.addSubview(deviceInfoLabel)
        containerView.addSubview(statusIndicator)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0))
        }

        deviceIconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }

        deviceNameLabel.snp.makeConstraints { make in
            make.left.equalTo(deviceIconView.snp.right).offset(20)
            make.top.equalToSuperview().offset(20)
            make.right.equalTo(statusIndicator.snp.left).offset(-10)
        }

        deviceInfoLabel.snp.makeConstraints { make in
            make.left.equalTo(deviceIconView.snp.right).offset(20)
            make.top.equalTo(deviceNameLabel.snp.bottom).offset(5)
            make.right.equalTo(statusIndicator.snp.left).offset(-10)
        }

        statusIndicator.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
        }
    }

    func configure(with device: BilibiliTVDevice) {
        deviceNameLabel.text = device.deviceName
        deviceInfoLabel.text = "\(device.deviceModel) • \(device.ipAddress)"

        // Update status indicator color
        switch device.status {
        case .available:
            statusIndicator.backgroundColor = .systemGreen
        case .connected, .playing:
            statusIndicator.backgroundColor = .systemBlue
        case .paused:
            statusIndicator.backgroundColor = .systemYellow
        case .error:
            statusIndicator.backgroundColor = .systemRed
        default:
            statusIndicator.backgroundColor = .systemGray
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations {
            if self.isFocused {
                self.containerView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                self.containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                self.transform = .identity
            }
        }
    }
}
