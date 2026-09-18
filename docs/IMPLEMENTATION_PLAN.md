# Pathlog: Implementation Plan

## Current Status

The project currently has the first milestone implemented:

- the app opens to a map;
- the app requests location access;
- the app shows the user's current location;
- the project builds successfully.

## Implementation Phases

### 1. Tracking Session UI

Add the basic controls needed to start and stop tracking.

Scope:

- add a Start Tracking / Stop Tracking button;
- show whether tracking is active;
- show a basic count of collected route points;
- keep the UI visible and understandable on top of the map.

Done when:

- the user can start tracking;
- the user can stop tracking;
- the UI clearly reflects the current tracking state.

### 2. In-Memory Route Recording

Record route points while tracking is active, without local persistence yet.

Scope:

- collect location updates only while tracking is active;
- store route points in memory;
- include latitude, longitude, timestamp, accuracy, altitude, and speed;
- ignore location updates while tracking is stopped.

Done when:

- moving in the simulator or on a device adds points while tracking is active;
- stopping tracking prevents new points from being added;
- the app can show how many points were collected.

### 3. Route Line on the Map

Draw the collected route as a visible line on the map.

Scope:

- convert collected route points into map coordinates;
- render the route as a polyline;
- update the line as new points arrive;
- keep the current user location visible.

Done when:

- a visible route line appears after tracking starts;
- the line grows as new valid points arrive;
- stopping tracking keeps the existing line visible.

### 4. Basic Location Filtering

Avoid storing obviously bad or noisy route points.

Scope:

- ignore points with poor horizontal accuracy;
- avoid duplicate or near-duplicate points;
- avoid points that arrive too frequently to be useful;
- keep the rules simple and adjustable.

Done when:

- collected routes are reasonably clean;
- point count does not grow from duplicate stationary updates;
- filtering rules are easy to revise later.

### 5. Local Persistence

Store route history locally on the device.

Scope:

- choose the local storage approach;
- persist route points;
- load stored route points after app restart;
- support large histories over time.

Preferred direction:

- evaluate SQLite for long-term route history because the app may store many location points;
- keep SwiftData as an option if it remains simple and performs well enough.

Done when:

- route points survive app restarts;
- the app can load previous history;
- storage is structured enough to support deletion by date or time range later.

### 6. Basic History View

Let the user inspect previously recorded history.

Scope:

- select a date;
- load route points for that date;
- show the route on the map;
- show basic metadata such as point count and time range.

Done when:

- the user can view a recorded route from a previous session;
- the route is loaded from local storage, not memory.

### 7. Timeline Playback

Add route playback with a calendar and timeline controls.

Scope:

- select a date or time range;
- show a playback slider;
- move the current position marker as the slider changes;
- visually fill the route as playback progresses;
- keep private-zone gaps understandable once private zones exist.

Done when:

- the user can scrub through a recorded route like a video timeline;
- the map updates to show the route state at the selected moment.

### 8. Private Zones

Add areas where route points are not saved.

Scope:

- create a private zone with center, radius, name, and enabled state;
- detect whether a new location point is inside an active private zone;
- skip saving points inside active private zones;
- show private-zone gaps on the route.

Done when:

- points inside a private zone are not stored;
- route gaps are visible and understandable on the map;
- the user can enable or disable a private zone.

### 9. Background Tracking

Allow tracking to continue after the app leaves the foreground.

Scope:

- request the required background location permissions;
- enable the required iOS background location capability;
- continue recording valid points in the background;
- clearly communicate active background tracking to the user.

Done when:

- tracking continues after the app is backgrounded;
- the app records useful route points in background conditions;
- the user can stop tracking after returning to the app.

### 10. Local Tracking Notifications

Add occasional local notifications while tracking is active.

Scope:

- request notification permission;
- send local reminders that tracking is active;
- optionally notify when tracking pauses or resumes because of private zones;
- avoid excessive notification frequency.

Done when:

- the app can show local tracking reminders;
- notifications are useful and not noisy;
- notifications do not require a backend.

## Near-Term Milestone

The next milestone is:

> Start/Stop Tracking + in-memory route recording + route line on the map.

This is the first milestone where Pathlog becomes a real route tracker rather than only a map with the user's current location.

## Later Work

Planned for later phases:

- history deletion by date or time range;
- delete all history;
- data export;
- battery and accuracy tuning;
- App Store readiness;
- Android exploration.
