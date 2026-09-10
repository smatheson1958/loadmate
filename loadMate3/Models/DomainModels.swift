import Foundation
import SwiftData

enum VehicleKind: String, Codable, CaseIterable, Identifiable {
    case caravan
    case motorhome

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .caravan: return "Caravan"
        case .motorhome: return "Motorhome"
        }
    }

    var systemImage: String {
        switch self {
        case .caravan: return "tow.hitch.fill"
        case .motorhome: return "bus.fill"
        }
    }
}

/// Wheels currently fitted — caravans often plate both steel and alloy Nm, but only one set is in use.
enum FittedWheelMaterial: String, Codable, CaseIterable, Identifiable {
    case steel
    case alloy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steel: return "Steel"
        case .alloy: return "Alloy"
        }
    }
}

/// What mass to use when calculating the 5%–7% nose weight safe band.
enum NoseSafeZoneBasis: String, Codable, CaseIterable, Identifiable {
    case mtplm
    case ladenWeight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mtplm: return "MTPLM"
        case .ladenWeight: return "Laden weight"
        }
    }
}

enum LoadZone: String, Codable, CaseIterable, Identifiable {
    // Caravan
    case frontLocker
    case middle
    case rear
    case bikeRack
    // Shared
    case front
    // Motorhome
    case driver
    case central
    case back
    case garage
    case unassigned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frontLocker: return "Front Locker"
        case .front: return "Front"
        case .middle: return "Middle (Axle)"
        case .rear: return "Rear"
        case .bikeRack: return "Bike Rack"
        case .driver: return "Cab"
        case .central: return "Central"
        case .back: return "Back"
        case .garage: return "Garage"
        case .unassigned: return "Unassigned"
        }
    }
}

@Model
final class VehicleProfile {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = VehicleKind.caravan.rawValue
    var sortOrder: Int = 0

    /// VIN / chassis / CRiS number from the manufacturer plate (optional).
    var vinChassisNumber: String = ""

    /// Converter body / cell number from some EU motorhome plates (e.g. Rapido N° de cellule).
    var bodyCellNumber: String = ""

    /// UK registration mark (motorhome). Optional; used for vehicle lookup.
    var registrationMark: String = ""

    /// Brand / maker from the manufacturer plate (optional), e.g. "Swift".
    var manufacturer: String = ""
    /// Model / range from the manufacturer plate (optional), e.g. "Conqueror 645".
    var modelName: String = ""

    /// Year of first UK registration from vehicle lookup (optional).
    var firstRegistrationYear: Int?
    /// Date of last MOT from vehicle lookup (optional).
    var lastMotDate: Date?
    /// MOT expiry from vehicle lookup (optional). Used to show "MOT due" when expired.
    var motExpiryDate: Date?

    /// Local filename for the last scanned manufacturer plate photo (empty when none).
    var manufacturerPlatePhotoFileName: String = ""
    /// Legacy CloudKit asset field. Kept nil; JPEG bytes live on disk only.
    @Attribute(.externalStorage)
    var manufacturerPlatePhotoData: Data? = nil

    /// Wheel nut torque for steel wheels from the caravan manufacturer plate (Nm). 0 = not set.
    var wheelNutTorqueSteelNm: Double = 0
    /// Wheel nut torque for alloy wheels from the caravan manufacturer plate (Nm). 0 = not set.
    var wheelNutTorqueAlloyNm: Double = 0
    /// Single wheel nut torque for motorhomes from the base vehicle handbook (Nm). 0 = not set.
    var wheelNutTorqueNm: Double = 0
    /// Fitted wheel material for caravans (`steel` / `alloy`). Empty infers from plated values.
    var fittedWheelMaterialRaw: String = ""

    /// Manufacturer MIRO / MRO — used when no weighbridge reading is entered.
    var baseWeightKg: Double = 0
    /// Measured laden mass before trip items (caravan total or motorhome gross).
    var weighbridgeWeightKg: Double = 0

    /// MTPLM (caravan) or MAM (motorhome).
    var mtplmKg: Double = 0
    /// Gross train weight (vehicle + trailer maximum). 0 = not set. Informational — not tow-bar nose load.
    var gtwKg: Double = 0

    // MARK: Caravan

