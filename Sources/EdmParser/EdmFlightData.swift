//
//  EdmFlightData.swift
//  EdmTools
//
//  Created by Staszkiewicz, Carl Philipp on 17.01.22.
//

import Foundation

struct BitArray16 : OptionSet {
    let rawValue: Int16
    let numberOfBits = 16
    var numberOfBytes : Int {
        return numberOfBits / 8
    }
    
    init(rawValue: Int16) {
            self.rawValue = rawValue
    }
    
    func hasBit(i : Int) -> Bool {
        if i < 0 || i > 15 {
            return false
        }
        if self.contains(BitArray16(rawValue: 1 << i)) {
            return true
        } else {
            return false
        }
    }
}

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

typealias EdmNAFlags = BitArray48
typealias EdmValueFlags = BitArray48
typealias EdmSignFlags = BitArray48

typealias EdmDecodeFlags = BitArray16
typealias EdmScaleFlags = BitArray16

struct EdmRawDataRecord {
    var decodeFlags : EdmDecodeFlags?
    var repeatCount : Int8 = 0
    var valueFlags = EdmValueFlags()
    var scaleFlags = EdmScaleFlags()
    var signFlags = EdmSignFlags()
    
    var values : [Int16] = Array(repeating: 0, count: 48)
    var signValues : [Int] = Array(repeating: 1, count: 48)
    var scaleValues : [Int16] = Array(repeating: 0, count: 16)
    
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
    var egt : [Int16] =  Array(repeating: 0x00f0, count: 6) //[0x00f0, 0x00f0]
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
    
    func info () -> String {
        return "Edm Flight-Data Body"
    }
    
    public func maxEgt () -> Int {
        return egt.reduce(0, { (res, e) in
            Int(e) > res ? Int(e) : res
        })
    }
    
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
            try container.encode(ff, forKey: .ff)
            try container.encode(usd, forKey: .usd)
            try container.encode(mark, forKey: .mark)
            try container.encode(egt, forKey: .egt)
            try container.encode(cht, forKey: .cht)
            try container.encode(cld, forKey: .cld)
            try container.encode(bat, forKey: .bat)
            try container.encode(diff[0], forKey: .diff)
            
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
        case diff = "Maximal EGT difference"
        case iat = "Induction Air Temparature"
        case oat = "Outside Air Temperature"
        case map = "Manifold Pressure"
        case rpm = "RPM"
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
        for i in (0...5) {
            egt[i] += Int16(rawValue.values[i])
        }
        t1 += Int16(rawValue.values[6])
        t2 += Int16(rawValue.values[7])
        
        for i in (0...5) {
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
        

        for i in (0...5) {
            regt[i] += Int16(rawValue.values[24+i])
        }
        
        switch hprtl.self {
            case .hp(var hpval) : hpval += Int16(rawValue.values[30])
            case .rt1(var rt1val) : rt1val += Int16(rawValue.values[30])
        }
                              
        rt2 += Int16(rawValue.values[31])

        for i in (0...5) {
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

        if oat != 0x00f0 {
            hasoat = true
        }
        if iat != 0x00f0 {
            hasiat = true
        }
        if map != 0x00f0 {
            hasmap = true
        }
        if rpm != 0x00f0 {
            hasrpm = true
        }
        repeatCount += Int(rawValue.repeatCount)
        return
    }
}

public struct EdmFlightData : Encodable {
    public var flightHeader : EdmFlightHeader?
    public var flightDataBody : [EdmFlightDataRecord] = []
    public var hasoat = false
    public var hasiat = false
    public var hasmap = false
    
    public func valid () -> Bool {
        if flightHeader == nil || flightDataBody.count < 1 {
            return false
        }
        
        return true
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
        if self.valid() == false {
            return -1
        }
        
        return Int(flightDataBody.last!.usd) - Int(flightDataBody.first!.usd)
    }
    
    // fuel used as a sum of "integrated" fuel flow values at each data point
    public func getFuelUsed(outFuelUnit : FuelFlowUnit?) -> Double {
        guard let h = flightHeader else {
            trc(level: .error, string: "getFuelUsed(): no valid header")
            return 0
        }
        
        var interval_secs = h.interval_secs

        let usd = flightDataBody.reduce(0.0) { (res, el) in
          
            if el.mark == 2 {
                interval_secs = 1
            } else if el.mark == 3 {
                interval_secs = h.interval_secs
            }
            return res + Double(el.ff)*Double(interval_secs) / 3600.0
        }
        
        let ff_unit = h.ff.getUnit()
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

    public func getFuelFlowIntervals () -> [(Int, Int, FuelFlowLimits)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getFuelFlowIntervals(): no valid header")
            return nil
        }

        trc(level: .all, string: "getFuelFlowIntervals(): \(h.ff.ff_limits.stringValue())")
        
        let mapped = flightDataBody.map({ $0.ff < h.ff.ff_limits.idle ? FuelFlowLimits.idle : $0.ff < h.ff.ff_limits.cruise ? FuelFlowLimits.cruise : FuelFlowLimits.climb })
        let fr = mapped.enumerated()

        //let filtered = fr.filter({ $0.1.diff[0] > h.alarmLimits.diff || $0.1.diff[1] > h.alarmLimits.diff })
        
        var values : [(Int, Int, FuelFlowLimits) ] = []
        var val : (Int, Int, FuelFlowLimits) = (0,0,FuelFlowLimits.idle)
        var lastVal : FuelFlowLimits? = nil
        
        values = fr.reduce(into: values) { res, elem in
            if lastVal != nil && elem.1 == lastVal {
                // todo: respect mark == 2 || mark == 3
                val.1 += Int(h.interval_secs)
            } else {
                if lastVal != nil {
                    res.append(val)
                }
                val.0 = elem.0
                val.1 = Int(h.interval_secs)
                val.2 = elem.1
            }
            lastVal = elem.1
        }
        
        if lastVal != nil {
            values.append(val)
        }
        
        return values
    }

