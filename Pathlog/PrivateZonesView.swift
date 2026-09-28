import CoreLocation
import SwiftUI

struct PrivateZone: Identifiable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var isEnabled: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var radiusDescription: String {
        radiusMeters == 0 ? "Off" : "\(Int(radiusMeters)) m radius"
    }

    func contains(_ location: CLLocation) -> Bool {
        guard isEnabled, radiusMeters > 0 else { return false }

        let center = CLLocation(latitude: latitude, longitude: longitude)
        let uncertainty = max(0, location.horizontalAccuracy)
        return location.distance(from: center) <= radiusMeters + uncertainty
    }

    func intersectsRouteSegment(from start: CLLocation, to end: CLLocation) -> Bool {
        guard isEnabled, radiusMeters > 0 else { return false }

        // Use a local meter plane to catch GPS samples that jump across a zone.
        let earthRadius = 6_371_000.0
        let centerLatitude = latitude * .pi / 180
        let longitudeScale = cos(centerLatitude) * earthRadius

        func offset(from coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            var longitudeDelta = coordinate.longitude - longitude
            if longitudeDelta > 180 { longitudeDelta -= 360 }
            if longitudeDelta < -180 { longitudeDelta += 360 }

            return (
                x: longitudeDelta * .pi / 180 * longitudeScale,
                y: (coordinate.latitude - latitude) * .pi / 180 * earthRadius
            )
        }

        let startOffset = offset(from: start.coordinate)
        let endOffset = offset(from: end.coordinate)
        let dx = endOffset.x - startOffset.x
        let dy = endOffset.y - startOffset.y
        let lengthSquared = dx * dx + dy * dy
        let projection: Double

        if lengthSquared == 0 {
            projection = 0
        } else {
            projection = min(
                1,
                max(0, -(startOffset.x * dx + startOffset.y * dy) / lengthSquared)
            )
        }

        let closestX = startOffset.x + projection * dx
        let closestY = startOffset.y + projection * dy
        let uncertainty = max(0, max(start.horizontalAccuracy, end.horizontalAccuracy))
        return hypot(closestX, closestY) <= radiusMeters + uncertainty
    }
}

struct PrivateZonesView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingZone = false
    @State private var zonePendingDeletion: PrivateZone?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Points inside enabled zones are not recorded. Existing route history is unchanged.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Zones") {
                    if locationManager.privateZones.isEmpty {
                        Text("No private zones yet.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(locationManager.privateZones) { zone in
                        HStack(spacing: 12) {
                            NavigationLink {
                                PrivateZoneEditorView(locationManager: locationManager, existingZone: zone)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(zone.name)
                                        .font(.body.weight(.medium))
                                    Text(zone.radiusDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Toggle(
                                "\(zone.name) enabled",
                                isOn: Binding(
                                    get: { zone.isEnabled },
                                    set: { locationManager.setPrivateZoneEnabled(zone.id, isEnabled: $0) }
                                )
                            )
                            .labelsHidden()
                            .accessibilityLabel("\(zone.name) enabled")
                            .disabled(zone.radiusMeters == 0)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                zonePendingDeletion = zone
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Private Zones")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingZone = true
                    } label: {
                        Label("Add Zone", systemImage: "plus")
                    }
                    .disabled(locationManager.privateZoneCreationCoordinate == nil)
                }
            }
            .sheet(isPresented: $isCreatingZone) {
                NavigationStack {
                    PrivateZoneEditorView(locationManager: locationManager)
                }
                .presentationDetents([.large])
            }
            .alert(
                "Delete Private Zone?",
                isPresented: Binding(
                    get: { zonePendingDeletion != nil },
                    set: { if !$0 { zonePendingDeletion = nil } }
                )
            ) {
                Button("Delete Zone", role: .destructive) {
                    if let zonePendingDeletion {
                        locationManager.deletePrivateZone(zonePendingDeletion.id)
                    }
                    zonePendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    zonePendingDeletion = nil
                }
            } message: {
                Text("Previously recorded route history will not be changed.")
            }
        }
    }
}