    var caravanMaxNoseKg: Double = 0
    var carMaxTowBallKg: Double = 0
    var noseWeightBasePercent: Double = 6.0
    /// Stored basis for 5%–7% safe zone; default MTPLM for existing profiles.
    var noseSafeZoneBasisRaw: String = NoseSafeZoneBasis.mtplm.rawValue

    var factorFrontLocker: Double = 0.25
    var factorFront: Double = 0.15
    var factorMiddle: Double = 0
    var factorRear: Double = -0.20
    var factorBikeRack: Double = -0.35
    /// Rear bike rack fitted — controls placement art and whether the bike rack zone is offered.
    var hasBikeRack: Bool = false

    // MARK: Motorhome axle weighbridge & limits

    var weighbridgeFrontAxleKg: Double = 0
    var weighbridgeRearAxleKg: Double = 0
    /// Used when axle weights are not entered: front axle share of base mass (%).
    var axleSplitFrontPercent: Double = 45
    var maxFrontAxleKg: Double = 0
    var maxRearAxleKg: Double = 0
    /// Max load for the rear garage / overhang box (0 = not set — no separate limit).
    var maxGarageKg: Double = 0
    /// When true, trip items in the bike rack zone count toward `maxGarageKg` (manufacturer combined rear limit).
    var garageLimitIncludesBikeRack: Bool = false
    /// Motorhome: user tows with a tow bar — enter load per trip on the Load tab.
    var usesManualTowBarLoad: Bool = false
    /// Maximum tow bar (nose) load the motorhome tow bar can take (0 = not set).
    var maxTowBarKg: Double = 0

    /// Motorhome: kg added to each axle estimate per kg of item in that zone.
    var mhFactorDriverFront: Double = 0.75
    var mhFactorDriverRear: Double = 0.15
    var mhFactorFrontFront: Double = 0.95
    var mhFactorFrontRear: Double = 0.05
    var mhFactorCentralFront: Double = 0.50
    var mhFactorCentralRear: Double = 0.50
    var mhFactorBackFront: Double = 0.05
    var mhFactorBackRear: Double = 0.95
    var mhFactorGarageFront: Double = 0.02
    var mhFactorGarageRear: Double = 0.98
    var mhFactorBikeRackFront: Double = -0.08
    var mhFactorBikeRackRear: Double = 1.08

    /// Last-selected load setup for this vehicle (beach, Europe, etc.).
    var activeTripID: UUID?

    /// Starter kit was loaded for this profile — hide the one-time load option.
    var hasAppliedStarterKit: Bool = false

    /// When false, warranty tab and related shortcuts are hidden for this vehicle.
    var warrantyAvailable: Bool = true

    /// When true, UK/NI manufacturer warranty starters are offered. Outside the UK, owners build a custom plan.
    var warrantyUKMarket: Bool = true

    /// Policy start / renewal anniversary. Nil when not set. Used for yearly insurance check actions.
    var insuranceStartDate: Date? = nil
    /// Insurer name for accident recorder prefill.
    var insuranceProviderName: String = ""
    /// Policy number for accident recorder prefill.
    var insurancePolicyNumber: String = ""
    /// 24-hour claims phone for accident recorder prefill.
    var insuranceClaimsPhone: String = ""

    // MARK: External dimensions (handbook / plate — for route and site planning)

