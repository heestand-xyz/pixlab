import Foundation
import Cocoa
import ArgumentParser
import Expression
import LiveValues
import RenderKit
import PixelKit

var didSetup: Bool = false
var didSetLib: Bool = false

func setup() {
    guard didSetLib else { return }
    guard !didSetup else { return }
    frameLoopRenderThread = .background
    PixelKit.main.render.engine.renderMode = .manual
//    PixelKit.main.disableLogging()
//    #if DEBUG
    PixelKit.main.logDebug()
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
        if argument.starts(with: "/") {
            self = URL(fileURLWithPath: argument)
        } else if argument.starts(with: "~/") {
            self = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(argument.replacingOccurrences(of: "~/", with: ""))
        } else {
            let callURL: URL = URL(fileURLWithPath: CommandLine.arguments.first!)
            self = callURL.appendingPathComponent(argument)
        }
    }
}

class PIXs {
    static var pixs: [String: PIX & NODEOut] = [:]
}

struct Pixlab: ParsableCommand {
    
//    @Flag(help: "Include a counter with each repetition.")
//    var includeCounter: Bool

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
        case imageNotFound
        case corruptImage
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
        print("PIXLab ready to code:")
        try code()
    }
    
    func code() throws {
        guard let command: String = readLine() else {
            throw PIXLabError.code("no command")
        }
        if try assign(command) {
            try code()
            return
        }
        print("command:", command)
        var symbols: [AnyExpression.Symbol: AnyExpression.SymbolEvaluator] = [:]
        for blendMode in BlendMode.allCases {
            let infix: String = PIX.blendOperators.operatorName(of: blendMode)
            symbols[.infix(infix)] = { args in
                let blendPix = BlendPIX()
                blendPix.blendMode = blendMode
                blendPix.inputA = args[0] as! PIX & NODEOut
                blendPix.inputB = args[1] as! PIX & NODEOut
                return blendPix
            }
        }
        let expression = AnyExpression(command, constants: PIXs.pixs, symbols: symbols)
        let pix: PIX & NODEOut = try expression.evaluate()
        try render(pix)
    }
    
    func assign(_ command: String) throws -> Bool {
        guard command.contains("=") else { return false }
        let parts: [String] = command.components(separatedBy: "=")
        var name: String = parts.first!
        if name.last! == " " {
            name = String(name.dropLast())
        }
        var path: String = parts.last!
        if path.first! == " " {
            path = String(path.dropFirst())
        }
        if path.last! == " " {
            path = String(path.dropLast())
        }
        let url: URL = URL(argument: path)!
        try loadImage(from: url, as: name)
        return true
    }
    
    func loadImage(from url: URL, as name: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PIXLabError.imageNotFound
        }
        guard let image: NSImage = NSImage(contentsOf: url) else {
            throw PIXLabError.corruptImage
        }
        let imagePix = ImagePIX()
        imagePix.image = image
        PIXs.pixs[name] = imagePix
    }
    
    func render(_ pix: PIX) throws {
        print("will render pix")
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
        print("did render pix")
        let outData: Data = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try outData.write(to: output)
        print("saved pix")
    }
    
}

Pixlab.main()
