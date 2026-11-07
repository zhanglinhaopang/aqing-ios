import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.backgroundColor = AQColor.background
        w.rootViewController = makeRoot()
        w.makeKeyAndVisible()
        window = w
        if let url = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async { DeepLink.handle(url, window: w) }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url, let w = window else { return }
        DeepLink.handle(url, window: w)
    }

    static func makeRoot() -> UIViewController {
        if Store.isConfigured { return ChatViewController() }
        return ConnectViewController { vc in
            guard let w = vc.view.window else { return }
            w.rootViewController = ChatViewController()
            UIView.transition(with: w, duration: 0.35,
                              options: .transitionCrossDissolve,
                              animations: nil, completion: nil)
        }
    }
}

/// 快捷指令 / Siri 可以调：
///   aqing://open            打开聊天
///   aqing://say?text=想你了  直接把这句话发给她
///   aqing://setup           改服务器地址或令牌
enum DeepLink {
    static func handle(_ url: URL, window: UIWindow) {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let host = (c.host ?? "").lowercased()
        let text = c.queryItems?.first(where: { $0.name == "text" })?.value
        let query = { (name: String) -> String? in
            c.queryItems?.first(where: { $0.name == name })?.value
        }

        // 装好壳之后点一条 aqing://setup?token=…&server=… 就能配好，不用手敲长令牌
        if let tok = query("token"), !tok.isEmpty {
            if let srv = query("server"), !srv.isEmpty {
                Store.baseURL = Store.normalize(srv)
            }
            Store.token = tok
            if window.rootViewController is ChatViewController {
                NotificationCenter.default.post(name: .aqReload, object: nil)
            } else {
                window.rootViewController = ChatViewController()
            }
            return
        }

        if host == "setup" || url.path == "setup" {
            presentSetup(from: window)
            return
        }
        guard Store.isConfigured else {
            presentSetup(from: window)
            return
        }
        if let t = text, !t.isEmpty {
            if let chat = topChat(in: window) {
                chat.send(text: t)
            } else {
                window.rootViewController = ChatViewController(pendingText: t)
            }
        } else if topChat(in: window) == nil {
            window.rootViewController = ChatViewController()
        }
    }

    private static func topChat(in window: UIWindow) -> ChatViewController? {
        var vc = window.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc as? ChatViewController
    }

    private static func presentSetup(from window: UIWindow) {
        guard let base = window.rootViewController, base.presentedViewController == nil else { return }
        let setup = ConnectViewController { vc in
            vc.dismiss(animated: true) {
                NotificationCenter.default.post(name: .aqReload, object: nil)
            }
        }
        setup.modalPresentationStyle = .formSheet
        base.present(setup, animated: true)
    }
}
