import Foundation
import MessageUI
import SwiftUI

struct BalanceReminder: Identifiable {
    let id = UUID()
    let recipient: ParticipantEntity
    let subject: String
    let body: String
}

enum MailReminderService {
    static func reminder(for suggestion: SettlementSuggestion, trip: TripEntity, preferences: PreferencesStore) -> BalanceReminder {
        let amount = preferences.formatted(suggestion.amount)
        return BalanceReminder(
            recipient: suggestion.from,
            subject: "Pennywise reminder for \(trip.name)",
            body: """
            Hi \(suggestion.from.name),

            Pennywise shows an outstanding balance for \(trip.name).

            Please send \(amount) to \(suggestion.to.name) when you have a chance.

            Thanks!
            """
        )
    }

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }
}

struct MailComposer: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let reminder: BalanceReminder

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        if let email = reminder.recipient.email, !email.isEmpty {
            composer.setToRecipients([email])
        }
        composer.setSubject(reminder.subject)
        composer.setMessageBody(reminder.body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
