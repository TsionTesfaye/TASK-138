import UIKit

/// Exception list + detail + appeal submission + reviewer decision.
final class ExceptionListViewController: BaseTableViewController {

    private var exceptions: [ExceptionCase] = []
    var site: String = ""

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Exceptions"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let user = container.sessionService.currentUser else { return }
        if case .success(let found) = container.exceptionService.findByStatus(by: user, site: site, .open) {
            exceptions = found.sorted { $0.createdAt > $1.createdAt }
        }
        if exceptions.isEmpty { applyState(.empty("No exceptions")) }
        else { applyState(.loaded) }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { exceptions.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let exc = exceptions[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = exc.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        config.secondaryText = "\(exc.status.rawValue.capitalized) \u{2022} \(exc.reason.prefix(50))"
        config.image = UIImage(systemName: "exclamationmark.shield")
        config.imageProperties.tintColor = exc.status == .open ? .systemRed : .secondaryLabel
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let exc = exceptions[indexPath.row]
        let vc = ExceptionDetailViewController(container: container, exceptionId: exc.id)
        vc.site = site
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Exception Detail + Appeal

final class ExceptionDetailViewController: BaseTableViewController {

    private let exceptionId: UUID
    private var exception: ExceptionCase?
    private var appeals: [Appeal] = []
    private var evidence: [EvidenceFile] = []
    var site: String = ""

    init(container: ServiceContainer, exceptionId: UUID) {
        self.exceptionId = exceptionId
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Exception Detail"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Actions", style: .plain, target: self, action: #selector(showActions))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let user = container.sessionService.currentUser else { return }
        if case .success(let exc) = container.exceptionService.findById(by: user, site: site, exceptionId) {
            exception = exc
        }
        if case .success(let a) = container.appealService.findByExceptionId(by: user, site: site, exceptionId) {
            appeals = a
        }
        // Load evidence attached to appeals (not exception) — evidence lifecycle is per-appeal
        evidence = []
        for appeal in appeals {
            if case .success(let files) = container.fileService.findByEntity(by: user, site: site, entityId: appeal.id, entityType: "Appeal") {
                evidence.append(contentsOf: files)
            }
        }
        tableView.reloadData()
    }

    @objc private func showActions() {
        guard let user = container.sessionService.currentUser, let exc = exception else { return }
        let sheet = UIAlertController(title: "Actions", message: nil, preferredStyle: .actionSheet)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem

        // Submit appeal (Sales Associate or Admin)
        if PermissionMatrix.canPerform(role: user.role, action: "create", module: .appeals) && exc.status == .open {
            sheet.addAction(UIAlertAction(title: "Submit Appeal", style: .default) { [weak self] _ in self?.promptSubmitAppeal() })
        }

        // Reviewer actions
        if PermissionMatrix.canPerform(role: user.role, action: "review", module: .appeals) {
            for appeal in appeals where appeal.status == .submitted {
                sheet.addAction(UIAlertAction(title: "Start Review (Appeal \(appeal.id.uuidString.prefix(6))...)", style: .default) { [weak self] _ in
                    self?.startReview(appealId: appeal.id)
                })
            }
            for appeal in appeals where appeal.status == .underReview && appeal.reviewerId == user.id {
                sheet.addAction(UIAlertAction(title: "Approve Appeal", style: .default) { [weak self] _ in self?.approveAppeal(appeal.id) })
                sheet.addAction(UIAlertAction(title: "Deny Appeal", style: .destructive) { [weak self] _ in self?.denyAppeal(appeal.id) })
            }
        }

        // Attach evidence to the active appeal (submitted or under review)
        if PermissionMatrix.canPerform(role: user.role, action: "create", module: .appeals) {
            let activeAppeal = appeals.first { $0.status == .submitted || $0.status == .underReview }
            if let appeal = activeAppeal {
                sheet.addAction(UIAlertAction(title: "Attach Evidence (Photo)", style: .default) { [weak self] _ in self?.pickEvidence(for: appeal.id) })
            }
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private var pendingEvidenceAppealId: UUID?

    private func pickEvidence(for appealId: UUID) {
        pendingEvidenceAppealId = appealId
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.delegate = self
        present(picker, animated: true)
    }

    private func promptSubmitAppeal() {
        let alert = UIAlertController(title: "Submit Appeal", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Reason for appeal" }
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            guard let self = self, let user = self.container.sessionService.currentUser,
                  let reason = alert.textFields?.first?.text, !reason.isEmpty else { return }
            let result = self.container.appealService.submitAppeal(by: user, site: self.site, exceptionId: self.exceptionId, reason: reason, operationId: UUID())
            switch result {
            case .success: self.showSuccess("Appeal submitted"); self.viewWillAppear(false)
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func startReview(appealId: UUID) {
        guard let user = container.sessionService.currentUser else { return }
        switch container.appealService.startReview(by: user, site: site, appealId: appealId, operationId: UUID()) {
        case .success: showSuccess("Review started"); viewWillAppear(false)
        case .failure(let err): showError(err.message)
        }
    }

    private func approveAppeal(_ id: UUID) {
        guard let user = container.sessionService.currentUser else { return }
        switch container.appealService.approveAppeal(by: user, site: site, appealId: id, operationId: UUID()) {
        case .success: showSuccess("Appeal approved — exception resolved"); viewWillAppear(false)
        case .failure(let err): showError(err.message)
        }
    }

    private func denyAppeal(_ id: UUID) {
        guard let user = container.sessionService.currentUser else { return }
        switch container.appealService.denyAppeal(by: user, site: site, appealId: id, operationId: UUID()) {
        case .success: showSuccess("Appeal denied"); viewWillAppear(false)
        case .failure(let err): showError(err.message)
        }
    }

    // MARK: - Table (Info, Appeals, Evidence)

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section { case 0: return "Exception"; case 1: return "Appeals (\(appeals.count))"; case 2: return "Evidence (\(evidence.count))"; default: return nil }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section { case 0: return 4; case 1: return max(appeals.count, 1); case 2: return max(evidence.count, 1); default: return 0 }
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true

        guard let exc = exception else { return cell }
        switch indexPath.section {
        case 0:
            let rows = [
                "Type: \(exc.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)",
                "Status: \(exc.status.rawValue.capitalized)",
                "Reason: \(exc.reason)",
                "Created: \(exc.createdAt)",
            ]
            config.text = rows[indexPath.row]
        case 1:
            if appeals.isEmpty { config.text = "No appeals"; config.textProperties.color = .secondaryLabel }
            else {
                let a = appeals[indexPath.row]
                config.text = "Appeal: \(a.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)"
                config.secondaryText = a.reason.prefix(60).description
                config.image = UIImage(systemName: a.status == .approved ? "checkmark.seal" : "doc.text")
            }
        case 2:
            if evidence.isEmpty { config.text = "No evidence attached"; config.textProperties.color = .secondaryLabel }
            else {
                let e = evidence[indexPath.row]
                config.text = "\(e.fileType.rawValue.uppercased()) — \(e.fileSize / 1024) KB"
                config.secondaryText = e.pinnedByAdmin ? "Pinned" : ""
                config.image = UIImage(systemName: e.fileType.isImage ? "photo" : "video")
                cell.accessoryType = .disclosureIndicator
            }
        default: break
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 && indexPath.row < evidence.count {
            let vc = MediaViewerViewController(container: container, fileId: evidence[indexPath.row].id)
            vc.site = site
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - Evidence Upload via UIImagePickerController

extension ExceptionDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let user = container.sessionService.currentUser else { return }

        var fileData: Data?
        var fileType: EvidenceFileType = .jpg

        if let image = info[.originalImage] as? UIImage {
            fileData = image.jpegData(compressionQuality: 0.8)
            fileType = .jpg
        } else if let videoURL = info[.mediaURL] as? URL {
            fileData = try? Data(contentsOf: videoURL)
            fileType = .mp4
        }

        guard let data = fileData else {
            showError("Could not read file data"); return
        }

        guard let appealId = pendingEvidenceAppealId else {
            showError("No active appeal to attach evidence to"); return
        }
        pendingEvidenceAppealId = nil

        let result = container.fileService.uploadFile(
            by: user, site: site, entityId: appealId, entityType: "Appeal",
            data: data, fileType: fileType, operationId: UUID()
        )
        switch result {
        case .success:
            showSuccess("Evidence attached")
            viewWillAppear(false)
        case .failure(let err):
            showError(err.message)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
