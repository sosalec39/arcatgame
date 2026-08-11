import RealityKit
import Foundation

/// A RealityKit entity representing one virtual cat in the AR scene.
final class CatEntity: Entity, HasCollision, HasModel {

    var isCaught = false
    private var bobbingUp = true

    required init() { super.init() }

    // MARK: - Factory

    /// Asynchronously loads cat.usdz and returns a ready-to-use CatEntity.
    static func makeCat() async -> CatEntity? {
        guard let model = try? await Entity.loadModel(named: "cat") else {
            print("[CatEntity] ⚠️ Failed to load cat.usdz")
            return nil
        }
        let cat = CatEntity()
        cat.addChild(model)
        cat.scale = SIMD3<Float>(repeating: 0.12)   // tune to real scan size
        cat.generateCollisionShapes(recursive: true)
        return cat
    }

    // MARK: - Animations

    func startBobbing() { bob() }

    private func bob() {
        guard !isCaught else { return }
        let dy: Float = bobbingUp ? 0.025 : -0.025
        bobbingUp.toggle()
        var dest = transform
        dest.translation.y += dy
        move(to: dest, relativeTo: parent, duration: 0.55, timingFunction: .easeInOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.bob()
        }
    }

    /// Scale-burst catch animation, then calls completion.
    func playCatchAnimation(completion: @escaping () -> Void) {
        isCaught = true
        var big = transform
        big.scale = SIMD3<Float>(repeating: 0.22)
        move(to: big, relativeTo: parent, duration: 0.18, timingFunction: .easeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            var zero = self.transform
            zero.scale = .zero
            self.move(to: zero, relativeTo: self.parent, duration: 0.14, timingFunction: .easeIn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { completion() }
        }
    }
}
