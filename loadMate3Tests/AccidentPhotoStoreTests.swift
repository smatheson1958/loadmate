import SwiftData
import UIKit
import XCTest
@testable import loadMate3

@MainActor
final class AccidentPhotoStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try LoadMateModelContainer.makePreview()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testCreateRecordAndSavePhoto() throws {
        let vehicleID = UUID()
        let record = AccidentStore.createRecord(for: vehicleID, in: context)
        XCTAssertEqual(record.vehicleID, vehicleID)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }

        let photo = try AccidentPhotoStore.save(
            image: image,
            vehicleID: vehicleID,
            record: record,
            kind: .plate,
            in: context
        )

        XCTAssertFalse(photo.localFileName.isEmpty)
        XCTAssertEqual(photo.kind, .plate)
        XCTAssertNil(photo.imageData)
        XCTAssertNotNil(AccidentPhotoStore.loadImage(for: photo, vehicleID: vehicleID))
        XCTAssertEqual(AccidentPhotoStore.photos(of: .plate, on: record).count, 1)
    }

    func testLoadDoesNotUseCloudKitAssetBytesAfterSave() throws {
        let vehicleID = UUID()
        let record = AccidentStore.createRecord(for: vehicleID, in: context)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 120)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 120))
        }
        let photo = try AccidentPhotoStore.save(
            image: image,
            vehicleID: vehicleID,
            record: record,
            kind: .road,
            in: context
        )
        let url = try AccidentPhotoStore.fileURL(vehicleID: vehicleID, fileName: photo.localFileName)
        try FileManager.default.removeItem(at: url)

        XCTAssertNil(photo.imageData)
        XCTAssertNil(AccidentPhotoStore.loadImage(for: photo, vehicleID: vehicleID))
    }

    func testPendingLookupIsMarkedOnNetworkError() async throws {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        let other = AccidentStore.addOtherVehicle(to: record, in: context)
        other.registration = "AB12 CDE"

        let failing = FailingVehicleLookupProvider(error: .noNetwork)
        let result = await AccidentStore.lookupUKPlate(
            "AB12 CDE",
            on: other,
            using: failing,
            in: context
        )

        XCTAssertEqual(result, .failure(.noNetwork))
        XCTAssertTrue(other.lookupPending)
        XCTAssertFalse(other.lookupErrorMessage.isEmpty)
    }

    func testApplyLookupSetsSORNFlag() {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        let other = AccidentStore.addOtherVehicle(to: record, in: context)
        let lookup = VehicleLookupResult(
            registration: "AB12CDE",
            displayRegistration: "AB12 CDE",
            make: "FORD",
            model: "FOCUS",
            colour: "BLUE",
            fuelType: nil,
            vehicleType: nil,
            yearOfManufacture: nil,
            monthOfFirstRegistration: nil,
            engineCapacityCc: nil,
            co2EmissionsGPerKm: nil,
            latestOdometerMiles: nil,
            taxStatus: "SORN",
            taxDueDate: nil,
            motStatus: "valid",
            motExpiryDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            motDaysRemaining: nil,
            lastMotResult: nil,
            lastMotDate: nil,
            firstMotDue: nil,
            totalMotTests: nil,
            motPassRate: nil,
            imminentMot: nil,
            markedForExport: false,
            ulezCompliant: nil,
            checkedAt: Date()
        )

        AccidentStore.applyLookup(lookup, to: other)
        XCTAssertTrue(other.redFlags.contains(.sorn))
        XCTAssertEqual(other.lookupMake, "FORD")
        XCTAssertFalse(other.lookupPending)
    }

    func testEditingPlateClearsPreviousVehicleDetails() {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        let other = AccidentStore.addOtherVehicle(to: record, in: context)
        AccidentStore.applyLookup(Self.makeLookup(registration: "AB12CDE", display: "AB12 CDE"), to: other)
        XCTAssertTrue(other.hasLookupSnapshot)

        other.registration = "HM58 SMD"
        XCTAssertTrue(other.lookupSnapshotIsStale)
        XCTAssertTrue(AccidentStore.clearLookupSnapshotIfStale(for: other))

        XCTAssertFalse(other.hasLookupSnapshot)
        XCTAssertEqual(other.lookupMake, "")
        XCTAssertEqual(other.lookupMotStatus, "")
        XCTAssertEqual(other.lookupTaxStatus, "")
        XCTAssertNil(other.lookupCheckedAt)
        XCTAssertTrue(other.redFlags.isEmpty)
    }

    func testFailedLookupForNewPlateDropsPreviousVehicleDetails() async {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        let other = AccidentStore.addOtherVehicle(to: record, in: context)
        AccidentStore.applyLookup(Self.makeLookup(registration: "AB12CDE", display: "AB12 CDE"), to: other)

        other.registration = "HM58 SMD"
        let failing = FailingVehicleLookupProvider(error: .notFound)
        let result = await AccidentStore.lookupUKPlate("HM58 SMD", on: other, using: failing, in: context)

        XCTAssertEqual(result, .failure(.notFound))
        XCTAssertFalse(other.hasLookupSnapshot)
        XCTAssertFalse(other.lookupErrorMessage.isEmpty)
    }

    func testFailedLookupKeepsDetailsForSamePlate() async {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        let other = AccidentStore.addOtherVehicle(to: record, in: context)
        AccidentStore.applyLookup(Self.makeLookup(registration: "AB12CDE", display: "AB12 CDE"), to: other)

        let failing = FailingVehicleLookupProvider(error: .noNetwork)
        _ = await AccidentStore.lookupUKPlate("AB12 CDE", on: other, using: failing, in: context)

        XCTAssertTrue(other.hasLookupSnapshot)
        XCTAssertEqual(other.lookupMake, "FORD")
    }

    private static func makeLookup(registration: String, display: String) -> VehicleLookupResult {
        VehicleLookupResult(
            registration: registration,
            displayRegistration: display,
            make: "FORD",
            model: "FOCUS",
            colour: "BLUE",
            fuelType: nil,
            vehicleType: nil,
            yearOfManufacture: nil,
            monthOfFirstRegistration: nil,
            engineCapacityCc: nil,
            co2EmissionsGPerKm: nil,
            latestOdometerMiles: nil,
            taxStatus: "taxed",
            taxDueDate: nil,
            motStatus: "valid",
            motExpiryDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            motDaysRemaining: nil,
            lastMotResult: nil,
            lastMotDate: nil,
            firstMotDue: nil,
            totalMotTests: nil,
            motPassRate: nil,
            imminentMot: nil,
            markedForExport: false,
            ulezCompliant: nil,
            checkedAt: Date()
        )
    }
}

private struct FailingVehicleLookupProvider: VehicleLookupProviding {
    let error: VehicleLookupError

    func lookup(registration: String, forceRefresh: Bool) async throws -> VehicleLookupResult {
        throw error
    }
}
