//
//  File.swift
//  
//
//  Created by Staszkiewicz, Carl Philipp on 13.03.23.
//

import Foundation

public enum EdmParamDimensionEnum {
    case VOLUME // volume (liters)
    case TEMP // engine temperature (°C)
    case OAT // outside temperatures
    case FLOW // flow (gallons / h)
    case PRESS // pressure (inHg)
    case VOLT // voltage (volts)
    case FREQ // frequency (rpm)
}

public enum EdmParamUnitEnum : Encodable {
    case liters
    case gallons
    case lbs
    case kg
    case celsius
    case fahrenheit
    case lph
    case gph
    case lbsph
    case kgph
    case inhg
    case volt
    case rpm
    
    public var shortname : String {
        get {
            switch self {
            case .liters:
                return "ltr"
            case .gallons:
                return "G"
            case .lbs:
                return "LBS"
            case .kg:
                return "KG"
            case .celsius:
                return "°C"
            case .fahrenheit:
                return "°F"
            case .lph:
                return " lph"
            case .gph:
                return " gph"
            case .lbsph:
                return " lbs/h"
            case .kgph:
                return " kg/h"
            case .inhg:
                return "\"Hg"
            case .volt:
                return " V"
            case .rpm:
                return " rpm"
            }
        }
    }
    
    public var name: String {
        get { return String(describing: self) }
    }
    
    public var scale : Int {
        get {
            switch self {
            case .gallons, .gph, .volt, .inhg:
                return 10
            default:
                return 1
            }
        }
    }
    
    public var dimension : EdmParamDimensionEnum {
        get {
            switch self {
            case .gallons, .liters,.kg, .lbs:
                return .VOLUME
            case .volt:
                return .VOLT
            case .inhg:
                return .PRESS
            case .gph, .lph, .kgph, .lbsph:
                return .FLOW
            case .rpm:
                return .FREQ
            case .fahrenheit, .celsius:
                return .TEMP
            }
        }
    }
}

public struct EdmUnits : Encodable {
    public var volume_unit : EdmParamUnitEnum = .liters
    public var temp_unit : EdmParamUnitEnum = .fahrenheit
    public var flow_unit : EdmParamUnitEnum = .lph
    public var press_unit : EdmParamUnitEnum = .inhg
    public var volt_unit : EdmParamUnitEnum = .volt
    public var freq_unit : EdmParamUnitEnum = .rpm
    public var oat_unit : EdmParamUnitEnum = .celsius
    public init () {
        volume_unit = .liters
        temp_unit = .fahrenheit
        oat_unit = .celsius
        flow_unit = .lph
        press_unit = .inhg
        volt_unit = .volt
        freq_unit = .rpm
    }
    
    public func stringValue() -> String {
        var str = "Units: "
        
        str.append(volume_unit.name + ", ")
        str.append(temp_unit.name + ", ")
        str.append(oat_unit.name + ", ")
        str.append(flow_unit.name + ", ")
        str.append(press_unit.name + ", ")
        str.append(volt_unit.name + ", ")
        str.append(freq_unit.name)
        return str
    }
}

public enum EdmFlightPeakValue : CaseIterable {
    case CHT
    case EGT
    case FF
    case CLD
    case DIFF
    case OILLOW
    case OILHI
    case BATLOW
    case BATHI
    case RPM
    case MAP
    case IAT
    case OATHI
    case OATLO
    
    public var name: String {
        get { return String(describing: self) }
    }
    
    public var longname : String {
        get {
            switch self {
            case .CHT:
                return "max CHT"
            case .EGT:
                return "max EGT"
            case .FF:
                return "max FF"
            case .CLD:
                return "max cooling"
            case .DIFF:
                return "max DIF"
            case .OILLOW:
                return "min OIL"
            case .OILHI:
                return "max OIL"
            case .BATLOW:
                return "min BAT"
            case .BATHI:
                return "max BAT"
            case .RPM:
                return "max RPM"
            case .MAP:
                return "max MAP"
            case .IAT:
                return "max IAT"
            case .OATLO:
                return "min OAT"
            case .OATHI:
                return "max OAT"
            }
        }
    }

