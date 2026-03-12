# iOS CI/CD Blueprint

> Source of truth for all Fr0zenSide iOS & Swift projects.
> Templates live in `templates/ios-cicd/`. Update here, propagate to projects.

## Architecture

```
feature/* ──┐
story/*  ───┤
             ├──▶ develop ──▶ release/* ──▶ main
hotfix/* ───┘        │                        │
                     ▼                        ▼
               TestFlight β              App Store
```

Every project follows git flow. The branch names may vary but the pattern is constant:
- **CI** runs on PRs + push to the integration branch (usually `develop`)
- **CD** deploys to TestFlight on merge to the integration branch
- **Release** submits to App Store from `release/*` branches (manual gate)

## Project Registry

| Project | Repo | Type | CI Template | CD | Monorepo Deps | Status |
|---------|------|------|-------------|-----|---------------|--------|
| **Maya** | Fr0zenSide/Maya | Xcode + SPM | `ci.yml` | TestFlight | Yes (CoreKit, NetworkKit, SecurityKit, Kintsugi) | Active |
| **WabiSabi** | Fr0zenSide/WabiSabi | Xcode + SPM | `ci.yml` | TestFlight | Yes (CoreKit, SecurityKit, NetworkKit, DesignKit) | Active |
| **Flsh** | Fr0zenSide/Flsh | SPM | `spm-ci.yml` | — | No | Needs CI |
| **fuzzy-swift** | Fr0zenSide/fuzzy-swift | SPM | `spm-ci.yml` | — | No | Needs CI |
| **swiftui-qc** | Fr0zenSide/chromatic-swift | SPM | `spm-ci.yml` | — | No | Needs CI |
| **kintsugi-ds** | Fr0zenSide/kintsugi-ds | SPM + Node | `spm-ci.yml` | — | No | Needs CI |
| **Brainy** | (not yet) | SPM | `spm-ci.yml` | — | TBD | Planning |

### Dependency Graph

```
                    ┌─────────────┐
                    │   CoreKit   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
      ┌───────▼──┐  ┌─────▼────┐  ┌───▼────────┐
      │NetworkKit│  │SecurityKit│  │  DesignKit  │
      └───┬──────┘  └────┬─────┘  └──────┬──────┘
          │               │               │
    ┌─────▼───────────────▼───┐     ┌─────▼──────┐
    │         Maya            │     │ Kintsugi DS │
    │      WabiSabi           │     └─────┬──────┘
    └─────────────────────────┘           │
                ▲                         │
                └─────────────────────────┘
```

Projects that depend on shared packages (`../../packages/*`) need the **monorepo checkout** pattern in CI.

## Templates

### 1. `ci.yml` — Xcode Project Build & Test

For iOS apps with `.xcodeproj` (Maya, WabiSabi).

**Two parallel jobs:**
- SPM Package Tests (`swift test --parallel`)
- iOS App Build & Test (`xcodebuild build-for-testing` + `test-without-building`)

**Customization points** (search `TODO` in template):

| Variable | Maya | WabiSabi |
|----------|------|----------|
| `SCHEME` | `Maya` | `WabiSabi` |
| `PROJECT_FILE` | `MayaFit.xcodeproj` | `WabiSabi.xcodeproj` |
| `TEST_TARGET` | `MayaFitTests` | `WabiSabiTests` |
| `NEEDS_MONOREPO_CHECKOUT` | `true` | `true` |
| Monorepo subpath | `monorepo/projects/maya` | `monorepo/projects/wabisabi` |
| Branches | `develop` | `develop` |

### 2. `cd-testflight.yml` — TestFlight Deploy

For iOS apps that ship to TestFlight.

**Single job:** Archive → Export IPA → Upload via ASC API key.

**Additional customization:**

| Variable | Maya | WabiSabi |
|----------|------|----------|
| `APP_NAME` | `Maya` | `WabiSabi` |
| `EXPORT_OPTIONS` | `MayaFit/App/exportOptions.plist` | `WabiSabi/exportOptions.plist` |
| Deploy branch | `develop` | `develop` |

### 3. `spm-ci.yml` — Pure SPM Package

For Swift packages without Xcode project (Flsh, fzf, swiftui-qc, kintsugi-ds).

**Single job:** `swift build` + `swift test --parallel`.

No secrets needed. No signing. No monorepo checkout (these packages are standalone).

## GitHub Secrets Reference

### Shared Across All iOS Apps

These secrets are the **same** for all projects under the same Apple Developer account:

| Secret | Description | Shared? |
|--------|-------------|---------|
| `DEVELOPMENT_TEAM` | Apple Team ID: `UVC4JM6XD4` | All projects |
| `ASC_API_KEY_ID` | App Store Connect API Key ID | All projects |
| `ASC_API_ISSUER_ID` | App Store Connect Issuer ID | All projects |
| `ASC_API_KEY_BASE64` | `.p8` API key, base64-encoded | All projects |

### Per-Project Secrets

| Secret | Description |
|--------|-------------|
| `SIGNING_CERTIFICATE_P12_BASE64` | Distribution certificate (.p12), base64 |
| `SIGNING_CERTIFICATE_PASSWORD` | Password for .p12 |
| `PROVISIONING_PROFILE_BASE64` | App Store provisioning profile, base64 |
| `PACKAGES_TOKEN` | GitHub PAT for `shiki` + `kintsugi-ds` repos |

> The signing certificate is tied to the Apple Developer account, so the same `.p12` works for all projects. The provisioning profile is **per bundle ID** (per project).

