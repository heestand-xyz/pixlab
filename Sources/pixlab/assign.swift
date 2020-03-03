import Foundation
import Cocoa
import ArgumentParser
import Expression
import LiveValues
import RenderKit
import PixelKit
import ShellOut

extension Pixlab {
    
    func assign(_ command: String) throws -> Bool {
        guard command.contains("=") else {
            if command.last == "." {
                let name: String = String(command.dropLast())
                try listProperties(of: name)
                return true
            }
            return false
        }
        let parts: [String] = command.components(separatedBy: "=")
        var name: String = parts.first!
        guard name.count > 0 else {
            throw PIXLabError.assign("no name")
        }
        if name.count > 1 {
            if name.last! == " " {
                name = String(name.dropLast())
            }
        }
        var arg: String = parts.last!
        guard arg.count > 0 else {
            throw PIXLabError.assign("no code")
        }
        if arg.count > 1 {
            if arg.first! == " " {
                arg = String(arg.dropFirst())
            }
            if arg.last! == " " {
                arg = String(arg.dropLast())
            }
        }
        if try assignDot(name, value: arg) {
            return true
        }
        let url: URL = URL(argument: arg)!
        if FileManager.default.fileExists(atPath: url.path) {
            try assignImage(from: url, as: name)
        } else {
            try assignPIX(code: arg, as: name)
        }
        return true
    }
    
