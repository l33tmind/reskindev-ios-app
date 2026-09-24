# ReskinDev Deep Linking — Deployment Guide

This folder contains all server files needed for deep linking on **reskindev.com**.

---

## File Structure

```
server_files/
├── gig.php                          ← Upload to reskindev.com/gig/index.php
├── .well-known/
│   ├── assetlinks.json              ← Android App Links verification
│   └── apple-app-site-association  ← iOS Universal Links verification
└── README.md                        ← This file
```

---

## Step 1 — Upload gig.php

Upload `gig.php` to your server as:

```
/public_html/gig/index.php
```

> The file must live at the path `gig/index.php` so that the `.htaccess` rewrite rule below works correctly.

---

## Step 2 — Add .htaccess Rewrite Rule

In your root `.htaccess` (usually `/public_html/.htaccess`), add the following block:

```apache
# ── ReskinDev Gig Deep Links ──────────────────────────────────────────────────
<IfModule mod_rewrite.c>
    RewriteEngine On

    # Route /gig/{id} → /gig/index.php
    RewriteRule ^gig/([^/]+)/?$ /gig/index.php [L,QSA]
</IfModule>
```

If you already have a `RewriteEngine On` directive in your `.htaccess`, just add the `RewriteRule` line inside the existing `<IfModule mod_rewrite.c>` block.

**Verify it works:**
```
https://reskindev.com/gig/TEST123
```
This should load the PHP page (or a 404 if the gig doesn't exist in Firestore).

---

## Step 3 — Upload .well-known Files

Upload both files inside the `.well-known/` folder to:

```
/public_html/.well-known/assetlinks.json
/public_html/.well-known/apple-app-site-association
```

> ⚠️ `apple-app-site-association` must have **no file extension**. Do not rename it to `.json`.

Make sure the `.well-known/` directory is publicly accessible (some hosts block dot-folders by default). If needed, add to `.htaccess`:

```apache
# Allow .well-known directory
<IfModule mod_rewrite.c>
    RewriteRule ^\.well-known/ - [L]
</IfModule>
```

Or with a separate `.well-known/.htaccess`:
```apache
Options -Indexes
Allow from all
```

**Verify Android:**
```
https://reskindev.com/.well-known/assetlinks.json
```
Should return the JSON with your SHA-256 fingerprint.

**Verify iOS:**
```
https://reskindev.com/.well-known/apple-app-site-association
```
Should return the JSON with your Team ID (after Step 4).

You can also use Google's tester:
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://reskindev.com&relation=delegate_permission/common.handle_all_urls

---

## Step 4 — Replace TEAM_ID in apple-app-site-association

The file currently contains `TEAM_ID` as a placeholder. You must replace it with your **10-character Apple Developer Team ID**.

### How to find your Team ID:

**Option A — Xcode:**
1. Open your project in Xcode
2. Click on your project in the Navigator
3. Select your Target → **Signing & Capabilities**
4. Your Team ID is shown next to the Team dropdown (e.g., `AB12CD34EF`)

**Option B — Apple Developer Portal:**
1. Go to https://developer.apple.com/account
2. Log in and click **Membership** in the left sidebar
3. Your Team ID is listed under **Membership Information**

**After finding it**, open `.well-known/apple-app-site-association` and replace both occurrences of `TEAM_ID`:

```json
"appIDs": ["AB12CD34EF.com.reskindevdotcom.reskindev"]
```

and

```json
"apps": ["AB12CD34EF.com.reskindevdotcom.reskindev"]
```

Then re-upload the file to your server.

---

## Step 5 — Enable Firestore Public Read for `services` Collection

The PHP file reads gig data from Firestore using the REST API. You need to allow public read access to the `services` collection.

### In Firebase Console:

1. Go to https://console.firebase.google.com/project/reskindev-769d3/firestore/rules
2. Update the security rules to allow public read on `services`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Allow public read access to the services (gigs) collection
    match /services/{gigId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    // Keep all other collections private (authenticated only)
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

3. Click **Publish**

> ⚠️ This only exposes the `services` collection for read access. All writes still require authentication.

---

## Step 6 — Enable Associated Domains in Xcode (iOS)

For iOS Universal Links to work, you must add the Associated Domains capability to your app:

1. In Xcode, select your Target → **Signing & Capabilities**
2. Click **+ Capability** → search for **Associated Domains**
3. Add the domain:
   ```
   applinks:reskindev.com
   ```
4. Build & submit a new version to TestFlight/App Store for the entitlement to activate

---

## Step 7 — Enable App Links in Android (AndroidManifest.xml)

In your `AndroidManifest.xml`, make sure your main/gig Activity has an intent-filter like:

```xml
<activity android:name=".GigActivity" ...>
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data
            android:scheme="https"
            android:host="reskindev.com"
            android:pathPrefix="/gig/"/>
    </intent-filter>
    <!-- Custom scheme fallback -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="reskindev" android:host="gig"/>
    </intent-filter>
</activity>
```

> `android:autoVerify="true"` triggers verification against `assetlinks.json` on install.

---

## Configuration Reference

| Setting | Value |
|---|---|
| Firebase Project ID | `reskindev-769d3` |
| Firebase Web API Key | `AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo` |
| Firestore Collection | `services` |
| Android Package | `com.reskindevdotcom.reskindev` |
| iOS Bundle ID | `com.reskindevdotcom.reskindev` |
| App Deep Link Scheme | `reskindev://gig/{id}` |
| Universal Link Pattern | `https://reskindev.com/gig/{id}` |
| SHA-256 Cert Fingerprint | `6F:62:30:6C:2F:6C:9B:75:09:82:0A:55:AA:44:60:33:...` |

---

## Testing Deep Links

**Android (via ADB):**
```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://reskindev.com/gig/TEST123" \
  com.reskindevdotcom.reskindev
```

**iOS (via xcrun):**
```bash
xcrun simctl openurl booted "https://reskindev.com/gig/TEST123"
```

**Custom scheme:**
```bash
# Android
adb shell am start -a android.intent.action.VIEW \
  -d "reskindev://gig/TEST123" com.reskindevdotcom.reskindev

# iOS simulator
xcrun simctl openurl booted "reskindev://gig/TEST123"
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Page returns 404 | Check `.htaccess` rewrite rule is active; confirm `gig/index.php` exists |
| Firestore returns error 403 | Update Firestore security rules (Step 5) |
| Android app doesn't open | Verify `assetlinks.json` is served at correct URL with correct SHA-256 |
| iOS app doesn't open | Confirm Team ID is set, Associated Domains capability added, and AASA file is reachable |
| Image not showing in OG preview | Ensure `imageUrl` field in Firestore is a public HTTPS URL |
