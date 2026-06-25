import Cocoa

// MARK: - WaveGeneratingView
/// Displays a "Generating…" label with an animated shimmer / wave highlight
/// that sweeps continuously from left to right over the text.
class WaveGeneratingView: NSView {

    // MARK: - Subviews
    private let label = NSTextField(labelWithString: "Generating…")

    // MARK: - Shimmer layers
    /// The gradient that acts as a luminance mask over the text color.
    private var shimmerGradient: CAGradientLayer?
    private var isAnimating = false

    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setup() {
        wantsLayer = true

        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.35)  // dim base — shimmer sweeps over it
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - Layout
    override func layout() {
        super.layout()
        // Keep shimmer gradient frame in sync with this view
        shimmerGradient?.frame = bounds
    }

    // MARK: - Animation control
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // Remove any stale gradient
        shimmerGradient?.removeFromSuperlayer()

        let gradient = CAGradientLayer()
        gradient.frame = bounds
        // Horizontal sweep: start = -100%, end = +200%
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)

        // Three-stop gradient: dark → bright → dark, acts as a moving light beam
        let dimAlpha: CGFloat = 0.35
        let peakAlpha: CGFloat = 0.95
        gradient.colors = [
            NSColor.white.withAlphaComponent(dimAlpha).cgColor,
            NSColor.white.withAlphaComponent(dimAlpha).cgColor,
            NSColor.white.withAlphaComponent(peakAlpha).cgColor,
            NSColor.white.withAlphaComponent(dimAlpha).cgColor,
            NSColor.white.withAlphaComponent(dimAlpha).cgColor,
        ]
        gradient.locations = [0, 0.3, 0.5, 0.7, 1]

        // Apply gradient as mask to the text layer so only text gets the shimmer
        label.wantsLayer = true
        label.layer?.mask = gradient
        shimmerGradient = gradient

        // Animate the gradient positions so the bright band sweeps LTR
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.6, -0.4, -0.1, 0.2, 0.4]
        animation.toValue = [0.6, 0.8, 1.1, 1.4, 1.6]
        animation.duration = 1.6
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.repeatCount = .infinity
        gradient.add(animation, forKey: "shimmer")
    }

    func stopAnimation() {
        guard isAnimating else { return }
        isAnimating = false
        shimmerGradient?.removeAllAnimations()
        shimmerGradient?.removeFromSuperlayer()
        shimmerGradient = nil
        label.layer?.mask = nil
    }
}
