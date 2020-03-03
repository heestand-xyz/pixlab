import Foundation
import Cocoa
import ArgumentParser
import Expression
import LiveValues
import RenderKit
import PixelKit
import ShellOut
import PIXLang

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
        guard try PIXLang.assign(value, at: property, to: pix) else {
            throw PIXLabError.assign("unknown dot assign")
        }
        return true
    }
    
    func listProperties(of name: String) throws {
        guard let pix: PIX & NODEOut = PIXs.pixs[name] else {
            throw PIXLabError.assign("pix \(name) not found")
        }
        guard let list: [String] = PIXLang.propertyNames(for: pix) else {
            throw PIXLabError.assign("list for pix \(name) not found")
        }
        for name in list {
            print(".\(name)")
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
        let pix = try PIXLang.eval(code: code, with: PIXs.pixs, defaultResolution: resolution)
        PIXs.pixs[name] = pix
    }
    
}
