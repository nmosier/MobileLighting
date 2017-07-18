import Foundation
import Cocoa

func getKernelString(from filepath: String) -> String {
    var kernel: String
    var result = String()
    var chars: String.CharacterView
    do {
        kernel = try String(contentsOfFile: filepath)
    } catch {
        print("getKernelString: error reading file.")
        return ""
    }
    chars = kernel.characters
    for c in chars {
        if c == "\t" {continue}
        else if c == "\n" {result.append("\\n")}
        else {result.append(c)}
    }
    return result
}

print(getKernelString(from: "/Users/nicholas/OneDrive - Middlebury College/Summer Research 2017/MobileLighting/smartThreshold_NEW.cikernel"))
