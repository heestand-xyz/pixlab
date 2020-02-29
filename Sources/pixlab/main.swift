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
setLib(url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code/Frameworks/Production/PixelKit/Resources/Metal Libs/PixelKitShaders-macOS.metallib"))

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

struct PixLab: ParsableCommand {
    
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
    
    enum PixLabError: Error {
        case outputNotPNG
        case metalLibNotFound
        case code(String)
        case assign(String)
        case render(String)
    }
    
    func run() throws {
        guard output.pathExtension == "png" else {
            throw PixLabError.outputNotPNG
        }
        if let metalLib: URL = metalLib {
            setLib(url: metalLib)
        }
        guard didSetup else {
            throw PixLabError.metalLibNotFound
        }
        print("PIXLab ready to code:")
        try code()
    }
    
    func code() throws {
        guard let command: String = readLine() else {
            throw PixLabError.code("no command")
        }
        if try assign(command) {
            try code()
            return
        }
        print("command:", command)
        let expression = AnyExpression(command, constants: PIXs.pixs)
        let pix: PIX & NODEOut = try expression.evaluate()
        try render(pix)
    }
    
    func assign(_ command: String) throws -> Bool {
        guard command.contains(" = ") else { return false }
        let parts: [String] = command.components(separatedBy: " = ")
        let name: String = parts.first!
        let path: String = parts.last!
        let url: URL = URL(argument: path)!
        let image: NSImage = NSImage(byReferencing: url)
        let imagePix = ImagePIX()
        imagePix.image = image
        PIXs.pixs[name] = imagePix
        print("image loaded into \(name)")
        return true
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
            throw PixLabError.render("render failed")
        }
        print("did render pix")
        let outData: Data = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try outData.write(to: output)
        print("saved pix")
    }
    
}

PixLab.main()
