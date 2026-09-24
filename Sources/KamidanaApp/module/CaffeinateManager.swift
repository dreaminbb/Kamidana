import Foundation
import IOKit.pwr_mgt

@MainActor
final class CaffeinateManager: ObservableObject {
    static let shared = CaffeinateManager()

    @Published private(set) var isActive: Bool = false {
        didSet {
            if isActive {
                print("Caffain active")
                createAssertion()
            } else {
                print("Caffain deactive")
                releaseAssertion()
            }
        }
    }

    private var assertionID: IOPMAssertionID = 0

    func toggle() {
        isActive.toggle()
    }

    private func createAssertion() {
        print("Creating assertion...")
        guard assertionID == 0 else { return }
        let reasonForActivity = "Kamidana Caffeinate Widget" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &assertionID
        )
        if result != kIOReturnSuccess {
            assertionID = 0
            isActive = false
            print("Failed to create assertion: \(result)")
        } else {
            print("Assertion created with ID: \(assertionID)")
        }

    }

    nonisolated private func releaseAssertion() {
        Task { @MainActor in
            if assertionID != 0 {
                IOPMAssertionRelease(assertionID)
                assertionID = 0
            }
        }
    }

    deinit {
        releaseAssertion()
    }
}
