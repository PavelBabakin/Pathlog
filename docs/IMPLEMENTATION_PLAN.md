# Pathlog: Implementation Plan

## Current Status

The project currently has the first fourteen implementation phases completed:

- the app opens to a map;
- the app requests location access;
- the app shows the user's current location;
- the user can start and stop tracking;
- the app records route points in memory while tracking is active;
- the app shows the collected point count;
- the app draws the recorded route as a line on the map;
- the app applies conservative filtering to remove only clearly low-quality location points;
- the app persists route sessions locally in SQLite;
- the app can show completed historical routes as a separate map layer;
- the app can load route history for a selected date;
- the app can play back a selected route with a timeline slider;
- the app can continue recording the active route while backgrounded when Always location access is enabled;
- the app communicates whether background tracking is enabled or limited to foreground use;
- the app can send quiet local reminders while tracking is active;
- tracking reminders stop when the user stops tracking;
- the app shows approximate local data usage and stored item counts;
- the app shows recent tracking time, background time, location updates, and accuracy mode;
- the app explains battery impact as activity context and directs users to Settings > Battery for Apple's per-app report;
- the user can create, edit, enable, disable, and delete local private zones;
- route points in enabled private zones are not stored, and route lines visibly break after those zones;
- the app can create local map notes with text and photos;
- the app can attach map notes to nearby places when MapKit returns place data;
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

### 4. Basic Location Filtering - Completed

Avoid storing obviously bad or noisy route points.

Scope:

- ignore points with poor horizontal accuracy;
- avoid duplicate or near-duplicate points;
- avoid points that arrive too frequently to be useful;
- keep the rules simple and adjustable.

Filtering direction:

- use conservative filtering only;
- do not remove small-area movement just because it happens in one place;
- preserve valid use cases such as running laps on a stadium or moving inside a covered venue;
- use private zones later for places where the user does not want tracking, such as home or office.

Done when:

- collected routes are reasonably clean;
- point count does not grow from duplicate stationary updates;
- filtering rules are easy to revise later.

Status:

- completed.

### 5. Local Persistence - Completed

Store route history locally on the device.

Scope:

- choose the local storage approach;
- persist route points;
- load stored route points after app restart;
- support large histories over time.

Preferred direction:

- use SQLite for long-term route history because the app may store many location points and needs efficient queries by date and time range;
- keep storage APIs isolated behind a small store type so the rest of the app does not depend on raw SQL.

Initial implementation:

- route sessions and route points are stored locally in a SQLite database in the app's Application Support directory;
- route points are written during active tracking so the current route can survive app restarts as stored data;
- stored points can be queried by date and time range;
- the app does not automatically draw the latest stored route on launch;
- after restart, the default map behavior should focus on the user's current location;
- stored routes should be loaded onto the map only through history, timeline, or persisted-route map-layer features.

Done when:

- route points survive app restarts;
- the app can query previous history by date and time range;
- storage is structured enough to support deletion by date or time range later.

Status:

- completed.

### 6. Persisted Routes Map Layer - Completed

Show previously walked routes on the map as a persistent historical layer without replacing the current-location experience.

Scope:

- load stored route segments from SQLite for the currently visible map region or selected time scope;
- draw previously walked routes as a subdued map overlay;
- keep the current live tracking route visually distinct from historical routes;
- use different colors or visual styles for historical routes and the current tracking session;
- make overlapping routes distinguishable when the user walks along a previously recorded path again;
- avoid loading all historical points at once when the database becomes large;
- provide a way to hide or show the persisted route layer;
- keep app launch focused on the user's current location, not on the latest stored route.

Initial implementation:

- completed route sessions are loaded from SQLite as separate historical route segments;
- historical routes are shown with a subdued gray style;
- the current live tracking route is shown with a stronger blue style;
- the user can hide or show the historical route layer from the main map panel;
- historical loading is limited to recent data and a maximum point count until region-based loading is added.

Done when:

- the map can show already walked routes from local storage;
- historical route overlays do not block current-location tracking;
- historical routes and the current live route remain visually distinguishable, including when they overlap;
- the app can keep the overlay performant by querying only the needed data;
- the user can understand the difference between current tracking and previous routes.

Status:

- completed.

### 7. Basic History View - Completed

Let the user inspect previously recorded history.

Scope:

- select a date;
- load route points for that date;
- show the route on the map;
- show basic metadata such as point count and time range.

Initial implementation:

- the main map panel opens a History sheet;
- the user can select a date with a graphical date picker;
- completed route points for the selected day are loaded from SQLite;
- the selected day's route is drawn on the map with a distinct orange style;
- the map camera focuses on the selected route after loading it;
- the selected route shows basic metadata: point count and time range.

Done when:

- the user can view a recorded route from a previous session;
- the route is loaded from local storage, not memory.

Status:

- completed.

### 8. Timeline Playback - Completed

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

Initial implementation:

- the History sheet shows recent active days with recorded point counts;
- selecting an active day loads that day's route from SQLite;
- the selected route is shown as a faint full-route preview;
- a playback slider scrubs through the selected route;
- the map shows a moving playback marker at the selected point;
- the played portion of the route is filled with a stronger orange line;
- the playback control shows the selected point's timestamp.

Done when:

