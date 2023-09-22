//
//  EdmTools.swift
//  BlueEDM
//
//  Created by Staszkiewicz, Carl Philipp on 21.10.21.
//

import Foundation

public func isHighByteBit(_ i: Int) -> Bool {
    return (i>=48 && i<64) || (i == 42 ? true : false)
}

public func getLowByteBit(_ i: Int) -> Int {
    if i>=48 && i < 56 {
        return i - 48
    }
    if i >= 56 && i < 64 {
        return i - 32
    }
    if i == 42 {
        return 41
    }
    return i
}

public enum EdmProtovolVersion {
    case v1 // model number < 900, != 760, no protocol header
    case v2 // model 760
    case v3 // model >= 900 but firmware version < 108
    case v4 // model >= 900, firmware version >= 108 || has a protocol header
    case v5 // model 960
    
    static let highByteBits1 = UInt64(0xff)<<5*8 | UInt64(0xff)<<6*8 | UInt64(1)<<42

    public var flightHeaderSize : Int {
        switch self {
        case .v1: return 15
        case .v2: return 15
        case .v3: return 19
        case .v4: return 21
        case .v5: return 19
        }
    }
    
    public var decodeFlagsSize : Int {
        switch self {
        case .v1, .v2:
            return 16
        default:
            return 32
        }
    }
    
    public var valueFlagsSize : Int {
        switch self {
        case .v1, .v2:
            return 64
        default:
            return 128
        }
    }
}

public struct EdmFileParser {
    public var data : Data = Data()
    public var edmFileData : EdmFileData = EdmFileData()
    var nextread  = 0
    var eor = false // signals end of record
    var headerChecksum : UInt8 = 0
    public var complete = false
    public var invalid = false
    public var proto : EdmProtovolVersion = .v1

    var flightRecords : [EdmFlightDataRecord] = []
    
    public var available : Int {
        return data.count - nextread
    }
    
    var values : [String] = []
    var item : String?

    public init () {
    }
    
    public init (data: Data) {
        self.data = data
    }
    
    public mutating func setData (_ data1: Data){
        data = data1
    }
    
    subscript(index: Data.Index) -> Character {
        return Character(Unicode.Scalar(data[index]))
    }
    
    mutating func readChar() -> Character {
        let c = self[nextread]
        
        //print ("read char: " + String(c) + " (" + String(Int(c.asciiValue ?? 0)) + ")")
        headerChecksum ^= UInt8(c.asciiValue ?? 0)
        nextread += 1
        return c
    }
    
    
    mutating func readUShort() -> UInt16 {
        let us = UInt16(data[nextread]) << 8 + UInt16(data[nextread+1])
        nextread += 2
        return us
    }
    
    mutating func readByte() -> UInt8 {
        let b = data[nextread]
        nextread += 1
        return b
    }
    
    mutating func nextHeaderItem () -> String? {
        var c : Character
        var newItem : String?
        var skip = false
        
        while available > 0 {
            c = readChar()

            if (c == ","){
                if newItem != nil {
                    trc(level: .info, string: "new Item: " + newItem!)
                }
                return newItem
            }
            if (c == "*"){
                // checksum without the "trailing" *
                headerChecksum ^= UInt8(c.asciiValue ?? 0)
                eor = true
                trc(level: .info, string: "new Item: " + (newItem ?? "nil"))
                return newItem
            }

            if (c.isLetter || c.isNumber || c == Character("-") || c == Character("_")){
                if skip {
                    continue
                }
                
                //print("found letter: " + String(c))
                if (newItem == nil){
                    newItem = String(c)
                } else {
                    newItem!.append(String(c))
                }
            } else if (c.isASCII || c.isWhitespace){
                if newItem != nil {
                    skip = true
                }
            }
        }

        return String()
    }
    