    /// External body width in metres (e.g. 2.35).
    var externalWidthM: Double = 0
    /// External body height in metres (e.g. 2.74).
    var externalHeightM: Double = 0
    /// Overall length in metres (e.g. 7.20).
    var externalLengthM: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \Trip.profile)
    var trips: [Trip]?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistSection.profile)
    var checklistSections: [ChecklistSection]?

    /// Legacy loaded-item links kept for migration from pre-trip stores.
    @Relationship(deleteRule: .nullify, inverse: \LoadedItem.profile)
    var legacyLoadedItems: [LoadedItem]?

    init(
        id: UUID = UUID(),
        name: String = "My vehicle",
        kind: VehicleKind = .caravan,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.vinChassisNumber = ""
        self.bodyCellNumber = ""
        self.registrationMark = ""
        self.manufacturer = ""
        self.modelName = ""
        self.manufacturerPlatePhotoFileName = ""
        self.manufacturerPlatePhotoData = nil
        self.firstRegistrationYear = nil
        self.lastMotDate = nil
        self.motExpiryDate = nil
        self.wheelNutTorqueSteelNm = 0
        self.wheelNutTorqueAlloyNm = 0
        self.wheelNutTorqueNm = 0
        self.fittedWheelMaterialRaw = ""
        self.baseWeightKg = 0
        self.weighbridgeWeightKg = 0
        self.mtplmKg = 0
        self.gtwKg = 0
        self.caravanMaxNoseKg = 0
        self.carMaxTowBallKg = 0
        self.noseWeightBasePercent = 6.0
        self.noseSafeZoneBasisRaw = NoseSafeZoneBasis.mtplm.rawValue
        self.factorFrontLocker = 0.25
        self.factorFront = 0.15
        self.factorMiddle = 0.0
        self.factorRear = -0.20
        self.factorBikeRack = -0.35
        self.hasBikeRack = false
        self.weighbridgeFrontAxleKg = 0
        self.weighbridgeRearAxleKg = 0
        self.axleSplitFrontPercent = 45
        self.maxFrontAxleKg = 0
        self.maxRearAxleKg = 0
        self.maxGarageKg = 0
        self.garageLimitIncludesBikeRack = false
        self.usesManualTowBarLoad = false
        self.maxTowBarKg = 0
        self.mhFactorDriverFront = 0.75
        self.mhFactorDriverRear = 0.15
        self.mhFactorFrontFront = 0.95
        self.mhFactorFrontRear = 0.05
        self.mhFactorCentralFront = 0.50
        self.mhFactorCentralRear = 0.50
        self.mhFactorBackFront = 0.05
        self.mhFactorBackRear = 0.95
        self.mhFactorGarageFront = 0.02
        self.mhFactorGarageRear = 0.98
        self.mhFactorBikeRackFront = -0.08
        self.mhFactorBikeRackRear = 1.08
        self.externalWidthM = 0
        self.externalHeightM = 0
        self.externalLengthM = 0
    }

    var hasExternalDimensions: Bool {
        externalWidthM > 0 || externalHeightM > 0 || externalLengthM > 0
    }

    var kind: VehicleKind {
        get { VehicleKind(rawValue: kindRaw) ?? .caravan }
        set { kindRaw = newValue.rawValue }
    }

    static func applyCaravanFactorDefaults(to profile: VehicleProfile) {
        profile.factorFrontLocker = 0.25
        profile.factorFront = 0.15
        profile.factorMiddle = 0.0
        profile.factorRear = -0.20
        profile.factorBikeRack = -0.35
    }

    /// Per-kg factors: how much each kg in a zone adds to front vs rear axle estimates.
    /// Cab ahead of the front axle; Middle between axles; Rear above the rear axle; Garage and bike rack behind the rear axle.
    static func applyMotorhomeFactorDefaults(to profile: VehicleProfile) {
        profile.mhFactorDriverFront = 0.75
        profile.mhFactorDriverRear = 0.15
        profile.mhFactorFrontFront = 0.95
        profile.mhFactorFrontRear = 0.05
        profile.mhFactorCentralFront = 0.50
        profile.mhFactorCentralRear = 0.50
        profile.mhFactorBackFront = 0.05
        profile.mhFactorBackRear = 0.95
        profile.mhFactorGarageFront = 0.02
        profile.mhFactorGarageRear = 0.98
        profile.mhFactorBikeRackFront = -0.08
        profile.mhFactorBikeRackRear = 1.08
    }
}

extension VehicleProfile {
    var fittedWheelMaterial: FittedWheelMaterial {
        get {
            if let stored = FittedWheelMaterial(rawValue: fittedWheelMaterialRaw) {
                return stored
            }
            if wheelNutTorqueAlloyNm > 0, wheelNutTorqueSteelNm <= 0 {
                return .alloy
            }
            return .steel
        }
        set {
            fittedWheelMaterialRaw = newValue.rawValue
        }
    }

