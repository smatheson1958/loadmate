import Foundation
import SwiftData

enum AccidentJurisdiction: String, Codable, CaseIterable, Identifiable, Sendable {
    case unitedKingdom
    case ireland
    case france
    case spain
    case germany
    case europeanUnion
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unitedKingdom: return "United Kingdom"
        case .ireland: return "Ireland"
        case .france: return "France"
        case .spain: return "Spain"
        case .germany: return "Germany"
        case .europeanUnion: return "Elsewhere in Europe"
        case .other: return "Outside Europe"
        }
    }

    var isUnitedKingdom: Bool { self == .unitedKingdom }

    var isEuropeOrIreland: Bool {
        switch self {
        case .ireland, .france, .spain, .germany, .europeanUnion:
            return true
        default:
            return false
        }
    }

    var emergencyNumber: String {
        self == .unitedKingdom ? "999" : "112"
    }

    var policeNonEmergencyNumber: String? {
        switch self {
        case .unitedKingdom: return "101"
        case .france: return "17"
        case .ireland: return "112"
        default: return isEuropeOrIreland ? "112" : nil
        }
    }

    static func inferred(fromCountryCode countryCode: String?) -> AccidentJurisdiction? {
        guard let code = countryCode?.uppercased(), !code.isEmpty else { return nil }
        switch code {
        case "GB": return .unitedKingdom
        case "IE": return .ireland
        case "FR": return .france
        case "ES": return .spain
        case "DE": return .germany
        default:
            return europeanCountryCodes.contains(code) ? .europeanUnion : .other
        }
    }

    private static let europeanCountryCodes: Set<String> = [
        "AD", "AL", "AT", "BA", "BE", "BG", "BY", "CH", "CY", "CZ",
        "DK", "EE", "FI", "GR", "HR", "HU", "IS", "IT", "LI", "LT",
        "LU", "LV", "MC", "MD", "ME", "MK", "MT", "NL", "NO", "PL",
        "PT", "RO", "RS", "SE", "SI", "SK", "SM", "TR", "UA", "VA"
    ]
}

enum AccidentRedFlag: String, Codable, CaseIterable, Identifiable, Sendable {
    case invalidMOT
    case sorn
    case untaxed
    case markedForExport
    case plateMismatch
    case foreignPlate
    case suspectedUninsured
    case hitAndRun

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .invalidMOT: return "MOT not valid"
        case .sorn: return "SORN"
        case .untaxed: return "Untaxed"
        case .markedForExport: return "Marked for export"
        case .plateMismatch: return "Plate may not match vehicle"
        case .foreignPlate: return "Foreign registration"
        case .suspectedUninsured: return "Insurance not confirmed"
        case .hitAndRun: return "Hit and run"
        }
    }

    var raisesPoliceReportInUK: Bool {
        switch self {
        case .invalidMOT, .sorn, .untaxed, .markedForExport, .plateMismatch, .suspectedUninsured, .hitAndRun:
            return true
        case .foreignPlate:
            return false
        }
    }
}

enum AccidentProcessBranch: String, Codable, CaseIterable, Sendable {
    case ukStandard
    case ukPoliceFlag
    case ukForeignVehicle
    case europeEAS
    case francePaperEAS
    case otherAbroad

    var displayName: String {
        switch self {
        case .ukStandard: return "UK — exchange details"
        case .ukPoliceFlag: return "UK — consider reporting to police"
        case .ukForeignVehicle: return "UK — foreign vehicle"
        case .europeEAS: return "Europe — accident statement"
        case .francePaperEAS: return "France — paper accident statement"
        case .otherAbroad: return "Abroad"
        }
    }
}

enum AccidentPhotoKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case positions
    case damageOwn
    case damageOther
    case plate
    case hitch
    case trailer
    case road
    case documents
    case drivingLicence
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .positions: return "Vehicle positions"
        case .damageOwn: return "Damage to your vehicle"
        case .damageOther: return "Damage to other vehicle"
        case .plate: return "Number plates"
        case .hitch: return "Hitch and coupling"
        case .trailer: return "Caravan or trailer"
        case .road: return "Road, signs and debris"
        case .documents: return "Insurance or Green Card"
        case .drivingLicence: return "Driving licence"
        case .other: return "Other"
        }
    }

    var guidance: String {
        switch self {
        case .positions:
            return "If it is safe, photograph where the vehicles stopped before anything is moved."
        case .damageOwn:
            return "Close-ups and wider shots of damage to your vehicle, including the tow vehicle if you were towing."
        case .damageOther:
            return "Damage on the other vehicle or vehicles, wide and close."
        case .plate:
            return "Every number plate involved — tow vehicle and caravan or trailer separately."
        case .hitch:
            return "Hitch, A-frame, coupling, breakaway cable and jockey wheel."
        case .trailer:
            return "Caravan or trailer body, corner steadies and any load shift inside if safe."
        case .road:
            return "Road layout, markings, signs, lights, debris, skid marks, weather and landmarks."
        case .documents:
            return "Only if the other driver shows insurance or a Green Card — do not take documents from them."
        case .drivingLicence:
            return "Only photograph a driving licence if the driver offers it and agrees. They do not have to let you photograph it. UK and EU photocards can be read automatically."
        case .other:
            return "Anything else that may help your insurer understand what happened."
        }
    }
}

