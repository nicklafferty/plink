import AppKit
import Darwin
import ImageIO
import UniformTypeIdentifiers

@main
enum PlinkMain {
    static func main() {
        if CommandLine.arguments.dropFirst().first == "--convert" {
            exit(Int32(CommandLineRunner.run(arguments: CommandLine.arguments)))
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        retainedAppDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

private var retainedAppDelegate: AppDelegate?

enum CommandLineRunner {
    static func run(arguments: [String]) -> Int {
        guard arguments.count == 3 else {
            fputs("Usage: Plink --convert /path/to/file.heic\n", stderr)
            return 64
        }

        let inputURL = URL(fileURLWithPath: arguments[2])
        let result = HEICConverter().convertFile(inputURL)

        guard let outputURL = result.outputURL else {
            fputs((result.message ?? "Conversion failed") + "\n", stderr)
            return 1
        }

        print(outputURL.path)
        return 0
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let dropController = DropViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        dropController.chooseFilesHandler = { [weak self] in
            self?.chooseFiles()
        }

        dropController.quitHandler = {
            NSApp.terminate(nil)
        }

        dropController.chooseDestinationHandler = { [weak self] in
            self?.chooseDestination()
        }

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 360, height: 300)
        popover.contentViewController = dropController

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = menuBarImage()
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "Plink"
        }

        // Surface the popover on first launch so the menu bar icon is easy to find.
        if !UserDefaults.standard.bool(forKey: "PlinkDidIntro") {
            UserDefaults.standard.set(true, forKey: "PlinkDidIntro")
            DispatchQueue.main.async { [weak self] in self?.showPopover() }
        }
    }

    // Re-opening the app (e.g. double-clicking it again) reveals the popover,
    // since a menu-bar-only app has no window to bring forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showPopover()
        dropController.convert(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }

        guard urls.contains(where: HEICConverter.isSupportedFile) else {
            sender.reply(toOpenOrPrint: .failure)
            showPopover()
            dropController.convert(urls)
            return
        }

        sender.reply(toOpenOrPrint: .success)
        showPopover()
        dropController.convert(urls)
    }

    @objc(convertHEICService:userData:error:)
    func convertHEICService(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = fileURLs(from: pasteboard)
        let files = urls.filter(HEICConverter.isSupportedFile)

        guard !files.isEmpty else {
            error.pointee = "Choose HEIC or HEIF files." as NSString
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.showPopover()
            self?.dropController.convert(files)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "heic"),
            UTType(filenameExtension: "heif")
        ].compactMap { $0 }

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.dropController.convert(panel.urls)
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Choose where converted JPGs are saved"
        panel.directoryURL = Destination.folder

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Destination.set(url)
            self?.dropController.destinationChanged()
        }
    }
}

private func menuBarImage() -> NSImage? {
    dropletImage(side: 18)  // 18×18pt is the sweet spot for a status item
}

/// The "Sheen" droplet, drawn as a vector at any size and returned as a template
/// image (so it tints automatically). Shared by the menu bar and the in-app header.
func dropletImage(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
        // Path authored on an 18-unit grid (y-down); scale to the requested side.
        let transform = NSAffineTransform()
        transform.scale(by: side / 18.0)
        transform.concat()

        let p = NSBezierPath()
        p.windingRule = .evenOdd

        // --- droplet silhouette ---
        p.move(to: NSPoint(x: 9, y: 1.8))
        p.curve(to: NSPoint(x: 14.2, y: 11.4),
                controlPoint1: NSPoint(x: 9, y: 1.8),
                controlPoint2: NSPoint(x: 14.2, y: 7.6))
        p.curve(to: NSPoint(x: 9, y: 16.6),
                controlPoint1: NSPoint(x: 14.2, y: 14.27),
                controlPoint2: NSPoint(x: 11.87, y: 16.6))
        p.curve(to: NSPoint(x: 3.8, y: 11.4),
                controlPoint1: NSPoint(x: 6.13, y: 16.6),
                controlPoint2: NSPoint(x: 3.8, y: 14.27))
        p.curve(to: NSPoint(x: 9, y: 1.8),
                controlPoint1: NSPoint(x: 3.8, y: 7.6),
                controlPoint2: NSPoint(x: 9, y: 1.8))
        p.close()

        // --- catchlight (knocked out by even-odd) ---
        p.move(to: NSPoint(x: 7.2, y: 8.3))
        p.curve(to: NSPoint(x: 5.9, y: 12.1),
                controlPoint1: NSPoint(x: 5.9, y: 9.1),
                controlPoint2: NSPoint(x: 5.3, y: 10.7))
        p.curve(to: NSPoint(x: 7.6, y: 8.6),
                controlPoint1: NSPoint(x: 5.6, y: 10.5),
                controlPoint2: NSPoint(x: 6.2, y: 9.2))
        p.close()

        NSColor.black.setFill()   // ignored once isTemplate = true
        p.fill()
        return true
    }

    image.isTemplate = true
    return image
}

