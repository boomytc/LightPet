import Foundation

package func formatScale(_ scale: Double) -> String {
    if scale.rounded() == scale {
        return String(Int(scale))
    }
    return String(format: "%.2f", scale).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
}

package func isAvailableScale(_ scale: Double) -> Bool {
    availableScales.contains { abs($0 - scale) < 0.001 }
}
