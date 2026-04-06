# Changelog

## [1.8.0](https://github.com/rvanbaalen/mdreader/compare/v1.7.3...v1.8.0) (2026-04-06)


### Features

* **about:** replace native NSAlert about dialog with in-web AboutDialog ([0c73b83](https://github.com/rvanbaalen/mdreader/commit/0c73b83421143e5383236299372c7d526fccd92d))

## [1.7.3](https://github.com/rvanbaalen/mdreader/compare/v1.7.2...v1.7.3) (2026-04-06)


### Bug Fixes

* **reader:** increase content max-width from 900px to 7xl ([552eff2](https://github.com/rvanbaalen/mdreader/commit/552eff20bca7a24ddb1bfdb32757483e0ea32a65))

## [1.7.2](https://github.com/rvanbaalen/mdreader/compare/v1.7.1...v1.7.2) (2026-04-05)


### Bug Fixes

* **update:** handle brew upgrade failures with error feedback and retry ([228a58a](https://github.com/rvanbaalen/mdreader/commit/228a58add61f8d9837a36bd5b9d8274c5a90679d))

## [1.7.1](https://github.com/rvanbaalen/mdreader/compare/v1.7.0...v1.7.1) (2026-04-04)


### Bug Fixes

* increase min window height and cap recent files list at 5 ([a4b2f2f](https://github.com/rvanbaalen/mdreader/commit/a4b2f2f2b65c8f989bd0b649487e247788a69a51))

## [1.7.0](https://github.com/rvanbaalen/mdreader/compare/v1.6.2...v1.7.0) (2026-04-04)


### Features

* **icon:** redesign app icon with Phosphor BookOpen and dark/light mode ([86e2999](https://github.com/rvanbaalen/mdreader/commit/86e2999a7dc796142210147ac40ef9035b50be40))
* **quicklook:** add Quick Look extension to build pipeline ([8f1cdd5](https://github.com/rvanbaalen/mdreader/commit/8f1cdd5b104fc1267be7b158742a06a8ddd4b257))
* **quicklook:** add Quick Look preview extension provider ([8ac3960](https://github.com/rvanbaalen/mdreader/commit/8ac3960dd1ef24f65e2ece2b8c7f3c16aabf4040))
* **quicklook:** add standalone CSS for Quick Look preview ([a01d1f6](https://github.com/rvanbaalen/mdreader/commit/a01d1f6b27b9b84da3efda0c22c785c6b0db8c7b))
* **quicklook:** native markdown rendering with JSC + NSAttributedString ([20d12dd](https://github.com/rvanbaalen/mdreader/commit/20d12dd338b22694e87f5ad63cb216b29670e1f3))


### Bug Fixes

* **icon:** regenerate doc.icns with alpha transparency ([9f92c35](https://github.com/rvanbaalen/mdreader/commit/9f92c3550bf4f2d687ced7b8ccc38017616dde4d))
* **quicklook:** add missing Foundation import ([41245d4](https://github.com/rvanbaalen/mdreader/commit/41245d4363336f828dce139207e679dbda357fa4))
* **quicklook:** address build.sh review feedback ([5df31a9](https://github.com/rvanbaalen/mdreader/commit/5df31a9fcd142a367cef3f71c4a5f6ee827bb326))
* **quicklook:** improve code quality per review feedback ([87260a3](https://github.com/rvanbaalen/mdreader/commit/87260a330fe0968ad12759e1571e7b112507fdce))
* **quicklook:** restore anchor transition for smooth hover ([7d9c942](https://github.com/rvanbaalen/mdreader/commit/7d9c942128dc5c015c3de2ecece15923fc422ffc))
* read version from release-please manifest instead of stale placeholder ([41fc283](https://github.com/rvanbaalen/mdreader/commit/41fc2834c341d426d0091f1cdacb2b65be801f4b))


### Reverts

* remove Quick Look extension (blocked by macOS 26 sandbox) ([2e440c1](https://github.com/rvanbaalen/mdreader/commit/2e440c1d110af2c8d2ebfcc3710f72d1b558ebe7))

## [1.6.2](https://github.com/rvanbaalen/mdreader/compare/v1.6.1...v1.6.2) (2026-04-03)


### Bug Fixes

* **app:** fall back to bundle path relaunch for dev builds ([9cfd102](https://github.com/rvanbaalen/mdreader/commit/9cfd1025e71825ec7fb85c25c3142f370b198cb2))

## [1.6.1](https://github.com/rvanbaalen/mdreader/compare/v1.6.0...v1.6.1) (2026-04-03)


### Bug Fixes

* **app:** use bundle ID for relaunch so macOS finds new version after brew upgrade ([4bd2094](https://github.com/rvanbaalen/mdreader/commit/4bd2094641f8eae4cb859bdda107ed027fd53e77))
* **content:** tighten list indentation and scale down marker size ([76a3ad6](https://github.com/rvanbaalen/mdreader/commit/76a3ad6257c5c9a972b150be5e06447878d20fb3))

## [1.6.0](https://github.com/rvanbaalen/mdreader/compare/v1.5.2...v1.6.0) (2026-04-03)


### Features

* add global type declarations for window bridge and File.path ([a052d2b](https://github.com/rvanbaalen/mdreader/commit/a052d2bd02bd71e7feeb959b2153bc07c93a1729))
* add logging system for dev and production ([e6e3026](https://github.com/rvanbaalen/mdreader/commit/e6e30265815cc771732d5bc24f48fbabd5b6d797))
* add shadcn button, toggle, tooltip, sonner components ([cf7f8d1](https://github.com/rvanbaalen/mdreader/commit/cf7f8d15d9b05a7152124539bbc890fb8a87d50c))
* CLI flags, edit mode, recents, robust file watching ([0d32aa8](https://github.com/rvanbaalen/mdreader/commit/0d32aa84468bd3fc0f5ae7709b232d63af3daa65))


### Bug Fixes

* dev.sh reliability and cleanup ([dec9fc7](https://github.com/rvanbaalen/mdreader/commit/dec9fc77e40b981ab7afa5a057686d0c70fa0008))

## [1.5.2](https://github.com/rvanbaalen/mdreader/compare/v1.5.1...v1.5.2) (2026-04-02)


### Bug Fixes

* restore allowFileAccessFromFileURLs for WKWebView module loading ([63e649e](https://github.com/rvanbaalen/mdreader/commit/63e649e8516e769648e4e6ae8379a6577500d960))

## [1.5.1](https://github.com/rvanbaalen/mdreader/compare/v1.5.0...v1.5.1) (2026-04-02)


### Bug Fixes

* correct release-please extra-files config and sync version to 1.5.0 ([9a3c118](https://github.com/rvanbaalen/mdreader/commit/9a3c11825e9b2f20c90eb8dc64e399c2fba50e70))

## [1.5.0](https://github.com/rvanbaalen/mdreader/compare/v1.4.0...v1.5.0) (2026-04-02)


### Features

* auto-update check with brew upgrade and post-update changelog ([e393806](https://github.com/rvanbaalen/mdreader/commit/e39380628cc694571de4a1136ea54e680614fd4c))
* update banner UI and opaque titlebar fix ([85adf41](https://github.com/rvanbaalen/mdreader/commit/85adf41079b9e1e0b94b2506d4fe631ec7636a69))

## [1.4.0](https://github.com/rvanbaalen/mdreader/compare/v1.3.0...v1.4.0) (2026-04-02)


### Features

* frosted glass titlebar with native traffic lights ([beae05b](https://github.com/rvanbaalen/mdreader/commit/beae05bc74af8739f6ffdcf0d3d72c2a033a9187))
* image support, syntax-highlighted source view, scroll fixes ([46b3561](https://github.com/rvanbaalen/mdreader/commit/46b35617576e4073409fed97124d3cc27e232c8a))
* multi-window support with WindowController architecture ([65e9101](https://github.com/rvanbaalen/mdreader/commit/65e910173c09107a77ff6cb8c80e291aca1cb9d6))
* native titlebar, custom URL scheme for images, dev workflow ([d0b9b11](https://github.com/rvanbaalen/mdreader/commit/d0b9b11fe55fddde90f8064110b662b8ca253f41))


### Bug Fixes

* use non-deprecated Phosphor icon naming convention ([d2273a3](https://github.com/rvanbaalen/mdreader/commit/d2273a344728a297a7347e64a165031d5d70348f))

## [1.3.0](https://github.com/rvanbaalen/mdreader/compare/v1.2.2...v1.3.0) (2026-04-02)


### Features

* auto-update homebrew formula on release ([772c84a](https://github.com/rvanbaalen/mdreader/commit/772c84a8d578a1ff27b73aefa6dce0154531436d))
* migrate UI to Vite + React + Tailwind v4 ([4031266](https://github.com/rvanbaalen/mdreader/commit/4031266b479459333a80786792f61f04d0172dce))


### Bug Fixes

* update brew install instructions to use consolidated tap ([3fd6ba8](https://github.com/rvanbaalen/mdreader/commit/3fd6ba8d6d08d9c4d86af4dd8a236271c98f8443))

## [1.2.2](https://github.com/rvanbaalen/mdreader/compare/v1.2.1...v1.2.2) (2026-04-02)


### Bug Fixes

* detach CLI process from terminal, update README with screenshot ([10428dd](https://github.com/rvanbaalen/mdreader/commit/10428ddd832bd1c1acc038bb4e2f33964ab6e4f6))

## [1.2.1](https://github.com/rvanbaalen/mdreader/compare/v1.2.0...v1.2.1) (2026-04-02)


### Bug Fixes

* resolve symlinks in ResourceLoader for Homebrew installs ([0ce0ae7](https://github.com/rvanbaalen/mdreader/commit/0ce0ae78aef82d400306c276d96c6c9a3f6a3162))

## [1.2.0](https://github.com/rvanbaalen/mdreader/compare/v1.1.0...v1.2.0) (2026-04-02)


### Features

* full rewrite as borderless WKWebView app ([7afba30](https://github.com/rvanbaalen/mdreader/commit/7afba30a5fb6f079aabb282321cae09d974a312b))

## [1.1.0](https://github.com/rvanbaalen/mdreader/compare/v1.0.3...v1.1.0) (2026-04-01)


### Features

* add release-please for native Swift version ([b890497](https://github.com/rvanbaalen/mdreader/commit/b8904976db2140193cf19b15c10279879d387ada))
* custom icon, about window, auto-updater, default app prompt ([4658f13](https://github.com/rvanbaalen/mdreader/commit/4658f13f0458831b709ee0b8daa5f7d7f5b4e9db))
* rewrite as native macOS app (SwiftUI + WKWebView) ([686761b](https://github.com/rvanbaalen/mdreader/commit/686761b8b2b02a4eb675b92fc5fa2ca29b9965cd))
* ToC as floating panel, content adjusts for both panels ([0de885c](https://github.com/rvanbaalen/mdreader/commit/0de885c8373c792e4a9fded9a1bb1212a4ee421b))


### Bug Fixes

* ToC panel pushes content instead of overlaying ([9f1c980](https://github.com/rvanbaalen/mdreader/commit/9f1c980f4c2b8dd759ac23d57849a9d02c546da1))