private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
    let urls = objects.compactMap { object -> URL? in
        if let url = object as? URL {
            return url
        }

        if let nsURL = object as? NSURL {
            return nsURL as URL
        }

        return nil
    }

    if !urls.isEmpty {
        return urls
    }

    let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    let filenames = pasteboard.propertyList(forType: filenamesType) as? [String] ?? []
    return filenames.map { URL(fileURLWithPath: $0) }
}

final class DropViewController: NSViewController {
    var chooseFilesHandler: (() -> Void)?
    var quitHandler: (() -> Void)?
    var chooseDestinationHandler: (() -> Void)?

    private let dropView = DropView()
    private let converter = HEICConverter()
    private var lastOutputs: [URL] = []
    private var isConverting = false

    override func loadView() {
        // NSPopover sizes itself to the content view's Auto Layout fitting size and
        // forces translatesAutoresizingMaskIntoConstraints = true on it — so a size
        // constraint on the content view itself conflicts and the width collapses.
        // Fix: the content view is a plain container; DropView lives inside it with a
        // required 360×300 size constraint. The container's fitting size is then a
        // solid 360×300 and the popover renders at full width.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 300))
        dropView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dropView)
        NSLayoutConstraint.activate([
            dropView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dropView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dropView.topAnchor.constraint(equalTo: container.topAnchor),
            dropView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            dropView.widthAnchor.constraint(equalToConstant: 360),
            dropView.heightAnchor.constraint(equalToConstant: 300)
        ])
        view = container
        preferredContentSize = NSSize(width: 360, height: 300)

        dropView.onFilesDropped = { [weak self] urls in
            self?.convert(urls)
        }

        dropView.onChooseFiles = { [weak self] in
            self?.chooseFilesHandler?()
        }

        dropView.onReveal = { [weak self] in
            self?.revealLastOutputs()
        }

        dropView.onQuit = { [weak self] in
            self?.quitHandler?()
        }

        dropView.onChooseDestination = { [weak self] in
            self?.chooseDestinationHandler?()
        }
    }

    /// Called after the user picks a new destination folder.
    func destinationChanged() {
        dropView.updateDestination()
    }

    func convert(_ urls: [URL]) {
        guard !isConverting else {
            dropView.showMessage(title: "Still converting", detail: "Drop the next batch when this one finishes.")
            return
        }

        let files = urls.filter(HEICConverter.isSupportedFile)

        guard !files.isEmpty else {
            dropView.showMessage(title: "Not a HEIC file", detail: "Only .heic and .heif files can be converted.")
            return
        }

        isConverting = true
        lastOutputs = []
        dropView.setConverting(completed: 0, total: files.count, currentFile: files.first?.lastPathComponent)

        converter.convert(files) { [weak self] completed, total, currentFile in
            DispatchQueue.main.async {
                self?.dropView.setConverting(completed: completed, total: total, currentFile: currentFile)
            }
        } completion: { [weak self] results in
            DispatchQueue.main.async {
                self?.finish(results)
            }
        }
    }

    private func finish(_ results: [ConversionResult]) {
        isConverting = false

        let successes = results.compactMap(\.outputURL)
        let failures = results.filter { $0.outputURL == nil }
        lastOutputs = successes

        if successes.isEmpty {
            dropView.showError(title: "Couldn’t convert", detail: failures.first?.message ?? "No JPGs were created.")
            return
        }

        let noun = successes.count == 1 ? "JPG" : "JPGs"
        if failures.isEmpty {
            dropView.showDone(title: "\(successes.count) \(noun) saved", detail: "On your Desktop")
        } else {
            dropView.showDone(
                title: "\(successes.count) \(noun) saved",
                detail: "\(failures.count) couldn’t be converted"
            )
        }
    }

    private func revealLastOutputs() {
        guard !lastOutputs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(lastOutputs)
    }
}