    func assignDot(_ path: String, value: String) throws -> Bool {
        guard path.contains(".") else { return false }
        let parts: [String] = path.components(separatedBy: ".")
        let name: String = parts.first!
        let property: String = parts.last!
        guard let pix: PIX & NODEOut = PIXs.pixs[name] else {
            throw PIXLabError.assign("pix \(name) not found")
        }
        for auto in AutoPIXGenerator.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let autoPix = pix as! PIXGenerator
            let allProperties: [String] = auto.allAutoPropertyNames(for: autoPix)
            guard allProperties.contains(property) else {
                for iProperty in allProperties { print(".\(iProperty)") }
                throw PIXLabError.assign("property \(property) of pix \(name) not found")
            }
            let floats: [AutoLiveFloatProperty] = auto.autoLiveFloats(for: autoPix)
            let ints: [AutoLiveIntProperty] = auto.autoLiveInts(for: autoPix)
            let bools: [AutoLiveBoolProperty] = auto.autoLiveBools(for: autoPix)
            let points: [AutoLivePointProperty] = auto.autoLivePoints(for: autoPix)
            let sizes: [AutoLiveSizeProperty] = auto.autoLiveSizes(for: autoPix)
            let rects: [AutoLiveRectProperty] = auto.autoLiveRects(for: autoPix)
            let colors: [AutoLiveColorProperty] = auto.autoLiveColors(for: autoPix)
            let enums: [AutoEnumProperty] = auto.autoEnums(for: autoPix)
            if try dot(property: property, value: value, floats: floats, ints: ints, bools: bools, points: points, sizes: sizes, rects: rects, colors: colors, enums: enums) {
                return true
            }
        }
        for auto in AutoPIXSingleEffect.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let autoPix = pix as! PIXSingleEffect
            let allProperties: [String] = auto.allAutoPropertyNames(for: autoPix)
            guard allProperties.contains(property) else {
                for iProperty in allProperties { print(".\(iProperty)") }
                throw PIXLabError.assign("property \(property) of pix \(name) not found")
            }
            let floats: [AutoLiveFloatProperty] = auto.autoLiveFloats(for: autoPix)
            let ints: [AutoLiveIntProperty] = auto.autoLiveInts(for: autoPix)
            let bools: [AutoLiveBoolProperty] = auto.autoLiveBools(for: autoPix)
            let points: [AutoLivePointProperty] = auto.autoLivePoints(for: autoPix)
            let sizes: [AutoLiveSizeProperty] = auto.autoLiveSizes(for: autoPix)
            let rects: [AutoLiveRectProperty] = auto.autoLiveRects(for: autoPix)
            let colors: [AutoLiveColorProperty] = auto.autoLiveColors(for: autoPix)
            let enums: [AutoEnumProperty] = auto.autoEnums(for: autoPix)
            if try dot(property: property, value: value, floats: floats, ints: ints, bools: bools, points: points, sizes: sizes, rects: rects, colors: colors, enums: enums) {
                return true
            }
        }
        for auto in AutoPIXMergerEffect.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let autoPix = pix as! PIXMergerEffect
            let allProperties: [String] = auto.allAutoPropertyNames(for: autoPix)
            guard allProperties.contains(property) else {
                for iProperty in allProperties { print(".\(iProperty)") }
                throw PIXLabError.assign("property \(property) of pix \(name) not found")
            }
            let floats: [AutoLiveFloatProperty] = auto.autoLiveFloats(for: autoPix)
            let ints: [AutoLiveIntProperty] = auto.autoLiveInts(for: autoPix)
            let bools: [AutoLiveBoolProperty] = auto.autoLiveBools(for: autoPix)
            let points: [AutoLivePointProperty] = auto.autoLivePoints(for: autoPix)
            let sizes: [AutoLiveSizeProperty] = auto.autoLiveSizes(for: autoPix)
            let rects: [AutoLiveRectProperty] = auto.autoLiveRects(for: autoPix)
            let colors: [AutoLiveColorProperty] = auto.autoLiveColors(for: autoPix)
            let enums: [AutoEnumProperty] = auto.autoEnums(for: autoPix)
            if try dot(property: property, value: value, floats: floats, ints: ints, bools: bools, points: points, sizes: sizes, rects: rects, colors: colors, enums: enums) {
                return true
            }
        }
        for auto in AutoPIXMultiEffect.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let autoPix = pix as! PIXMultiEffect
            let allProperties: [String] = auto.allAutoPropertyNames(for: autoPix)
            guard allProperties.contains(property) else {
                for iProperty in allProperties { print(".\(iProperty)") }
                throw PIXLabError.assign("property \(property) of pix \(name) not found")
            }
            let floats: [AutoLiveFloatProperty] = auto.autoLiveFloats(for: autoPix)
            let ints: [AutoLiveIntProperty] = auto.autoLiveInts(for: autoPix)
            let bools: [AutoLiveBoolProperty] = auto.autoLiveBools(for: autoPix)
            let points: [AutoLivePointProperty] = auto.autoLivePoints(for: autoPix)
            let sizes: [AutoLiveSizeProperty] = auto.autoLiveSizes(for: autoPix)
            let rects: [AutoLiveRectProperty] = auto.autoLiveRects(for: autoPix)
            let colors: [AutoLiveColorProperty] = auto.autoLiveColors(for: autoPix)
            let enums: [AutoEnumProperty] = auto.autoEnums(for: autoPix)
            if try dot(property: property, value: value, floats: floats, ints: ints, bools: bools, points: points, sizes: sizes, rects: rects, colors: colors, enums: enums) {
                return true
            }
        }
        throw PIXLabError.assign("unknown dot assign")
    }
    
    func dot(property: String,
             value: String,
             floats: [AutoLiveFloatProperty],
             ints: [AutoLiveIntProperty],
             bools: [AutoLiveBoolProperty],
             points: [AutoLivePointProperty],
             sizes: [AutoLiveSizeProperty],
             rects: [AutoLiveRectProperty],
             colors: [AutoLiveColorProperty],
             enums: [AutoEnumProperty]) throws -> Bool {
        if let float = floats.first(where: { $0.name == property }) {
            let val: Double = try Expression(value).evaluate()
            float.value = LiveFloat(val)
            return true
        }
        if let int = ints.first(where: { $0.name == property }) {
            let val: Double = try Expression(value).evaluate()
            int.value = LiveInt(Int(val))
            return true
        }
        if let bool = bools.first(where: { $0.name == property }) {
            if ["true", "True", "YES"].contains(value) {
                bool.value = true
            } else if ["false", "False", "NO"].contains(value) {
                bool.value = false
            } else {
                let val: Double = try Expression(value).evaluate()
                bool.value = LiveBool(val > 0.0)
            }
            return true
        }
        if let point = points.first(where: { $0.name == property }) {
            let vals: [Double] = try AnyExpression(value).evaluate()
            guard vals.count == 2 else {
                throw PIXLabError.assign("double array needs 2 values [x,y]")
            }
            point.value = LivePoint(x: LiveFloat(vals[0]),
                                    y: LiveFloat(vals[1]))
            return true
        }
        if let size = sizes.first(where: { $0.name == property }) {
            let vals: [Double] = try AnyExpression(value).evaluate()
            guard vals.count == 2 else {
                throw PIXLabError.assign("double array needs 2 values [w,h]")
            }
            size.value = LiveSize(w: LiveFloat(vals[0]),
                                  h: LiveFloat(vals[1]))
            return true
        }
        if let rect = rects.first(where: { $0.name == property }) {
            let vals: [Double] = try AnyExpression(value).evaluate()
            guard vals.count == 4 else {
                throw PIXLabError.assign("double array needs 4 values [x,y,w,h]")
            }
            rect.value = LiveRect(x: LiveFloat(vals[0]),
                                  y: LiveFloat(vals[1]),
                                  w: LiveFloat(vals[2]),
                                  h: LiveFloat(vals[3]))
            return true
        }
        if let color = colors.first(where: { $0.name == property }) {
            let vals: [Double] = try AnyExpression(value).evaluate()
            guard vals.count == 4 else {
                throw PIXLabError.assign("double array needs 4 values [r,g,b,a]")
            }
            color.value = LiveColor(r: LiveFloat(vals[0]),
                                    g: LiveFloat(vals[1]),
                                    b: LiveFloat(vals[2]),
                                    a: LiveFloat(vals[3]))
            return true
        }
        if let _enum = enums.first(where: { $0.name == property }) {
            guard value.starts(with: ".") else {
                throw PIXLabError.assign("start the enum value with a dot (.)")
            }
            func list() {
                for _case in _enum.cases {
                    print(".\(_case)")
                }
            }
            if value == "." {
                list()
                return true
            }
            guard _enum.cases.map({ ".\($0)" }).contains(value) else {
                list()
                throw PIXLabError.assign("enum value \(value) not found")
            }
            _enum.value = String(value.dropFirst())
            return true
        }
        return false
    }
    
    func listProperties(of name: String) throws {
        guard let pix: PIX & NODEOut = PIXs.pixs[name] else {
            throw PIXLabError.assign("pix \(name) not found")
        }
        for auto in AutoPIXGenerator.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let allProperties: [String] = auto.allAutoPropertyNames(for: pix as! PIXGenerator)
            for iProperty in allProperties {
                print(".\(iProperty)")
            }
            return
        }
        for auto in AutoPIXSingleEffect.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let allProperties: [String] = auto.allAutoPropertyNames(for: pix as! PIXSingleEffect)
            for iProperty in allProperties {
                print(".\(iProperty)")
            }
            return
        }
        for auto in AutoPIXMergerEffect.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let allProperties: [String] = auto.allAutoPropertyNames(for: pix as! PIXMergerEffect)
            for iProperty in allProperties {
                print(".\(iProperty)")
            }
            return
        }
        for auto in AutoPIXMultiEffect.allCases {
            guard String(describing: type(of: pix)) == String(describing: auto.pixType) else { continue }
            let allProperties: [String] = auto.allAutoPropertyNames(for: pix as! PIXMultiEffect)
            for iProperty in allProperties {
                print(".\(iProperty)")
            }
            return
        }
    }
    
    func assignImage(from url: URL, as name: String) throws {
        guard let image: NSImage = NSImage(contentsOf: url) else {
            throw PIXLabError.corruptImage
        }
        let imagePix = ImagePIX()
        imagePix.image = image
        PIXs.pixs[name] = imagePix
    }
    
    func assignPIX(code: String, as name: String) throws {
        let pix = try make(code)
        PIXs.pixs[name] = pix
    }
    
}
