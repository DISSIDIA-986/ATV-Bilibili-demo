//
//  AppDelegate.swift
//  BilibiliLive
//
//  Created by Etan on 2021/3/27.
//

import AVFoundation
import CocoaLumberjackSwift
import Kingfisher
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.setup()
        ImageCache.default.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        AVInfoPanelCollectionViewThumbnailCellHook.start()
        AccountManager.shared.bootstrap()
        BiliBiliUpnpDMR.shared.start()
        URLSession.shared.configuration.headers.add(.userAgent("BiLiBiLi AppleTV Client/1.0.0 (github/yichengchen/ATV-Bilibili-live-demo)"))
        WebRequest.requestIndex()
        return true
    }

    /// 根控制器的选择逻辑。窗口的创建与展示已移交 `SceneDelegate`
    /// （tvOS 27 SDK 起 UIScene 生命周期为强制要求），这里只负责决定装什么。
    func makeRootViewController() -> UIViewController {
        guard ApiRequest.isLogin() else {
            return LoginViewController.create()
        }
        if let expireDate = ApiRequest.getToken()?.expireDate {
            if expireDate.timeIntervalSince(Date()) < 60 * 60 * 30 {
                ApiRequest.refreshToken()
            }
        } else {
            ApiRequest.refreshToken()
        }
        return BLTabBarViewController()
    }

    func showLogin() {
        replaceRootViewController(with: LoginViewController.create(), animated: false)
    }

    func showTabBar() {
        replaceRootViewController(with: BLTabBarViewController(), animated: false)
    }

    func resetTabBar() {
        replaceRootViewController(with: BLTabBarViewController(), animated: true)
    }

    static var shared: AppDelegate {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("AppDelegate not found")
        }
        return delegate
    }

    private func replaceRootViewController(with viewController: UIViewController, animated: Bool) {
        guard let window else { return }
        if animated, let snapshot = window.snapshotView(afterScreenUpdates: false) {
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            viewController.view.addSubview(snapshot)
            UIView.animate(withDuration: 0.25, animations: {
                snapshot.alpha = 0
            }, completion: { _ in
                snapshot.removeFromSuperview()
            })
        } else {
            window.rootViewController = viewController
            window.makeKeyAndVisible()
        }
    }
}

/// tvOS 27 SDK 起 UIKit 强制要求采用 UIScene 生命周期，否则启动即 trap：
/// `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`
/// "UIScene life cycle is required for apps built with this SDK."
///
/// 这里做最小适配：窗口改由 scene 创建，并回填 `AppDelegate.shared.window`，
/// 使既有的 `AppDelegate.shared.window?.rootViewController` 调用点
/// （投屏 DLNA、topMostViewController 等）无需改动。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        AppDelegate.shared.window = window
        window.rootViewController = AppDelegate.shared.makeRootViewController()
        window.makeKeyAndVisible()
    }

    /// scene 生命周期下 `applicationDidBecomeActive` 不再被调用，
    /// 音频会话的配置必须挂在这里，否则播放无声/被其他音频打断。
    func sceneDidBecomeActive(_: UIScene) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }
}
