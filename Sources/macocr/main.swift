import Cocoa
import Vision

// https://developer.apple.com/documentation/vision/vnrecognizetextrequest

let MODE = VNRequestTextRecognitionLevel.accurate // or .fast
let USE_LANG_CORRECTION = true
var REVISION:Int
if #available(macOS 13, *) {
    REVISION = VNRecognizeTextRequestRevision3
} else {
    REVISION = VNRecognizeTextRequestRevision1
}

func main(args: [String]) -> Int32 {


    guard (CommandLine.arguments.count == 3 || CommandLine.arguments.count == 2) else {
        fputs(String(format: "usage: %1$@ image dst | usage: %1$@ image\n", CommandLine.arguments[0]), stderr)
        return 1
    }

    // Flag ideas:
    // --version
    // Print REVISION
    // --langs
    // guard let langs = VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: REVISION)
    // --fast (default accurate)
    // --fix (default no language correction)

    // let (src, dst) = (args[1], args[2])

    guard let img = NSImage(byReferencingFile: args[1]) else {
        fputs("Error: failed to load image '\(args[1])'\n", stderr)
        return 1
    }

    guard let imgRef = img.cgImage(forProposedRect: &img.alignmentRect, context: nil, hints: nil) else {
        fputs("Error: failed to convert NSImage to CGImage for '\(args[1])'\n", stderr)
        return 1
    }


    let request = VNRecognizeTextRequest { (request, error) in
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let obs : [String] = observations.map { $0.topCandidates(1).first?.string ?? ""}
        if CommandLine.arguments.count == 3{
            try? obs.joined(separator: "\n").write(to: URL(fileURLWithPath: args[2]), atomically: true, encoding: String.Encoding.utf8)
        }else{
            print(obs.joined(separator: "\n"))
        }
    }
    request.recognitionLevel = MODE
    request.usesLanguageCorrection = USE_LANG_CORRECTION
    request.revision = REVISION
    if #available(macOS 13, *) {
        request.recognitionLanguages = ["zh-Hans","en-US"]
        // request.automaticallyDetectsLanguage = true
        // Supported Languages: ["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR", "zh-Hans", "zh-Hant", "yue-Hans", "yue-Hant", "ko-KR", "ja-JP", "ru-RU", "uk-UA"]
    }
    //request.minimumTextHeight = 0
    //request.customWords = [String]

    try? VNImageRequestHandler(cgImage: imgRef, options: [:]).perform([request])

    return 0
}
exit(main(args: CommandLine.arguments))
