import UIKit
import CoreLocation

/// Check-in screen: staff taps to record check-in at current location.
/// Calls ExceptionService.recordCheckIn() — real service, real persistence.
final class CheckInViewController: FormViewController, CLLocationManagerDelegate {

    private let statusLabel = UILabel()
    private let latField: UITextField
    private let lngField: UITextField
    var site: String = ""
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((CLLocation?) -> Void)?

    override init(container: ServiceContainer) {
        latField = UITextField()
        lngField = UITextField()
        super.init(container: container)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Check In"
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        let headerLabel = makeLabel(text: "Record your check-in at current location", style: .headline)
        stackView.addArrangedSubview(headerLabel)

        latField.placeholder = "Latitude"
        latField.borderStyle = .roundedRect
        latField.keyboardType = .decimalPad
        latField.font = .preferredFont(forTextStyle: .body)
        latField.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(latField)

        lngField.placeholder = "Longitude"
        lngField.borderStyle = .roundedRect
        lngField.keyboardType = .decimalPad
        lngField.font = .preferredFont(forTextStyle: .body)
        lngField.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(lngField)

        let useLocBtn = makeButton(title: "Use Device Location", style: .secondary)
        useLocBtn.addTarget(self, action: #selector(fillDeviceLocation), for: .touchUpInside)
        stackView.addArrangedSubview(useLocBtn)

        let checkInBtn = makeButton(title: "Check In Now")
        checkInBtn.addTarget(self, action: #selector(didTapCheckIn), for: .touchUpInside)
        stackView.addArrangedSubview(checkInBtn)

        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(errorLabel)
    }

    @objc private func fillDeviceLocation() {
        clearFormError()
        requestOneShotLocation { [weak self] location in
            guard let self = self else { return }
            if let location = location {
                self.latField.text = String(format: "%.6f", location.coordinate.latitude)
                self.lngField.text = String(format: "%.6f", location.coordinate.longitude)
            } else {
                self.showFormError("Location unavailable. Enter coordinates manually.")
            }
        }
    }

    @objc private func didTapCheckIn() {
        clearFormError()
        guard let user = container.sessionService.currentUser else {
            showFormError("Session expired"); return
        }
        guard let lat = Double(latField.text ?? ""), let lng = Double(lngField.text ?? "") else {
            showFormError("Enter valid coordinates"); return
        }
        guard lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 else {
            showFormError("Coordinates out of range"); return
        }

        let result = container.exceptionService.recordCheckIn(
            by: user, site: site, locationLat: lat, locationLng: lng, operationId: UUID()
        )
        switch result {
        case .success(let checkIn):
            statusLabel.text = "Check-in recorded at \(checkIn.timestamp)"
            statusLabel.textColor = .systemGreen
        case .failure(let err):
            showFormError(err.message)
        }
    }

    // MARK: - One-Shot Location

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
            if locationCompletion != nil {
                manager.requestLocation()
            }
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
}
