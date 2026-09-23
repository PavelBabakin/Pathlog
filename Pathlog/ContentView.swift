//
//  ContentView.swift
//  Pathlog
//
//  Created by Pavlo Babakin on 16/09/2026.
//

import MapKit
import CoreLocation
import Combine
import PhotosUI
import SQLite3
import SwiftUI
import UIKit

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(\.openURL) private var openURL
    @State private var isHistoryPresented = false
    @State private var isNoteEditorPresented = false
    @State private var selectedMapNote: MapNote?

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $locationManager.cameraPosition) {
                ForEach(locationManager.mapNotes) { note in
                    Annotation(note.displayTitle, coordinate: note.coordinate) {
                        Button {
                            selectedMapNote = note
                        } label: {
                            Image(systemName: "note.text")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(.purple, in: Circle())
                        }
                    }
                }

                if locationManager.isHistoricalRoutesVisible {
                    ForEach(locationManager.historicalRouteSegments) { segment in
                        if segment.coordinates.count >= 2 {
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(.gray.opacity(0.55), lineWidth: 4)
                        }
                    }
                }

                if locationManager.selectedHistoryRouteCoordinates.count >= 2 {
                    MapPolyline(coordinates: locationManager.selectedHistoryRouteCoordinates)
                        .stroke(.orange.opacity(0.25), lineWidth: 5)
                }

                if locationManager.playbackRouteCoordinates.count >= 2 {
                    MapPolyline(coordinates: locationManager.playbackRouteCoordinates)
                        .stroke(.orange, lineWidth: 6)
                }

                if let playbackCoordinate = locationManager.playbackCoordinate {
                    Annotation("Playback", coordinate: playbackCoordinate) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                            .padding(5)
                            .background(.regularMaterial, in: Circle())
                    }
                }

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
            .onMapCameraChange { context in
                locationManager.updateMapCenter(context.region.center)
            }
            .ignoresSafeArea()

            statusPanel
        }
        .onAppear {
            locationManager.requestLocationAccess()
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(settingsURL)
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
                    if locationManager.shouldOpenLocationSettings {
                        openAppSettings()
                    } else {
                        locationManager.requestLocationAccess()
                    }
                } label: {
                    Label(
                        locationManager.shouldOpenLocationSettings ? "Open Settings" : "Allow Location Access",
                        systemImage: locationManager.shouldOpenLocationSettings ? "gearshape" : "location.fill"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if locationManager.shouldShowBackgroundPermissionButton {
                Button {
                    if locationManager.shouldOpenBackgroundSettings {
                        openAppSettings()
                    } else {
                        locationManager.requestBackgroundLocationAccess()
                    }
                } label: {
                    Label(
                        locationManager.shouldOpenBackgroundSettings ? "Open Settings" : "Allow Background Tracking",
                        systemImage: locationManager.shouldOpenBackgroundSettings ? "gearshape" : "location.circle.fill"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            HStack {
                Label(
                    "\(locationManager.historicalRouteCount) previous routes",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                )
                .font(.subheadline.weight(.medium))

                Spacer()

                Button {
                    locationManager.toggleHistoricalRoutesVisibility()
                } label: {
                    Label(
                        locationManager.isHistoricalRoutesVisible ? "Hide" : "Show",
                        systemImage: locationManager.isHistoricalRoutesVisible ? "eye.slash" : "eye"
                    )
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            if let selectedHistorySummary = locationManager.selectedHistorySummary {
                HStack {
                    Label("Selected day", systemImage: "calendar")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("\(selectedHistorySummary.pointCount) points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(selectedHistorySummary.timeRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                isHistoryPresented = true
            } label: {
                Label("History", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                isNoteEditorPresented = true
            } label: {
                Label("Add Note", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

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

            if locationManager.isTracking {
                Label(locationManager.backgroundTrackingStatusText, systemImage: "iphone.radiowaves.left.and.right")
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
        .sheet(isPresented: $isHistoryPresented) {
            HistoryView(locationManager: locationManager)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isNoteEditorPresented) {
            NoteEditorView(locationManager: locationManager)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedMapNote) { note in
            MapNoteDetailView(note: note)
                .presentationDetents([.medium])
        }
    }
}

struct HistoryView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Recorded Days") {
                    if locationManager.activeDaySummaries.isEmpty {
                        Text("No recorded days yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(locationManager.activeDaySummaries.prefix(8)) { summary in
                            Button {
                                locationManager.selectedHistoryDate = summary.date
                                locationManager.loadHistoryForSelectedDate()
                            } label: {
                                HStack {
                                    Text(summary.date, style: .date)
                                    Spacer()
                                    Text("\(summary.pointCount) points")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Date") {
                    DatePicker(
                        "Route date",
                        selection: $locationManager.selectedHistoryDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)

                    Button {
                        locationManager.loadHistoryForSelectedDate()
                    } label: {
                        Label("Show Route", systemImage: "map")
                    }
                }

                Section("Selected Route") {
                    if let selectedHistorySummary = locationManager.selectedHistorySummary {
                        LabeledContent("Points", value: "\(selectedHistorySummary.pointCount)")
                        LabeledContent("Time", value: selectedHistorySummary.timeRangeText)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Playback", systemImage: "play.circle")
                                Spacer()
                                Text(locationManager.playbackTimestampText)
                                    .foregroundStyle(.secondary)
                            }

                            Slider(
                                value: $locationManager.playbackProgress,
                                in: 0...1
                            )
                        }

                        Button(role: .destructive) {
                            locationManager.clearSelectedHistoryRoute()
                        } label: {
                            Label("Clear Selection", systemImage: "xmark.circle")
                        }
                    } else {
                        ContentUnavailableView(
                            "No Route Selected",
                            systemImage: "map",
                            description: Text("Choose a date with recorded route points.")
                        )
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NoteEditorView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var target = MapNoteTarget.mapCenter
    @State private var selectedPlace: MapPlaceCandidate?
    @State private var title = ""
    @State private var text = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    Picker("Position", selection: $target) {
                        ForEach(MapNoteTarget.allCases) { target in
                            Text(target.label).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(target.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Nearby Places") {
                    Button {
                        Task {
                            await locationManager.searchNearbyPlaces()
                        }
                    } label: {
                        Label("Find Nearby Places", systemImage: "mappin.and.ellipse")
                    }

                    if locationManager.isSearchingNearbyPlaces {
                        ProgressView("Searching...")
                    } else if locationManager.nearbyPlaceCandidates.isEmpty {
                        Text("Move the map to a place, then search nearby places.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(locationManager.nearbyPlaceCandidates) { place in
                            Button {
                                selectedPlace = place
                                target = .selectedPlace
                                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    title = place.name
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(place.name)
                                            .font(.subheadline.weight(.medium))

                                        Spacer()

                                        if selectedPlace?.id == place.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }

                                    if let subtitle = place.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Note") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 4,
                        matching: .images
                    ) {
                        Label("Choose Photos", systemImage: "photo")
                    }

                    if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count) selected")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await locationManager.createMapNote(
                                title: title,
                                text: text,
                                target: target,
                                selectedPlace: selectedPlace,
                                selectedPhotos: selectedPhotos
                            )
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct MapNoteDetailView: View {
    let note: MapNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    if !note.title.isEmpty {
                        Text(note.title)
                            .font(.headline)
                    }

                    if !note.text.isEmpty {
                        Text(note.text)
                    }
                }

                Section("Position") {
                    if let placeName = note.placeName {
                        LabeledContent("Place", value: placeName)
                    }

                    if let placeCategory = note.placeCategory {
                        LabeledContent("Category", value: placeCategory)
                    }

                    LabeledContent("Latitude", value: note.latitude.formatted(.number.precision(.fractionLength(6))))
                    LabeledContent("Longitude", value: note.longitude.formatted(.number.precision(.fractionLength(6))))
                    LabeledContent("Created", value: note.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                if !note.photoLocalPaths.isEmpty {
                    Section("Photos") {
                        LabeledContent("Attached", value: "\(note.photoLocalPaths.count)")
                    }
                }
            }
            .navigationTitle("Map Note")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

enum MapNoteTarget: String, CaseIterable, Identifiable {
    case mapCenter
    case currentLocation
    case selectedPlace

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .mapCenter:
            "Map Center"
        case .currentLocation:
            "Current Location"
        case .selectedPlace:
            "Place"
        }
    }

    var description: String {
        switch self {
        case .mapCenter:
            "Move the map so the place is centered, then save the note."
        case .currentLocation:
            "Save the note at your latest known location."
        case .selectedPlace:
            "Save the note on the selected nearby place."
        }
    }
}

struct MapPlaceCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String?
    let category: String?
    let latitude: Double
    let longitude: Double
    let identifier: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct MapNoteResolvedTarget {
    let coordinate: CLLocationCoordinate2D
    let place: MapPlaceCandidate?
}

struct RoutePoint: Identifiable {
    let id: UUID
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

struct RouteSession: Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
}

struct HistoricalRouteSegment: Identifiable {
    let id: UUID
    let coordinates: [CLLocationCoordinate2D]
}

struct MapNote: Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let title: String
    let text: String
    let placeName: String?
    let placeCategory: String?
    let placeIdentifier: String?
    let photoLocalPaths: [String]
    let createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayTitle: String {
        if !title.isEmpty {
            return title
        }

        return placeName ?? "Note"
    }
}

struct ActiveDaySummary: Identifiable {
    let date: Date
    let pointCount: Int

    var id: Date {
        date
    }
}

struct HistoryRouteSummary {
    let pointCount: Int
    let startDate: Date
    let endDate: Date

    var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var statusMessage = "Requesting your location..."
    @Published var shouldShowPermissionButton = false
    @Published var shouldShowBackgroundPermissionButton = false
    @Published var shouldOpenBackgroundSettings = false
    @Published var isTracking = false
    @Published var isHistoricalRoutesVisible = true
    @Published var selectedHistoryDate = Date()
    @Published var playbackProgress = 1.0
    @Published var collectedPointCount = 0
    @Published private(set) var routePoints: [RoutePoint] = []
    @Published private(set) var historicalRouteSegments: [HistoricalRouteSegment] = []
    @Published private(set) var selectedHistoryRoutePoints: [RoutePoint] = []
    @Published private(set) var selectedHistorySummary: HistoryRouteSummary?
    @Published private(set) var activeDaySummaries: [ActiveDaySummary] = []
    @Published private(set) var mapNotes: [MapNote] = []
    @Published private(set) var nearbyPlaceCandidates: [MapPlaceCandidate] = []
    @Published private(set) var isSearchingNearbyPlaces = false

    var routeCoordinates: [CLLocationCoordinate2D] {
        routePoints.map(\.coordinate)
    }

    var selectedHistoryRouteCoordinates: [CLLocationCoordinate2D] {
        selectedHistoryRoutePoints.map(\.coordinate)
    }

    var playbackPointIndex: Int? {
        guard !selectedHistoryRoutePoints.isEmpty else {
            return nil
        }

        let lastIndex = selectedHistoryRoutePoints.count - 1
        return min(max(Int((Double(lastIndex) * playbackProgress).rounded()), 0), lastIndex)
    }

    var playbackRouteCoordinates: [CLLocationCoordinate2D] {
        guard let playbackPointIndex else {
            return []
        }

        return selectedHistoryRoutePoints.prefix(playbackPointIndex + 1).map(\.coordinate)
    }

    var playbackCoordinate: CLLocationCoordinate2D? {
        guard let playbackPointIndex else {
            return nil
        }

        return selectedHistoryRoutePoints[playbackPointIndex].coordinate
    }

    var playbackTimestampText: String {
        guard let playbackPointIndex else {
            return "--"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none

        return formatter.string(from: selectedHistoryRoutePoints[playbackPointIndex].timestamp)
    }

    var historicalRouteCount: Int {
        historicalRouteSegments.count
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

    var shouldOpenLocationSettings: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
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

    var backgroundTrackingStatusText: String {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            "Background tracking enabled"
        case .authorizedWhenInUse:
            "Tracking works while Pathlog is open"
        case .denied, .notDetermined, .restricted:
            "Background tracking unavailable"
        @unknown default:
            "Background tracking status unknown"
        }
    }

    private let manager = CLLocationManager()
    private let locationFilter = TrackingLocationFilter()
    private let routeHistoryStore = RouteHistoryStore()
    private var latestKnownCoordinate: CLLocationCoordinate2D?
    private var mapCenterCoordinate: CLLocationCoordinate2D?
    private var activeSessionID: UUID?
    private var activeSessionStartedAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        reloadHistoricalRouteSegments()
        reloadActiveDaySummaries()
        reloadMapNotes()
    }

    func requestLocationAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            shouldShowPermissionButton = false
            shouldShowBackgroundPermissionButton = true
            statusMessage = "Showing your current location. Allow background tracking to keep recording after leaving the app."
            manager.startUpdatingLocation()
        case .authorizedAlways:
            shouldShowPermissionButton = false
            shouldShowBackgroundPermissionButton = false
            statusMessage = "Showing your current location."
            manager.startUpdatingLocation()
        case .denied, .restricted:
            shouldShowPermissionButton = true
            shouldShowBackgroundPermissionButton = false
            statusMessage = "Location access is disabled. Enable it in Settings to show your position."
        @unknown default:
            statusMessage = "Location status is unknown."
        }
    }

    func requestBackgroundLocationAccess() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            shouldOpenBackgroundSettings = true
            statusMessage = "Requesting background tracking access."
        case .authorizedAlways:
            shouldShowBackgroundPermissionButton = false
            shouldOpenBackgroundSettings = false
            statusMessage = "Background tracking is enabled."
        case .notDetermined:
            requestLocationAccess()
        case .denied, .restricted:
            shouldShowPermissionButton = true
            statusMessage = "Location access is disabled. Enable Always access in Settings for background tracking."
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

    func toggleHistoricalRoutesVisibility() {
        isHistoricalRoutesVisible.toggle()
    }

    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        mapCenterCoordinate = coordinate
    }

    @MainActor
    func createMapNote(
        title: String,
        text: String,
        target: MapNoteTarget,
        selectedPlace: MapPlaceCandidate?,
        selectedPhotos: [PhotosPickerItem]
    ) async {
        guard let noteTarget = noteTarget(for: target, selectedPlace: selectedPlace) else {
            statusMessage = "Could not create note because the selected position is unavailable."
            return
        }

        let photoPaths = await routeHistoryStore.saveNotePhotos(selectedPhotos)
        let note = MapNote(
            id: UUID(),
            latitude: noteTarget.coordinate.latitude,
            longitude: noteTarget.coordinate.longitude,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            placeName: noteTarget.place?.name,
            placeCategory: noteTarget.place?.category,
            placeIdentifier: noteTarget.place?.identifier,
            photoLocalPaths: photoPaths,
            createdAt: Date()
        )

        routeHistoryStore.createMapNote(note)
        reloadMapNotes()
        statusMessage = "Saved map note."
    }

    @MainActor
    func searchNearbyPlaces() async {
        guard let center = mapCenterCoordinate ?? latestKnownCoordinate else {
            statusMessage = "Move the map to the place you want to search."
            return
        }

        isSearchingNearbyPlaces = true
        defer {
            isSearchingNearbyPlaces = false
        }

        let request = MKLocalPointsOfInterestRequest(center: center, radius: 250)
        request.pointOfInterestFilter = .includingAll

        do {
            let response = try await MKLocalSearch(request: request).start()
            nearbyPlaceCandidates = response.mapItems
                .filter { CLLocationCoordinate2DIsValid($0.location.coordinate) }
                .prefix(12)
                .enumerated()
                .map { index, mapItem in
                    let coordinate = mapItem.location.coordinate

                    return MapPlaceCandidate(
                        id: mapItem.identifier?.rawValue ?? "\(mapItem.name ?? "Place")-\(index)-\(coordinate.latitude)-\(coordinate.longitude)",
                        name: mapItem.name ?? "Unnamed Place",
                        subtitle: mapItem.address?.shortAddress,
                        category: mapItem.pointOfInterestCategory?.rawValue,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        identifier: mapItem.identifier?.rawValue
                    )
                }
            statusMessage = nearbyPlaceCandidates.isEmpty ? "No nearby places found." : "Found \(nearbyPlaceCandidates.count) nearby places."
        } catch {
            statusMessage = "Could not search nearby places: \(error.localizedDescription)"
        }
    }

    func loadHistoryForSelectedDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedHistoryDate)

        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        let points = routeHistoryStore.loadPoints(from: startOfDay, to: endOfDay)
        selectedHistoryRoutePoints = points
        playbackProgress = 1

        if let firstPoint = points.first, let lastPoint = points.last {
            selectedHistorySummary = HistoryRouteSummary(
                pointCount: points.count,
                startDate: firstPoint.timestamp,
                endDate: lastPoint.timestamp
            )
            focusCamera(on: points)
            statusMessage = "Loaded \(points.count) points for the selected day."
        } else {
            selectedHistorySummary = nil
            statusMessage = "No route history found for the selected day."
        }
    }

    func clearSelectedHistoryRoute() {
        selectedHistoryRoutePoints = []
        selectedHistorySummary = nil
        playbackProgress = 1
    }

    private func startTracking() {
        if manager.authorizationStatus == .authorizedWhenInUse {
            requestBackgroundLocationAccess()
        }

        let session = RouteSession(id: UUID(), startedAt: Date(), endedAt: nil)
        routeHistoryStore.createSession(session)
        activeSessionID = session.id
        activeSessionStartedAt = session.startedAt
        routePoints = []
        collectedPointCount = 0
        isTracking = true
        configureBackgroundTracking()
        manager.startUpdatingLocation()
        statusMessage = manager.authorizationStatus == .authorizedAlways
            ? "Tracking is active, including in the background."
            : "Tracking is active while Pathlog remains open."
    }

    private func stopTracking() {
        isTracking = false
        configureBackgroundTracking()
        if let activeSessionID {
            routeHistoryStore.finishSession(id: activeSessionID, endedAt: Date())
        }
        activeSessionID = nil
        activeSessionStartedAt = nil
        reloadHistoricalRouteSegments()
        reloadActiveDaySummaries()
        routePoints = []
        statusMessage = "Tracking stopped with \(collectedPointCount) points."
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocationAccess()
        if manager.authorizationStatus == .authorizedAlways {
            shouldOpenBackgroundSettings = false
        }
        configureBackgroundTracking()
        if isTracking {
            updateStatusAfterLocationUpdate()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latestKnownCoordinate = location.coordinate

        updateStatusAfterLocationUpdate()

        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )

        guard isTracking else { return }

        guard locationFilter.shouldAccept(location, after: routePoints.last) else { return }

        let routePoint = RoutePoint(location: location)
        routePoints.append(routePoint)
        collectedPointCount = routePoints.count

        if let activeSessionID {
            routeHistoryStore.insertPoint(routePoint, sessionID: activeSessionID)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if !isTracking && collectedPointCount > 0 {
            return
        }

        statusMessage = "Could not get your location: \(error.localizedDescription)"
    }

    private func updateStatusAfterLocationUpdate() {
        shouldShowPermissionButton = false
        shouldShowBackgroundPermissionButton = manager.authorizationStatus == .authorizedWhenInUse

        if isTracking {
            statusMessage = manager.authorizationStatus == .authorizedAlways
                ? "Tracking is active, including in the background."
                : "Tracking is active while Pathlog remains open."
        } else {
            statusMessage = "Showing your current location."
        }
    }

    private func configureBackgroundTracking() {
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = isTracking && manager.authorizationStatus == .authorizedAlways
        manager.showsBackgroundLocationIndicator = isTracking && manager.authorizationStatus == .authorizedAlways
    }

    private func reloadHistoricalRouteSegments() {
        historicalRouteSegments = routeHistoryStore.loadHistoricalRouteSegments()
    }

    private func reloadActiveDaySummaries() {
        activeDaySummaries = routeHistoryStore.loadActiveDaySummaries()
    }

    private func reloadMapNotes() {
        mapNotes = routeHistoryStore.loadMapNotes()
    }

    private func noteTarget(for target: MapNoteTarget, selectedPlace: MapPlaceCandidate?) -> MapNoteResolvedTarget? {
        switch target {
        case .mapCenter:
            return (mapCenterCoordinate ?? latestKnownCoordinate).map {
                MapNoteResolvedTarget(coordinate: $0, place: nil)
            }
        case .currentLocation:
            return latestKnownCoordinate.map {
                MapNoteResolvedTarget(coordinate: $0, place: nil)
            }
        case .selectedPlace:
            guard let selectedPlace else {
                return nil
            }

            return MapNoteResolvedTarget(coordinate: selectedPlace.coordinate, place: selectedPlace)
        }
    }

    private func focusCamera(on points: [RoutePoint]) {
        let coordinates = points.map(\.coordinate)

        guard let firstCoordinate = coordinates.first else {
            return
        }

        let latitudeValues = coordinates.map(\.latitude)
        let longitudeValues = coordinates.map(\.longitude)
        let minimumLatitude = latitudeValues.min() ?? firstCoordinate.latitude
        let maximumLatitude = latitudeValues.max() ?? firstCoordinate.latitude
        let minimumLongitude = longitudeValues.min() ?? firstCoordinate.longitude
        let maximumLongitude = longitudeValues.max() ?? firstCoordinate.longitude
        let center = CLLocationCoordinate2D(
            latitude: (minimumLatitude + maximumLatitude) / 2,
            longitude: (minimumLongitude + maximumLongitude) / 2
        )
        let latitudeDelta = max((maximumLatitude - minimumLatitude) * 1.4, 0.005)
        let longitudeDelta = max((maximumLongitude - minimumLongitude) * 1.4, 0.005)

        cameraPosition = .region(
            MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: latitudeDelta,
                    longitudeDelta: longitudeDelta
                )
            )
        )
    }
}

private extension RoutePoint {
    init(location: CLLocation) {
        self.id = UUID()
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

private final class RouteHistoryStore {
    private let historicalLookbackDays: TimeInterval = 90
    private let historicalPointLimit: Int32 = 10_000
    private let fileManager: FileManager
    private var database: OpaquePointer?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        openDatabase()
        createTables()
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func createSession(_ session: RouteSession) {
        let sql = """
            INSERT INTO route_sessions (id, started_at, ended_at)
            VALUES (?, ?, ?);
            """

        withPreparedStatement(sql) { statement in
            bind(session.id.uuidString, to: statement, at: 1)
            bind(session.startedAt.timeIntervalSince1970, to: statement, at: 2)
            sqlite3_bind_null(statement, 3)
            step(statement)
        }
    }

    func finishSession(id: UUID, endedAt: Date) {
        let sql = """
            UPDATE route_sessions
            SET ended_at = ?
            WHERE id = ?;
            """

        withPreparedStatement(sql) { statement in
            bind(endedAt.timeIntervalSince1970, to: statement, at: 1)
            bind(id.uuidString, to: statement, at: 2)
            step(statement)
        }
    }

    func insertPoint(_ point: RoutePoint, sessionID: UUID) {
        let sql = """
            INSERT INTO route_points (
                id,
                session_id,
                latitude,
                longitude,
                timestamp,
                horizontal_accuracy,
                altitude,
                speed
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """

        withPreparedStatement(sql) { statement in
            bind(point.id.uuidString, to: statement, at: 1)
            bind(sessionID.uuidString, to: statement, at: 2)
            bind(point.latitude, to: statement, at: 3)
            bind(point.longitude, to: statement, at: 4)
            bind(point.timestamp.timeIntervalSince1970, to: statement, at: 5)
            bind(point.horizontalAccuracy, to: statement, at: 6)
            bind(point.altitude, to: statement, at: 7)
            bind(point.speed, to: statement, at: 8)
            step(statement)
        }
    }

    func loadPoints(from startDate: Date, to endDate: Date) -> [RoutePoint] {
        let sql = """
            SELECT
                route_points.id,
                route_points.latitude,
                route_points.longitude,
                route_points.timestamp,
                route_points.horizontal_accuracy,
                route_points.altitude,
                route_points.speed
            FROM route_points
            INNER JOIN route_sessions ON route_sessions.id = route_points.session_id
            WHERE route_points.timestamp >= ? AND route_points.timestamp <= ?
                AND route_sessions.ended_at IS NOT NULL
            ORDER BY route_points.timestamp ASC;
            """
        var points: [RoutePoint] = []

        withPreparedStatement(sql) { statement in
            bind(startDate.timeIntervalSince1970, to: statement, at: 1)
            bind(endDate.timeIntervalSince1970, to: statement, at: 2)

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = stringValue(from: statement, at: 0).flatMap(UUID.init(uuidString:)) else {
                    continue
                }

                points.append(
                    RoutePoint(
                        id: id,
                        latitude: sqlite3_column_double(statement, 1),
                        longitude: sqlite3_column_double(statement, 2),
                        timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                        horizontalAccuracy: sqlite3_column_double(statement, 4),
                        altitude: sqlite3_column_double(statement, 5),
                        speed: sqlite3_column_double(statement, 6)
                    )
                )
            }
        }

        return points
    }

    func loadHistoricalRouteSegments() -> [HistoricalRouteSegment] {
        let earliestTimestamp = Date()
            .addingTimeInterval(-historicalLookbackDays * 24 * 60 * 60)
            .timeIntervalSince1970
        let sql = """
            SELECT
                s.id,
                p.latitude,
                p.longitude
            FROM route_sessions s
            INNER JOIN route_points p ON p.session_id = s.id
            WHERE s.ended_at IS NOT NULL AND p.timestamp >= ?
            ORDER BY s.started_at ASC, p.timestamp ASC
            LIMIT ?;
            """
        var segments: [HistoricalRouteSegmentBuilder] = []
        var segmentIndexesByID: [UUID: Int] = [:]

        withPreparedStatement(sql) { statement in
            bind(earliestTimestamp, to: statement, at: 1)
            bind(historicalPointLimit, to: statement, at: 2)

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let sessionID = stringValue(from: statement, at: 0).flatMap(UUID.init(uuidString:)) else {
                    continue
                }

                let coordinate = CLLocationCoordinate2D(
                    latitude: sqlite3_column_double(statement, 1),
                    longitude: sqlite3_column_double(statement, 2)
                )

                if let segmentIndex = segmentIndexesByID[sessionID] {
                    segments[segmentIndex].coordinates.append(coordinate)
                } else {
                    segmentIndexesByID[sessionID] = segments.count
                    segments.append(
                        HistoricalRouteSegmentBuilder(
                            id: sessionID,
                            coordinates: [coordinate]
                        )
                    )
                }
            }
        }

        return segments
            .filter { $0.coordinates.count >= 2 }
            .map { HistoricalRouteSegment(id: $0.id, coordinates: $0.coordinates) }
    }

    func loadActiveDaySummaries() -> [ActiveDaySummary] {
        let sql = """
            SELECT
                CAST(strftime('%s', date(route_points.timestamp, 'unixepoch', 'localtime')) AS REAL),
                COUNT(route_points.id)
            FROM route_points
            INNER JOIN route_sessions ON route_sessions.id = route_points.session_id
            WHERE route_sessions.ended_at IS NOT NULL
            GROUP BY date(route_points.timestamp, 'unixepoch', 'localtime')
            ORDER BY route_points.timestamp DESC
            LIMIT 30;
            """
        var summaries: [ActiveDaySummary] = []

        withPreparedStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                summaries.append(
                    ActiveDaySummary(
                        date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 0)),
                        pointCount: Int(sqlite3_column_int(statement, 1))
                    )
                )
            }
        }

        return summaries
    }

    func createMapNote(_ note: MapNote) {
        let sql = """
            INSERT INTO map_notes (
                id,
                latitude,
                longitude,
                title,
                text,
                place_name,
                place_category,
                place_identifier,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        withPreparedStatement(sql) { statement in
            bind(note.id.uuidString, to: statement, at: 1)
            bind(note.latitude, to: statement, at: 2)
            bind(note.longitude, to: statement, at: 3)
            bind(note.title, to: statement, at: 4)
            bind(note.text, to: statement, at: 5)
            bind(note.placeName, to: statement, at: 6)
            bind(note.placeCategory, to: statement, at: 7)
            bind(note.placeIdentifier, to: statement, at: 8)
            bind(note.createdAt.timeIntervalSince1970, to: statement, at: 9)
            step(statement)
        }

        for path in note.photoLocalPaths {
            createMapNotePhoto(noteID: note.id, localPath: path)
        }
    }

    func loadMapNotes() -> [MapNote] {
        let sql = """
            SELECT
                id,
                latitude,
                longitude,
                title,
                text,
                place_name,
                place_category,
                place_identifier,
                created_at
            FROM map_notes
            ORDER BY created_at DESC;
            """
        var notes: [MapNote] = []

        withPreparedStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = stringValue(from: statement, at: 0).flatMap(UUID.init(uuidString:)) else {
                    continue
                }

                notes.append(
                    MapNote(
                        id: id,
                        latitude: sqlite3_column_double(statement, 1),
                        longitude: sqlite3_column_double(statement, 2),
                        title: stringValue(from: statement, at: 3) ?? "",
                        text: stringValue(from: statement, at: 4) ?? "",
                        placeName: stringValue(from: statement, at: 5),
                        placeCategory: stringValue(from: statement, at: 6),
                        placeIdentifier: stringValue(from: statement, at: 7),
                        photoLocalPaths: loadPhotoPaths(for: id),
                        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
                    )
                )
            }
        }

        return notes
    }

    func saveNotePhotos(_ selectedPhotos: [PhotosPickerItem]) async -> [String] {
        var paths: [String] = []

        for selectedPhoto in selectedPhotos {
            guard let data = try? await selectedPhoto.loadTransferable(type: Data.self) else {
                continue
            }

            do {
                let photoURL = try writeNotePhotoData(data)
                paths.append(photoURL.path)
            } catch {
                assertionFailure("Failed to save note photo: \(error.localizedDescription)")
            }
        }

        return paths
    }

    private func openDatabase() {
        do {
            let databaseURL = routeHistoryDatabaseURL()
            try fileManager.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
                assertionFailure("Failed to open Pathlog database.")
            }
        } catch {
            assertionFailure("Failed to prepare Pathlog database directory: \(error.localizedDescription)")
        }
    }

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS route_sessions (
                id TEXT PRIMARY KEY NOT NULL,
                started_at REAL NOT NULL,
                ended_at REAL
            );
            """)

        execute("""
            CREATE TABLE IF NOT EXISTS route_points (
                id TEXT PRIMARY KEY NOT NULL,
                session_id TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                timestamp REAL NOT NULL,
                horizontal_accuracy REAL NOT NULL,
                altitude REAL NOT NULL,
                speed REAL NOT NULL,
                FOREIGN KEY(session_id) REFERENCES route_sessions(id) ON DELETE CASCADE
            );
            """)

        execute("""
            CREATE INDEX IF NOT EXISTS idx_route_points_session_timestamp
            ON route_points(session_id, timestamp);
            """)

        execute("""
            CREATE INDEX IF NOT EXISTS idx_route_points_timestamp
            ON route_points(timestamp);
            """)

        execute("""
            CREATE TABLE IF NOT EXISTS map_notes (
                id TEXT PRIMARY KEY NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                title TEXT NOT NULL,
                text TEXT NOT NULL,
                place_name TEXT,
                place_category TEXT,
                place_identifier TEXT,
                created_at REAL NOT NULL
            );
            """)

        addColumnIfNeeded(
            table: "map_notes",
            column: "place_name",
            definition: "TEXT"
        )
        addColumnIfNeeded(
            table: "map_notes",
            column: "place_category",
            definition: "TEXT"
        )
        addColumnIfNeeded(
            table: "map_notes",
            column: "place_identifier",
            definition: "TEXT"
        )

        execute("""
            CREATE TABLE IF NOT EXISTS map_note_photos (
                id TEXT PRIMARY KEY NOT NULL,
                note_id TEXT NOT NULL,
                local_path TEXT NOT NULL,
                FOREIGN KEY(note_id) REFERENCES map_notes(id) ON DELETE CASCADE
            );
            """)

        execute("""
            CREATE INDEX IF NOT EXISTS idx_map_notes_created_at
            ON map_notes(created_at);
            """)
    }

    private func execute(_ sql: String) {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            assertionFailure("SQLite execution failed: \(lastDatabaseErrorMessage)")
            return
        }
    }

    private func withPreparedStatement(_ sql: String, body: (OpaquePointer?) -> Void) {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            assertionFailure("SQLite prepare failed: \(lastDatabaseErrorMessage)")
            return
        }

        defer {
            sqlite3_finalize(statement)
        }

        body(statement)
    }

    private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func bind(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ value: Double, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_double(statement, index, value)
    }

    private func bind(_ value: Int32, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_int(statement, index, value)
    }

    private func step(_ statement: OpaquePointer?) {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            assertionFailure("SQLite step failed: \(lastDatabaseErrorMessage)")
            return
        }
    }

    private func stringValue(from statement: OpaquePointer?, at index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: text)
    }

    private func addColumnIfNeeded(table: String, column: String, definition: String) {
        guard !tableColumnNames(table: table).contains(column) else {
            return
        }

        execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
    }

    private func tableColumnNames(table: String) -> Set<String> {
        let sql = "PRAGMA table_info(\(table));"
        var names = Set<String>()

        withPreparedStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                if let name = stringValue(from: statement, at: 1) {
                    names.insert(name)
                }
            }
        }

        return names
    }

    private func createMapNotePhoto(noteID: UUID, localPath: String) {
        let sql = """
            INSERT INTO map_note_photos (id, note_id, local_path)
            VALUES (?, ?, ?);
            """

        withPreparedStatement(sql) { statement in
            bind(UUID().uuidString, to: statement, at: 1)
            bind(noteID.uuidString, to: statement, at: 2)
            bind(localPath, to: statement, at: 3)
            step(statement)
        }
    }

    private func loadPhotoPaths(for noteID: UUID) -> [String] {
        let sql = """
            SELECT local_path
            FROM map_note_photos
            WHERE note_id = ?
            ORDER BY local_path ASC;
            """
        var paths: [String] = []

        withPreparedStatement(sql) { statement in
            bind(noteID.uuidString, to: statement, at: 1)

            while sqlite3_step(statement) == SQLITE_ROW {
                if let path = stringValue(from: statement, at: 0) {
                    paths.append(path)
                }
            }
        }

        return paths
    }

    private func writeNotePhotoData(_ data: Data) throws -> URL {
        let directoryURL = applicationSupportPathlogURL()
            .appendingPathComponent("NotePhotos", isDirectory: true)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: fileURL, options: [.atomic])

        return fileURL
    }

    private var lastDatabaseErrorMessage: String {
        guard let errorPointer = sqlite3_errmsg(database) else {
            return "Unknown SQLite error."
        }

        return String(cString: errorPointer)
    }

    private func routeHistoryDatabaseURL() -> URL {
        applicationSupportPathlogURL()
            .appendingPathComponent("pathlog.sqlite")
    }

    private func applicationSupportPathlogURL() -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupportURL
            .appendingPathComponent("Pathlog", isDirectory: true)
    }
}

private struct HistoricalRouteSegmentBuilder {
    let id: UUID
    var coordinates: [CLLocationCoordinate2D]
}
