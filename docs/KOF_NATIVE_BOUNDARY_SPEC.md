# KOOKIE Kof native-boundary and synchronous batch ABI

[Português (Brasil)](../pt-BR/docs/KOF_NATIVE_BOUNDARY_SPEC.md)

Status: **PROPOSED**. Decision: `D-KOF-NATIVE-BOUNDARY`.

This document defines the boundary for engine-owned Kof semantics and native
platform mechanisms. It is a behavioral contract for KOOKIE adapters, not a
stable public Kof C ABI.

RFC 2119 terms are normative: **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**,
and **MAY**.

## 1. Ownership contract

### Kof MUST own

- gameplay, simulation, fixed-tick and authoritative state;
- packet/message semantics, payload aggregation and protocol policy;
- content admission, codecs and checksums owned by the engine;
- camera, projection, visibility, sorting, batching and render-pass policy;
- UI layout, semantic text runs, sound-cue policy and resource generations;
- save envelope, schema, migration, slot selection and publication policy;
- validation of values before crossing the native boundary.

### Native C MUST own

- SDL3, SDL_GPU and SDL_mixer handles and driver calls;
- POSIX/Winsock sockets, address structures and timeout syscalls;
- safe file descriptors/handles, fsync or `FlushFileBuffers`, atomic rename and
  path/reparse protection;
- FreeType/HarfBuzz shaping/rasterization and native pixel/depth storage;
- worker threads, queues and native completion storage;
- CPUID/NEON/AVX2/SSE2 detection and intrinsic kernels;
- PE entry/exit glue and foreign-library setup/teardown.

C MUST NOT become the owner of gameplay, scene algorithms, asset admission,
render ordering, save schema, packet authority or UI composition.

### Zig MUST own

- secure release download/update mechanics;
- HTTP/TLS, archive extraction, signature verification and process launch;
- cross-compilation, PE linking and packaging glue.

The launcher is not a candidate for this runtime batch ABI. Pure manifest policy
MAY be shared later only if a target-neutral Kof implementation is proven and
there is no duplicated security authority.

## 2. Existing FFI baseline

1. Scalar `extern` calls are the default boundary for handles, status, counts,
   generations and small descriptors.
2. Native pointers MUST NOT be converted to integer resource IDs. Integer tokens
   are indices into native registries with validation and generation checks.
3. Kof `Int[]`, `Float[]`, records and generic collections MUST NOT be passed to C
   by assuming a contiguous or stable object layout.
4. `Buffer(U8)` is currently qualified only for bounded synchronous use on JVM
   and native x86-64. Cross-target source claims are not KOOKIE qualification.
5. The buffer pointer is valid only for the duration of the extern call. C MUST
   NOT retain it, enqueue it, expose it to a foreign callback or use it after
   return.
6. Any asynchronous or retained native operation MUST copy into C-owned storage
   before the extern call returns.
7. Exceptions MUST NOT unwind across the C boundary. Failure is a bounded scalar
   result plus an existing diagnostic/status getter.
The local P1 qualification now proves Kof-side `buffer.poke8` population,
one bounded native INOUT call and copy-back on JVM and native x86-64. It does
not qualify a production GPU, audio, transport or persistence batch ABI.

## 3. Batch V1 common contract

Batch V1 is a family of subsystem-specific calls sharing the same validation
rules. It is not a packed native struct and it does not expose Kof object
headers or allocator details.

### 3.1 Descriptor fields

Every batch call MUST validate these scalar fields, where applicable:

| Field | Meaning | Rule |
|---|---|---|
| `kind` | Payload schema identifier | Known value only; unknown kind is rejected. |
| `schemaVersion` | Payload schema version | V1 is `1`; no silent reinterpretation. |
| `byteLength` | Valid bytes in the buffer | `0 <= byteLength <= subsystem cap`. |
| `elementCount` | Records or words | Non-negative and bounded. |
| `stride` | Bytes per fixed-size element | Fixed schemas require exact stride. |
| `capacity` | Destination capacity | MUST cover the requested payload. |
| `generation` | Resource/publication generation | Must match the active generation when required. |
| `checksum` | Kof-computed payload checksum | Must match the declared bytes before commit. |

A subsystem MAY omit fields that have no meaning, but it MUST NOT invent a
pointer or implicit length. Arithmetic for `elementCount * stride` MUST be
checked before multiplication and MUST equal `byteLength` for fixed-record
schemas.
For subsystem-specific symbols below, `kind` is fixed by the symbol name. The
`schemaVersion` remains an explicit scalar argument; a generic entry point MUST
pass both `kind` and `schemaVersion`.