    mutating func parseFlightDataRecord(rec original: EdmFlightDataRecord) ->EdmFlightDataRecord? {
        var rdr = EdmRawDataRecord(protocolVersion: proto)
        var rec = original
        let recstart = nextread // keep this for later checksum calculation
        var tmpString = ""
        
        // read the decode flagw
        guard let df = parseFlightDecodeFlags() else {
            return rec
        }
        rdr.decodeFlags = df
        trc(level: .all, string: "parseFlightDataRecord: decode flags = " + String(df.rawValueLow.rawValue, radix: 2))
        
        rdr.repeatCount = Int8(readByte())
        trc(level: .all, string: "parseFlightDataRecord: repeat count = \(rdr.repeatCount)")
        
        // read the compressed value flags
        // TODO assert rdr.valueFlags.numberOfBytes <= rdr.decodeFlags.numberofBits
        for i in 0..<rdr.valueFlags.numberOfBytes {
            if rdr.decodeFlags!.hasBit(i: i) {
                let tmp = UInt8(readByte())
                rdr.valueFlags.setByte(i, value: tmp)
                tmpString.append("[" + String(i) + " " + String(tmp) + "]")
                //trc(level: .error, string: "parseFlightDataRecord: f_value = \(i): \(tmp) sum = \(rdr.valueFlags.rawValueLow.rawValue), values " + String(tmp, radix: 2) + ", " + String(tmp, radix: 16))
            }
        }
        trc(level: .info, string: "parseFlightDataRecord: valueFlags " + tmpString )
        tmpString = ""
        
        // read the compressed signflags
        // TODO assert rdr.signFlags.numberOfBytes <= rdr.decodeFlags.numberofBits
        for i in 0..<rdr.signFlags.numberOfBytes {
            if i != 6 && i != 7 && rdr.decodeFlags!.hasBit(i: i) { // bits 6 & 7 don't have a sign bit
                let tmp = readByte()
                //trc(level: .all, string: "parseFlightDataRecord: f_sign = \(i): \(tmp) " + String(tmp, radix: 2) + ", " + String(tmp, radix: 16))
                rdr.signFlags.setByte(i, value: tmp)
                tmpString.append("[" + String(i) + " " + String(tmp) + "]")
            }
        }
        trc(level: .info, string: "parseFlightDataRecord: signFlags " + tmpString )
        tmpString = ""

        // read compressed values and compute naflags
        for i in 0..<rdr.valueFlags.numberOfBits {
            if rdr.valueFlags.hasBit(i: i){
                let tmp = UInt8(readByte())
                //trc(level: .info, string: "read value \(i) = \(tmp)" + (isHighByteBit(i) ? " high byte" : " low byte"))
                if tmp != 0 { // stored value != zero => store in data record
                    if rec.naflags.hasBit(i: i){
                        trc(level: .info, string: "clear NA for \(i)")
                        rec.naflags.clearBit(i: i)
                    }
                    if isHighByteBit(i){
                        let j = getLowByteBit(i)
                        //trc(level: .error, string: "(\(j!),\(i)) -> (\(rdr.values[j!]), \(tmp) -> ")
                        rdr.values[j] += (rdr.signFlags.hasBit(i: j) ? -1 : 1) * (Int16(tmp)<<8)
                        //trc(level: .error, string: "(\(j!),\(i)) -> \(rdr.values[j!])")

                    } else {
                        rdr.values[i] += (rdr.signFlags.hasBit(i: i) ? -1 : 1) * Int16(UInt16(tmp))
                    }
                } else { // if stored value is zero, set NA for the low byte. High byte == 0 will leave this unchanged
                    if !isHighByteBit(i){
                        rec.naflags.setBit(i: i)
                        trc(level: .info, string: "NA for Bit \(i)")
                    }
                }
                tmpString.append("[" + String(i) + " " + String(tmp) + "]")
                // trc(level: .all, string: "parse: idx \(i) val8 \(val8) \(rdr.values[i])")
            }
        }
        trc(level: .info, string: "parseFlightDataRecord: values " + tmpString )
        tmpString = ""
        // special case for the rpm value (byte 41 and hi value only present for single engine)
        if edmFileData.edmFileHeader != nil{
            let numOfEngines = edmFileData.edmFileHeader?.config.numOfEngines()
            if numOfEngines == 1 {
                if rdr.signFlags.hasBit(i: 41) {
                    rdr.values[42] = -rdr.values[42]
                }
                if rdr.values[42] != 0 {
                    rec.naflags.clearBit(i: 42)
                }
            }
        }
        
        guard let hd = edmFileData.edmFileHeader else {
            return rec
        }
        let numOfCyl = hd.config.features.numCylinders()
        let numOfEng = hd.config.numOfEngines()
        
        if numOfEng > 1 && numOfCyl > 6 {
            return rec
        }
        
        rec.add(rawValue: rdr)
        
        // egt spread for first engine
        var min = Int16(0x7fff)
        var max = Int16(-1)
        for i in 0..<numOfCyl {
            if !rec.naflags.hasBit(i: i) {
                if rec.egt[i] > max {
                    max = rec.egt[i]
                }
                if rec.egt[i] < min {
                    min = rec.egt[i]
                }
            } else {
                rec.egt[i] = 0
            }
        }
        
        rec.diff[0] = Int(max) - Int(min)
        trc(level: .info, string: "parseFlightDataRecord: diff for engine \(0) \(rec.diff[0])")

        // egt spread for second engine
        if numOfEng > 1 {
            min = Int16(0x7fff)
            max = Int16(-1)
            for i in 0..<numOfCyl {
                if !rec.naflags.hasBit(i: i + 24) {
                    if rec.regt[i] > max {
                        max = rec.regt[i]
                    }
                    if rec.regt[i] < min {
                        min = rec.regt[i]
                    }
                } else {
                    rec.regt[i] = 0
                }
            }
            rec.diff[1] = Int(max) - Int(min)
            trc(level: .info, string: "parseFlightDataRecord: diff for engine \(1) \(rec.diff[1])")
        }
        
        let count = nextread - recstart
        trc(level: .info, string: "parseFlightDataRecord: parsed \(count+1) Bytes")
       
        // do the checksum stuff
        let cs = calcChecksum(from: recstart, to: nextread)
        let storedcs = readByte()
        if cs != storedcs {
            trc(level: .error, string: String(format: "ParseFlightDataRecord: checksum failed (expected 0x%X , found 0x%X)", storedcs, cs))
            return nil
        }
        return rec
    }
    
