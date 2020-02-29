import Foundation
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
    #if DEBUG
    PixelKit.main.logDebug()
    #endif
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

struct PixLab: ParsableCommand {
    
//    @Flag(help: "Include a counter with each repetition.")
//    var includeCounter: Bool

    @Option(name: .shortAndLong, help: "Metal Library.")
    var metalLib: URL?
    
    @Option(name: .shortAndLong, help: "Input image.")
    var input: [URL]

//    @Argument()
//    var prefix: String

    @Argument(help: "Code to run.")
    var pixcode: String
    
    enum PixLabError: Error {
        case metalLibNotFound
    }
    
    func run() throws {
        if let metalLib: URL = metalLib {
            setLib(url: metalLib)
        }
        guard didSetup else {
            throw PixLabError.metalLibNotFound
        }
        print("PixLab", input, pixcode)
        var constants: [String: Double] = [:]
        for (i, input) in input.enumerated() {
            constants["$\(i)"] = Double(i)
        }
        let expression = Expression(pixcode, constants: constants)
        let result = try expression.evaluate()
        print("result", result)
    }
    
}

PixLab.main()
