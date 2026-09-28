# Course-driven compiler experiments

Research date: 2026-09-22. Companion to [KOF_COURSE](KOF_COURSE.md).

## Scope and reproduction

These are 18 small source programs: one unchanged course solution and 17 focused probes, executed through 36 `run` and two `check` invocations. This is not a course-wide test run or a platform matrix. Only JVM and native Linux x86-64 were exercised. No server, process demo, database, GUI, network scanner or graphical surface was launched.

Compiler artifact, SHA-256, JDK, environment and the native full-runtime/pruning warning are unchanged from [RESEARCH_PROBES](RESEARCH_PROBES.md). Each command ran serially with a 60-second timeout. Both target executions of the byte probe produced the independently inspected file bytes `00 7f 80 ff`; the file was removed between runs.

Place each source below in its own directory as `main.kf`; `run` collects siblings. From that directory, with the verified jar path in `JAR`:

```sh
export JAVA_TOOL_OPTIONS=--enable-native-access=ALL-UNNAMED
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run main.kf --target native
```

For `reduce-seed-first`, `check` was run on both targets before the two `run` commands. Successful `check` alone was not treated as execution proof. Compiler-generated scratch paths and assembly sizes are incidental, not performance results.

## Observed results

The table records actual exit codes and stdout, including failing and misleadingly successful programs. `json-observe` native tiny nonzero Double values below are one observed run, not stable expected values. They must not be turned into golden outputs. Standard `JAVA_TOOL_OPTIONS` notices and native generation/pruning diagnostics are omitted here, not suppressed during execution.

| Source | Command | Target | Exit | Observed stdout |
|---|---|---|---|---|
| `functions` | `run` | jvm | 0 | <code>4<br>9<br>hello world<br>22<br>7</code> |
| `functions` | `run` | native | 0 | <code>4<br>9<br>hello world<br>22<br>7</code> |
| `numeric` | `run` | jvm | 0 | <code>true<br>4.0<br>5.0<br>8.0</code> |
| `numeric` | `run` | native | 0 | <code>true<br>4.0<br>5.0<br>8.0</code> |
| `collections` | `run` | jvm | 0 | <code>6<br>1<br>true<br>true<br>3<br>b</code> |
| `collections` | `run` | native | 1 | <code>6<br>1<br>true<br>true<br>1<br>Runtime error: array index out of bounds</code> |
| `matrix` | `run` | jvm | 0 | <code>2<br>3<br>0<br>17</code> |
| `matrix` | `run` | native | 0 | <code>2<br>3<br>0<br>17</code> |
| `bytes` | `run` | jvm | 0 | <code>bytes-ok<br>range-ok</code> |
| `bytes` | `run` | native | 0 | <code>bytes-ok<br>range-ok</code> |
| `json` | `run` | jvm | 0 | <code>{"version":1,"speed":1.25,"name":"hero"}<br>json-ok</code> |
| `json` | `run` | native | 1 | <code>fraction</code> |
| `finally` | `run` | jvm | 0 | <code>return-cleanup<br>7<br>throw-cleanup<br>boom<br>done</code> |
| `finally` | `run` | native | 0 | <code>return-cleanup<br>7<br>throw-cleanup<br>boom<br>done</code> |
| `assert-trap` | `run` | jvm | 1 | <code>false-positive<br>no-throw</code> |
| `assert-trap` | `run` | native | 0 | <code>false-positive<br>no-throw<br>unreachable</code> |
| `bounds` | `run` | jvm | 0 | <code>caught-bounds<br>bounds-cleanup<br>survived</code> |
| `bounds` | `run` | native | 1 | <code>Runtime error: array index out of bounds</code> |
| `queue-course` | `run` | jvm | 0 | <code>10<br>20<br>30<br>40</code> |
| `queue-course` | `run` | native | 0 | <code>10<br>20<br>30<br>40</code> |
| `split` | `run` | jvm | 0 | <code>3<br>5<br>3</code> |
| `split` | `run` | native | 0 | <code>1<br>3<br>3</code> |
| `json-observe` | `run` | jvm | 0 | <code>{"version":1,"speed":1.25,"name":"hero"}<br>1<br>1.25<br>hero<br>1.25</code> |
| `json-observe` | `run` | native | 0 | <code>{"version":1,"speed":0.0,"name":"hero"}<br>1<br>6.89901252743E-310<br><br>6.8990125262158E-310</code> |
| `catch-state` | `run` | jvm | 0 | <code>false<br>normal<br>false<br>checked</code> |
| `catch-state` | `run` | native | 0 | <code>false<br>normal<br>false<br>checked</code> |
| `catch-return` | `run` | jvm | 0 | <code>normal<br>false<br>normal<br>checked</code> |
| `catch-return` | `run` | native | 0 | <code>normal<br>false<br>normal<br>checked</code> |
| `reduce-seed-first` | `check` | jvm | 0 | <code>checked 1 file(s) — no errors</code> |
| `reduce-seed-first` | `check` | native | 0 | <code>checked 1 file(s) — no errors</code> |
| `assert-after-catch` | `run` | jvm | 1 | <code>no-throw<br>false</code> |
| `assert-after-catch` | `run` | native | 0 | <code>no-throw<br>false<br>true<br>unreachable</code> |
| `assert-false` | `run` | jvm | 1 | <code>false</code> |
| `assert-false` | `run` | native | 1 | <code>false<br>expected failure</code> |
| `reduce-seed-first` | `run` | jvm | 0 | <code>6</code> |
| `reduce-seed-first` | `run` | native | 0 | <code>6</code> |
| `record-float` | `run` | jvm | 0 | <code>1<br>1.25<br>hero<br>1.25<br>1.25</code> |
| `record-float` | `run` | native | 0 | <code>1<br>1.25<br>hero<br>1.25<br>1.25</code> |

