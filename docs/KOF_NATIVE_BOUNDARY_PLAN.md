# KOOKIE Kof native-boundary migration plan

[Português (Brasil)](../pt-BR/docs/KOF_NATIVE_BOUNDARY_PLAN.md)

Status: **PROPOSED**. This plan is the execution document for decision
`D-KOF-NATIVE-BOUNDARY`. It does not authorize a broad C/Zig rewrite.

Normative boundary and batch ABI: [Kof native-boundary and synchronous batch
ABI](KOF_NATIVE_BOUNDARY_SPEC.md).

Current source pin: Kof `0.6.5` at
`a14a7cd47d74192dcc977c9d4cbf87d407694560`. Qualification of this pin is in
progress; the previous local proof was for
`f42ed91dfbceae09880b7d0619d98f67490149d1` and does not transfer
automatically.

## 1. Decision summary

1. Kof remains the authority for engine-owned CPU behavior: protocol policy,
   simulation, content admission, render extraction, layout, save schema and
   lifecycle decisions.
2. C remains the authority for operating-system and foreign-library mechanisms:
   SDL3/SDL_GPU/SDL_mixer handles, sockets, durable filesystem operations,
   FreeType/HarfBuzz, worker threads, SIMD intrinsics and PE entry glue.
3. `Buffer(U8)` is a synchronous, bounded, copy-in/copy-back boundary. It is not
   a typed-array ABI, a retained pointer, an asynchronous ownership transfer or
   a GPU/audio callback contract.
4. The first migration targets pure semantics and one measured batch path. It
   does not target the launcher, shader build, threads, audio device, font
   rasterization or GPU handles.
5. Existing scalar calls remain the fallback during qualification. They are
   removed only after the batch path has passed the gates in this document; no
   permanent compatibility alias is added.

## 2. Evidence and limits

The current working-tree composition measured by `scripts/report_code_mix.py`
is:

| Group | Lines | Share |
|---|---:|---:|
| Kof (`.kf`) | 83,128 | 77.89% |
| KofScript (`.ks`) | 764 | 0.72% |
| C/header | 8,660 | 8.11% |
| Shell tooling | 8,103 | 7.59% |
| Python tooling | 4,346 | 4.07% |
| PE bridge Java | 1,504 | 1.41% |
| GPU shader | 215 | 0.20% |

This is physical source composition, not a performance claim.

With the exact pinned Kof `0.6.5` source
`a14a7cd47d74192dcc977c9d4cbf87d407694560`, the installer recorded archive
SHA-256
`300e4200386b53d8e64796e110946340a6fe74ea9b2145af9aac8ade4caa86ef`
and completed in 173.76 seconds. The following gates passed:

- static/JVM: 170 Kof source files, 140 tests, 0 failures, 65 seconds;
- SIMD/native dispatch: scalar/SIMD parity, AArch64 syntax proof and the P1
  `buffer.poke8`/C-INOUT fixture, 10 seconds.

The full native/package gate for `a14a7cd` failed after 968 seconds with exit
143 while the native Kof build was still running; no native/package pass is
claimed. The native external-LAN build separately exceeded its 600-second
local limit. The previous `f42` attempt also exceeded 900 seconds and does not
qualify this source.

## 3. Scope

### In scope

- Qualifying and, if accepted, pinning the current upstream `lab` commit;
- extracting transport semantics from native mechanism code;
- qualifying one explicit synchronous batch ABI;
- replacing one representative scalar GPU staging path after measurement;
- optionally batching bounded persistence staging;
- documenting the SVG semantic/raster boundary;
- removing obsolete scalar paths only after the relevant gate passes.

### Out of scope

- moving `launcher/kookie_launcher.zig` into Kof;
- replacing Zig cross-compilation, PE linking or packaging;
- moving SDL, SDL_GPU, SDL_mixer, Winsock/POSIX, fsync/rename,
  FreeType/HarfBuzz, worker threads or SIMD intrinsics;
- introducing typed Kof arrays as a C memory-layout contract;
- introducing retained native pointers or callbacks into engine-owned state;
- replacing the shader pipeline with a runtime Kof shader compiler;
- changing the transport wire format or cryptographic construction.

## 4. Workstreams

### P0 — Upstream pin and baseline qualification

