import Foundation
import Cocoa
import ArgumentParser
import Expression
import LiveValues
import RenderKit
import PixelKit
import ShellOut
import PIXLang

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

extension Resolution: ExpressibleByArgument {
    public init?(argument: String) {
        if argument.contains("x") {
            let parts: [String] = argument.split(separator: "x").map({"\($0)"})
            let widthStr: String = parts[0]
            let heightStr: String = parts[1]
            guard let width: Int = Int(widthStr),
                  let height: Int = Int(heightStr) else {
                return nil
            }
            self = .custom(w: width, h: height)
        } else if let val = Int(argument) {
            self = .square(val)
        } else if let res: Resolution = Resolution.standardCases.first(where: { $0.name == argument }) {
            self = res
        } else {
            return nil
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
    
    @Option(name: .shortAndLong, help: "resolution. default is auto.")
    var resolution: Resolution?

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
        case corruptImage
//        case pixInitFail(String)
//        case unknownArg(Any)
//        case badArg(String)
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
                print("error:", String(describing: error))
            }
        }
    }
    
    func code() throws {
        print("> ", terminator: "")
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
            let clearPix = ColorPIX(at: resolution ?? ._128)
            clearPix.color = .clear
            try render(clearPix)
            try code()
            return
        }
        if try assign(command) {
            try code()
            return
        }
        guard command != "?" else {
            list()
            try code()
            return
        }
        let pix = try PIXLang.eval(code: command, with: PIXs.pixs, defaultResolution: resolution)
        try render(pix)
        try code()
    }
    
    func list() {
        for auto in AutoPIXGenerator.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            print("\(name)(res)")
        }
        for auto in AutoPIXSingleEffect.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            print("\(name)(pix)")
        }
        for auto in AutoPIXMergerEffect.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            print("\(name)(pixA, pixB)")
        }
        for auto in AutoPIXMultiEffect.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            print("\(name)(pixA, pixB, pixC, ...)")
        }
    }
    
    func render(_ pix: PIX & NODEOut) throws {
        var finalPix: PIX = pix
        if let resolution: Resolution = resolution {
            let resolutionPix = ResolutionPIX(at: resolution)
            resolutionPix.input = pix
            resolutionPix.extend = .hold
            resolutionPix.placement = .aspectFill
            finalPix = resolutionPix
        }
        var outImg: NSImage?
        var rendering: Bool? = true
        startTic()
        loopTic(while: { rendering })
        let group = DispatchGroup()
        group.enter()
        try PixelKit.main.render.engine.manuallyRender {
            outImg = finalPix.renderedImage
            group.leave()
        }
        group.wait()
        guard let img: NSImage = outImg else {
            rendering = nil
            throw PIXLabError.render("render failed")
        }
        rendering = false
        let outData: Data = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try outData.write(to: output)
        if view {
            _ = try shellOut(to: .openFile(at: output.path))
        }
        rendering = nil
        endTic()
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
            self.gohstPrint(String.init(repeating: state == true ? "." : ":", count: i + 1) + String.init(repeating: " ", count: 3 - i))
            return true
        }
    }
    
    func gohstPrint(_ message: String) {
        print("\(message)\r", terminator: "")
        fflush(stdout)
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