    public var aboveOrBelow : String {
        get {
            switch self {
            case .OILLOW, .BATLOW, .CLD:
                return "below"
            default:
                return "above"
            }
        }
    }
        
    public var feature : EdmFeatures {
        get {
            switch self {
            case .CHT:
                return .c[0] // cylinders always present
            case .EGT:
                return .e[0] // EGT always present
            case .FF:
                return .ff
            case .CLD:
                return .cld
            case .DIFF:
                return .e[0] // if EGT is present, DIFF is present
            case .OILLOW:
                return .oil
            case .OILHI:
                return .oil
            case .BATLOW:
                return .battery
            case .BATHI:
                return .battery
            case .RPM:
                return .rpm
            case .MAP:
                return .map
            case .IAT:
                return .iat
            case .OATLO:
                return .oat
            case .OATHI:
                return .oat
            }
        }
    }
    
    public var dimension : EdmParamDimensionEnum {
        get {
            switch self {
            case .CHT, .EGT, .CLD, .DIFF, .OILLOW, .OILHI, .OATLO, .OATHI, .IAT:
                return .TEMP
            case .FF:
                return .FLOW
            case .BATLOW, .BATHI:
                return .VOLT
            case .MAP:
                return .PRESS
            case .RPM:
                return .FREQ
            }
        }
    }
    
    public func unit(for flight: EdmFileHeader) -> EdmParamUnitEnum {
        switch self.dimension {
        case .TEMP:
            return flight.units.temp_unit
        case .OAT:
            return flight.units.oat_unit
        case .FREQ:
            return flight.units.freq_unit
        case .FLOW:
            return flight.units.flow_unit
        case .PRESS:
            return flight.units.press_unit
        case .VOLT:
            return flight.units.volt_unit
        case .VOLUME:
            return flight.units.volume_unit
        }
    }
    
    public func getThresholdFor(header: EdmFlightHeader) -> Int? {
        switch self {
        case .CHT:
            return header.alarmLimits.cht
        case .CLD:
            return header.alarmLimits.cld
        case .DIFF:
            return header.alarmLimits.diff
        case .OILLOW:
            return header.alarmLimits.oilLow
        case .OILHI:
            return header.alarmLimits.oilHi
        case .BATLOW:
            return header.alarmLimits.voltsLow
        case .BATHI:
            return header.alarmLimits.voltsHi
        default:
                return nil
        }
    }
    
    public  func getPeak(for edmFlightData : EdmFlightData) -> (() -> (Int, Int))? {
        switch self {
        case .CHT:
            return edmFlightData.getMaxCht
        case .EGT:
            return edmFlightData.getMaxEgt
        case .OILHI:
            return edmFlightData.getMaxOil
        case .DIFF:
            return edmFlightData.getMaxDiff
        case .CLD:
            return edmFlightData.getMaxCld
        case .MAP:
            return edmFlightData.getMaxMap
        case .FF:
            return edmFlightData.getMaxFF
        case .OATHI:
            return edmFlightData.getMaxOat
        case .OATLO:
            return edmFlightData.getMinOat
        case .RPM:
            return edmFlightData.getMaxRpm
        default:
            return nil
        }
    }
    
    public func getWarnIntervalls(for edmFlightData : EdmFlightData) -> (() -> [(Int, Int, Int)]?) {
        switch self {
        case .CHT:
            return edmFlightData.getChtWarnIntervals
        case .EGT:
            return edmFlightData.getChtWarnIntervals
        case .OILLOW:
            return edmFlightData.getOilLowIntervals
        case .OILHI:
            return edmFlightData.getOilHighIntervals
        case .DIFF:
            return edmFlightData.getDiffWarnIntervals
        case .CLD:
            return edmFlightData.getColdWarnIntervals
        default:
            return edmFlightData.getColdWarnIntervals
        }
    }
}