// MARK: - Palette

private extension NSColor {
    /// Popover surface — graphite, matches the icon.
    static let mnSurface = NSColor(srgbRed: 0x1c/255, green: 0x1c/255, blue: 0x1e/255, alpha: 1)
    static func mnWhite(_ a: CGFloat) -> NSColor { NSColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
    /// Success green (lifted brighter for a dark surface — ~oklch(80% .17 150)).
    static let mnGreen = NSColor(srgbRed: 0x57/255, green: 0xd9/255, blue: 0x8a/255, alpha: 1)
    /// Error red for a dark surface (~oklch(72% .19 25)).
    static let mnRed = NSColor(srgbRed: 0xf2/255, green: 0x6d/255, blue: 0x6d/255, alpha: 1)
}

// MARK: - Drop zone (CAShapeLayer dashed/solid border)

final class DropZoneView: NSView {
    enum Mode { case dashed, solid, none }

    private let borderLayer = CAShapeLayer()
    var mode: Mode = .dashed { didSet { refresh() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineCap = .round
        layer?.addSublayer(borderLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        borderLayer.frame = bounds
        let inset: CGFloat = 1
        let rect = bounds.insetBy(dx: inset, dy: inset)
        borderLayer.path = CGPath(roundedRect: rect, cornerWidth: 11, cornerHeight: 11, transform: nil)
        refresh()
    }

    private func refresh() {
        switch mode {
        case .dashed:
            layer?.backgroundColor = NSColor.mnWhite(0.02).cgColor
            borderLayer.strokeColor = NSColor.mnWhite(0.20).cgColor
            borderLayer.lineWidth = 1.5
            borderLayer.lineDashPattern = [6, 6]
        case .solid:
            layer?.backgroundColor = NSColor.mnWhite(0.07).cgColor
            borderLayer.strokeColor = NSColor.white.cgColor
            borderLayer.lineWidth = 1.5
            borderLayer.lineDashPattern = nil
        case .none:
            layer?.backgroundColor = NSColor.clear.cgColor
            borderLayer.strokeColor = NSColor.clear.cgColor
            borderLayer.lineDashPattern = nil
        }
    }
}

// MARK: - Determinate progress bar (track + fill, tintable)

final class ProgressBar: NSView {
    private let track = CALayer()
    private let fill = CALayer()
    /// 0…1
    var fraction: CGFloat = 0 { didSet { needsLayout = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        track.backgroundColor = NSColor.mnWhite(0.12).cgColor
        fill.backgroundColor = NSColor.white.cgColor
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let h = bounds.height, radius = h / 2
        track.frame = bounds
        track.cornerRadius = radius
        let w = max(h, bounds.width * max(0, min(1, fraction)))
        fill.frame = NSRect(x: 0, y: 0, width: w, height: h)
        fill.cornerRadius = radius
        CATransaction.begin(); CATransaction.setDisableActions(true)
        CATransaction.commit()
    }
}

// MARK: - DropView

final class DropView: NSView {
    var onFilesDropped: (([URL]) -> Void)?
    var onChooseFiles: (() -> Void)?
    var onReveal: (() -> Void)?
    var onQuit: (() -> Void)?
    var onChooseDestination: (() -> Void)?

    // Header
    private let titleLabel = NSTextField(labelWithString: "Plink")
    private let headerSpinner = NSProgressIndicator()
    private let destinationButton = GhostIconButton()
    private let quitButton = GhostIconButton()

    // True while the footer is showing the "Saves to …" destination text
    // (i.e. not a done/error message), so we know when to refresh it live.
    private var footerShowsDestination = true

    // Body
    private let dropZone = DropZoneView()
    private let zoneIcon = NSImageView()
    private let zoneTitle = NSTextField(labelWithString: "Drop HEIC files")
    private let zoneSub = NSTextField(labelWithString: "or click to choose")

    // Converting body
    private let convStack = NSStackView()
    private let convTitle = NSTextField(labelWithString: "Converting…")
    private let convCount = NSTextField(labelWithString: "")
    private let convBar = ProgressBar()
    private let convFile = NSTextField(labelWithString: "")

    // Footer
    private let footerLabel = NSTextField(labelWithString: "Saves to your Desktop")
    fileprivate let revealButton = TextLinkButton(title: "Reveal")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        build()
        applyIdle()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
        build()
        applyIdle()
    }

    override var isFlipped: Bool { true }

    // MARK: Build

    private func build() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.mnSurface.cgColor
        layer?.cornerRadius = 14
        layer?.masksToBounds = true

        // ---------- Header ----------
        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 6
        chip.layer?.backgroundColor = NSColor.mnWhite(0.10).cgColor
        chip.translatesAutoresizingMaskIntoConstraints = false
        let chipIcon = NSImageView()
        chipIcon.image = dropletImage(side: 13)
        chipIcon.contentTintColor = .white
        chipIcon.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(chipIcon)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white

        headerSpinner.style = .spinning
        headerSpinner.controlSize = .small
        headerSpinner.isDisplayedWhenStopped = false
        headerSpinner.appearance = NSAppearance(named: .darkAqua)
        headerSpinner.isHidden = true
        headerSpinner.translatesAutoresizingMaskIntoConstraints = false

        quitButton.configure(symbol: "xmark", point: 12, color: .mnWhite(0.45))
        quitButton.toolTip = "Quit Plink"
        quitButton.onClick = { [weak self] in self?.onQuit?() }

        destinationButton.configure(symbol: "folder", point: 12, color: .mnWhite(0.45))
        destinationButton.toolTip = "Change where JPGs are saved"
        destinationButton.onClick = { [weak self] in self?.onChooseDestination?() }

        let titleRow = NSStackView(views: [chip, titleLabel])
        titleRow.spacing = 9
        titleRow.alignment = .centerY
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleRow)
        header.addSubview(headerSpinner)
        header.addSubview(destinationButton)
        header.addSubview(quitButton)
        let divider1 = hairline()

        // ---------- Body: drop zone ----------
        zoneIcon.contentTintColor = .mnWhite(0.45)
        zoneIcon.translatesAutoresizingMaskIntoConstraints = false

        for (lbl, size, weight, color) in [
            (zoneTitle, CGFloat(15), NSFont.Weight.semibold, NSColor.white),
            (zoneSub, CGFloat(13), NSFont.Weight.regular, NSColor.mnWhite(0.55))
        ] {
            lbl.font = .systemFont(ofSize: size, weight: weight)
            lbl.textColor = color
            lbl.alignment = .center
            lbl.lineBreakMode = .byTruncatingMiddle
        }

        let zoneText = NSStackView(views: [zoneTitle, zoneSub])
        zoneText.orientation = .vertical
        zoneText.spacing = 2
        zoneText.alignment = .centerX

        let zoneContent = NSStackView(views: [zoneIcon, zoneText])
        zoneContent.orientation = .vertical
        zoneContent.spacing = 11
        zoneContent.alignment = .centerX
        zoneContent.translatesAutoresizingMaskIntoConstraints = false

        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.addSubview(zoneContent)
        let click = NSClickGestureRecognizer(target: self, action: #selector(zoneClicked))
        dropZone.addGestureRecognizer(click)

        // ---------- Body: converting ----------
        convTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        convTitle.textColor = .white
        convCount.font = .systemFont(ofSize: 12, weight: .medium)
        convCount.textColor = .mnWhite(0.5)
        convCount.alignment = .right
        let convTop = NSStackView(views: [convTitle, NSView(), convCount])
        convTop.alignment = .firstBaseline
        convTop.translatesAutoresizingMaskIntoConstraints = false

        convBar.translatesAutoresizingMaskIntoConstraints = false
        convBar.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let fileIcon = NSImageView()
        fileIcon.image = symbol("photo", point: 12, weight: .regular)
        fileIcon.contentTintColor = .mnWhite(0.5)
        convFile.font = .systemFont(ofSize: 12, weight: .regular)
        convFile.textColor = .mnWhite(0.55)
        convFile.lineBreakMode = .byTruncatingMiddle
        let fileRow = NSStackView(views: [fileIcon, convFile])
        fileRow.spacing = 7
        fileRow.alignment = .centerY

        convStack.orientation = .vertical
        convStack.spacing = 16
        convStack.alignment = .leading
        convStack.translatesAutoresizingMaskIntoConstraints = false
        convStack.addArrangedSubview(convTop)
        convStack.addArrangedSubview(convBar)
        convStack.addArrangedSubview(fileRow)
        convTop.widthAnchor.constraint(equalTo: convStack.widthAnchor).isActive = true
        convBar.widthAnchor.constraint(equalTo: convStack.widthAnchor).isActive = true
        convStack.isHidden = true

        let body = NSView()
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(dropZone)
        body.addSubview(convStack)

        // ---------- Footer ----------
        let divider2 = hairline()
        footerLabel.font = .systemFont(ofSize: 12, weight: .regular)
        footerLabel.textColor = .mnWhite(0.4)
        revealButton.onClick = { [weak self] in self?.onReveal?() }
        revealButton.isEnabled = false
        revealButton.setContentHuggingPriority(.required, for: .horizontal)
        revealButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        footerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [footerLabel, NSView(), revealButton])
        footer.alignment = .centerY
        footer.translatesAutoresizingMaskIntoConstraints = false

        // ---------- Assemble ----------
        for v in [header, divider1, body, divider2, footer] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            chip.widthAnchor.constraint(equalToConstant: 22),
            chip.heightAnchor.constraint(equalToConstant: 22),
            chipIcon.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            chipIcon.centerYAnchor.constraint(equalTo: chip.centerYAnchor),

            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),
            titleRow.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 15),
            titleRow.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            quitButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -11),
            quitButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            quitButton.widthAnchor.constraint(equalToConstant: 26),
            quitButton.heightAnchor.constraint(equalToConstant: 26),
            destinationButton.trailingAnchor.constraint(equalTo: quitButton.leadingAnchor, constant: -2),
            destinationButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            destinationButton.widthAnchor.constraint(equalToConstant: 26),
            destinationButton.heightAnchor.constraint(equalToConstant: 26),
            headerSpinner.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerSpinner.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            divider1.topAnchor.constraint(equalTo: header.bottomAnchor),
            divider1.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider1.trailingAnchor.constraint(equalTo: trailingAnchor),

            body.topAnchor.constraint(equalTo: divider1.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.bottomAnchor.constraint(equalTo: divider2.topAnchor),

            dropZone.topAnchor.constraint(equalTo: body.topAnchor, constant: 14),
            dropZone.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 14),
            dropZone.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -14),
            dropZone.bottomAnchor.constraint(equalTo: body.bottomAnchor, constant: -14),
            dropZone.heightAnchor.constraint(greaterThanOrEqualToConstant: 142),

            zoneContent.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            zoneContent.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),

            convStack.leadingAnchor.constraint(equalTo: body.leadingAnchor, constant: 18),
            convStack.trailingAnchor.constraint(equalTo: body.trailingAnchor, constant: -18),
            convStack.centerYAnchor.constraint(equalTo: body.centerYAnchor),

            divider2.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider2.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider2.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    // MARK: State entry points (called by DropViewController)

    func setConverting(completed: Int, total: Int, currentFile: String?) {
        revealButton.isEnabled = false
        footerShowsDestination = true
        showConvertingBody(true)
        headerSpinner.isHidden = false
        headerSpinner.startAnimation(nil)
        quitButton.isHidden = true
        destinationButton.isHidden = true
        convTitle.stringValue = "Converting…"
        convCount.stringValue = "\(completed) of \(total)"
        convBar.fraction = total > 0 ? CGFloat(completed) / CGFloat(total) : 0
        convFile.stringValue = currentFile ?? "Reading files…"
    }

    func showDone(title: String, detail: String) {
        stopSpinner()
        showConvertingBody(false)
        dropZone.mode = .none
        zoneIcon.image = symbol("checkmark.circle", point: 34, weight: .regular)
        zoneIcon.contentTintColor = .mnGreen
        zoneTitle.stringValue = title
        zoneSub.stringValue = detail
        footerShowsDestination = false
        footerLabel.stringValue = "Ready for the next batch"
        revealButton.isEnabled = true
    }

    func showError(title: String, detail: String) {
        stopSpinner()
        showConvertingBody(false)
        dropZone.mode = .none
        zoneIcon.image = symbol("xmark.circle", point: 34, weight: .regular)
        zoneIcon.contentTintColor = .mnRed
        zoneTitle.stringValue = title
        zoneSub.stringValue = detail
        footerShowsDestination = false
        footerLabel.stringValue = "Try another file"
        revealButton.isEnabled = false
    }

    func showMessage(title: String, detail: String) {
        stopSpinner()
        applyIdle()
        zoneTitle.stringValue = title
        zoneSub.stringValue = detail
    }

    // MARK: Idle / drag visuals

    private func applyIdle() {
        showConvertingBody(false)
        dropZone.mode = .dashed
        zoneIcon.image = symbol("photo", point: 30, weight: .regular)
        zoneIcon.contentTintColor = .mnWhite(0.45)
        zoneTitle.stringValue = "Drop HEIC files"
        zoneSub.stringValue = "or click to choose"
        footerShowsDestination = true
        footerLabel.stringValue = Destination.savesToText
    }

    /// Refresh the footer's destination text after the user picks a new folder.
    func updateDestination() {
        if footerShowsDestination {
            footerLabel.stringValue = Destination.savesToText
        }
    }

    private func applyDrag(fileCount: Int) {
        showConvertingBody(false)
        dropZone.mode = .solid
        zoneIcon.image = symbol("arrow.up.doc", point: 30, weight: .regular)
        zoneIcon.contentTintColor = .white
        zoneTitle.stringValue = "Release to convert"
        zoneSub.stringValue = fileCount == 1 ? "1 HEIC file" : "\(fileCount) HEIC files"
    }

    private func showConvertingBody(_ show: Bool) {
        convStack.isHidden = !show
        dropZone.isHidden = show
    }

    private func stopSpinner() {
        headerSpinner.stopAnimation(nil)
        headerSpinner.isHidden = true
        quitButton.isHidden = false
        destinationButton.isHidden = false
    }

    @objc private func zoneClicked() { onChooseFiles?() }

    // MARK: Drag & drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let files = supportedFiles(sender)
        guard !files.isEmpty else { return [] }
        applyDrag(fileCount: files.count)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { applyIdle() }
    override func draggingEnded(_ sender: NSDraggingInfo) { /* handled by perform */ }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { applyIdle(); return false }
        onFilesDropped?(urls)
        return true
    }

    private func supportedFiles(_ sender: NSDraggingInfo) -> [URL] {
        fileURLs(from: sender.draggingPasteboard).filter(HEICConverter.isSupportedFile)
    }

    // MARK: Helpers

    private func hairline() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.mnWhite(0.07).cgColor
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func symbol(_ name: String, point: CGFloat, weight: NSFont.Weight) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: point, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: name)?
            .withSymbolConfiguration(cfg)
    }
}