    /// Torque for the wheels currently fitted (caravan) or the handbook figure (motorhome).
    var activeWheelNutTorqueNm: Double {
        get {
            switch kind {
            case .motorhome:
                return resolvedMotorhomeWheelNutTorqueNm
            case .caravan:
                switch fittedWheelMaterial {
                case .steel: return wheelNutTorqueSteelNm
                case .alloy: return wheelNutTorqueAlloyNm
                }
            }
        }
        set {
            switch kind {
            case .motorhome:
                wheelNutTorqueNm = newValue
            case .caravan:
                if fittedWheelMaterialRaw.isEmpty {
                    fittedWheelMaterialRaw = fittedWheelMaterial.rawValue
                }
                switch fittedWheelMaterial {
                case .steel: wheelNutTorqueSteelNm = newValue
                case .alloy: wheelNutTorqueAlloyNm = newValue
                }
            }
        }
    }

    var hasActiveWheelNutTorque: Bool {
        activeWheelNutTorqueNm > 0
    }

    var wheelNutTorqueSectionCaption: String {
        switch kind {
        case .motorhome:
            return "From the base vehicle handbook, not the converter plate."
        case .caravan:
            return "From the manufacturer plate. Choose the wheels fitted now."
        }
    }

    var activeWheelNutTorqueFieldCaption: String {
        switch kind {
        case .motorhome:
            return "Fiat, Ford, Mercedes or aftermarket wheel maker"
        case .caravan:
            switch fittedWheelMaterial {
            case .steel: return "Steel wheels — from the manufacturer plate"
            case .alloy: return "Alloy wheels — from the manufacturer plate"
            }
        }
    }

    private var resolvedMotorhomeWheelNutTorqueNm: Double {
        if wheelNutTorqueNm > 0 { return wheelNutTorqueNm }
        if wheelNutTorqueSteelNm > 0 { return wheelNutTorqueSteelNm }
        return wheelNutTorqueAlloyNm
    }

    func migrateLegacyMotorhomeWheelNutTorqueIfNeeded() {
        guard kind == .motorhome, wheelNutTorqueNm <= 0 else { return }
        let legacy = wheelNutTorqueSteelNm > 0 ? wheelNutTorqueSteelNm : wheelNutTorqueAlloyNm
        guard legacy > 0 else { return }
        wheelNutTorqueNm = legacy
    }

    func applyCaravanPlateTorque(steelNm: Double?, alloyNm: Double?) {
        guard kind == .caravan else { return }
        let steel = steelNm ?? 0
        let alloy = alloyNm ?? 0
        if steel > 0 { wheelNutTorqueSteelNm = steel }
        if alloy > 0 { wheelNutTorqueAlloyNm = alloy }
        guard fittedWheelMaterialRaw.isEmpty else { return }
        if steel > 0, alloy <= 0 {
            fittedWheelMaterial = .steel
        } else if alloy > 0, steel <= 0 {
            fittedWheelMaterial = .alloy
        }
    }

    /// iPad cutaway asset for the active vehicle configuration.
    var padCutawayAssetName: String {
        switch kind {
        case .caravan:
            return hasBikeRack ? "caravanAndBike" : "Caravan"
        case .motorhome:
            switch (usesManualTowBarLoad, hasBikeRack) {
            case (true, true): return "MotorhomeTowBike"
            case (true, false): return "MotorhomeTow"
            case (false, true): return "MotorhomeBike"
            case (false, false): return "Motorhome"
            }
        }
    }

    /// Zone chips left-to-right above the iPad cutaway (front/cab on the left, rear on the right).
    var padZoneDisplayOrder: [LoadZone] {
        switch kind {
        case .caravan:
            let zones: [LoadZone] = [.frontLocker, .front, .middle, .rear, .bikeRack]
            return hasBikeRack ? zones : zones.filter { $0 != .bikeRack }
        case .motorhome:
            let zones: [LoadZone] = [.driver, .central, .back, .garage, .bikeRack]
            return hasBikeRack ? zones : zones.filter { $0 != .bikeRack }
        }
    }

    /// Wording for garage limit UI when monitoring rear storage.
    var garageLimitSourcesLabel: String {
        garageLimitIncludesBikeRack ? "Garage and bike rack" : "Garage only"
    }

    var effectiveMaxTowBallKg: Double {
        let limits = [carMaxTowBallKg, caravanMaxNoseKg].filter { $0 > 0 }
        return limits.min() ?? 0
    }

