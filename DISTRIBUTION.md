# Distributing Sagasu (non–App Store)

This repo builds a macOS menu bar app via a Swift binary wrapped into a `.app` bundle, then packaged into a `.dmg`.

## Build a DMG locally

Prereqs:
- macOS with Xcode Command Line Tools installed (for `swiftc`, `hdiutil`, etc.)

From the repo root:

```bash
./scripts/package_dmg.sh
```

Output:
- The DMG is created at `dist/Sagasu.dmg`.
- The app bundle used to build the DMG is at `dist/Sagasu.app`.

### Installing on another Mac

1. Copy `dist/Sagasu.dmg` to the other Mac.
2. Open the DMG.
3. Drag `Sagasu.app` into `Applications`.
4. Launch it from `Applications`.

Gatekeeper note (unsigned builds):
- If macOS blocks it, right-click `Sagasu.app` → **Open** → **Open**.

## Build the DMG via GitHub Releases

This repo includes a GitHub Actions workflow that builds `dist/Sagasu.dmg` and attaches it to a Release.

### Option A: Tag-based release (recommended)

1. Create a tag:

```bash
git tag v1.0.0
```

2. Push the tag:

```bash
git push origin v1.0.0
```

3. GitHub Actions will run **Build DMG and attach to Release**.
4. The resulting DMG will be downloadable from the GitHub Release page for that tag.

### Option B: Manual workflow run

1. Go to **Actions** → **Build DMG and attach to Release**.
2. Click **Run workflow**.
3. Download the DMG from the workflow’s **Artifacts**.

## Creating an app icon (for the `.app` inside the DMG)

This packaging setup looks for an icon at:
- `asset/AppIcon.icns`

If present, it is copied into the app bundle and used as the app icon.

### Make `AppIcon.icns` from a 1024×1024 PNG

1. Start from a square PNG, ideally 1024×1024, e.g. `asset/AppIcon.png`.
2. Run the commands below from the repo root:

```bash
mkdir -p /tmp/Sagasu.iconset

# Generate the required icon sizes
sips -z 16 16     asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_16x16.png
sips -z 32 32     asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_16x16@2x.png
sips -z 32 32     asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_32x32.png
sips -z 64 64     asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_32x32@2x.png
sips -z 128 128   asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_128x128.png
sips -z 256 256   asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_128x128@2x.png
sips -z 256 256   asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_256x256.png
sips -z 512 512   asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_256x256@2x.png
sips -z 512 512   asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_512x512.png
sips -z 1024 1024 asset/AppIcon.png --out /tmp/Sagasu.iconset/icon_512x512@2x.png

# Convert iconset -> icns
iconutil -c icns /tmp/Sagasu.iconset -o asset/AppIcon.icns
```

3. Re-run the packager:

```bash
./scripts/package_dmg.sh
```

## (Optional) Proper distribution: signing + notarization

For a smoother install experience on other Macs, you’ll typically want:
- A **Developer ID Application** certificate
- `codesign` the `.app`
- Notarize it with `notarytool`

If you want, tell me whether you have an Apple Developer ID set up and I can add a `scripts/notarize.sh` tailored to your setup.