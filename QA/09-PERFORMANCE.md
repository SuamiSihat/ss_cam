# 09 — Performance Profiling

Last updated: 2026-10-22 | Version: v5.3.0

---

## Startup & Profiling Benchmarks (v5.3.0)

| Metric | Target | Baseline (v4.9.0) | Actual (v5.3.0) | Notes |
|--------|--------|-------------------|-----------------|-------|
| Cold launch to visible window | < 3s | ~1.8s | ~1.5s | Defer non-critical startup to ContextIdle |
| First page render (Dashboard) | < 1s | ~0.4s | ~0.3s | Cached workspace snapshot painted immediately |
| NAS probe / drive readiness | < 5s | ~2–4s | 2–4 ms | `DriveInfo.IsReady` check prevents SMB hanging |
| 50x UserProfile read access | < 50ms | ~24,000 ms | 13 ms (0.26 ms/call) | Thread-safe in-memory cache with write-invalidation |
| 2nd launch payload verification | < 50ms | ~1,200 ms | < 1 ms | `.payload_marker` version match skips redundant copy |
| 2nd launch fonts verification | < 50ms | ~450 ms | < 1 ms | `.sscam_fonts_marker` skips redundant extraction |
| LogTrace disk write latency | < 1ms | 2–5 ms | < 0.01 ms | In-memory `ConcurrentQueue` with 1s batch flush |

## Build Times (MSBuild 4.0 / Framework64)

| Configuration | Target | Actual | Notes |
|---------------|--------|--------|-------|
| Clean Build (`/t:Clean;Build /m`) | < 15s | ~5.0s | Multi-core `/m` enabled in QA runner |
| Incremental Build (`/t:Build /m`) | < 8s | ~5.4s | Fody/Costura disabled in Debug configuration |

## Memory

| State | RSS |
|-------|-----|
| Idle (Dashboard) | ~85 MB |
| Radio playing | ~110 MB |
| Dashboard + full workspace scan | ~140 MB |

## Background Timers

| Timer | Interval | Thread | Status / Optimization |
|-------|----------|--------|-----------------------|
| NAS health check | 30s | ThreadPool | Safe non-blocking probe |
| Radio proxy heartbeat | 5s | ThreadPool | Background worker |
| Dashboard auto-refresh | 60s | Dispatcher (UI) | Guarded against concurrent runs |
| Focus timer tick | 1s | DispatcherTimer | UI thread |
| Visualizer rhythm tick | 33ms | DispatcherTimer | **Active ONLY during playback** (idle eliminated) |
| UI Header aura tick | 50ms | DispatcherTimer | Throttled (20 FPS), paused when minimized |
| LogTrace flush timer | 1s | ThreadPool | Batch writes log buffer |

## Known Performance Risks & Mitigations

- WorkspaceScanner.cs: full directory scan is synchronous within its thread. Mitigated by `GetCached(root)` painting immediately on dashboard navigation.
- RadioStreamService.cs: Stream proxy now throttles visualizer updates when stopped, eliminating CPU wakeups.

## Status: PASS

