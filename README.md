# OffRecord

<!-- One line: what the app does. -->

## Setup

```bash
brew install xcodegen swiftlint
bundle install
cp .env.example .env && chmod 600 .env          # fill values, never commit
cp Config/Secrets.xcconfig.example Config/Secrets.xcconfig   # if the app has build-time secrets
xcodegen generate && open OffRecord.xcodeproj
```

## Environments

| Scheme | Bundle id | Backend | Ships to |
|---|---|---|---|
| `OffRecord-Dev` | `com.iletai.offrecord.dev` | Dev | TestFlight (on every push to `develop`) |
| `OffRecord-Staging` | `com.iletai.offrecord.staging` | Prod | TestFlight (on push to `release/*`, `hotfix/*`) |
| `OffRecord` | `com.iletai.offrecord` | Prod | App Store (on tag `x.y.z`) |

fastlane: `bundle exec fastlane <lane> --env dev|staging|prod` (lanes from [iletai/ios-shared](https://github.com/iletai/ios-shared)).

## Branches

`feature/*` → PR into `develop` → `release/x.y.z` (version bump) → PR into `main` → tag `x.y.z` on the merge commit → merge `main` back into `develop`. Hotfix: `hotfix/x.y.z` from `main`. Conventional commits.

Store text lives in `fastlane/metadata/`; screenshots come from `bundle exec fastlane screenshots --env prod`.

---

## License

Copyright (c) 2026 Le Quang Trong Tai. All rights reserved.

This repository is proprietary and source-available for viewing only.
No permission is granted to use, copy, modify, distribute, or create
derivative works from this code without prior written permission.
See [LICENSE](LICENSE) for the full terms.
