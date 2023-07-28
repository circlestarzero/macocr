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

func kMeans(_ data: [Double], k: Int, threshold: Double = 1e-4) -> ([Double], [Int]) {
    assert(k > 0, "Number of clusters must be positive.")
    
    // 1. Randomly select k data points as initial centroids
    var centroids = data.shuffled().prefix(k)
    
    var oldCentroids = [Double](repeating: 0.0, count: k)
    var labels = [Int](repeating: 0, count: data.count)
    
    while maxDifference(oldCentroids: oldCentroids, newCentroids: Array(centroids)) > threshold {
        oldCentroids = Array(centroids)
        
        // 2. Assign each data point to the closest centroid
        for (i, point) in data.enumerated() {
            let closestCentroidIndex = centroids.enumerated().min(by: {
                abs($0.1 - point) < abs($1.1 - point)
            })!.0
            
            labels[i] = closestCentroidIndex
        }
        
        // 3. Update each centroid to the mean of its assigned points
        for i in 0..<k {
            let pointsInCluster = zip(data, labels).filter({$1 == i}).map({$0.0})
            centroids[i] = pointsInCluster.reduce(0, +) / Double(pointsInCluster.count)
        }
    }
    
    return (Array(centroids), labels)
}

// Function to find the maximum difference between old and new centroids
func maxDifference(oldCentroids: [Double], newCentroids: [Double]) -> Double {
    assert(oldCentroids.count == newCentroids.count, "Old and new centroids must have the same count.")
    
    var maxDiff = 0.0
    for (old, new) in zip(oldCentroids, newCentroids) {
        maxDiff = max(maxDiff, abs(old - new))
    }
    return maxDiff
}

func isTwoColums(centroids:[Double], labelsOneCluster:[Int],xCordinates: [Double])-> Bool{
    
    //count the number of elements in each cluster
    let distance = abs(centroids[0]-centroids[1])
    // count 0 in the labels
    var clusterSizes = [0, 0]
    for label in labelsOneCluster {
        clusterSizes[label] += 1
    }
    let difpercent = Double(abs(clusterSizes[0]-clusterSizes[1]))/Double(xCordinates.count)
    print(distance, difpercent)
    if (difpercent < 0.2 && distance > 0.2){
        return true
    }else{
        return false
    }
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


    // let request = VNRecognizeTextRequest { (request, error) in
    //     let observations = request.results as? [VNRecognizedTextObservation] ?? []
    //     let obs : [String] = observations.map { $0.topCandidates(1).first?.string ?? ""}
    //     if CommandLine.arguments.count == 3{
    //         try? obs.joined(separator: "\n").write(to: URL(fileURLWithPath: args[2]), atomically: true, encoding: String.Encoding.utf8)
    //     }else{
    //         print(obs.joined(separator: "\n"))
    //     }
    // }
    let request = VNRecognizeTextRequest { (request, error) in
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    var textWithBoundingBoxes: [String: CGRect] = [:]
    for observation in observations {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        let boundingBox = observation.boundingBox
        textWithBoundingBoxes[topCandidate.string] = boundingBox
    }
    let xCords = textWithBoundingBoxes.map {Double ($0.value.origin.x )}
    let widths = textWithBoundingBoxes.map {Double ($0.value.width )}
    //caculate the mean of the width
    let meanWidth = widths.reduce(0, +)/Double(widths.count)
    print(meanWidth)
    let (centroids, labelsOneCluster) = kMeans(xCords, k: 2)
    var text = ""
    // find the threshold of the two columns by the maxium of the first cluster
    if isTwoColums(centroids:centroids,labelsOneCluster:labelsOneCluster,xCordinates: xCords){
        var xthreshold = 0.0
         for xcord in xCords{
            if labelsOneCluster[xCords.firstIndex(of: xcord)!] == 0{
                if xcord > xthreshold{
                    xthreshold = xcord
                }
            }
            }
        for (key, value) in textWithBoundingBoxes {
            if (value.width > meanWidth*1.5){
                //find the middle space of the text
                let text = key
                let middle = text.index(text.startIndex, offsetBy: text.count/2)
                // find the position of space character in the text which is nearest the middle
                let left = text[..<middle].lastIndex(of: " ")
                let right = text[middle...].firstIndex(of: " ")
                var splitIndex = left ?? right ?? middle
                // if left and right are not nil, find the nearest one to the middle
                if left != nil && right != nil {
                    let leftDistance = text.distance(from: left!, to: middle)
                    let rightDistance = text.distance(from: right!, to: middle)
                    if leftDistance > rightDistance {
                        splitIndex = right!
                    } else {
                        splitIndex = left!
                    }
                }
                if left == nil && right == nil || text.distance(from: splitIndex, to: middle) > text.count/2{
                    // splitIndex = middle
                    continue
                }
                // strip the space character
                let firstPart = text[..<splitIndex]
                // strip the space character
                let secondPart = text[splitIndex...]
                // add the two parts to the dictionary
                var value1 = value
                value1.size.width = CGFloat(Double(value.width)/Double(text.count)*Double(firstPart.count))
                var value2 = value
                value2.size.width = CGFloat(Double(value.width)/Double(text.count)*Double(secondPart.count))
                textWithBoundingBoxes[String(firstPart)] = value1
                textWithBoundingBoxes[String(secondPart)] = value2.offsetBy(dx: value1.width, dy: 0)
                print("split \(key) into \(firstPart) and \(secondPart)")
                print("width \(value.width) into \(value1.width) and \(value2.width)")
                // remove the original text
                textWithBoundingBoxes.removeValue(forKey: key)
            }
        }
        
        //if the xCords is less than the threshold, it is in the left column, otherwise it is in the right column
        //then sort the text in the left column by yCords
        let leftText = textWithBoundingBoxes.filter {Double ($0.value.origin.x ) < xthreshold}.sorted {Double ($0.value.origin.y ) > Double ($1.value.origin.y )}
        //then sort the text in the right column by yCords
        let rightText = textWithBoundingBoxes.filter {Double ($0.value.origin.x ) >= xthreshold}.sorted {Double ($0.value.origin.y ) > Double ($1.value.origin.y )}
        // return the text in the left column and right column
        text = leftText.map { "\($0.key)" }.joined(separator: " ") + " " + rightText.map { "\($0.key)" }.joined(separator: " ")
        
    }
    if CommandLine.arguments.count == 3 {
        let path = CommandLine.arguments[2]
        let fileUrl = URL(fileURLWithPath: path)
        let text = textWithBoundingBoxes.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        do {
            try text.write(to: fileUrl, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing to file: \(error)")
        }
    } else  {
        if (text == "") {
            text = textWithBoundingBoxes.map { "\($0.key)" }.joined(separator: " ")
        }
        print(text)
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