// MARK: - Ghost icon button (header X)

final class GhostIconButton: NSView {
    var onClick: (() -> Void)?
    private let iconView = NSImageView()

    override init(frame frameRect: NSRect) { super.init(frame: frameRect); common() }
    required init?(coder: NSCoder) { super.init(coder: coder); common() }

    private func common() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleNone
        addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(symbol: String, point: CGFloat, color: NSColor) {
        let cfg = NSImage.SymbolConfiguration(pointSize: point, weight: .semibold)
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)?.withSymbolConfiguration(cfg)
        img?.isTemplate = true
        iconView.image = img
        iconView.contentTintColor = color
    }

    // Whole control area is the click target (so the inner image view never
    // swallows the click).
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = NSColor.mnWhite(0.08).cgColor }
    override func mouseExited(with event: NSEvent) { layer?.backgroundColor = NSColor.clear.cgColor }
    override func mouseDown(with event: NSEvent) { /* retain event to receive mouseUp */ }
    override func mouseUp(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}

// MARK: - Text link button (footer "Reveal" / "Try again")

final class TextLinkButton: NSButton {
    var onClick: (() -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        (cell as? NSButtonCell)?.wraps = false
        lineBreakMode = .byClipping
        target = self
        action = #selector(fire)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isEnabled: Bool { didSet { refresh() } }

    override var intrinsicContentSize: NSSize {
        let size = attributedTitle.size()
        return NSSize(width: ceil(size.width) + 2, height: ceil(size.height))
    }

    private func refresh() {
        let color: NSColor = isEnabled ? .white : .mnWhite(0.28)
        attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
        invalidateIntrinsicContentSize()
    }

    @objc private func fire() { if isEnabled { onClick?() } }
}

/// Where converted JPGs are saved. Persists across launches (and is shared with
/// the `--convert` CLI / Finder Quick Action, since they read the same defaults).
enum Destination {
    private static let defaultsKey = "PlinkDestinationPath"

