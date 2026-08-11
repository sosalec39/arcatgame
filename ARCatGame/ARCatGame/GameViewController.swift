import UIKit
import ARKit
import RealityKit

/// Main game screen: cats appear in the scanned room, tap to catch them.
final class GameViewController: UIViewController {

    // MARK: - Properties
    private let savedWorldMap: ARWorldMap?
    private var arView: ARView!
    private var scoreLabel: UILabel!
    private var score = 0 { didSet { updateScoreLabel() } }
    private var cats: [CatEntity] = []
    private var spawnTimer: Timer?
    private var maxCats = 5

    init(worldMap: ARWorldMap?) {
        self.savedWorldMap = worldMap
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        setupHUD()
        setupGesture()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startAR()
        scheduleSpawning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        spawnTimer?.invalidate()
        arView.session.pause()
    }

    // MARK: - AR

    private func setupAR() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        arView.session.delegate = self
    }

    private func startAR() {
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal]
        cfg.environmentTexturing = .automatic
        var opts: ARSession.RunOptions = []
        if let map = savedWorldMap {
            cfg.initialWorldMap = map
        } else {
            opts = [.resetTracking, .removeExistingAnchors]
        }
        arView.session.run(cfg, options: opts)
    }

    // MARK: - HUD

    private func setupHUD() {
        // Score badge
        let badge = UIView()
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        badge.layer.cornerRadius = 18
        badge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badge)

        scoreLabel = UILabel()
        scoreLabel.text = "🐱  0"
        scoreLabel.font = .boldSystemFont(ofSize: 28)
        scoreLabel.textColor = .white
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(scoreLabel)

        // Back button
        let backBtn = UIButton(type: .system)
        backBtn.setTitle("✕", for: .normal)
        backBtn.titleLabel?.font = .boldSystemFont(ofSize: 20)
        backBtn.setTitleColor(.white, for: .normal)
        backBtn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backBtn.layer.cornerRadius = 20
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        view.addSubview(backBtn)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            badge.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scoreLabel.topAnchor.constraint(equalTo: badge.topAnchor, constant: 8),
            scoreLabel.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -8),
            scoreLabel.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 18),
            scoreLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -18),

            backBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            backBtn.widthAnchor.constraint(equalToConstant: 40),
            backBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func updateScoreLabel() {
        scoreLabel.text = "🐱  \(score)"
        UIView.animate(withDuration: 0.12, animations: {
            self.scoreLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.12) {
                self.scoreLabel.transform = .identity
            }
        }
    }

    // MARK: - Gesture

    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: arView)
        guard let hit = arView.entity(at: loc) else { return }

        // Walk up entity hierarchy to find the CatEntity
        var entity: Entity? = hit
        while entity != nil {
            if let cat = entity as? CatEntity, !cat.isCaught {
                catchCat(cat)
                return
            }
            entity = entity?.parent
        }
    }

    // MARK: - Cat lifecycle

    private func scheduleSpawning() {
        spawnCatIfNeeded()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            self?.spawnCatIfNeeded()
        }
    }

    private func spawnCatIfNeeded() {
        let alive = cats.filter { !$0.isCaught }
        guard alive.count < maxCats else { return }
        Task { await spawnCat() }
    }

    private func spawnCat() async {
        guard let cat = await CatEntity.makeCat() else { return }

        // Place cat 1–2.5 m in front at a random horizontal offset, on the "floor"
        let distance = Float.random(in: 1.0...2.5)
        let angle    = Float.random(in: -.pi/3 ... .pi/3)
        let x        = distance * sin(angle)
        let z        = -distance * cos(angle)

        let anchor = AnchorEntity(world: SIMD3<Float>(x, -0.3, z))
        anchor.addChild(cat)
        arView.scene.addAnchor(anchor)
        cats.append(cat)
        cat.startBobbing()

        // Cat runs away after 12-20 s if not caught
        let delay = Double.random(in: 12...20)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak cat] in
            guard let cat, !cat.isCaught else { return }
            self?.runAwayCat(cat)
        }
    }

    private func catchCat(_ cat: CatEntity) {
        score += 1
        showCatchEffect(at: cat.position(relativeTo: nil))
        cat.playCatchAnimation { [weak self, weak cat] in
            cat?.parent?.removeFromParent()
            self?.cats.removeAll { $0 === cat }
            self?.spawnCatIfNeeded()
        }
    }

    private func runAwayCat(_ cat: CatEntity) {
        // Move the cat quickly in a random direction, then remove
        var flee = cat.transform
        flee.translation.x += Float.random(in: -2...2)
        flee.translation.z += Float.random(in: -2...2)
        cat.move(to: flee, relativeTo: cat.parent, duration: 0.8, timingFunction: .easeIn)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self, weak cat] in
            cat?.parent?.removeFromParent()
            self?.cats.removeAll { $0 === cat }
        }
    }

    // MARK: - Visual effect

    private func showCatchEffect(at worldPos: SIMD3<Float>) {
        // Simple emoji label floating up
        let label = UILabel()
        label.text = "🎉+1"
        label.font = .boldSystemFont(ofSize: 36)
        label.sizeToFit()

        if let screenPt = arView.project(worldPos) {
            label.center = screenPt
        } else {
            label.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
        view.addSubview(label)

        UIView.animate(withDuration: 0.9,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: {
            label.center.y -= 80
            label.alpha = 0
        }) { _ in label.removeFromSuperview() }
    }

    // MARK: - Actions

    @objc private func exitTapped() {
        spawnTimer?.invalidate()
        dismiss(animated: false)
    }
}

// MARK: - ARSessionDelegate

extension GameViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Spawn a cat near the first horizontal plane found
        for anchor in anchors {
            guard anchor is ARPlaneAnchor else { continue }
            if cats.isEmpty { Task { await spawnCat() } }
            break
        }
    }
}