public struct EdmAlarmLimits : Encodable {
    public var voltsHi     : Int = 0
    public var voltsLow    : Int = 0
    public var diff        : Int = 0
    public var cht         : Int = 0
    public var cld         : Int = 0
    public var tit         : Int = 0
    public var oilHi       : Int = 0
    public var oilLow      : Int = 0
    
    init (_ values: [String] = []){
        if values.count != 8 {
            voltsHi = 0
            voltsLow = 0
            diff = 0
            cht  = 0
            cld = 0
            tit = 0
            oilHi = 0
            oilLow = 0
        } else {
            voltsHi = Int(values[0]) ?? 0
            voltsLow = Int(values[1]) ?? 0
            diff = Int(values[2]) ?? 0
            cht  = Int(values[3]) ?? 0
            cld = Int(values[4]) ?? 0
            tit = Int(values[5]) ?? 0
            oilHi = Int(values[6]) ?? 0
            oilLow = Int(values[7]) ?? 0
        }
    }
    
    enum CodingKeys : String, CodingKey {
        case voltsHi = "Volts High"
        case voltsLow = "Volts Low"
        case diff = "Diff"
        case cht = "Cylinder Head Temperature"
        case cld = "Cooling Rate"
        case tit = "Turbine Inlet Temperature"
        case oilHi = "Oil High"
        case oilLow = "Oil Low"
    }

    public func toJsonString() -> String {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
            
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        encoder.dateEncodingStrategy = .formatted(formatter)
        encoder.outputFormatting = .prettyPrinted

        //todo
        let data = try! encoder.encode(self)
        let s = String(data: data, encoding: .utf8) ?? " --invalid record-- "
        return s + "\n"
    }

    public func stringValue() -> String  {
        var str = ""
        let vHi : Double = Double(voltsHi / 10)
        let vLo : Double = Double(voltsLow / 10)
        str.append("Alarm Thresholds: ")
        str.append("Volts Hi: " + String(vHi))
        str.append(", Volts Low: " + String(vLo))
        str.append(", Diff: " + String(diff))
        str.append(", CHT: " + String(cht))
        str.append(", CLD: " + String(cld))
        str.append(", TIT: " + String(tit))
        str.append(", Oil High: " + String(oilHi))
        str.append(", Oil Low: " + String(oilLow))

        str.append("\n")
        
        return str
    }
}

public enum FuelFlowLimits : Int {
    case idle
    case cruise
    case climb

    public func stringValue() -> String {
        switch self {
            case .idle:
                return "Idle/Taxi/Descend"
            case .cruise:
                return "Cruise"
            case .climb:
                return "Climb"
        }
    }
    
}

public struct FFLimits {
    var idleval : Int
    var cruiseval : Int
    var climbval : Int
    
    public var idle : Int {
        get {
            return idleval
        }
    }
    
    public var cruise : Int {
        get {
            return cruiseval
        }
    }
    
    public var climb : Int {
        get {
            return climbval
        }
    }
    
    public func stringValue() -> String {
        return "Idle: \(self.idle), cruise: \(self.cruise), climb: \(self.climb)"
    }
    
    public init (for fuelFlowUnit : FuelFlowUnit){
        let gplfactor : Double = FuelFlowUnit.gpl * Double(fuelFlowUnit.factor)
        switch fuelFlowUnit {
        case .GPH:
            idleval = Int(29 * gplfactor)
            cruiseval = Int(47 * gplfactor)
            climbval = Int(120 * gplfactor)
        default:
            idleval = 35
            cruiseval = 65
            climbval = 120
        }
        trc(level: .all, string: "FuelFlowLimits(\(fuelFlowUnit.name)) = " + self.stringValue())
    }
    
    
}
public enum FuelFlowUnit : Encodable {
    case GPH // Gallon per hour
    case KPH // Kilogram per hour
    case LPH // Liter per hour
    case PPH // Pound per hour

    public var factor : Int {
        get { switch self {
                    case .GPH: return 10
                    default: return 1
                }
        }
    }
    public static let gpl = 0.264172
    public static let lpg = 3.78541
    
