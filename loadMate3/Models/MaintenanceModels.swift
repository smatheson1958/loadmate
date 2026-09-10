import Foundation
import SwiftData

enum MaintenanceCategory: String, Codable, CaseIterable, Identifiable {
    case annualHabitationService
    case dampInspection
    case chassisService
    case brakeService
    case wheelBearings
    case tyres
    case leisureBattery
    case electricalSystem
    case waterSystem
    case gasSystem
    case applianceRepair
    case bodywork
    case awning
    case warrantyRepair
    case generalMaintenance
    case engineService
    case mot
    case gearbox
    case airConditioning
    case engineBattery
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .annualHabitationService: return "Annual Habitation Service"
        case .dampInspection: return "Damp Inspection"
        case .chassisService: return "Chassis Service"
        case .brakeService: return "Brake Service"
        case .wheelBearings: return "Wheel Bearings"
        case .tyres: return "Tyres"
        case .leisureBattery: return "Leisure Battery"
        case .electricalSystem: return "Electrical System"
        case .waterSystem: return "Water System"
        case .gasSystem: return "Gas System"
        case .applianceRepair: return "Appliance Repair"
        case .bodywork: return "Bodywork"
        case .awning: return "Awning"
        case .warrantyRepair: return "Warranty Repair"
        case .generalMaintenance: return "General Maintenance"
        case .engineService: return "Engine Service"
        case .mot: return "MOT"
        case .gearbox: return "Gearbox"
        case .airConditioning: return "Air Conditioning"
        case .engineBattery: return "Engine Battery"
        case .other: return "Other"
        }
    }

    func isAvailable(for kind: VehicleKind) -> Bool {
        switch self {
        case .engineService, .mot, .gearbox, .airConditioning, .engineBattery:
            return kind == .motorhome
        default:
            return true
        }
    }
}

enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case insurance
    case breakdownCover
    case warranty
    case serviceHistory
    case habitationCertificate
    case dampReport
    case mot
    case crisRegistration
    case vinChassisInformation
    case gasSafetyCertificate
    case applianceManuals
    case purchaseInvoice
    case tyreInvoice
    case batteryWarranty
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .insurance: return "Insurance"
        case .breakdownCover: return "Breakdown Cover"
        case .warranty: return "Warranty"
        case .serviceHistory: return "Service History"
        case .habitationCertificate: return "Habitation Certificate"
        case .dampReport: return "Damp Report"
        case .mot: return "MOT"
        case .crisRegistration: return "CRiS Registration"
        case .vinChassisInformation: return "VIN / Chassis Information"
        case .gasSafetyCertificate: return "Gas Safety Certificate"
        case .applianceManuals: return "Appliance Manuals"
        case .purchaseInvoice: return "Purchase Invoice"
        case .tyreInvoice: return "Tyre Invoice"
        case .batteryWarranty: return "Battery Warranty"
        case .other: return "Other"
        }
    }
}

enum FaultSeverity: String, Codable, CaseIterable, Identifiable {
    case information
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .information: return "Information"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum FaultStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case inProgress
    case waitingParts
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .waitingParts: return "Waiting Parts"
        case .completed: return "Completed"
        }
    }

    var isResolved: Bool {
        self == .completed
    }
}

enum MaintenanceAttachmentKind: String, Codable, CaseIterable, Identifiable {
    case photo
    case scannedDocument
    case pdf
    case file

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .scannedDocument: return "Scanned document"
        case .pdf: return "PDF"
        case .file: return "File"
        }
    }
}

