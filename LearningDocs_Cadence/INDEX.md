# Learning Index — Cadence

Running table of contents and roadmap for the Cadence offline-first personal operating system.

| Chunk # | Title | One-Line Goal | Tags | Status |
|---|---|---|---|---|
| 1 | [Flutter Project Skeleton & M3 Expressive Setup](1.project-setup.md) | Initialize Flutter app with Riverpod, Material 3 Expressive theming, and dynamic circadian color system. | `#flutter #ui #theming #riverpod` | Complete |
| 2 | [GitHub Actions CI/CD Pipeline](2.github-actions-ci-cd.md) | Build automated workflow to compile and release APK artifacts on GitHub. | `#ci-cd #github-actions #android` | Complete |
| 3 | [Local Database Layer with Drift](3.local-db-drift.md) | Setup SQLite database via Drift with type-safe schemas and DAOs. | `#sqlite #drift #storage #offline-first` | Complete |
| 4 | [Supabase Auth & Client Wiring](4.supabase-auth-client.md) | Configure Supabase GoTrue client, persistent auth state, and secure login/signup. | `#supabase #auth #security` | Complete |
| 5 | [Drift & Supabase Sync Engine](5.drift-supabase-sync.md) | Implement offline-first bidirectional sync with push/pull queues and last-write-wins conflict resolution. | `#sync #networking #drift #supabase` | Complete |
| R1 | [Review Chunks 1–5](R1.review-chunks-1-5.md) | Review core foundation concepts, mistakes, and architecture checkpoints. | `#review` | Complete |
| 6 | [Shared Entries & Generic Logging](6.shared-entries-generic-logging.md) | Build generic `entries` model and UI for lightweight logging (habits, water, sleep, mood). | `#drift #riverpod #habits` | Complete |
| 7 | [Expense Tracker — Data Layer & Calculations](7.expense-tracker-data-layer.md) | Create expenses and budgets tables with monthly limits and category summaries. | `#finance #drift #sql` | Complete |
| 8 | [Expense Tracker — UI & Visualizations](8.expense-tracker-ui-visualizations.md) | Build expense creation screens, receipt attachment mocks, and category breakdown charts. | `#finance #ui #fl_chart #riverpod` | Complete |
| 9 | [Daily Goals & Progress Tracker](9.daily-goals-progress-tracker.md) | Implement daily/weekly targets and streak tracking across modules. | `#goals #state-management` | Complete |
| 10 | [Agenda Calendar UI](10.agenda-calendar-ui.md) | Render day and week agenda schedules with custom calendar events. | `#calendar #ui #planner` | Complete |
| R2 | [Review Chunks 6–10](R2.review-chunks-6-10.md) | Review shared entries, finance modeling, goals, and calendar architecture. | `#review` | Complete |
| 11 | [Step Counter Integration](11.step-counter-integration.md) | Connect native pedometer hardware sensor to log daily steps locally as a reliable fallback. | `#sensors #pedometer #background` | Complete |
| 12 | [Background Foreground Service](12.background-foreground-service.md) | Configure persistent Android foreground service to prevent OS process termination during tracking. | `#android #background #foreground-service` | Complete |
| 13 | [GPS Route Recording & Drift Buffering](13.gps-route-recording-drift-buffering.md) | Stream location updates, buffer coordinate points locally, and compute distance/pace. | `#geolocator #gps #battery #drift` | Complete |
| 14 | [Route Map Visualization](14.route-map-visualization.md) | Render recorded GPS tracks on an interactive OpenStreetMap view using `flutter_map`. | `#maps #flutter_map #gis` | Complete |
| 15 | [PostGIS Route Sync to Supabase](15.postgis-route-sync-supabase.md) | Transform local route paths into PostGIS LineString geometry and sync on route completion. | `#postgis #supabase #geo #sync` | Complete |
| R3 | [Review Chunks 11–15](R3.review-chunks-11-15.md) | Review sensor streaming, Android lifecycle/foreground service, and GIS geometry. | `#review` | Complete |
| 16 | [Routines & Daily Scheduling Checklist](16.routines-scheduling-checklist.md) | Build daily routines with sortable tasks and completion histories. | `#routines #habits #ui` | Complete |
| 17 | Pomodoro & Study Time Tracker | Implement focused study session timer with tag association (e.g., "Thesis"). | `#timer #pomodoro #study` | Planned |
| 18 | Full Time-Blocking Planner | Integrate interactive drag-and-drop calendar planner linking routines and study blocks. | `#syncfusion #calendar #planner` | Planned |
| 19 | Cross-Module Aggregation & Weekly Review | Read across expenses, movement, study, and goals to generate automated weekly review summaries. | `#aggregation #analytics #review` | Planned |
| 20 | Net Worth & Balance Tracking | Track historical account balances and visualize net worth trajectory. | `#finance #fl_chart #analytics` | Planned |
| R4 | Review Chunks 16–20 | Review routines, time-blocking, cross-module joins, and financial graphing. | `#review` | Planned |
| 21 | Debt & Lending Ledger | Manage debts and IOUs (owed to me vs I owe) with settlement tracking. | `#finance #ledger` | Planned |
| 22 | Android Screen-Time Integration | Query Android `UsageStatsManager` for app usage rollups correlated with daily productivity. | `#android #usage-stats #analytics` | Planned |
| 23 | Biometric Security & Full JSON Export | Add biometric app lock (`local_auth`) and one-click JSON export for complete data sovereignty. | `#security #biometrics #export #privacy` | Planned |
| 24 | Unified Home Dashboard & Global Quick-Add | Build centralized daily overview and modular quick-entry modal. | `#dashboard #ui #ux` | Planned |
| 25 | Unified Tag Explorer & Cross-Module Search | Query and navigate items across entries, expenses, and study sessions by shared tags. | `#search #indexing #tags` | Planned |
| R5 | Review Chunks 21–25 | Review system security, Android platform channels, and global querying. | `#review` | Planned |
| 26 | Final Release Polish, End-to-End Build & Summary | Perform end-to-end integration test, build release APK via GitHub Actions, and write SUMMARY.md. | `#release #ci-cd #summary` | Planned |
