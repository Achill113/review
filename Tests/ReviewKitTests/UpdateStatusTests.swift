import Testing
@testable import ReviewKit

@Suite
struct UpdateStatusTests {
    private let waiting = AvailableUpdate(head: "abc1234def", commits: [.init(sha: "abc1234", subject: "Newer")])

    @Test("An update that is waiting offers to install")
    func offersInstall() {
        let status = UpdateStatus(update: waiting, hasChecked: true)

        #expect(status.primaryAction == .install)
        #expect(status.isPrimaryActionEnabled)
    }

    @Test("Nothing waiting offers nothing")
    func offersNothing() {
        #expect(UpdateStatus(hasChecked: true).primaryAction == nil)
    }

    @Test("A failed check retries the check, even with an earlier update still waiting")
    func failedCheckRetriesCheck() {
        #expect(UpdateStatus(phase: .checkFailed("offline"), update: waiting, hasChecked: true).primaryAction == .retryCheck)
        #expect(UpdateStatus(phase: .checkFailed("offline")).primaryAction == .retryCheck)
    }

    @Test("A failed install retries the install")
    func failedInstallRetriesInstall() {
        let status = UpdateStatus(phase: .installFailed("✗ swift build failed"), update: waiting, hasChecked: true)

        #expect(status.primaryAction == .retryInstall)
    }

    @Test("The action waits while a check or an install is running")
    func disabledWhileBusy() {
        #expect(!UpdateStatus(phase: .checking, update: waiting, hasChecked: true).isPrimaryActionEnabled)
        #expect(!UpdateStatus(phase: .installing, update: waiting, hasChecked: true).isPrimaryActionEnabled)
    }

    @Test("A copy that must not install can still retry a check")
    func cannotInstall() {
        #expect(!UpdateStatus(update: waiting, hasChecked: true, canInstall: false).isPrimaryActionEnabled)
        #expect(!UpdateStatus(phase: .installFailed("log"), update: waiting, canInstall: false).isPrimaryActionEnabled)
        #expect(UpdateStatus(phase: .checkFailed("offline"), canInstall: false).isPrimaryActionEnabled)
    }

    @Test("The hourly check leaves a failed install's log alone; asking for a check does not")
    func scheduledCheckKeepsInstallFailure() {
        let status = UpdateStatus(phase: .installFailed("log"), update: waiting, hasChecked: true)

        #expect(!status.allowsCheck(.scheduled))
        #expect(status.allowsCheck(.requested))
    }

    @Test("No check starts while one is running or an install is")
    func noCheckWhileBusy() {
        for reason in [UpdateStatus.CheckReason.scheduled, .requested] {
            #expect(!UpdateStatus(phase: .checking).allowsCheck(reason))
            #expect(!UpdateStatus(phase: .installing).allowsCheck(reason))
            #expect(UpdateStatus().allowsCheck(reason))
            #expect(UpdateStatus(phase: .checkFailed("offline")).allowsCheck(reason))
        }
    }

    @Test("Before the first check has answered, the answer is still awaited, not up to date")
    func awaitsFirstAnswer() {
        #expect(UpdateStatus().isAwaitingAnswer)
        #expect(UpdateStatus(phase: .checking).isAwaitingAnswer)
        #expect(!UpdateStatus(hasChecked: true).isAwaitingAnswer)
        #expect(!UpdateStatus(phase: .checking, update: waiting, hasChecked: true).isAwaitingAnswer)
        #expect(!UpdateStatus(phase: .checkFailed("offline")).isAwaitingAnswer)
    }
}
