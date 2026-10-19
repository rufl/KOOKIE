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

The native Verify step also captures the complete `verify.sh` stdout/stderr in
`native-package-verification.log`; this distinguishes dependency gates from
Kof command failures. The hosted native runner bootstraps the pinned SDL3
3.4.18 and SDL_mixer 3.2.4 prefixes, and installs `glslc` plus `spirv-tools`
because the external-LAN parity gate validates generated SPIR-V.

## Current release observation

Verify KOOKIE run
[`38978943862`](https://github.com/rufl/KOOKIE/actions/runs/38978943862)
passed for source commit `e8cad301b566607a3b8095a219d05441de3240e5`.
Release run
[`38981016223`](https://github.com/rufl/KOOKIE/actions/runs/38981016223) completed
the Kof toolchain and Linux package jobs successfully. Its Windows
presentation job ran on the now-online `kookie-windows-01` runner but failed
before artifact work because the runner could not find `powershell`; the
workflow fix declares `shell: bash` for the Kof-pin step. The publish job was
skipped and no `.64` release exists.


The wrapper does not infer percentage completion because Kof does not expose a
stable machine-readable native compilation progress protocol. The reliable
signals are stage, elapsed time, historical ETA, timeout countdown, exit code
and the complete log path.
