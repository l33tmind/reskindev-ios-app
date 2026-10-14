import Foundation
import FirebaseFirestore

/// Loose readers for documents written by the website, the Flutter app and admin tools.
/// Numbers can arrive as strings, dates as Timestamp / Date / milliseconds.
enum FS {
    /// Non-empty string or nil
    static func string(_ value: Any?) -> String? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        return s
    }

    static func double(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        double(value).map { Int($0) }
    }

    static func date(_ value: Any?) -> Date? {
        if let ts = value as? Timestamp { return ts.dateValue() }
        if let d = value as? Date { return d }
        if let n = value as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue / 1000) }
        return nil
    }

    static func map(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }
}

extension Double {
    /// "$157.50"
    var usd: String { formatted(.currency(code: "USD")) }
}
