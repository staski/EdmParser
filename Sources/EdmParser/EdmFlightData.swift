//
//  EdmFlightData.swift
//  EdmTools
//
//  Created by Staszkiewicz, Carl Philipp on 17.01.22.
//

import Foundation

struct BitArray48: OptionSet, Codable {
    var rawValue: Int64
    let numberOfBits = 48
    var numberOfBytes : Int {
        return numberOfBits / 8
    }
    
    init(rawValue: Int64) {
            self.rawValue = rawValue
    }

    func hasBit(i : Int) -> Bool {
        if i < 0 || i > 47 {
            return false
        }
        if self.contains(BitArray48(rawValue: 1 << i)) {
            return true
        } else {
            return false
        }
    }
    
    mutating func setBit(i : Int) {
        if i < 0 || i > 47 {
            return
        }
        self.rawValue |= Int64(1 << i)
    }

    mutating func clearBit(i : Int) {
        if i < 0 || i > 47 {
            return
        }
        self.rawValue &= ~Int64(1 << i)
    }

}

struct BitArray64 : OptionSet {
    var rawValue: UInt64
}

struct BitArray {
    var rawValueLow : BitArray64
    var rawValueHi : BitArray64
    var numberOfBits : Int
    var numberOfBytes : Int{
        return numberOfBits / 8
    }
    
    init (size: Int) {
        rawValueHi = BitArray64()
        rawValueLow = BitArray64()
        numberOfBits = size
    }
    
    init(low: UInt64, high: UInt64, size: Int) {
        self.rawValueLow = BitArray64(rawValue: low)
        self.rawValueHi = BitArray64(rawValue: high)
        self.numberOfBits = size
    }

    func hasBit(i : Int) -> Bool {
        if i < 0 || i >= numberOfBits {
            return false
        }
        
        //trc(level: .info, string: String(rawValueLow.rawValue, radix: 2) + ".hasBit(\(i))")
        if i < 64 && rawValueLow.contains(BitArray64(rawValue: 1 << i)) {
            return true
        } else if i >= 64 && rawValueHi.contains(BitArray64(rawValue: 1 << (i-64))){
            return true
        }
        //trc(level: .info, string: "----NO-----")
        return false
    }
    
    mutating func setBit(i : Int) {
        if i < 0 || i >= numberOfBits {
            return
        }
        
        trc(level: .info, string: String(rawValueLow.rawValue, radix: 2) + ".setBit(\(i))")
        if i < 64 {
            rawValueLow.rawValue |= UInt64(1<<i)
        } else {
            rawValueHi.rawValue |= UInt64(1<<(i-64))
        }
        trc(level: .info, string: "result is" + String(rawValueLow.rawValue, radix: 2))

    }

    mutating func clearBit(i : Int) {
        if i < 0 || i >= numberOfBits {
            return
        }

        trc(level: .info, string: String(rawValueLow.rawValue, radix: 2) + ".clearBit(\(i))")
        if i < 64 {
            rawValueLow.rawValue &= ~UInt64(1<<i)
        } else {
            rawValueHi.rawValue &= ~UInt64(1<<(i-64))
        }
        trc(level: .info, string: "result is " + String(rawValueLow.rawValue, radix: 2))

    }

    mutating func setByte(_ i: Int, value: UInt8) {
        if i < 0 || i >= numberOfBytes {
            return
        }
        let m = UInt64(0xff)
        let v = UInt64(value)
        let idx = i < 8 ? i : i - 8
        if i < 8 {
            rawValueLow.rawValue &= ~(m<<(idx*8))
            rawValueLow.rawValue |= v<<(idx*8)
        } else {
            rawValueHi.rawValue &= ~(m << (idx*8))
            rawValueHi.rawValue |= v << (idx*8)
        }
    }
}

typealias EdmNAFlags = BitArray48

