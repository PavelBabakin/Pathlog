import CoreLocation
import MapLibre
import SwiftUI
import UIKit

struct PathlogMapRouteLine {
    enum Appearance {
        case historical
        case selectedHistory
        case playback
        case live
    }

    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let appearance: Appearance
}

struct PathlogMapGapMarker: Identifiable {
    enum Kind: Equatable {
        case privateZone
        case tracking
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
}

struct MapFeatureCoordinate: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MapFeaturePolygon: Equatable {
    let exteriorRing: [MapFeatureCoordinate]
    let interiorRings: [[MapFeatureCoordinate]]
}

struct MapFeatureSelection: Equatable {
    let identifier: String?
    let sourceLayer: String
    let geometryJSON: String?
    let polygons: [MapFeaturePolygon]
}

struct MapLocationSelection: Equatable, Identifiable {
    let id: UUID
    let coordinate: MapFeatureCoordinate
    let feature: MapFeatureSelection?

    init(coordinate: CLLocationCoordinate2D, feature: MapFeatureSelection?) {
        self.id = UUID()
        self.coordinate = MapFeatureCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        self.feature = feature
    }

    var locationCoordinate: CLLocationCoordinate2D {
        coordinate.locationCoordinate
    }
}

struct PathlogMapView: UIViewRepresentable {
    let styleURL: URL
    let privateZones: [PrivateZone]
    let notes: [MapNote]
    let routeLines: [PathlogMapRouteLine]
    let gapMarkers: [PathlogMapGapMarker]
    let playbackCoordinate: CLLocationCoordinate2D?
    let currentCoordinate: CLLocationCoordinate2D?
    let routeRevision: UInt64
    let zoneRevision: UInt64
    let markerRevision: UInt64
    let cameraCommand: PathlogMapCameraCommand?
    let selectedLocation: MapLocationSelection?
    let onCameraChange: (CLLocationCoordinate2D) -> Void
    let onLongPress: (CGPoint, MapLocationSelection) -> Void
    let onPrivateZoneSelected: (UUID) -> Void
    let onNoteSelected: (UUID) -> Void
    let onMapLoadError: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsCompassView = true
        mapView.compassViewPosition = .topRight
        mapView.compassViewMargins = CGPoint(x: 12, y: 76)
        mapView.showsScale = true
        mapView.scaleBarPosition = .topLeft
        mapView.scaleBarMargins = CGPoint(x: 12, y: 82)
        mapView.scaleBarUsesMetricSystem = true
        mapView.showsAttributionButton = true
        mapView.attributionButtonPosition = .topLeft
        mapView.attributionButtonMargins = CGPoint(x: 12, y: 126)
        mapView.showsLogoView = true

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        longPress.allowableMovement = 10
        longPress.cancelsTouchesInView = false
        longPress.delegate = context.coordinator
        mapView.addGestureRecognizer(longPress)
        context.coordinator.longPressRecognizer = longPress
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if mapView.styleURL != styleURL {
            coordinator.isStyleLoaded = false
            mapView.styleURL = styleURL
        }

