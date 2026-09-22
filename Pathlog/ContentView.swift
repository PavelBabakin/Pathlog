//
//  ContentView.swift
//  Pathlog
//
//  Created by Pavlo Babakin on 16/09/2026.
//

import MapKit
import CoreLocation
import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $locationManager.cameraPosition) {
                if locationManager.routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: locationManager.routeCoordinates)
                        .stroke(.blue, lineWidth: 5)
                }

                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            statusPanel
        }
        .onAppear {
            locationManager.requestLocationAccess()
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pathlog")
                .font(.headline)

            Text(locationManager.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if locationManager.shouldShowPermissionButton {
                Button {
                    locationManager.requestLocationAccess()
                } label: {
                    Label("Allow Location Access", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            HStack {
                Label(
                    locationManager.trackingStateText,
                    systemImage: locationManager.isTracking ? "location.fill" : "location.slash"
                )
                .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(locationManager.collectedPointCount) points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                locationManager.toggleTracking()
            } label: {
                Label(locationManager.trackingButtonTitle, systemImage: locationManager.trackingButtonIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(locationManager.isTracking ? .red : .blue)
            .disabled(!locationManager.canTrack)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

struct RoutePoint: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    let altitude: Double
    let speed: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: kCLLocationAccuracyBest,
            timestamp: timestamp
        )
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var statusMessage = "Requesting your location..."
    @Published var shouldShowPermissionButton = false
    @Published var isTracking = false
    @Published var collectedPointCount = 0
    @Published private(set) var routePoints: [RoutePoint] = []

    var routeCoordinates: [CLLocationCoordinate2D] {
        routePoints.map { point in
            CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
    }

    var canTrack: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            true
        case .denied, .notDetermined, .restricted:
            false
        @unknown default:
            false
        }
    }

    var trackingStateText: String {
        isTracking ? "Tracking active" : "Tracking stopped"
    }

    var trackingButtonTitle: String {
        isTracking ? "Stop Tracking" : "Start Tracking"
    }

    var trackingButtonIcon: String {
        isTracking ? "stop.fill" : "play.fill"
    }

    private let manager = CLLocationManager()
    private let locationFilter = TrackingLocationFilter()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            shouldShowPermissionButton = false
            statusMessage = "Showing your current location."
            manager.startUpdatingLocation()
        case .denied, .restricted:
            shouldShowPermissionButton = true
            statusMessage = "Location access is disabled. Enable it in Settings to show your position."
        @unknown default:
            statusMessage = "Location status is unknown."
        }
    }

    func toggleTracking() {
        guard canTrack else {
            requestLocationAccess()
            return
        }

        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    private func startTracking() {
        routePoints = []
        collectedPointCount = 0
        isTracking = true
        statusMessage = "Tracking is active."
    }

    private func stopTracking() {
        isTracking = false
        statusMessage = "Tracking stopped with \(collectedPointCount) points."
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocationAccess()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        updateStatusAfterLocationUpdate()

        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )

        guard isTracking else { return }

        guard locationFilter.shouldAccept(location, after: routePoints.last) else { return }

        routePoints.append(RoutePoint(location: location))
        collectedPointCount = routePoints.count
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if !isTracking && collectedPointCount > 0 {
            return
        }

        statusMessage = "Could not get your location: \(error.localizedDescription)"
    }

    private func updateStatusAfterLocationUpdate() {
        shouldShowPermissionButton = false

        if isTracking {
            statusMessage = "Tracking is active."
        } else {
            statusMessage = "Showing your current location."
        }
    }
}

private extension RoutePoint {
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.horizontalAccuracy = location.horizontalAccuracy
        self.altitude = location.altitude
        self.speed = location.speed
    }
}

private struct TrackingLocationFilter {
    private let maximumHorizontalAccuracy: CLLocationAccuracy = 100
    private let duplicateDistanceThreshold: CLLocationDistance = 1
    private let duplicateTimeThreshold: TimeInterval = 5
    private let tooFrequentTimeThreshold: TimeInterval = 1
    private let tooFrequentDistanceThreshold: CLLocationDistance = 5
    private let maximumReasonableSpeed: CLLocationSpeed = 80

    func shouldAccept(_ location: CLLocation, after previousPoint: RoutePoint?) -> Bool {
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            return false
        }

        guard location.horizontalAccuracy >= 0 else {
            return false
        }

        guard location.horizontalAccuracy <= maximumHorizontalAccuracy else {
            return false
        }

        guard let previousPoint else {
            return true
        }

        let previousLocation = previousPoint.location
        let elapsedTime = location.timestamp.timeIntervalSince(previousPoint.timestamp)

        guard elapsedTime > 0 else {
            return false
        }

        let distance = location.distance(from: previousLocation)

        if elapsedTime < duplicateTimeThreshold && distance < duplicateDistanceThreshold {
            return false
        }

        if elapsedTime < tooFrequentTimeThreshold && distance < tooFrequentDistanceThreshold {
            return false
        }

        let calculatedSpeed = distance / elapsedTime

        if calculatedSpeed > maximumReasonableSpeed {
            return false
        }

        return true
    }
}
