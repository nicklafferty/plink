# Releasing Plink

Tagged releases (`vX.Y.Z`) are built, **Developer ID signed**, **notarized**, and
stapled by GitHub Actions (`.github/workflows/release.yml`), then attached to a
GitHub Release as `Plink.zip`. A notarized download opens with a normal
double-click — no Gatekeeper warning.

## One-time setup

### 1. Export your Developer ID certificate

In **Keychain Access**, find **Developer ID Application: <your name> (TEAMID)**,
right-click → **Export** → save as `cert.p12` and set an export password. Then
base64-encode it for the GitHub secret:

```sh
base64 -i cert.p12 | pbcopy   # now on your clipboard
```

### 2. Create an app-specific password

At **appleid.apple.com → Sign-In and Security → App-Specific Passwords**, create
one (e.g. "plink-notary"). This is used by `notarytool`, not your real password.

### 3. Find your Team ID

```sh
security find-identity -v -p codesigning | grep "Developer ID Application"
# the 10-character code in parentheses is your TEAMID
```

### 4. Add the GitHub Actions secrets

```sh
gh secret set MACOS_CERT_P12        # paste the base64 from step 1
gh secret set MACOS_CERT_PASSWORD   # the .p12 export password
gh secret set APPLE_ID              # your Apple ID email
gh secret set APPLE_TEAM_ID         # the TEAMID from step 3
gh secret set APPLE_APP_PASSWORD    # the app-specific password from step 2
```

## Cutting a release

```sh
git tag v1.0.0
git push origin v1.0.0
```

The workflow runs automatically and publishes the notarized `Plink.zip`.

## Building a notarized app locally (optional)

```sh
# one-time: store notary credentials in your keychain
xcrun notarytool store-credentials plink-notary \
  --apple-id you@example.com --team-id TEAMID --password app-specific-pw

# each build:
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
NOTARY_PROFILE=plink-notary ./notarize.sh
```

Without `SIGN_IDENTITY`, `./build.sh` falls back to ad-hoc signing for everyday
local development.