**Inputs:** `scripts/update_kof_lab.py`, `scripts/kof_pin.sh`, active CI/docs.

**Steps:**

1. Re-run `python3 scripts/update_kof_lab.py --check` immediately before the
   change.
2. If adopting the candidate, apply it with
   `--expected-commit a14a7cd47d74192dcc977c9d4cbf87d407694560` and
   `--expected-version 0.6.5`; do not update a moving `lab` ref implicitly.
3. Build the exact source archive and record source commit and archive hash.
4. Re-run static/JVM, SIMD and the native/package gate with the exact source.
5. Refresh active documentation only after the new baseline is green or its
   limits are explicitly recorded.

**Exit gate:** all active pin references name
`a14a7cd47d74192dcc977c9d4cbf87d407694560` and the exact qualification
results and remaining native/package limit are recorded. No migration claims
“latest” before this gate.

### P1 — Batch ABI qualification

**Inputs:** `docs/KOF_NATIVE_BOUNDARY_SPEC.md`, current SIMD probe and native
C fixtures.

**Steps:**

1. Prove a Kof-managed byte payload can be populated and passed to a native
   call without per-byte FFI copying. If the current Kof surface cannot do
   that, stop the production migration and record the missing upstream
   capability.
2. Add a bounded copy-in/copy-back fixture for valid, empty, maximum and
   malformed payloads.
3. Verify immediate C copy into owned storage and rejection of invalid
   descriptors.
4. Run the fixture on JVM and native x86-64. Keep scalar fallback for other
   targets.

**Exit gate:** the fixture proves lifetime, bounds, copy semantics, checksum,
zero/maximum cases and scalar parity. A source comment or an upstream claim is
not sufficient.

### P2 — Transport semantic extraction

**Candidate files:** `native/kookie_transport.c`,
`native/kookie_transport.h`,
`probes/g0_external_transport_backends/transport_jvm.kf`,
`probes/g0_external_transport_backends/transport_native.kf`, and a proposed
common `src/session/transport_codec.kf`.

**Steps:**

1. Inventory native code into socket/address/timeout mechanism versus packet,
   sequence, payload aggregation and validation semantics.
2. Move common endian and payload codec code into Kof only when byte-for-byte
   vectors pass against the current JVM/native implementations.
3. Keep socket creation, peer address handling, timeout and `sendto`/`recvfrom`
   in C.
4. Treat MAC/key ownership as a separate security gate. Do not expose key
   material to Kof merely to remove a C function. Until that gate passes, C
   may retain framing/MAC while Kof owns message semantics and aggregation.
5. Add raw bounded byte transport only through the batch ABI; do not pass
   `Byte[]` or `Int[]` by assuming a C layout.

**Exit gate:** existing LAN/loopback vectors remain wire-compatible; malformed,
replay, stale-sequence and wrong-peer cases retain their outcomes; no key or
wire-version change is introduced.

**Current status:** `src/session/transport_codec.kf` now owns the common
endian/payload helpers; the JVM backend calls it, while native C retains
socket, framing, MAC and key handling. The JVM external-LAN gate passed in
9 seconds. The native external-LAN `kof build --target native` exceeded the
local 600-second limit, so the P2 exit gate is not claimed.

### P3 — One GPU batch vertical slice

**First candidate:** scene vertex staging through the
`GPU_SCENE_VERTEX_V1` batch descriptor, with
`kookie_gpu_scene_push_vertex_resource` retained as scalar fallback; not audio,
text shaping or device handles.

**Steps:**

1. Keep `FrameStaging` and render/pass policy in Kof.
2. Encode a bounded `GPU_SCENE_VERTEX_V1` payload as specified by the ABI
   document.
3. Add a C entry point that validates the descriptor, copies into C-owned
   storage and feeds the existing SDL_GPU upload path.
4. Run the old scalar path and batch path over the same frame fixture.
5. Compare vertex count, checksum, draw count, resource generations and
   captured output. Measure boundary calls, allocations and p95 frame time.
6. Cut over only if the batch path passes the go/no-go thresholds.

**Exit gate:** exact semantic and capture parity, no retained pointer, no p95
regression beyond the specified tolerance, and scalar fallback still passes.

