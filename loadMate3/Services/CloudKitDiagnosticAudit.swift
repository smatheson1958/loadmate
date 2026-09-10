import Foundation
import SwiftData

enum CloudKitDiagnosticClassification: String {
    case clearlyDiagnostic = "Clearly diagnostic"
    case possiblyDiagnostic = "Possibly diagnostic"
    case normal = "Normal user data"
}

struct CloudKitDiagnosticHit: Equatable, Identifiable {
    var id: UUID
    var model: String
    var marker: String
    var displayName: String
    var parentID: UUID?
    var classification: CloudKitDiagnosticClassification
}

struct CloudKitDiagnosticModelSummary: Equatable {
    var model: String
    var total: Int
    var clearlyDiagnostic: Int
    var possiblyDiagnostic: Int
    var hits: [CloudKitDiagnosticHit]
}

struct CloudKitDiagnosticAuditReport: Equatable {
    var summaries: [CloudKitDiagnosticModelSummary]
    var generatedAt = Date()

    var clearlyDiagnosticHits: [CloudKitDiagnosticHit] {
        summaries.flatMap(\.hits).filter { $0.classification == .clearlyDiagnostic }
    }

    var formatted: String {
        var lines = [
            "Diagnostic Data Audit",
            "Generated: \(SyncDebugFormatting.logDateFormatter.string(from: generatedAt))",
            "",
        ]
        for summary in summaries {
            lines.append(summary.model)
            lines.append("  Total: \(summary.total)")
            lines.append("  Clearly diagnostic: \(summary.clearlyDiagnostic)")
            lines.append("  Possibly diagnostic: \(summary.possiblyDiagnostic)")
            let clearHits = summary.hits.filter { $0.classification == .clearlyDiagnostic }
            for hit in clearHits {
                lines.append("  - \(hit.model) \(hit.id.uuidString)")
                lines.append("    marker: \(hit.marker)")
                lines.append("    name: \(hit.displayName)")
                if let parentID = hit.parentID {
                    lines.append("    parent: \(parentID.uuidString)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    var removalPlan = CloudKitDiagnosticRemovalPlan()

    var removalPreview: String {
        removalPlan.formatted
    }
}

struct CloudKitDiagnosticRemovalSkip: Equatable {
    var model: String
    var id: UUID
    var reason: String
}

struct CloudKitDiagnosticRemovalPlan: Equatable {
    var removable: [CloudKitDiagnosticHit] = []
    var skipped: [CloudKitDiagnosticRemovalSkip] = []
    var cascadeNotes: [String] = []

    var formatted: String {
        if removable.isEmpty, skipped.isEmpty {
            return "No clearly diagnostic records to remove."
        }
        var lines: [String] = []
        if removable.isEmpty {
            lines.append("No records will be removed automatically.")
        } else {
            lines.append("Will remove \(removable.count) clearly diagnostic record(s):")
            lines.append("")
            for hit in removable {
                lines.append("- \(hit.model) \(hit.id.uuidString) (\(hit.displayName)) marker=\(hit.marker)")
                if let parentID = hit.parentID {
                    lines.append("  parent \(parentID.uuidString)")
                }
            }
        }
        if !cascadeNotes.isEmpty {
            lines.append("")
            lines.append("Relationship effects:")
            lines.append(contentsOf: cascadeNotes.map { "- \($0)" })
        }
        if !skipped.isEmpty {
            lines.append("")
            lines.append("Skipped (not high-confidence enough to delete):")
            for skip in skipped {
                lines.append("- \(skip.model) \(skip.id.uuidString): \(skip.reason)")
            }
        }
        lines.append("")
        lines.append("Possibly diagnostic and normal user records are not removed.")
        lines.append("AppState is never deleted.")
        return lines.joined(separator: "\n")
    }
}

enum CloudKitDiagnosticMarkers {
    static let namePrefix = "__CLOUDKIT_DIAGNOSTIC__"

    static let exactNames: Set<String> = [
        "CloudKit Test Vehicle",
        "CloudKit Test Trip",
        "CloudKit Test Section",
        "CloudKit Test Item",
        "CloudKit Test Group",
        "CloudKit Test Library Item",
    ]

    static let probePrefixes = [
        "core-vehicle-isolation-",
        "checklist-isolation-",
        "checklist-group-isolation-",
        "loaded-item-isolation-",
        "library-item-isolation-",
        "appstate-isolation-",
        "cloudkit-diagnostic-",
    ]

    static func isClearlyDiagnosticName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix(namePrefix) { return namePrefix }
        if exactNames.contains(name) { return name }
        return nil
    }

    static func isPossiblyDiagnosticName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.caseInsensitiveCompare("Test") == .orderedSame { return "title Test" }
        if name.localizedCaseInsensitiveContains("cloudkit-test") { return "cloudkit-test" }
        if name.localizedCaseInsensitiveContains("diagnostic") { return "diagnostic" }
        return nil
    }

    static func probeMarker(in value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in probePrefixes where trimmed.hasPrefix(prefix) {
            return prefix
        }
        if trimmed.localizedCaseInsensitiveContains("isolation test") {
            return "isolation test"
        }
        return nil
    }
}

@MainActor
enum CloudKitDiagnosticAuditor {
    static func audit(in context: ModelContext) -> CloudKitDiagnosticAuditReport {
        var summaries: [CloudKitDiagnosticModelSummary] = []

        summaries.append(summarize(
            model: "VehicleProfile",
            records: fetch(VehicleProfile.self, in: context)
        ) { profile in
            classify(
                id: profile.id,
                model: "VehicleProfile",
                displayName: sanitizedName(profile.name),
                parentID: nil,
                name: profile.name,
                extra: nil
            )
        })

        summaries.append(summarize(
            model: "Trip",
            records: fetch(Trip.self, in: context)
        ) { trip in
            classify(
                id: trip.id,
                model: "Trip",
                displayName: sanitizedName(trip.name),
                parentID: trip.profile?.id,
                name: trip.name,
                extra: nil
            )
        })

        summaries.append(summarize(
            model: "ChecklistSection",
            records: fetch(ChecklistSection.self, in: context)
        ) { section in
            classify(
                id: section.id,
                model: "ChecklistSection",
                displayName: sanitizedName(section.title),
                parentID: nil,
                name: section.title,
                extra: nil
            )
        })

        summaries.append(summarize(
            model: "ChecklistGroup",
            records: fetch(ChecklistGroup.self, in: context)
        ) { group in
            classify(
                id: group.id,
                model: "ChecklistGroup",
                displayName: sanitizedName(group.title),
                parentID: group.section?.id,
                name: group.title,
                extra: nil
            )
        })

        summaries.append(summarize(
            model: "ChecklistItem",
            records: fetch(ChecklistItem.self, in: context)
        ) { item in
            classify(
                id: item.id,
                model: "ChecklistItem",
                displayName: sanitizedName(item.title),
                parentID: item.group?.id ?? item.section?.id,
                name: item.title,
                extra: nil
            )
        })

        summaries.append(summarize(
            model: "LibraryItem",
            records: fetch(LibraryItem.self, in: context)
        ) { item in
            classify(
                id: item.id,
                model: "LibraryItem",
                displayName: sanitizedName(item.name),
                parentID: nil,
                name: item.name,
                extra: nil
            )
        })

        summaries.append(summarize(
            model: "DocumentRecord",
            records: fetch(DocumentRecord.self, in: context)
        ) { document in
            classify(
                id: document.id,
                model: "DocumentRecord",
                displayName: sanitizedName(document.title),
                parentID: nil,
                name: document.title,
                extra: document.notes
            )
        })

        summaries.append(summarize(
            model: "MaintenanceAttachment",
            records: fetch(MaintenanceAttachment.self, in: context)
        ) { attachment in
            classify(
                id: attachment.id,
                model: "MaintenanceAttachment",
                displayName: sanitizedName(attachment.displayName),
                parentID: attachment.documentRecord?.id
                    ?? attachment.warrantyEvent?.id
                    ?? attachment.maintenanceRecord?.id
                    ?? attachment.faultRecord?.id,
                name: attachment.displayName,
                extra: attachment.localFileName
            )
        })

        summaries.append(summarize(
            model: "LoadedItem",
            records: fetch(LoadedItem.self, in: context)
        ) { item in
            let libraryName = item.item.map(\.name) ?? ""
            let hit = classify(
                id: item.id,
                model: "LoadedItem",
                displayName: sanitizedName(libraryName.isEmpty ? "LoadedItem" : libraryName),
                parentID: item.trip?.id,
                name: libraryName,
                extra: nil
            )
            if hit == nil, let library = item.item,
               CloudKitDiagnosticMarkers.isClearlyDiagnosticName(library.name) != nil {
                return CloudKitDiagnosticHit(
                    id: item.id,
                    model: "LoadedItem",
                    marker: "parent LibraryItem diagnostic",
                    displayName: sanitizedName(library.name),
                    parentID: library.id,
                    classification: .clearlyDiagnostic
                )
            }
            return hit
        })

        let appStates = fetch(AppState.self, in: context)
        var appHits: [CloudKitDiagnosticHit] = []
        for state in appStates {
            if let marker = CloudKitDiagnosticMarkers.probeMarker(in: state.syncProbeValue)
                ?? CloudKitDiagnosticMarkers.probeMarker(in: state.syncProbeUpdatedBy) {
                appHits.append(
                    CloudKitDiagnosticHit(
                        id: state.id,
                        model: "AppState",
                        marker: marker,
                        displayName: "probe metadata only — AppState is not deleted",
                        parentID: nil,
                        classification: .clearlyDiagnostic
                    )
                )
            }
        }
        summaries.append(
            CloudKitDiagnosticModelSummary(
                model: "AppState",
                total: appStates.count,
                clearlyDiagnostic: appHits.count,
                possiblyDiagnostic: 0,
                hits: appHits
            )
        )

        var report = CloudKitDiagnosticAuditReport(summaries: summaries)
        report.removalPlan = removalPlan(from: report, in: context)
        return report
    }

    static func removeClearlyDiagnosticRecords(in context: ModelContext) throws -> String {
        let report = audit(in: context)
        let removable = report.removalPlan.removable
        guard !removable.isEmpty else {
            return "No clearly diagnostic records were removed. Ambiguous and user records were left in place. AppState is never deleted."
        }

        let idsByModel = Dictionary(grouping: removable, by: \.model)
        func ids(_ model: String) -> Set<UUID> {
            Set((idsByModel[model] ?? []).map(\.id))
        }

        for document in fetch(DocumentRecord.self, in: context) where ids("DocumentRecord").contains(document.id) {
            for attachment in document.attachmentsList {
                MaintenanceAttachmentStore.delete(attachment, in: context)
            }
            context.delete(document)
        }
        for attachment in fetch(MaintenanceAttachment.self, in: context) where ids("MaintenanceAttachment").contains(attachment.id) {
            MaintenanceAttachmentStore.delete(attachment, in: context)
        }
        for item in fetch(LoadedItem.self, in: context) where ids("LoadedItem").contains(item.id) {
            context.delete(item)
        }
        for item in fetch(LibraryItem.self, in: context) where ids("LibraryItem").contains(item.id) {
            context.delete(item)
        }
        for item in fetch(ChecklistItem.self, in: context) where ids("ChecklistItem").contains(item.id) {
            context.delete(item)
        }
        for group in fetch(ChecklistGroup.self, in: context) where ids("ChecklistGroup").contains(group.id) {
            context.delete(group)
        }
        for section in fetch(ChecklistSection.self, in: context) where ids("ChecklistSection").contains(section.id) {
            context.delete(section)
        }
        for trip in fetch(Trip.self, in: context) where ids("Trip").contains(trip.id) {
            context.delete(trip)
        }
        for profile in fetch(VehicleProfile.self, in: context) where ids("VehicleProfile").contains(profile.id) {
            context.delete(profile)
        }

        try context.save()
        var lines = ["Removed \(removable.count) clearly diagnostic record(s). AppState left in place."]
        lines.append(contentsOf: report.removalPlan.cascadeNotes)
        if !report.removalPlan.skipped.isEmpty {
            lines.append("Skipped \(report.removalPlan.skipped.count) parent record(s) that still have non-diagnostic children.")
        }
        return lines.joined(separator: "\n")
    }

    private static func removalPlan(
        from report: CloudKitDiagnosticAuditReport,
        in context: ModelContext
    ) -> CloudKitDiagnosticRemovalPlan {
        let candidates = report.clearlyDiagnosticHits.filter { $0.model != "AppState" }
        let candidateIDs = Set(candidates.map(\.id))
        var skipped: [CloudKitDiagnosticRemovalSkip] = []
        var skipIDs = Set<UUID>()
        var cascadeNotes: [String] = []

        func skip(_ hit: CloudKitDiagnosticHit, reason: String) {
            guard skipIDs.insert(hit.id).inserted else { return }
            skipped.append(CloudKitDiagnosticRemovalSkip(model: hit.model, id: hit.id, reason: reason))
        }

        let sections = Dictionary(uniqueKeysWithValues: fetch(ChecklistSection.self, in: context).map { ($0.id, $0) })
        let groups = Dictionary(uniqueKeysWithValues: fetch(ChecklistGroup.self, in: context).map { ($0.id, $0) })
        let trips = Dictionary(uniqueKeysWithValues: fetch(Trip.self, in: context).map { ($0.id, $0) })
        let documents = Dictionary(uniqueKeysWithValues: fetch(DocumentRecord.self, in: context).map { ($0.id, $0) })
        let profiles = Dictionary(uniqueKeysWithValues: fetch(VehicleProfile.self, in: context).map { ($0.id, $0) })

        for hit in candidates where hit.model == "ChecklistGroup" {
            guard let group = groups[hit.id] else { continue }
            let blocking = group.itemsList.filter { !candidateIDs.contains($0.id) }
            if !blocking.isEmpty {
                skip(hit, reason: "has \(blocking.count) non-diagnostic checklist item(s)")
            }
        }

        for hit in candidates where hit.model == "ChecklistSection" {
            guard let section = sections[hit.id] else { continue }
            let nestedItems = section.itemsList + section.groupsList.flatMap(\.itemsList)
            let blockingItems = nestedItems.filter { !candidateIDs.contains($0.id) }
            if !blockingItems.isEmpty {
                skip(hit, reason: "has \(blockingItems.count) non-diagnostic checklist item(s); those items will not be removed")
            } else {
                let cascadeGroups = section.groupsList.filter { !candidateIDs.contains($0.id) }
                if !cascadeGroups.isEmpty {
                    cascadeNotes.append(
                        "Removing ChecklistSection \(hit.id.uuidString) also deletes \(cascadeGroups.count) related ChecklistGroup(s) via cascade"
                    )
                }
            }
        }

        for hit in candidates where hit.model == "DocumentRecord" {
            guard let document = documents[hit.id] else { continue }
            let blocking = document.attachmentsList.filter { !candidateIDs.contains($0.id) }
            if !blocking.isEmpty {
                skip(hit, reason: "has \(blocking.count) non-diagnostic attachment(s)")
            } else if !document.attachmentsList.isEmpty {
                cascadeNotes.append(
                    "Removing DocumentRecord \(hit.id.uuidString) also deletes \(document.attachmentsList.count) related MaintenanceAttachment(s) via cascade"
                )
            }
        }

        for hit in candidates where hit.model == "Trip" {
            guard let trip = trips[hit.id] else { continue }
            let blocking = trip.loadedItemsList.filter { !candidateIDs.contains($0.id) }
            if !blocking.isEmpty {
                skip(hit, reason: "has \(blocking.count) non-diagnostic LoadedItem(s)")
            }
        }

        for hit in candidates where hit.model == "VehicleProfile" {
            guard let profile = profiles[hit.id] else { continue }
            let blockingTrips = profile.tripsList.filter { trip in
                !candidateIDs.contains(trip.id) || trip.loadedItemsList.contains { !candidateIDs.contains($0.id) }
            }
            if !blockingTrips.isEmpty {
                skip(
                    hit,
                    reason: "has \(blockingTrips.count) related Trip(s) that are not clearly diagnostic or that contain non-diagnostic loaded items"
                )
            } else if !profile.tripsList.isEmpty {
                cascadeNotes.append(
                    "Removing VehicleProfile \(hit.id.uuidString) also deletes \(profile.tripsList.count) related Trip(s) via cascade"
                )
            }
        }

        let removable = candidates.filter { !skipIDs.contains($0.id) }
        return CloudKitDiagnosticRemovalPlan(
            removable: removable,
            skipped: skipped,
            cascadeNotes: cascadeNotes
        )
    }

    private static func classify(
        id: UUID,
        model: String,
        displayName: String,
        parentID: UUID?,
        name: String,
        extra: String?
    ) -> CloudKitDiagnosticHit? {
        if let marker = CloudKitDiagnosticMarkers.isClearlyDiagnosticName(name)
            ?? extra.flatMap(CloudKitDiagnosticMarkers.probeMarker(in:)) {
            return CloudKitDiagnosticHit(
                id: id,
                model: model,
                marker: marker,
                displayName: displayName,
                parentID: parentID,
                classification: .clearlyDiagnostic
            )
        }
        if let marker = CloudKitDiagnosticMarkers.isPossiblyDiagnosticName(name) {
            return CloudKitDiagnosticHit(
                id: id,
                model: model,
                marker: marker,
                displayName: displayName,
                parentID: parentID,
                classification: .possiblyDiagnostic
            )
        }
        return nil
    }

    private static func summarize<Model>(
        model: String,
        records: [Model],
        hit: (Model) -> CloudKitDiagnosticHit?
    ) -> CloudKitDiagnosticModelSummary {
        let hits = records.compactMap(hit)
        return CloudKitDiagnosticModelSummary(
            model: model,
            total: records.count,
            clearlyDiagnostic: hits.filter { $0.classification == .clearlyDiagnostic }.count,
            possiblyDiagnostic: hits.filter { $0.classification == .possiblyDiagnostic }.count,
            hits: hits
        )
    }

    private static func fetch<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) -> [Model] {
        (try? context.fetch(FetchDescriptor<Model>())) ?? []
    }

    private static func sanitizedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if CloudKitDiagnosticMarkers.isClearlyDiagnosticName(trimmed) != nil
            || CloudKitDiagnosticMarkers.isPossiblyDiagnosticName(trimmed) != nil
            || trimmed.hasPrefix(CloudKitDiagnosticMarkers.namePrefix) {
            return trimmed
        }
        if trimmed.isEmpty { return "(empty)" }
        return "(user value hidden)"
    }
}
