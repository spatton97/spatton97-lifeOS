import SwiftUI

struct MailPlaceholderView: View {
    @Environment(\.colorBlindMode) private var colorBlind

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Mail", systemImage: "envelope.badge.shield.half.filled")
            } description: {
                Text("Mail is coming after OAuth. For now, LifeOS stays fully local — no inbox login required.")
            } actions: {
                Text("Placeholder only — no mail accounts in v1")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .navigationTitle("Mail")
        }
        .tint(LifeOSAccent.primary(colorBlind: colorBlind))
    }
}

#Preview {
    MailPlaceholderView()
        .environment(\.colorBlindMode, false)
}