### How to Generate Each Secret

#### 1. Distribution Certificate (one-time, shared)

```bash
# In Keychain Access:
# 1. Find "Apple Distribution: Your Name (UVC4JM6XD4)"
# 2. Right-click → Export → save as Certificates.p12 (set a password)

# Encode for GitHub:
base64 -i Certificates.p12 | pbcopy
# → Paste as SIGNING_CERTIFICATE_P12_BASE64
# → Save the password as SIGNING_CERTIFICATE_PASSWORD
```

#### 2. Provisioning Profile (per project)

```bash
# Download from: https://developer.apple.com/account/resources/profiles/list
# Select the "App Store" profile for your bundle ID

base64 -i "match_AppStore_fit_maya.mobileprovision" | pbcopy
# → Paste as PROVISIONING_PROFILE_BASE64
```

#### 3. App Store Connect API Key (one-time, shared)

```bash
# 1. Go to: https://appstoreconnect.apple.com/access/integrations/api
# 2. Click "+" → Name: "CI/CD", Role: "App Manager"
# 3. Download the .p8 file (ONLY downloadable once!)
# 4. Note the Key ID and Issuer ID from the page

base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
# → Paste as ASC_API_KEY_BASE64
# → Copy Key ID as ASC_API_KEY_ID
# → Copy Issuer ID as ASC_API_ISSUER_ID
```

#### 4. Packages Token (one-time, shared)

```bash
# 1. Go to: https://github.com/settings/tokens?type=beta
# 2. "Generate new token" (Fine-grained)
# 3. Token name: "CI Packages Read"
# 4. Repository access → Only select: Fr0zenSide/shiki, Fr0zenSide/kintsugi-ds
# 5. Permissions → Repository: Contents (Read-only)
# 6. Generate → Copy token
# → Paste as PACKAGES_TOKEN on each project that needs shared packages
```

## Onboarding a New Project

### Xcode App (with TestFlight)

```bash
# 1. Copy templates
cp templates/ios-cicd/ci.yml           <project>/.github/workflows/ci.yml
cp templates/ios-cicd/cd-testflight.yml <project>/.github/workflows/cd-testflight.yml

# 2. Search and replace TODO markers
grep -n "TODO" <project>/.github/workflows/*.yml

# 3. Set up GitHub Secrets on the repo
#    (see "How to Generate Each Secret" above)

# 4. Create exportOptions.plist if missing
cat > <project>/exportOptions.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>provisioningProfiles</key>
    <dict>
        <key>YOUR.BUNDLE.ID</key>
        <string>match AppStore YOUR.BUNDLE.ID</string>
    </dict>
</dict>
</plist>
PLIST

# 5. Push and create a PR to develop → CI triggers
# 6. Merge to develop → TestFlight deploys
```

### SPM Package (no deploy)

```bash
# 1. Copy template
cp templates/ios-cicd/spm-ci.yml <project>/.github/workflows/ci.yml

# 2. Adjust branch names in the file
# 3. No secrets needed — just push
```

## Release Process

### TestFlight Beta (automatic)

```
merge PR to develop → CD triggers → TestFlight build available (~15min)
```

### App Store Release (manual)

```
1. Cut release branch:    git checkout -b release/X.Y.Z develop
2. Bump version:          Update project.yml or Info.plist
3. Push:                  git push -u origin release/X.Y.Z
4. CI runs on release branch
5. Product team prepares:
   - App Store screenshots & preview videos
   - Release notes / What's New
   - App Store metadata (keywords, description)
6. Manual TestFlight build from release branch (workflow_dispatch)
7. Final QA on TestFlight release build
8. Submit via App Store Connect (manual)
9. After approval: merge release → main, tag vX.Y.Z
```

## Updating Templates

When you improve a workflow:

1. Update the template in `obyw-one/templates/ios-cicd/`
2. Update this blueprint doc if the change affects the process
3. Propagate to active projects:

```bash
# Diff template vs project
diff templates/ios-cicd/ci.yml ~/path/to/maya/.github/workflows/ci.yml

# Apply changes manually (templates have TODO markers that are project-specific)
```

Future automation: a Shiki command (`/sync-cicd`) that diffs templates against all projects and generates update PRs.

## Runner Environment

| Component | Version | Notes |
|-----------|---------|-------|
| macOS | 15 (Sequoia) | `macos-15` runner |
| Xcode | 16.2 | `sudo xcode-select -switch` |
| Swift | 6.0 | Bundled with Xcode 16.2 |
| Simulator | iPhone 16 / iOS 18.2 | Default for tests |
| xcpretty | latest | Pre-installed on macOS runners |

Update `XCODE_VERSION`, `SIMULATOR`, and `IOS_VERSION` in templates when Apple ships new tools.

## Troubleshooting

### "No matching destination found"
Simulator name/OS combo doesn't exist on the runner. Check available:
```bash
xcrun simctl list devices available
```

### SPM resolution fails with "missing package"
Multi-repo checkout order matters. Shiki sparse checkout must happen **before** the project checkout (otherwise it wipes the project directory).

### Code signing errors
- Verify provisioning profile matches bundle ID
- Check certificate hasn't expired
- Ensure `DEVELOPMENT_TEAM` matches the cert

### "altool: Upload failed"
- API key `.p8` must be at `~/.private_keys/AuthKey_<KEY_ID>.p8`
- Check `ASC_API_KEY_ID` and `ASC_API_ISSUER_ID` match
- Verify the API key has "App Manager" role
