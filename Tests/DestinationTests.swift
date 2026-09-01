import Foundation

@main
enum DestinationTests {
    static func main() throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("plink-destination-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let desktop = root.appendingPathComponent("desktop", isDirectory: true)
        let temporary = root.appendingPathComponent("temporary", isDirectory: true)
        let library = root.appendingPathComponent("library", isDirectory: true)
        let downloads = root.appendingPathComponent("downloads", isDirectory: true)
        let pictures = root.appendingPathComponent("pictures", isDirectory: true)
        let custom = root.appendingPathComponent("custom", isDirectory: true)

        for folder in [desktop, temporary, library, downloads, pictures, custom] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let environment = DestinationEnvironment(
            fileManager: fileManager,
            desktop: desktop,
            temporaryDirectory: temporary,
            libraryDirectory: library
        )
        let downloadInput = downloads.appendingPathComponent("photo.heic")

        let defaultOutput = try Destination.outputURL(
            for: downloadInput,
            selection: .nextToOriginals,
            environment: environment
        )
        try expect(
            defaultOutput == downloads.appendingPathComponent("photo.jpg"),
            "default output should be beside the original"
        )

        let customOutput = try Destination.outputURL(
            for: downloadInput,
            selection: .custom(custom),
            environment: environment
        )
        try expect(
            customOutput == custom.appendingPathComponent("photo.jpg"),
            "custom destinations should override the default"
        )

        try Data().write(to: downloads.appendingPathComponent("photo.jpg"))
        let collisionOutput = try Destination.outputURL(
            for: downloadInput,
            selection: .nextToOriginals,
            environment: environment
        )
        try expect(
            collisionOutput == downloads.appendingPathComponent("photo-2.jpg"),
            "existing JPGs should receive a numeric suffix"
        )

        let temporaryInput = temporary.appendingPathComponent("attachment.heic")
        let temporaryOutput = try Destination.outputURL(
            for: temporaryInput,
            selection: .nextToOriginals,
            environment: environment
        )
        try expect(
            temporaryOutput == desktop.appendingPathComponent("attachment.jpg"),
            "temporary sources should fall back to the Desktop"
        )

        let libraryInput = library.appendingPathComponent("message.heic")
        let libraryOutput = try Destination.outputURL(
            for: libraryInput,
            selection: .nextToOriginals,
            environment: environment
        )
        try expect(
            libraryOutput == desktop.appendingPathComponent("message.jpg"),
            "hidden Library sources should fall back to the Desktop"
        )

        let hidden = root.appendingPathComponent(".hidden", isDirectory: true)
        try fileManager.createDirectory(at: hidden, withIntermediateDirectories: true)
        let hiddenOutput = try Destination.outputURL(
            for: hidden.appendingPathComponent("secret.heic"),
            selection: .nextToOriginals,
            environment: environment
        )
        try expect(
            hiddenOutput == desktop.appendingPathComponent("secret.jpg"),
            "hidden source folders should fall back to the Desktop"
        )

        do {
            _ = try Destination.outputURL(
                for: downloadInput,
                selection: .unavailableCustom(root.appendingPathComponent("gone")),
                environment: environment
            )
            throw TestFailure("unavailable custom destinations should fail clearly")
        } catch ConversionError.destinationUnavailable(_) {
            // Expected.
        }

        let besideResult = ConversionResult(
            inputURL: downloadInput,
            outputURL: downloads.appendingPathComponent("photo.jpg"),
            message: nil
        )
        try expect(
            Destination.savedDetail(for: [besideResult]) == "Next to the original",
            "single-file completion copy should describe the source folder"
        )

        let fallbackResult = ConversionResult(
            inputURL: temporaryInput,
            outputURL: desktop.appendingPathComponent("attachment.jpg"),
            message: nil
        )
        try expect(
            Destination.savedDetail(for: [fallbackResult], environment: environment) == "On your Desktop",
            "fallback completion copy should describe the actual output folder"
        )

        let customResult = ConversionResult(
            inputURL: downloadInput,
            outputURL: custom.appendingPathComponent("photo.jpg"),
            message: nil
        )
        try expect(
            Destination.savedDetail(for: [customResult], environment: environment) == "In custom",
            "custom completion copy should describe the selected folder"
        )

        let pictureInput = pictures.appendingPathComponent("second.heic")
        let mixedResult = ConversionResult(
            inputURL: pictureInput,
            outputURL: pictures.appendingPathComponent("second.jpg"),
            message: nil
        )
        try expect(
            Destination.savedDetail(for: [besideResult, mixedResult]) == "Next to each original",
            "mixed source folders should still report next to each original"
        )

        let readOnly = root.appendingPathComponent("read-only", isDirectory: true)
        try fileManager.createDirectory(at: readOnly, withIntermediateDirectories: true)
        let readOnlyInput = readOnly.appendingPathComponent("locked.heic")
        let appIcon = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("App/AppIcon.png")
        try Data(contentsOf: appIcon).write(to: readOnlyInput)
        try fileManager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly.path)
        defer { try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path) }

        let readOnlyResult = HEICConverter().convertFile(
            readOnlyInput,
            destination: .nextToOriginals,
            environment: environment
        )
        try expect(
            readOnlyResult.outputURL == desktop.appendingPathComponent("locked.jpg"),
            "failed source-folder writes should retry on the Desktop"
        )

        print("Destination tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}

struct TestFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
