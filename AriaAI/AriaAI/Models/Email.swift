import Foundation

struct EmailMessage: Identifiable, Codable {
    let id: String
    var threadId: String
    var subject: String
    var from: EmailContact
    var to: [EmailContact]
    var cc: [EmailContact]
    var body: String
    var snippet: String
    var date: Date
    var isRead: Bool
    var isStarred: Bool
    var labels: [String]
    var hasAttachments: Bool

    var isImportant: Bool { labels.contains("IMPORTANT") }
    var isInbox: Bool    { labels.contains("INBOX") }
}

struct EmailContact: Codable, Equatable {
    var name: String
    var email: String

    var displayName: String { name.isEmpty ? email : name }
    var initials: String    { displayName.initials }
}

struct DraftEmail {
    var to: String = ""
    var cc: String = ""
    var subject: String = ""
    var body: String = ""

    var isValid: Bool { !to.trimmed.isEmpty && !subject.trimmed.isEmpty && !body.trimmed.isEmpty }

    var toContacts: [EmailContact] {
        to.components(separatedBy: ",").compactMap { raw in
            let trimmed = raw.trimmed
            guard !trimmed.isEmpty else { return nil }
            return EmailContact(name: "", email: trimmed)
        }
    }
}

// Gmail API response models
struct GmailListResponse: Decodable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Decodable {
    let id: String
    let threadId: String
}

struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailPayload?
    let internalDate: String?

    var date: Date {
        guard let ms = internalDate, let ts = Double(ms) else { return Date() }
        return Date(timeIntervalSince1970: ts / 1000)
    }
}

struct GmailPayload: Decodable {
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPart]?
    let mimeType: String?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailBody: Decodable {
    let data: String?
    let size: Int?
}

struct GmailPart: Decodable {
    let mimeType: String?
    let body: GmailBody?
    let parts: [GmailPart]?
    let filename: String?
}

extension GmailMessage {
    func toEmailMessage() -> EmailMessage {
        let headers = payload?.headers ?? []
        func header(_ name: String) -> String {
            headers.first { $0.name.lowercased() == name.lowercased() }?.value ?? ""
        }

        let fromHeader = header("From")
        let fromContact = parseContact(fromHeader)

        let toHeader = header("To")
        let toContacts = toHeader.components(separatedBy: ",").map { parseContact($0.trimmed) }

        let ccHeader = header("Cc")
        let ccContacts = ccHeader.isEmpty ? [] : ccHeader.components(separatedBy: ",").map { parseContact($0.trimmed) }

        let bodyText = extractBody(payload)

        return EmailMessage(
            id: id,
            threadId: threadId,
            subject: header("Subject").isEmpty ? "(No Subject)" : header("Subject"),
            from: fromContact,
            to: toContacts,
            cc: ccContacts,
            body: bodyText,
            snippet: snippet ?? "",
            date: date,
            isRead: !(labelIds?.contains("UNREAD") ?? false),
            isStarred: labelIds?.contains("STARRED") ?? false,
            labels: labelIds ?? [],
            hasAttachments: hasAttachmentParts(payload)
        )
    }

    private func parseContact(_ raw: String) -> EmailContact {
        if raw.contains("<") && raw.contains(">") {
            let parts = raw.components(separatedBy: "<")
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"")))
            let email = parts[1].replacingOccurrences(of: ">", with: "").trimmed
            return EmailContact(name: name, email: email)
        }
        return EmailContact(name: "", email: raw.trimmed)
    }

    private func extractBody(_ payload: GmailPayload?) -> String {
        guard let payload = payload else { return "" }
        if let data = payload.body?.data, !data.isEmpty {
            return decodeBase64(data)
        }
        if let text = findBodyText(in: payload.parts ?? []) {
            return text
        }
        return snippet ?? ""
    }

    private func findBodyText(in parts: [GmailPart]) -> String? {
        // Prefer text/plain, then text/html, then recurse into nested multipart
        for part in parts {
            if part.mimeType == "text/plain", let data = part.body?.data, !data.isEmpty {
                return decodeBase64(data)
            }
        }
        for part in parts {
            if part.mimeType == "text/html", let data = part.body?.data, !data.isEmpty {
                return decodeBase64(data).stripHTML()
            }
        }
        for part in parts {
            if part.mimeType?.hasPrefix("multipart/") == true, let nested = part.parts {
                if let text = findBodyText(in: nested) { return text }
            }
        }
        return nil
    }

    private func decodeBase64(_ base64: String) -> String {
        let padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        let padded2 = remainder == 0 ? padded : padded + String(repeating: "=", count: 4 - remainder)
        guard let data = Data(base64Encoded: padded2) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func hasAttachmentParts(_ payload: GmailPayload?) -> Bool {
        guard let parts = payload?.parts else { return false }
        return parts.contains { !($0.filename?.isEmpty ?? true) }
    }
}

extension String {
    func stripHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
