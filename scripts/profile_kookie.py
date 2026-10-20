#!/usr/bin/env python3
"""Profile the bounded KOOKIE reference workload on the Kof targets.

This records compiler-profile timing, workload phase percentiles, RSS plateau,
OS process counters, JVM GC evidence, and perf counters when the host permits
perf_event access. It is deliberately a diagnostic, not a gameplay authority.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from typing import Any, NoReturn

ROOT = Path(__file__).resolve().parents[1]
KOF_PIN = ROOT / "scripts" / "kof_pin.sh"


def fail(message: str) -> NoReturn:
    print(f"profile_kookie: {message}", file=sys.stderr)
    raise SystemExit(2)


def run(command: list[str], *, cwd: Path, env: dict[str, str], stdout: Path,
        stderr: Path | None = None) -> tuple[int, float]:
    start = time.monotonic()
    with stdout.open("w", encoding="utf-8") as output:
        if stderr is None:
            completed = subprocess.run(
                command,
                cwd=cwd,
                env=env,
                stdout=output,
                stderr=subprocess.STDOUT,
                check=False,
            )
        else:
            with stderr.open("w", encoding="utf-8") as error:
                completed = subprocess.run(
                    command,
                    cwd=cwd,
                    env=env,
                    stdout=output,
                    stderr=error,
                    check=False,
                )
    return completed.returncode, (time.monotonic() - start) * 1000.0


def shell_command(command: str) -> list[str]:
    return ["bash", "-lc", command]


def source_tree(work: Path) -> Path:
    source = work / "source"
    for module in ("core", "content", "session"):
        module_dir = source / module
        module_dir.mkdir(parents=True, exist_ok=True)
        for source_file in sorted((ROOT / "src" / module).glob("*.kf")):
            (module_dir / source_file.name).symlink_to(source_file)
    (source / "main.kf").symlink_to(ROOT / "apps" / "server" / "main.kf")
    lib_dir = source / "lib"
    lib_dir.mkdir()
    cc = shutil.which(os.environ.get("CC", "cc"))
    if cc is None:
        fail("a C compiler is required for the headless native adapter")
    adapter = lib_dir / "libkookie_headless_adapter.so"
    completed = subprocess.run(
        [
            cc,
            "-std=c11",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-O2",
            "-fPIC",
            "-shared",
            str(ROOT / "native" / "kookie_transport.c"),
            "-o",
            str(adapter),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        print(completed.stdout, end="", file=sys.stderr)
        print(completed.stderr, end="", file=sys.stderr)
        fail("headless adapter compilation failed")
    return source


def parse_time(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    result: dict[str, Any] = {"raw": text}
    patterns: dict[str, tuple[str, type[Any]]] = {
        "user_seconds": (r"User time \(seconds\): ([0-9.]+)", float),
        "system_seconds": (r"System time \(seconds\): ([0-9.]+)", float),
        "max_rss_kib": (r"Maximum resident set size \(kbytes\): ([0-9]+)", int),
        "minor_faults": (r"Minor \(reclaiming a frame\) page faults: ([0-9]+)", int),
        "major_faults": (r"Major \(requiring I/O\) page faults: ([0-9]+)", int),
        "voluntary_context_switches": (r"Voluntary context switches: ([0-9]+)", int),
        "involuntary_context_switches": (r"Involuntary context switches: ([0-9]+)", int),
        "elapsed": (r"Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): (.+)", str),
    }
    for key, (pattern, converter) in patterns.items():
        match = re.search(pattern, text)
        if match:
            result[key] = converter(match.group(1))
    return result



def parse_perf(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    counters: dict[str, str] = {}
    for line in text.splitlines():
        fields = line.split(",")
        if len(fields) >= 3 and fields[0].strip() and fields[2].strip():
            counters[fields[2].strip()] = fields[0].strip()
    return {"available": bool(counters), "counters": counters, "raw": text}


def parse_workload(path: Path) -> dict[str, str]:
    raw_lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    try:
        marker = raw_lines.index("KOOKIE G5 dedicated headless server")
    except ValueError as error:
        raise ValueError(f"missing G5 workload marker in {path}") from error
    lines = raw_lines[marker:]
    values: dict[str, str] = {}
    paired = {
        "warmup-ticks",
        "measured-ticks",
        "simulation-p50-us",
        "simulation-p95-us",
        "simulation-p99-us",
        "simulation-max-us",
        "simulation-budget-us",
        "simulation-budget-pass",
        "rss-first-kib",
        "rss-last-kib",
        "rss-growth-kib",
        "rss-range-kib",
        "rss-samples",
        "rss-plateau",
        "realtime",
    }
    index = 0
    while index < len(lines):
        line = lines[index]
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
        elif line in paired and index + 1 < len(lines):
            values[line] = lines[index + 1]
            index += 1
        index += 1
    if not lines or lines[0] != "KOOKIE G5 dedicated headless server":
        raise ValueError(f"missing G5 workload marker in {path}")
    required = (
        "simulation-p95-us",
        "simulation-p99-us",
        "simulation-max-us",
        "rss-growth-kib",
        "rss-range-kib",
        "rss-plateau",
        "resource-plateau",
        "phase-telemetry",
        "phase-profile",
    )
    missing = [key for key in required if key not in values]
    if missing:
        raise ValueError(f"missing workload fields: {', '.join(missing)}")
    return values


def compiler_profile(source: Path, target: str, artifact_dir: Path,
                     env: dict[str, str]) -> dict[str, Any]:
    log = artifact_dir / f"compiler-profile-{target}.log"
    command = (
        f"kof profile main.kf --target {target}"
    )
    status, wall_ms = run(
        shell_command(command), cwd=source, env=env, stdout=log
    )
    text = log.read_text(encoding="utf-8", errors="replace")
    wall_match = re.search(r"^\s*wall:\s+([0-9]+) ms$", text, re.MULTILINE)
    result: dict[str, Any] = {
        "status": status,
        "wall_ms": int(wall_match.group(1)) if wall_match else round(wall_ms),
        "elapsed_ms": round(wall_ms),
        "log": str(log),
    }
    if status != 0:
        raise RuntimeError(f"Kof compiler profile failed for {target}: {log}")
    return result


def shlex_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def perf_available(env: dict[str, str]) -> bool:
    perf = shutil.which("perf")
    if perf is None:
        return False
    probe = subprocess.run(
        [perf, "stat", "-x,", "-o", os.devnull, "--", "true"],
        cwd=ROOT,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return probe.returncode == 0


def profile_runtime(target: str, source: Path, jvm_build: Path | None,
                    native_build: Path | None, artifact_dir: Path,
                    env: dict[str, str], use_perf: bool,
                    args: argparse.Namespace) -> dict[str, Any]:
    runtime_log = artifact_dir / f"runtime-{target}.log"
    time_log = artifact_dir / f"time-{target}.log"
    perf_log = artifact_dir / f"perf-{target}.log"
    gc_log = artifact_dir / f"gc-{target}.log"
    runtime_env = dict(env)
    runtime_env.update(
        {
            "KOOKIE_SERVER_WARMUP_TICKS": str(args.warmup_ticks),
            "KOOKIE_SERVER_TICKS": str(args.ticks),
            "KOOKIE_SERVER_RSS_SAMPLE_TICKS": str(args.sample_ticks),
            "KOOKIE_SERVER_P95_BUDGET_US": str(args.p95_budget_us),
            "KOOKIE_SERVER_REALTIME": "1" if args.realtime else "0",
        }
    )
    if target == "jvm":
        if jvm_build is None:
            raise RuntimeError("JVM build is required for JVM profiling")
        runtime_env["JAVA_TOOL_OPTIONS"] = (
            f"-Xlog:gc*:file={gc_log}:tags,uptime,level"
        )
        runtime = [
            "java",
            "--enable-native-access=ALL-UNNAMED",
            "-cp",
            str(jvm_build),
            "Default.Main",
        ]
    else:
        if native_build is None:
            raise RuntimeError("native build is required for native profiling")
        runtime = [str(native_build / "Default" / "Main")]
    measured = ["/usr/bin/time", "-v", "-o", str(time_log), *runtime]
    if not Path("/usr/bin/time").is_file():
        measured = runtime
    command = measured
    perf_enabled = use_perf
    if use_perf:
        perf = shutil.which("perf")
        if perf is None:
            perf_enabled = False
        else:
            command = [perf, "stat", "-x,", "-o", str(perf_log), "--", *measured]
    process_log = artifact_dir / f"process-{target}.json"
    command = [
        sys.executable,
        str(ROOT / "scripts" / "profile_process.py"),
        "--output",
        str(process_log),
        "--",
        *command,
    ]
    status, wall_ms = run(command, cwd=source, env=runtime_env, stdout=runtime_log)
    if status != 0:
        raise RuntimeError(f"{target} workload failed with status {status}: {runtime_log}")
    workload = parse_workload(runtime_log)
    process = json.loads(process_log.read_text(encoding="utf-8"))
    process["external_time"] = parse_time(time_log)
    process["source"] = "profile_process"
    return {
        "status": status,
        "wall_ms": round(wall_ms),
        "workload": workload,
        "process": process,
        "perf": parse_perf(perf_log) if perf_enabled else {
            "available": False,
            "counters": {},
            "raw": "perf unavailable or not permitted",
        },
        "jvm_gc": {
            "observable": target == "jvm" and gc_log.exists(),
            "log": str(gc_log) if target == "jvm" else None,
            "events": sum(
                1 for line in gc_log.read_text(encoding="utf-8", errors="replace").splitlines()
                if "GC(" in line
            ) if target == "jvm" and gc_log.exists() else None,
        },
        "log": str(runtime_log),
    }


def verify(result: dict[str, Any], args: argparse.Namespace) -> None:
    workload = result["workload"]
    if workload.get("simulation-budget-pass") != "true":
        raise RuntimeError(f"{result['target']} simulation budget failed")
    if int(workload["simulation-p95-us"]) > args.p95_budget_us:
        raise RuntimeError(f"{result['target']} simulation p95 exceeded budget")
    if int(workload["rss-growth-kib"]) > 4096 or int(workload["rss-range-kib"]) > 4096:
        raise RuntimeError(f"{result['target']} RSS plateau failed")
    if workload.get("rss-plateau") != "true" or workload.get("resource-plateau") != "true":
        raise RuntimeError(f"{result['target']} resource plateau failed")
    if workload.get("phase-telemetry") != "true":
        raise RuntimeError(f"{result['target']} phase telemetry missing")
    if args.require_perf and not result["perf"]["available"]:
        raise RuntimeError(f"{result['target']} perf counters unavailable")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=("jvm", "native", "all"), default="all")
    parser.add_argument("--warmup-ticks", type=int, default=128)
    parser.add_argument("--ticks", type=int, default=512)
    parser.add_argument("--sample-ticks", type=int, default=32)
    parser.add_argument("--p95-budget-us", type=int, default=4000)
    parser.add_argument("--realtime", action="store_true")
    parser.add_argument("--require-perf", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--output", type=Path, default=ROOT / "build" / "kookie-performance-profile.json")
    args = parser.parse_args()
    args.output = args.output.resolve()
    if args.warmup_ticks < 0 or args.ticks <= 0 or args.sample_ticks <= 0:
        fail("tick counts must be positive, with warmup non-negative")
    if args.ticks > 10000000 or args.warmup_ticks > 1000000:
        fail("tick counts exceed the bounded workload contract")

    targets = ("jvm", "native") if args.target == "all" else (args.target,)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    artifact_dir = args.output.parent / f"{args.output.stem}-artifacts"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    base_env = os.environ.copy()
    base_env["PATH"] = f"{ROOT / 'scripts' / 'kof-as'}{os.pathsep}{base_env.get('PATH', '')}"
    with tempfile.TemporaryDirectory(prefix="kookie-profile-") as temporary:
        work = Path(temporary)
        source = source_tree(work)
        jvm_build: Path | None = None
        native_build: Path | None = None
        jvm_compile: dict[str, Any] | None = None
        native_compile: dict[str, Any] | None = None
        if "jvm" in targets:
            jvm_build = work / "jvm-build"
            build_log = artifact_dir / "build-jvm.log"
            command = (
                f"source {shlex_quote(str(KOF_PIN))} && "
                "kof build main.kf --target jvm --output " +
                shlex_quote(str(jvm_build))
            )
            status, wall_ms = run(
                shell_command(command), cwd=source, env=base_env, stdout=build_log
            )
            if status != 0:
                raise RuntimeError(f"JVM build failed: {build_log}")
            jvm_compile = {
                "status": status, "wall_ms": round(wall_ms), "log": str(build_log)
            }
        if "native" in targets:
            native_build = work / "native-build"
            build_log = artifact_dir / "build-native.log"
            command = (
                f"source {shlex_quote(str(KOF_PIN))} && "
                "kof build main.kf --target native --output " +
                shlex_quote(str(native_build))
            )
            status, wall_ms = run(
                shell_command(command), cwd=source, env=base_env, stdout=build_log
            )
            if status != 0:
                raise RuntimeError(f"native build failed: {build_log}")
            native_compile = {
                "status": status, "wall_ms": round(wall_ms), "log": str(build_log)
            }

        results: list[dict[str, Any]] = []
        for target in targets:
            compiler = compiler_profile(source, target, artifact_dir, base_env)
            use_perf = perf_available(base_env)
            result = profile_runtime(
                target, source, jvm_build, native_build, artifact_dir,
                base_env, use_perf, args
            )
            result["target"] = target
            result["compiler_profile"] = compiler
            if args.verify:
                verify(result, args)
            results.append(result)

    report = {
        "schema": "kookie.performance-profile/v1",
        "kof_version": "0.6.5",
        "kof_source_commit": "8e59b24acc978eb2546509b5cfca867a06e7283a",
        "source_commit": subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip(),
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "python": platform.python_version(),
        },
        "workload": {
            "warmup_ticks": args.warmup_ticks,
            "measured_ticks": args.ticks,
            "sample_ticks": args.sample_ticks,
            "p95_budget_us": args.p95_budget_us,
            "realtime": args.realtime,
            "enemies": 64,
            "projectiles": 256,
            "pickups": 512,
        },
        "jvm_compile": jvm_compile,
        "native_compile": native_compile,
        "results": results,
    }
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"KOOKIE performance profile: {args.output}")
    for result in results:
        workload = result["workload"]
        perf_state = "available" if result["perf"]["available"] else "unavailable"
        print(
            f"target={result['target']} p50={workload.get('simulation-p50-us')}us "
            f"p95={workload.get('simulation-p95-us')}us "
            f"p99={workload.get('simulation-p99-us')}us "
            f"rss-growth={workload.get('rss-growth-kib')}KiB perf={perf_state}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
