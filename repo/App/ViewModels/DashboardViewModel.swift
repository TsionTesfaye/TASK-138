import Foundation

final class DashboardViewModel: BaseViewModel {

    struct DashboardData {
        let username: String
        let role: String
        let newLeadCount: Int
        let slaViolationCount: Int
        let pendingAppealCount: Int
        let pendingVarianceCount: Int
        let unconfirmedAppointmentCount: Int
    }

    private(set) var data: DashboardData?
    var site: String = ""

    override init(container: ServiceContainer) {
        super.init(container: container)
        site = container.currentSite
    }

    func load() {
        guard let user = currentUser() else { return }
        setState(.loading)

        var newLeads = 0
        if case .success(let leads) = container.leadService.findByStatus(by: user, site: site, .new) {
            newLeads = leads.count
        }

        let violations = container.slaService.violationCounts(site: site)

        var pendingAppeals = 0
        if case .success(let submitted) = container.appealService.findByStatus(by: user, site: site, .submitted) {
            pendingAppeals += submitted.count
        }
        if case .success(let underReview) = container.appealService.findByStatus(by: user, site: site, .underReview) {
            pendingAppeals += underReview.count
        }

        var pendingVariances = 0
        if case .success(let v) = container.inventoryService.findPendingVariances(by: user, site: site) {
            pendingVariances = v.count
        }

        var unconfirmed = 0
        if case .success(let appts) = container.appointmentService.getUnconfirmedWithinSLA(by: user, site: site) {
            unconfirmed = appts.count
        }

        data = DashboardData(
            username: user.username,
            role: user.role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
            newLeadCount: newLeads,
            slaViolationCount: violations.leadViolations + violations.appointmentViolations,
            pendingAppealCount: pendingAppeals,
            pendingVarianceCount: pendingVariances,
            unconfirmedAppointmentCount: unconfirmed
        )

        setState(.loaded)
    }
}
