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

struct Pixlab: ParsableCommand {
    
    @Flag(help: "View the image after render.")
    var view: Bool

    @Option(name: .shortAndLong, help: "metal library")
    var metalLib: URL?
    
//    @Option(name: .shortAndLong, help: "Input image.")
//    var input: [URL]

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
        print("pixlab ready to code:")
        while true {
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
                var arg: Any = args.first!
                if let number: Int = arg as? Int {
                    arg = "\(number)"
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
                let res: Resolution = .custom(w: w, h: h)
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
        guard command.contains("=") else { return false }
        let parts: [String] = command.components(separatedBy: "=")
        var name: String = parts.first!
        if name.last! == " " {
            name = String(name.dropLast())
        }
        var arg: String = parts.last!
        if arg.first! == " " {
            arg = String(arg.dropFirst())
        }
        if arg.last! == " " {
            arg = String(arg.dropLast())
        }
        let url: URL = URL(argument: arg)!
        if FileManager.default.fileExists(atPath: url.path) {
            try assignImage(from: url, as: name)
        } else {
            try assignPIX(code: arg, as: name)
        }
        return true
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
        let group = DispatchGroup()
        group.enter()
        try PixelKit.main.render.engine.manuallyRender {
            outImg = pix.renderedImage
            group.leave()
        }
        group.wait()
        guard let img: NSImage = outImg else {
            throw PIXLabError.render("render failed")
        }
        let outData: Data = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try outData.write(to: output)
        if view {
            _ = try shellOut(to: .openFile(at: output.path))
        }
    }
    
}

Pixlab.main()