    static var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    /// The chosen folder, falling back to the Desktop if unset or missing.
    static var folder: URL {
        if let path = UserDefaults.standard.string(forKey: defaultsKey), !path.isEmpty {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return desktop
    }

    static func set(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
    }

    static var isDesktop: Bool {
        folder.standardizedFileURL == desktop.standardizedFileURL
    }

    /// Footer phrasing: "Saves to your Desktop" or "Saves to <Folder>".
    static var savesToText: String {
        isDesktop ? "Saves to your Desktop" : "Saves to \(folder.lastPathComponent)"
    }
}

struct ConversionResult {
    let inputURL: URL
    let outputURL: URL?
    let message: String?
}

final class HEICConverter {
    private let quality: CGFloat = 0.92

    static func isSupportedFile(_ url: URL) -> Bool {
        ["heic", "heif"].contains(url.pathExtension.lowercased())
    }

    func convert(
        _ urls: [URL],
        progress: @escaping (_ completed: Int, _ total: Int, _ currentFile: String?) -> Void,
        completion: @escaping ([ConversionResult]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [ConversionResult] = []

            for (index, url) in urls.enumerated() {
                let result = self.convertFile(url)
                results.append(result)
                progress(index + 1, urls.count, url.lastPathComponent)
            }

            completion(results)
        }
    }

