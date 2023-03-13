//
//  File.swift
//  BlueEDM
//
//  Created by Staszkiewicz, Carl Philipp on 11.10.21.
//

import Foundation
import SwiftUI

public struct EdmFileHeader : Encodable {
    public var registration : String = ""
    public var date : Date?
    public var alarms = EdmAlarmLimits()
    public var ff = EdmFuelFlow()
    public var config = EdmConfig()
    public var flightInfos : [EdmFlightInfo] = []
    var protocolHeader : Int? = nil
    var headerLen = 0
    public var totalLen = 0
    public var units = EdmUnits()
    
    public var hasProtocolHeader : Bool {
        get {
            return protocolHeader == nil ? false : true
        }
    }
    
    public var extraConfig : Bool {
        get {
            return hasProtocolHeader || config.modelNumber >= 900
        }
    }
    
    public var decodeMaskSingleByte : Bool {
        get {
            return !extraConfig
        }
    }
    
    public var flightHeaderSize : Int {
        get {
            return 15 + (extraConfig ? ((config.buildNumber ?? 0) >= 108 ? 6 : 4) : 0)
        }
    }
    
    public var protocolVersion : EdmProtovolVersion {
        if config.modelNumber == 760 {
            return .v2
        }
        if config.modelNumber == 960 {
            return .v5
        }
        if config.modelNumber >= 900 {
            if config.buildNumber != nil && config.buildNumber! >= 108 {
                return .v4
            } else {
                return .v3
            }
        } else {
            return hasProtocolHeader ? .v4 : .v1
        }
    }
    
    func idx(for flightid: Int) -> Int? {
        for (i, info) in flightInfos.enumerated() {
            if info.id == flightid {
                return i
            }
        }
        return nil
    }
        
    func initDate(_ values: [String]) -> Date? {
        if values.count != 6 {
            return nil
        }
        
        let month = Int(values[0]) ?? 0
        let day = Int(values[1]) ?? 0
        let year = (Int(values[2]) ?? 0) + 2000
        let hour = Int(values[3]) ?? 0
        let minutes = Int(values[4]) ?? 0
        
        let dc = DateComponents(year: year, month: month, day: day, hour: hour, minute: minutes)
        let c = Calendar(identifier: Calendar.Identifier.gregorian)
        let d = c.date(from: dc)
        
        return d
    }
    
    func initRegistration (_ values: [String]) -> String? {
        if values.count != 1 {
            return nil
        }
        let r = values[0]
        return r
    }
    
    public func stringValue(includeFlights: Bool) -> String {
        var str = ""
        str.append("Header Size: " + String(headerLen))
        str.append(", Total Size: " + String(totalLen) + "\n\n")
        str.append("Registration: " + registration + "\n")
        if date != nil {
            str.append("Download Date: " + date!.toString(dateFormat: "dd.MM.YY HH:mm\n"))
            //str.append("(offset: " + String(Int((self.timeOffset()/60.0))) + " minutes)\n")
        }
        str.append(config.stringValue())
        str.append(config.features.stringValue())
        str.append(ff.stringValue())
        str.append(alarms.stringValue())
        
        str.append("Flights:")
        if includeFlights {
            str.append("\n")
            for flight in flightInfos {
                str.append(flight.stringValue())
            }
        }
        return str
    }
    
    public func timeOffset () -> TimeInterval {
        return -Date().distance(to: self.date ?? Date())
    }
}

public struct EdmFlightInfo : Encodable {
    public var id : Int = 0
    var sizeWords : Int = 0
    var offset : Int = 0 // byte offset of this flights data in the data stream
    
    public var sizeBytes : Int {
        return sizeWords * 2
    }
    
    init(_ values: [String] = []){
        if values.count != 2 {
            return
        }
        
        id = Int(values[0]) ?? -1
        sizeWords = Int(values[1]) ?? -1
    }
    
    public func stringValue() -> String {
        var str = ""
        str.append("Id: " + String(id) + ", Offset: " + String(offset) + ", Size: " + String(sizeBytes) + " Bytes\n")
        return str
    }
}

extension UInt16 {
    func bytesumval() -> UInt {
        let r : UInt16 = self & 0xff + (self >> 8) & 0xff
        return UInt(r & 0xff)
    }
}

public struct EdmFlightHeader : Encodable {
    public var id : UInt16 = 0
    var flags = EdmFeatures()
    var unknown : UInt16 = 0
    var interval_secs : UInt16 = 0
    public var date : Date?
    public var alarmLimits = EdmAlarmLimits()
    public var ff = EdmFuelFlow()
    
    public var registration = ""
    var checksum : UInt8 = 0
    
    public func hasfeature(_ feature: EdmFeatures) -> Bool {
        return flags.contains(feature)
    }
    
    public func stringValue () -> String {
        var str = ""
        
        let d : Date = date ?? Date()
        str.append("flight id: " + String(id))
        str.append(", " + d.toString(dateFormat: "dd.MM.YY HH:mm"))
        
        return str
    }
    
    init? (values a : [UInt16], checksum : UInt8){
        
        if a.count < 7 {
            return nil
        }

        let i = a.count - 7
        id = a[0]
        flags = EdmFeatures(high: a[2], low: a[1])
    
        unknown = a[3+i]
        interval_secs = a[4+i]
        
        
        let dt = a[5+i]
        let tm = a[6+i]
        
        let day = Int(dt & 0x001F)
        let month = Int((dt & 0x01E0) >> 5)
        let year = Int((dt & 0xfe00) >> 9)
        
        let seconds = Int((tm & 0x001f)) * 2
        let minutes = Int((tm & 0x07E0) >> 5)
        let hour = Int((tm & 0xF800) >> 11)

        let dc = DateComponents(year: year, month: month, day: day, hour: hour, minute: minutes, second: seconds)
        let c = Calendar(identifier: Calendar.Identifier.gregorian)
        date = c.date(from: dc)
        
        var cs = a.map { $0.bytesumval() }.reduce(0,+) & 0xff
        cs = (256 - cs) & 0xff
        
        trc(level: .info, string: "EdmFlightHeader(\(id)): checksum is \(cs)")
        
        if cs != checksum {
            print(String(format: "EdmFlightHeader (id %d): failed for checksum (required 0x%X , data 0x%X)", id, checksum, cs))
            return nil
        }
        self.checksum = checksum
    }
}

public struct EdmFileData : Encodable {
    public var edmFileHeader : EdmFileHeader?
    public var edmFlightData : [EdmFlightData]
    init () {
        edmFlightData = []
    }
    
    public func getFlight(for id : Int) -> EdmFlightData? {
        guard let h = self.edmFileHeader else {
            trc(level: .error, string: "getFlight(\(id)): no flight header")
            return nil
        }
        
        guard let idx = h.idx(for: id) else {
            trc(level: .error, string: "getFlight(\(id)): no such flight")
            return nil
        }
        
        return edmFlightData[idx]
    }
}

public enum EdmTracelevel: Int {
    case error = 0
    case warn
    case info
    case all
}

public var traceLevel : EdmTracelevel = .error

public func setTraceLevel(_ level : EdmTracelevel) {
    traceLevel = level
}

public func trc(level: EdmTracelevel, string : @autoclosure () -> String) {
    if level.rawValue <= traceLevel.rawValue {
        print(string())
    }
}