public enum EdmSensorBits : Int, CaseIterable {
    case egt0 = 0,
    egt1,
    egt2,
    egt3,
    egt4,
    egt5,
    t1,
    t2,
    cht0,
    cht1,
    cht2,
    cht3,
    cht4,
    cht5,
    cld,
    oil,
    mark,
    unk_3_1,
    cdt,
    iat,
    bat,
    oat,
    usd,
    ff,
    regt0,
    regt1,
    regt2,
    regt3,
    regt4,
    regt5,
    hprt1,
    rt2,
    rcht0,
    rcht1,
    rcht2,
    rcht3,
    rcht4,
    rcht5,
    rcld,
    roil,
    map,
    rpm,
    rpmhircdt,
    riat,
    unk_6_4,
    unk_6_5,
    rusd,
    rff
    
    func stringValue () -> String { return String(describing: self) }
}

extension EdmNAFlags {
    var arrayValue : [String] {
        var ret : [String] = []
        for bit in EdmSensorBits.allCases {
            if self.hasBit(i: bit.rawValue) {
                ret.append(bit.stringValue())
            }
        }
        return ret
    }
    enum CodingKeys : CodingKey {
        case arrayValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(arrayValue, forKey: .arrayValue)
    }
}

typealias EdmDecodeFlags = BitArray
typealias EdmValueFlags = BitArray
typealias EdmSignFlags = BitArray

typealias EdmScaleFlags = BitArray

struct EdmRawDataRecord {
    var decodeFlags : EdmDecodeFlags?
    var repeatCount : Int8 = 0
    var valueFlags : EdmValueFlags
    var signFlags : EdmSignFlags
    
    var values : [Int16]
    var signValues : [Int]
    
    init (protocolVersion: EdmProtovolVersion) {
        switch protocolVersion {
        case .v1, .v2:
            valueFlags = EdmValueFlags(size: 64)
            signFlags = EdmSignFlags(size: 64)
            values = Array(repeating: 0, count: 64)
            signValues = Array(repeating: 1, count: 64)
        default:
            valueFlags = EdmValueFlags(size: 128)
            signFlags = EdmSignFlags(size: 128)
            values = Array(repeating: 0, count: 128)
            signValues = Array(repeating: 1, count: 128)
        }
    }
    
    var checksum : UInt8 = 0
}

enum hp_or_rt1 : Codable {
    case hp(Int16)
    case rt1(Int16)
}

enum rpmhi_or_rcdt : Codable {
    case rpmhi(Int16)
    case rcdt(Int16)
}


public struct EdmFlightDataRecord : Codable {
    public var date : Date?
    var egt : [Int16]
    var numOfCyl : Int = 6
    var t1 : Int16 = 0x00f0
    var t2 : Int16 = 0x00f0
    
    var cht : [Int16] = Array(repeating: 0x00f0, count: 6)
    var cld : Int16 = 0x00f0
    var oil : Int16 = 0x00f0
    
    var mark : Int16 = 0x00f0
    var unk_3_1 : Int16 = 0x00f0
    var cdt : Int16 = 0x00f0
    var iat : Int16 = 0x00f0
    var bat : Int16 = 0x00f0
    var oat : Int16 = 0x00f0
    var usd : Int16 = 0x00f0
    var ff  : Int16 = 0x00f0
    
    var regt : [Int16] = Array(repeating: 0x00f0, count: 6)
    var hprtl : hp_or_rt1 = hp_or_rt1.hp(0x00f0)
    var rt2 : Int16 = 0x00f0
    
    var rcht : [Int16] = Array(repeating: 0x00f0, count: 6)
    var rcld : Int16 = 0x00f0
    var roil : Int16 = 0x00f0
    
    var map : Int16 = 0x00f0
    var rpm : Int16 = 0x00f0
    var rpmhircdt : rpmhi_or_rcdt = rpmhi_or_rcdt.rpmhi(0x0000)
    var riat : Int16 = 0x00f0
    var unk_6_4 : Int16 = 0x00f0
    var unk_6_5 : Int16 = 0x00f0
    var rusd : Int16 = 0x00f0
    var rff : Int16 = 0x00f0
    