    public var name: String {
        get { return String(describing: self) }
    }
    
    public var volumename : String {
        get {
            switch self {
                case .GPH: return "Gallons"
                case .LPH:  return "Liters"
                case .KPH: return "Kilogram"
                case .PPH: return "Pounds"
            }
        }
    }

}

public struct EdmFuelFlow : Encodable {
    var fuelFlow        : FuelFlowUnit = .LPH
    var ftank1 : Int , ftank2 : Int
    var k1, k2          : Int

    var ff_limits : FFLimits
    
    public func getUnit() -> FuelFlowUnit {
        return fuelFlow
    }
    
    init (_ values: [String] = []){
        fuelFlow = .LPH
        ftank1 = 0; ftank2 = 0; k1 = 0; k2 = 0
        if values.count == 5 {
            ftank1 = Int(values[1]) ?? 0
            ftank2 = Int(values[2]) ?? 0
            k1 = Int(values[3]) ?? 0
            k2 = Int(values[4]) ?? 0
            
            let v = Int(values[0]) ?? 0
            switch v {
            case 0:
                fuelFlow = .GPH
            case 1:
                fuelFlow = .PPH
            case 2:
                fuelFlow = .LPH
            case 3:
                fuelFlow = .KPH
            default:
                break
            }
        }
        ff_limits = FFLimits(for: fuelFlow)
    }
    
    enum CodingKeys : String, CodingKey {
        case fuelFlow = "Fuel Flow Unit"
        case ftank1 =  "Fuel Capacity Main Tanks"
        case ftank2 = "Fuel Capacity Tips"
    }
    
    public func toJsonString() -> String {
            let encoder = JSONEncoder()
            let formatter = DateFormatter()
            
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            encoder.dateEncodingStrategy = .formatted(formatter)
            encoder.outputFormatting = .prettyPrinted

            //todo
            let data = try! encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? " --invalid record-- "
    }
    
    public func stringValue() -> String {
        var str = ""
        str.append("Fuel Flow Units: " + fuelFlow.name)
        str.append(", capacity1: " + String(ftank1))
        str.append(", capacity2: " + String(ftank2))
        str.append(", k1: " + String(k1) + ", k2: " + String(k2))
        str.append("\n")
        
        return str
    }
}

// -m-d fpai r2to eeee eeee eccc cccc cc-b
public struct EdmFeatures : OptionSet, Encodable {
    public let rawValue: UInt32
    
    public static let battery = EdmFeatures(rawValue: (1<<0))
    public static let oil = EdmFeatures(rawValue: (1<<20))
    public static let tit = EdmFeatures(rawValue: (1<<21))
    public static let tit2 = EdmFeatures(rawValue: (1<<22))
    public static let carb = EdmFeatures(rawValue: (1<<23))
    public static let iat = EdmFeatures(rawValue: (1<<24))
    public static let oat = EdmFeatures(rawValue: (1<<25))
    public static let rpm = EdmFeatures(rawValue: (1<<26))
    public static let ff = EdmFeatures(rawValue: (1<<27))
    public static let cld = EdmFeatures(rawValue: (1<<28))
    public static let map = EdmFeatures(rawValue: (1<<30))

    public static let c = [
        EdmFeatures(rawValue: (1<<2)),
        EdmFeatures(rawValue: (1<<3)),
        EdmFeatures(rawValue: (1<<4)),
        EdmFeatures(rawValue: (1<<5)),
        EdmFeatures(rawValue: (1<<6)),
        EdmFeatures(rawValue: (1<<7)),
        EdmFeatures(rawValue: (1<<8)),
        EdmFeatures(rawValue: (1<<9)),
        EdmFeatures(rawValue: (1<<10)),
    ]
    
