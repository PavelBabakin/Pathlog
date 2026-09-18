# Pathlog

Pathlog is a private iOS app for recording movement history locally on the device. It shows the user's current location on a map and is being built toward continuous route tracking, local history playback, and private zones where location points are not saved.

## Current Status

- Native iOS app built with SwiftUI.
- MapKit map is displayed on launch.
- Location permission is requested.
- The user's current location is shown on the map.
- Basic Start Tracking / Stop Tracking UI is implemented.

## Product Direction

Pathlog is designed to be privacy-first:

- location history is local by default;
- no account or backend is required for the initial version;
- the user controls when tracking starts and stops;
- private zones will prevent sensitive locations from being stored.

## Documentation

- [Project Description](docs/PROJECT_DESCRIPTION.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
