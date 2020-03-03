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
//        guard command != "clear" else {
//            print("\u{001B}[2J")
//            try code()
//            return
//        }
        if try assign(command) {
            try code()
            return
        }
        guard command != "?" else {
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
            try code()
            return
        }
        let pix = try make(command)
        try render(pix)
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