        if coordinator.isStyleLoaded {
            coordinator.applyContentIfNeeded(to: mapView)
            coordinator.applyCurrentLocationIfNeeded(to: mapView)
            coordinator.applySelectedLocationIfNeeded(to: mapView)
            coordinator.applyCameraCommandIfNeeded(to: mapView)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: PathlogMapView
        weak var mapView: MLNMapView?
        weak var longPressRecognizer: UILongPressGestureRecognizer?
        var isStyleLoaded = false
        private var lastRouteRevision: UInt64?
        private var lastZoneRevision: UInt64?
        private var lastMarkerRevision: UInt64?
        private var lastCurrentCoordinate: CLLocationCoordinate2D?
        private var lastSelectedLocationID: UUID?
        private var lastCameraCommandID: UUID?
        private var routeOverlays: [MLNOverlay] = []
        private var zoneOverlays: [MLNOverlay] = []
        private var markerAnnotations: [PathlogPointAnnotation] = []
        private var currentLocationAnnotation: PathlogPointAnnotation?
        private var selectedLocationAnnotation: PathlogPointAnnotation?
        private var selectedFeaturePolygons: [MLNPolygon] = []
        private var selectedFeatureOutlines: [MLNPolyline] = []
        private var routeStyles: [ObjectIdentifier: RouteStyle] = [:]
        private var zoneStyles: [ObjectIdentifier: ZoneStyle] = [:]
        private var selectedFeatureStyles: [ObjectIdentifier: ZoneStyle] = [:]

        init(parent: PathlogMapView) {
            self.parent = parent
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard
                recognizer.state == .began,
                let mapView = recognizer.view as? MLNMapView
            else {
                return
            }

            let point = recognizer.location(in: mapView)
            if let zoneID = privateZoneID(at: point, in: mapView) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                parent.onPrivateZoneSelected(zoneID)
                return
            }

            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let feature = buildingFeature(at: point, coordinate: coordinate, in: mapView)
            let selection = MapLocationSelection(coordinate: coordinate, feature: feature)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            parent.onLongPress(point, selection)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            isStyleLoaded = true
            addHouseNumberLayer(to: style)
            lastRouteRevision = nil
            lastZoneRevision = nil
            lastMarkerRevision = nil
            lastSelectedLocationID = nil
            applyContentIfNeeded(to: mapView)
            applyCurrentLocationIfNeeded(to: mapView)
            applySelectedLocationIfNeeded(to: mapView)
            applyCameraCommandIfNeeded(to: mapView)
            parent.onMapLoadError(nil)
        }

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            parent.onMapLoadError(error.localizedDescription)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            parent.onCameraChange(mapView.centerCoordinate)
        }

        func mapView(
            _ mapView: MLNMapView,
            didSelect annotation: MLNAnnotation
        ) {
            guard let marker = annotation as? PathlogPointAnnotation else { return }
            if let noteID = marker.noteID {
                parent.onNoteSelected(noteID)
            }
            mapView.deselectAnnotation(annotation, animated: false)
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let marker = annotation as? PathlogPointAnnotation else { return nil }

            let reuseIdentifier = marker.visual.reuseIdentifier
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
                ?? MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            annotationView.annotation = annotation
            annotationView.subviews.forEach { $0.removeFromSuperview() }
            annotationView.backgroundColor = .clear
            annotationView.clipsToBounds = false

            let markerSize: CGFloat = marker.visual == .currentLocation ? 20 : 34
            let labelHeight: CGFloat = marker.label == nil ? 0 : 20
            let width = max(markerSize, marker.label.map { textWidth($0) } ?? markerSize)
            annotationView.bounds = CGRect(x: 0, y: 0, width: width, height: markerSize + labelHeight)
            annotationView.centerOffset = CGVector(dx: 0, dy: labelHeight / 2)

            let symbolView = UIView(frame: CGRect(
                x: (width - markerSize) / 2,
                y: 0,
                width: markerSize,
                height: markerSize
            ))
            symbolView.backgroundColor = marker.visual.color
            symbolView.layer.cornerRadius = markerSize / 2
            symbolView.layer.borderColor = UIColor.white.cgColor
            symbolView.layer.borderWidth = 2
            symbolView.layer.shadowColor = UIColor.black.cgColor
            symbolView.layer.shadowOpacity = 0.22
            symbolView.layer.shadowRadius = 3
            symbolView.layer.shadowOffset = CGSize(width: 0, height: 2)

            let imageView = UIImageView(image: UIImage(systemName: marker.visual.symbol))
            imageView.tintColor = .white
            imageView.contentMode = .scaleAspectFit
            imageView.frame = symbolView.bounds.insetBy(dx: 8, dy: 8)
            symbolView.addSubview(imageView)
            annotationView.addSubview(symbolView)

            if let label = marker.label {
                let titleLabel = UILabel(frame: CGRect(x: 0, y: markerSize, width: width, height: labelHeight))
                titleLabel.text = label
                titleLabel.textAlignment = .center
                titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
                titleLabel.textColor = .label
                titleLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.82)
                titleLabel.layer.cornerRadius = 5
                titleLabel.clipsToBounds = true
                annotationView.addSubview(titleLabel)
            }