JVM `assert-trap`, `assert-after-catch` and `assert-false` also emitted `java.lang.RuntimeException` on stderr with, respectively, `correctly rejects no throw`, `expected failure`, and `expected failure`.

## Interpretation and limits

- `functions`: arity overloads, default arguments, mutation visible through a capture, and a nested lambda worked in these shapes. Not proof that every closure/type combination works or is allocation-free.
- `numeric`: Long field compared with Int literal and a discarded Double method result worked. Builtin Double `math.sqrt`, `math.lerp` and `math.pow` returned expected values. No broad numerical-accuracy/performance claim.
- `collections`: callback-first reduce, map method size, present zero versus missing null worked before split. Native escaped-pipe split returned one element, then the deliberately indexed second element caused a fatal bounds error.
- `split`: JVM regex and native single-character delimiter behavior differ. Plain comma worked on both; that does not establish general split parity.
- `reduce-seed-first`: the course's seed-first order also ran successfully. Do not "correct" it solely because another official lesson uses callback-first.
- `matrix`: allocation, nested lengths, zero initialization and one 2D Int write/read worked. It does not establish contiguous external buffer layout.
- `bytes`: instance `File.writeBytes/readBytes/readRange(1, 2)` preserved zero/high-bit bytes. Missing files, negative ranges, large inputs, atomic replacement/durability and native-library staging remain untested.
- `record-float`: direct mixed-field/Double/Float record getters worked. Therefore the JSON failure below cannot be dismissed as every floating-point record being broken.
- `json`: a mixed Int/Double/String record round-trip failed its fractional-value assertion on native. `json-observe` showed wrong encoded Double, wrong decoded Double and empty decoded name. Decoding a literal independently also produced a wrong Double. This blocks relying on this native serialization shape; it does not prove every JSON API is broken.
- `finally`: cleanup ran before a return, and during explicit String-throw propagation. `bounds` demonstrates a separate fatal native path that did not run catch/finally or continue.
- `assert-trap`: putting `assert(false)` inside the catch region under test can catch the test's own failure. Worse, simply moving the assertion after a normally completed try/catch did not make the native test trustworthy.
- `assert-after-catch`: native printed `false`, then `true` after the failed assertion, and reached `unreachable` with exit 0. The assertion after the try was handled by the preceding catch. JVM failed with exit 1. `assert-false` failed correctly on both without the preceding try. `catch-state` shows the normal path did not enter its catch before a later throw. This narrows a native exception-handler lifetime defect; no compiler fix was attempted.
- `catch-return`: explicit returns inside both branches produced the expected false result. This is a diagnostic control, not a recommended engine-wide workaround for defective exception handling.
- `queue-course`: the unchanged course sample printed FIFO order on both targets. It did not test overflow, underflow, wraparound reuse or sustained throughput.