    func calcChecksum(from start: Int, to end: Int) -> UInt8 {
        let version = edmFileData.edmFileHeader?.config.version ?? 300 // use new checksum as default
        var cs : UInt8 = 0
        
        if version >= 300 {
            for i in start ..< end {
                cs = cs &+ data[i]
            }
            cs = 0 &- cs
        }
        else {
            for i in start ..< end {
                cs = cs ^ data[i]
            }
        }
        return cs
    }
    
    mutating func parseFlightDecodeFlags() -> EdmDecodeFlags? {
        guard available > 1 else {
            return nil
        }
        
        if edmFileData.edmFileHeader!.decodeMaskSingleByte {
            let rv = UInt64(data[nextread]) << 8 + UInt64(data[nextread+1])
            nextread += 2
            let edmDecodeFlags = EdmDecodeFlags(low: rv, high: 0, size: 16)
            return edmDecodeFlags
        } else {
            let rv = UInt64(data[nextread]) << 24 + UInt64(data[nextread+1]) << 16 +
                UInt64(data[nextread+2]) << 8 + UInt64(data[nextread+3])
            nextread += 4
            let edmDecodeFlags = EdmDecodeFlags(low: rv, high: 0, size: 32)
            return edmDecodeFlags

        }
    }
    
    mutating func parseHeaderLine () -> EdmHeaderLine {
        var hl : EdmHeaderLine = EdmHeaderLine()
        var linetypechar : Character = Character("Z")
        eor = false
        headerChecksum = 0
        
        if available > 1 {
            if self[0] != "$" {
                return hl
            }
            nextread += 1
            linetypechar = readChar()
        }
        
        while available > 0 && eor == false {
            item = nextHeaderItem()
            if item != nil {
                hl.contents.append(item!)
            }
        }
        
        if available > 2 {
            // read checksum
            var s : String = String(self[nextread])
            s.append(self[nextread + 1])
            let cs = UInt8(s, radix: 16)
        
            if cs != headerChecksum {
                trc(level: .error, string: "parseHeaderLine: checksum error. Required " + String(cs ?? 0) + ", calculated " + String(headerChecksum) + " (" + s + ")")
            }
            nextread += 2
            
            // read \n\r
            if self[nextread] != "\r" || self[nextread + 1] != "\n" {
                trc(level: .error, string: "parseHeaderLine: invalid token at EOL " + String(self[nextread]))
                nextread += 2
                hl.lineType = .lineTypeInvalid
                return hl
            }
            nextread += 2
        }
                
        switch linetypechar {
            case "U":
                hl.lineType = .lineTypeRegistration
            case "A":
                hl.lineType = .lineTypeAlert
            case "F":
                hl.lineType = .lineTypeFuelFlow
            case "T":
                hl.lineType = .lineTypeTimestamp
            case "C":
                hl.lineType = .lineTypeConfig
            case "P":
                hl.lineType = .lineTypeProto
            case "H":
                hl.lineType = .lineTypeFvl
            case "I":
                hl.lineType = .lineTypeCrb
            case "D":
                hl.lineType = .lineTypeFlight
            case "L":
                hl.lineType = .lineTypeLastLine
            default:
                hl.lineType = .lineTypeInvalid
        }
        
        if hl.lineType == .lineTypeInvalid {
            trc(level: .error, string: "parseHeaderLine: invalid line type: \(linetypechar)")
        }
        trc(level: .info, string: "parseHeaderLine: new line type: " + String(linetypechar))
        return hl
    }
    