**Current status:** the three adapter probes now encode one
`GPU_SCENE_VERTEX_V1` `Buffer(U8)` batch per staged frame; C validates the
descriptor in two passes and copies into owned scene storage. The G0 adapter
replays the same staged fixture through batch and scalar paths and compares
count, draw calls and headless capture checksum when the native runtime is
available. Static/JVM passed; native adapter/GPU runtime and p95 qualification
remain pending because native Kof builds exceeded the local timeout and this
host has no headless GPU device.

### P4 — Optional persistence batch

**Candidate files:** `native/kookie_persistence_adapter.c/.h` and the existing
`BoundedDurableSaveFileCodec`/publication path.

Move only the bounded byte staging call. Kof keeps envelope, schema, migration,
checksum and slot policy. C keeps path validation, safe open, fsync or
`FlushFileBuffers`, atomic rename and fault handling.

**Exit gate:** interrupted publication, checksum failure, recovery and durable
rename tests remain identical; no byte staging loop is replaced without a
measured reduction in boundary calls.

**Disposition:** no P4 cutover is selected. The persistence adapter stages bytes
with indexed/order checks and keeps fault-injection, flush, rename and recovery
in C; the prerequisite native boundary gate is not green and no boundary-call
reduction has been measured.

### P5 — Optional SVG semantic split

`src/content/svg_intake.kf` and `native/kookie_ui_renderer.c` have overlapping
shape parsing responsibilities. A future slice may move admission and shape
normalization to Kof, but it MUST leave FreeType/HarfBuzz, pixel/depth buffers
and rasterization native.

This workstream is non-blocking and MUST NOT delay transport or batch gates.

**Disposition:** no P5 cutover is selected. Kof already owns SVG admission,
normalization and canonical checksums; C owns FreeType/HarfBuzz, pixel/depth
buffers and rasterization. The proposed split would add no qualified batch
boundary and remains non-blocking.

### P6 — Cleanup and documentation

After each accepted cutover:

- delete the obsolete implementation and stale comments;
- remove the old scalar entry point when no qualified caller remains;
- keep no alias solely for compatibility;
- update the English/Portuguese architecture, plan, spec and changelog pages;
- record the exact source pin, command, target and remaining limit.

## 5. Acceptance gates

| Gate | Requirement |
|---|---|
| Baseline | Exact Kof source, pin and archive are recorded; static/JVM and SIMD pass; native/package limits are explicit. |
| Behavior | Batch and scalar paths produce identical accepted output, rejection and lifecycle state. |
| Wire | Transport bytes, MAC outcomes, sequence/replay behavior and status values remain compatible. |
| Lifetime | C never retains a Kof buffer pointer; asynchronous work uses C-owned copies only. |
| Bounds | Negative, zero, overflow, stride, capacity, generation, checksum and maximum-size cases are deterministic. |
| Performance | The selected workload reduces boundary calls by at least 10x or improves p95 by at least 5%; p95 MUST NOT regress by more than 2% versus scalar. |
| Targets | JVM and native x86-64 are measured; unqualified targets retain scalar behavior. |
| Ownership | No gameplay, scene policy, asset admission, shader composition, OS durability or thread scheduler moves into C. |
| Cleanup | Obsolete paths, aliases and misleading comments are removed after cutover. |

The performance thresholds are go/no-go criteria for a production cutover, not a
claim about hardware performance before measurement.

## 6. Rollback and failure handling

A failed gate stops only the affected workstream. The scalar path remains the
working implementation until the batch path is proven. Do not hide a mismatch
by loosening validation, changing checksums, widening caps or adding a fallback
that silently changes ownership.

If the current Kof source cannot populate `Buffer(U8)` efficiently, document the
missing capability and keep bounded Kof arrays plus the checked scalar adapter.
That is an accepted outcome; a per-byte emulation of the proposed batch path is
not.

## 7. Explicit non-decisions

- No Kof rewrite of `kookie_launcher.zig`.
- No Kof replacement for the C thread pool, socket syscalls, durable filesystem
  primitives, SDL handles, FreeType/HarfBuzz or SIMD kernels.
- No raw pointer tokenization.
- No generic C renderer or asset parser created to justify a benchmark.
- No public ABI promise derived from `RUNTIME_ABI.md`; the engine boundary is
  target-qualified and behavioral.
