import Foundation
import Cocoa
import ArgumentParser
import Expression
import LiveValues
import RenderKit
import PixelKit
import ShellOut

extension Pixlab {

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
        for auto in AutoPIXSingleEffect.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            symbols[.function(name, arity: .exactly(1))] = { args in
                let pix: PIXSingleEffect = auto.pixType.init()
                pix.input = try self.argToPix(args[0])
                return pix
            }
        }
        for auto in AutoPIXMergerEffect.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            symbols[.function(name, arity: .exactly(2))] = { args in
                let pix: PIXMergerEffect = auto.pixType.init()
                pix.inputA = try self.argToPix(args[0])
                pix.inputB = try self.argToPix(args[1])
                return pix
            }
        }
        for auto in AutoPIXMultiEffect.allCases {
            let name: String = auto.rawValue.replacingOccurrences(of: "pix", with: "")
            symbols[.function(name, arity: .atLeast(1))] = { args in
                let pix: PIXMultiEffect = auto.pixType.init()
                pix.inputs = try args.map({ try self.argToPix($0) })
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
    
}