    var diff : [Int] = [0,0]
    var naflags : EdmNAFlags = EdmNAFlags(rawValue: 0)
    
    var repeatCount : Int = 0
    var hasmap = false
    var hasoat = false
    var hasiat = false
    var hasrpm = false
    var hasff = false
    var hascld = false
    var hasoil = false
    
    public init(numofCyl n: Int) {
        numOfCyl = n
        egt =  Array(repeating: 0x00f0, count: numOfCyl) //[0x00f0, 0x00f0]
        cht =  Array(repeating: 0x00f0, count: numOfCyl) //[0x00f0, 0x00f0]
        regt =  Array(repeating: 0x00f0, count: numOfCyl) //[0x00f0, 0x00f0]
        rcht =  Array(repeating: 0x00f0, count: numOfCyl) //[0x00f0, 0x00f0]
    }
    
    func info () -> String {
        return "Edm Flight-Data Body"
    }
    
    // works also for na values of egt because they are adjusted to 0 value
    public func maxEgt () -> Int {
        return egt.reduce(0, { (res, e) in
            Int(e) > res ? Int(e) : res
        })
    }
    
    // works also for na values of cht because they are adjusted to 0 value
    public func maxCht () -> Int {
        return cht.reduce(0, { (res, e) in
            Int(e) > res ? Int(e) : res
        })
    }
    
    public func egtWarnCount (a: Int) -> Int {
        return egt.filter({ Int($0) > a}).reduce(0, { (res, elem) in
            return res+1
        })
    }

    public func chtWarnCount (a: Int) -> Int {
        return cht.filter({ Int($0) > a}).reduce(0, { (res, elem) in
            return res+1
        })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(mark, forKey: .mark)
        try container.encode(egt, forKey: .egt)
        try container.encode(cht, forKey: .cht)
        try container.encode(bat, forKey: .bat)
        try container.encode(diff[0], forKey: .diff)
           
        if hasoil == true {
            try container.encode(oil, forKey: .oil)
        }
        if hascld == true {
            try container.encode(cld, forKey: .cld)
        }
        if hasff == true {
            try container.encode(ff, forKey: .ff)
            try container.encode(usd, forKey: .usd)
        }
        if naflags.rawValue != 0 {
            try container.encode(naflags.arrayValue, forKey: .naflags)
        }
        if hasrpm == true {
            try container.encode(rpm, forKey: .rpm)
        }
        if hasoat == true {
            try container.encode(oat, forKey: .oat)
        }
        if hasiat == true {
            try container.encode(iat, forKey: .iat)
        }
        if hasmap == true {
            try container.encode(map, forKey: .map)
        }
    }
    
