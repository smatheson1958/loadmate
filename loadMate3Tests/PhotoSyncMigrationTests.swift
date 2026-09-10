import SwiftData
import UIKit
import XCTest
@testable import loadMate3

@MainActor
final class PhotoSyncMigrationTests: XCTestCase {
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

    func testOffloadsLegacyCloudKitBytesOntoDiskAndClearsModelFields() throws {
        let profile = TestFixtures.motorhomeProfile()
        context.insert(profile)

        let plateName = try VehiclePlatePhotoStore.save(
            image: makeImage(color: .gray),
            to: profile
        )
        let plateData = try Data(contentsOf: try VehiclePlatePhotoStore.fileURL(vehicleID: profile.id, fileName: plateName))
        try FileManager.default.removeItem(
            at: try VehiclePlatePhotoStore.fileURL(vehicleID: profile.id, fileName: plateName)
        )
        profile.manufacturerPlatePhotoData = plateData

        let vehicleID = profile.id
        let accident = AccidentStore.createRecord(for: vehicleID, in: context)
        let accidentPhoto = try AccidentPhotoStore.save(
            image: makeImage(color: .blue, size: CGSize(width: 180, height: 120)),
            vehicleID: vehicleID,
            record: accident,
            kind: .road,
            in: context
        )
        let accidentData = try Data(contentsOf: try AccidentPhotoStore.fileURL(vehicleID: vehicleID, fileName: accidentPhoto.localFileName))
        try FileManager.default.removeItem(
            at: try AccidentPhotoStore.fileURL(vehicleID: vehicleID, fileName: accidentPhoto.localFileName)
        )
        accidentPhoto.imageData = accidentData

        let tyre = TyreRecord(vehicleID: vehicleID, position: .motorhomeFrontLeft)
        context.insert(tyre)
        let tyrePhoto = try TyrePhotoStore.save(
            image: makeImage(color: .red, size: CGSize(width: 180, height: 180)),
            vehicleID: vehicleID,
            record: tyre,
            inspection: nil,
            kind: .sidewall,
            in: context
        )
        let tyreData = try Data(contentsOf: try TyrePhotoStore.fileURL(vehicleID: vehicleID, fileName: tyrePhoto.localFileName))
        try FileManager.default.removeItem(
            at: try TyrePhotoStore.fileURL(vehicleID: vehicleID, fileName: tyrePhoto.localFileName)
        )
        tyrePhoto.imageData = tyreData

        let maintenance = MaintenanceRecord(vehicleID: vehicleID)
        context.insert(maintenance)
        let draft = try MaintenanceAttachmentStore.draft(
            image: makeImage(color: .green, size: CGSize(width: 200, height: 140)),
            fileType: .photo,
            displayName: "Service"
        )
        let attachment = try MaintenanceAttachmentStore.save(
            draft: draft,
            to: .maintenance(maintenance),
            in: context
        )
        let attachmentData = try Data(contentsOf: try MaintenanceAttachmentStore.fileURL(vehicleID: vehicleID, fileName: attachment.localFileName))
        let thumbnailName = try XCTUnwrap(attachment.thumbnailFileName)
        let thumbnailData = try Data(contentsOf: try MaintenanceAttachmentStore.fileURL(vehicleID: vehicleID, fileName: thumbnailName))
        try FileManager.default.removeItem(
            at: try MaintenanceAttachmentStore.fileURL(vehicleID: vehicleID, fileName: attachment.localFileName)
        )
        try FileManager.default.removeItem(
            at: try MaintenanceAttachmentStore.fileURL(vehicleID: vehicleID, fileName: thumbnailName)
        )
        attachment.fileData = attachmentData
        attachment.thumbnailData = thumbnailData
        try context.save()

        XCTAssertTrue(PhotoSyncMigration.offloadCloudKitAssetBytesIfNeeded(in: context))

        XCTAssertNil(profile.manufacturerPlatePhotoData)
        XCTAssertNil(accidentPhoto.imageData)
        XCTAssertNil(tyrePhoto.imageData)
        XCTAssertNil(attachment.fileData)
        XCTAssertNil(attachment.thumbnailData)

        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: profile))
        XCTAssertNotNil(AccidentPhotoStore.loadImage(for: accidentPhoto, vehicleID: vehicleID))
        XCTAssertNotNil(TyrePhotoStore.loadImage(for: tyrePhoto, vehicleID: vehicleID))
        XCTAssertNotNil(MaintenanceAttachmentStore.loadImage(for: attachment))
        XCTAssertNotNil(MaintenanceAttachmentStore.loadThumbnail(for: attachment))
        XCTAssertFalse(PhotoSyncMigration.offloadCloudKitAssetBytesIfNeeded(in: context))
    }

    func testSaveAlreadyKeepsAssetFieldsNilSoOffloadIsANoOp() throws {
        let profile = TestFixtures.caravanProfile()
        context.insert(profile)
        try VehiclePlatePhotoStore.save(image: makeImage(color: .gray), to: profile)
        try context.save()

        XCTAssertNil(profile.manufacturerPlatePhotoData)
        XCTAssertFalse(PhotoSyncMigration.offloadCloudKitAssetBytesIfNeeded(in: context))
        XCTAssertNotNil(VehiclePlatePhotoStore.loadImage(for: profile))
    }

    private func makeImage(color: UIColor, size: CGSize = CGSize(width: 80, height: 50)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
