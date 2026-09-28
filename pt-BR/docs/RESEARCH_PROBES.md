# Sondas de pesquisa executadas

Data: 2026-09-22. Estes são experimentos restritos de CLI, não testes do mecanismo nem certificação gráfica.

## Ambiente e artefato

- Linux x86-64; OpenJDK 27 (`java -version`: build 27).
- `kof info --json`: Kof/compiler/runtime/stdlib 0.4.9, beta release 0.4.9-beta; `embeddedJdk: false`.
- [Jar de lançamento](https://github.com/KofLang/Kof4j/releases/tag/kof-0.4.9-beta-linux-x86_64), 42,090,580 bytes.
- SHA-256: `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`, verificado em relação aos metadados da API de lançamento.
- SDL3 do sistema: `pkg-config --modversion sdl3` → `3.4.16`; diretório da biblioteca `/usr/lib`.
- Cada comando teve um tempo limite de 60 segundos. DISPLAY, WAYLAND_DISPLAY e DBUS_SESSION_BUS_ADDRESS foram removidas dos ambientes dos processos filhos. **Nenhuma API de display, janela, servidor do editor ou GPU foi iniciada**; este não foi um teste gráfico. Limpar essas variáveis por si só não qualificaria como isolamento gráfico.
- Não foram executados testes em todo o repositório, recompilações do código-fonte nem uma matriz de displays. Nenhuma instalação do compilador ou configuração do usuário foi alterada.

## Invocação

Baixe o jar fixado e verifique seu hash. Defina `JAR` como esse arquivo. A compilação nativa também requer assembler/linker compatíveis e bibliotecas do sistema; este experimento usou a toolchain existente do host. Estes comandos descrevem o que foi exercitado, não um instalador portátil de dependências.

```sh
export JAVA_TOOL_OPTIONS=--enable-native-access=ALL-UNNAMED
java --enable-native-access=ALL-UNNAMED -jar "$JAR" info --json
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run core/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run core/main.kf --target native
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run ffi/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run ffi/main.kf --target native
java --enable-native-access=ALL-UNNAMED -jar "$JAR" check ffi_array/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" check ffi_array/main.kf --target native
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run module/main.kf --target jvm
java --enable-native-access=ALL-UNNAMED -jar "$JAR" run module/main.kf --target native
```

A invocação original do core usava `core.kf` antes de as outras sondas serem adicionadas. Posteriormente, os arquivos foram separados nos diretórios acima. As verificações originais do array usavam `ffi_array.kf`; o código-fonte não foi alterado. `JAVA_TOOL_OPTIONS` propagou o acesso nativo para as JVMs filhas; sua linha de diagnóstico padrão foi omitida da tabela de resultados.

## Resultados observados

| Sonda | JVM | Nativo x86-64 | Significado |
|---|---|---|---|
| Arrays mutáveis tipados + loop de método de classe + record + map + RNG com seed | exit 0; `-20`, `true`, `12`, `12`, `true` | igual | Esta forma de dados funciona; não é uma medição de desempenho |
| sqrt de libm + extern escalar da versão do SDL3 | exit 0; `3.0`, `3004016` | igual | Downcalls de biblioteca escalar funcionam; somente a versão do SDL, sem inicialização/renderização |
| Declaração de extern para array de float | exit 1; `FFI001` | exit 1; `FFI001` | A ABI de buffer não está implementada; rejeição esperada |
| Importação de diretório / função de combate separada | exit 0; `20` | igual | Esta forma de importação de múltiplos arquivos funciona |
| Vários pontos de entrada colocados lado a lado | exit 1; `PKG002` | igual | `run` coleta irmãos; o layout da sonda precisava de raízes separadas |

As execuções nativas bem-sucedidas emitiram o aviso:

```text
NativeBackend: runtime prune DESABILITADO (java.lang.IllegalStateException: NativeRuntime.java not found (run from the kof-compiler module)) — emitindo runtime completo (fallback seguro).
```

Esta é uma limitação real da distribuição de lançamento, não uma falha da sonda. A assembly completa emitida tinha aproximadamente 722–741 KB para esses programas minúsculos. Esse é o tamanho do código-fonte da assembly, **não o tamanho do executável**. Nenhuma solução alternativa de pruning foi usada.

Diagnósticos exatos da fronteira rejeitada (nome de arquivo original):

```text
ffi_array.kf:1:1: error: extern 'upload' in /tmp/not-loaded.so: FFI binding not implemented on the JVM target yet (FFI001) [FFI001]
ffi_array.kf:1:1: error: extern 'upload' in /tmp/not-loaded.so: FFI binding not implemented on the NATIVE target yet (FFI001) [FFI001]
```

A sonda de array foi verificada, não executada; ela não tentou carregar a biblioteca nomeada. Uma execução inicial de FFI escalar falhou antes da geração de código porque três irmãos `.kf` declaravam main cada um:

```text
:0:0: error: module has 3 main() functions; expected exactly one [PKG002]
```

Mover cada sonda independente para seu próprio diretório de entrada fez com que o código-fonte escalar inalterado fosse executado com sucesso. Isso distingue um erro de layout do módulo do suporte a FFI.

## Códigos-fonte completos das sondas

### `core/main.kf`

```kof
record Hit(Int amount, Float fraction)

class Pool {
    Float[] positions
    Int[] health
    constructor(Int count) {
        this.positions = new Float[count]
        this.health = new Int[count]
    }
    void step(Float dt) {
        for (var i = 0; i < 4; i++) {
            positions[i] = positions[i] + dt * 120.0f
            health[i] = health[i] - 1
        }
    }
}

main() {
    var pool = Pool(4)
    for (var i = 0; i < 4; i++) { pool.health[i] = 100 }
    for (var tick = 0; tick < 120; tick++) { pool.step(0.008333334f) }
    var hit = Hit(12, 0.5f)
    println(pool.health[0])
    println(pool.positions[0] > 119.0f && pool.positions[0] < 121.0f)
    println(hit.amount())
    var totals: Map<String, Int> = mapOf("damage", 12)
    println(totals.get("damage"))
    rng.seed(42)
    var first = rng.int(1000)
    rng.seed(42)
    println(first == rng.int(1000))
}
```

### `ffi/main.kf`

```kof
extern "/usr/lib/libm.so.6" sqrt(Double value): Double
extern "/usr/lib/libSDL3.so" SDL_GetVersion(): Int
main() {
    println(sqrt(9.0))
    println(SDL_GetVersion())
}
```

### `ffi_array/main.kf`

```kof
extern "/tmp/not-loaded.so" upload(Float[] values): void
main() {
    var values = new Float[4]
    upload(values)
}
```

### `module/main.kf`

```kof
import sim
main() {
    println(damageAfterArmor(25, 5))
}
```

### `module/sim/combat.kf`

```kof
package sim
Int damageAfterArmor(Int damage, Int armor) {
    return if (damage > armor) damage - armor else 0
}
```## Não estabelecido

- Inicialização real de vídeo/GPU/áudio do SDL a partir do ELF nativo do Kof; compatibilidade com o runtime C/TLS/driver.
- Suporte a FFI de ponteiros/estruturas/arrays, retenção de callbacks ou transferência segura sem cópia.
- Tempos de quadro do shooter, throughput de FFI, segurança do coletor em execução prolongada ou platô de memória.
- Suporte a executáveis nativos multiplataforma, paridade entre arquiteturas, paridade do runtime JS.
- Instalação do Kof Editor, operação visual, integração com depurador ou exploração de segurança.
- Jogos encontrados online executando corretamente nesta versão do compilador.

Esses pontos continuam sendo gates explícitos de implementação em [ENGINE_PLAN](ENGINE_PLAN.md). O adaptador SDL proposto e todas as APIs de engine propostas não foram implementados; nenhum esqueleto de engine foi criado durante a pesquisa.

## Experimentos subsequentes orientados pelo curso

[COURSE_PROBES](COURSE_PROBES.md) adiciona 18 programas/38 invocações sobre o mesmo artefato: funções, matemática, coleções, arrays, E/S de bytes/intervalos, JSON, exceções e uma solução inalterada de fila do curso. Ele registra falhas nativas assim como sucessos, incluindo um manipulador de exceções obsoleto e JSON corrompido de registros mistos. Os resultados originais acima permanecem inalterados; eles nunca estabeleceram esses contratos mais abrangentes.