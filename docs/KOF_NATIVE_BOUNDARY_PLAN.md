# KOOKIE Kof native-boundary migration plan

[Português (Brasil)](../pt-BR/docs/KOF_NATIVE_BOUNDARY_PLAN.md)

Status: **PROPOSED**. This plan is the execution document for decision
`D-KOF-NATIVE-BOUNDARY`. It does not authorize a broad C/Zig rewrite.

Normative boundary and batch ABI: [Kof native-boundary and synchronous batch
ABI](KOF_NATIVE_BOUNDARY_SPEC.md).

Current source pin: official Kof `0.6.8` at
`2971d2fe4cc873eb50fcd1b7d7d3e097381281c8`. The previous local proof was for
`f42ed91dfbceae09880b7d0619d98f67490149d1`; that proof does not transfer
automatically. Requalification is in progress.

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

The official Kof 0.6.8 Linux release archive
`kof-0.6.8-linux-x86_64.tar.gz` has SHA-256
`8da8f9efc7c55b6e5314248b90a0ac62d900117f4a3503af8dadf6ce82a20577`.
CI separately builds the exact pinned source commit after normalizing
toolchain metadata. Earlier qualification records below retain their original
toolchain identities and results; they are not evidence for the current pin.

**Current local qualification:** the official Kof `0.6.8` archive passed package
identity preflight. Static verification passed: 181 Kof files linted, 145-file
LSP diagnostics, and all 164 JVM tests. Exception, bounded Buffer SIMD,
external-LAN, interaction, durable-save, goose, PE durable-save and dedicated
server/network gates passed. The full `scripts/verify.sh` run reaches
`verify_kof_web_server.sh` but fails its coffee-pickup replication assertion;
therefore the full matrix is not green. Cross-target syntax proofs passed, but
cross-target runtime and hardware qualification remain outstanding.

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
   `--expected-commit 2971d2fe4cc873eb50fcd1b7d7d3e097381281c8` and
   `--expected-version 0.6.8`; do not update a moving `lab` ref implicitly.
3. Build the exact source archive and record source commit and archive hash.
4. Re-run static/JVM, SIMD and the native/package gate with the exact source.
5. Refresh active documentation only after the new baseline is green or its
   limits are explicitly recorded.

**Exit gate:** active pin references name
`2971d2fe4cc873eb50fcd1b7d7d3e097381281c8` and exact qualification results
and remaining native/package limits are recorded. No migration claims
“latest” before this gate.

**Current local result:** the official Kof `0.6.8` archive identity and local
static/JVM, SIMD, exception, native, package, and dedicated-server gates passed.
The full matrix remains blocked by the web multiplayer coffee-pickup
replication assertion; cross-target runtime and hardware gates are also
unqualified.

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

**Current status:** `scripts/verify_simd_dispatch.sh` passed with the official
Kof `0.6.8` archive on JVM and native x86-64. It reported
`buffer-fixture-sum=809`, `buffer-inout-sum=1231`, equal scalar/SIMD totals
`16844324864`, and selected SIMD routing. Freestanding syntax proofs passed
for AArch64 Linux, RISC-V Linux and x86-64/AArch64 macOS. This qualifies
bounded synchronous producer/copy-back plus target compilation only;
cross-target runtime and generic asynchronous or retained-payload ownership
remain unqualified.


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

**Current status:** `src/session/transport_codec.kf` owns the common
endian/payload helpers; the JVM backend calls it, while native C retains
socket, framing, MAC and key handling. The current full gate passed the
external-LAN JVM/native parity, codec, stale/replay and peer-ownership checks.
The P2 local exit gate is now green; separate-host and broader WAN claims remain
outside this result.

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

**Current status:** the three adapter probes encode one
`GPU_SCENE_VERTEX_V1` `Buffer(U8)` batch per staged frame; C validates the
descriptor in two passes and copies into owned scene storage. The optimized
full gate passed the native adapter and Vulkan reference renderer on
`Intel(R) Graphics (ARL)`, with one draw call, 984 instances and p95
`1710` microseconds. This is local Linux evidence; broader target hardware
and cross-platform presentation evidence remain separate gates.


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
