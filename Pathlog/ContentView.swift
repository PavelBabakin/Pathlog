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
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var statusMessage = "Requesting your location..."
    @Published var shouldShowPermissionButton = false
    @Published var isTracking = false
    @Published var collectedPointCount = 0
    @Published private(set) var routePoints: [RoutePoint] = []

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

        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )

        guard isTracking else { return }

        let routePoint = RoutePoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            speed: location.speed
        )

        routePoints.append(routePoint)
        collectedPointCount = routePoints.count
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusMessage = "Could not get your location: \(error.localizedDescription)"
    }
}