### 3.2 Proposed call shapes

The exact exported C symbol may follow the existing subsystem naming, but its
behavior MUST match these shapes:

```kof
Bool kookie_gpu_scene_submit_batch(
    Buffer(U8) payload,
    Int schemaVersion,
    Int byteLength,
    Int vertexCount,
    Int stride,
    Int generation,
    Long checksum
)

Int kookie_transport_receive_wire_batch(
    Buffer(U8) destination,
    Int schemaVersion,
    Int capacity,
    Int generation
)

Bool kookie_transport_send_wire_batch(
    Buffer(U8) wire,
    Int schemaVersion,
    Int byteLength,
    Long checksum
)

Bool kookie_persistence_stage_batch(
    Buffer(U8) bytes,
    Int schemaVersion,
    Int byteLength,
    Long checksum
)
```

These are proposed native entry points, not compatibility aliases. A receive
call returns the number of bytes copied, or a documented negative/status result;
Kof reads the copy-back only after the call returns. A send, GPU submit or
persistence stage call MUST reject the request before mutating native state when
validation fails.

### 3.3 Lifetime and ownership

- Kof owns the source semantic arrays and their checksum.
- The adapter owns the copied native representation after return.
- C MUST copy only `byteLength` bytes.
- C MUST NOT read beyond `byteLength`, even if the buffer allocation is larger.
- C MUST NOT retain the Kof pointer.
- A generation mismatch MUST reject the batch without partial publication.
- A checksum mismatch MUST reject the batch without partial publication.
- The scalar path MUST remain available until the corresponding cutover gate
  passes.

### 3.4 Byte encoding

V1 intentionally avoids typed floating-point arrays.

- Raw byte schemas have no additional byte order.
- Fixed integer records use signed 32-bit little-endian fields (`i32_le`).
- Values are validated in Kof before encoding and defended again in C.
- No Kof object, array header, string pointer or native pointer is serialized.

## 4. V1 payload schemas

### `GPU_SCENE_VERTEX_V1`

One record contains six `i32_le` fields, stride `24`:

```text
resource, x, y, depth, u, v
```

The payload is semantic staging data. C validates capacity and resource tokens,
then copies to its existing scene storage. SDL_GPU handles and draw submission
remain C-owned.

The first GPU vertical slice now implements the exact
`kookie_gpu_scene_push_vertex_batch_v1(Buffer(U8), schemaVersion, byteLength,
vertexCount, stride, generation, checksum)` shape. Kof encodes
`GPU_SCENE_VERTEX_V1` with `buffer.poke8`, computes the bounded sum checksum
over the six semantic fields, and calls the batch once per staged frame. C
rejects schema, length, stride, generation, checksum and field violations before
publication, then copies into the existing scene storage. The adapter probes use
this path first and retain the scalar resource call as fallback.

This records the implemented source contract, not a native runtime
qualification claim; target-specific capture and p95 evidence remain required.

### `GPU_WORLD_VERTEX_V1`

One record contains six `i32_le` fields, stride `24`:

```text
resource, x, y, z, u, v
```

Camera/projection, visibility, material selection and pass order remain Kof
policy. C only validates, copies, uploads and submits.

### `GPU_WORDS_V1`

A bounded sequence of `i32_le` words, stride `4`. This covers packed texture,
world-atlas and camera-word staging only where an existing scalar path already
has a declared count and capacity. It does not grant C authority over texture
admission or camera semantics.

The implemented `kookie_gpu_world_texture_stage_batch_v1` entry point uses
`GPU_WORLD_TEXTURE_V1`: the descriptor carries atlas width/height, VFX origin,
goose/cat regions, and a bounded little-endian packed-pixel payload. Kof
encodes the existing `BoundedWorldTextureAsset` words once; C validates the
checksum and descriptor, copies the payload into adapter-owned staging, and
publishes it only after the copy completes. The G5 hardware gate renders the
world-only VFX pass and requires its checksum to differ from the clear-frame
baseline.

### `GPU_TEXTURE_BYTES_V1`

A bounded opaque byte payload. Kof MUST admit and checksum the source range
before the call. C MAY decode an admitted format or upload the bytes, but MUST
NOT become the source-format admission or cooking authority.

