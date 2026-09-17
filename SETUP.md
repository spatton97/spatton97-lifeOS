# LifeOS — Setup

## Option A: XcodeGen (preferred if installed)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if needed: `brew install xcodegen`
2. From this directory:
   ```bash
   cd /path/to/LifeOS
   xcodegen generate
   open LifeOS.xcodeproj
   ```
3. Select your **Team** under Signing & Capabilities for the LifeOS target.
4. Set a unique Bundle Identifier if needed (default in `project.yml`: `com.lifeos.app`).
5. Build & run on simulator or device (iOS 17+).

## Option B: Manual Xcode project (drop-in Sources)

1. Open Xcode → **File → New → Project → App**
2. Product Name: `LifeOS`
3. Interface: **SwiftUI**, Language: **Swift**, Storage: **None** (we use SwiftData in code)
4. Save the project somewhere convenient.
5. Delete the default `ContentView.swift` / `*App.swift` that Xcode created (keep the asset catalog if you want).
6. Add the files from this repo’s `Sources/` folder to the app target (drag into the project navigator, check “Copy items if needed”, ensure target membership).
7. Set **iOS Deployment Target** to **17.0**.
8. Signing: select your Team; set Bundle ID as desired.

## Face ID / Local Authentication privacy string

Face ID / passcode lock is **live** in the app (off by default; toggle under **Me → Privacy**). The usage description is **required** and is already configured in `project.yml` via `INFOPLIST_KEY_NSFaceIDUsageDescription`.

If you create a project manually (Option B) without XcodeGen, add this key to the target’s Info (or merge the snippet below into `Info.plist`):

| Key | Value |
|-----|--------|
| `NSFaceIDUsageDescription` | `Unlock LifeOS` |

### INFO.plist snippet

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock LifeOS</string>
```

A copy of this note also lives in `INFO.plist.snippet` in this folder.

## Capabilities

- **Face ID / Local Authentication**: privacy string above is required (already in `project.yml` for XcodeGen). Unlock is off by default until enabled in Me → Privacy.
- No Sign in with Apple, no IAP, no associated domains needed for v1.

## Verify

1. Launch app → **Today** tab should be center and usable empty.
2. **Me** → optionally tap **Add sample data**, then return to Today / Finance.
3. Create a bill with a linked account → on Today mark paid → check Finance Activity and account balance; use undo on Today.
4. **Me → Privacy** → enable **Require Face ID / Passcode**, background the app, and confirm the lock screen appears.

## Assumptions

- Xcode 15+ with iOS 17 SDK
- No third-party SPM packages required for v1
