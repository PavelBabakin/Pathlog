//
//  ContentView.swift
//  Pathlog
//
//  Created by Pavlo Babakin on 16/09/2026.
//

import MapKit
import CoreLocation
import Combine
import SQLite3
import SwiftUI

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var isHistoryPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $locationManager.cameraPosition) {
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
                        .stroke(.orange, lineWidth: 6)
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
        .sheet(isPresented: $isHistoryPresented) {
            HistoryView(locationManager: locationManager)
                .presentationDetents([.medium, .large])
        }
    }
}

struct HistoryView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
    @Published var isTracking = false
    @Published var isHistoricalRoutesVisible = true
    @Published var selectedHistoryDate = Date()
    @Published var collectedPointCount = 0
    @Published private(set) var routePoints: [RoutePoint] = []
    @Published private(set) var historicalRouteSegments: [HistoricalRouteSegment] = []
    @Published private(set) var selectedHistoryRoutePoints: [RoutePoint] = []
    @Published private(set) var selectedHistorySummary: HistoryRouteSummary?

    var routeCoordinates: [CLLocationCoordinate2D] {
        routePoints.map(\.coordinate)
    }

    var selectedHistoryRouteCoordinates: [CLLocationCoordinate2D] {
        selectedHistoryRoutePoints.map(\.coordinate)
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
    private let routeHistoryStore = RouteHistoryStore()
    private var activeSessionID: UUID?
    private var activeSessionStartedAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        reloadHistoricalRouteSegments()
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

    func toggleHistoricalRoutesVisibility() {
        isHistoricalRoutesVisible.toggle()
    }

    func loadHistoryForSelectedDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedHistoryDate)

        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        let points = routeHistoryStore.loadPoints(from: startOfDay, to: endOfDay)
        selectedHistoryRoutePoints = points

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
    }

    private func startTracking() {
        let session = RouteSession(id: UUID(), startedAt: Date(), endedAt: nil)
        routeHistoryStore.createSession(session)
        activeSessionID = session.id
        activeSessionStartedAt = session.startedAt
        routePoints = []
        collectedPointCount = 0
        isTracking = true
        statusMessage = "Tracking is active."
    }

    private func stopTracking() {
        isTracking = false
        if let activeSessionID {
            routeHistoryStore.finishSession(id: activeSessionID, endedAt: Date())
        }
        activeSessionID = nil
        activeSessionStartedAt = nil
        reloadHistoricalRouteSegments()
        routePoints = []
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

        if isTracking {
            statusMessage = "Tracking is active."
        } else {
            statusMessage = "Showing your current location."
        }
    }

    private func reloadHistoricalRouteSegments() {
        historicalRouteSegments = routeHistoryStore.loadHistoricalRouteSegments()
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

    private var lastDatabaseErrorMessage: String {
        guard let errorPointer = sqlite3_errmsg(database) else {
            return "Unknown SQLite error."
        }

        return String(cString: errorPointer)
    }

    private func routeHistoryDatabaseURL() -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupportURL
            .appendingPathComponent("Pathlog", isDirectory: true)
            .appendingPathComponent("pathlog.sqlite")
    }
}

private struct HistoricalRouteSegmentBuilder {
    let id: UUID
    var coordinates: [CLLocationCoordinate2D]
}
