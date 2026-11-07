import UIKit
import WebKit

/// 全屏 WKWebView 壳：没有地址栏、没有 Safari 工具栏，启动画面结束后就是「阿青」本身。
final class ChatViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {

    private var webView: WKWebView!
    private let cover = UIView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let errorCard = UIView()
    private let errorLabel = UILabel()
    private var pendingText: String?
    private var progressObservation: NSKeyValueObservation?
    private var loaded = false

    init(pendingText: String? = nil) {
        self.pendingText = pendingText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = AQColor.background
        buildWebView()
        buildProgress()
        buildCover()
        buildErrorCard()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAll),
                                               name: .aqReload, object: nil)
        load()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        progressObservation?.invalidate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { false }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true   // 聊着别熄屏
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - 搭界面

    private func buildWebView() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.websiteDataStore = .default()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.isOpaque = false
        wv.backgroundColor = AQColor.background
        wv.scrollView.backgroundColor = AQColor.background
        wv.scrollView.bounces = false
        wv.scrollView.showsVerticalScrollIndicator = false
        wv.scrollView.showsHorizontalScrollIndicator = false
        wv.scrollView.minimumZoomScale = 1.0
        wv.scrollView.maximumZoomScale = 1.0
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.delegate = self
        wv.uiDelegate = self
        wv.navigationDelegate = self
        view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView = wv
    }

    private func buildProgress() {
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = AQColor.accent
        progress.trackTintColor = .clear
        progress.isHidden = true
        view.addSubview(progress)
        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            guard let self = self else { return }
            let p = Float(wv.estimatedProgress)
            self.progress.setProgress(p, animated: true)
            self.progress.isHidden = p >= 1
        }
    }

    private func buildCover() {
        cover.translatesAutoresizingMaskIntoConstraints = false
        cover.backgroundColor = AQColor.background
        view.addSubview(cover)

        let logo = UIImageView(image: UIImage(named: "LaunchLogo"))
        logo.contentMode = .scaleAspectFit
        logo.layer.cornerRadius = 22
        logo.clipsToBounds = true
        logo.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(logo)

        spinner.color = AQColor.accent
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        cover.addSubview(spinner)

        let tip = UILabel()
        tip.text = "阿青 · 正在醒过来"
        tip.font = UIFont.systemFont(ofSize: 13)
        tip.textColor = AQColor.dim
        tip.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(tip)

        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: view.topAnchor),
            cover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cover.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            logo.widthAnchor.constraint(equalToConstant: 96),
            logo.heightAnchor.constraint(equalToConstant: 96),
            logo.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: cover.centerYAnchor, constant: -44),

            spinner.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 34),
            spinner.centerXAnchor.constraint(equalTo: cover.centerXAnchor),

            tip.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            tip.centerXAnchor.constraint(equalTo: cover.centerXAnchor)
        ])
    }

    private func buildErrorCard() {
        errorCard.translatesAutoresizingMaskIntoConstraints = false
        errorCard.backgroundColor = AQColor.card
        errorCard.layer.cornerRadius = 18
        errorCard.isHidden = true
        view.addSubview(errorCard)

        let head = UILabel()
        head.text = "没连上阿青"
        head.font = UIFont.boldSystemFont(ofSize: 18)
        head.textColor = AQColor.text
        head.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.font = UIFont.systemFont(ofSize: 13)
        errorLabel.textColor = AQColor.dim
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        let retry = UIButton(type: .system)
        retry.setTitle("再试一次", for: .normal)
        retry.tintColor = AQColor.text
        retry.addTarget(self, action: #selector(reloadAll), for: .touchUpInside)

        let setup = UIButton(type: .system)
        setup.setTitle("改地址 / 令牌", for: .normal)
        setup.tintColor = AQColor.accent
        setup.addTarget(self, action: #selector(openSetup), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [retry, setup])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false

        errorCard.addSubview(head)
        errorCard.addSubview(errorLabel)
        errorCard.addSubview(row)
        NSLayoutConstraint.activate([
            errorCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            errorCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            errorCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            head.topAnchor.constraint(equalTo: errorCard.topAnchor, constant: 22),
            head.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 20),
            head.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -20),

            errorLabel.topAnchor.constraint(equalTo: head.bottomAnchor, constant: 10),
            errorLabel.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -20),

            row.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 18),
            row.leadingAnchor.constraint(equalTo: errorCard.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: errorCard.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(equalTo: errorCard.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - 加载

    private func load() {
        guard let url = Store.chatURL(text: pendingText) else {
            showError("服务器地址填得不对")
            return
        }
        pendingText = nil
        errorCard.isHidden = true
        cover.isHidden = false
        cover.alpha = 1
        spinner.startAnimating()
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.cachePolicy = .reloadRevalidatingCacheData
        webView.load(req)
    }

    @objc private func reloadAll() {
        loaded = false
        load()
    }

    @objc private func openSetup() {
        let vc = ConnectViewController { [weak self] sheet in
            sheet.dismiss(animated: true) { self?.reloadAll() }
        }
        vc.modalPresentationStyle = .formSheet
        present(vc, animated: true)
    }

    /// 快捷指令 aqing://say?text=… 走这里，直接把字塞进她输入框。
    func send(text: String) {
        guard loaded else { pendingText = text; return }
        guard let data = try? JSONSerialization.data(withJSONObject: [text], options: []),
              let arr = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.__aqSend && window.__aqSend.apply(null, \(arr))",
                                   completionHandler: nil)
    }

    private func showError(_ message: String) {
        errorLabel.text = message + "\n\n检查手机网络，或改回公网入口。"
        errorCard.isHidden = false
        hideCover()
    }

    private func hideCover() {
        guard !cover.isHidden else { return }
        UIView.animate(withDuration: 0.3, animations: { self.cover.alpha = 0 }) { _ in
            self.cover.isHidden = true
            self.spinner.stopAnimating()
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        progress.isHidden = true
        errorCard.isHidden = true
        hideCover()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let e = error as NSError
        if e.code == NSURLErrorCancelled { return }
        showError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        if e.code == NSURLErrorCancelled { return }
        showError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        if navigationAction.targetFrame == nil {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }
        // 点外链才交给 Safari；页面自己的静态资源、CDN 一律放行
        if navigationAction.navigationType == .linkActivated,
           let host = url.host,
           let mine = URL(string: Store.baseURL)?.host,
           host != mine,
           let scheme = url.scheme, scheme.hasPrefix("http") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 只对「用户明确勾了信任 + 家里私有地址」放宽自签证书；公网永远走系统校验
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              Store.trustLAN,
              isPrivateHost(challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func isPrivateHost(_ h: String) -> Bool {
        if ["192.168.", "10.", "127.", "169.254."].contains(where: { h.hasPrefix($0) }) { return true }
        if h.hasSuffix(".local") { return true }
        if h.hasPrefix("172.") {
            let parts = h.split(separator: ".").compactMap { Int($0) }
            if parts.count >= 2, parts[1] >= 16, parts[1] <= 31 { return true }
        }
        return false
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    /// iOS 15+ 网页要麦克风/摄像头时必须由壳明确点头，否则 getUserMedia 直接失败。
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: "阿青", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: "阿青", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "不要", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: "阿青", message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "好", style: .default) { _ in
            completionHandler(a.textFields?.first?.text)
        })
        present(a, animated: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
}
