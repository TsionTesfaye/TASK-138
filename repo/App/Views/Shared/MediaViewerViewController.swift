import UIKit
import AVKit

/// Media viewer with watermark overlay.
final class MediaViewerViewController: UIViewController {

    private let container: ServiceContainer
    private let fileId: UUID
    var site: String = ""

    init(container: ServiceContainer, fileId: UUID) {
        self.container = container
        self.fileId = fileId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Evidence Viewer"
        view.backgroundColor = .black

        guard let user = container.sessionService.currentUser else { showNotFound(); return }

        guard case .success(let file) = container.fileService.findById(by: user, site: site, fileId),
              let file = file else {
            showNotFound(); return
        }

        // Image viewer
        if file.fileType.isImage {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            ])
            if let image = UIImage(contentsOfFile: file.filePath) {
                imageView.image = image
            }
        } else if file.fileType.isVideo {
            let player = AVPlayer(url: URL(fileURLWithPath: file.filePath))
            let playerVC = AVPlayerViewController()
            playerVC.player = player
            addChild(playerVC)
            playerVC.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(playerVC.view)
            NSLayoutConstraint.activate([
                playerVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                playerVC.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            ])
            playerVC.didMove(toParent: self)
            player.play()
        }

        // Watermark overlay
        let watermarkResult = container.fileService.getWatermarkInfo(by: user, site: site, for: fileId)
        if case .success(let info) = watermarkResult, info.enabled {
            let watermark = UILabel()
            watermark.text = info.watermarkText
            watermark.font = .systemFont(ofSize: 24, weight: .bold)
            watermark.textColor = UIColor.white.withAlphaComponent(0.4)
            watermark.transform = CGAffineTransform(rotationAngle: -.pi / 6)
            watermark.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(watermark)
            NSLayoutConstraint.activate([
                watermark.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                watermark.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }

        // File info bar
        let infoLabel = UILabel()
        infoLabel.text = "\(file.fileType.rawValue.uppercased()) \u{2022} \(file.fileSize / 1024) KB \u{2022} SHA: \(file.hash.prefix(12))..."
        infoLabel.font = .preferredFont(forTextStyle: .caption2)
        infoLabel.adjustsFontForContentSizeCategory = true
        infoLabel.textColor = .lightGray
        infoLabel.textAlignment = .center
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        NSLayoutConstraint.activate([
            infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func showNotFound() {
        let label = UILabel()
        label.text = "File not found"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
