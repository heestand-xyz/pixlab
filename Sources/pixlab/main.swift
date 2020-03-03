import Foundation
import Cocoa
import ArgumentParser
import Expression
import LiveValues
import RenderKit
import PixelKit
import ShellOut

var didSetup: Bool = false
var didSetLib: Bool = false

func setup() {
    guard didSetLib else { return }
    guard !didSetup else { return }
    frameLoopRenderThread = .background
    PixelKit.main.render.engine.renderMode = .manual
    PixelKit.main.disableLogging()
//    #if DEBUG
//    PixelKit.main.logDebug()
//    #endif
    didSetup = true
}

func setLib(url: URL) {
    guard !didSetLib else { return }
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    pixelKitMetalLibURL = url
    didSetLib = true
    setup()
}

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        let path: String = argument.replacingOccurrences(of: "\\ ", with: " ")
        if path.starts(with: "/") {
            self = URL(fileURLWithPath: path)
        } else if path.starts(with: "~/") {
            self = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path.replacingOccurrences(of: "~/", with: ""))
        } else {
            let callURL: URL = URL(fileURLWithPath: CommandLine.arguments.first!)
            self = callURL.appendingPathComponent(path)
        }
    }
}

class PIXs {
    static var pixs: [String: PIX & NODEOut] = [:]
}

var active: Bool = true

struct Pixlab: ParsableCommand {
    
    @Flag(help: "View the image after render.")
    var view: Bool

    @Option(name: .shortAndLong, help: "metal library")
    var metalLib: URL?
    
//    @Option(name: .shortAndLong, help: "resolution. default: 1920x1080")
//    var resolution: [URL]

//    @Argument()
//    var prefix: String

//    @Argument(help: "Code to run.")
//    var pixcode: String
    
    @Argument(help: "final output image")
    var output: URL
    
    enum PIXLabError: Error {
        case outputNotPNG
        case metalLibNotFound
        case code(String)
        case assign(String)
        case render(String)
//        case imageNotFound
        case corruptImage
        case pixInitFail(String)
        case unknownArg(Any)
        case badArg(String)
    }
    
