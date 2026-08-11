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
    private let maxCats = 5
    /// Detected vertical planes (walls). Cats must stay out of these.
    private var wallPlanes: [ARPlaneAnchor] = []
    private var hintLabel: UILabel!

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
        setupHint()
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
        // Vertical planes matter here: we need to know where walls are so we
        // never place a cat inside one.
        cfg.planeDetection = [.horizontal, .vertical]
        cfg.environmentTexturing = .automatic
        // Keep the mesh from the scan phase — raycasts hit real geometry.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            cfg.sceneReconstruction = .mesh
        }
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

    // MARK: - Hint

    private func setupHint() {
        hintLabel = UILabel()
        hintLabel.text = "Наведите камеру на пол — котик появится"
        hintLabel.font = .systemFont(ofSize: 15, weight: .medium)
        hintLabel.textColor = .white
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        hintLabel.layer.cornerRadius = 14
        hintLabel.layer.masksToBounds = true
        hintLabel.alpha = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            hintLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
        ])
    }

    private func setHint(_ text: String?) {
        guard let text else {
            UIView.animate(withDuration: 0.25) { self.hintLabel.alpha = 0 }
            return
        }
        hintLabel.text = text
        UIView.animate(withDuration: 0.25) { self.hintLabel.alpha = 1 }
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
        // Find a real surface first — no point loading a model we can't place.
        guard let placement = findSpawnTransform() else {
            setHint("Поводите камерой по полу — ищу место для котика")
            return
        }
        guard let cat = await CatEntity.makeCat() else { return }
        setHint(nil)

        let anchor = AnchorEntity(world: placement)
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

    /// Raycasts against detected horizontal surfaces and returns a transform
    /// that sits on the floor, clear of walls and other cats.
    /// Returns nil when nothing suitable is visible.
    private func findSpawnTransform() -> simd_float4x4? {
        let bounds = arView.bounds
        // Sample the lower half of the screen — that's where the floor is.
        // Try several random points and keep the first valid one.
        for _ in 0..<25 {
            let screenPoint = CGPoint(
                x: CGFloat.random(in: bounds.minX + 40 ... bounds.maxX - 40),
                y: CGFloat.random(in: bounds.midY ... bounds.maxY - 60)
            )

            // .existingPlaneGeometry respects the real extent of the detected
            // plane, so a ray aimed past the floor's edge simply misses
            // instead of landing on an infinite phantom plane.
            let results = arView.raycast(
                from: screenPoint,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            guard let hit = results.first else { continue }

            let pos = SIMD3<Float>(hit.worldTransform.columns.3.x,
                                   hit.worldTransform.columns.3.y,
                                   hit.worldTransform.columns.3.z)

            guard isPlayableDistance(pos), hasWallClearance(pos), isFreeOfCats(pos) else {
                continue
            }
            return hit.worldTransform
        }
        return nil
    }

    /// Keeps cats reachable but not glued to the lens.
    private func isPlayableDistance(_ pos: SIMD3<Float>) -> Bool {
        guard let camera = arView.session.currentFrame?.camera else { return false }
        let camPos = SIMD3<Float>(camera.transform.columns.3.x,
                                  camera.transform.columns.3.y,
                                  camera.transform.columns.3.z)
        let d = simd_distance(pos, camPos)
        return d > 0.7 && d < 3.5
    }

    /// Rejects points closer than 40 cm to any detected wall, measured
    /// perpendicular to the wall and only within that wall's actual extent.
    private func hasWallClearance(_ pos: SIMD3<Float>) -> Bool {
        let minClearance: Float = 0.4

        for wall in wallPlanes {
            // Move the point into the plane's local space.
            let inv = simd_inverse(wall.transform)
            let local4 = inv * SIMD4<Float>(pos.x, pos.y, pos.z, 1)
            let local = SIMD3<Float>(local4.x, local4.y, local4.z)

            // For a vertical plane, local Y is the normal direction.
            let perpendicular = abs(local.y)
            guard perpendicular < minClearance else { continue }

            // Only counts if the point is actually within the wall's bounds,
            // not off past its edge.
            let c = wall.center
            let size = wall.planeSize
            let halfWidth  = size.x / 2 + minClearance
            let halfHeight = size.y / 2 + minClearance
            if abs(local.x - c.x) < halfWidth && abs(local.z - c.z) < halfHeight {
                return false
            }
        }
        return true
    }

    /// Avoids stacking a new cat on top of an existing one.
    private func isFreeOfCats(_ pos: SIMD3<Float>) -> Bool {
        for cat in cats where !cat.isCaught {
            if simd_distance(cat.position(relativeTo: nil), pos) < 0.5 { return false }
        }
        return true
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
        // Don't slide the cat along a random vector — that was pushing it
        // through walls. Just hop up and vanish, then respawn somewhere valid.
        cat.isCaught = true   // stops bobbing and excludes it from the alive count

        var away = cat.transform
        away.translation.y += 0.12
        away.scale = .zero
        cat.move(to: away, relativeTo: cat.parent, duration: 0.45, timingFunction: .easeIn)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak cat] in
            cat?.parent?.removeFromParent()
            self?.cats.removeAll { $0 === cat }
            self?.spawnCatIfNeeded()
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

// MARK: - Plane size compatibility

private extension ARPlaneAnchor {
    /// Plane dimensions as (width, height).
    /// `planeExtent` is iOS 16+; fall back to the deprecated `extent` on iOS 15.
    var planeSize: SIMD2<Float> {
        if #available(iOS 16.0, *) {
            return SIMD2<Float>(planeExtent.width, planeExtent.height)
        } else {
            return SIMD2<Float>(extent.x, extent.z)
        }
    }
}

// MARK: - ARSessionDelegate

extension GameViewController: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        var foundFloor = false

        for case let plane as ARPlaneAnchor in anchors {
            switch plane.alignment {
            case .vertical:
                wallPlanes.append(plane)
            case .horizontal:
                foundFloor = true
            @unknown default:
                break
            }
        }

        // First floor found: try to place the opening cat.
        if foundFloor, cats.isEmpty {
            Task { await spawnCat() }
        }
    }

    /// Planes grow as ARKit learns the room — keep our wall list current,
    /// otherwise clearance checks use stale extents.
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for case let plane as ARPlaneAnchor in anchors where plane.alignment == .vertical {
            if let i = wallPlanes.firstIndex(where: { $0.identifier == plane.identifier }) {
                wallPlanes[i] = plane
            } else {
                wallPlanes.append(plane)
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let removed = Set(anchors.map(\.identifier))
        wallPlanes.removeAll { removed.contains($0.identifier) }
    }
}
