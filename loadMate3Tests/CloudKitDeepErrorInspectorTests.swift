import CloudKit
import SwiftData
import XCTest
@testable import loadMate3

final class CloudKitDeepErrorInspectorTests: XCTestCase {
    func testInspectIncludesStartAndEndMarkers() {
        let error = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)"]
        )

        let dump = CloudKitDeepErrorInspector.inspect(error: error)

        XCTAssertTrue(dump.contains(CloudKitDeepErrorInspector.startMarker))
        XCTAssertTrue(dump.contains(CloudKitDeepErrorInspector.endMarker))
        XCTAssertTrue(dump.contains("Swift error type:"))
        XCTAssertTrue(dump.contains("NSError domain: CKErrorDomain"))
        XCTAssertTrue(dump.contains("NSError code: 2"))
        XCTAssertTrue(dump.contains("CKError readable code: partialFailure"))
        XCTAssertTrue(dump.contains("partialErrorsByItemID: NONE"))
        XCTAssertTrue(dump.contains("NSUnderlyingErrorKey: NONE"))
        XCTAssertTrue(dump.contains("NSDetailedErrorsKey: NONE"))
        XCTAssertTrue(dump.contains("CKPartialErrorsByItemIDKey: absent"))
    }

    func testInspectEnumeratesEveryPartialFailureItem() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.serverRejectedRequest.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Did not find record type 'CD_WarrantyPlan'",
                NSDebugDescriptionErrorKey: "CKError 15",
            ]
        )
        let first = CKRecord.ID(recordName: "warranty-1")
        let second = CKRecord.ID(recordName: "warranty-2")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "Partial failure",
                "CKPartialErrorsByItemIDKey": [first: nested, second: nested],
            ]
        )

        let dump = CloudKitDeepErrorInspector.inspect(error: partial)

        XCTAssertTrue(dump.contains("partialErrorsByItemID: 2 items"))
        XCTAssertTrue(dump.contains("Partial failure item:"))
        XCTAssertTrue(dump.contains("warranty-1"))
        XCTAssertTrue(dump.contains("warranty-2"))
        XCTAssertTrue(dump.contains("Nested CKError code/name: 15 (serverRejectedRequest)"))
        XCTAssertTrue(dump.contains("CKPartialErrorsByItemIDKey: present"))
        XCTAssertTrue(dump.contains("NSDebugDescription"))
    }

    func testInspectWalksCocoaWrappedPartialFailureAndUserInfoKeys() {
        let nested = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.invalidArguments.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Field 'recordName' is not marked queryable"]
        )
        let recordID = CKRecord.ID(recordName: "CD_AppState:1")
        let partial = NSError(
            domain: CKErrorDomain,
            code: CKError.Code.partialFailure.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: "The operation couldn’t be completed. (CKErrorDomain error 2.)",
                "CKPartialErrorsByItemIDKey": [recordID: nested],
            ]
        )
        let cocoa = NSError(
            domain: NSCocoaErrorDomain,
            code: 134406,
            userInfo: [
                NSLocalizedDescriptionKey: "CloudKit mirroring failed",
                NSUnderlyingErrorKey: partial,
            ]
        )

        let dump = CloudKitDeepErrorInspector.inspect(error: cocoa)

        XCTAssertTrue(dump.contains("NSError domain: NSCocoaErrorDomain"))
        XCTAssertTrue(dump.contains("NSError code: 134406"))
        XCTAssertTrue(dump.contains("NSUnderlyingErrorKey: present"))
        XCTAssertTrue(dump.contains("CKError readable code: partialFailure"))
        XCTAssertTrue(dump.contains("CD_AppState:1"))
        XCTAssertTrue(dump.contains("Nested CKError code/name: 12 (invalidArguments)"))
        XCTAssertTrue(dump.contains("not marked queryable"))
    }

    @MainActor
    func testReportKeepsLastDetailedFailureSeparateFromHistory() {
        let snapshot = SyncDebugSnapshot(
            accountStatus: .available,
            lastCheckedAt: nil,
            lastErrorDescription: "CKErrorDomain error 2",
            lastSyncEventSummary: "Export FAILED",
            recentSyncEventLines: ["EXPORT failed"],
            lastSuccessfulImportAt: nil,
            lastSuccessfulExportAt: nil,
            lastDetailedCloudKitFailure: """
            === DEEP CLOUDKIT ERROR INSPECTION START ===
            CKError readable code: partialFailure
            partialErrorsByItemID: NONE
            === DEEP CLOUDKIT ERROR INSPECTION END ===
            """,
            lastMinimalSyncTestResult: "Not run",
            cloudKitIsolationTestReport: "CloudKit Model Isolation Test\nStatus: Not run",
            isRegisteredForRemoteNotifications: true,
            pushRegistrationDetail: "Registered",
            cloudKitSchemaDetail: "CloudKit connectivity/schema probe:\nCD_AppState reachable",
            exportPoisonReport: "",
            deviceName: "Test iPad",
            bundleID: "test.bundle",
            appVersion: "4.0",
            buildNumber: "49",
            vehicleProfileCount: 2,
            tripCount: 2,
            loadedItemCount: 0,
            libraryItemCount: 0,
            checklistSectionCount: 5,
            checklistItemCount: 68,
            appStateCount: 1,
            activeProfileName: "My Caravan",
            syncProbeSequence: 0,
            syncProbeValue: "",
            syncProbeUpdatedAt: nil,
            syncProbeUpdatedBy: ""
        )

        let report = SyncDebugLogger.shared.makeReport(snapshot: snapshot)

        XCTAssertTrue(report.contains("Last Detailed CloudKit Failure"))
        XCTAssertTrue(report.contains(CloudKitDeepErrorInspector.startMarker))
        XCTAssertTrue(report.contains("partialErrorsByItemID: NONE"))
        XCTAssertTrue(report.contains("CloudKit connectivity/schema probe:"))
        XCTAssertFalse(report.contains("Schema OK — CD_AppState reachable in this environment"))
        XCTAssertTrue(report.contains("SwiftData CloudKit model audit"))
        XCTAssertTrue(report.contains("CloudKit Model Isolation Test"))
    }

    func testModelAuditDoesNotFlagBlankOriginalNameAsRename() {
        XCTAssertFalse(CloudKitModelAudit.isGenuineRename(originalName: "", currentName: "name"))
        XCTAssertFalse(CloudKitModelAudit.isGenuineRename(originalName: "   ", currentName: "name"))
        XCTAssertFalse(CloudKitModelAudit.isGenuineRename(originalName: "name", currentName: "name"))
        XCTAssertTrue(CloudKitModelAudit.isGenuineRename(originalName: "old_name", currentName: "name"))

        let report = CloudKitModelAudit.report()
        XCTAssertFalse(report.contains("renamed from  "))
        XCTAssertFalse(report.contains("renamed from ]"))
        XCTAssertFalse(report.contains("originalName=]"))
    }

    func testIsolationStoreIsSeparateFromProductionAndAppStateOnly() {
        let isolationURL = LoadMateModelContainer.appStateOnlyIsolationStoreURL
        XCTAssertTrue(isolationURL.path.contains("LoadMateCloudKitIsolation"))
        XCTAssertTrue(isolationURL.path.contains("AppStateOnly"))
        XCTAssertEqual(LoadMateModelContainer.appStateOnlyIsolationSchema.entities.count, 1)
        XCTAssertEqual(LoadMateModelContainer.appStateOnlyIsolationSchema.entities.first?.name, "AppState")
        XCTAssertGreaterThan(LoadMateModelContainer.schema.entities.count, 1)

        let coreURL = LoadMateModelContainer.coreVehicleIsolationStoreURL
        XCTAssertTrue(coreURL.path.contains("LoadMateCloudKitIsolation"))
        XCTAssertTrue(coreURL.path.contains("CoreVehicle"))
        XCTAssertFalse(coreURL.path.contains("default.store"))
        let coreNames = Set(LoadMateModelContainer.coreVehicleIsolationSchema.entities.map(\.name))
        XCTAssertTrue(coreNames.contains("AppState"))
        XCTAssertTrue(coreNames.contains("VehicleProfile"))
        XCTAssertTrue(coreNames.contains("Trip"))
        XCTAssertTrue(coreNames.contains("ChecklistSection"), "SwiftData registers ChecklistSection as a VehicleProfile relationship destination")
        XCTAssertTrue(coreNames.contains("ChecklistItem"))
        XCTAssertFalse(coreNames.contains("AccidentRecord"))
        XCTAssertFalse(coreNames.contains("TripRecord"))
        XCTAssertLessThan(coreNames.count, LoadMateModelContainer.schema.entities.count)
        XCTAssertNotEqual(isolationURL, coreURL)
    }

    func testChecklistIsolationStoreIsSeparateAndOmitsUnrelatedModels() {
        let checklistURL = LoadMateModelContainer.checklistIsolationStoreURL
        XCTAssertTrue(checklistURL.path.contains("LoadMateCloudKitIsolation"))
        XCTAssertTrue(checklistURL.path.contains("ChecklistModel"))
        XCTAssertNotEqual(checklistURL, LoadMateModelContainer.coreVehicleIsolationStoreURL)
        XCTAssertNotEqual(checklistURL, LoadMateModelContainer.appStateOnlyIsolationStoreURL)

        let names = Set(LoadMateModelContainer.checklistIsolationSchema.entities.map(\.name))
        XCTAssertTrue(names.isSuperset(of: ["AppState", "VehicleProfile", "Trip", "ChecklistSection", "ChecklistItem"]))
        XCTAssertTrue(names.contains("ChecklistGroup"), "SwiftData registers ChecklistGroup as a relationship destination")
        XCTAssertFalse(names.contains("AccidentRecord"))
        XCTAssertFalse(names.contains("TripRecord"))
        XCTAssertFalse(names.contains("TyreRecord"))
        XCTAssertLessThan(names.count, LoadMateModelContainer.schema.entities.count)
    }

    func testChecklistIsolationSchemaCanSaveMinimalRecordsInMemory() throws {
        let schema = LoadMateModelContainer.checklistIsolationSchema
        let configuration = ModelConfiguration(
            "ChecklistIsolationInMemory",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let section = ChecklistSection(title: "CloudKit Test Section", sortOrder: 0)
        context.insert(section)
        let item = ChecklistItem(title: "CloudKit Test Item", isChecked: false, sortOrder: 0, section: section)
        context.insert(item)
        try context.save()
        XCTAssertEqual((try context.fetch(FetchDescriptor<ChecklistSection>())).count, 1)
        XCTAssertEqual((try context.fetch(FetchDescriptor<ChecklistItem>())).count, 1)
    }

    func testIsolationReportDescribesAppStateOnlyOutcome() {
        var report = CloudKitIsolationTestReport()
        report.status = .passed
        report.localStoreCreated = true
        report.localSave = "succeeded"
        report.insertedAppStateCount = 1
        report.setup = "succeeded"
        report.export = "succeeded"
        report.probeValue = "appstate-isolation-test"
        report.conclusion = "APPSTATE-ONLY TEST PASSED"

        let text = report.formatted
        XCTAssertTrue(text.contains("CloudKit Model Isolation Test"))
        XCTAssertTrue(text.contains("Test: AppState only"))
        XCTAssertTrue(text.contains("Status: PASSED"))
        XCTAssertTrue(text.contains("AppState = 1"))
        XCTAssertTrue(text.contains("Local save:"))
        XCTAssertTrue(text.contains("succeeded"))
        XCTAssertTrue(text.contains("SETUP succeeded"))
        XCTAssertTrue(text.contains("EXPORT succeeded"))
        XCTAssertTrue(text.contains("APPSTATE-ONLY TEST PASSED"))
    }

    func testIsolationReportDescribesCoreVehicleOutcome() {
        var report = CloudKitIsolationTestReport()
        report.scenario = .coreVehicle
        report.testName = CloudKitIsolationScenario.coreVehicle.testName
        report.modelContainerLines = CloudKitIsolationScenario.coreVehicle.modelContainerLines
        report.relationshipLines = CloudKitIsolationScenario.coreVehicle.relationshipLines
        report.status = .failed
        report.localStoreCreated = true
        report.localSave = "succeeded"
        report.insertedAppStateCount = 1
        report.insertedVehicleProfileCount = 1
        report.insertedTripCount = 1
        report.setup = "succeeded"
        report.export = "failed"
        report.probeValue = "core-vehicle-isolation-test"
        report.conclusion = "CORE VEHICLE TEST FAILED"

        let text = report.formatted
        XCTAssertTrue(text.contains("Test: AppState + VehicleProfile + Trip"))
        XCTAssertTrue(text.contains("Status: FAILED"))
        XCTAssertTrue(text.contains("VehicleProfile = 1"))
        XCTAssertTrue(text.contains("Trip = 1"))
        XCTAssertTrue(text.contains("Trip.profile -> VehicleProfile"))
        XCTAssertTrue(text.contains("VehicleProfile.trips -> Trip"))
        XCTAssertTrue(text.contains("CORE VEHICLE TEST FAILED"))
        XCTAssertTrue(text.contains("EXPORT failed"))
    }

    func testIsolationReportDescribesChecklistOutcome() {
        var report = CloudKitIsolationTestReport()
        report.scenario = .checklist
        report.testName = CloudKitIsolationScenario.checklist.testName
        report.modelContainerLines = CloudKitIsolationScenario.checklist.modelContainerLines
        report.relationshipLines = CloudKitIsolationScenario.checklist.relationshipLines
        report.status = .passed
        report.localStoreCreated = true
        report.localSave = "succeeded"
        report.insertedAppStateCount = 1
        report.insertedVehicleProfileCount = 1
        report.insertedTripCount = 1
        report.insertedChecklistSectionCount = 1
        report.insertedChecklistItemCount = 1
        report.setup = "succeeded"
        report.export = "succeeded"
        report.probeValue = "checklist-isolation-test"
        report.conclusion = "CHECKLIST MODEL TEST PASSED"

        let text = report.formatted
        XCTAssertTrue(text.contains("Test: AppState + VehicleProfile + Trip + ChecklistSection + ChecklistItem"))
        XCTAssertTrue(text.contains("Status: PASSED"))
        XCTAssertTrue(text.contains("ChecklistSection = 1"))
        XCTAssertTrue(text.contains("ChecklistItem = 1"))
        XCTAssertTrue(text.contains("ChecklistSection.items -> ChecklistItem"))
        XCTAssertTrue(text.contains("ChecklistItem.section -> ChecklistSection"))
        XCTAssertTrue(text.contains("ChecklistSection.profile -> VehicleProfile"))
        XCTAssertTrue(text.contains("CHECKLIST MODEL TEST PASSED"))
        XCTAssertTrue(text.contains("EXPORT succeeded"))
    }

    func testChecklistGroupLoadedAndLibraryIsolationStoresAreSeparate() {
        XCTAssertTrue(LoadMateModelContainer.checklistGroupIsolationStoreURL.path.contains("ChecklistGroup"))
        XCTAssertTrue(LoadMateModelContainer.loadedItemIsolationStoreURL.path.contains("LoadedItem"))
        XCTAssertTrue(LoadMateModelContainer.libraryItemIsolationStoreURL.path.contains("LibraryItem"))
        XCTAssertNotEqual(
            LoadMateModelContainer.checklistGroupIsolationStoreURL,
            LoadMateModelContainer.checklistIsolationStoreURL
        )
        XCTAssertNotEqual(
            LoadMateModelContainer.loadedItemIsolationStoreURL,
            LoadMateModelContainer.libraryItemIsolationStoreURL
        )

        let groupNames = Set(LoadMateModelContainer.checklistGroupIsolationSchema.entities.map(\.name))
        XCTAssertTrue(groupNames.isSuperset(of: ["ChecklistSection", "ChecklistGroup", "ChecklistItem"]))
        XCTAssertFalse(groupNames.contains("AccidentRecord"))
        XCTAssertFalse(groupNames.contains("TripRecord"))

        let loadedNames = Set(LoadMateModelContainer.loadedItemIsolationSchema.entities.map(\.name))
        XCTAssertTrue(loadedNames.isSuperset(of: ["LoadedItem", "LibraryItem", "Trip", "VehicleProfile"]))
        XCTAssertTrue(loadedNames.contains("ChecklistItem"), "SwiftData registers checklist models via VehicleProfile")
        XCTAssertFalse(loadedNames.contains("AccidentRecord"))
        XCTAssertFalse(loadedNames.contains("TripRecord"))

        let libraryNames = Set(LoadMateModelContainer.libraryItemIsolationSchema.entities.map(\.name))
        XCTAssertTrue(libraryNames.isSuperset(of: ["LibraryItem", "AppState", "VehicleProfile"]))
        XCTAssertTrue(libraryNames.contains("ChecklistSection"), "SwiftData registers checklist models via VehicleProfile")
        XCTAssertFalse(libraryNames.contains("AccidentRecord"))
        XCTAssertFalse(libraryNames.contains("TripRecord"))
    }

    func testIsolationReportDescribesChecklistGroupOutcome() {
        var report = CloudKitIsolationTestReport()
        report.scenario = .checklistGroup
        report.testName = CloudKitIsolationScenario.checklistGroup.testName
        report.modelContainerLines = CloudKitIsolationScenario.checklistGroup.modelContainerLines
        report.relationshipLines = CloudKitIsolationScenario.checklistGroup.relationshipLines
        report.status = .passed
        report.insertedAppStateCount = 1
        report.insertedVehicleProfileCount = 1
        report.insertedTripCount = 1
        report.insertedChecklistSectionCount = 1
        report.insertedChecklistGroupCount = 1
        report.insertedChecklistItemCount = 1
        report.localSave = "succeeded"
        report.export = "succeeded"
        report.conclusion = "CHECKLIST GROUP TEST PASSED"

        let text = report.formatted
        XCTAssertTrue(text.contains("ChecklistGroup = 1"))
        XCTAssertTrue(text.contains("ChecklistItem.group -> ChecklistGroup"))
        XCTAssertTrue(text.contains("Requested:"))
        XCTAssertTrue(text.contains("CHECKLIST GROUP TEST PASSED"))
    }

    func testIsolationReportDescribesLoadedItemOutcome() {
        var report = CloudKitIsolationTestReport()
        report.scenario = .loadedItem
        report.testName = CloudKitIsolationScenario.loadedItem.testName
        report.modelContainerLines = CloudKitIsolationScenario.loadedItem.modelContainerLines
        report.relationshipLines = CloudKitIsolationScenario.loadedItem.relationshipLines
        report.status = .passed
        report.insertedAppStateCount = 1
        report.insertedVehicleProfileCount = 1
        report.insertedTripCount = 1
        report.insertedLibraryItemCount = 1
        report.insertedLoadedItemCount = 1
        report.localSave = "succeeded"
        report.export = "succeeded"
        report.conclusion = "LOADED ITEM TEST PASSED"

        let text = report.formatted
        XCTAssertTrue(text.contains("LoadedItem = 1"))
        XCTAssertTrue(text.contains("LoadedItem.item -> LibraryItem"))
        XCTAssertTrue(text.contains("LibraryItem was included because LoadedItem.item is required"))
        XCTAssertTrue(text.contains("LOADED ITEM TEST PASSED"))
    }

    func testIsolationReportDescribesLibraryItemOutcome() {
        var report = CloudKitIsolationTestReport()
        report.scenario = .libraryItem
        report.testName = CloudKitIsolationScenario.libraryItem.testName
        report.modelContainerLines = CloudKitIsolationScenario.libraryItem.modelContainerLines
        report.relationshipLines = CloudKitIsolationScenario.libraryItem.relationshipLines
        report.status = .passed
        report.insertedAppStateCount = 1
        report.insertedVehicleProfileCount = 1
        report.insertedLibraryItemCount = 1
        report.localSave = "succeeded"
        report.export = "succeeded"
        report.conclusion = "LIBRARY ITEM TEST PASSED"

        let text = report.formatted
        XCTAssertTrue(text.contains("LibraryItem = 1"))
        XCTAssertTrue(text.contains("LoadedItem = 0"))
        XCTAssertTrue(text.contains("LIBRARY ITEM TEST PASSED"))
        XCTAssertEqual(CloudKitIsolationScenario.restored(from: text), .libraryItem)
        XCTAssertEqual(
            CloudKitIsolationScenario.restored(from: CloudKitIsolationScenario.loadedItem.testName),
            .loadedItem
        )
    }

    func testChecklistGroupAndLoadIsolationSchemasCanSaveInMemory() throws {
        let groupConfig = ModelConfiguration(
            "ChecklistGroupIsolationInMemory",
            schema: LoadMateModelContainer.checklistGroupIsolationSchema,
            isStoredInMemoryOnly: true
        )
        let groupContainer = try ModelContainer(
            for: LoadMateModelContainer.checklistGroupIsolationSchema,
            configurations: [groupConfig]
        )
        let groupContext = ModelContext(groupContainer)
        let section = ChecklistSection(title: "Section", sortOrder: 0)
        groupContext.insert(section)
        let group = ChecklistGroup(title: "Group", sortOrder: 0, section: section)
        groupContext.insert(group)
        groupContext.insert(ChecklistItem(title: "Item", group: group))
        try groupContext.save()

        let loadConfig = ModelConfiguration(
            "LoadedItemIsolationInMemory",
            schema: LoadMateModelContainer.loadedItemIsolationSchema,
            isStoredInMemoryOnly: true
        )
        let loadContainer = try ModelContainer(
            for: LoadMateModelContainer.loadedItemIsolationSchema,
            configurations: [loadConfig]
        )
        let loadContext = ModelContext(loadContainer)
        let profile = VehicleProfile(name: "Vehicle")
        loadContext.insert(profile)
        let trip = Trip(name: "Trip", profile: profile)
        loadContext.insert(trip)
        let library = LibraryItem(name: "Item", weightKg: 1)
        loadContext.insert(library)
        loadContext.insert(LoadedItem(item: library, trip: trip))
        try loadContext.save()
    }

    func testMinimalSyncStatusDoesNotTreatLocalProbeAsSuccess() {
        XCTAssertEqual(MinimalSyncTestStatus.notRun.rawValue, "Not run")
        XCTAssertEqual(MinimalSyncTestStatus.waitingForCloudKit.rawValue, "Waiting for CloudKit")
        XCTAssertEqual(MinimalSyncTestStatus.exportSucceeded.rawValue, "CloudKit export succeeded")
        XCTAssertNotEqual(MinimalSyncTestStatus.localSaveSucceeded, MinimalSyncTestStatus.exportSucceeded)
    }

    func testModelAuditListsCloudKitModelsAndDoesNotMutateSchema() {
        let report = CloudKitModelAudit.report()

        XCTAssertTrue(report.contains("Model name: AppState"))
        XCTAssertTrue(report.contains("Model name: VehicleProfile"))
        XCTAssertTrue(report.contains("Model name: Trip"))
        XCTAssertTrue(report.contains("Model name: ChecklistSection"))
        XCTAssertTrue(report.contains("Model name: ChecklistItem"))
        XCTAssertTrue(report.contains("Attributes:"))
        XCTAssertTrue(report.contains("Relationships:"))
        XCTAssertTrue(report.contains("CloudKit-sensitive flags"))
    }

    func testSeedIsolationDefaultsToOff() {
        SyncDebugSeedIsolation.overrideForTests = false
        XCTAssertFalse(SyncDebugSeedIsolation.isAutomaticSeedingSuppressed)
        SyncDebugSeedIsolation.overrideForTests = true
        XCTAssertTrue(SyncDebugSeedIsolation.isAutomaticSeedingSuppressed)
        SyncDebugSeedIsolation.overrideForTests = nil
    }

    func testAutomaticSeedPolicyIsDisabledForCleanStartBuild() {
        XCTAssertFalse(LoadMateSeedPolicy.automaticVehicleAndChecklistSeedEnabled)
        XCTAssertTrue(LoadMateSeedPolicy.statusLine.contains("DISABLED"))
    }

    @MainActor
    func testEnsureInitialDataDoesNotCreateFactoryVehiclesWhenSeedDisabled() throws {
        let schema = Schema([AppState.self, VehicleProfile.self, Trip.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let result = VehicleProfileStore.ensureInitialData(in: context, profiles: [], appState: nil)
        XCTAssertTrue(result.profiles.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<VehicleProfile>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Trip>()).isEmpty)
    }

    @MainActor
    func testChecklistEnsureSeedDataDoesNotInsertTemplateWhenSeedDisabled() throws {
        let schema = Schema([
            AppState.self,
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let state = AppState()
        context.insert(state)

        ChecklistViewModel().ensureSeedData(in: context, existingSections: [], appState: state)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChecklistSection>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChecklistGroup>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChecklistItem>()).isEmpty)
        XCTAssertFalse(state.didSeedDefaultChecklist)
    }

    func testIsolationWritesStayDisabledAgainstProduction() {
        XCTAssertFalse(CloudKitEnvironment.isolationWritesEnabled)
        XCTAssertFalse(CloudKitEnvironment.isDiagnosticContainerConfigured)
        XCTAssertEqual(CloudKitEnvironment.productionContainerID, "iCloud.com.curleybracketsengineering.loadMate3")
        XCTAssertTrue(CloudKitEnvironment.productionDisabledMessage.contains("temporarily disabled"))
    }

    func testDiagnosticMarkersDoNotFlagFactoryVehicleNames() {
        XCTAssertNotNil(CloudKitDiagnosticMarkers.isClearlyDiagnosticName("CloudKit Test Section"))
        XCTAssertNotNil(CloudKitDiagnosticMarkers.isClearlyDiagnosticName("CloudKit Test Vehicle"))
        XCTAssertNil(CloudKitDiagnosticMarkers.isClearlyDiagnosticName("My Caravan"))
        XCTAssertNil(CloudKitDiagnosticMarkers.isClearlyDiagnosticName("Default"))
        XCTAssertEqual(CloudKitDiagnosticMarkers.isPossiblyDiagnosticName("Test"), "title Test")
        XCTAssertNotNil(CloudKitDiagnosticMarkers.probeMarker(in: "checklist-isolation-ABC"))
    }

    func testCountDeltaDescribesProfileChanges() {
        var before = SyncDebugEntityCounts()
        before.profiles = 1
        var after = before
        after.profiles = 2
        after.checklistItems = 69
        after.checklistSections = 6
        let delta = after.deltaDescription(from: before)
        XCTAssertTrue(delta.contains("VehicleProfile: 1 -> 2"))
        XCTAssertTrue(delta.contains("ChecklistItem: 0 -> 69"))
        XCTAssertFalse(delta.contains("Trip:"))
    }

    @MainActor
    func testDiagnosticAuditClassifiesIsolationSectionAndLeavesFactoryProfile() throws {
        let schema = Schema([
            AppState.self,
            VehicleProfile.self,
            Trip.self,
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
            LibraryItem.self,
            LoadedItem.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 0))
        let section = ChecklistSection(title: "CloudKit Test Section", sortOrder: 0)
        context.insert(section)
        context.insert(ChecklistItem(title: "CloudKit Test Item", isChecked: false, sortOrder: 0, section: section))
        context.insert(ChecklistItem(title: "Test", isChecked: false, sortOrder: 1, section: section))
        try context.save()

        let report = CloudKitDiagnosticAuditor.audit(in: context)
        let sectionSummary = report.summaries.first { $0.model == "ChecklistSection" }
        XCTAssertEqual(sectionSummary?.clearlyDiagnostic, 1)
        let profiles = report.summaries.first { $0.model == "VehicleProfile" }
        XCTAssertEqual(profiles?.clearlyDiagnostic, 0)
        let items = report.summaries.first { $0.model == "ChecklistItem" }
        XCTAssertEqual(items?.clearlyDiagnostic, 1)
        XCTAssertEqual(items?.possiblyDiagnostic, 1)
        XCTAssertTrue(report.formatted.contains("Clearly diagnostic: 1"))
        XCTAssertEqual(report.removalPlan.removable.count, 1)
        XCTAssertEqual(report.removalPlan.removable.first?.model, "ChecklistItem")
        XCTAssertTrue(report.removalPlan.skipped.contains { $0.model == "ChecklistSection" })
        XCTAssertTrue(report.removalPreview.contains("Skipped"))
    }

    @MainActor
    func testDiagnosticRemovalDeletesLinkedIsolationSectionWhenAllChildrenAreDiagnostic() throws {
        let schema = Schema([
            AppState.self,
            VehicleProfile.self,
            Trip.self,
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
            LibraryItem.self,
            LoadedItem.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let section = ChecklistSection(title: "CloudKit Test Section", sortOrder: 0)
        context.insert(section)
        context.insert(ChecklistItem(title: "CloudKit Test Item", isChecked: false, sortOrder: 0, section: section))
        try context.save()

        let preview = CloudKitDiagnosticAuditor.audit(in: context)
        XCTAssertTrue(preview.removalPlan.removable.contains { $0.model == "ChecklistSection" })
        XCTAssertTrue(preview.removalPlan.removable.contains { $0.model == "ChecklistItem" })

        _ = try CloudKitDiagnosticAuditor.removeClearlyDiagnosticRecords(in: context)
        let remainingSections = try context.fetch(FetchDescriptor<ChecklistSection>())
        let remainingItems = try context.fetch(FetchDescriptor<ChecklistItem>())
        XCTAssertTrue(remainingSections.isEmpty)
        XCTAssertTrue(remainingItems.isEmpty)
    }
}