    var noseSafeZoneBasis: NoseSafeZoneBasis {
        get { NoseSafeZoneBasis(rawValue: noseSafeZoneBasisRaw) ?? .mtplm }
        set { noseSafeZoneBasisRaw = newValue.rawValue }
    }

    /// Mass used for 5% / 7% nose safe-zone bounds (car and hitch caps still apply separately).
    func noseSafeZoneReferenceWeightKg(totalLadenWeightKg: Double) -> Double {
        switch noseSafeZoneBasis {
        case .mtplm:
            return mtplmKg > 0 ? mtplmKg : totalLadenWeightKg
        case .ladenWeight:
            return totalLadenWeightKg
        }
    }

    var calculationBaseWeightKg: Double {
        if kind == .motorhome {
            let axleSum = weighbridgeFrontAxleKg + weighbridgeRearAxleKg
            if MotorhomeWeighbridgeValidation.shouldUseAxleSumForBaseWeight(profile: self) {
                return axleSum
            }
            if weighbridgeWeightKg > 0 { return weighbridgeWeightKg }
            if axleSum > 0 { return axleSum }
        }
        return weighbridgeWeightKg > 0 ? weighbridgeWeightKg : baseWeightKg
    }

    var baselineFrontAxleKg: Double {
        if kind == .motorhome, motorhomeHasConflictingWeighbridgeEntries {
            let pct = axleSplitFrontPercent > 0 ? axleSplitFrontPercent : 45
            return calculationBaseWeightKg * (pct / 100.0)
        }
        if weighbridgeFrontAxleKg > 0 { return weighbridgeFrontAxleKg }
        let pct = axleSplitFrontPercent > 0 ? axleSplitFrontPercent : 45
        return calculationBaseWeightKg * (pct / 100.0)
    }

    var baselineRearAxleKg: Double {
        if kind == .motorhome, motorhomeHasConflictingWeighbridgeEntries {
            return calculationBaseWeightKg - baselineFrontAxleKg
        }
        if weighbridgeRearAxleKg > 0 { return weighbridgeRearAxleKg }
        return calculationBaseWeightKg - baselineFrontAxleKg
    }

    var isConfiguredForWeightCalculations: Bool {
        missingWeightCalculationFieldLabels.isEmpty
    }

    /// Settings labels for required fields that are still empty (matches Settings field titles).
    var missingWeightCalculationFieldLabels: [String] {
        switch kind {
        case .caravan:
            var missing: [String] = []
            if calculationBaseWeightKg <= 0 {
                missing.append("MIRO (kg) or weighbridge weight (kg)")
            }
            if mtplmKg <= 0 {
                missing.append("MTPLM (kg)")
            }
            if carMaxTowBallKg <= 0 {
                missing.append("Car tow ball limit (kg)")
            }
            return missing
        case .motorhome:
            var missing: [String] = []
            if calculationBaseWeightKg <= 0 {
                missing.append("MRO (kg) or weighbridge weight")
            }
            if mtplmKg <= 0 {
                missing.append("MAM (kg)")
            }
            if maxFrontAxleKg <= 0 {
                missing.append("Max front axle (kg)")
            }
            if maxRearAxleKg <= 0 {
                missing.append("Max rear axle (kg)")
            }
            return missing
        }
    }

    /// Motorhome: plated axle limits are required before weight calculations can run.
    var isMissingMotorhomePlatedAxleLimits: Bool {
        kind == .motorhome && (maxFrontAxleKg <= 0 || maxRearAxleKg <= 0)
    }

    /// Message when required Settings fields are incomplete (Summary, Load, setup alert).
    var weightCalculationSetupSummaryMessage: String {
        if isMissingMotorhomePlatedAxleLimits {
            return Self.motorhomePlatedAxleLimitsRequiredMessage
        }
        return Self.summarySetupMessage(forMissingFieldLabels: missingWeightCalculationFieldLabels)
    }

    static let motorhomePlatedAxleLimitsRequiredMessage =
        "We can't move forward until the plated front and rear axle limits are entered in Settings."

    static func summarySetupMessage(forMissingFieldLabels labels: [String]) -> String {
        guard !labels.isEmpty else {
            return "Open Settings and complete your vehicle profile."
        }
        let fieldList = formattedFieldList(labels)
        if labels.count == 1 {
            return "Can't show summary information until \(fieldList) has been completed in Settings."
        }
        return "Can't show summary information until \(fieldList) have been completed in Settings."
    }

