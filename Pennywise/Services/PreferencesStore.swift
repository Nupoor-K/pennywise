import Combine
import Foundation

final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    @Published var currencyCode: String {
        didSet { userDefaults.set(currencyCode, forKey: Self.currencyKey) }
    }

    let supportedCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "INR"]

    private static let currencyKey = "preferredCurrencyCode"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        currencyCode = userDefaults.string(forKey: Self.currencyKey) ?? Locale.current.currency?.identifier ?? "USD"
    }

    func formatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter
    }

    func formatted(_ amount: Double) -> String {
        formatter().string(from: NSNumber(value: amount)) ?? "\(currencyCode) \(amount)"
    }
}
