import AppKit

/// A floating confirmation panel, in the spirit of the system volume overlay.
///
/// This is how the app reports its state when the menu bar icon is hidden.
enum HUD {

    private static var panel: NSPanel?
    private static var dismissal: DispatchWorkItem?

    static func show(symbol: String, title: String, detail: String, tint: NSColor) {
        let size = NSSize(width: 240, height: 200)
        let panel = self.panel ?? makePanel(size: size)
        self.panel = panel

        dismissal?.cancel()
        panel.contentView = content(size: size, symbol: symbol, title: title, detail: detail, tint: tint)

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.minY + frame.height * 0.14
            ))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
        dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    private static func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    private static func content(size: NSSize, symbol: String, title: String, detail: String, tint: NSColor) -> NSView {
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 22
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true

        let configuration = NSImage.SymbolConfiguration(pointSize: 68, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [tint]))
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
            .withSymbolConfiguration(configuration)

        let titleLabel = label(title, font: .systemFont(ofSize: 17, weight: .semibold), color: .labelColor)
        let detailLabel = label(detail, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)

        let stack = NSStackView(views: [imageView, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(14, after: imageView)

        // Size to content, then centre it in the panel.
        let fitting = stack.fittingSize
        stack.setFrameSize(NSSize(width: max(fitting.width, size.width - 32), height: fitting.height))
        stack.setFrameOrigin(NSPoint(
            x: (size.width - stack.frame.width) / 2,
            y: (size.height - stack.frame.height) / 2
        ))

        effect.addSubview(stack)
        return effect
    }

    private static func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.alignment = .center
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 2
        field.preferredMaxLayoutWidth = 200
        return field
    }
}