    public func minEncode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(ff, forKey: .ff)
        try container.encode(usd, forKey: .usd)
        try container.encode(mark, forKey: .mark)

    }
    
    enum CodingKeys : String, CodingKey {
        case date = "Date"
        case ff = "Fuel Flow"
        case usd = "Fuel Used"
        case mark = "Mark"
        case bat = "Battery Voltage"
        case egt = "EGT"
        case cld = "Cooling Rate"
        case cht = "CHT"
        case diff = "Maximum EGT difference"
        case iat = "Induction Air Temparature"
        case oat = "Outside Air Temperature"
        case map = "Manifold Pressure"
        case rpm = "RPM"
        case oil = "Oil Temperature"
        case naflags = "Failed Sensors"
    }
    
    public func stringValue() -> String {
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
    
    mutating func add (rawValue : EdmRawDataRecord) {
        for i in (0...numOfCyl - 1) {
            egt[i] += Int16(rawValue.values[i])
        }
        t1 += Int16(rawValue.values[6])
        t2 += Int16(rawValue.values[7])
        
        for i in (0...numOfCyl - 1) {
            cht[i] += Int16(rawValue.values[8+i])
        }
        
        cld += Int16(rawValue.values[14])
        oil += Int16(rawValue.values[15])
        
        mark += Int16(rawValue.values[16])
        unk_3_1 += Int16(rawValue.values[17])
        cdt += Int16(rawValue.values[18])
        iat += Int16(rawValue.values[19])
        bat += Int16(rawValue.values[20])
        oat += Int16(rawValue.values[21])
        usd += Int16(rawValue.values[22])
        ff  += Int16(rawValue.values[23])
        

        for i in (0...numOfCyl - 1) {
            regt[i] += Int16(rawValue.values[24+i])
        }
        
        switch hprtl.self {
            case .hp(var hpval) : hpval += Int16(rawValue.values[30])
            case .rt1(var rt1val) : rt1val += Int16(rawValue.values[30])
        }
                              
        rt2 += Int16(rawValue.values[31])

        for i in (0...numOfCyl - 1) {
            rcht[i] += Int16(rawValue.values[32+i])
        }

        rcld  += Int16(rawValue.values[38])
        roil  += Int16(rawValue.values[39])
        map  += Int16(rawValue.values[40])
        rpm  += rawValue.values[41]

        switch rpmhircdt.self {
            case .rpmhi(var rpmhival) :
                rpmhival = Int16(rawValue.values[42])
                rpm += (rpmhival&0xff)<<8
                rpmhival=0
            case .rcdt(var rcdtval) : rcdtval += (rawValue.signFlags.hasBit(i: 42) ? -1 : 1) * Int16(rawValue.values[42])
        }
        
        riat  += Int16(rawValue.values[43])
        unk_6_4  += Int16(rawValue.values[44])
        unk_6_5  += Int16(rawValue.values[45])
        rusd  += Int16(rawValue.values[46])
        rff  += Int16(rawValue.values[47])

        repeatCount += Int(rawValue.repeatCount)
        return
    }
}

public struct EdmFlightData : Encodable {
    public var flightHeader : EdmFlightHeader?
    public var flightDataBody : [EdmFlightDataRecord] = []
    public var hasnaflag = false
    
    public func valid () -> Bool {
        if flightHeader == nil || flightDataBody.count < 1 {
            return false
        }
        
        return true
    }
    
    public func hasfeature(_ feature : EdmFeatures) -> Bool {
        if valid() == false {
            return false
        }
        return flightHeader?.hasfeature(feature) ?? false
    }
    
    public var duration : TimeInterval {
    
        if self.valid() == false {
            return TimeInterval()
        }
        
        guard let d1 = flightDataBody.first!.date else {
            return TimeInterval()
        }
        guard let d2 = flightDataBody.last!.date else {
            return TimeInterval()
        }
        
        return DateInterval(start: d1, end: d2).duration
    }
    
    // fuel used as difference between fuel used data points at start and end of flight
    public var fuelUsed : Int {
        if hasfeature(.ff) == false {
            return 0
        }
        return Int(flightDataBody.last!.usd) - Int(flightDataBody.first!.usd)
    }
    
    // fuel used as a sum of "integrated" fuel flow values at each data point
    public func getFuelUsed(outFuelUnit : FuelFlowUnit?) -> Double {
        if hasfeature(.ff) == false {
            return 0
        }

        var interval_secs = flightHeader!.interval_secs

        let usd = flightDataBody.reduce(0.0) { (res, el) in
          
            if el.mark == 2 {
                interval_secs = 1
            } else if el.mark == 3 {
                interval_secs = flightHeader!.interval_secs
            }
            return res + Double(el.ff)*Double(interval_secs) / 3600.0
        }
        
        let ff_unit = flightHeader!.ff.getUnit()
        let ff_ounit = outFuelUnit ?? ff_unit

        let factor = Double(ff_unit.factor)
        var fuelused = Double(usd)/factor
        
        switch ff_ounit {
        case .LPH:
            if ff_unit == .GPH {
                fuelused *= FuelFlowUnit.lpg
            }
        case .GPH:
            if ff_unit == .LPH {
                fuelused *= FuelFlowUnit.gpl
            }
        case .KPH:
            break
        case .PPH:
            break
        }
        
        return fuelused
    }