            annotationView.isAccessibilityElement = true
            annotationView.accessibilityLabel = marker.label ?? marker.visual.accessibilityLabel
            return annotationView
        }

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            if let polyline = annotation as? MLNPolyline {
                return routeStyles[ObjectIdentifier(polyline)]?.color ?? .systemBlue
            }
            if let style = selectedFeatureStyles[ObjectIdentifier(annotation)] {
                return style.stroke
            }
            return zoneStyles[ObjectIdentifier(annotation)]?.stroke ?? .systemRed
        }

        func mapView(_ mapView: MLNMapView, fillColorForPolygonAnnotation annotation: MLNPolygon) -> UIColor {
            if let style = selectedFeatureStyles[ObjectIdentifier(annotation)] {
                return style.fill
            }
            return zoneStyles[ObjectIdentifier(annotation)]?.fill ?? UIColor.systemRed.withAlphaComponent(0.12)
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
            routeStyles[ObjectIdentifier(annotation)]?.width ?? 4
        }

        private func privateZoneID(at point: CGPoint, in mapView: MLNMapView) -> UUID? {
            markerAnnotations.reversed().first { marker in
                guard
                    marker.zoneID != nil,
                    marker.visual == .privateZone || marker.visual == .disabledZone
                else {
                    return false
                }

                let markerPoint = mapView.convert(marker.coordinate, toPointTo: mapView)
                return hypot(markerPoint.x - point.x, markerPoint.y - point.y) <= 28
            }?.zoneID
        }

        func applyContentIfNeeded(to mapView: MLNMapView) {
            guard isStyleLoaded else { return }

            if lastRouteRevision != parent.routeRevision {
                mapView.removeOverlays(routeOverlays)
                routeOverlays.forEach { routeStyles.removeValue(forKey: ObjectIdentifier($0)) }
                routeOverlays = parent.routeLines.compactMap { route in
                    guard route.coordinates.count >= 2 else { return nil }
                    let coordinates = route.coordinates
                    let line = MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
                    routeStyles[ObjectIdentifier(line)] = RouteStyle(appearance: route.appearance)
                    return line
                }
                mapView.addOverlays(routeOverlays)
                lastRouteRevision = parent.routeRevision
            }

            if lastZoneRevision != parent.zoneRevision {
                mapView.removeOverlays(zoneOverlays)
                zoneOverlays.forEach { zoneStyles.removeValue(forKey: ObjectIdentifier($0)) }
                zoneOverlays = parent.privateZones.compactMap { zone in
                    guard zone.radiusMeters > 0 else { return nil }
                    let coordinates = circleCoordinates(center: zone.coordinate, radius: zone.radiusMeters)
                    let polygon = MLNPolygon(coordinates: coordinates, count: UInt(coordinates.count))
                    zoneStyles[ObjectIdentifier(polygon)] = ZoneStyle(isEnabled: zone.isEnabled)
                    return polygon
                }
                mapView.addOverlays(zoneOverlays)
                lastZoneRevision = parent.zoneRevision
            }

            if lastMarkerRevision != parent.markerRevision {
                mapView.removeAnnotations(markerAnnotations)
                markerAnnotations = parent.privateZones.map { zone in
                    PathlogPointAnnotation(
                        coordinate: zone.coordinate,
                        visual: zone.isEnabled ? .privateZone : .disabledZone,
                        label: nil,
                        zoneID: zone.id
                    )
                }
                markerAnnotations += parent.notes.map { note in
                    PathlogPointAnnotation(
                        coordinate: note.coordinate,
                        visual: .note,
                        label: note.displayTitle,
                        noteID: note.id
                    )
                }
                markerAnnotations += parent.gapMarkers.map { gap in
                    PathlogPointAnnotation(
                        coordinate: gap.coordinate,
                        visual: gap.kind == .privateZone ? .privateGap : .trackingGap,
                        label: nil
                    )
                }
                if let playbackCoordinate = parent.playbackCoordinate {
                    markerAnnotations.append(
                        PathlogPointAnnotation(coordinate: playbackCoordinate, visual: .playback, label: nil)
                    )
                }
                mapView.addAnnotations(markerAnnotations)
                lastMarkerRevision = parent.markerRevision
            }

            applyCurrentLocationIfNeeded(to: mapView)
        }

        func applySelectedLocationIfNeeded(to mapView: MLNMapView) {
            guard lastSelectedLocationID != parent.selectedLocation?.id else { return }

            mapView.removeOverlays(selectedFeaturePolygons + selectedFeatureOutlines)
            selectedFeaturePolygons.forEach {
                selectedFeatureStyles.removeValue(forKey: ObjectIdentifier($0))
            }
            selectedFeatureOutlines.forEach {
                routeStyles.removeValue(forKey: ObjectIdentifier($0))
            }
            selectedFeaturePolygons.removeAll(keepingCapacity: true)
            selectedFeatureOutlines.removeAll(keepingCapacity: true)

            if let selectedLocationAnnotation {
                mapView.removeAnnotation(selectedLocationAnnotation)
            }

            if let selection = parent.selectedLocation {
                if let feature = selection.feature {
                    for featurePolygon in feature.polygons {
                        guard let polygon = makePolygon(from: featurePolygon) else { continue }
                        selectedFeaturePolygons.append(polygon)
                        selectedFeatureStyles[ObjectIdentifier(polygon)] = ZoneStyle(
                            stroke: UIColor.systemTeal,
                            fill: UIColor.systemTeal.withAlphaComponent(0.22)
                        )
                        selectedFeatureOutlines += makeOutlines(from: featurePolygon)
                    }
                    selectedFeatureOutlines.forEach {
                        routeStyles[ObjectIdentifier($0)] = RouteStyle(color: .systemTeal, width: 3)
                    }
                    mapView.addOverlays(selectedFeaturePolygons + selectedFeatureOutlines)
                }

                let marker = PathlogPointAnnotation(
                    coordinate: selection.locationCoordinate,
                    visual: .selectedLocation,
                    label: nil
                )
                selectedLocationAnnotation = marker
                mapView.addAnnotation(marker)
            } else {
                selectedLocationAnnotation = nil
            }

            lastSelectedLocationID = parent.selectedLocation?.id
        }

        func applyCurrentLocationIfNeeded(to mapView: MLNMapView) {
            guard !sameCoordinate(lastCurrentCoordinate, parent.currentCoordinate) else { return }
            if let currentLocationAnnotation {
                mapView.removeAnnotation(currentLocationAnnotation)
            }

            if let coordinate = parent.currentCoordinate {
                let marker = PathlogPointAnnotation(coordinate: coordinate, visual: .currentLocation, label: nil)
                mapView.addAnnotation(marker)
                currentLocationAnnotation = marker
            } else {
                currentLocationAnnotation = nil
            }
            lastCurrentCoordinate = parent.currentCoordinate
        }

        func applyCameraCommandIfNeeded(to mapView: MLNMapView) {
            guard let command = parent.cameraCommand else { return }
            guard lastCameraCommandID != command.id else { return }
            guard isStyleLoaded else { return }

            switch command.target {
            case let .center(coordinate, zoom):
                mapView.setCenter(coordinate, zoomLevel: zoom, animated: true)
            case let .fit(coordinates):
                guard let first = coordinates.first else { return }
                let minLatitude = coordinates.map(\.latitude).min() ?? first.latitude
                let maxLatitude = coordinates.map(\.latitude).max() ?? first.latitude
                let minLongitude = coordinates.map(\.longitude).min() ?? first.longitude
                let maxLongitude = coordinates.map(\.longitude).max() ?? first.longitude
                let center = CLLocationCoordinate2D(
                    latitude: (minLatitude + maxLatitude) / 2,
                    longitude: (minLongitude + maxLongitude) / 2
                )
                let latitudeSpan = max(maxLatitude - minLatitude, 0.002)
                let longitudeSpan = max((maxLongitude - minLongitude) * cos(center.latitude * .pi / 180), 0.002)
                let span = max(latitudeSpan, longitudeSpan) * 1.5
                let zoom = min(17, max(3, log2(360 / span)))
                mapView.setCenter(center, zoomLevel: zoom, animated: true)
            }

            lastCameraCommandID = command.id
        }

        private func circleCoordinates(center: CLLocationCoordinate2D, radius: Double) -> [CLLocationCoordinate2D] {
            let earthRadius = 6_371_000.0
            let angularRadius = radius / earthRadius
            let latitude = center.latitude * .pi / 180
            let longitude = center.longitude * .pi / 180

            return (0...64).map { index in
                let bearing = Double(index) * 2 * .pi / 64
                let circleLatitude = asin(
                    sin(latitude) * cos(angularRadius)
                        + cos(latitude) * sin(angularRadius) * cos(bearing)
                )
                let circleLongitude = longitude + atan2(
                    sin(bearing) * sin(angularRadius) * cos(latitude),
                    cos(angularRadius) - sin(latitude) * sin(circleLatitude)
                )
                return CLLocationCoordinate2D(
                    latitude: circleLatitude * 180 / .pi,
                    longitude: circleLongitude * 180 / .pi
                )
            }
        }

        private func buildingFeature(
            at point: CGPoint,
            coordinate: CLLocationCoordinate2D,
            in mapView: MLNMapView
        ) -> MapFeatureSelection? {
            guard let style = mapView.style else { return nil }
            let buildingLayerIdentifiers = Set(style.layers.compactMap { layer -> String? in
                guard
                    let vectorLayer = layer as? MLNVectorStyleLayer,
                    vectorLayer.sourceLayerIdentifier == "building"
                else {
                    return nil
                }

                return layer.identifier
            })
            guard !buildingLayerIdentifiers.isEmpty else { return nil }

            for feature in mapView.visibleFeatures(at: point, styleLayerIdentifiers: buildingLayerIdentifiers) {
                let polygons: [MLNPolygon]
                if let polygon = feature as? MLNPolygonFeature {
                    polygons = [polygon]
                } else if let multiPolygon = feature as? MLNMultiPolygonFeature {
                    polygons = multiPolygon.polygons
                } else {
                    continue
                }

                guard
                    let selectedPolygon = polygons
                        .compactMap(mapFeaturePolygon(from:))
                        .first(where: { contains(coordinate, in: $0) })
                else {
                    continue
                }

                return MapFeatureSelection(
                    identifier: feature.identifier.map { String(describing: $0) },
                    sourceLayer: "building",
                    geometryJSON: geometryJSON(for: selectedPolygon),
                    polygons: [selectedPolygon]
                )
            }

            return nil
        }

        private func mapFeaturePolygon(from polygon: MLNPolygon) -> MapFeaturePolygon? {
            let exteriorRing = mapFeatureRing(from: polygon)
            guard exteriorRing.count >= 4 else { return nil }
            let interiorRings = (polygon.interiorPolygons ?? []).map(mapFeatureRing(from:))
            return MapFeaturePolygon(exteriorRing: exteriorRing, interiorRings: interiorRings)
        }

        private func contains(_ coordinate: CLLocationCoordinate2D, in polygon: MapFeaturePolygon) -> Bool {
            ringContains(coordinate, ring: polygon.exteriorRing)
                && !polygon.interiorRings.contains { ringContains(coordinate, ring: $0) }
        }

        private func ringContains(
            _ coordinate: CLLocationCoordinate2D,
            ring: [MapFeatureCoordinate]
        ) -> Bool {
            guard ring.count >= 3 else { return false }
            var isInside = false
            var previousIndex = ring.count - 1

            for currentIndex in ring.indices {
                let current = ring[currentIndex]
                let previous = ring[previousIndex]
                let crossesLatitude = (current.latitude > coordinate.latitude)
                    != (previous.latitude > coordinate.latitude)

                if crossesLatitude {
                    let crossingLongitude = (previous.longitude - current.longitude)
                        * (coordinate.latitude - current.latitude)
                        / (previous.latitude - current.latitude)
                        + current.longitude
                    if coordinate.longitude < crossingLongitude {
                        isInside.toggle()
                    }
                }

                previousIndex = currentIndex
            }

            return isInside
        }

        private func geometryJSON(for polygon: MapFeaturePolygon) -> String? {
            let rings = [polygon.exteriorRing] + polygon.interiorRings
            let geometry: [String: Any] = [
                "type": "Polygon",
                "coordinates": rings.map { ring in
                    ring.map { [$0.longitude, $0.latitude] }
                }
            ]
            guard
                JSONSerialization.isValidJSONObject(geometry),
                let data = try? JSONSerialization.data(withJSONObject: geometry, options: [.sortedKeys])
            else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }

        private func mapFeatureRing(from polygon: MLNPolygon) -> [MapFeatureCoordinate] {
            let count = Int(polygon.pointCount)
            guard count > 0 else { return [] }
            let coordinates = Array(UnsafeBufferPointer(start: polygon.coordinates, count: count))
            return coordinates.map {
                MapFeatureCoordinate(latitude: $0.latitude, longitude: $0.longitude)
            }
        }

        private func makePolygon(from featurePolygon: MapFeaturePolygon) -> MLNPolygon? {
            let coordinates = featurePolygon.exteriorRing.map(\.locationCoordinate)
            guard coordinates.count >= 4 else { return nil }
            let interiorPolygons = featurePolygon.interiorRings.compactMap { ring -> MLNPolygon? in
                let coordinates = ring.map(\.locationCoordinate)
                guard coordinates.count >= 4 else { return nil }
                return MLNPolygon(coordinates: coordinates, count: UInt(coordinates.count))
            }
            return MLNPolygon(
                coordinates: coordinates,
                count: UInt(coordinates.count),
                interiorPolygons: interiorPolygons
            )
        }

        private func makeOutlines(from featurePolygon: MapFeaturePolygon) -> [MLNPolyline] {
            ([featurePolygon.exteriorRing] + featurePolygon.interiorRings).compactMap { ring in
                let coordinates = ring.map(\.locationCoordinate)
                guard coordinates.count >= 2 else { return nil }
                return MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
            }
        }

        private func addHouseNumberLayer(to style: MLNStyle) {
            let layerID = "pathlog-house-numbers"
            guard
                style.layer(withIdentifier: layerID) == nil,
                let source = style.source(withIdentifier: "openmaptiles")
            else {
                return
            }

            let layer = MLNSymbolStyleLayer(identifier: layerID, source: source)
            layer.sourceLayerIdentifier = "housenumber"
            layer.minimumZoomLevel = 17
            layer.text = NSExpression(forKeyPath: "housenumber")
            layer.textFontNames = NSExpression(forConstantValue: ["Noto Sans Regular"])
            layer.textFontSize = NSExpression(forConstantValue: 11)
            layer.textColor = NSExpression(forConstantValue: UIColor.darkGray)
            layer.textHaloColor = NSExpression(forConstantValue: UIColor.white)
            layer.textHaloWidth = NSExpression(forConstantValue: 1.25)
            layer.textAllowsOverlap = NSExpression(forConstantValue: false)
            style.addLayer(layer)
        }

        private func sameCoordinate(_ lhs: CLLocationCoordinate2D?, _ rhs: CLLocationCoordinate2D?) -> Bool {
            guard let lhs, let rhs else { return lhs == nil && rhs == nil }
            return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
        }

        private func textWidth(_ text: String) -> CGFloat {
            let width = (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)]).width
            return min(max(width + 14, 52), 150)
        }
    }
}

