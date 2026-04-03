# Pre-built Vite dist in release tarball

## Problem

The Homebrew formula currently builds the Vite web UI from source during `brew install`. This requires Node.js as a build dependency, slows down installation, and adds a failure point. Users installing a markdown reader shouldn't need a JavaScript toolchain.

## Solution

Build the Vite output in the GitHub Actions release workflow and include it in a custom source tarball uploaded as a release asset. The Homebrew formula downloads this tarball instead of GitHub's auto-generated source archive. One download, everything included, git stays clean.

## Changes

### 1. Release workflow (`.github/workflows/release-please.yml`)

Add a `build-release` job between `release-please` and `update-homebrew`:

- **Trigger**: only when `release_created == true`
- **Runs on**: `ubuntu-latest` (Node.js only needed here)
- **Steps**:
  1. Checkout the tagged code
  2. Setup Node.js, run `npm ci && npx vite build` in `web/`
  3. Create tarball: full source tree + `web/dist/` (named `mdreader-<version>.tar.gz`)
  4. Upload tarball as a release asset via `gh release upload`
  5. Compute SHA256 of the tarball

The `update-homebrew` job changes:
- **Depends on**: `build-release` instead of `release-please` directly
- **SHA256**: computed from our custom tarball, not GitHub's auto-generated source archive
- **Payload**: includes the download URL for our tarball

### 2. `build.sh`

Skip the npm/vite block when `web/dist/` already exists:

```bash
if [ -d "web/dist" ]; then
    echo "Using pre-built web UI..."
elif [ -d "web" ] && [ -f "web/package.json" ]; then
    echo "Building web UI..."
    cd web
    npm ci --silent 2>/dev/null || npm install --silent
    npx vite build 2>&1 | tail -3
    cd ..
fi
```

This preserves the ability to build from source for development while skipping npm entirely when a pre-built dist is present (Homebrew installs, tagged releases).

### 3. Homebrew formula (in `rvanbaalen/homebrew-tap`)

- `url` points to our custom tarball (`mdreader-<version>.tar.gz` release asset) instead of GitHub's auto-generated source archive
- Remove Node.js from `depends_on` build dependencies
- `sha256` matches the custom tarball

The formula template in `.github/workflows/update-formula.yml` needs the URL pattern updated to reference the release asset.

## What doesn't change

- `web/dist/` stays in `.gitignore`, never committed to git
- Local development (`npm run dev`, `npm run build`) unchanged
- The `dev.sh` script still builds Vite from source (it's a dev workflow)
- release-please config unchanged
- The Swift build step in the formula unchanged

## Release flow (before vs after)

**Before:**
1. release-please creates tag
2. Workflow computes SHA256 of GitHub's source tarball
3. Dispatches to Homebrew tap
4. `brew install` downloads source, installs Node.js, runs npm ci + vite build + swift build

**After:**
1. release-please creates tag
2. Workflow checks out tag, builds Vite dist, creates custom tarball, uploads as release asset
3. Workflow computes SHA256 of custom tarball
4. Dispatches to Homebrew tap with custom tarball URL
5. `brew install` downloads custom tarball (includes pre-built dist), runs swift build only
