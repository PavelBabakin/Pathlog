# Pathlog

Pathlog is a private iOS app for recording movement history locally on the device. It shows the user's current location on a map and is being built toward continuous route tracking, local history playback, and private zones where location points are not saved.

## Current Status

- Native iOS app built with SwiftUI.
- MapLibre Native displays the OpenFreeMap Liberty map style.
- Location permission is requested.
- The user's current location is shown on the map.
- Basic Start Tracking / Stop Tracking UI is implemented.
- GPS tracking and route history remain stored locally and are independent of map tile availability.

The map style URL is configured with `PathlogMapStyleURL` in `Pathlog-Info.plist`. The configured style supplies its vector-tile, glyph, and sprite endpoints, so a compatible self-hosted OpenFreeMap style can replace the public style without changing GPS or storage code.

## Product Direction

Pathlog is designed to be privacy-first:

- location history is local by default;
- no account or backend is required for the initial version;
- the user controls when tracking starts and stops;
- private zones will prevent sensitive locations from being stored.

## Documentation

- [Project Description](docs/PROJECT_DESCRIPTION.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