- the user can choose a recorded day from a calendar;
- the user can visually distinguish days with activity from empty days;
- the user can scrub through the selected route like a video timeline;
- the map updates to show the route state at the selected moment.

Deferred timeline scope:

- active-days-only calendar mode;
- selecting a date range;
- narrowing a selection to a time range;
- playback behavior across multiple days;
- private-zone gap visualization in playback.

Status:

- completed.

### 9. Map Notes - Completed

Add user-created notes on the map.

Scope:

- add a map button for creating a note;
- allow notes to be created at the current position;
- allow notes to be created at any point on the map by moving the map center to the target place;
- store note text locally;
- attach one or more local photos to a note;
- show notes as markers on the map;
- open note details from the map;
- support notes during route history browsing.

Done when:

- the user can create a note at the current location;
- the user can create a note for a place that is not their current location;
- the user can add text and photos to the note;
- the note remains available after app restart;
- notes are visible and tappable on the map.

Initial implementation:

- the main map panel has an Add Note button;
- notes can target the user's latest known location or the current map center;
- note title, description, and up to four photos are stored locally;
- note markers are shown on the map;
- tapping a note marker opens note details;
- map notes are stored in SQLite and photo files are stored in Application Support.

Status:

- completed.

### 10. Place-Based Map Notes - Completed

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

Initial implementation:

- the note editor can search nearby points of interest around the current map center;
- the user can select a nearby place before saving a note;
- selected place name, category, and identifier are stored when available;
- notes remain coordinate-based when no place identifier is available;
- note details show the attached place metadata.

Status:

- completed.

### 11. Background Tracking - Completed

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

Initial implementation:

- the app requests Always location access when the user starts tracking or selects the background access control;
- the target includes the Location updates background mode and clear permission descriptions;
- background location updates and the system location indicator are enabled only while tracking with Always access;
- the tracking screen reports whether background tracking is enabled or foreground-only;
- denied location access provides a direct route to the app's Settings page.

Status:

- completed.

### 12. Local Tracking Notifications - Completed

Add occasional local notifications while tracking is active.

Scope:

- request notification permission;
- send local reminders that tracking is active;
- leave room for later pause and resume notifications once private zones exist;
- avoid excessive notification frequency.

Done when:

- the app can show local tracking reminders;
- notifications are useful and not noisy;
- notifications do not require a backend.

Initial implementation:

- the app requests notification permission when tracking starts;
- a quiet local reminder repeats every two hours while tracking is active;
- stopping tracking cancels the pending reminder;
- denied permission does not interrupt route recording and provides a link to notification settings;
- notification authorization is refreshed when the app returns to the foreground during tracking.

Status:

- completed.

### 13. Storage and Tracking Impact - Completed

Show the user how much local data Pathlog stores and provide transparent tracking impact information.

Scope:

- show the approximate size of locally stored Pathlog data;
- separate route history, map notes, photos, exports, and other local app data when possible;
- show how many route points, sessions, notes, and photos are stored;
- provide shortcuts to delete selected history, delete all history, or manage large data groups once deletion features exist;
- show tracking activity metrics that affect battery usage, such as active tracking time, background tracking time, location update count, and selected accuracy mode;
- estimate battery impact from app-owned tracking metrics where possible;
- clearly distinguish Pathlog's activity summary from Apple's per-app battery report;
- guide users to iOS Settings for Apple's official per-app battery usage view when needed.

Done when:

- the user can see how much storage Pathlog data uses;
- the user can understand which stored data categories use the most space;
- the user can see recent tracking activity metrics that explain likely battery impact;
- battery information is presented as an estimate or activity summary, not as exact system battery usage.

Initial implementation:

- the Storage & Impact sheet shows approximate Application Support usage, SQLite size, photo size, and unclassified local files;
- the sheet shows route session, point, note, and photo counts from SQLite;
- completed sessions store background duration and location update count; the sheet shows these alongside tracking duration and recorded route points;
- the accuracy mode is identified as best available and fixed in this version;
- battery guidance describes tracking activity without claiming an exact battery percentage and points to Settings > Battery;
- deletion shortcuts remain deferred until history deletion features are implemented.

Status:

- completed.

### 14. Private Zones - Completed

Add areas where route points are not saved.

Scope:

- create a private zone with center, radius, name, and enabled state;
- edit or delete an existing private zone;
- detect whether a new location point is inside an active private zone;
- skip saving points inside active private zones;
- show private-zone gaps on the route.

Done when:

- points inside a private zone are not stored;
- route gaps are visible and understandable on the map;
- the user can enable or disable a private zone.

Implementation details:

- private zones are stored locally in SQLite and shown as circles on the map;
- points are withheld when their reported GPS uncertainty overlaps an enabled zone;
- the first saved point after leaving a zone starts a new route segment and displays a lock marker;
- previously recorded history is not altered when a private zone is created;
- existing databases add a defaulted route-segment flag so older route history remains intact.

Status:

- completed.

## Near-Term Milestone

The next milestone is:

> History deletion by date or time range.

This milestone should let the user remove selected local route history without deleting unrelated data.

## Later Work

Planned for later phases:

- history deletion by date or time range;
- delete all history;
- data export;
- battery and accuracy tuning;
- App Store readiness;
- Android exploration.
