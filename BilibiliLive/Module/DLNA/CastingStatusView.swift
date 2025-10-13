//
//  CastingStatusView.swift
//  BilibiliLive
//
//  Casting status indicator view for Apple TV
//

import SnapKit
import UIKit

/// Casting status indicator view - displays when Apple TV is receiving a cast
class CastingStatusView: UIView {
    // MARK: - UI Components

    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()

    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "airplayvideo")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "正在接收投屏"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .left
        return label
    }()

    private lazy var sourceLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .left
        return label
    }()

    private lazy var indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 6
        return view
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupObservers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(statusLabel)
        containerView.addSubview(sourceLabel)
        containerView.addSubview(indicatorView)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        statusLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(15)
            make.top.equalToSuperview().offset(15)
            make.right.equalTo(indicatorView.snp.left).offset(-10)
        }

        sourceLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(15)
            make.top.equalTo(statusLabel.snp.bottom).offset(5)
            make.right.equalTo(indicatorView.snp.left).offset(-10)
        }

        indicatorView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(12)
        }

        // Start with hidden state
        alpha = 0
        isHidden = true
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCastingStateChanged(_:)),
            name: .init("CastingStateChanged"),
            object: nil
        )
    }

    // MARK: - Public Methods

    func show(source: String) {
        statusLabel.text = "正在接收投屏"
        sourceLabel.text = "来源: \(source)"
        indicatorView.backgroundColor = .systemGreen

        isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1.0
        }

        // Add pulsing animation to indicator
        startPulseAnimation()
    }

    func hide() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { _ in
            self.isHidden = true
            self.stopPulseAnimation()
        }
    }

    func updateStatus(isReceiving: Bool, source: String? = nil) {
        if isReceiving {
            show(source: source ?? "Unknown")
        } else {
            hide()
        }
    }

    // MARK: - Notification Handlers

    @objc private func handleCastingStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        DispatchQueue.main.async {
            if let isReceiving = userInfo["isReceiving"] as? Bool {
                let source = userInfo["source"] as? String ?? "Unknown"
                self.updateStatus(isReceiving: isReceiving, source: source)
            }
        }
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.3
        pulseAnimation.duration = 1.0
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity

        indicatorView.layer.add(pulseAnimation, forKey: "pulse")
    }

    private func stopPulseAnimation() {
        indicatorView.layer.removeAnimation(forKey: "pulse")
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    private static var castingStatusViewKey: UInt8 = 0

    /// Get or create casting status view for this view controller
    var castingStatusView: CastingStatusView {
        if let existingView = objc_getAssociatedObject(self, &UIViewController.castingStatusViewKey) as? CastingStatusView {
            return existingView
        }

        let statusView = CastingStatusView()
        view.addSubview(statusView)

        statusView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.right.equalToSuperview().offset(-40)
            make.width.equalTo(300)
            make.height.equalTo(80)
        }

        objc_setAssociatedObject(self, &UIViewController.castingStatusViewKey, statusView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return statusView
    }

    /// Show casting status indicator
    func showCastingStatus(source: String) {
        castingStatusView.show(source: source)
    }

    /// Hide casting status indicator
    func hideCastingStatus() {
        castingStatusView.hide()
    }
}