    public func getMaxEgt () -> (Int,Int) {
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = elem.1.maxEgt()
            trc(level: .info, string: "getMaxEgt(\(res) \(m)")
            return m > res.1 ? (elem.0,m) : res
        })
    }

    public func getMaxCht () -> (Int,Int) {
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = elem.1.maxCht()
            return m > res.1 ? (elem.0,m) : res
        })
    }

    public func getMaxDiff () -> (Int,Int) {
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = elem.1.diff[0] > elem.1.diff[1] ? elem.1.diff[0] : elem.1.diff[1]
            return m > res.1 ? (elem.0,m) : res
        })
    }
    
    public func getMaxOil () -> (Int,Int) {
        if hasfeature(.oil) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = Int(elem.1.oil)
            return m > res.1 ? (elem.0,m) : res
        })
    }
    
    public func getMaxOat () -> (Int,Int) {
        if hasfeature(.oat) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,-100), { (res, elem ) in
            let m = Int(elem.1.oat)
            return m > res.1 ? (elem.0,m) : res
        })
    }
    
    public func getMinOat () -> (Int,Int) {
        if hasfeature(.oat) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,100), { (res, elem ) in
            let m = Int(elem.1.oat)
            return m < res.1 ? (elem.0,m) : res
        })
    }

    public func getMaxCld () -> (Int,Int) {
        if hasfeature(.cld) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = Int(elem.1.cld)
            return m < res.1 ? (elem.0,m) : res //cooling rate records negative values only (?)
        })
    }

    public func getMaxFF () -> (Int,Int) {
        if hasfeature(.ff) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = Int(elem.1.ff)
            return m > res.1 ? (elem.0,m) : res //cooling rate records negative values only (?)
        })
    }

    public func getMaxMap () -> (Int,Int) {
        if hasfeature(.map) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = Int(elem.1.map)
            return m > res.1 ? (elem.0,m) : res
        })
    }

    public func getMaxRpm () -> (Int,Int) {
        if hasfeature(.rpm) == false {
            return (0,0)
        }
        
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = Int(elem.1.rpm)
            return m > res.1 ? (elem.0,m) : res
        })
    }

    enum CodingKeys : CodingKey {
        case flightHeader
        case flightDataBody
    }
}

public typealias EdmNAIntervals = [String: [Int]]

// getNAIntervals returns for each non available sensor values a list of intervals of non availability
// the interval is encoded as an array of (start, stop)-indices
extension EdmFlightData {
    public func getNAIntervals() -> EdmNAIntervals {
        var dict : EdmNAIntervals = [:]
        if hasnaflag == false {
            return dict
        }
        for i in 0..<flightDataBody.count {
            if flightDataBody[i].naflags.rawValue == 0 { continue }
            let naflagarray = flightDataBody[i].naflags.arrayValue
            for v in naflagarray {
                if dict[v] == nil {
                    dict[v] = [i,i]
                } else if dict[v]!.last! + 1 == i {
                    dict[v]!.removeLast()
                    dict[v]!.append(i)
                } else {
                    dict[v]!.append(contentsOf: [i,i])
                }
            }
        }
        return dict
    }
}
// calculate number of warnings and warning durations
extension EdmFlightData {
    