private struct RouteStyle {
    let color: UIColor
    let width: CGFloat

    init(color: UIColor, width: CGFloat) {
        self.color = color
        self.width = width
    }

    init(appearance: PathlogMapRouteLine.Appearance) {
        switch appearance {
        case .historical:
            color = UIColor.systemGray.withAlphaComponent(0.62)
            width = 4
        case .selectedHistory:
            color = UIColor.systemOrange.withAlphaComponent(0.35)
            width = 5
        case .playback:
            color = .systemOrange
            width = 6
        case .live:
            color = .systemBlue
            width = 5
        }
    }
}

private struct ZoneStyle {
    let stroke: UIColor
    let fill: UIColor

    init(stroke: UIColor, fill: UIColor) {
        self.stroke = stroke
        self.fill = fill
    }

    init(isEnabled: Bool) {
        stroke = isEnabled ? UIColor.systemRed.withAlphaComponent(0.8) : UIColor.systemGray.withAlphaComponent(0.55)
        fill = isEnabled ? UIColor.systemRed.withAlphaComponent(0.12) : UIColor.systemGray.withAlphaComponent(0.04)
    }
}

private final class PathlogPointAnnotation: NSObject, MLNAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String? = nil
    let visual: Visual
    let label: String?
    let noteID: UUID?
    let zoneID: UUID?

    init(
        coordinate: CLLocationCoordinate2D,
        visual: Visual,
        label: String?,
        noteID: UUID? = nil,
        zoneID: UUID? = nil
    ) {
        self.coordinate = coordinate
        self.visual = visual
        self.label = label
        self.noteID = noteID
        self.zoneID = zoneID
        self.title = label
    }

    enum Visual: Equatable {
        case note
        case privateZone
        case disabledZone
        case privateGap
        case trackingGap
        case playback
        case currentLocation
        case selectedLocation

        var symbol: String {
            switch self {
            case .note: "text.bubble.fill"
            case .privateZone, .disabledZone: "lock.fill"
            case .privateGap: "lock.fill"
            case .trackingGap: "clock.fill"
            case .playback: "circle.fill"
            case .currentLocation: "location.fill"
            case .selectedLocation: "mappin.and.ellipse"
            }
        }

        var color: UIColor {
            switch self {
            case .note: .systemPurple
            case .privateZone, .privateGap: .systemRed
            case .disabledZone: .systemGray
            case .trackingGap: .systemGray
            case .playback: .systemOrange
            case .currentLocation: .systemBlue
            case .selectedLocation: .systemTeal
            }
        }

        var reuseIdentifier: String {
            switch self {
            case .note: "map-note"
            case .privateZone: "private-zone"
            case .disabledZone: "disabled-zone"
            case .privateGap: "private-gap"
            case .trackingGap: "tracking-gap"
            case .playback: "playback-position"
            case .currentLocation: "current-location"
            case .selectedLocation: "selected-map-location"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .note: "Map note"
            case .privateZone: "Private zone"
            case .disabledZone: "Disabled private zone"
            case .privateGap: "Route resumed after private zone"
            case .trackingGap: "Location recording resumed after a gap"
            case .playback: "Playback position"
            case .currentLocation: "Current location"
            case .selectedLocation: "Selected map location"
            }
        }
    }
}
