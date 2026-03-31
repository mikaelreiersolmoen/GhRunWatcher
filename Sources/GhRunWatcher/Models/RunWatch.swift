import Foundation

struct RunWatch: Identifiable, Equatable {
    let id = UUID()
    let runId: String
    let repo: String?
}