    public mutating func parseFlightHeaderAndSkip (for id: Int) -> EdmFlightHeader? {
        
        guard let flightheader = parseFlightHeader(for: id) else {
            return nil
        }

        guard let idx = edmFileData.edmFileHeader!.idx(for: id) else {
            trc(level: .error, string: "parseFlightHeaderAndSkip: no idx found for id \(id)")
            return nil
        }
        
        let size = edmFileData.edmFileHeader!.flightInfos[idx].sizeBytes - edmFileData.edmFileHeader!.flightHeaderSize
        nextread += size

        return flightheader
    }
    
    public mutating func parseFlightHeaderAndBody (for id: Int) {

        trc(level: .info, string: "parseFlightHeaderAndBody: read position before header \(nextread)")
        guard let flightheader = parseFlightHeader(for: id) else {
            self.invalid = true
            return
        }
        
        let flightId = flightheader.id
        let flags = flightheader.flags

        if (flightId != id) {
            trc(level: .error, string: "parseFlightHeaderAndBody(\(id)): flight Ids dont match. Wanted \(id), found \(flightId)")
            //self.invalid = true
            return
        }
        
        let features = self.edmFileData.edmFileHeader!.config.features
        if (flags.rawValue != features.rawValue){
            trc(level: .warn, string: "parseFlightHeaderAndBody(\(id)): flags dont match. flight " + flags.stringValue() + ", file " + features.stringValue())
//            self.invalid = true
//            return
        }

        guard let idx =  edmFileData.edmFileHeader!.idx(for: id) else {
            trc(level: .error, string: "parseFlightHeaderAndBody(\(id)): no idx found for flight id \(id)")
            self.invalid = true
            return
        }
        
        let size = edmFileData.edmFileHeader!.flightInfos[idx].sizeBytes - edmFileData.edmFileHeader!.flightHeaderSize
        let nextflightread = nextread + size
        
        if available < size {
            trc(level: .error, string: "parseFlightHeaderAndBody(\(id)): Not enough data (have \(available), need \(size)")
            self.invalid = true
            return
        }
        
        var efd = EdmFlightData()
        efd.flightHeader = flightheader

        guard let date = flightheader.date else {
            trc(level: .error,string:  "parseFlightHeaderAndBody(\(id)): no date in header")
            self.invalid = true
            return
        }

        var currentRec = EdmFlightDataRecord(numofCyl: edmFileData.edmFileHeader?.config.features.numCylinders() ?? 6)

        currentRec.date = date
        var interval_secs = TimeInterval(flightheader.interval_secs)
        currentRec.hasoat = features.contains(.oat)
        currentRec.hasiat = features.contains(.iat)
        currentRec.hasmap = features.contains(.map)
        currentRec.hasrpm = features.contains(.rpm)
        currentRec.hasff = features.contains(.ff)
        currentRec.hascld = features.contains(.cld)
        currentRec.hasoil = features.contains(.oil)
        var repeatcount = 0
        var reccount = 0
        let inc : Int = edmFileData.edmFileHeader!.decodeMaskSingleByte ? 3 : 5
        while nextread + inc <= nextflightread {
            trc(level: .info, string: "parseFlightHeaderAndBody: read position before record \(nextread) (nextflightread=\(nextflightread))")
            guard let rec = parseFlightDataRecord(rec: currentRec) else {
                trc(level: .error, string: "parseFlightDataAndBody(\(id),\(repeatcount)): parsing flight record failed")
                self.invalid = true
                return
            }
            //rec.date = date
            
            efd.hasnaflag = efd.hasnaflag == true ? true : (rec.naflags.rawValue != 0 ? true : false)
            
            trc(level: .info, string: "flight (\(id)) record: \(repeatcount) (\(reccount)) \(rec.date!)")
            efd.flightDataBody.append(rec)
            currentRec = rec
            
            var rc = rec.repeatCount
            repeatcount += rc + 1
            reccount += 1
            while rc > 0 {
                trc(level: .info, string: "repeat record \(reccount) of flight \(id) \(rc)")
                currentRec.date = currentRec.date!.advanced(by: interval_secs)
                efd.flightDataBody.append(currentRec)
                rc -= 1
            }
            
            if rec.naflags.rawValue != 0 {
                trc(level: .info, string: "NA for record(\(reccount)) is set")
            }
            trc(level: .info, string: "parseFlightHeaderAndBody (\(id), \(repeatcount)): " + rec.stringValue())
            
            currentRec.repeatCount = 0
            if currentRec.mark == 2 {
                trc(level: .info, string: "parseFlightHeaderAndBody(\(id),\(repeatcount)): mark is 2, switch timeinterval to 1 second")
                interval_secs = 1
            }
            
            if currentRec.mark == 3 {
                trc(level: .info, string: "parseFlightHeaderAndBody(\(id),\(repeatcount): mark is 3, switch back timeinterval to \(flightheader.interval_secs) second")
                interval_secs = TimeInterval(flightheader.interval_secs)
            }
            currentRec.date = currentRec.date!.advanced(by: interval_secs)
        }
        
        edmFileData.edmFlightData.append(efd)

        trc(level: .info, string: "parseFlightHeaderAndBody(\(id)): nextread is \(nextread), next flight starts at \(nextflightread), size is  \(size) ")

        nextread = nextflightread

        return
    }

