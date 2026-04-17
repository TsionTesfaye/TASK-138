import UIKit
import CoreLocation

/// Carpool module: create pool order, view matches, accept, complete.
final class CarpoolListViewController: BaseTableViewController {

    private var orders: [PoolOrder] = []
    var site: String = ""

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
        site = container.currentSite
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Carpool"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapCreate))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadOrders()
    }

    private func loadOrders() {
        guard let user = container.sessionService.currentUser else { return }
        switch container.carpoolService.findAllOrders(by: user, site: site) {
        case .success(let found):
            orders = found.sorted { $0.startTime > $1.startTime }
            if orders.isEmpty { applyState(.empty("No pool orders")) }
            else { applyState(.loaded) }
        case .failure(let err):
            orders = []
            applyState(.error("Access denied: \(err.message)"))
        }
    }

    @objc private func didTapCreate() {
        let vc = CreatePoolOrderViewController(container: container)
        vc.site = site
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { orders.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let order = orders[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = "\(order.vehicleType) — \(order.seatsAvailable) seats"
        config.secondaryText = "\(order.status.rawValue.capitalized) \u{2022} \(order.startTime)"
        config.image = UIImage(systemName: "car.2")
        config.imageProperties.tintColor = order.status == .active ? .systemGreen : .secondaryLabel
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
        let order = orders[indexPath.row]
        let vc = CarpoolDetailViewController(container: container, orderId: order.id)
        vc.site = site
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Create Pool Order

final class CreatePoolOrderViewController: FormViewController, CLLocationManagerDelegate {

    private let originLatField, originLngField, destLatField, destLngField, seatsField, vehicleField: UITextField
    private let startTimePicker = UIDatePicker()
    private let endTimePicker = UIDatePicker()
    var site: String = ""
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((CLLocation?) -> Void)?

    override init(container: ServiceContainer) {
        originLatField = UITextField(); originLngField = UITextField()
        destLatField = UITextField(); destLngField = UITextField()
        seatsField = UITextField(); vehicleField = UITextField()
        super.init(container: container)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Pool Order"
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        let fields: [(UITextField, String)] = [
            (originLatField, "Origin Latitude"), (originLngField, "Origin Longitude"),
            (destLatField, "Destination Latitude"), (destLngField, "Destination Longitude"),
            (seatsField, "Seats Available"), (vehicleField, "Vehicle Type"),
        ]
        for (tf, ph) in fields {
            tf.placeholder = ph; tf.borderStyle = .roundedRect
            tf.font = .preferredFont(forTextStyle: .body)
            tf.adjustsFontForContentSizeCategory = true
            tf.keyboardType = ph.contains("Lat") || ph.contains("Long") || ph.contains("Seats") ? .decimalPad : .default
            stackView.addArrangedSubview(tf)
        }

        // Use device location button
        let locBtn = makeButton(title: "Use Current Location", style: .secondary)
        locBtn.addTarget(self, action: #selector(useLocation), for: .touchUpInside)
        stackView.addArrangedSubview(locBtn)

        // Start time picker
        let startLabel = makeLabel(text: "Departure Time", style: .subheadline)
        stackView.addArrangedSubview(startLabel)
        startTimePicker.datePickerMode = .dateAndTime
        startTimePicker.preferredDatePickerStyle = .compact
        startTimePicker.minimumDate = Date().addingTimeInterval(60)
        startTimePicker.date = Date().addingTimeInterval(3600)
        stackView.addArrangedSubview(startTimePicker)

        // End time picker
        let endLabel = makeLabel(text: "Return / End Time", style: .subheadline)
        stackView.addArrangedSubview(endLabel)
        endTimePicker.datePickerMode = .dateAndTime
        endTimePicker.preferredDatePickerStyle = .compact
        endTimePicker.minimumDate = Date().addingTimeInterval(120)
        endTimePicker.date = Date().addingTimeInterval(7200)
        stackView.addArrangedSubview(endTimePicker)

        let submitBtn = makeButton(title: "Create Order")
        submitBtn.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        stackView.addArrangedSubview(submitBtn)
        stackView.addArrangedSubview(errorLabel)
    }

    @objc private func useLocation() {
        clearFormError()
        requestOneShotLocation { [weak self] location in
            guard let self = self else { return }
            if let location = location {
                self.originLatField.text = String(format: "%.6f", location.coordinate.latitude)
                self.originLngField.text = String(format: "%.6f", location.coordinate.longitude)
            } else {
                self.showFormError("Location unavailable. Enter coordinates manually.")
            }
        }
    }

    private func requestOneShotLocation(completion: @escaping (CLLocation?) -> Void) {
        locationCompletion = completion
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            completion(nil)
            locationCompletion = nil
        @unknown default:
            completion(nil)
            locationCompletion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if locationCompletion != nil { manager.requestLocation() }
        } else if status == .denied || status == .restricted {
            locationCompletion?(nil)
            locationCompletion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationCompletion?(locations.last)
        locationCompletion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCompletion?(nil)
        locationCompletion = nil
    }

    @objc private func didTapSubmit() {
        clearFormError()
        guard let user = container.sessionService.currentUser else { showFormError("Session expired"); return }
        guard let olat = Double(originLatField.text ?? ""), let olng = Double(originLngField.text ?? ""),
              let dlat = Double(destLatField.text ?? ""), let dlng = Double(destLngField.text ?? "") else {
            showFormError("Enter valid coordinates"); return
        }
        guard let seats = Int(seatsField.text ?? ""), seats > 0 else { showFormError("Enter seats > 0"); return }
        let vehicle = vehicleField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !vehicle.isEmpty else { showFormError("Enter vehicle type"); return }

        guard startTimePicker.date < endTimePicker.date else { showFormError("End time must be after start time"); return }

        let input = CarpoolService.CreatePoolOrderInput(
            originLat: olat, originLng: olng, destinationLat: dlat, destinationLng: dlng,
            startTime: startTimePicker.date, endTime: endTimePicker.date,
            seatsAvailable: seats, vehicleType: vehicle
        )
        let result = container.carpoolService.createPoolOrder(by: user, site: site, input: input, operationId: UUID())
        switch result {
        case .success(let order):
            // Activate immediately
            _ = container.carpoolService.activateOrder(by: user, site: site, orderId: order.id, operationId: UUID())
            navigationController?.popViewController(animated: true)
        case .failure(let err): showFormError(err.message)
        }
    }
}

// MARK: - Carpool Detail

final class CarpoolDetailViewController: BaseTableViewController {

    private let orderId: UUID
    private var order: PoolOrder?
    private var matches: [CarpoolMatch] = []
    var site: String = ""

    init(container: ServiceContainer, orderId: UUID) {
        self.orderId = orderId
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pool Order Detail"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Find Matches", style: .plain, target: self, action: #selector(findMatches))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let user = container.sessionService.currentUser else { return }
        if case .success(let o) = container.carpoolService.findOrderById(by: user, site: site, orderId) {
            order = o
        }
        if case .success(let m) = container.carpoolService.findMatchesByOrderId(by: user, site: site, orderId) {
            matches = m
        }
        tableView.reloadData()
    }

    @objc private func findMatches() {
        guard let user = container.sessionService.currentUser else { return }
        let result = container.carpoolService.computeMatches(by: user, site: site, for: orderId)
        switch result {
        case .success(let m):
            matches = m
            tableView.reloadData()
            if m.isEmpty { showError("No matches found") }
        case .failure(let err): showError(err.message)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Order Info" : "Matches (\(matches.count))"
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 4 : max(matches.count, 1)
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true

        if indexPath.section == 0 {
            guard let o = order else { return cell }
            let rows = [
                "Status: \(o.status.rawValue.capitalized)",
                "Seats: \(o.seatsAvailable)",
                "Vehicle: \(o.vehicleType)",
                "Time: \(o.startTime) — \(o.endTime)",
            ]
            config.text = rows[indexPath.row]
        } else {
            if matches.isEmpty { config.text = "No matches yet"; config.textProperties.color = .secondaryLabel }
            else {
                let m = matches[indexPath.row]
                config.text = String(format: "Score: %.2f  Detour: %.1f mi  Overlap: %.0f min", m.matchScore, m.detourMiles, m.timeOverlapMinutes)
                config.secondaryText = m.accepted ? "Accepted" : "Tap to accept"
                config.image = UIImage(systemName: m.accepted ? "checkmark.circle.fill" : "arrow.triangle.merge")
                config.imageProperties.tintColor = m.accepted ? .systemGreen : .systemBlue
                if !m.accepted { cell.accessoryType = .disclosureIndicator }
            }
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, indexPath.row < matches.count else { return }
        let match = matches[indexPath.row]
        guard !match.accepted, let user = container.sessionService.currentUser else { return }
        let result = container.carpoolService.acceptMatch(by: user, site: site, matchId: match.id, operationId: UUID())
        switch result {
        case .success: viewWillAppear(false)
        case .failure(let err): showError(err.message)
        }
    }
}
