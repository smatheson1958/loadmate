import SwiftData
import UIKit
import XCTest
@testable import loadMate3

@MainActor
final class VehiclePlatePhotoStoreTests: XCTestCase {
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

    func testSaveAndLoadPlatePhoto() throws {
        let profile = TestFixtures.motorhomeProfile()
        context.insert(profile)

        let image = makeImage(color: .red, size: CGSize(width: 400, height: 240))
        let fileName = try VehiclePlatePhotoStore.save(image: image, to: profile)

        XCTAssertFalse(fileName.isEmpty)
        XCTAssertEqual(profile.manufacturerPlatePhotoFileName, fileName)
        XCTAssertNil(profile.manufacturerPlatePhotoData)
        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: profile))
    }

    func testReplaceDeletesPreviousFile() throws {
        let profile = TestFixtures.caravanProfile()
        context.insert(profile)

        let firstName = try VehiclePlatePhotoStore.save(image: makeImage(color: .blue), to: profile)
        let firstURL = try VehiclePlatePhotoStore.fileURL(vehicleID: profile.id, fileName: firstName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        let secondName = try VehiclePlatePhotoStore.save(image: makeImage(color: .green), to: profile)
        XCTAssertNotEqual(firstName, secondName)
        XCTAssertEqual(profile.manufacturerPlatePhotoFileName, secondName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: profile))
    }

    func testDeleteClearsProfileAndFile() throws {
        let profile = TestFixtures.caravanProfile()
        context.insert(profile)

        let fileName = try VehiclePlatePhotoStore.save(image: makeImage(color: .orange), to: profile)
        let url = try VehiclePlatePhotoStore.fileURL(vehicleID: profile.id, fileName: fileName)

        VehiclePlatePhotoStore.delete(for: profile)

        XCTAssertTrue(profile.manufacturerPlatePhotoFileName.isEmpty)
        XCTAssertNil(profile.manufacturerPlatePhotoData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(VehiclePlatePhotoStore.loadImage(for: profile))
    }

    func testTransferCopiesPhotoToTargetProfile() throws {
        let source = TestFixtures.caravanProfile(name: "Source")
        let target = TestFixtures.caravanProfile(name: "Target")
        context.insert(source)
        context.insert(target)

        try VehiclePlatePhotoStore.save(image: makeImage(color: .purple), to: source)
        VehiclePlatePhotoStore.transferIfNeeded(from: source, to: target)

        XCTAssertFalse(target.manufacturerPlatePhotoFileName.isEmpty)
        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: target))
        XCTAssertNotEqual(source.id, target.id)
    }

    func testTransferDoesNotOverwriteExistingTargetPhoto() throws {
        let source = TestFixtures.motorhomeProfile(name: "Source MH")
        let target = TestFixtures.motorhomeProfile(name: "Target MH")
        context.insert(source)
        context.insert(target)

        try VehiclePlatePhotoStore.save(image: makeImage(color: .cyan), to: source)
        let targetName = try VehiclePlatePhotoStore.save(image: makeImage(color: .brown), to: target)

        VehiclePlatePhotoStore.transferIfNeeded(from: source, to: target)

        XCTAssertEqual(target.manufacturerPlatePhotoFileName, targetName)
    }

    func testLoadDoesNotUseCloudKitAssetBytesAfterSave() throws {
        let profile = TestFixtures.caravanProfile()
        context.insert(profile)

        let fileName = try VehiclePlatePhotoStore.save(image: makeImage(color: .red), to: profile)
        let url = try VehiclePlatePhotoStore.fileURL(vehicleID: profile.id, fileName: fileName)
        try FileManager.default.removeItem(at: url)

        XCTAssertNil(profile.manufacturerPlatePhotoData)
        XCTAssertNil(VehiclePlatePhotoStore.loadImage(for: profile))
    }

    func testTransferCopiesWhenTargetHasFilenameButMissingFile() throws {
        let source = TestFixtures.caravanProfile(name: "Source")
        let target = TestFixtures.caravanProfile(name: "Target")
        context.insert(source)
        context.insert(target)

        try VehiclePlatePhotoStore.save(image: makeImage(color: .purple), to: source)
        target.manufacturerPlatePhotoFileName = "missing-from-icloud.jpg"
        target.manufacturerPlatePhotoData = nil

        VehiclePlatePhotoStore.transferIfNeeded(from: source, to: target)

        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: target))
        XCTAssertNil(target.manufacturerPlatePhotoData)
        XCTAssertNotEqual(target.manufacturerPlatePhotoFileName, "missing-from-icloud.jpg")
    }

    func testResizeReducesLargeImages() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000)).image { _ in }
        let resized = VehiclePlatePhotoStore.resize(image: image, maxDimension: 2048)
        XCTAssertLessThanOrEqual(max(resized.size.width, resized.size.height), 2048)
    }

    private func makeImage(color: UIColor, size: CGSize = CGSize(width: 120, height: 80)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
