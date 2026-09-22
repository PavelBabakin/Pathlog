# Pathlog: Implementation Plan

## Current Status

The project currently has the first three implementation phases completed:

- the app opens to a map;
- the app requests location access;
- the app shows the user's current location;
- the user can start and stop tracking;
- the app records route points in memory while tracking is active;
- the app shows the collected point count;
- the app draws the recorded route as a line on the map;
- the project builds successfully.

## Implementation Phases

### 1. Tracking Session UI - Completed

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

Status:

- completed.

### 2. In-Memory Route Recording - Completed

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

Status:

- completed.

### 3. Route Line on the Map - Completed

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

Status:

- completed.

### 4. Basic Location Filtering - Next

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

- open a calendar from a dedicated timeline or calendar control;
- browse any year, month, and day;
- select a single day;
- select a range of days;
- highlight days that contain recorded pathlog data;
- provide an active-days-only mode for focusing the calendar on days with recorded activity;
- optionally select a specific time or time range after choosing the date scope;
- show a playback slider;
- move the current position marker as the slider changes;
- visually fill the route as playback progresses;
- keep private-zone gaps understandable once private zones exist.

Done when:

- the user can choose a recorded day from a calendar;
- the user can visually distinguish days with activity from empty days;
- the user can switch to a calendar mode focused on active days;
- the user can select a single day or a date range;
- the user can optionally narrow the result to a time range;
- the user can scrub through the selected route like a video timeline;
- the map updates to show the route state at the selected moment.

### 8. Map Notes

Add user-created notes on the map.

Scope:

- add a map button for creating a note at the current position;
- store note text locally;
- attach one or more local photos to a note;
- show notes as markers on the map;
- open note details from the map;
- support notes during route history browsing.

Done when:

- the user can create a note at the current location;
- the user can add text and photos to the note;
- the note remains available after app restart;
- notes are visible and tappable on the map.

### 9. Place-Based Map Notes

Allow notes to be attached to selected map objects or points of interest, not only to the user's current position or route point.

Scope:

- detect or select nearby map places when possible;
- let the user choose a cafe, shop, building, or other point of interest;
- attach note text and photos to the selected place;
- store the selected place name and identifier when available;
- show place-based notes on the map.

Done when:

- the user can select a visible or nearby map place;
- the user can attach a note to that place;
- the note remains connected to the place when browsing later;
- the experience still works when a place identifier is unavailable by falling back to coordinates.

### 10. Private Zones

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

### 11. Background Tracking

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

### 12. Local Tracking Notifications

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

> Basic location filtering.

This milestone should make recorded routes cleaner by ignoring low-quality, duplicate, or overly frequent location updates.

## Later Work

Planned for later phases:

- map notes for current position;
- notes attached to selected map places or points of interest;
- history deletion by date or time range;
- delete all history;
- data export;
- battery and accuracy tuning;
- App Store readiness;
- Android exploration.
