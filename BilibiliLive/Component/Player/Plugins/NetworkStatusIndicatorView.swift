//
//  NetworkStatusIndicatorView.swift
//  BilibiliLive
//
//  Created by Claude on 2025/7/12.
//

import SnapKit
import UIKit

/// 网络状态指示器视图
class NetworkStatusIndicatorView: UIView {
    // MARK: - UI 组件

    private let containerView = UIView()
    private let statusIconView = UIImageView()
    private let qualityLabel = UILabel()
    private let metricsLabel = UILabel()
    private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

    // MARK: - 状态

    private var currentStatus: NetworkConnectionStatus = .unknown
    private var currentQuality: NetworkQualityLevel = .unknown

    // MARK: - 初始化

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        updateAppearance()
    }

    // MARK: - UI 设置

    private func setupUI() {
        // 背景
        addSubview(backgroundView)
        backgroundView.layer.cornerRadius = 8
        backgroundView.clipsToBounds = true

        // 容器
        backgroundView.contentView.addSubview(containerView)

        // 状态图标
        containerView.addSubview(statusIconView)
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.tintColor = .white

        // 质量标签
        containerView.addSubview(qualityLabel)
        qualityLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        qualityLabel.textColor = .white
        qualityLabel.textAlignment = .center
        qualityLabel.text = "未知"

        // 指标标签
        containerView.addSubview(metricsLabel)
        metricsLabel.font = UIFont.systemFont(ofSize: 8)
        metricsLabel.textColor = .lightGray
        metricsLabel.textAlignment = .center
        metricsLabel.numberOfLines = 2
        metricsLabel.text = "-- ms\\n-- %"

        // 添加点击动画
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }

        statusIconView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(16)
        }

        qualityLabel.snp.makeConstraints { make in
            make.top.equalTo(statusIconView.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(containerView)
        }

        metricsLabel.snp.makeConstraints { make in
            make.top.equalTo(qualityLabel.snp.bottom).offset(2)
            make.centerX.bottom.equalToSuperview()
            make.width.lessThanOrEqualTo(containerView)
        }

        // 设置视图大小
        snp.makeConstraints { make in
            make.width.equalTo(60)
            make.height.equalTo(80)
        }
    }

    @objc private func handleTap() {
        // 添加点击反馈动画
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }

    // MARK: - 状态更新

    func updateStatus(connectionStatus: NetworkConnectionStatus, networkType: NetworkType, isMetered: Bool) {
        currentStatus = connectionStatus

        // 更新图标
        let iconName: String
        switch connectionStatus {
        case .connected:
            iconName = networkType.icon
        case .disconnected:
            iconName = "wifi.slash"
        case .connecting:
            iconName = "wifi.exclamationmark"
        case .unknown:
            iconName = "questionmark.circle"
        }

        statusIconView.image = UIImage(systemName: iconName)
        statusIconView.tintColor = connectionStatus.color

        // 更新网络类型显示
        var statusText = connectionStatus.rawValue
        if connectionStatus == .connected {
            statusText = networkType.rawValue
            if isMetered {
                statusText += "*"
            }
        }

        updateAppearance()
    }

    func updateQuality(_ quality: NetworkQualityLevel) {
        currentQuality = quality
        qualityLabel.text = quality.description
        qualityLabel.textColor = UIColor(hexString: quality.color) ?? .white
        updateAppearance()
    }

    func updateMetrics(latency: TimeInterval, packetLoss: Double) {
        let latencyText = String(format: "%.0f ms", latency * 1000)
        let lossText = String(format: "%.1f%%", packetLoss * 100)
        metricsLabel.text = "\\(latencyText)\\n\\(lossText)"
    }

    private func updateAppearance() {
        // 根据连接状态调整透明度
        switch currentStatus {
        case .connected:
            alpha = 0.9
        case .disconnected:
            alpha = 1.0
        case .connecting:
            alpha = 0.7
            // 添加连接中动画
            startConnectingAnimation()
        case .unknown:
            alpha = 0.6
        }

        // 根据质量调整边框
        if currentStatus == .connected && currentQuality != .unknown {
            backgroundView.layer.borderWidth = 1.0
            backgroundView.layer.borderColor = UIColor(hexString: currentQuality.color)?.cgColor
        } else {
            backgroundView.layer.borderWidth = 0
        }
    }

    private func startConnectingAnimation() {
        // 停止之前的动画
        layer.removeAllAnimations()

        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 0.5
        pulseAnimation.toValue = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity

        layer.add(pulseAnimation, forKey: "connecting_pulse")
    }

    func stopAnimations() {
        layer.removeAllAnimations()
    }

    // MARK: - 显示控制

    func show(animated: Bool = true) {
        isHidden = false
        if animated {
            alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.alpha = 0.9
            }
        }
    }

    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0
            }) { _ in
                self.isHidden = true
                self.stopAnimations()
            }
        } else {
            isHidden = true
            stopAnimations()
        }
    }
}

// MARK: - UIColor 扩展

extension UIColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
