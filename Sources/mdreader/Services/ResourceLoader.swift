import Foundation
import CoreText

enum ResourceLoader {
    static let bundle: Bundle = {
        // Resolve the actual executable path (follows symlinks)
        let execPath: String
        if let execURL = Bundle.main.executableURL {
            execPath = execURL.resolvingSymlinksInPath().path
        } else {
            execPath = CommandLine.arguments[0]
        }
        let execDir = (execPath as NSString).deletingLastPathComponent

        // 1. Running inside .app bundle: executable is at .app/Contents/MacOS/mdreader
        let macosDir = execDir
        let contentsDir = (macosDir as NSString).deletingLastPathComponent
        let appBundle = contentsDir + "/Resources/mdreader_mdreader.bundle"
        if let b = Bundle(path: appBundle) { return b }

        // 2. SPM debug/release: bundle next to executable
        let sibling = execDir + "/mdreader_mdreader.bundle"
        if let b = Bundle(path: sibling) { return b }

        // 3. Homebrew Cellar: walk up from the symlink target to find the .app
        //    e.g. /opt/homebrew/Cellar/mdreader/1.2.0/mdreader.app/Contents/MacOS/mdreader
        //    but also /opt/homebrew/Cellar/mdreader/1.2.0/bin/mdreader (symlink to .app)
        let cellarDir = (execDir as NSString).deletingLastPathComponent // version dir
        let cellarApp = cellarDir + "/mdreader.app/Contents/Resources/mdreader_mdreader.bundle"
        if let b = Bundle(path: cellarApp) { return b }

        // 4. Last resort
        return Bundle.module
    }()

    static func url(forResource name: String) -> URL? {
        let direct = bundle.bundleURL.appendingPathComponent("Resources/\(name)")
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
        return bundle.url(forResource: name, withExtension: nil, subdirectory: "Resources")
            ?? bundle.url(forResource: name, withExtension: nil)
    }

    static func string(forResource name: String) -> String {
        guard let url = url(forResource: name) else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    static var resourcesDirectory: URL {
        bundle.bundleURL.appendingPathComponent("Resources")
    }

    static let fontsRegistered: Bool = {
        let fontDir = resourcesDirectory.appendingPathComponent("Fonts")
        for file in ["Lora-Regular.otf", "Lora-Bold.otf", "Lora-Italic.otf",
                      "Lora-BoldItalic.otf", "IBMPlexMono-Regular.otf", "DMSans-Variable.ttf"] {
            let url = fontDir.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) {
                var err: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
            }
        }
        return true
    }()
}