    mutating func parseFlightHeader (for id: Int) -> EdmFlightHeader? {
        
        guard let fh = edmFileData.edmFileHeader else {
            return nil
        }
        
        guard let idx = fh.idx(for: id) else {
            trc(level: .error, string: "parseFlightHeader(for: \(id)): no flight found")
            return nil
        }

        nextread = fh.flightInfos[idx].offset - 1

        if !peek(for: id) {
            trc(level: .info, string: "Id \(id) not found at nextread \(nextread), advance by one")
            nextread += 1
        }
        
        return parseFlightHeader()
    }
    
    func peek(for id : Int) -> Bool {
        let lid = Int(data[nextread]) << 8 + Int(data[nextread+1])
        if lid == id {
            return true
        }
        return false
    }
    
    mutating func parseFlightHeader ( ) -> EdmFlightHeader? {
        
        guard available > edmFileData.edmFileHeader!.flightHeaderSize else {
            return nil
        }
        
        guard let h = edmFileData.edmFileHeader else {
            trc(level: .error, string: "parseFlightHeader(): no File header")
            return nil
        }
        
        var a : [UInt16]  = []
        let start = nextread
        for _ in 0...6 {
            a.append(readUShort())
        }
        
        if h.hasProtocolHeader {
            a.append(readUShort())
            a.append(readUShort())
            if (h.config.buildNumber ?? 0) > 108 {
                a.append(readUShort())
            }
        }
        
        
        var flightheader = EdmFlightHeader(values: a)

        let cs = calcChecksum(from: start, to: nextread)
        let checksum = self.data[nextread]
        nextread += 1
        
        if cs != checksum {
            print(String(format: "EdmFlightHeader (id %d): failed for checksum (required 0x%X , data 0x%X)", flightheader?.id ?? 0, checksum, cs))
            return nil
        }
        flightheader?.checksum = cs
        //inherit alarmLimits, Fuel Flow and registration from file header
        flightheader?.alarmLimits = h.alarms
        flightheader?.registration = h.registration
        flightheader?.ff = h.ff
        flightheader?.units = h.units
        
        trc(level: .all, string: "inherited ff")
        return flightheader
    }