The engine must compare observable values and failure paths, not count green exits. Native exception handling needs repair/revalidation before trusting cleanup or exception assertions. Float JSON needs its own fix/schema proof before persistence/content import. These investigations did not implement the engine or modify the compiler/course.

## Complete executed sources

Sources are reproduced exactly, including the intentionally bad assertion and failing cases. Do not copy those patterns into production.

### `functions/main.kf`

```kof
Int add(Int a) { return a }
Int add(Int a, Int b) { return a + b }
String greet(String who = "world") { return "hello " + who }
main() {
    println(add(4))
    println(add(4, 5))
    println(greet())
    var offset = 10
    var shifted = (x: Int) -> x + offset
    offset = 20
    println(shifted(2))
    var nested = (x: Int) -> ((y: Int) -> x + y)
    var addThree = nested(3)
    println(addThree(4))
}
```

### `numeric/main.kf`

```kof
class Meter {
    Long count
    constructor() { count = 3L }
    Double ratio() { return 1.5 }
    Bool positive() { return count > 0 }
}
main() {
    var m = Meter()
    println(m.positive())
    m.ratio()
    println(math.sqrt(16.0))
    println(math.lerp(0.0, 10.0, 0.5))
    println(math.pow(2.0, 3.0))
}
```

### `collections/main.kf`

```kof
main() {
    var nums = listOf(1, 2, 3)
    println(nums.reduce((acc: Int, x: Int) -> acc + x, 0))
    var values: Map<String, Int> = mapOf("present", 0)
    println(values.size())
    println(values.get("present") == 0)
    println(values.get("missing") == null)
    var parts = "a|b|c".split("\\|")
    println(parts.length)
    println(parts[1])
}
```

### `matrix/main.kf`

```kof
main() {
    var grid = new Int[2][3]
    grid[1][2] = 17
    println(grid.length)
    println(grid[1].length)
    println(grid[0][2])
    println(grid[1][2])
}
```

### `bytes/main.kf`

```kof
main() {
    var bytes = new Int[4]
    bytes[0] = 0
    bytes[1] = 127
    bytes[2] = 128
    bytes[3] = 255
    var file = File("payload.bin")
    assert(file.writeBytes(bytes), "write failed")
    var loaded = file.readBytes()
    assert(loaded.length == 4, "length")
    for (var i = 0; i < bytes.length; i++) {
        assert(loaded[i] == bytes[i], "byte mismatch")
    }
    println("bytes-ok")
    var part = file.readRange(1, 2)
    assert(part.length == 2, "range length")
    assert(part[0] == 127 && part[1] == 128, "range bytes")
    println("range-ok")
}
```

### `json/main.kf`

```kof
record Save(Int version, Double speed, String name)
main() {
    var original = Save(1, 1.25, "hero")
    var text = json.encode(original)
    var loaded = json.decode<Save>(text)
    assert(loaded.version() == 1, "version")
    assert(loaded.speed() == 1.25, "fraction")
    assert(loaded.name() == "hero", "name")
    println(text)
    println("json-ok")
}
```

### `finally/main.kf`

```kof
Int finish() {
    try { return 7 } finally { println("return-cleanup") }
}
void propagate() {
    try { throw "boom" } finally { println("throw-cleanup") }
}
main() {
    println(finish())
    try { propagate() } catch (String e) { println(e) }
    println("done")
}
```

