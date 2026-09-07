import CloudKit
import Foundation
import SwiftData

struct CloudKitExportPoisonFinding: Equatable {
    enum Severity: String, Equatable {
        case likely = "LIKELY"
        case info = "INFO"
    }

    var severity: Severity
    var code: String
    var detail: String
}

struct CloudKitExportPoisonSectionRow: Equatable {
    var id: UUID
    var title: String
    var profileID: UUID?
}

struct CloudKitExportPoisonVehicleRow: Equatable {
    var vehicleID: UUID
    var name: String
    var count: Int
}

struct CloudKitExportPoisonLocalSnapshot: Equatable {
    var profileCount = 0
    var sectionCount = 0
    var groupCount = 0
    var itemCount = 0
    var appStateCount = 0
    var didMigrateChecklistsToVehicles = false
    var vehicleIDs: [UUID] = []
    var sectionIDs: [UUID] = []
    var groupIDs: [UUID] = []
    var itemIDs: [UUID] = []
    var sections: [CloudKitExportPoisonSectionRow] = []
    var sectionsPerVehicle: [CloudKitExportPoisonVehicleRow] = []
}

struct CloudKitExportPoisonReport: Equatable {
    var generatedAt = Date()
    var local = CloudKitExportPoisonLocalSnapshot()
    var findings: [CloudKitExportPoisonFinding] = []
    var cloudDetail = "Not checked yet"

    var formatted: String {
        var lines = [
            "Export poison audit",
            "Generated: \(SyncDebugFormatting.logDateFormatter.string(from: generatedAt))",
            "Does not write to CloudKit.",
            "",
            "LOCAL GRAPH",
            "profiles=\(local.profileCount) sections=\(local.sectionCount) groups=\(local.groupCount) items=\(local.itemCount) appStates=\(local.appStateCount) migrated=\(local.didMigrateChecklistsToVehicles)",
        ]
        if local.sectionsPerVehicle.isEmpty {
            lines.append("vehicles: none")
        } else {
            for row in local.sectionsPerVehicle {
                lines.append("vehicle \(row.vehicleID.uuidString) name=\(row.name) sections=\(row.count)")
            }
        }
        lines.append("")
        let likely = findings.filter { $0.severity == .likely }
        lines.append("LIKELY PROBLEMS")
        if likely.isEmpty {
            lines.append("none in the local graph")
        } else {
            for finding in likely {
                lines.append("- [\(finding.code)] \(finding.detail)")
            }
        }
        let info = findings.filter { $0.severity == .info }
        if !info.isEmpty {
            lines.append("")
            lines.append("INFO")
            for finding in info {
                lines.append("- [\(finding.code)] \(finding.detail)")
            }
        }
        lines.append("")
        lines.append("CLOUDKIT FIELDS")
        lines.append(cloudDetail)
        return lines.joined(separator: "\n")
    }
}

