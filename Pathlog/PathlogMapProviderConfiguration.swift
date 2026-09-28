import CoreLocation
import Foundation

enum PathlogMapProviderConfiguration {
    static let openFreeMapLibertyStyleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!

    static var styleURL: URL {
        guard
            let configuredValue = Bundle.main.object(forInfoDictionaryKey: "PathlogMapStyleURL") as? String,
            let configuredURL = URL(string: configuredValue),
            configuredURL.scheme == "https"
        else {
            return openFreeMapLibertyStyleURL
        }

        return configuredURL
    }
}

struct PathlogMapCameraCommand {
    enum Target {
        case center(CLLocationCoordinate2D, zoom: Double)
        case fit([CLLocationCoordinate2D])
    }

    let id = UUID()
    let target: Target
}