### `assert-trap/main.kf`

```kof
main() {
    try {
        assert(false, "operation did not throw")
    } catch (String e) {
        assert(true, "caught")
    }
    println("false-positive")
    var caught = false
    try { println("no-throw") } catch (String e) { caught = true }
    assert(caught, "correctly rejects no throw")
    println("unreachable")
}
```

### `bounds/main.kf`

```kof
main() {
    var values = new Int[1]
    try {
        println(values[values.length])
    } catch (String e) { println("caught-bounds") }
    finally { println("bounds-cleanup") }
    println("survived")
}
```

### `queue-course/main.kf`

Unchanged [course solution 16-fila-circular.kf](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/02-estruturas-de-dados/solucoes/16-fila-circular.kf). Upstream course attribution/license applies; this is a research reproduction, not engine source.

```kof
class FilaCircular {
    Int[] buffer
    Int inicio
    Int fim
    Int n
    constructor(Int capacidade) {
        buffer = new Int[capacidade]
        inicio = 0
        fim = 0
        n = 0
    }
    Bool cheia() {
        return n == buffer.length
    }
    Bool vazia() {
        return n == 0
    }
    void enfileirar(Int v) {
        if (cheia()) {
            throw "fila cheia"
        }
        buffer[fim] = v
        fim = (fim + 1) % buffer.length
        n = n + 1
    }
    Int desenfileirar() {
        if (vazia()) {
            throw "fila vazia"
        }
        var v = buffer[inicio]
        inicio = (inicio + 1) % buffer.length
        n = n - 1
        return v
    }
}
main() {
    var f = FilaCircular(4)
    f.enfileirar(10)
    f.enfileirar(20)
    f.enfileirar(30)
    println(f.desenfileirar())   // 10
    println(f.desenfileirar())   // 20
    f.enfileirar(40)
    println(f.desenfileirar())   // 30
    println(f.desenfileirar())   // 40
}
```

### `split/main.kf`

```kof
main() {
    println("a|b|c".split("\\|").length)
    println("a|b|c".split("|").length)
    println("a,b,c".split(",").length)
}
```

### `json-observe/main.kf`

```kof
record Save(Int version, Double speed, String name)
main() {
    var text = json.encode(Save(1, 1.25, "hero"))
    println(text)
    var loaded = json.decode<Save>(text)
    println(loaded.version())
    println(loaded.speed())
    println(loaded.name())
    var literal = json.decode<Save>("{\"version\":1,\"speed\":1.25,\"name\":\"hero\"}")
    println(literal.speed())
}
```

### `catch-state/main.kf`

```kof
main() {
    var caught = false
    println(caught)
    try { println("normal") }
    catch (String e) { println("catch-entered"); caught = true }
    println(caught)
    assert(!caught, "normal path must not catch")
    println("checked")
}
```

### `catch-return/main.kf`

```kof
Bool throwsNothing() {
    try { println("normal"); return false }
    catch (String e) { return true }
}
main() {
    println(throwsNothing())
    assert(!throwsNothing(), "must return false")
    println("checked")
}
```

### `reduce-seed-first/main.kf`

```kof
main() {
    var nums = listOf(1, 2, 3)
    println(nums.reduce(0, (acc: Int, x: Int) -> acc + x))
}
```

### `assert-after-catch/main.kf`

```kof
main() {
    var caught = false
    try { println("no-throw") }
    catch (String e) { caught = true }
    println(caught)
    assert(caught, "expected failure")
    println("unreachable")
}
```

### `assert-false/main.kf`

```kof
main() {
    var caught = false
    println(caught)
    assert(caught, "expected failure")
    println("unreachable")
}
```

### `record-float/main.kf`

```kof
record Mixed(Int version, Double speed, String name)
record Scalar(Double value)
record Small(Float value)
main() {
    var mixed = Mixed(1, 1.25, "hero")
    println(mixed.version())
    println(mixed.speed())
    println(mixed.name())
    println(Scalar(1.25).value())
    println(Small(1.25f).value())
}
```
