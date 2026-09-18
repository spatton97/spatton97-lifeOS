import SwiftUI
import LocalAuthentication

@MainActor
final class AppLockController: ObservableObject {
    @Published var isUnlocked = false
    @Published var statusMessage: String?

    func lock() {
        isUnlocked = false
        statusMessage = nil
    }

    func apply(enabled: Bool) async {
        if enabled {
            if !isUnlocked {
                await authenticate()
            }
        } else {
            isUnlocked = true
            statusMessage = nil
        }
    }

    func authenticate() async {
        let context = LAContext()
        var error: NSError?
        let reason = "Unlock LifeOS"

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Simulator / device with no passcode: keep locked and explain.
            statusMessage = error?.localizedDescription
                ?? "Set a device passcode (or enroll Face ID) to use the lock."
            isUnlocked = false
            return
        }

        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isUnlocked = ok
            statusMessage = ok ? nil : "Authentication failed."
        } catch {
            isUnlocked = false
            statusMessage = error.localizedDescription
        }
    }
}

struct LockScreenView: View {
    let message: String?
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("LifeOS is locked")
                    .font(.title2.weight(.semibold))
                Text("Use Face ID or your device passcode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button("Unlock", action: onUnlock)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding()
        }
    }
}
