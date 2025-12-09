# Workout App (SwiftUI)

A SwiftUI-based workout tracker for iPhone that supports autosaved sessions, custom workout types, per-set tracking, gym geofencing prompts, metrics with PRs and streaks, and iCloud key-value sync.

## Highlights
- **Home**: Start a workout from presets (chest/arms/legs/core/cardio/HIIT/etc.), create new types, resume ongoing autosaved sessions, and browse history.
- **Workout logging**: Add exercises per type, quick-add multiple sets, or edit sets one-by-one with weight, reps, RPE, notes, and custom fields. Start time is captured when a workout begins; end time is set on save but remains editable.
- **Autosave + ongoing state**: Every change auto-persists locally and to iCloud key-value store so closing/locking the app keeps the session alive. Ongoing sessions surface on the home screen.
- **Gyms**: Save gym addresses/coords and radii. When arriving (or leaving without starting), trigger prompts to begin a workout (hook into geofencing/notifications).
- **Metrics**: Attendance for week/month, streaks, per-exercise PR chart, and average durations. Extendable for 1RM graphs and streak visuals.
- **Export & Health**: Export workouts to CSV and track last Apple Health export time. HealthKit integration hooks can be added where `markExportedToHealth` is used.
- **Theming & security**: System/light/dark theme toggle plus optional Face ID / PIN gate.
- **Accessibility**: Uses system Dynamic Type, VoiceOver-friendly labels, and high-contrast friendly palettes by default.

## Structure
- `App/WorkoutApp.swift`: Entry point and tab layout.
- `App/Models/Models.swift`: Models for workout types, exercises, sets, sessions, gyms, timers, metrics, and themes.
- `App/Data/WorkoutStore.swift`: Observable store with autosave, iCloud KVS sync, metrics, CSV export, and helper utilities.
- `App/Views/`: Screens for home, sessions, metrics, gym locations, and settings.

## Running
Open the folder in Xcode 15+ as a SwiftUI app target (iOS 17+ recommended). The project intentionally avoids third-party dependencies; Charts framework is used for metrics visuals.
