import Contacts
import MessageUI
import UIKit

struct ContactInfo: Identifiable {
    let id: String
    let name: String
    let phoneNumbers: [String]
    var primaryPhone: String { phoneNumbers.first ?? "" }
}

enum SMSError: LocalizedError {
    case contactsAccessDenied
    case smsNotAvailable
    var errorDescription: String? {
        switch self {
        case .contactsAccessDenied: return "Contacts access denied. Enable it in Settings → Privacy → Contacts."
        case .smsNotAvailable: return "SMS is not available on this device."
        }
    }
}

@MainActor
final class SMSService: NSObject, ObservableObject {
    static let shared = SMSService()
    private var messageCompletion: ((Bool) -> Void)?
    private override init() { super.init() }

    var canSendSMS: Bool { MFMessageComposeViewController.canSendText() }

    func requestContactsAccess() async -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return true
        case .notDetermined:
            return (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        default: return false
        }
    }

    func searchContacts(query: String) async throws -> [ContactInfo] {
        guard await requestContactsAccess() else { throw SMSError.contactsAccessDenied }
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey,
                    CNContactPhoneNumbersKey, CNContactIdentifierKey] as [CNKeyDescriptor]
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let raw = try CNContactStore().unifiedContacts(matching: predicate, keysToFetch: keys)
        return raw.compactMap { c -> ContactInfo? in
            let phones = c.phoneNumbers.map { $0.value.stringValue }
            guard !phones.isEmpty else { return nil }
            return ContactInfo(
                id: c.identifier,
                name: "\(c.givenName) \(c.familyName)".trimmed,
                phoneNumbers: phones
            )
        }
    }

    func presentSMSComposer(to phoneNumber: String, body: String) async -> Bool {
        guard MFMessageComposeViewController.canSendText() else { return false }
        return await withCheckedContinuation { continuation in
            let vc = MFMessageComposeViewController()
            vc.recipients = [phoneNumber]
            vc.body = body
            vc.messageComposeDelegate = self
            self.messageCompletion = { continuation.resume(returning: $0) }
            guard let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController?.topMost else {
                continuation.resume(returning: false)
                return
            }
            root.present(vc, animated: true)
        }
    }
}

extension SMSService: MFMessageComposeViewControllerDelegate {
    nonisolated func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        let success = result == .sent
        controller.dismiss(animated: true)
        Task { @MainActor [weak self] in
            self?.messageCompletion?(success)
            self?.messageCompletion = nil
        }
    }
}

private extension UIViewController {
    var topMost: UIViewController {
        presentedViewController?.topMost ?? self
    }
}