    // fuel flow
    public func getFuelFlowIntervals () -> [(Int, Int, FuelFlowLimits)]? {
        if hasfeature(.ff) == false {
            return nil
        }

        trc(level: .all, string: "getFuelFlowIntervals(): \(flightHeader!.ff.ff_limits.stringValue())")
        
        let mapped = flightDataBody.map({ $0.ff < flightHeader!.ff.ff_limits.idle ? FuelFlowLimits.idle : $0.ff < flightHeader!.ff.ff_limits.cruise ? FuelFlowLimits.cruise : FuelFlowLimits.climb })
        let fr = mapped.enumerated()

        //let filtered = fr.filter({ $0.1.diff[0] > h.alarmLimits.diff || $0.1.diff[1] > h.alarmLimits.diff })
        
        var values : [(Int, Int, FuelFlowLimits) ] = []
        var val : (Int, Int, FuelFlowLimits) = (0,0,FuelFlowLimits.idle)
        var lastVal : FuelFlowLimits? = nil
        
        values = fr.reduce(into: values) { res, elem in
            if lastVal != nil && elem.1 == lastVal {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(flightHeader!.interval_secs)
            } else {
                if lastVal != nil {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(flightHeader!.interval_secs)
                val.2 = elem.1
            }
            lastVal = elem.1
        }
        
        if lastVal != nil {
            values.append(val)
        }
        
        return values
    }
    
    // cht limit exceeded
    public func getChtWarnCount () -> [(Int,Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getChtWarnCount(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.maxCht() > h.alarmLimits.cht })
        return a.map({ elem in
            (elem.0, elem.1.chtWarnCount(a: h.alarmLimits.cht))
        })
    }
    
    public func getChtWarnIntervals () -> [(Int, Int, Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getChtWarnIntervals(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let filtered = fr.filter({ $0.1.maxCht() > h.alarmLimits.cht })
        
        var values : [(Int, Int, Int) ] = []
        var val : (Int, Int, Int) = (0,0,0)
        var lastIdx = -1
        
        values = filtered.reduce(into: values) { res, elem in
            if elem.0 == lastIdx + 1  && lastIdx != -1 {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(h.interval_secs)
            } else {
                if lastIdx != -1 {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(h.interval_secs)
                val.2 = Int(h.alarmLimits.cht)
            }
            lastIdx = elem.0
        }
        
        if lastIdx != -1 {
            values.append(val)
        }
        
        return values
    }
    
    public func getDiffWarnCount () -> [(Int,Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getDiffWarnCount(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()
        
        
        let a = fr.filter({ $0.1.diff[0] > h.alarmLimits.diff || $0.1.diff[1] > h.alarmLimits.diff })
        return a.map({ elem in
            (elem.0, elem.1.chtWarnCount(a: h.alarmLimits.diff))
        })
    }
    
    // egt spread
    public func getDiffWarnIntervals () -> [(Int, Int, Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getChtWarnIntervals(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let filtered = fr.filter({ $0.1.diff[0] > h.alarmLimits.diff || $0.1.diff[1] > h.alarmLimits.diff })
        
        var values : [(Int, Int, Int) ] = []
        var val : (Int, Int, Int) = (0,0,0)
        var lastIdx = -1
        
        values = filtered.reduce(into: values) { res, elem in
            if elem.0 == lastIdx + 1  && lastIdx != -1 {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(h.interval_secs)
            } else {
                if lastIdx != -1 {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(h.interval_secs)
                val.2 = Int(h.alarmLimits.diff)
            }
            lastIdx = elem.0
        }
        
        if lastIdx != -1 {
            values.append(val)
        }
        
        return values
    }

    // oil high exceeded
    public func getOilHighCount () -> [(Int,Int)]? {
        if hasfeature(.oil) == false {
            trc(level: .warn, string: "getOilHighCount: no oil sensors")
            return nil
        }
        let h = flightHeader!
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.oil > h.alarmLimits.oilHi })
        return a.map({ elem in
            (elem.0, Int(elem.1.oil))
        })
    }

    public func getOilHighIntervals () -> [(Int, Int, Int)]? {
        if hasfeature(.oil) == false {
            trc(level: .warn, string: "getOilHighIntervals: no oil sensors")
            return nil
        }
        let h = flightHeader!
        let fr = flightDataBody.enumerated()

        let filtered = fr.filter({ $0.1.oil > h.alarmLimits.oilHi })
        
        var values : [(Int, Int, Int) ] = []
        var val : (Int, Int, Int) = (0,0,0)
        var lastIdx = -1
        
        values = filtered.reduce(into: values) { res, elem in
            if elem.0 == lastIdx + 1  && lastIdx != -1 {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(h.interval_secs)
            } else {
                if lastIdx != -1 {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(h.interval_secs)
                val.2 = Int(h.alarmLimits.oilHi)
            }
            lastIdx = elem.0
        }

        if lastIdx != -1 {
            values.append(val)
        }

        return values
    }

    public func getOilLowCount () -> [(Int,Int)]? {
        if hasfeature(.oil) == false {
            trc(level: .warn, string: "getOilLowCount: no oil sensors")
            return nil
        }
        let h = flightHeader!
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.oil < h.alarmLimits.oilLow })
        return a.map({ elem in
            (elem.0, Int(elem.1.oil))
        })
    }
    
    // fall below oil low  threshold
    public func getOilLowIntervals () -> [(Int, Int, Int)]? {
        if hasfeature(.oil) == false {
            trc(level: .warn, string: "getOilLowIntervals: no oil sensors")
            return nil
        }
        let h = flightHeader!
        let fr = flightDataBody.enumerated()

        let filtered = fr.filter({ $0.1.oil < h.alarmLimits.oilLow })
        
        var values : [(Int, Int, Int) ] = []
        var val : (Int, Int, Int) = (0,0,0)
        var lastIdx = -1
        
        values = filtered.reduce(into: values) { res, elem in
            if elem.0 == lastIdx + 1  && lastIdx != -1 {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(h.interval_secs)
            } else {
                if lastIdx != -1 {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(h.interval_secs)
                val.2 = Int(h.alarmLimits.oilLow)
            }
            lastIdx = elem.0
        }

        if lastIdx != -1 {
            values.append(val)
        }
        return values
    }

    // cooling rate
    public func getColdWarnCount () -> [(Int,Int)]? {
        if hasfeature(.cld) == false {
            trc(level: .warn, string: "getColdWarnCount: no cld sensors")
            return nil
        }
        let h = flightHeader!
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.cld < -h.alarmLimits.cld })
        return a.map({ elem in
            (elem.0, Int(elem.1.cld))
        })
    }

    public func getColdWarnIntervals () -> [(Int, Int, Int)]? {
        if hasfeature(.cld) == false {
            trc(level: .warn, string: "getColdWarnIntervals: no cld sensors")
            return nil
        }
        let h = flightHeader!
        let fr = flightDataBody.enumerated()

        let filtered = fr.filter({ $0.1.cld < -h.alarmLimits.cld })
        
        var values : [(Int, Int, Int) ] = []
        var val : (Int, Int, Int) = (0,0,0)
        var lastIdx = -1
        
        values = filtered.reduce(into: values) { res, elem in
            if elem.0 == lastIdx + 1  && lastIdx != -1 {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(h.interval_secs)
            } else {
                if lastIdx != -1 {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(h.interval_secs)
                val.2 = Int(h.alarmLimits.cld)
            }
            lastIdx = elem.0
        }

        if lastIdx != -1 {
            values.append(val)
        }

        return values
    }

}

extension EdmFlightData {

    // one line summary of a flight, including duration, fuel used (if available)
    public func stringSummary(ff_out_unit : FuelFlowUnit?) -> String? {
        guard let fh = flightHeader else {
            return nil
        }

        var s = fh.stringValue()
        
        let durationstring = String("duration: " + duration.hms())
        let recordstring = String(format: "%3d records", flightDataBody.count)

        if hasfeature(.ff){
            let ff_ounit = ff_out_unit ?? fh.ff.getUnit()
            let f_unit_string = ff_ounit.volumename
        
            let fuelused : Double = Double(getFuelUsed(outFuelUnit: ff_out_unit))
            let usedstring = String(format: "fuel used: %6.1f %@", fuelused, f_unit_string)

            s.append(", " + durationstring + ", " + usedstring + ", " + recordstring)
        } else {
            s.append(", " + durationstring + ", " + recordstring)
        }
        
        return s
    }
    
    // flight information including max values and warnings
    public func stringValue(ff_out_unit : FuelFlowUnit?) -> String? {
        guard let fh = flightHeader else {
            return nil
        }
        var s = fh.stringValue()
        let u = fh.units

        if hasfeature(.ff){
            let ff_unit = fh.ff.getUnit()
            let ff_ounit = ff_out_unit ?? ff_unit
            let f_unit_string = ff_ounit.volumename
            let fuelused : Double = Double(getFuelUsed(outFuelUnit: ff_out_unit))
            let usedstring = String(format: "%2.2f", fuelused)

            s.append("\nduration: " + duration.hms() + ", fuel used: \(usedstring) \(f_unit_string)\n")
        } else {
            s.append("\nduration: " + duration.hms() + "\n")

        }
        var (idx, maxt) = self.getMaxEgt()
        var fr = flightDataBody[idx]
        guard let t = fr.date else {
            trc(level: .error, string: "FlightData.stringValue(): no date set")
            return nil
        }
        
        var d = t.timeIntervalSince(fh.date!)
        s.append("max EGT: \(maxt)°F after " + d.hms() + "\n")

        (idx, maxt) = self.getMaxCht()
        fr = flightDataBody[idx]
        guard let t = fr.date else {
            trc(level: .error, string: "FlightData.stringValue(): no date set")
            return nil
        }
        
        d = t.timeIntervalSince(fh.date!)
        s.append("max CHT: \(maxt.unitString(for: u.temp_unit)) after " + d.hms())
        
        (idx, maxt) = self.getMaxDiff()
        fr = flightDataBody[idx]
        guard let t = fr.date else {
            trc(level: .error, string: "FlightData.stringValue(): no date set")
            return nil
        }
        
        d = t.timeIntervalSince(fh.date!)
        s.append("\nmax DIFF: \(maxt.unitString(for: u.temp_unit)) after " + d.hms())
        
        if hasfeature(.oil){
            (idx, maxt) = self.getMaxOil()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmax Oil: \(maxt.unitString(for: u.temp_unit)) after " + d.hms())
        }

        if hasfeature(.ff){
            (idx, maxt) = self.getMaxFF()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmax FF: \(maxt.unitString(for: u.flow_unit)) after " + d.hms())
        }

        if hasfeature(.oat){
            (idx, maxt) = self.getMaxOat()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmax OAT: \(maxt.unitString(for: u.oat_unit)) after " + d.hms())
        }
        
        if hasfeature(.oat){
            (idx, maxt) = self.getMinOat()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmin OAT: \(maxt.unitString(for: u.oat_unit)) after " + d.hms())
        }

        if hasfeature(.cld){
            (idx, maxt) = self.getMaxCld()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmax CLD: \(maxt.unitString(for: u.temp_unit))/min after " + d.hms())
        }

        if hasfeature(.map){
            (idx, maxt) = self.getMaxMap()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            //maxt = maxt/10
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmax MAP: \(maxt.unitString(for: u.press_unit)) inches after " + d.hms())
        }

        if hasfeature(.rpm){
            (idx, maxt) = self.getMaxRpm()
            fr = flightDataBody[idx]
            guard let t = fr.date else {
                trc(level: .error, string: "FlightData.stringValue(): no date set")
                return nil
            }
            
            d = t.timeIntervalSince(fh.date!)
            s.append("\nmax RPM: \(maxt.unitString(for: u.freq_unit)) after " + d.hms())
        }

        return s
    }
}


extension Double {
    public func unitString(for unit: EdmParamUnitEnum) -> String {
        return String(self).appending(unit.shortname)
    }
}

extension Int {
    public func unitString(for unit: EdmParamUnitEnum) -> String {
        if unit.scale == 1 {
            return String(self).appending(unit.shortname)
        }
        return String(Double(self)/Double(unit.scale)).appending(unit.shortname)
    }
}


extension TimeInterval {
    public func hms () -> String {
        var m = Int(self / 60.0)
        let s = Int(self) - m * 60
        let h = Int(Double(m) / 60.0)
        m = m - h * 60
        
        return String(format: "%2.2d:%2.2d:%2.2d", h,m,s)
    }
}
