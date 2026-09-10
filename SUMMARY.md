# Cadence — Summary

Offline-first personal operating system (Flutter + Drift + Supabase), built per `Cadence-design-doc.md`.

## What it does
One app replaces a dozen trackers — money, movement, time, habits, planning — on a **shared data model**:
- **Shared `entries` table** for lightweight logs (water, sleep, mood, habits, journal) with a cross-module `tags` vocabulary.
- **Dedicated tables** for expenses/budgets, GPS routes, steps, routines, study sessions, calendar events, goals, weekly reviews, accounts/balances, debts, and screen-time snapshots.
- **Weekly review** auto-synthesizes every module into a 0–100 life-rhythm score.
- **Command center**: circadian hero greeting, daily vitals glance bar, 6-action global quick-add palette, and unified tag explorer ("everything tagged Thesis").

## Architecture
- `drift`/SQLite is the source of truth on-device; a sync worker pushes/pulls Supabase opportunistically (last-write-wins by `updated_at`).
- Riverpod throughout; pure-function cores (aggregation, search, vitals math) under thin providers — unit-tested without SQLite.
- Android foreground service keeps GPS tracking alive; steps via pedometer as fallback; routes sync to PostGIS as LineString on walk end.
- Biometric app lock + one-click full JSON export (data sovereignty, no backend lock-in).

## Quality gates (design doc §10)
- `flutter analyze`: 0 issues. `flutter test`: 184/184 pass (incl. boot-to-save widget test).
- GitHub Actions (`.github/workflows/build_and_release.yml`): analyze → test → release APK → GitHub Release on every `main` push.

## Roadmap status
Phases 0–4 complete (chunks 1–25 + reviews R1–R5). Open decisions carried from the design doc: optional Go aggregation service (deferred — weekly compute runs on-device), iOS support (deferred — screen-time module is Android-only).