    public mutating func parseFileHeaders () -> EdmFileHeader? {
        var edmFileHeader =  EdmFileHeader()
        var hl = EdmHeaderLine()

        while hl.lineType != .lineTypeLastLine {
            hl = parseHeaderLine()
            switch hl.lineType {
                case .lineTypeRegistration:
                    edmFileHeader.registration = edmFileHeader.initRegistration(hl.contents) ?? ""
                    edmFileHeader.registration.trimEnd()
                case .lineTypeAlert:
                    edmFileHeader.alarms = EdmAlarmLimits(hl.contents)
                case .lineTypeFuelFlow:
                    edmFileHeader.ff = EdmFuelFlow(hl.contents)
                case .lineTypeTimestamp:
                    edmFileHeader.date = edmFileHeader.initDate(hl.contents)
                case .lineTypeConfig:
                    edmFileHeader.config = EdmConfig(hl.contents)
                case .lineTypeFlight:
                    edmFileHeader.flightInfos.append(EdmFlightInfo(hl.contents))
                case .lineTypeProto:
                    edmFileHeader.protocolHeader = Int(hl.contents[0]) ?? 0
                case .lineTypeCrb, .lineTypeFvl:
                    break
                case .lineTypeLastLine:
                    break
                case .lineTypeInvalid:
                    return nil
            }
        }
        
        edmFileHeader.headerLen = nextread
        edmFileHeader.totalLen = edmFileHeader.headerLen
        for (index, flight) in edmFileHeader.flightInfos.enumerated() {
            edmFileHeader.flightInfos[index].offset = edmFileHeader.totalLen
            edmFileHeader.totalLen += flight.sizeBytes
        }
        
        self.proto = edmFileHeader.protocolVersion
        // all other units correct by default
        switch  edmFileHeader.ff.getUnit() {
        case .GPH:
            edmFileHeader.units.flow_unit = .gph
            edmFileHeader.units.volume_unit = .gallons
        case .KPH:
            edmFileHeader.units.flow_unit = .kgph
            edmFileHeader.units.volume_unit = .kg
        case .PPH:
            edmFileHeader.units.flow_unit = .lbsph
            edmFileHeader.units.volume_unit = .lbs
        case .LPH:
            edmFileHeader.units.flow_unit = .lph
            edmFileHeader.units.volume_unit = .liters
        }
        
        if edmFileHeader.config.temperatureUnit == .celsius {
            edmFileHeader.units.temp_unit = .celsius
        }
        
        if edmFileHeader.config.unknown & 0xF0 == 0 {
            edmFileHeader.units.oat_unit = .fahrenheit
        }
        
        trc(level: .info, string: edmFileHeader.stringValue(includeFlights: true) + "Protocol Version: \(proto)")
        return edmFileHeader
    }
}


struct EdmHeaderLine {
    
    static let MAX_LEN = 256
    enum EdmLineType {
        case lineTypeInvalid
        case lineTypeRegistration
        case lineTypeAlert
        case lineTypeFuelFlow
        case lineTypeTimestamp
        case lineTypeConfig
        case lineTypeFlight
        case lineTypeFvl
        case lineTypeProto
        case lineTypeCrb
        case lineTypeLastLine
    }
    
    var lineType : EdmLineType = .lineTypeInvalid
    var contents : [String] = []
    var registration : String = ""
    var checkSum : Int
    
    init() {
        lineType = .lineTypeInvalid
        contents = []
        checkSum = 0
    }
    
}

extension Date
{
    public func toString( dateFormat format  : String ) -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }

}

