import Foundation
import CoreText

enum ResourceLoader {
    static let bundle: Bundle = {
        // .app bundle: Resources dir is inside Contents/Resources/
        let appResources = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/mdreader_mdreader.bundle")
        if let b = Bundle(path: appResources.path) { return b }

        // SPM debug: bundle next to executable
        let spmDebug = Bundle.main.bundleURL
            .appendingPathComponent("mdreader_mdreader.bundle")
        if let b = Bundle(path: spmDebug.path) { return b }

        // Executable sibling
        if let execURL = Bundle.main.executableURL {
            let sibling = execURL.deletingLastPathComponent()
                .appendingPathComponent("mdreader_mdreader.bundle")
            if let b = Bundle(path: sibling.path) { return b }
        }

        return Bundle.module
    }()

    static func url(forResource name: String) -> URL? {
        // Try direct file URL first (handles paths like "Fonts/Lora-Regular.otf")
        let direct = bundle.bundleURL.appendingPathComponent("Resources/\(name)")
        if FileManager.default.fileExists(atPath: direct.path) { return direct }

        // Try Bundle API
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

    // Register fonts immediately when ResourceLoader is first used
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
