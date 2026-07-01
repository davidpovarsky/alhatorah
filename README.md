# NativeSiteApp

A clean UIKit iOS app that turns a chosen website into a focused native-style app.

Default website: `https://alhatorah.org/`

## What is included

- UIKit app, no SwiftUI, no HStack/VStack.
- `WKWebView` main browser.
- Native bottom `UIToolbar` that hides on scroll and can be shown again by swiping from the bottom edge or two-finger tapping.
- Native tabs screen using `UITableViewController`.
- Native history screen with search using `UISearchController`.
- Native settings screen using `UITableViewController`.
- Allowed-domain policy with subdomain support.
- External domains open in `SFSafariViewController`, which is Safari inside the app.
- Custom deep link scheme: `nativeweb://open?url=https://alhatorah.org/`
- Universal Link handler code is ready, but Universal Links also require website-side setup.
- IPA build script with archive/export logs.
- GitHub Actions workflow template for IPA artifact output.

## Project structure

```text
NativeSiteApp.xcodeproj
NativeSiteApp/
  App/
    AppDelegate.swift
    SceneDelegate.swift
  Browser/
    BrowserViewController.swift
  Core/
    AppSettings.swift
    BrowserTab.swift
    DeepLinkParser.swift
    DomainNormalizer.swift
    HistoryItem.swift
    HistoryStore.swift
    SettingsStore.swift
    TabStore.swift
    URLPolicy.swift
  History/
    HistoryViewController.swift
  Settings/
    SettingsViewController.swift
    TextListEditorViewController.swift
  Tabs/
    TabsViewController.swift
  Utilities/
    AlertFactory.swift
    DateFormatting.swift
    FileStore.swift
scripts/
  build_ipa.sh
.github/workflows/
  build-ipa.yml
```

## Domain behavior

The settings screen has **Allowed Domains**.

If you enter:

```text
alhatorah.org
```

then all of these are treated as internal links and open in the main WebView:

```text
https://alhatorah.org/
https://shas.alhatorah.org/Full/Chulin/62a.1#e0n6
```

Any other domain opens in a native Safari view inside the app.

You can also paste full URLs into Allowed Domains. The app normalizes them to hosts.

## Deep links

The app registers this custom URL scheme:

```text
nativeweb://open?url=https://alhatorah.org/
```

For example:

```text
nativeweb://open?url=https%3A%2F%2Fshas.alhatorah.org%2FFull%2FChulin%2F62a.1%23e0n6
```

This works without controlling the website.

## Universal Links note

Opening normal `https://alhatorah.org/...` links directly in the app requires both:

1. Associated Domains enabled in Xcode for the app.
2. An `apple-app-site-association` file served from the website domain.

If you do not control the website, use the custom scheme, a Shortcut, or a Safari extension to redirect into `nativeweb://open?url=...`.

## Build an IPA locally

Run from the repository root on macOS with Xcode installed:

```bash
TEAM_ID=ABCDE12345 \
BUNDLE_ID=com.yourname.NativeSiteApp \
ALLOW_AUTOMATIC_SIGNING=true \
./scripts/build_ipa.sh
```

Output:

```text
build/ipa/*.ipa
build_logs/archive.log
build_logs/export.log
build_logs/last_build_summary.txt
```

A real device IPA requires valid Apple signing. If signing fails, send or inspect `build_logs/archive.log` and `build_logs/export.log`.

## GitHub Actions

The workflow is included at:

```text
.github/workflows/build-ipa.yml
```

It expects these repository secrets:

```text
APPLE_TEAM_ID
APP_BUNDLE_ID
BUILD_CERTIFICATE_BASE64
P12_PASSWORD
BUILD_PROVISION_PROFILE_BASE64
KEYCHAIN_PASSWORD
```

The workflow installs the signing certificate and provisioning profile, then runs `scripts/build_ipa.sh` and uploads the IPA plus logs as an artifact.
