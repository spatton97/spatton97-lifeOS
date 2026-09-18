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
6. Add the files from this repo’s `Sources/` folder to the app target (drag into the project navigator, check “Copy items if needed”, ensure target membership). **Do not** keep `MailPlaceholderView.swift` if you still have it — it was replaced by `MailView.swift`.
7. Set **iOS Deployment Target** to **17.0**.
8. Signing: select your Team; set Bundle ID as desired.

## Face ID / Local Authentication privacy string

Face ID / passcode lock is **live** in the app (off by default; toggle under **Me → Privacy**). The usage description is **required** and is already configured in `project.yml` via `INFOPLIST_KEY_NSFaceIDUsageDescription`.

If you create a project manually (Option B) without XcodeGen, add this key to the target’s Info (or merge the snippet below into `Info.plist`):

| Key | Value |
|-----|--------|
| `NSFaceIDUsageDescription` | `Unlock LifeOS` |

### INFO.plist snippet (Face ID)

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock LifeOS</string>
```

## Gmail OAuth (Mail tab — one free read-only mailbox)

Mail uses **Google OAuth for iOS** via `ASWebAuthenticationSession` and the Gmail API with scope:

`https://www.googleapis.com/auth/gmail.readonly`

If the Client ID is missing, the Mail tab shows setup instructions and **Connect** stays disabled (no crash).

### 1. Google Cloud Console

1. Open [Google Cloud Console](https://console.cloud.google.com/) → create or select a project.
2. **APIs & Services → Library** → enable **Gmail API**.
3. **APIs & Services → OAuth consent screen** → configure (External is fine for personal use). Add yourself as a test user while the app is in Testing.
4. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
5. Application type: **iOS**.
6. Bundle ID: must match the Xcode target (default `com.lifeos.app`, or whatever you set).
7. Copy the **Client ID** (looks like `123456789-abcdefg.apps.googleusercontent.com`).

### 2. Paste Client ID into Xcode

Add **one** of these keys to the LifeOS target **Info** (Custom iOS Target Properties), or to `Info.plist`:

| Key | Value |
|-----|--------|
| `LifeOSGmailClientID` | *your iOS Client ID* |
| **or** `GIDClientID` | *same Client ID* (Google Sign-In convention) |

The app reads `LifeOSGmailClientID` first, then falls back to `GIDClientID`.

**XcodeGen:** you can set either via build settings, e.g. in `project.yml` under the LifeOS target:

```yaml
INFOPLIST_KEY_LifeOSGmailClientID: "YOUR_IOS_CLIENT_ID.apps.googleusercontent.com"
```

(Do not commit a real production secret if the repo is shared; for a personal iOS client ID this is normal client-side config.)

### 3. URL scheme (reversed Client ID)

Google’s iOS redirect uses the **reversed** Client ID as the URL scheme.

Example:

- Client ID: `123456789-abcdefg.apps.googleusercontent.com`
- Reversed: `com.googleusercontent.apps.123456789-abcdefg`

In Xcode → LifeOS target → **Info → URL Types** → add:

| Field | Value |
|-------|--------|
| Identifier | `GoogleOAuth` (any label) |
| URL Schemes | `com.googleusercontent.apps.YOUR_PREFIX` (the reversed Client ID) |

Or in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>GoogleOAuth</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_PREFIX</string>
    </array>
  </dict>
</array>
```

Redirect URI used by the app: `{reversedClientID}:/oauth2redirect/google`  
(You do **not** register this redirect in Google Cloud for an iOS client type — only the Bundle ID matters there.)

### 4. Product limits (no IAP yet)

- Free: **exactly one** mailbox. A second connect attempt shows **“Subscription unlocks more mailboxes”** (UI only).
- Tokens are stored in the **Keychain** keyed by mailbox id — not in SwiftData plaintext.
- Disconnect / sign-out removes Keychain tokens and deletes the mailbox row.

## Capabilities

- **Face ID / Local Authentication**: privacy string above is required (already in `project.yml` for XcodeGen). Unlock is off by default until enabled in Me → Privacy.
- **Gmail**: Client ID + URL scheme as above. No Sign in with Apple SDK, no IAP, no associated domains required for this free mail slice.

## Verify

1. Launch app → **Today** tab should be center and usable empty.
2. **Me** → optionally tap **Add sample data**, then return to Today / Finance.
3. Create a bill with a linked account → on Today mark paid → check Finance Activity and account balance; use undo on Today.
4. **Me → Privacy** → enable **Require Face ID / Passcode**, background the app, and confirm the lock screen appears.
5. **Mail** → with Client ID configured, Connect Gmail → grant readonly → see inbox list; Refresh / pull-to-refresh; Disconnect clears the account. Without Client ID, you should see setup copy and a disabled Connect button.

## Assumptions

- Xcode 15+ with iOS 17 SDK
- No third-party SPM packages required for this mail slice (uses system `AuthenticationServices`)