enum CloudKitExportPoisonAudit {
    @MainActor
    static func audit(in context: ModelContext) -> CloudKitExportPoisonReport {
        let profiles = fetch(VehicleProfile.self, in: context)
        let sections = fetch(ChecklistSection.self, in: context)
        let groups = fetch(ChecklistGroup.self, in: context)
        let items = fetch(ChecklistItem.self, in: context)
        let appStates = fetch(AppState.self, in: context)
        let migrated = appStates.contains { $0.didMigrateChecklistsToVehicles }

        let snapshot = CloudKitExportPoisonLocalSnapshot(
            profileCount: profiles.count,
            sectionCount: sections.count,
            groupCount: groups.count,
            itemCount: items.count,
            appStateCount: appStates.count,
            didMigrateChecklistsToVehicles: migrated,
            vehicleIDs: profiles.map(\.id),
            sectionIDs: sections.map(\.id),
            groupIDs: groups.map(\.id),
            itemIDs: items.map(\.id),
            sections: sections.map {
                CloudKitExportPoisonSectionRow(id: $0.id, title: $0.title, profileID: $0.profile?.id)
            },
            sectionsPerVehicle: profiles
                .sorted { $0.sortOrder < $1.sortOrder }
                .map {
                    CloudKitExportPoisonVehicleRow(
                        vehicleID: $0.id,
                        name: $0.name,
                        count: $0.checklistSectionsList.count
                    )
                }
        )

        var findings: [CloudKitExportPoisonFinding] = []
        findings.append(contentsOf: duplicateFindings(ids: snapshot.vehicleIDs, model: "VehicleProfile"))
        findings.append(contentsOf: duplicateFindings(ids: snapshot.sectionIDs, model: "ChecklistSection"))
        findings.append(contentsOf: duplicateFindings(ids: snapshot.groupIDs, model: "ChecklistGroup"))
        findings.append(contentsOf: duplicateFindings(ids: snapshot.itemIDs, model: "ChecklistItem"))
        findings.append(contentsOf: duplicateFindings(ids: appStates.map(\.id), model: "AppState"))

        if appStates.count != 1 {
            findings.append(
                CloudKitExportPoisonFinding(
                    severity: .likely,
                    code: "appstate-count",
                    detail: "expected 1 AppState, found \(appStates.count)"
                )
            )
        }

        let profileIDs = Set(snapshot.vehicleIDs)
        let unscoped = sections.filter { $0.profile == nil }
        if migrated, !unscoped.isEmpty {
            findings.append(
                CloudKitExportPoisonFinding(
                    severity: .likely,
                    code: "unscoped-after-migrate",
                    detail: "\(unscoped.count) ChecklistSection(s) still have no vehicle after migration: \(unscoped.map { $0.id.uuidString }.joined(separator: ", "))"
                )
            )
        } else if !migrated, !unscoped.isEmpty {
            findings.append(
                CloudKitExportPoisonFinding(
                    severity: .info,
                    code: "unscoped-before-migrate",
                    detail: "\(unscoped.count) ChecklistSection(s) have no vehicle and migration has not run"
                )
            )
        }

        for section in sections {
            if let profileID = section.profile?.id, !profileIDs.contains(profileID) {
                findings.append(
                    CloudKitExportPoisonFinding(
                        severity: .likely,
                        code: "dangling-profile",
                        detail: "ChecklistSection \(section.id.uuidString) points at missing vehicle \(profileID.uuidString)"
                    )
                )
            }
        }

        let orphanGroups = groups.filter { $0.section == nil }
        if !orphanGroups.isEmpty {
            findings.append(
                CloudKitExportPoisonFinding(
                    severity: .likely,
                    code: "orphan-group",
                    detail: "\(orphanGroups.count) ChecklistGroup(s) have no section: \(orphanGroups.map { $0.id.uuidString }.joined(separator: ", "))"
                )
            )
        }

        let orphanItems = items.filter { $0.group == nil && $0.section == nil }
        if !orphanItems.isEmpty {
            findings.append(
                CloudKitExportPoisonFinding(
                    severity: .likely,
                    code: "orphan-item",
                    detail: "\(orphanItems.count) ChecklistItem(s) have no group and no section: \(orphanItems.prefix(8).map { $0.id.uuidString }.joined(separator: ", "))"
                )
            )
        }

        for row in snapshot.sectionsPerVehicle where row.count == 0 {
            findings.append(
                CloudKitExportPoisonFinding(
                    severity: .info,
                    code: "empty-vehicle-checklist",
                    detail: "vehicle \(row.vehicleID.uuidString) has 0 checklist sections"
                )
            )
        }

        return CloudKitExportPoisonReport(local: snapshot, findings: findings)
    }

    static func compareIDs(local: [UUID], cloud: [UUID]) -> (localOnly: [UUID], cloudOnly: [UUID]) {
        let localSet = Set(local)
        let cloudSet = Set(cloud)
        return (
            localSet.subtracting(cloudSet).sorted { $0.uuidString < $1.uuidString },
            cloudSet.subtracting(localSet).sorted { $0.uuidString < $1.uuidString }
        )
    }

    static func uuid(fromCloudValue value: CKRecordValueProtocol?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String {
            return UUID(uuidString: string)
        }
        return nil
    }

    static func formattedField(_ value: CKRecordValueProtocol?) -> String {
        switch value {
        case nil:
            return "(nil)"
        case let string as String:
            return string.isEmpty ? "(empty)" : string
        case let uuid as UUID:
            return uuid.uuidString
        case let number as NSNumber:
            return number.stringValue
        case let date as Date:
            return SyncDebugFormatting.string(for: date)
        case let reference as CKRecord.Reference:
            return "REF \(reference.recordID.recordName) zone=\(reference.recordID.zoneID.zoneName)"
        default:
            return String(describing: value!)
        }
    }

    private static func duplicateFindings(ids: [UUID], model: String) -> [CloudKitExportPoisonFinding] {
        var counts: [UUID: Int] = [:]
        for id in ids {
            counts[id, default: 0] += 1
        }
        return counts.compactMap { id, count in
            guard count > 1 else { return nil }
            return CloudKitExportPoisonFinding(
                severity: .likely,
                code: "duplicate-id",
                detail: "\(model) id \(id.uuidString) appears \(count) times"
            )
        }
        .sorted { $0.detail < $1.detail }
    }

