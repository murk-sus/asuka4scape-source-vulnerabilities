import XCTest
@testable import natsuk1

final class DeviceNameTests: XCTestCase {
    func testMachineID() {
        XCTAssertFalse(DeviceName.machineID().isEmpty)
    }
}
