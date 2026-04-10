import Cocoa

public struct HotkeyParser {
    public static func parse(_ string: String) -> (NSEvent.ModifierFlags, UInt16)? {
        let components = string.components(separatedBy: "+").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let keyString = components.last else { return nil }

        var modifiers: NSEvent.ModifierFlags = []

        for component in components.dropLast() {
            switch component.lowercased() {
            case "cmd", "command": modifiers.insert(.command)
            case "ctrl", "control": modifiers.insert(.control)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "shift": modifiers.insert(.shift)
            case "caps", "capslock": modifiers.insert(.capsLock)
            case "fn", "function": modifiers.insert(.function)
            default: break
            }
        }

        guard let keyCode = keyCode(for: keyString) else { return nil }

        return (modifiers, keyCode)
    }

    private static func keyCode(for key: String) -> UInt16? {
        switch key.lowercased() {
        case "space": return 49
        case "return", "enter": return 36
        case "tab": return 48
        case "esc", "escape": return 53
        case "delete", "backspace": return 51
        case "left": return 123
        case "right": return 124
        case "down": return 125
        case "up": return 126

        case "a": return 0
        case "b": return 11
        case "c": return 8
        case "d": return 2
        case "e": return 14
        case "f": return 3
        case "g": return 5
        case "h": return 4
        case "i": return 34
        case "j": return 38
        case "k": return 40
        case "l": return 37
        case "m": return 46
        case "n": return 45
        case "o": return 31
        case "p": return 35
        case "q": return 12
        case "r": return 15
        case "s": return 1
        case "t": return 17
        case "u": return 32
        case "v": return 9
        case "w": return 13
        case "x": return 7
        case "y": return 16
        case "z": return 6

        case "0": return 29
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "5": return 23
        case "6": return 22
        case "7": return 26
        case "8": return 28
        case "9": return 25

        case ".": return 47
        case ",": return 43
        case "/": return 44
        case ";": return 41
        case "'": return 39
        case "`": return 50
        case "-": return 27
        case "=": return 24
        case "[": return 33
        case "]": return 30
        case "\\": return 42

        default: return nil
        }
    }

    public static func string(for modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var components: [String] = []

        if modifiers.contains(.command) { components.append("Cmd") }
        if modifiers.contains(.shift) { components.append("Shift") }
        if modifiers.contains(.control) { components.append("Ctrl") }
        if modifiers.contains(.option) { components.append("Opt") }

        if let keyStr = keyString(for: keyCode) {
            components.append(keyStr)
        }

        return components.joined(separator: "+")
    }

    private static func keyString(for code: UInt16) -> String? {
        // Reverse mapping manually for critical keys
        switch code {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Esc"
        case 51: return "Delete"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"

        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"

        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"

        case 47: return "."
        case 43: return ","
        case 44: return "/"
        case 41: return ";"
        case 39: return "'"
        case 50: return "`"
        case 27: return "-"
        case 24: return "="
        case 33: return "["
        case 30: return "]"
        case 42: return "\\"

        default: return nil
        }
    }
}
