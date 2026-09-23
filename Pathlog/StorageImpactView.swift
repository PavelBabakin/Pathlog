import SwiftUI

struct LocalStorageSummary {
    let totalBytes: Int64
    let databaseBytes: Int64
    let photoBytes: Int64
    let otherBytes: Int64
    let sessionCount: Int
    let routePointCount: Int
    let noteCount: Int
    let photoCount: Int

    func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct TrackingActivitySummary {
    let startedAt: Date
    let endedAt: Date?
    let trackingDuration: TimeInterval
    let backgroundDuration: TimeInterval
    let locationUpdateCount: Int
    let savedPointCount: Int
}

struct StorageImpactView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Local Storage") {
                    if let summary = locationManager.storageUsageSummary {
                        LabeledContent("Pathlog data", value: summary.formattedSize(summary.totalBytes))
                        LabeledContent("Routes and notes database", value: summary.formattedSize(summary.databaseBytes))
                        LabeledContent("Photos", value: summary.formattedSize(summary.photoBytes))

                        if summary.otherBytes > 0 {
                            LabeledContent("Other local files", value: summary.formattedSize(summary.otherBytes))
                        }

                        Text("The database size includes route history and map notes. The app download size is not included.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                    }
                }

                Section("Stored Items") {
                    if let summary = locationManager.storageUsageSummary {
                        LabeledContent("Route sessions", value: "\(summary.sessionCount)")
                        LabeledContent("Route points", value: "\(summary.routePointCount)")
                        LabeledContent("Map notes", value: "\(summary.noteCount)")
                        LabeledContent("Photos", value: "\(summary.photoCount)")
                    } else {
                        Text("Loading stored items...")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Recent Tracking") {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        if let summary = locationManager.trackingActivitySummary(at: timeline.date) {
                            LabeledContent(
                                locationManager.isTracking ? "Current session" : "Last session",
                                value: summary.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "In progress"
                            )
                            LabeledContent("Tracking time", value: formattedDuration(summary.trackingDuration))
                            LabeledContent("Background time", value: formattedDuration(summary.backgroundDuration))
                            LabeledContent("Location updates", value: "\(summary.locationUpdateCount)")
                            LabeledContent("Saved route points", value: "\(summary.savedPointCount)")
                        } else {
                            Text("No tracking sessions yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Location accuracy", value: "Best available")
                    Text("Accuracy mode is fixed to best available in this version.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Battery") {
                    Text("Long sessions, frequent location updates, and background tracking can increase battery use.")
                    Text("This is a tracking activity summary, not an exact battery reading. For Apple's per-app report, open Settings > Battery.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Storage & Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                locationManager.refreshStorageAndImpact()
            }
            .onAppear {
                locationManager.refreshStorageAndImpact()
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        }

        return "\(minutes) min"
    }
}
