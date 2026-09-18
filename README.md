# LifeOS (working name: **2do4you**)

Local-first iOS Life OS — SwiftUI + SwiftData. Your day, money, notes, habits, and mail in one place.

## Product summary

LifeOS is a personal operating system for daily life: today’s schedule and checklist, manual finance tracking, notes, habits, and a free single Gmail inbox (read-only). Core data lives on-device via SwiftData; Gmail OAuth tokens live in the Keychain.

**Working name:** 2do4you

## Navigation

| Tab | Role |
|-----|------|
| **Mail** | One free Gmail login, read-only inbox (subject / from / date / snippet). Disconnect supported. |
| **Notes** | List / add / edit / delete notes |
| **Today** | Center tab (emphasized) — schedule, habits, unpaid bills with pay/undo |
| **Finance** | Overview, bills, activity; accounts & balance snapshots |
| **Me** | Habits CRUD, theme, color-blind mode, privacy lock, sample data |

## Mail (free vs later)

- **Free:** exactly **one** connected Gmail mailbox, **read-only** (Gmail `gmail.readonly` scope). Inbox list + optional message detail. Refresh / pull-to-refresh. Sign-out / disconnect clears Keychain tokens and the SwiftData mailbox row.
- **Not in free / not implemented yet:** multiple mailboxes, send/compose, bill auto-suggestions from mail. Attempting a second connect shows a clear **“Subscription unlocks more mailboxes”** UI gate (no StoreKit IAP wiring yet). Bill suggestions may land in a later / pro release.

## v1 scope

### In scope
- Local-first SwiftData persistence
- Notes CRUD
- Habits CRUD + Today checklist
- Manual finance: accounts (checking / savings / credit / cash), balance snapshots, bills, transactions
- Bill check on Today: mark paid → debit linked account (if any) → create transaction; support undo
- Theme preference: system / light / dark; simple `colorBlindMode` bool
- Schedule items on Today
- Face ID / device passcode lock is **live** — off by default; enable in **Me → Privacy** (`Require Face ID / Passcode`)
- **Mail:** one free Gmail OAuth login + read-only inbox (see above)

### Explicitly out of scope (v1)
- Plaid / bank login — balances are manual
- Multi-mailbox, send mail, bill auto-suggestions from inbox
- In-app purchases / StoreKit (subscription gate is UI-only)
- Cloud sync / accounts

## Tech

- iOS 17+
- SwiftUI + SwiftData (`@Model`, `@Query`, `@Environment(\.modelContext)`)
- Mail: `AuthenticationServices` (`ASWebAuthenticationSession`) + Gmail REST API; tokens in Keychain keyed by mailbox id
- XcodeGen `project.yml` provided, or drop `Sources/` into a new empty iOS App target
- `NSFaceIDUsageDescription` is required for the privacy lock and is already set in `project.yml` (`Unlock LifeOS`)
- Gmail requires a Google Cloud OAuth **iOS** client ID + URL scheme — see [SETUP.md](SETUP.md)

## Quick start

See [SETUP.md](SETUP.md).

## License

Private / personal use unless otherwise noted.
