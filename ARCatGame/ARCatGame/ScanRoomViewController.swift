import UIKit
import ARKit
import RealityKit

/// First screen: guides the user to scan the room before the game starts.
final class ScanRoomViewController: UIViewController {

    // MARK: - Views
    private var arView: ARView!
    private var overlayView: UIView!
    private var statusLabel: UILabel!
    private var progressBar: UIProgressView!
    private var hintLabel: UILabel!
    private var startButton: UIButton!

    // MARK: - State
    private var isMapped = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }

    // MARK: - AR

    private func setupAR() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.debugOptions = [.showFeaturePoints]
        view.addSubview(arView)
        arView.session.delegate = self
    }

    private func startScanning() {
        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection = [.horizontal, .vertical]
        cfg.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            cfg.sceneReconstruction = .mesh
        }
        arView.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - UI

    private func setupUI() {
        // Bottom overlay card
        overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        overlayView.layer.cornerRadius = 22
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)

        let titleLabel = makeLabel("🐱 AR Cat Hunt", font: .boldSystemFont(ofSize: 22), color: .white)
        hintLabel = makeLabel("Медленно водите телефоном по комнате.\nКоты появятся на плоских поверхностях.", font: .systemFont(ofSize: 14), color: .lightGray)
        hintLabel.numberOfLines = 0

        statusLabel = makeLabel("Начинаю сканирование…", font: .monospacedDigitSystemFont(ofSize: 13, weight: .regular), color: .white)

        progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.progressTintColor = UIColor(red: 0.3, green: 0.85, blue: 0.45, alpha: 1)
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        progressBar.layer.cornerRadius = 4
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        startButton = UIButton(type: .system)
        startButton.setTitle("🎮  Начать игру!", for: .normal)
        startButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor(red: 0.18, green: 0.68, blue: 0.28, alpha: 1)
        startButton.layer.cornerRadius = 14
        startButton.isHidden = true
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startGameTapped), for: .touchUpInside)

        [titleLabel, hintLabel, progressBar, statusLabel, startButton].forEach {
            overlayView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            overlayView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            titleLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 18),
            titleLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),

            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),

            progressBar.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),
            progressBar.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 6),
            statusLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),

            startButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            startButton.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 52),
            startButton.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -18),
        ])
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    // MARK: - Actions

    @objc private func startGameTapped() {
        arView.debugOptions = []
        arView.session.getCurrentWorldMap { [weak self] worldMap, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let game = GameViewController(worldMap: worldMap)
                game.modalPresentationStyle = .fullScreen
                self.present(game, animated: false)
            }
        }
    }

    // MARK: - Progress update

    private func updateProgress(frame: ARFrame) {
        let pts = frame.rawFeaturePoints?.points.count ?? 0
        let needed = 200

        switch frame.worldMappingStatus {
        case .notAvailable:
            statusLabel.text = "Ищу поверхности…"
            progressBar.setProgress(0.05, animated: true)
        case .limited:
            let p = min(Float(pts) / Float(needed), 0.72)
            statusLabel.text = "Сканирую… \(pts) точек"
            progressBar.setProgress(p, animated: true)
        case .extending:
            statusLabel.text = "Хорошо! Продолжайте…  \(pts) точек"
            progressBar.setProgress(0.85, animated: true)
        case .mapped:
            statusLabel.text = "✅ Комната отсканирована!"
            progressBar.setProgress(1.0, animated: true)
            if !isMapped {
                isMapped = true
                UIView.animate(withDuration: 0.35) {
                    self.hintLabel.text = "Готово! Коты ждут тебя 😺"
                    self.startButton.isHidden = false
                }
            }
        @unknown default: break
        }
    }
}

// MARK: - ARSessionDelegate

extension ScanRoomViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async { [weak self] in self?.updateProgress(frame: frame) }
    }
}