### `TRANSPORT_WIRE_V1`

The current transport wire bytes, including the existing header and MAC result,
remain byte-compatible. This plan does not change magic, version, word order,
sequence fields, packet limits or cryptographic construction.

During the first cutover C MAY remain responsible for framing and MAC/key
handling. Moving the codec or MAC to Kof requires a separate key-ownership and
security gate. The batch ABI alone MUST NOT expose key material to Kof.

The current maximum transport payload is bounded by the existing
`KOOKIE_TRANSPORT_MAX_WORDS` and header limit. The adapter MUST reject lengths
above the configured wire cap.

### `SAVE_BYTES_V1`

A bounded save byte range produced by the Kof save codec. C writes exactly the
copied bytes and retains responsibility for safe path operations, durability,
atomic publication and fault injection. Kof remains responsible for schema,
checksum, migration and slot policy.

## 5. Transport migration contract

1. `native/kookie_transport.c` MUST retain socket runtime, peer addresses,
   timeout and OS I/O until a later explicit decision.
2. Kof MAY own common payload aggregation and validation in a proposed shared
   `src/session/transport_codec.kf` module only after JVM/native golden vectors
   match byte-for-byte.
3. MAC and key handling MUST remain where the security review places them. No
   migration is justified solely by reducing C line count.
4. A wrong peer, malformed header, bad MAC, stale sequence, replay and capacity
   violation MUST preserve current outcomes and diagnostics.
5. The wire version MUST NOT change in this migration.
6. The JVM backend and native backend MAY use different I/O mechanisms, but they
   MUST expose the same Kof message semantics and rejection rules.

## 6. GPU and persistence migration contract

- Kof MUST produce the same semantic frame/save descriptor for scalar and batch
  paths.
- C MUST validate and copy before any asynchronous GPU/audio/file operation.
- C MUST NOT parse gameplay, scene graphs, save schemas or UI layout.
- A batch path MUST expose a deterministic scalar fallback for unqualified
  targets.
- The first GPU batch target is scene vertices. Text shaping, audio streams,
  device-loss recovery and retained GPU resources are not V1.
- Persistence batching MUST NOT weaken fsync/`FlushFileBuffers`, atomic rename,
  path safety or interrupted-publication recovery.

## 7. Error and atomicity rules

A rejected batch MUST:

- return `false`, a negative count or the existing bounded status result;
- leave the destination/native publication state unchanged;
- avoid partial writes visible to later draw, send, save or recovery calls;
- report enough bounded diagnostic state for the existing Kof probe to identify
  the rejection class.

The adapter MUST reject negative values, integer overflow, unsupported schema,
wrong stride, capacity overflow, generation mismatch, checksum mismatch and
payload lengths above subsystem limits.

## 8. Qualification matrix

| Surface | JVM | Native x86-64 | PE/other targets |
|---|---|---|---|
| Scalar externs | qualified by existing static/JVM gate | qualified by native probes | target-specific gate required |
| `Buffer(U8)` copy-in/copy-back | qualified by SIMD fixture | qualified by SIMD fixture | unqualified until measured |
| GPU scene batch | required before cutover | required before cutover | scalar fallback |
| Transport wire batch | required if backend uses it | required if backend uses it | scalar/current mechanism |
| Persistence batch | required if backend uses it | required if backend uses it | scalar fallback |
| Retained pointer/callback | prohibited | prohibited | prohibited |
| Async Kof buffer ownership | prohibited | prohibited | prohibited |

A target is not qualified because the compiler source contains an implementation
or documentation claim. It is qualified only by an executable fixture and the
relevant KOOKIE gate.

## 9. Required tests before deleting scalar paths

1. Valid, empty, maximum and malformed batch descriptors.
2. Exact scalar/batch output and checksum parity.
3. Generation advance, stale generation and cancellation behavior.
4. Copy-back length and high-bit/zero-byte preservation.
5. Transport wire, MAC, replay, stale sequence and wrong-peer vectors.
6. GPU vertex count, resource generation, draw count and captured frame parity.
7. Save checksum failure, interrupted stage, recovery and atomic publication.
8. Repeated warmup/measured runs recording boundary-call count, allocation count,
   p95 latency and peak resident memory.
9. JVM and native x86-64 execution; explicit scalar fallback on other targets.

The scalar entry point may be deleted only when every caller is migrated, the
relevant matrix is green and the corresponding plan gate is recorded.
