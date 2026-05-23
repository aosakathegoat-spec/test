import SwiftUI
import UIKit

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Date helpers
private enum DateFormatters {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    static let monthDayYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}

extension Date {
    var shortTimeString: String {
        DateFormatters.shortTime.string(from: self)
    }

    var emailDateString: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return shortTimeString }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        let sameYear = cal.component(.year, from: self) == cal.component(.year, from: Date())
        return (sameYear ? DateFormatters.monthDay : DateFormatters.monthDayYear).string(from: self)
    }
}

// MARK: - String helpers
extension String {
    var initials: String {
        let words = components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return prefix(2).uppercased()
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Int formatting
extension Int {
    var tokenFormatted: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

// MARK: - UIImage compression
extension UIImage {
    func jpegDataCapped(maxBytes: Int = 1_048_576) -> Data? {
        var quality: CGFloat = 0.85
        while quality > 0.1 {
            if let data = jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.15
        }
        return jpegData(compressionQuality: 0.1)
    }

    func base64EncodedString(maxBytes: Int = 1_048_576) -> String? {
        jpegDataCapped(maxBytes: maxBytes)?.base64EncodedString()
    }
}

