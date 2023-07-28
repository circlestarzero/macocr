import Cocoa
import Vision

// https://developer.apple.com/documentation/vision/vnrecognizetextrequest

let MODE = VNRequestTextRecognitionLevel.accurate // or .fast
let USE_LANG_CORRECTION = true
var REVISION:Int
let RecognitionLanguages = ["zh-Hans","en-US"]
if #available(macOS 13, *) {
    REVISION = VNRecognizeTextRequestRevision3
} else {
    REVISION = VNRecognizeTextRequestRevision1
}

struct CodableBoundingBox: Codable {
    var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat

    init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}

struct PixelBoundingBox: Codable {
    var x: Int, y: Int, width: Int, height: Int
}

struct TextWithBoundingBox: Codable {
    var text: String
    var box: PixelBoundingBox
}

struct OCRResult: Encodable {
    let width: Int
    let height: Int
    let success: Bool
    let result: [TextWithBoundingBox]
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
    let imageWidth = Int(img.size.width)
    let imageHeight = Int(img.size.height)

    let request = VNRecognizeTextRequest { (request, error) in
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        
        var textWithBoundingBoxes: [String: PixelBoundingBox] = [:]
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            // 将归一化的坐标和尺寸转化为像素值，同时调整y值
            let pixelBoundingBox = CGRect(x: observation.boundingBox.origin.x * CGFloat(imageWidth),
                                      y: (1 - (observation.boundingBox.origin.y + observation.boundingBox.height)) * CGFloat(imageHeight),
                                      width: observation.boundingBox.width * CGFloat(imageWidth),
                                      height: observation.boundingBox.height * CGFloat(imageHeight))

            textWithBoundingBoxes[topCandidate.string] = PixelBoundingBox(x: Int(pixelBoundingBox.origin.x), y: Int(pixelBoundingBox.origin.y), width: Int(pixelBoundingBox.width), height: Int(pixelBoundingBox.height))
        }

        // 将字典转化为数组并进行排序
        let sortedBoundingBoxes = textWithBoundingBoxes.map { TextWithBoundingBox(text: $0.key, box: $0.value) }.sorted { (first, second) -> Bool in
            if first.box.y == second.box.y {
                return first.box.x < second.box.x
            }
            return first.box.y < second.box.y
        }

        do {
            let ocrResult = OCRResult(
                width: imageWidth, // replace with actual image width
                height: imageHeight, // replace with actual image height
                success: true,
                result: sortedBoundingBoxes
            )

            let jsonData = try JSONEncoder().encode(ocrResult)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } catch {
            print("{\"success\": false}")
        }

    }
    request.recognitionLevel = MODE
    request.usesLanguageCorrection = USE_LANG_CORRECTION
    request.revision = REVISION
    if #available(macOS 13, *) {
        request.recognitionLanguages = RecognitionLanguages
        // request.automaticallyDetectsLanguage = true
        // Supported Languages: ["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR", "zh-Hans", "zh-Hant", "yue-Hans", "yue-Hant", "ko-KR", "ja-JP", "ru-RU", "uk-UA"]
    }
    //request.minimumTextHeight = 0
    //request.customWords = [String]
    try? VNImageRequestHandler(cgImage: imgRef, options: [:]).perform([request])
    return 0
}
exit(main(args: CommandLine.arguments))
