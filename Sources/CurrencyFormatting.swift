import Foundation

/// Shared locale currency code for Today + Finance amount formatting.
var lifeOSCurrencyCode: String {
    Locale.current.currency?.identifier ?? "USD"
}