@Model
final class MaintenanceRecord {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = MaintenanceCategory.generalMaintenance.rawValue
    var serviceDate: Date = Date()
    var cost: Double?
    var supplier: String = ""
    var notes: String = ""
    var reminderDate: Date?
    var vehicleMileage: Double?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceAttachment.maintenanceRecord)
    var attachments: [MaintenanceAttachment]?

    @Relationship(deleteRule: .nullify, inverse: \FaultRecord.linkedMaintenanceRecord)
    var linkedFaults: [FaultRecord]?

    init(id: UUID = UUID(), vehicleID: UUID) {
        self.id = id
        self.vehicleID = vehicleID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var category: MaintenanceCategory {
        get { MaintenanceCategory(rawValue: categoryRaw) ?? .generalMaintenance }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class DocumentRecord {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = DocumentCategory.other.rawValue
    var dateAdded: Date = Date()
    var expiryDate: Date?
    var reminderDate: Date?
    var notes: String = ""
    var isWarrantyRelated: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceAttachment.documentRecord)
    var attachments: [MaintenanceAttachment]?

    init(id: UUID = UUID(), vehicleID: UUID) {
        self.id = id
        self.vehicleID = vehicleID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var category: DocumentCategory {
        get { DocumentCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class FaultRecord {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var severityRaw: String = FaultSeverity.low.rawValue
    var statusRaw: String = FaultStatus.open.rawValue
    var discoveredDate: Date = Date()
    var resolvedDate: Date?
    /// Legacy storage retained so existing estimates can be shown as a single cost.
    var estimatedRepairCost: Double?
    var actualRepairCost: Double?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var linkedMaintenanceRecord: MaintenanceRecord?

    var isWarrantyRelated: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceAttachment.faultRecord)
    var attachments: [MaintenanceAttachment]?

    init(id: UUID = UUID(), vehicleID: UUID) {
        self.id = id
        self.vehicleID = vehicleID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var severity: FaultSeverity {
        get { FaultSeverity(rawValue: severityRaw) ?? .low }
        set { severityRaw = newValue.rawValue }
    }

    var status: FaultStatus {
        get { FaultStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class MaintenanceAttachment {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var localFileName: String = ""
    var thumbnailFileName: String?
    /// Legacy CloudKit asset field. Kept nil; file bytes live on disk only.
    @Attribute(.externalStorage)
    var fileData: Data? = nil
    /// Legacy CloudKit asset field. Kept nil; thumbnail bytes live on disk only.
    @Attribute(.externalStorage)
    var thumbnailData: Data? = nil
    var fileTypeRaw: String = MaintenanceAttachmentKind.file.rawValue
    var displayName: String = ""
    var utiIdentifier: String = ""
    var pageCount: Int?
    var byteCount: Int = 0
    var createdAt: Date = Date()

    var maintenanceRecord: MaintenanceRecord?
    var documentRecord: DocumentRecord?
    var faultRecord: FaultRecord?
    var warrantyEvent: WarrantyEvent?

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        localFileName: String,
        thumbnailFileName: String? = nil,
        fileType: MaintenanceAttachmentKind,
        displayName: String,
        utiIdentifier: String,
        pageCount: Int? = nil,
        byteCount: Int = 0
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.localFileName = localFileName
        self.thumbnailFileName = thumbnailFileName
        self.fileData = nil
        self.thumbnailData = nil
        self.fileTypeRaw = fileType.rawValue
        self.displayName = displayName
        self.utiIdentifier = utiIdentifier
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.createdAt = Date()
    }

    var fileType: MaintenanceAttachmentKind {
        get { MaintenanceAttachmentKind(rawValue: fileTypeRaw) ?? .file }
        set { fileTypeRaw = newValue.rawValue }
    }
}

extension MaintenanceRecord {
    var attachmentsList: [MaintenanceAttachment] {
        (attachments ?? []).sorted { $0.createdAt > $1.createdAt }
    }
}

extension DocumentRecord {
    var attachmentsList: [MaintenanceAttachment] {
        (attachments ?? []).sorted { $0.createdAt > $1.createdAt }
    }
}

extension FaultRecord {
    var attachmentsList: [MaintenanceAttachment] {
        (attachments ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// The fault's single recorded repair cost. Falls back to legacy estimate data.
    var repairCost: Double? {
        actualRepairCost ?? estimatedRepairCost
    }
}
