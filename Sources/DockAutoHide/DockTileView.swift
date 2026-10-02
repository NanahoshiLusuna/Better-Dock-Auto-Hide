import AppKit

final class DockTileView: NSView {
    private let label = NSTextField(labelWithString: "—")
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        label.font = .systemFont(ofSize: 42, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true

        addSubview(label)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 78),
            imageView.heightAnchor.constraint(equalToConstant: 78),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 6), xRadius: 24, yRadius: 24)
        NSColor(calibratedWhite: 0.12, alpha: 0.92).setFill()
        background.fill()
    }

    func showTemperature(_ text: String) {
        label.stringValue = text
        label.isHidden = false
        imageView.isHidden = true
    }

    func showSymbol(_ name: String) {
        let config = NSImage.SymbolConfiguration(pointSize: 68, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        imageView.image = NSImage(systemSymbolName: name, accessibilityDescription: name)?
            .withSymbolConfiguration(config)
        imageView.isHidden = false
        label.isHidden = true
    }
}
