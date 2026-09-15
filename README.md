# LifeOS (working name: **2do4you**)

Local-first iOS Life OS — SwiftUI + SwiftData. Your day, money, notes, and habits in one place, with no cloud dependency for v1.

## Product summary

LifeOS is a personal operating system for daily life: today’s schedule and checklist, manual finance tracking, notes, habits, and (later) mail. Everything lives on-device via SwiftData.

**Working name:** 2do4you

## Navigation

| Tab | Role |
|-----|------|
| **Mail** | Placeholder only — no OAuth in v1 |
| **Notes** | List / add / edit / delete notes |
| **Today** | Center tab (emphasized) — schedule, habits, unpaid bills with pay/undo |
| **Finance** | Overview, bills, activity; accounts & balance snapshots |
| **Me** | Habits CRUD, theme, color-blind mode, sample data |

## v1 scope

### In scope
- Local-first SwiftData persistence only
- Notes CRUD
- Habits CRUD + Today checklist
- Manual finance: accounts (checking / savings / credit / cash), balance snapshots, bills, transactions
- Bill check on Today: mark paid → debit linked account (if any) → create transaction; support undo
- Theme preference: system / light / dark; simple `colorBlindMode` bool
- Schedule items on Today
- Face ID unlock string ready (`Unlock LifeOS`) — wiring optional

### Explicitly out of scope (v1)
- Plaid / bank login — balances are manual
- Mail OAuth / real inbox
- In-app purchases
- Cloud sync / accounts

## Tech

- iOS 17+
- SwiftUI + SwiftData (`@Model`, `@Query`, `@Environment(\.modelContext)`)
- XcodeGen `project.yml` provided, or drop `Sources/` into a new empty iOS App target

## Quick start

See [SETUP.md](SETUP.md).

## License

Private / personal use unless otherwise noted.