    public static let e = [
        EdmFeatures(rawValue: (1<<11)),
        EdmFeatures(rawValue: (1<<12)),
        EdmFeatures(rawValue: (1<<13)),
        EdmFeatures(rawValue: (1<<14)),
        EdmFeatures(rawValue: (1<<15)),
        EdmFeatures(rawValue: (1<<16)),
        EdmFeatures(rawValue: (1<<17)),
        EdmFeatures(rawValue: (1<<18)),
        EdmFeatures(rawValue: (1<<19)),
    ]
    
    public init(rawValue: UInt32) {
            self.rawValue = rawValue
    }
    
    init (high: UInt16,low: UInt16){
        self.rawValue = (UInt32(high)<<16) + UInt32(low)
    }
    
    public func numCylinders() -> Int {
        var count = 0
        
        for i in EdmFeatures.c {
            if self.contains(i) {
                count += 1
            }
        }

        return count
    }
    
    public func stringValue () -> String {
        var str = ""
        str.append("Sensors: ")
        str.append(String(numCylinders()) + " cylinders")
        if self.contains(.battery){
            str.append(", battery")
        }
        if self.contains(.oil) {
            str.append(", oil")
        }
        if self.contains(.tit) {
            str.append(", tit")
        }
        if self.contains(.tit2) {
            str.append(", tit2")
        }
        if self.contains(.carb) {
            str.append(", carb")
        }
        if self.contains(.iat) {
            str.append(", iat")
        }
        if self.contains(.oat) {
            str.append(", oat")
        }
        if self.contains(.rpm) {
            str.append(", rpm")
        }
        if self.contains(.ff) {
            str.append(", fuelflow")
        }
        if self.contains(.cld) {
            str.append(", cld")
        }
        if self.contains(.map) {
            str.append(", map")
        }

        if self.contains(.cld){
            str.append(" [temperature unit is \(EdmTemperatureUnit.fahrenheit.getString())]")
        } else {
            str.append(" [temperature unit is \(EdmTemperatureUnit.celsius.getString())]")
        }
        
        str.append("\n")
        
        return str
    }
}

public enum EdmTemperatureUnit {
    case fahrenheit
    case celsius
    
    public func getString() -> String {
        switch self {
        case .fahrenheit:
                return "°F"
        case .celsius:
            return "°C"
        }
    }
}

public struct EdmConfig : Encodable {
    public var modelNumber : Int = 0
    var flagsLow : UInt16 = 0, flagsHi : UInt16 = 0
    var unknown : Int = 0
    public var version : Int = 0
    public var features =  EdmFeatures(rawValue: 0)
    public var betaNumber : Int? = nil
    public var buildNumber : Int? = nil

    public var temperatureUnit : EdmTemperatureUnit {
        get {
            return features.contains(.cld) == true ? .fahrenheit : .celsius
        }
    }
    
    init (_ values: [String] = []) {
        var c = values.count
        if c < 5  {
            if c > 0 {
                trc(level: .error, string: "EdmConfig(): too few fields in config header (\(c))")
            }
            return
        }
        
        modelNumber = Int(values[0]) ?? -1
        flagsLow = UInt16(values[1]) ?? 0
        flagsHi = UInt16(values[2]) ?? 0
        unknown = Int(values[3]) ?? -1
        if c > 6 {
            betaNumber = Int(values[c-1]); c -= 1
            buildNumber = Int(values[c-1]);c -= 1
        }
        
        version = Int(values[c-1]) ?? -1
        features = EdmFeatures(high: flagsHi, low: flagsLow)
        
        let oatstr = String(unknown, radix: 16)
        trc(level: .info, string: "EdmConfig(): model=\(modelNumber), version=\(version), build=\(String(describing: buildNumber)), beta=\(String(describing: betaNumber)), features: \(features.stringValue()), OAT-units=\(oatstr) (count=\(values.count))")
    }
    
    public func numOfEngines () -> Int {
        if modelNumber == 760 {
            return 2
        }
        return 1
    }
    
    func hasRPM () -> Bool {
        return false
    }
    
    public func stringValue () -> String {
        var str = ""
        str.append("Model: EDM" + String(modelNumber))
        str.append(", SW-Version: " + String(version) + "\n")
        
        return str
    }
}

