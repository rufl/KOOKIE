# Experimentos de compilador orientados pelo curso

Data da pesquisa: 2026-09-22. Complemento de [KOF_COURSE](KOF_COURSE.md).

## Escopo e reprodução

Estes são 18 pequenos programas-fonte: uma solução inalterada do curso e 17 sondas focadas, executados por meio de 36 invocações de `run` e duas de `check`. Isto não é uma execução de testes de todo o curso nem uma matriz de plataformas. Somente JVM e Linux nativo x86-64 foram exercitados. Nenhum servidor, demonstração de processo, banco de dados, GUI, scanner de rede ou superfície gráfica foi iniciado.

O artefato do compilador, SHA-256, JDK, ambiente e o aviso de runtime completo/poda nativa permanecem inalterados em relação a [RESEARCH_PROBES](RESEARCH_PROBES.md). Cada comando foi executado serialmente com um tempo limite de 60 segundos. Ambas as execuções-alvo da sonda de bytes produziram os bytes de arquivo inspecionados independentemente `00 7f 80 ff`; o arquivo foi removido entre as execuções.

Coloque cada fonte abaixo em seu próprio diretório como `main.kf`; `run` coleta os arquivos irmãos. A partir desse diretório, com o caminho verificado do jar em `JAR`:

```sh
export JAVA_TOOL_OPTIONS=--enable-native-access=ALL-UNNAMED
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run main.kf --target native
```

Para `reduce-seed-first`, `check` foi executado em ambos os alvos antes dos dois comandos `run`. O `check` bem-sucedido, por si só, não foi tratado como prova de execução. Os caminhos temporários gerados pelo compilador e os tamanhos dos assemblies são incidentais, não resultados de desempenho.

## Resultados observados

A tabela registra os códigos de saída reais e o stdout, incluindo programas com falha e programas enganosamente bem-sucedidos. Os pequenos valores Double não nulos nativos de `json-observe` abaixo correspondem a uma execução observada, não a valores esperados estáveis. Eles não devem ser transformados em saídas de referência. Os avisos padrão de `JAVA_TOOL_OPTIONS` e os diagnósticos de geração/poda nativa são omitidos aqui, não suprimidos durante a execução.

| Fonte | Comando | Alvo | Saída | stdout observado |
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

`assert-trap`, `assert-after-catch` e `assert-false` na JVM também emitiram `java.lang.RuntimeException` no stderr com, respectivamente, `correctly rejects no throw`, `expected failure` e `expected failure`.

## Interpretação e limites

- `functions`: sobrecargas de aridade, argumentos padrão, mutação visível por meio de uma captura e uma lambda aninhada funcionaram nessas formas. Isso não prova que toda combinação de closure/tipo funcione ou seja livre de alocações.
- `numeric`: o campo Long comparado com o literal Int e um resultado de método Double descartado funcionaram. Os built-ins Double `math.sqrt`, `math.lerp` e `math.pow` retornaram os valores esperados. Nenhuma alegação ampla de precisão/desempenho numérico.
- `collections`: reduce com callback primeiro, tamanho do método map, zero presente versus null ausente funcionaram antes da divisão. A divisão nativa por pipe escapado retornou um elemento, e então o segundo elemento indexado deliberadamente causou um erro fatal de limites.
- `split`: o regex da JVM e o comportamento nativo de delimitador de um único caractere diferem. Uma vírgula simples funcionou em ambos; isso não estabelece paridade geral de `split`.
- `reduce-seed-first`: a ordem seed-first do curso também foi executada com sucesso. Não a “corrija” somente porque outra lição oficial usa callback-first.
- `matrix`: alocação, comprimentos aninhados, inicialização com zero e uma escrita/leitura de Int 2D funcionaram. Isso não estabelece um layout contíguo de buffer externo.
- `bytes`: `File.writeBytes/readBytes/readRange(1, 2)` de instância preservou bytes zero/de bit alto. Arquivos ausentes, intervalos negativos, entradas grandes, substituição atômica/durabilidade e preparação de biblioteca nativa permanecem sem teste.
- `record-float`: getters diretos de registro com campos mistos/Double/Float funcionaram. Portanto, a falha de JSON abaixo não pode ser descartada como se todo registro de ponto flutuante estivesse quebrado.
- `json`: uma ida e volta de registro misto Int/Double/String falhou em sua asserção de valor fracionário no native. `json-observe` mostrou Double codificado incorreto, Double decodificado incorreto e nome decodificado vazio. A decodificação independente de um literal também produziu um Double incorreto. Isso impede confiar nessa forma de serialização nativa; não prova que toda a API JSON esteja quebrada.
- `finally`: a limpeza foi executada antes de um retorno e durante a propagação explícita de um throw de String. `bounds` demonstra um caminho nativo fatal separado que não executou catch/finally nem continuou.
- `assert-trap`: colocar `assert(false)` dentro da região de catch sob teste pode capturar a própria falha do teste. Pior ainda, simplesmente mover a asserção para depois de um try/catch concluído normalmente não tornou o teste nativo confiável.
- `assert-after-catch`: o native imprimiu `false`, depois `true` após a asserção falha, e chegou a `unreachable` com saída 0. A asserção após o try foi tratada pelo catch anterior. A JVM falhou com saída 1. `assert-false` falhou corretamente em ambos sem o try anterior. `catch-state` mostra que o caminho normal não entrou em seu catch antes de um throw posterior. Isso restringe o problema a um defeito no tempo de vida do tratador de exceções nativo; nenhuma correção do compilador foi tentada.
- `catch-return`: retornos explícitos dentro de ambos os ramos produziram o resultado false esperado. Este é um controle diagnóstico, não uma solução alternativa recomendada para todo o mecanismo para o tratamento defeituoso de exceções.
- `queue-course`: o exemplo inalterado do curso imprimiu a ordem FIFO em ambos os alvos. Ele não testou overflow, underflow, reutilização após wraparound ou throughput sustentado.O mecanismo deve comparar valores observáveis e caminhos de falha, não contar saídas verdes. O tratamento nativo de exceções precisa ser corrigido/revalidado antes de confiar na limpeza ou nas asserções de exceção. O JSON de ponto flutuante precisa de sua própria correção/prova de esquema antes da persistência/importação de conteúdo. Essas investigações não implementaram o mecanismo nem modificaram o compilador/curso.

## Fontes executadas completas

As fontes são reproduzidas exatamente, incluindo a asserção intencionalmente incorreta e os casos com falha. Não copie esses padrões para a produção.

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

Inalterado [course solution 16-fila-circular.kf](https://github.com/lunalully/curso-completo-de-kof/blob/d6fc8318e77f30ab0d6be87055d86a7eb63960d3/02-estruturas-de-dados/solucoes/16-fila-circular.kf). A atribuição/licença do curso upstream se aplica; esta é uma reprodução para pesquisa, não o código-fonte do mecanismo.

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
```### `reduce-seed-first/main.kf`

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