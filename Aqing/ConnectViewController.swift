import UIKit

/// 首次启动 / 改配置时的原生页面。壳里不塞任何网址和令牌，全靠用户填一次，之后进钥匙串。
final class ConnectViewController: UIViewController, UITextFieldDelegate {

    private let onDone: (ConnectViewController) -> Void
    private let gradient = CAGradientLayer()
    private let logoView = UIImageView()
    private let serverField = UITextField()
    private let tokenField = UITextField()
    private let trustSwitch = UISwitch()
    private let goButton = UIButton(type: .system)
    private let hintLabel = UILabel()

    init(onDone: @escaping (ConnectViewController) -> Void) {
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = AQColor.background
        gradient.colors = [
            UIColor(red: 0.169, green: 0.129, blue: 0.216, alpha: 1).cgColor,
            AQColor.background.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(gradient, at: 0)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .onDrag
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        logoView.image = UIImage(named: "LaunchLogo")
        logoView.contentMode = .scaleAspectFit
        logoView.layer.cornerRadius = 22
        logoView.clipsToBounds = true
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.heightAnchor.constraint(equalToConstant: 96).isActive = true
        logoView.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let title = makeLabel("阿青", size: 30, bold: true, color: AQColor.text)
        title.textAlignment = .center
        let sub = makeLabel("在呢，说吧", size: 14, bold: false, color: AQColor.dim)
        sub.textAlignment = .center

        let serverLabel = makeLabel("服务器地址", size: 13, bold: true, color: AQColor.dim)
        let tokenLabel = makeLabel("访问令牌", size: 13, bold: true, color: AQColor.dim)
        style(serverField, placeholder: "https://…/out/app/")
        serverField.text = Store.baseURL
        serverField.keyboardType = .URL
        serverField.autocapitalizationType = .none
        serverField.autocorrectionType = .no
        serverField.returnKeyType = .next
        serverField.delegate = self
        style(tokenField, placeholder: "aq-…")
        tokenField.text = Store.token
        tokenField.isSecureTextEntry = true
        tokenField.autocapitalizationType = .none
        tokenField.autocorrectionType = .no
        tokenField.returnKeyType = .go
        tokenField.delegate = self

        let pasteButton = UIButton(type: .system)
        pasteButton.setTitle("从剪贴板粘贴令牌", for: .normal)
        pasteButton.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        pasteButton.tintColor = AQColor.accent
        pasteButton.contentHorizontalAlignment = .left
        pasteButton.addTarget(self, action: #selector(pasteToken), for: .touchUpInside)

        let trustRow = UIStackView(arrangedSubviews: [trustSwitch, {
            let l = makeLabel("信任家里局域网的自签证书", size: 14, bold: false, color: AQColor.text)
            l.numberOfLines = 0
            return l
        }()])
        trustRow.axis = .horizontal
        trustRow.spacing = 12
        trustRow.alignment = .center
        trustSwitch.onTintColor = AQColor.accent2
        trustSwitch.isOn = Store.trustLAN

        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setTitle("连上阿青", for: .normal)
        goButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        goButton.setTitleColor(UIColor(red: 0.165, green: 0.106, blue: 0.157, alpha: 1), for: .normal)
        goButton.backgroundColor = AQColor.accent
        goButton.layer.cornerRadius = 15
        goButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        goButton.addTarget(self, action: #selector(connect), for: .touchUpInside)

        hintLabel.text = "默认已经填好公网入口 https://aqing.duckdns.org:18085/out/app/，\n"
            + "在家想走局域网也可以换成 https://192.168.9.10:8444/out/app/。\n"
            + "令牌和 NAS 上的 OUT_TOKEN 一致，只存在这台手机的钥匙串里。"
        hintLabel.font = UIFont.systemFont(ofSize: 12)
        hintLabel.textColor = AQColor.dim
        hintLabel.numberOfLines = 0

        // stack 是 fill，图标用一个居中容器包着才不会跟着拉伸
        let logoHolder = UIView()
        logoHolder.translatesAutoresizingMaskIntoConstraints = false
        logoHolder.heightAnchor.constraint(equalToConstant: 96).isActive = true
        logoHolder.addSubview(logoView)
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: logoHolder.centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: logoHolder.centerYAnchor)
        ])

        let stack = UIStackView(arrangedSubviews: [
            logoHolder, title, sub, spacer(30),
            serverLabel, serverField, spacer(8),
            tokenLabel, tokenField, pasteButton, spacer(14),
            trustRow, spacer(20), goButton, spacer(14), hintLabel
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 76),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -36),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -56)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(endEdit))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = view.bounds
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    @objc private func pasteToken() {
        tokenField.text = UIPasteboard.general.string ?? tokenField.text
    }

    @objc private func endEdit() { view.endEditing(true) }

    @objc private func connect() {
        let rawServer = serverField.text ?? ""
        let tok = (tokenField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tok.isEmpty else {
            tokenField.becomeFirstResponder()
            flash("令牌不能空着")
            return
        }
        Store.baseURL = Store.normalize(rawServer)
        Store.token = tok
        Store.trustLAN = trustSwitch.isOn
        view.endEditing(true)
        onDone(self)
    }

    private func flash(_ text: String) {
        let oldText = hintLabel.text
        let oldColor = hintLabel.textColor
        hintLabel.text = text
        hintLabel.textColor = AQColor.accent
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.hintLabel.text = oldText
            self?.hintLabel.textColor = oldColor
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === serverField { tokenField.becomeFirstResponder(); return true }
        connect()
        return true
    }

    private func style(_ f: UITextField, placeholder: String) {
        f.translatesAutoresizingMaskIntoConstraints = false
        f.borderStyle = .roundedRect
        f.backgroundColor = AQColor.card
        f.textColor = AQColor.text
        f.font = UIFont.systemFont(ofSize: 14)
        f.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: AQColor.dim]
        )
        f.heightAnchor.constraint(equalToConstant: 46).isActive = true
    }

    private func makeLabel(_ s: String, size: CGFloat, bold: Bool, color: UIColor) -> UILabel {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = s
        l.font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
        l.textColor = color
        l.numberOfLines = 0
        return l
    }

    private func spacer(_ h: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
        return v
    }
}