enum AccidentRecorderStep: Int, CaseIterable, Identifiable, Sendable {
    case scene = 1
    case doNow = 2
    case vehicles = 3
    case photos = 4
    case details = 5
    case review = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .scene: return "Scene"
        case .doNow: return "Do now"
        case .vehicles: return "Vehicles"
        case .photos: return "Photos"
        case .details: return "Details"
        case .review: return "Review"
        }
    }
}

@Model
final class AccidentRecord {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var occurredAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var jurisdictionRaw: String = AccidentJurisdiction.unitedKingdom.rawValue
    var latitude: Double = 0
    var longitude: Double = 0
    var locationDescription: String = ""
    var what3Words: String = ""

    var anyoneInjured: Bool = false
    var sceneUnsafeOrBlocked: Bool = false
    var suspectedImpairmentOrViolence: Bool = false
    var hitAndRun: Bool = false
    var detailsExchanged: Bool = false
    var insuranceCertificateSeen: Bool = false
    var otherDriverRefused: Bool = false
    /// True when this was a single-vehicle incident (no other party to exchange with).
    var noOtherVehicle: Bool = false
    /// True when a caravan or trailer was attached at the time of the incident.
    var wasTowing: Bool = false

    var policeReported: Bool = false
    var policeReference: String = ""
    var insurerNotified: Bool = false

    /// Your name at the time of this incident (for exchanging details). Not stored on the vehicle profile.
    var ownName: String = ""
    /// Your address at the time of this incident.
    var ownAddress: String = ""
    /// Your phone at the time of this incident.
    var ownPhone: String = ""

    /// Vehicle you were driving — often the tow car, not the caravan or motorhome this incident is filed against.
    var ownRegistration: String = ""
    /// Insurer for the vehicle you were driving. Prefills from Settings; may differ from the profiled vehicle.
    var ownInsurerName: String = ""
    var ownInsurancePolicyNumber: String = ""
    var ownInsuranceClaimsPhone: String = ""

    var ownLookupMake: String = ""
    var ownLookupModel: String = ""
    var ownLookupColour: String = ""
    var ownLookupTaxStatus: String = ""
    var ownLookupMotStatus: String = ""
    var ownLookupMotExpiryDate: Date?
    var ownLookupMarkedForExport: Bool = false
    var ownLookupCheckedAt: Date?
    var ownLookupPending: Bool = false
    var ownLookupErrorMessage: String = ""
    /// Normalised plate the own-vehicle lookup snapshot belongs to.
    var ownLookupRegistration: String = ""

    var factualNotes: String = ""
    var easCircumstancesNotes: String = ""
    var weatherNotes: String = ""

    /// Nearby fixed cameras (shops, junctions, car parks) that might have caught the collision.
    var cctvNearbyVisible: Bool = false
    /// A witness said they have dashcam, phone video, or other footage.
    var cctvWitnessesMentioned: Bool = false
    /// An uninvolved lorry or HGV nearby — many carry several outward-facing cameras.
    var cctvNearbyLorry: Bool = false
    var cctvNotes: String = ""

    var processBranchRaw: String = AccidentProcessBranch.ukStandard.rawValue

    @Relationship(deleteRule: .cascade, inverse: \AccidentOtherVehicle.record)
    var otherVehicles: [AccidentOtherVehicle]?

    @Relationship(deleteRule: .cascade, inverse: \AccidentWitness.record)
    var witnesses: [AccidentWitness]?

    @Relationship(deleteRule: .cascade, inverse: \AccidentPhoto.record)
    var photos: [AccidentPhoto]?

