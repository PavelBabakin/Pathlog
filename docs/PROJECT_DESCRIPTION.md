# Pathlog: Project Description

## Summary

Pathlog is a private iOS app for recording a user's movement history locally on the device. The app tracks location, shows movement history on a map, and lets the user go back to a specific point in time to see where they were.

The core idea: personal movement history should be useful, understandable, and private. Location data should not leave the device unless the user explicitly chooses that.

The intended default behavior is simple: the user starts tracking once, and Pathlog continues tracking in the background until the user stops it. The app may occasionally notify the user that tracking is still active.

## Problem

It is sometimes useful to know exactly where you were on a certain day or at a specific time: to remember a route, find a place again, reconstruct the timeline of a day, or understand movement habits. Many existing solutions depend on cloud accounts, have unclear privacy models, or do not provide simple control over where tracking should stop.

Pathlog solves this as a personal local movement journal.

## Target User

The first target user is the app owner: someone who wants to track their own movement history for personal use.

Potential use cases:

- remember where the user was at a specific time;
- view the route for a day;
- find a previously visited place;
- keep a private local archive of movement history;
- stop recording in private or sensitive areas.

## Product Principles

1. Privacy-first: data is stored locally on the device.
2. User control: the user controls when tracking starts, stops, and how it behaves.
3. Local by default: no account, server, or cloud sync in the initial version.
4. Minimal first: build a small working MVP before expanding the product.
5. Transparent tracking: the app must clearly show when tracking is active.
6. Accuracy first: location accuracy is more important than aggressive battery saving for the primary tracking mode.

## MVP

The first complete version should support:

- showing a map;
- requesting location permission;
- showing the user's current location;
- starting and stopping tracking;
- continuing tracking in the background after tracking is started;
- occasionally reminding the user that tracking is active;
- recording route points locally;
- drawing the route on the map;
- selecting history by calendar date and time;
- showing the user's position at a selected time;
- playing back a route with a timeline slider, similar to scrubbing through a video;
- creating private zones where route points are not recorded.

## Out of Scope for the First MVP

The initial version will not include:

- user accounts;
- backend services;
- cloud sync;
- Android support;
- social features;
- route sharing;
- advanced analytics;
- App Store release before the core behavior is stable.

## Private Zones

A private zone is an area on the map where the app should not store route points. Examples include home, work, or any other sensitive place.

Basic model:

- zone center: coordinates;
- radius in meters;
- name;
- enabled or disabled state.

Expected behavior: if a new location point is inside an active private zone, it is not saved to history.

Private-zone gaps should be visible on the map. The user should be able to understand that tracking was intentionally paused or omitted for privacy in that part of the route.

## Background Tracking

Pathlog should support long-running tracking. Once the user starts tracking, the app should continue recording location updates in the background until the user explicitly stops tracking.

Expected controls:

- Start Tracking;
- Stop Tracking;
- visible tracking status in the app;
- system permission flow for background location access;
- clear messaging that tracking can continue while the app is in the background.

Accuracy is the priority for the main tracking mode. Battery usage still matters, but the first product goal is to capture reliable and useful location history.

## Notifications

Pathlog may occasionally send local notifications while tracking is active. The purpose is transparency: the user should not forget that background tracking is running.

Possible notification examples:

- tracking is still active;
- tracking has been running for a long time;
- tracking was paused because the user entered a private zone;
- tracking resumed after leaving a private zone.

Notifications should be local to the device and should not require a server.

## Data

Core local data:

- route points;
- timestamps;
- location accuracy;
- tracking settings;
- private zones.

The app should store as much local history as is reasonably possible on the device. The user must be able to delete history manually.

Required deletion controls:

- delete all history;
- delete history for a selected date or time range.

Data export should be supported later, after the core tracking and local history features are stable.

Initial route point model:

```text
LocationPoint
- id
- latitude
- longitude
- timestamp
- horizontalAccuracy
- altitude
- speed
```

Initial private zone model:

```text
PrivacyZone
- id
- name
- latitude
- longitude
- radiusMeters
- isEnabled
```

## Timeline and Playback

History should be selected through a calendar and time controls. After selecting a date or time range, the user should be able to scrub through the route using a playback-style timeline.

Expected playback behavior:

- the map shows the route for the selected date or time range;
- a slider controls the current playback position;
- moving the slider updates the user's position on the map;
- the route can visually fill in as the timeline moves forward;
- private-zone gaps remain visually understandable during playback.

## Technical Direction

The app starts as a native iOS project:

- Swift;
- SwiftUI;
- MapKit;
- Core Location;
- local data storage.

The first milestone is already implemented: the app shows a map, requests location access, and displays the user's current location.

## Near-Term Steps

1. Add Start Tracking / Stop Tracking.
2. Collect route points in memory.
3. Draw the first route line on the map.
4. Add active-tracking status in the UI.
5. Persist route points locally.
6. Add a basic day history view.
7. Add timeline playback for a selected date.
8. Add the first version of private zones.
9. Add background tracking.
10. Add local tracking reminder notifications.

## Open Questions

- What location sampling strategy gives high accuracy without making battery usage unacceptable?
- What local storage technology should be used for long-term route history?
- What visual style should represent private-zone gaps on the map?
- What export formats should be supported later?
