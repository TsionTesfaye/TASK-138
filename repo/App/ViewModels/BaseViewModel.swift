import Foundation

/// Base ViewModel providing loading/error/empty state management.
/// All ViewModels inherit from this. No direct service calls in UI — all go through VMs.
class BaseViewModel {

    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case empty(String)
        case error(String)
    }

    private(set) var state: ViewState = .idle
    var onStateChange: ((ViewState) -> Void)?

    let container: ServiceContainer

    init(container: ServiceContainer) {
        self.container = container
    }

    func setState(_ newState: ViewState) {
        state = newState
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChange?(self.state)
        }
    }

    /// Check session validity before any action. Returns the current user or nil.
    func currentUser() -> User? {
        guard container.sessionService.isSessionValid() else {
            setState(.error("Session expired. Please log in again."))
            return nil
        }
        container.sessionService.recordActivity()
        return container.sessionService.currentUser
    }

    /// Execute a service call with automatic state management.
    func execute<T>(_ action: () -> ServiceResult<T>, onSuccess: (T) -> Void) {
        setState(.loading)
        let result = action()
        switch result {
        case .success(let value):
            setState(.loaded)
            onSuccess(value)
        case .failure(let error):
            setState(.error("\(error.code): \(error.message)"))
        }
    }
}