    private static func formattedFieldList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            let prefix = items.dropLast().joined(separator: ", ")
            return "\(prefix), and \(items[items.count - 1])"
        }
    }

    var grossMassLabel: String {
        kind == .motorhome ? "MAM" : "MTPLM"
    }
}

/// Subjective towing/handling rating recorded per trip after a real tow or test drive.
enum TowingExperience: String, Codable, CaseIterable, Identifiable {
    case notSet
    case excellent
    case good
    case fair
    case poor
    case unstable
    case notTowedYet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notSet: return "Not set"
        case .excellent: return "Great — stable"
        case .good: return "OK"
        case .fair: return "A bit twitchy"
        case .poor: return "Poor"
        case .unstable: return "Sway / instability"
        case .notTowedYet: return "Not towed yet"
        }
    }

    /// Options shown in the trip-notes picker (excludes the unset sentinel).
    static var pickerCases: [TowingExperience] {
        allCases.filter { $0 != .notSet }
    }
}

/// Loading configuration (named load setup for a vehicle).
/// User-facing name is "Loading Configuration"; the SwiftData type remains `Trip`.
@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    /// Manually entered tow bar (nose) load for this trip (kg).
    var manualTowBarLoadKg: Double = 0
    /// Caravan: nose weight measured on a gauge for this trip (kg). 0 = not set.
    var measuredNoseWeightKg: Double = 0
    /// Caravan: subjective towing experience for this trip setup.
    var towingExperienceRaw: String = TowingExperience.notSet.rawValue
    /// Free-form notes for this trip loading (caravan short notes; motorhome general notes).
    var tripNotes: String = ""

    var profile: VehicleProfile?

    @Relationship(deleteRule: .cascade, inverse: \LoadedItem.trip)
    var loadedItems: [LoadedItem]?

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        manualTowBarLoadKg: Double = 0,
        measuredNoseWeightKg: Double = 0,
        towingExperienceRaw: String = TowingExperience.notSet.rawValue,
        tripNotes: String = "",
        profile: VehicleProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.manualTowBarLoadKg = manualTowBarLoadKg
        self.measuredNoseWeightKg = measuredNoseWeightKg
        self.towingExperienceRaw = towingExperienceRaw
        self.tripNotes = tripNotes
        self.profile = profile
    }

    var towingExperience: TowingExperience {
        get { TowingExperience(rawValue: towingExperienceRaw) ?? .notSet }
        set { towingExperienceRaw = newValue.rawValue }
    }

    func hasLoadingNotes(for kind: VehicleKind) -> Bool {
        switch kind {
        case .caravan:
            return measuredNoseWeightKg > 0
                || towingExperience != .notSet
                || !trimmedTripNotes.isEmpty
        case .motorhome:
            return !trimmedTripNotes.isEmpty
        }
    }

    var trimmedTripNotes: String {
        tripNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class LibraryItem {
    var id: UUID = UUID()
    var name: String = ""
    var weightKg: Double = 0
    var defaultZoneRaw: String?

    @Relationship(deleteRule: .nullify, inverse: \LoadedItem.item)
    var loadedReferences: [LoadedItem]?

    init(id: UUID = UUID(), name: String, weightKg: Double, defaultZoneRaw: String? = nil) {
        self.id = id
        self.name = name
        self.weightKg = weightKg
        self.defaultZoneRaw = defaultZoneRaw
    }

    var defaultZone: LoadZone? {
        get { defaultZoneRaw.flatMap(LoadZone.init(rawValue:)) }
        set { defaultZoneRaw = newValue?.rawValue }
    }
}

@Model
final class LoadedItem {
    var id: UUID = UUID()
    var quantity: Int = 1
    var zoneRaw: String = LoadZone.unassigned.rawValue
    var loadedAt: Date = Date()
    var item: LibraryItem?
    var trip: Trip?
    /// Legacy link; new items use `trip` only. Kept for SwiftData migration from older stores.
    var profile: VehicleProfile?

    init(
        id: UUID = UUID(),
        item: LibraryItem,
        quantity: Int = 1,
        zone: LoadZone = .unassigned,
        loadedAt: Date = Date(),
        trip: Trip? = nil,
        profile: VehicleProfile? = nil
    ) {
        self.id = id
        self.item = item
        self.quantity = quantity
        self.zoneRaw = zone.rawValue
        self.loadedAt = loadedAt
        self.trip = trip
        self.profile = profile ?? trip?.profile
    }

    var zone: LoadZone {
        get {
            let kind = (trip?.profile ?? profile)?.kind ?? .caravan
            return LoadZone.resolved(rawValue: zoneRaw, for: kind)
        }
        set { zoneRaw = newValue.rawValue }
    }
}

@Model
final class AppState {
    var id: UUID = LoadMateSyncIDs.appState
    var disclaimerAccepted: Bool = false
    var acceptedAt: Date?
    var activeProfileID: UUID?
    /// Prevents duplicate default vehicle profiles when multiple devices bootstrap before iCloud sync completes.
    var didSeedDefaultProfiles: Bool = false
    /// Prevents duplicate built-in checklist templates across devices.
    var didSeedDefaultChecklist: Bool = false
    /// Copies the former shared checklist onto every vehicle once, then deletes unscoped rows.
    var didMigrateChecklistsToVehicles: Bool = false
    /// Hidden developer probe for confirming CloudKit export/import on real devices.
    var syncProbeSequence: Int = 0
    var syncProbeValue: String = ""
    var syncProbeUpdatedAt: Date?
    var syncProbeUpdatedBy: String = ""

    init(
        id: UUID = LoadMateSyncIDs.appState,
        disclaimerAccepted: Bool = false,
        acceptedAt: Date? = nil,
        activeProfileID: UUID? = nil,
        didSeedDefaultProfiles: Bool = false,
        didSeedDefaultChecklist: Bool = false,
        didMigrateChecklistsToVehicles: Bool = false,
        syncProbeSequence: Int = 0,
        syncProbeValue: String = "",
        syncProbeUpdatedAt: Date? = nil,
        syncProbeUpdatedBy: String = ""
    ) {
        self.id = id
        self.disclaimerAccepted = disclaimerAccepted
        self.acceptedAt = acceptedAt
        self.activeProfileID = activeProfileID
        self.didSeedDefaultProfiles = didSeedDefaultProfiles
        self.didSeedDefaultChecklist = didSeedDefaultChecklist
        self.didMigrateChecklistsToVehicles = didMigrateChecklistsToVehicles
        self.syncProbeSequence = syncProbeSequence
        self.syncProbeValue = syncProbeValue
        self.syncProbeUpdatedAt = syncProbeUpdatedAt
        self.syncProbeUpdatedBy = syncProbeUpdatedBy
    }
}

@Model
final class ChecklistSection {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0
    var profile: VehicleProfile? = nil

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.section)
    var items: [ChecklistItem]?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistGroup.section)
    var groups: [ChecklistGroup]?

    init(id: UUID = UUID(), title: String, sortOrder: Int = 0, profile: VehicleProfile? = nil) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.profile = profile
    }
}

@Model
final class ChecklistGroup {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0

    var section: ChecklistSection?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.group)
    var items: [ChecklistItem]?

    init(id: UUID = UUID(), title: String, sortOrder: Int = 0, section: ChecklistSection? = nil) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.section = section
    }
}

@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var title: String = ""
    var isChecked: Bool = false
    var sortOrder: Int = 0

    var section: ChecklistSection?
    var group: ChecklistGroup?

    init(
        id: UUID = UUID(),
        title: String,
        isChecked: Bool = false,
        sortOrder: Int = 0,
        section: ChecklistSection? = nil,
        group: ChecklistGroup? = nil
    ) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
        self.sortOrder = sortOrder
        self.section = section
        self.group = group
    }
}

extension VehicleProfile {
    var tripsList: [Trip] { trips ?? [] }
    var checklistSectionsList: [ChecklistSection] { checklistSections ?? [] }
}

extension Trip {
    var loadedItemsList: [LoadedItem] { loadedItems ?? [] }
}

extension ChecklistSection {
    var groupsList: [ChecklistGroup] { groups ?? [] }
    var itemsList: [ChecklistItem] { items ?? [] }
}

extension ChecklistGroup {
    var itemsList: [ChecklistItem] { items ?? [] }
}