    init(id: UUID = UUID(), vehicleID: UUID, occurredAt: Date = Date()) {
        self.id = id
        self.vehicleID = vehicleID
        self.occurredAt = occurredAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var jurisdiction: AccidentJurisdiction {
        get { AccidentJurisdiction(rawValue: jurisdictionRaw) ?? .unitedKingdom }
        set { jurisdictionRaw = newValue.rawValue }
    }

    var processBranch: AccidentProcessBranch {
        get { AccidentProcessBranch(rawValue: processBranchRaw) ?? .ukStandard }
        set { processBranchRaw = newValue.rawValue }
    }

    var hasCoordinate: Bool {
        latitude != 0 || longitude != 0
    }

    var otherVehiclesList: [AccidentOtherVehicle] {
        (otherVehicles ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var witnessesList: [AccidentWitness] {
        (witnesses ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var photosList: [AccidentPhoto] {
        (photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    var displayOwnRegistration: String {
        let trimmed = ownRegistration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return UKRegistration.displayFormatted(trimmed)
    }

    var hasOwnLookupSnapshot: Bool {
        !ownLookupMake.isEmpty
            || !ownLookupModel.isEmpty
            || !ownLookupColour.isEmpty
            || !ownLookupMotStatus.isEmpty
            || !ownLookupTaxStatus.isEmpty
            || ownLookupCheckedAt != nil
    }

    /// True when the stored snapshot was fetched for a different plate than the one now entered.
    var ownLookupSnapshotIsStale: Bool {
        guard hasOwnLookupSnapshot else { return false }
        return UKRegistration.normalizeForLookup(ownRegistration) != ownLookupRegistration
    }

    var ownLookupIdentityLine: String {
        [ownLookupMake, ownLookupModel, ownLookupColour]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

@Model
final class AccidentOtherVehicle {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var registration: String = ""
    var registrationCountry: String = ""
    var isForeignRegistration: Bool = false

    var driverName: String = ""
    var driverAddress: String = ""
    var driverPhone: String = ""
    var ownerName: String = ""
    var ownerAddress: String = ""

    var insurerName: String = ""
    var insurancePolicyNumber: String = ""
    var greenCardNumber: String = ""

    var lookupMake: String = ""
    var lookupModel: String = ""
    var lookupColour: String = ""
    var lookupTaxStatus: String = ""
    var lookupMotStatus: String = ""
    var lookupMotExpiryDate: Date?
    var lookupMarkedForExport: Bool = false
    var lookupCheckedAt: Date?
    var lookupPending: Bool = false
    var lookupErrorMessage: String = ""
    /// Normalised plate the lookup snapshot belongs to, so a stale snapshot is never shown against a new plate.
    var lookupRegistration: String = ""
    var userConfirmedMake: String = ""
    var userConfirmedColour: String = ""
    var redFlagsRaw: String = ""

    var record: AccidentRecord?

    init(id: UUID = UUID(), record: AccidentRecord) {
        self.id = id
        self.record = record
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var redFlags: [AccidentRedFlag] {
        get {
            redFlagsRaw
                .split(separator: ",")
                .compactMap { AccidentRedFlag(rawValue: String($0)) }
        }
        set {
            redFlagsRaw = newValue.map(\.rawValue).joined(separator: ",")
        }
    }

    var displayRegistration: String {
        let trimmed = registration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No plate yet" }
        if isForeignRegistration { return trimmed.uppercased() }
        return UKRegistration.displayFormatted(trimmed)
    }

    var hasLookupSnapshot: Bool {
        !lookupMake.isEmpty
            || !lookupModel.isEmpty
            || !lookupColour.isEmpty
            || !lookupMotStatus.isEmpty
            || !lookupTaxStatus.isEmpty
            || lookupCheckedAt != nil
    }

    /// True when the stored snapshot was fetched for a different plate than the one now entered.
    var lookupSnapshotIsStale: Bool {
        guard hasLookupSnapshot else { return false }
        return UKRegistration.normalizeForLookup(registration) != lookupRegistration
    }
}

@Model
final class AccidentWitness {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var name: String = ""
    var phone: String = ""
    var notes: String = ""
    /// Witness said they have dashcam, phone video, or other CCTV of the incident.
    var hasFootage: Bool = false

    var record: AccidentRecord?

    init(id: UUID = UUID(), record: AccidentRecord) {
        self.id = id
        self.record = record
        self.createdAt = Date()
    }
}

@Model
final class AccidentPhoto {
    var id: UUID = UUID()
    var vehicleID: UUID = UUID()
    var kindRaw: String = AccidentPhotoKind.other.rawValue
    var capturedAt: Date = Date()
    var localFileName: String = ""
    /// Legacy CloudKit asset field. Kept nil; JPEG bytes live on disk only.
    @Attribute(.externalStorage)
    var imageData: Data? = nil
    var caption: String = ""
    var createdAt: Date = Date()

    var record: AccidentRecord?

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        record: AccidentRecord,
        kind: AccidentPhotoKind,
        localFileName: String
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.record = record
        self.kindRaw = kind.rawValue
        self.localFileName = localFileName
        self.imageData = nil
        self.capturedAt = Date()
        self.createdAt = Date()
    }

    var kind: AccidentPhotoKind {
        get { AccidentPhotoKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}