private struct PrivateZoneEditorView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    private let existingZone: PrivateZone?

    @State private var name: String
    @State private var radiusMeters: Double
    @State private var isEnabled: Bool
    @State private var centerCoordinate: CLLocationCoordinate2D?
    @State private var centerSource: String
    @State private var isDeleteConfirmationPresented = false

    private let radiusChoices = Array(stride(from: 0.0, through: 1_600.0, by: 200.0))

    init(locationManager: LocationManager, existingZone: PrivateZone? = nil) {
        self.locationManager = locationManager
        self.existingZone = existingZone
        _name = State(initialValue: existingZone?.name ?? "Private Zone")
        _radiusMeters = State(initialValue: existingZone?.radiusMeters ?? 200)
        _isEnabled = State(initialValue: existingZone?.isEnabled ?? true)

        let mapCenter = locationManager.mapCenterForPrivateZone
        let currentLocation = locationManager.currentLocationForPrivateZone
        _centerCoordinate = State(
            initialValue: existingZone?.coordinate ?? mapCenter ?? currentLocation
        )
        _centerSource = State(
            initialValue: existingZone != nil ? "Saved center" : (mapCenter == nil ? "Current location" : "Map center")
        )
    }

    var body: some View {
        Form {
            Section("Zone") {
                TextField("Name", text: $name)
                Toggle("Enabled", isOn: $isEnabled)
                    .disabled(radiusMeters == 0)
            }

            Section("Center") {
                LabeledContent("Source", value: centerSource)
                LabeledContent("Coordinates", value: formattedCoordinate)

                HStack {
                    Button("Map Center") {
                        selectMapCenter()
                    }
                    .disabled(locationManager.mapCenterForPrivateZone == nil)

                    Spacer()

                    Button("Current Location") {
                        selectCurrentLocation()
                    }
                    .disabled(locationManager.currentLocationForPrivateZone == nil)
                }
                .font(.subheadline)
            }

            Section("Radius") {
                Picker("Zone radius", selection: $radiusMeters) {
                    if let existingZone, !radiusChoices.contains(existingZone.radiusMeters) {
                        Text("\(existingZone.radiusDescription) (current)")
                            .tag(existingZone.radiusMeters)
                    }
                    ForEach(radiusChoices, id: \.self) { radius in
                        Text(radius == 0 ? "Off" : "\(Int(radius)) m")
                            .tag(radius)
                    }
                }
                Text(radiusMeters == 0
                    ? "Off means route points are not filtered by this zone."
                    : "Points whose GPS uncertainty overlaps the zone are also withheld.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if existingZone != nil {
                Section {
                    Button("Delete Private Zone", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                }
            }
        }
        .onChange(of: radiusMeters) { _, newRadius in
            if newRadius == 0 {
                isEnabled = false
            }
        }
        .navigationTitle(existingZone == nil ? "New Private Zone" : "Edit Private Zone")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveZone()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || centerCoordinate == nil)
            }
        }
        .confirmationDialog(
            "Delete Private Zone?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Zone", role: .destructive) {
                guard let existingZone else { return }
                locationManager.deletePrivateZone(existingZone.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Previously recorded route history will not be changed.")
        }
    }

    private var formattedCoordinate: String {
        guard let centerCoordinate else { return "Unavailable" }
        return String(format: "%.5f, %.5f", centerCoordinate.latitude, centerCoordinate.longitude)
    }

    private func selectMapCenter() {
        guard let coordinate = locationManager.mapCenterForPrivateZone else { return }
        centerCoordinate = coordinate
        centerSource = "Map center"
    }

    private func selectCurrentLocation() {
        guard let coordinate = locationManager.currentLocationForPrivateZone else { return }
        centerCoordinate = coordinate
        centerSource = "Current location"
    }

    private func saveZone() {
        guard let centerCoordinate else { return }

        let zone = PrivateZone(
            id: existingZone?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: centerCoordinate.latitude,
            longitude: centerCoordinate.longitude,
            radiusMeters: radiusMeters,
            isEnabled: isEnabled && radiusMeters > 0
        )
        locationManager.savePrivateZone(zone)
        dismiss()
    }
}

struct PrivateZoneMapEditorView: View {
    @ObservedObject var locationManager: LocationManager
    let zone: PrivateZone

    var body: some View {
        NavigationStack {
            PrivateZoneEditorView(locationManager: locationManager, existingZone: zone)
        }
    }
}

struct QuickPrivateZoneEditorView: View {
    @ObservedObject var locationManager: LocationManager
    let centerCoordinate: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Private Zone"
    @State private var radiusMeters = 200.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone") {
                    TextField("Name", text: $name)
                }

                Section("Center") {
                    LabeledContent("Selected map location", value: formattedCoordinate)
                }

                Section("Radius") {
                    LabeledContent("Zone radius", value: radiusDescription)
                    Slider(value: $radiusMeters, in: 0...1_600, step: 200)
                    Text("Off keeps the zone marker but does not withhold route points.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Private Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveZone()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var formattedCoordinate: String {
        String(format: "%.5f, %.5f", centerCoordinate.latitude, centerCoordinate.longitude)
    }

    private var radiusDescription: String {
        radiusMeters == 0 ? "Off" : "\(Int(radiusMeters)) m"
    }

    private func saveZone() {
        let zone = PrivateZone(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: centerCoordinate.latitude,
            longitude: centerCoordinate.longitude,
            radiusMeters: radiusMeters,
            isEnabled: radiusMeters > 0
        )
        locationManager.savePrivateZone(zone)
        dismiss()
    }
}
