import Foundation

enum LeadType: String, CaseIterable, Codable {
    case quoteRequest = "quote_request"
    case appointment = "appointment"
    case generalContact = "general_contact"
}
