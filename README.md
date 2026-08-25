<p align="center">
  <img src="https://github.com/opa334/Dopamine/assets/52459150/ed04dd3e-d879-456d-9aa3-d4ed44819c7e" width="96" alt="Dopamine" />
</p>

<h1 align="center">Dopamine Flutter</h1>

<p align="center">
  <strong>Material 3 frontend</strong> for the Dopamine rootless jailbreak, built with Flutter and dart:ffi.<br/>
  All original exploit, BaseBin and bootstrap code is preserved unchanged.
</p>

---

## What is this?

This fork replaces the original UIKit interface with a **Flutter Material 3** UI while keeping the entire native jailbreak stack intact. Communication happens through a thin C ABI bridge that Dart calls via **`dart:ffi`** — no platform channels, no JavaScript bridges.

```
┌─────────────────────────────┐
│   Flutter (Material 3)      │
│   lib/src/app.dart          │
└──────────┬──────────────────┘
           │ dart:ffi (C ABI)
┌──────────▼──────────────────┐
│   NativeBridge.mm            │
│   dopamine_state_json()     │
│   dopamine_start_jailbreak()│
│   dopamine_run_action()     │
│   dopamine_read_log_line()  │
└──────────┬──────────────────┘
           │
┌──────────▼──────────────────┐
│   Dopamine Core (unchanged) │
│   DOJailbreaker             │
│   DOEnvironmentManager      │
│   DOBootstrapper            │
│   DOExploitManager          │
│   BaseBin / kfd / Fugu15    │
└─────────────────────────────┘
```

### Preserved features

- Kernel exploitation (Fugu15 / kfd / weightBufs / DarkSword)
- PAC & PPL/SPTM bypass selection
- Bootstrap extraction & Procursus installation
- Tweak injection toggle & safe mode
- iDownload developer shell
- Jetsam multiplier configuration
- Package manager picker (Sileo / Zebra)
- Boot logo customization
- Hide/unhide jailbreak
- Remove jailbreak
- Environment & app updates

### New in this fork

- Full **Material 3** design with dynamic color
- Dart FFI bindings (`lib/src/ffi/dopamine_ffi.dart`)
- Native C ABI bridge (`Application/Dopamine/NativeBridge.mm`)
- GitHub Actions CI producing **unsigned IPA** artifacts on every push

---

## Building

### Prerequisites

| Tool | Version |
|------|---------|
| Xcode | ≥ 16.0 |
| Flutter | stable channel |
| CocoaPods | not required |
| [Procursus](https://github.com/ProcursusTeam/procursus) `ldid` | latest |

### Local build

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Build the Flutter AOT engine as an xcframework
flutter build ios-framework --no-debug --no-profile \
  --output=Application/Frameworks/FlutterProducts

# 3. Download bootstrap archives
cd Application/Dopamine/Resources && ./download_bootstraps.sh && cd ../../..

# 4. Build the native app (unsigned)
cd Application
xcodebuild -project Dopamine.xcodeproj \
  -scheme Dopamine \
  -configuration Release \
  -derivedDataPath build \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' CODE_SIGN_ENTITLEMENTS='' \
  FRAMEWORK_SEARCH_PATHS='$(inherited) "$(SRCROOT)/Frameworks/FlutterProducts/Release"' \
  build

# 5. Embed Flutter framework + pseudo-sign with ldid
APP=build/Build/Products/Release-iphoneos/Dopamine.app
mkdir -p "$APP/Frameworks"
cp -a Frameworks/FlutterProducts/Release/Flutter.xcframework "$APP/Frameworks/"
ldid -SDopamine/Dopamine.entitlements "$APP/Dopamine"

# 6. Package IPA
rm -rf Payload && mkdir Payload
cp -a "$APP" Payload/Dopamine.app
zip -qry Dopamine.ipa Payload
rm -rf Payload
```

### CI build

Every push to any branch triggers `.github/workflows/build.yml`, which produces an unsigned IPA artifact named `Dopamine-Flutter-<sha>`. Download it from the **Actions** tab.

The IPA is **not signed** — install it with [TrollStore](https://github.com/opa334/TrollStore), [SideStore](https://sidestore.io), AltStore, or sign it yourself with your Apple Developer certificate before sideloading.

---

## Project layout

```
.
├── lib/                              # Flutter Dart source
│   ├── main.dart                     # Entry point
│   ├── dopamine.dart                 # Public exports
│   └── src/
│       ├── app.dart                  # Material 3 screens & controllers
│       └── ffi/
│           └── dopamine_ffi.dart     # dart:ffi bindings for the C ABI
├── Application/
│   ├── Dopamine.xcodeproj/          # Original Xcode project (patched)
│   └── Dopamine/
│       ├── NativeBridge.h/.mm        # C ABI bridge (new)
│       ├── UI/
│       │   └── DOUIManager+Bridge.* # Log capture extension (new)
│       └── …                        # All original native source unchanged
├── BaseBin/                          # Launchd hook, jbserver, trustcache (unchanged)
├── Packages/                         # Bootstrap packages (unchanged)
├── Exploits/                         # Kernel exploits (unchanged)
└── .github/workflows/build.yml      # Unsigned IPA CI (new)
```

## FFI API reference

```dart
// Singleton accessor; throws on non-Apple platforms.
final ffi = DopamineFfi.instance();

// Read current jailbreak state (JSON map).
Map<String, dynamic> state = ffi.state();

// Start the jailbreak with user preferences.
await ffi.startJailbreak(
  removeJailbreak: false,
  tweakInjection: true,
  iDownload: false,
  appJit: true,
  verboseLogs: false,
  jetsamMultiplier: 6,
);

// Run a named action (respring, userspaceReboot, hideJailbreak…).
ffi.action('respring');

// Poll captured stdout/stderr log lines one at a time.
String line = ffi.nextLog();
```

### C ABI symbols

| Symbol | Signature | Purpose |
|--------|-----------|---------|
| `dopamine_state_json` | `char *(void)` | Serialized device & jailbreak state |
| `dopamine_start_jailbreak` | `int(const char *json)` | Launch exploit chain asynchronously |
| `dopamine_run_action` | `int(const char *action, const char *json)` | Execute a named system action |
| `dopamine_read_log_line` | `long(char *buf, long cap)` | Drain next captured log line |
| `dopamine_free_string` | `void(char *)` | Free returned heap string |

---

## Credits

All credit goes to the original Dopamine team and contributors:

- **[opa334](https://github.com/opa334)** — lead developer
- **kok3shidoll**, **Alfie**, **Clarity**, **staturnz**, **wh1te4ever** — exploit development
- **tomt000**, **sourcelocation**, **xerus** — original UI design
- Based on [Fugu15](https://github.com/pinauten/Fugu15) by [pinauten](https://github.com/pinauten)

Flutter port by [@11lzq11](https://github.com/11lzq11).

## License

GPL-3.0 — see [LICENSE.md](LICENSE.md). Bundled components carry their own licenses listed under `Application/Dopamine/Resources/`.
