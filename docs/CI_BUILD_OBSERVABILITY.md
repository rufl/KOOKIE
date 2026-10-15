# CI build observability

[Português (Brasil)](../pt-BR/docs/CI_BUILD_OBSERVABILITY.md)

Kof native builds are executed through `scripts/kof_observed.sh` via the
`scripts/kof_pin.sh` helper `kookie_kof_observed`. The wrapper provides a
bounded command, periodic progress lines, a command log and a historical ETA.

## Local use

```bash
source scripts/kof_pin.sh
kookie_kof_observed local-jvm \
  kof build probes/g0_platform/main.kf \
  --target jvm --output /tmp/kookie-jvm
```

The wrapper prints lines like:

```text
kof-observed: name=canonical-native state=start timeout=1800s heartbeat=30s estimate=unknown basis=none log=...
kof-observed: name=canonical-native state=running elapsed=30s eta=unknown timeout-in=1770s
kof-observed: name=canonical-native state=passed duration=... log=...
```

The first successful run has no historical ETA. Later runs use the rounded
mean of the last five successful runs for the same Kof pin and stage. An ETA
is guidance, not compiler progress; `overdue+Ns` means the historical estimate
was exceeded while the hard timeout is still active.

## Controls

| Variable | Default | Meaning |
|---|---:|---|
| `KOOKIE_KOF_BUILD_TIMEOUT_SECONDS` | `1800` | Hard timeout for one Kof command. |
| `KOOKIE_KOF_BUILD_HEARTBEAT_SECONDS` | `30` | Progress interval. |
| `KOOKIE_KOF_BUILD_KILL_AFTER_SECONDS` | `30` | Grace period after timeout. |
| `KOOKIE_KOF_BUILD_ESTIMATE_SECONDS` | unset | Explicit ETA seed for one invocation. |
| `KOOKIE_BUILD_LOG_DIR` | `/tmp/kookie-build-logs` | Directory for full command logs. |
| `KOOKIE_KOF_BUILD_HISTORY_DIR` | `$XDG_CACHE_HOME/kookie` | Directory for `build-times.tsv`. |

The Verify native and release jobs override `KOOKIE_KOF_BUILD_TIMEOUT_SECONDS`
to `2700` seconds (45 minutes); the Verify native/package job has a
150-minute outer timeout. Individual stages can override the value through
`KOOKIE_KOF_BUILD_TIMEOUT_<STAGE>_SECONDS`; the helper normalizes stage names
to uppercase underscores.

`KOOKIE_KOF_BUILD_HISTORY_FILE` can override the history file directly.
Successful durations are recorded only after exit code zero, so a timeout does
not become a false ETA baseline.

The Verify workflow stores build logs as an artifact named
`kookie-kof-build-diagnostics-*`. The canonical build cache also stores the
history file so later runs can display an ETA. Release Linux/Windows jobs
store their build logs as separate diagnostic artifacts.

The wrapper does not infer percentage completion because Kof does not expose a
stable machine-readable native compilation progress protocol. The reliable
signals are stage, elapsed time, historical ETA, timeout countdown, exit code
and the complete log path.
