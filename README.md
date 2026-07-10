# Paramedic Triage Intake

> Offline-first triage intake for field paramedics. A record is **durable the
> instant it's saved** and syncs to the server automatically when connectivity
> returns — no user action, no lost data.

Built with **Flutter · Riverpod · Hive · connectivity_plus**.

---

## Why this exists

Paramedics log critical patient data in environments where cellular coverage is
unstable or absent. The core promise of this app is simple and non-negotiable:
**no triage record is ever lost**, regardless of network state. Everything below
serves that promise.

## Features

- Fast, single-screen intake optimized for one-handed thumb input under pressure.
- High-visibility hazard coding — Priority 1 & 2 stand out with deep red/orange,
  paired with icon + label so the signal never depends on color alone.
- Offline-first writes: submissions persist locally and instantly, online or not.
- Automatic background sync the moment connectivity is restored.
- Live sync-state per record: pending · syncing · synced · failed.
- Exponential backoff with jitter and bounded retries for transient failures.

## Tech stack

| Concern | Choice | Rationale |
|---|---|---|
| State | Riverpod (`StateNotifier`) | Compile-safe, testable, decouples UI state from the engine. |
| Persistence | Hive (JSON keyed by UUID) | Lightweight, zero code-gen — ideal for a key-value outbox. |
| Connectivity | connectivity_plus | Wrapped behind a `ConnectivityMonitor` interface for testability. |
| IDs | uuid v4 | Client-generated, doubles as the server idempotency key. |

---

## The core idea: the Outbox pattern

Every submission is written to a local durable store **first, unconditionally** —
online vs offline is irrelevant at write time. A separate sync engine drains that
outbox to the server whenever the network is up. Because the UI never talks to the
network directly, "offline" is never an error path — it's the normal path with
delivery deferred.

```
                    ┌─────────────────────┐
   Submit tapped ──▶│  Write to local     │  Hive · marked "pending"
                    │  outbox — ALWAYS     │  ← offline-first guarantee
                    └──────────┬──────────┘
                               │ optimistic UI update (shows instantly)
                               ▼
                    ┌─────────────────────┐
                    │      Sync engine     │  runs independently of the UI
                    │  ┌────────────────┐  │
   connectivity ───▶│  │  drain outbox   │  │
   restored         │  └───────┬────────┘  │
                    │          ▼           │
                    │   POST /api/v1/triage │  mock: 2s delay, may fail
                    │      ┌────┴────┐      │
                    │  success    failure   │
                    │     │           │     │
                    │  mark        backoff  │
                    │  synced      + retry ─┼──▶ re-queued as pending
                    └─────────────────────┘
```

## How the sync queue works

`lib/sync/sync_engine.dart` is the heart of the app. Its guarantees:

1. **Offline-first write** — `repository.save()` persists as `pending` and never
   touches the network, so it cannot fail on connectivity.
2. **Connectivity-driven drain** — the engine listens to `connectivity_plus` and
   drains the outbox on every `offline → online` transition.
3. **Reentrancy guard** — the listener, a manual refresh, an app-resume, and a
   scheduled retry can all fire at once; an `_isSyncing` flag collapses them into
   a single in-flight pass so nothing is sent twice.
4. **Offline no-op** — `syncPending()` checks connectivity up front and returns
   quietly if offline, so callers never guard it themselves.
5. **Idempotent delivery** — each record's UUID is the server idempotency key, so
   a retry after a lost acknowledgement upserts rather than duplicating.
6. **Exponential backoff with full jitter** — failed records back off `base·2ⁿ`
   (clamped), jittered to avoid a thundering herd on mass reconnect.
7. **Bounded retries** — after `maxRetries` a record is parked as `failed` with
   its last error, so a poison record can't loop forever.
8. **Lifecycle-safe** — a `WidgetsBindingObserver` triggers an opportunistic drain
   on resume, so minimizing and reopening behaves predictably.

> **On "background" sync:** the required demo (save in airplane mode → toggle it
> off → auto-sync) happens with the app in the foreground, which a connectivity
> listener plus lifecycle observer fully satisfies. True background execution when
> the app is *killed* (Android `WorkManager` / iOS `BGTaskScheduler`) is listed in
> the roadmap.

## Architecture

Four layers with strictly one-directional dependencies. The **repository is the
seam** that decouples the UI from persistence and sync — a background sync updates
the screen through the exact same path as a user action.

| Layer | Responsibility |
|---|---|
| Presentation (`lib/ui/`) | Form, queue list, badges. No knowledge of Hive/network. |
| State (`lib/state/`) | Immutable UI state, subscribed to the repository stream. |
| Repository (`lib/data/repository/`) | The single boundary; owns status transitions. |
| Data sources (`lib/data/`) | Hive outbox + mock remote. Dumb I/O. |
| Sync (`lib/sync/`) | Connectivity monitor, sync engine, backoff policy. |

**Two independent status fields** (kept deliberately separate):
`status` = the *patient's* triage status (`Pending` / `In-Transit`), set on the
form; `syncStatus` = the *record's* delivery lifecycle, owned by the sync engine.

## Project structure

```
lib/
├── main.dart                 # composition root: init, deps, provider overrides
├── app.dart                  # app shell, tabs, lifecycle observer
├── domain/                   # entities + validation rules (no Flutter/IO)
├── data/
│   ├── local/                # Hive outbox
│   ├── remote/               # mock API (2s delay, injectable failure)
│   └── repository/           # abstract + impl, reactive stream
├── sync/                     # connectivity monitor, sync engine, backoff
├── state/                    # Riverpod providers + notifier
└── ui/                       # form, queue, widgets, theme
test/                         # validator, backoff, sync engine tests
```

---

## Getting started

```bash
flutter create . --platforms=android,ios   # generate native runners
flutter pub get
flutter run
```

Requires Flutter 3.x (Dart ≥ 3.4). No backend needed — the API is simulated by
`MockRemoteDataSource` (2-second latency, 30% random failure). A **Force fail**
switch in the app bar deterministically triggers the retry/backoff path for the
demo.

## Testing

```bash
flutter test
```

Covers the parts that carry the risk:

- **Validation** — blank fields, priority range.
- **Backoff** — exponential growth, ceiling, jitter bounds, retry cap.
- **Sync engine** — offline no-op, successful drain, retry-on-failure increments
  the count, park-as-failed past the cap, batch drain. Uses an in-memory data
  source and a zero-latency injectable mock, so runs are fast and deterministic.

## Recording the demo

1. Submit a record → it appears in **Queue** as "Pending sync".
2. Enable **Airplane Mode**, submit another → still saved, still pending.
3. Disable **Airplane Mode** → within ~2s records flip `syncing → synced`
   automatically, with no interaction.

---

## Roadmap

- True background sync when the app is killed (`WorkManager` / `BGTaskScheduler`).
- Reachability ping on top of interface-level connectivity.
- SQLite/Drift outbox for indexed queries at high volume.
- At-rest encryption for patient data.
- Server-driven acks and conflict resolution against a real endpoint.