    func convertFile(_ inputURL: URL) -> ConversionResult {
        do {
            let outputURL = try outputURL(for: inputURL)
            try writeJPEG(from: inputURL, to: outputURL)
            return ConversionResult(inputURL: inputURL, outputURL: outputURL, message: nil)
        } catch {
            return ConversionResult(inputURL: inputURL, outputURL: nil, message: error.localizedDescription)
        }
    }

    private func writeJPEG(from inputURL: URL, to outputURL: URL) throws {
        guard Self.isSupportedFile(inputURL) else {
            throw ConversionError.unsupported(inputURL.lastPathComponent)
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, sourceOptions) else {
            throw ConversionError.cannotRead(inputURL.lastPathComponent)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.cannotCreate(outputURL.lastPathComponent)
        }

        let imageOptions = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, imageOptions) else {
            throw ConversionError.cannotRead(inputURL.lastPathComponent)
        }

        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        if let orientation = sourceProperties[kCGImagePropertyOrientation] {
            properties[kCGImagePropertyOrientation] = orientation
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.cannotWrite(outputURL.lastPathComponent)
        }
    }

    private func outputURL(for inputURL: URL) throws -> URL {
        let folder = Destination.folder
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        var candidate = folder.appendingPathComponent("\(baseName).jpg")
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(suffix).jpg")
            suffix += 1
        }

        return candidate
    }
}

enum ConversionError: LocalizedError {
    case unsupported(String)
    case cannotRead(String)
    case cannotCreate(String)
    case cannotWrite(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let file):
            return "\(file) is not a HEIC or HEIF file."
        case .cannotRead(let file):
            return "Could not read \(file)."
        case .cannotCreate(let file):
            return "Could not create \(file)."
        case .cannotWrite(let file):
            return "Could not write \(file)."
        }
    }
}