    public func getMaxEgt () -> (Int,Int) {
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = elem.1.maxEgt()
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
        let fr = flightDataBody.enumerated()
        return fr.reduce((0,0), { (res, elem ) in
            let m = Int(elem.1.oil)
            return m > res.1 ? (elem.0,m) : res
        })
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
                val.2 = Int(h.alarmLimits.cht)
            }
            lastIdx = elem.0
        }
        
        if lastIdx != -1 {
            values.append(val)
        }
        
        return values
    }
    
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

    public func getOilLowCount () -> [(Int,Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getOilLowCount(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.oil < h.alarmLimits.oilLow })
        return a.map({ elem in
            (elem.0, Int(elem.1.oil))
        })
    }

    public func getOilLowIntervals () -> [(Int, Int, Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getOilLowIntervals(): no valid header")
            return nil
        }
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

    public func getOilHighCount () -> [(Int,Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getOilHighCount(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.oil > h.alarmLimits.oilHi })
        return a.map({ elem in
            (elem.0, Int(elem.1.oil))
        })
    }

    public func getOilHighIntervals () -> [(Int, Int, Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getOilHighIntervals(): no valid header")
            return nil
        }
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
    
    public func getColdWarnCount () -> [(Int,Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getColdWarnCount(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let a = fr.filter({ $0.1.cld > h.alarmLimits.cld })
        return a.map({ elem in
            (elem.0, Int(elem.1.cld))
        })
    }

    public func getColdWarnIntervals () -> [(Int, Int, Int)]? {
        guard let h = flightHeader else {
            trc(level: .error, string: "getColdWarnIntervals(): no valid header")
            return nil
        }
        let fr = flightDataBody.enumerated()

        let filtered = fr.filter({ $0.1.cld > h.alarmLimits.cld })
        
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

    enum CodingKeys : CodingKey {
        case flightHeader
        case flightDataBody
    }
    
    public func stringSummary(ff_out_unit : FuelFlowUnit?) -> String? {
        guard let fh = flightHeader else {
            return nil
        }
        
        let ff_ounit = ff_out_unit ?? fh.ff.getUnit()
        let f_unit_string = ff_ounit.volumename
        
        let durationstring = String("duration: " + duration.hms())
        let fuelused : Double = Double(getFuelUsed(outFuelUnit: ff_out_unit))
        let usedstring = String(format: "fuel used: %6.1f %@", fuelused, f_unit_string)
        let recordstring = String(format: "%3d records", flightDataBody.count)

        var s = fh.stringValue()
        
        s.append(", " + durationstring + ", " + usedstring + ", " + recordstring)
         return s
    }

    public func stringValue(ff_out_unit : FuelFlowUnit?) -> String? {
        guard let fh = flightHeader else {
            return nil
        }
        
        let ff_unit = fh.ff.getUnit()
        let ff_ounit = ff_out_unit ?? ff_unit

        let f_unit_string = ff_ounit.volumename
        
        let fuelused : Double = Double(getFuelUsed(outFuelUnit: ff_out_unit))
        
        let usedstring = String(format: "%2.2f", fuelused)

        var s = fh.stringValue()
        
        s.append("\nduration: " + duration.hms() + ", fuel used: \(usedstring) \(f_unit_string)\n")
        
        var (idx, maxt) = self.getMaxEgt()
        var fr = flightDataBody[idx]
        guard let t = fr.date else {
            trc(level: .error, string: "FlightData.stringValue(): no date set")
            return nil
        }
        
        var d = t.timeIntervalSince(fh.date!)
        s.append("max EGT: \(maxt) F after " + d.hms() + "\n")

        (idx, maxt) = self.getMaxCht()
        fr = flightDataBody[idx]
        guard let t = fr.date else {
            trc(level: .error, string: "FlightData.stringValue(): no date set")
            return nil
        }
        
        d = t.timeIntervalSince(fh.date!)
        s.append("max CHT: \(maxt) F after " + d.hms())
        
        (idx, maxt) = self.getMaxDiff()
        fr = flightDataBody[idx]
        guard let t = fr.date else {
            trc(level: .error, string: "FlightData.stringValue(): no date set")
            return nil
        }
        
        d = t.timeIntervalSince(fh.date!)
        s.append("\nmax DIFF: \(maxt) F after " + d.hms())
        return s
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