    func run() throws {
        guard output.pathExtension == "png" else {
            throw PIXLabError.outputNotPNG
        }
        if let metalLib: URL = metalLib {
            setLib(url: metalLib)
        } else {
            setLib(url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code/Frameworks/Production/PixelKit/Resources/Metal Libs/PixelKitShaders-macOS.metallib"))
        }
        guard didSetup else {
            throw PIXLabError.metalLibNotFound
        }
//        print("pixlab ready to code:")
        while active {
            do {
                try code()
            } catch {
                print("pixlab error:", String(describing: error))
            }
        }
    }
    
    func code() throws {
        guard let command: String = readLine() else {
            throw PIXLabError.code("no command")
        }
        guard command != "" else {
            try code()
            return
        }
        guard ![":q", "exit"].contains(command) else {
            print("exit? y/n")
            if ["yes", "y"].contains(readLine()) {
                exit()
                return
            }
            try code()
            return
        }
        guard ![":q!"].contains(command) else {
            exit()
            return
        }
        guard command != "clear" else {
            print("\u{001B}[2J")
            print("abc")
            try code()
            return
        }
        if try assign(command) {
            try code()
            return
        }
        let pix = try make(command)
        try render(pix)
    }
    
    func make(_ code: String) throws -> PIX & NODEOut {
        var symbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator] = [:]
        symbols[.function("rgb", arity: .exactly(3))] = { args in
            guard let vals: [Double] = args as? [Double] else {
                throw PIXLabError.badArg("arg type is array of floats")
            }
            return LiveColor(r: LiveFloat(vals[0]),
                             g: LiveFloat(vals[1]),
                             b: LiveFloat(vals[2]))
        }
        symbols[.function("rgba", arity: .exactly(4))] = { args in
            guard let vals: [Double] = args as? [Double] else {
                throw PIXLabError.badArg("arg type is array of floats")
            }
            return LiveColor(r: LiveFloat(vals[0]),
                             g: LiveFloat(vals[1]),
                             b: LiveFloat(vals[2]),
                             a: LiveFloat(vals[3]))
        }
        symbols[.function("hsv", arity: .exactly(3))] = { args in
            guard let vals: [Double] = args as? [Double] else {
                throw PIXLabError.badArg("arg type is array of floats")
            }
            return LiveColor(h: LiveFloat(vals[0]),
                             s: LiveFloat(vals[1]),
                             v: LiveFloat(vals[2]))
        }
        symbols[.function("hsva", arity: .exactly(4))] = { args in
            guard let vals: [Double] = args as? [Double] else {
                throw PIXLabError.badArg("arg type is array of floats")
            }
            return LiveColor(h: LiveFloat(vals[0]),
                             s: LiveFloat(vals[1]),
                             v: LiveFloat(vals[2]),
                             a: LiveFloat(vals[3]))
        }
        for auto in AutoPIXGenerator.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            symbols[.function(name, arity: .exactly(1))] = { args in
                let res: Resolution = try self.res(from: args)
                let pix: PIXGenerator = auto.pixType.init(at: res)
                return pix
            }
        }
        for blendMode in BlendMode.allCases {
            let infix: String = PIX.blendOperators.operatorName(of: blendMode)
            symbols[.infix(infix)] = { args in
                let blendPix = BlendPIX()
                blendPix.blendMode = blendMode
                blendPix.placement = .aspectFill
                blendPix.extend = .hold
                blendPix.inputA = try self.argToPix(args[0])
                blendPix.inputB = try self.argToPix(args[1])
                return blendPix
            }
        }
        symbols[.infix("->")] = { args in
            let displacePix = DisplacePIX()
            displacePix.distance = 1.0
            displacePix.placement = .aspectFill
            displacePix.extend = .hold
            displacePix.inputA = try self.argToPix(args[0])
            displacePix.inputB = try self.argToPix(args[1])
            return displacePix
        }
        let expression = AnyExpression(code, constants: PIXs.pixs, symbols: symbols)
        let pix: PIX & NODEOut = try argToPix(try expression.evaluate())
        return pix
    }
    
    func argToPix(_ arg: Any) throws -> PIX & NODEOut {
        if let pix = arg as? PIX & NODEOut {
            return pix
        }
        if let color: LiveColor = argToColor(arg) {
            let colorPix = ColorPIX(at: .square(1))
            colorPix.color = color
            return colorPix
        }
        throw PIXLabError.unknownArg(arg)
    }
    
    func argToColor(_ arg: Any) -> LiveColor? {
        if let color: LiveColor = arg as? LiveColor {
            return color
        }
        var color: LiveColor?
        if let val = arg as? Double {
            color = LiveColor(lum: LiveFloat(val))
        } else if let vals = arg as? [Double] {
            if vals.count == 2 {
                color = LiveColor(lum: LiveFloat(vals[0]),
                                  a: LiveFloat(vals[1]))
            } else if vals.count == 3 {
                color = LiveColor(r: LiveFloat(vals[0]),
                                  g: LiveFloat(vals[1]),
                                  b: LiveFloat(vals[2]))
            } else if vals.count == 4 {
                color = LiveColor(r: LiveFloat(vals[0]),
                                  g: LiveFloat(vals[1]),
                                  b: LiveFloat(vals[2]),
                                  a: LiveFloat(vals[3]))
            }
        }
        return color
    }
    
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
            let allProperties: [String] = auto.allAutoPropertyNames(for: pix as! PIXGenerator)
            guard allProperties.contains(property) else {
                for iProperty in allProperties {
                    print(".\(iProperty)")
                }
                throw PIXLabError.assign("property \(property) of pix \(name) not found")
            }
            let floats = auto.autoLiveFloats(for: pix as! PIXGenerator)
            if let float = floats.first(where: { $0.name == property }) {
                let val: Double = try Expression(value).evaluate()
                float.value = LiveFloat(val)
                return true
            }
            let ints = auto.autoLiveInts(for: pix as! PIXGenerator)
            if let int = ints.first(where: { $0.name == property }) {
                let val: Double = try Expression(value).evaluate()
                int.value = LiveInt(Int(val))
                return true
            }
            let bools = auto.autoLiveBools(for: pix as! PIXGenerator)
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
            let points = auto.autoLivePoints(for: pix as! PIXGenerator)
            if let point = points.first(where: { $0.name == property }) {
                let vals: [Double] = try AnyExpression(value).evaluate()
                guard vals.count == 2 else {
                    throw PIXLabError.assign("double array needs 2 values [x,y]")
                }
                point.value = LivePoint(x: LiveFloat(vals[0]),
                                        y: LiveFloat(vals[1]))
                return true
            }
            let sizes = auto.autoLiveSizes(for: pix as! PIXGenerator)
            if let size = sizes.first(where: { $0.name == property }) {
                let vals: [Double] = try AnyExpression(value).evaluate()
                guard vals.count == 2 else {
                    throw PIXLabError.assign("double array needs 2 values [w,h]")
                }
                size.value = LiveSize(w: LiveFloat(vals[0]),
                                      h: LiveFloat(vals[1]))
                return true
            }
            let rects = auto.autoLiveRects(for: pix as! PIXGenerator)
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
            let colors = auto.autoLiveColors(for: pix as! PIXGenerator)
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
            let enums = auto.autoEnums(for: pix as! PIXGenerator)
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
        }
        throw PIXLabError.assign("unknown dot assign")
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
    
    func render(_ pix: PIX) throws {
        var outImg: NSImage?
        var rendering: Bool? = true
        startTic()
        loopTic(while: { rendering })
        let group = DispatchGroup()
        group.enter()
        try PixelKit.main.render.engine.manuallyRender {
            outImg = pix.renderedImage
            group.leave()
        }
        group.wait()
        rendering = false
        guard let img: NSImage = outImg else {
            throw PIXLabError.render("render failed")
        }
        let outData: Data = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try outData.write(to: output)
        if view {
            _ = try shellOut(to: .openFile(at: output.path))
        }
        rendering = nil
        endTic()
    }
    
    func res(from args: [Any]) throws -> Resolution {
        guard let arg: Any = args.first else {
            throw PIXLabError.pixInitFail("bad res arg count.")
        }
        if let val: Double = arg as? Double {
            return .square(Int(val))
        }
        guard let resStr: String = arg as? String else {
            throw PIXLabError.pixInitFail("bad res. format: 1920x1080")
        }
        let wStr: String = String(resStr.split(separator: "x").first!)
        let hStr: String = String(resStr.split(separator: "x").last!)
        guard let w: Int = Int(wStr) else {
            throw PIXLabError.pixInitFail("bad res width. format: 1920x1080")
        }
        guard let h: Int = Int(hStr) else {
            throw PIXLabError.pixInitFail("bad res height. format: 1920x1080")
        }
        return .custom(w: w, h: h)
    }
    
    func startTic() {
        print("...\r", terminator: "")
        fflush(stdout)
    }
    
    func loopTic(while active: @escaping () -> (Bool?)) {
        var i = 0
        self.bgTimer(0.01) {
            let state: Bool? = active()
            guard state != nil else { return false }
            i = (i + 1) % 3
            print(String.init(repeating: state == true ? "." : ":", count: i + 1) + String.init(repeating: " ", count: 3 - i) + "\r", terminator: "")
            fflush(stdout)
            return true
        }
    }
    
    func endTic() {
        print("   \r", terminator: "")
    }
    
    func bgTimer(_ duration: Double, _ callback: @escaping () -> (Bool)) {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .milliseconds(Int(duration * 1_000.0))) {
            guard callback() else { return }
            self.bgTimer(duration, callback)
        }
    }
    
    func exit() {
        active = false
    }
    
}

Pixlab.main()
