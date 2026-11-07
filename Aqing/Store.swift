import Foundation
import UIKit
import Security

enum AQColor {
    static let background = UIColor(red: 0.090, green: 0.078, blue: 0.114, alpha: 1)
    static let card       = UIColor(red: 0.145, green: 0.125, blue: 0.180, alpha: 1)
    static let accent     = UIColor(red: 0.941, green: 0.651, blue: 0.753, alpha: 1)
    static let accent2    = UIColor(red: 0.773, green: 0.549, blue: 1.000, alpha: 1)
    static let text       = UIColor(red: 0.950, green: 0.930, blue: 0.960, alpha: 1)
    static let dim        = UIColor(red: 0.660, green: 0.620, blue: 0.700, alpha: 1)
}

extension Notification.Name {
    static let aqReload = Notification.Name("aq.reload")
}

enum Store {
    /// 公网入口：DuckDNS 固定域名 + Let's Encrypt 真证书，IPv6 直连，不过任何隧道。
    /// 前缀变了 DDNS 会自己跟，证书 90 天自动续，这个地址长期有效。
    static let defaultBaseURL = "https://aqing.duckdns.org:18085/out/app/"

    private static let defaults = UserDefaults.standard

    static var token: String {
        get { Keychain.read("aq_token") ?? "" }
        set { Keychain.write("aq_token", newValue) }
    }

    static var baseURL: String {
        get { defaults.string(forKey: "aq_baseURL") ?? defaultBaseURL }
        set { defaults.set(newValue, forKey: "aq_baseURL") }
    }

    /// 只在填了家里局域网地址时才需要，用来信任自签 CA；公网正式证书一律不做例外。
    static var trustLAN: Bool {
        get { defaults.bool(forKey: "aq_trustLAN") }
        set { defaults.set(newValue, forKey: "aq_trustLAN") }
    }

    static var isConfigured: Bool { !token.isEmpty }

    /// 用户可能只填了域名，补上瘦网关路径，并去掉多余的 query/fragment。
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return defaultBaseURL }
        if !s.contains("://") { s = "https://" + s }
        guard var c = URLComponents(string: s) else { return s }
        if c.path.isEmpty || c.path == "/" { c.path = "/out/app/" }
        else if !c.path.hasSuffix("/") { c.path += "/" }
        c.query = nil
        c.fragment = nil
        return c.string ?? s
    }

    /// 真正加载的地址：每次都把令牌、原生壳标记带上，避免钥匙串和网页存储不同步。
    static func chatURL(text: String? = nil) -> URL? {
        guard var c = URLComponents(string: baseURL) else { return nil }
        var items = (c.queryItems ?? []).filter {
            $0.name != "token" && $0.name != "native" && $0.name != "text"
        }
        items.append(URLQueryItem(name: "token", value: token))
        items.append(URLQueryItem(name: "native", value: "1"))
        if let t = text, !t.isEmpty { items.append(URLQueryItem(name: "text", value: t)) }
        c.queryItems = items
        return c.url
    }
}

private enum Keychain {
    private static let service = "cn.aqing.companion"

    static func read(_ key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String) {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attrs: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        if SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        } else {
            var add = q
            add.merge(attrs) { _, new in new }
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
