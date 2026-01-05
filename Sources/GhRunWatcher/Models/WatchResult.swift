import Foundation

enum WatchResult {
    case success(exitCode: Int32, lastLine: String?)
    case workflowFailed(exitCode: Int32, lastLine: String?)
    case failure(exitCode: Int32, message: String)
    case startFailure(message: String)
}
