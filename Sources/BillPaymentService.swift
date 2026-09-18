import Foundation
import SwiftData

enum BillPaymentService {
    /// Mark bill paid, debit linked account if present, create transaction.
    @MainActor
    static func markPaid(_ bill: Bill, in context: ModelContext) {
        guard !bill.isPaid else { return }
        bill.isPaid = true
        bill.paidAt = .now

        let debitAmount = -bill.amount
        let tx = Transaction(
            title: "Bill: \(bill.name)",
            amount: debitAmount,
            date: .now,
            account: bill.linkedAccount,
            relatedBill: bill
        )
        context.insert(tx)
        bill.paymentTransaction = tx

        if let account = bill.linkedAccount {
            // Credit accounts: paying a bill often increases available credit;
            // for simplicity, all account types: subtract amount (money leaving).
            account.currentBalance += debitAmount
        }
        try? context.save()
    }

    /// Undo payment: restore bill, reverse balance, mark/remove transaction.
    @MainActor
    static func undoPaid(_ bill: Bill, in context: ModelContext) {
        guard bill.isPaid else { return }
        if let tx = bill.paymentTransaction {
            if let account = tx.account {
                // Reverse the debit
                account.currentBalance -= tx.amount
            }
            tx.isUndone = true
            context.delete(tx)
            bill.paymentTransaction = nil
        }
        bill.isPaid = false
        bill.paidAt = nil
        try? context.save()
    }
}