    private static func fetch<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) -> [Model] {
        (try? context.fetch(FetchDescriptor<Model>())) ?? []
    }
}

enum CloudKitQueryPaging {
    static let coreDataZoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")

    static func fetchAll(
        recordType: String,
        database: CKDatabase,
        zoneID: CKRecordZone.ID = coreDataZoneID,
        desiredKeys: [CKRecord.FieldKey]? = nil
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        var page = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            desiredKeys: desiredKeys,
            resultsLimit: 200
        )
        append(page.matchResults, into: &records)
        cursor = page.queryCursor
        while let current = cursor {
            page = try await database.records(
                continuingMatchFrom: current,
                desiredKeys: desiredKeys,
                resultsLimit: 200
            )
            append(page.matchResults, into: &records)
            cursor = page.queryCursor
        }
        return records
    }

    private static func append(
        _ matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
        into records: inout [CKRecord]
    ) {
        for pair in matchResults {
            if case .success(let record) = pair.1 {
                records.append(record)
            }
        }
    }
}

enum CloudKitFieldProbe {
    static func run(
        containerID: String,
        local: CloudKitExportPoisonLocalSnapshot
    ) async -> String {
        let container = CKContainer(identifier: containerID)
        let database = container.privateCloudDatabase
        let zoneID = CloudKitQueryPaging.coreDataZoneID

        do {
            let zones = try await database.allRecordZones()
            guard zones.contains(where: { $0.zoneID.zoneName == zoneID.zoneName }) else {
                return "No Core Data CloudKit zone in this environment."
            }

            let appStates = try await CloudKitQueryPaging.fetchAll(
                recordType: "CD_AppState",
                database: database,
                zoneID: zoneID,
                desiredKeys: [
                    "CD_id",
                    "CD_didMigrateChecklistsToVehicles",
                    "CD_syncProbeValue",
                    "CD_syncProbeSequence",
                ]
            )
            let vehicles = try await CloudKitQueryPaging.fetchAll(
                recordType: "CD_VehicleProfile",
                database: database,
                zoneID: zoneID,
                desiredKeys: ["CD_id", "CD_name", "CD_entityName"]
            )
            let sections = try await CloudKitQueryPaging.fetchAll(
                recordType: "CD_ChecklistSection",
                database: database,
                zoneID: zoneID,
                desiredKeys: ["CD_id", "CD_title", "CD_profile", "CD_sortOrder"]
            )
            let groups = try await CloudKitQueryPaging.fetchAll(
                recordType: "CD_ChecklistGroup",
                database: database,
                zoneID: zoneID,
                desiredKeys: ["CD_id", "CD_title", "CD_section"]
            )
            let items = try await CloudKitQueryPaging.fetchAll(
                recordType: "CD_ChecklistItem",
                database: database,
                zoneID: zoneID,
                desiredKeys: ["CD_id", "CD_title", "CD_section", "CD_group"]
            )

            let cloudSectionIDs = sections.compactMap { CloudKitExportPoisonAudit.uuid(fromCloudValue: $0["CD_id"]) }
            let cloudVehicleIDs = vehicles.compactMap { CloudKitExportPoisonAudit.uuid(fromCloudValue: $0["CD_id"]) }
            let cloudVehicleRecordNames = Set(vehicles.map(\.recordID.recordName))
            let sectionDiff = CloudKitExportPoisonAudit.compareIDs(local: local.sectionIDs, cloud: cloudSectionIDs)
            let vehicleDiff = CloudKitExportPoisonAudit.compareIDs(local: local.vehicleIDs, cloud: cloudVehicleIDs)

            var emptyProfile = 0
            var profileMismatches: [String] = []
            let localProfileBySection = Dictionary(
                uniqueKeysWithValues: local.sections.map { ($0.id, $0.profileID) }
            )

            var lines = [
                "paged fetch (not capped at 100)",
                "CD_AppState fetched=\(appStates.count)",
            ]
            for record in appStates {
                lines.append(
                    "  recordName=\(record.recordID.recordName) CD_id=\(CloudKitExportPoisonAudit.formattedField(record["CD_id"])) migrated=\(CloudKitExportPoisonAudit.formattedField(record["CD_didMigrateChecklistsToVehicles"])) probe=\(CloudKitExportPoisonAudit.formattedField(record["CD_syncProbeValue"]))"
                )
            }
            lines.append("CD_VehicleProfile fetched=\(vehicles.count)")
            for record in vehicles.sorted(by: { $0.recordID.recordName < $1.recordID.recordName }) {
                lines.append(
                    "  recordName=\(record.recordID.recordName) CD_id=\(CloudKitExportPoisonAudit.formattedField(record["CD_id"])) name=\(CloudKitExportPoisonAudit.formattedField(record["CD_name"]))"
                )
            }
            lines.append("CD_ChecklistSection fetched=\(sections.count)")
            for record in sections.sorted(by: { $0.recordID.recordName < $1.recordID.recordName }) {
                let profileField = CloudKitExportPoisonAudit.formattedField(record["CD_profile"])
                let sectionID = CloudKitExportPoisonAudit.uuid(fromCloudValue: record["CD_id"])
                if profileField == "(nil)" || profileField == "(empty)" {
                    emptyProfile += 1
                }
                if let sectionID, let localProfile = localProfileBySection[sectionID] {
                    let cloudProfileUUID = CloudKitExportPoisonAudit.uuid(fromCloudValue: record["CD_profile"])
                    let cloudProfileRaw = (record["CD_profile"] as? String) ?? ""
                    let matchesUUID = cloudProfileUUID != nil && cloudProfileUUID == localProfile
                    let matchesRecordName = !cloudProfileRaw.isEmpty && cloudVehicleRecordNames.contains(cloudProfileRaw)
                    if localProfile != nil, !matchesUUID, !matchesRecordName, profileField != "(nil)", profileField != "(empty)" {
                        profileMismatches.append(
                            "\(sectionID.uuidString) localProfile=\(localProfile?.uuidString ?? "nil") cloud=\(profileField)"
                        )
                    }
                }
                lines.append(
                    "  recordName=\(record.recordID.recordName) CD_id=\(CloudKitExportPoisonAudit.formattedField(record["CD_id"])) title=\(CloudKitExportPoisonAudit.formattedField(record["CD_title"])) CD_profile=\(profileField)"
                )
            }
            lines.append("CD_ChecklistGroup fetched=\(groups.count)")
            lines.append("CD_ChecklistItem fetched=\(items.count)")

            let itemsMissingParents = items.filter {
                CloudKitExportPoisonAudit.formattedField($0["CD_group"]) == "(nil)"
                    && CloudKitExportPoisonAudit.formattedField($0["CD_section"]) == "(nil)"
            }
            if !itemsMissingParents.isEmpty {
                lines.append("cloud items with no CD_group and no CD_section: \(itemsMissingParents.count)")
                for record in itemsMissingParents.prefix(8) {
                    lines.append(
                        "  recordName=\(record.recordID.recordName) CD_id=\(CloudKitExportPoisonAudit.formattedField(record["CD_id"])) title=\(CloudKitExportPoisonAudit.formattedField(record["CD_title"]))"
                    )
                }
            }

            lines.append("")
            lines.append("COMPARE")
            lines.append("vehicles local-only: \(describeIDs(vehicleDiff.localOnly))")
            lines.append("vehicles cloud-only: \(describeIDs(vehicleDiff.cloudOnly))")
            lines.append("sections local-only: \(describeIDs(sectionDiff.localOnly))")
            lines.append("sections cloud-only: \(describeIDs(sectionDiff.cloudOnly))")
            lines.append("cloud sections with empty CD_profile: \(emptyProfile)/\(sections.count)")
            if profileMismatches.isEmpty {
                lines.append("CD_profile values that match neither a vehicle CD_id nor a vehicle recordName: none")
            } else {
                lines.append("CD_profile values that match neither a vehicle CD_id nor a vehicle recordName:")
                lines.append(contentsOf: profileMismatches.prefix(12).map { "  \($0)" })
            }
            if sectionDiff.localOnly.isEmpty, emptyProfile == 0, profileMismatches.isEmpty {
                lines.append("Cloud section IDs match local. If export still fails, the poison is a field update on an existing record, not a missing type.")
            } else if !sectionDiff.localOnly.isEmpty {
                lines.append("Local-only sections are the best export-poison suspects: they exist here and have not appeared in CloudKit.")
            }
            return lines.joined(separator: "\n")
        } catch let error as CKError where error.code == .notAuthenticated {
            return "Cannot probe fields — sign in to iCloud on this device."
        } catch {
            return "Field probe failed: \(CloudSyncErrorFormatting.description(for: error))"
        }
    }

    private static func describeIDs(_ ids: [UUID]) -> String {
        if ids.isEmpty { return "none" }
        return "\(ids.count) \(ids.map(\.uuidString).joined(separator: ", "))"
    }
}
