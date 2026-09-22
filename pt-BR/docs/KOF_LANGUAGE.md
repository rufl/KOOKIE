# Referência da linguagem e do runtime Kof para KOOKIE

Data da pesquisa: 2026-09-22. Esta é uma referência de trabalho, não uma afirmação de conformidade completa com a linguagem.

## Base de evidências

- Código-fonte do compilador: [`KofLang/Kof4j@22a186b9bf9df37c03809ba6ef4af85085386f63`](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63), `VERSION` = `0.4.9-beta`.
- Artefato executado: [versão Linux, 0.4.9-beta, publicada em 2026-09-20](https://github.com/KofLang/Kof4j/releases/tag/kof-0.4.9-beta-linux-x86_64), `kof-cli-0.4.9-beta.jar` independente.
- SHA-256 do Jar: `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`, correspondente aos metadados do ativo da versão do GitHub antes da execução.
- O README do repositório obtido informa 0.4.0-beta; [o site](https://koflang.github.io/) informa 0.4.1-beta. Nenhum dos dois identifica a versão realmente medida aqui.
- **Medido** significa executado localmente; **verificado no código-fonte** significa lido na implementação fixada; **afirmação upstream** significa documentado, mas não exercitado de forma independente. O comportamento proposto do mecanismo é explicitamente uma decisão, não um recurso do Kof.
- [Sondagens iniciais](RESEARCH_PROBES.md) e [sondagens orientadas pelo curso](COURSE_PROBES.md) preservam fontes, comandos, saída e limitações completas. [Análise aprofundada do curso](KOF_COURSE.md) reconcilia o curso fornecido e a documentação oficial. Somente JVM/native x86-64 foram exercitados; nenhuma prova em navegador, gráficos nativos, arquiteturas diferentes ou de longa duração foi realizada.

## O que é a linguagem

Kof é uma linguagem estaticamente tipada e de propósito geral, com seu próprio lexer, parser, análise semântica e IR linear baseado em pilha. Bytecode JVM, assembly/ELF nativo e módulos JavaScript são saídas de backends; o Kof do usuário não é traduzido para Java e depois compilado com javac. A implementação do compilador e o suporte de runtime gerado realmente usam Java. Não confunda essas afirmações.

A extensão dos fontes é `.kf`. KofScript `.ks` compartilha o frontend e executa o IR diretamente; não é JavaScript. KofC é um compilador separado de um subconjunto de C, não um caminho para transformar bibliotecas C em código do mecanismo Kof.

Para este projeto, **fonte nativa de Kof** significa lógica de mecanismo/jogo/ferramenta escrita em `.kf`; **destino nativo** significa o backend ELF do Linux. A execução na JVM ainda pode executar um mecanismo criado em Kof, mas não é o destino nativo de distribuição proposto.

## Sintaxe prática

| Intenção | Forma real / ressalva |
|---|---|
| Ponto de entrada | `main() { ... }`; exatamente um por módulo. Não `Int main()` |
| Vinculação mutável / fixa | `var n = 1`; `val n = 1`; também `Int n = 1` ou `var n: Int = 1` |
| Função | `Int damage(Int raw, Int armor) { return raw - armor }` ou `damage(Int raw): Int { ... }` |
| Corpo de expressão | `Int twice(Int x) = x * 2` |
| Padrões / sobrecargas | `String greet(String who = "world")`; mesmo nome com assinaturas distintas de parâmetros. Ambos medidos |
| Condição como valor | `var x = if (condition) a else b`; não há ternário de C |
| Laço | `while (condition) { ... }`, `for (var i = 0; i < count; i++) { ... }` |
| Laço de coleção | `for (var item in items) { ... }`; `var` é obrigatório |
| Objeto mutável | `class Pool { Int count; constructor(Int count) { this.count = count } }` |
| Dados imutáveis | `record Hit(Int amount, Float fraction)`; acesso com `hit.amount()` |
| Chamada de construtor | `Pool(4)`; `class X(...)` é no estilo de record, não um construtor primário mutável comum |
| Array de tamanho fixo | `var xs = new Float[count]`; `xs[i] = value` |
| Array multidimensional | `new Int[2][3]`; indexação/comprimentos aninhados medidos. Não é uma garantia externa de buffer contíguo |
| Lista | `var xs: List<Int> = listOf(1, 2)`; `add`, `get`, `set`, `remove(index)`, `.size` |
| Mapa / conjunto | `mapOf("key", 1)`; `setOf("a", "b")`; tipos de elementos homogêneos |
| Lambda | `(x: Int) -> x + 1`; capturas mutáveis são boxed; use parâmetros explícitos |
| Valor de função a partir de uma função | Envolva em uma lambda; não presuma referências `twice` / `::twice` simples |
| Erro | `throw "message"`; `catch (String e)`; `finally` |
| Verificação de nulo | `String? value = map.get(key)` seguida por `if (value != null)` |
| Igualdade de strings | `==` compara conteúdo; concatene com `+` |
| Conversão | `value as Float`, `longValue as Int`; valide reduções de tipo nas fronteiras |
| Concorrência | `val task = spawn compute()`; `var result = await task` |
| Testes | `test "name" { assert(condition, "message") }`; `kof test` |
| Interoperabilidade nativa | `extern "/path/lib.so" symbol(Int x): Int` |

Pontos e vírgulas são opcionais nas formas comuns; os exemplos acima são fragmentos esquemáticos, a menos que estejam incluídos nas sondagens executadas. Use a gramática formal quando uma declaração for ambígua.

### Não importe hábitos de outras linguagens

- Não há `fun`, `fn`, `func`, `let`, `const`, `async` no estilo JS, intervalo `0..n`, literal de array `[1, 2]`, `?.`/`?:`/`!!` do Kotlin, argumentos nomeados, aliases de importação, traits ou macros.
- Não há `var`/`val` comuns no nível superior em `.kf`; coloque o estado dentro de um objeto de estado explícito, não em globais acidentais. O encapsulamento de scripts é um modo de execução diferente.
- Não há interpolação automática de strings `${expression}`. Ela permanece como texto literal.
- Tipos primitivos não expõem `Int.MAX_VALUE` no estilo Java; use limites explícitos.
- Não presuma que todos os métodos de coleções Java existam. Em particular, a remoção de listas é feita por índice, e `add(index, value)` posicional não é a API documentada.
- `val` fixa uma vinculação, não a imutabilidade profunda do objeto ao qual ela faz referência.
- `record` é armazenamento imutável/de referência com igualdade por conteúdo, **não** uma struct C/value compactada garantida. Evite alocar records de vetores em loops internos.
- `entity` é um recurso de ORM/dados, não um ECS de jogo integrado.

Fontes: [sintaxe](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/syntax.md), [gramática](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/grammar.md), [classes](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/classes.md), [anti-idiomas](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/training/anti-patterns/fake-idioms.md). A própria página de anti-idiomas contém linhas desatualizadas; ela é uma orientação, não um oráculo.## Tipos e semântica relevantes para um mecanismo

- Larguras numéricas primitivas: `Byte`/`Short`/`Int`/`Long` com sinal = 8/16/32/64 bits; `Float`/`Double` = 32/64 bits IEEE-754. `Char` é uma unidade de código UTF-16. Não há uma família de inteiros sem sinal.
- Use `Float[]`, `Int[]` e `Long[]` explicitamente tipados para o estado crítico. Genéricos são apagados; contêineres genéricos podem encapsular primitivos. Não se deve presumir que o armazenamento de arrays corresponda ao layout de memória de C nem expô-lo convertendo um identificador.
- Classes comuns são comparadas por identidade; strings/registros são comparados por conteúdo. Argumentos de objetos/coleções copiam uma referência, não o conteúdo.
- O estouro aritmético não é um contrato de jogabilidade verificado. Proteja contagens de inventário, moeda, indexação e tamanhos de salvamento; use a aritmética de PRNG especificada em vez de depender do estouro acidental do host.
- `Option`/`Result` genéricos e uniões discriminadas não estão disponíveis como recursos integrados. Use registros/classes/enums explícitos e transições de estado verificadas.
- A nulabilidade mudou recentemente. O literal `= null` é rejeitado (`SEM048`), enquanto null pode chegar por meio de APIs. `Bool?` é rejeitado (`SEM095`); `Troolean` é um recurso separado de três valores. Não use primitivas anuláveis para codificar ocupação em caminhos críticos; sinalizadores ativos explícitos e IDs de geração são mais claros. Teste qualquer novo padrão de campo anulável/genérico.
- A ordem de iteração de mapas/conjuntos não é especificada. Use IDs estáveis de entidades/itens e processamento ordenado ou explicitamente classificado para replays, salvamentos e espólios.
- Os resultados de ponto flutuante podem diferir entre alvos; não prometa lockstep multijogador com bits idênticos entre alvos.
- `rng.seed`/`rng.int` existem; a reprodutibilidade após redefinição da semente foi medida. Para fluxos separados de espólios/combate/IA, implemente estado explícito de RNG por fluxo em `.kf`; não acople tudo à sequência global integrada.
- Exceções são strings. Mantenha falhas normais, pools esgotados e consultas sem colisão como resultados comuns, não como fluxo de controle orientado por exceções. **Defeito nativo medido:** um try/catch concluído normalmente deixou um manipulador ativo para uma asserção falha posterior. Falhas nativas de limites ignoraram completamente catch/finally. Sondagens bem-sucedidas de limpeza com throw/return explícitos não substituem essas falhas; consulte [reproduções](COURSE_PROBES.md).

Fontes: [tipos](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/types.md), [semântica](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/semantics.md), [sistema de tipos](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/type-system.md), [módulos/RNG](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/modules.md).

## Módulos, compilação e dependências

Uma unidade de código-fonte pode declarar `package sim`; `import sim` pode expandir o diretório correspondente à raiz do módulo. Importações de tipos específicos e importações de diretórios/pacotes têm regras de qualificação diferentes. Não presuma a semântica de curingas do Java nem importações com alias.

**Medido:** um arquivo de entrada que importava `sim/combat.kf` foi executado em ambos os alvos e imprimiu `20`. **Também medido:** `kof run file.kf` coletou arquivos de entrada irmãos e rejeitou três funções `main()` (`PKG002`). Coloque jogo, cooker, testes e demos em raízes de entrada separadas; scripts que combinam fontes não são a arquitetura modular padrão.

Comandos da CLI de lançamento:

```sh
kof version
kof info --json
kof check path/to/main.kf --target native
kof build path/to/main.kf --target native --output build/native
kof run path/to/main.kf --target native
kof run path/to/main.kf --target jvm
kof inspect path/to/main.kf --json
kof profile path/to/main.kf --target native
kof lsp
```

`kof check` atualmente invoca a compilação completa em um diretório temporário e exclui sua saída; não é uma operação apenas de frontend, apesar do texto do curso/documentação ([CmdCheck.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdCheck.java#L78-L107)). A verificação nativa emitiu assembly em nossa sondagem. Ela ainda não prova que o código gerado seja executado. `run` coleta arquivos irmãos; `test` compila arquivos independentemente. `inspect` usa o caminho da JVM, não a inspeção de tamanho/desempenho do código nativo.

`kof deps` é um MVP de gerenciador de pacotes upstream, não evidência de um registro maduro de pacotes gráficos. Fixe explicitamente o compilador, as versões das bibliotecas, o compilador de shaders e os checksums. Investigue a configuração do projeto/raiz do módulo antes de finalizar o layout de múltiplas entradas proposto em ENGINE_PLAN.

**Limite medido da biblioteca Java:** com `kofdeps` declarando `org.joml:joml:1.10.9`, `run main.kf --target jvm --deps` executou o cálculo real de comprimento/produto escalar de vetor JOML e a translação de matriz. Um cache isolado `-Dkof.deps.home=...` forneceu o JAR verificado por hash. A mesma fonte com `--target native --deps` rejeitou ambas as importações Java com `PKG006`. O código-fonte completo, os comandos, os hashes dos artefatos e a saída estão em [MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md). Isso não estabelece execução nativa de JARs, suporte geral a JNI nem interoperabilidade com callbacks/construtores genéricos.

A distribuição completa inclui um JDK. O `pom.xml` do código-fonte exige a versão 25 do Java. O jar independente foi exercitado usando OpenJDK 27, não o runtime incluído. Não infira que programas gerados e o suporte de runtime emitido precisem apenas do Java 21 simplesmente porque a geração de bytecode usa uma linha de base V21.

**Defeito de empacotamento observado:** a execução nativa a partir de um diretório não relacionado avisou `NativeRuntime.java not found (run from the kof-compiler module)` e emitiu o runtime completo em vez de podá-lo. As sondagens ainda foram aprovadas. Não divulgue números upstream de binários pequenos para uma compilação KOOKIE empacotada até que esse caminho seja medido ou corrigido.

As ferramentas incluem comandos de formatação, diagnóstico, inspeção de IR, criação de perfis, LSP e depuração. O upstream agora documenta DAP para JVM/nativo, GDB/MI e DWARF; a presença desses recursos da CLI não implica que o Kof Editor os conecte à sua interface. Consulte [KOF_EDITOR](KOF_EDITOR.md).

A instalação local agora inclui uma compilação persistente do compilador com correções de protocolo
LSP/DAP com escopo definido e um cliente MrCode real. Seus fluxos de trabalho medidos e
limitações restantes estão registrados em [ferramentas locais](KOF_EDITOR.md#local-installation).
Esses reparos não alteram as descobertas abaixo sobre o runtime nativo.## Adequação dos alvos

| Alvo | Evidência / decisão sobre o mecanismo |
|---|---|
| JVM | As sondagens medidas de núcleo/importação/FFI escalar passam. Oráculo diferencial útil e possível fallback explicitamente escolhido. A interoperabilidade com classpath Java existe; há precedente de jogo com Jaylib |
| Nativo x86-64 | As mesmas sondagens medidas passam; mecanismo Linux preferido para o protótipo. Janela SDL completa/GPU/entrada/áudio e comportamento de memória de longa duração ainda são requisitos |
| Nativo RISC-V / AArch64 | Backend real e suporte a FFI escalar nas fontes/documentação fixadas, não placeholders. Não executado aqui; não é um compromisso inicial de distribuição |
| JS / KofJS | Módulos ES com recursos de host GraalJS incorporados. O navegador possui um conjunto diferente de capacidades de host; `extern` não pode simplesmente acessar bibliotecas nativas nele |
| Android | Caminho de empacotamento derivado da JVM; não é uma portabilidade nativa para desktop nem um alvo inicial |
| Script | Exploração útil de ferramentas; não é o runtime de jogo em tempo real |

Uma distribuição do compilador para Windows/macOS **não** comprova saída nativa PE/Mach-O. Os alvos nativos examinados são arquiteturas Linux ELF. A distribuição multiplataforma de jogos exige comprovação separada; não prometa isso apenas com base na portabilidade do SDL.

## FFI: utilizável agora, incompleto para gráficos

**Medido:** esta versão executa chamadas escalares `extern` na JVM e em x86-64 nativo. Chamar `sqrt(9.0)` da libm retornou `3.0`; chamar `SDL_GetVersion()` do SDL3 instalado retornou `3004016` (3.4.16).

Conjunto escalar verificado na fonte: `Int`, `Long`, `Float`, `Double`, `Bool`/`Boolean`, `String`; `void` também é permitido como retorno. O nome da declaração Kof é o símbolo C; não há alias. O nativo exige uma string de biblioteca e faz a ligação por uso com uma chamada ABI direta, não com `dlopen` em tempo de execução.

**Limitação medida:** `extern ... upload(Float[] values): void` é rejeitado com `FFI001` tanto na JVM quanto no nativo. O mecanismo escalar não expõe ponteiros C arbitrários, structs, arrays, buffers de saída ou variádicas. Retornar ponteiros SDL como `Long` não é um substituto portátil compatível.

Callbacks da JVM/host-JS são documentados para chamadas síncronas que não escapam; callbacks nativos são rejeitados. Uma biblioteca C que retenha um callback além da chamada descendente está fora desse contrato de tempo de vida. Prefira um loop de consulta controlado pelo mecanismo e áudio enfileirado, não callbacks estrangeiros para dentro do Kof.

Consequências:

1. APIs escalares diretas podem ser chamadas diretamente; não as envolva sem necessidade.
2. Uniões de eventos SDL, descritores de GPU, ponteiros de recursos nativos e buffers de upload precisam de um **pequeno adaptador de ABI C** até que o Kof adquira a interoperabilidade correspondente.
3. Exporte **tokens inteiros de registro**, não conversões de ponteiros; valide tipo/geração/limites, copie strings imediatamente e libere recursos explicitamente.
4. Mantenha no Kof a simulação, colisão, travessia da cena, culling, ordenação, materiais, seleção de passes, animação, semântica de assets e ferramentas. O código do adaptador faz o marshalling; ele não se torna o mecanismo.
5. O caminho de dados em massa é um requisito explícito de desempenho. O staging escalar pode comprovar a correção; ele não estabelece um tempo de quadro aceitável para geometria/instanciamento dinâmicos.
6. A integração de `_start`/runtime C exige comprovação real da inicialização da biblioteca gráfica. Uma consulta de versão não comprova que os caminhos da biblioteca que usam intensivamente alocador/TLS/threads funcionam.

Fontes: [CompilerPipeline.java:457–495](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/CompilerPipeline.java#L457-L495), [FfiSignature.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/FfiSignature.java), [testes de FFI nativo](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/test/java/dev/kof/compiler/FfiNativeE2ETest.java), [contrato de interoperabilidade de módulos](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference/modules.md#L128-L175).

## Riscos de memória e desempenho

O código-fonte x86 atual é mais útil do que a visão geral de memória mais antiga:

- Objetos nativos usam alocação gerenciada pelo Kof e um coletor conservador. `RuntimeMemory` verifica a lista livre, tenta a coleta e, em seguida, usa `mmap`.
- **Verificado na fonte:** a coleta automática quando a lista livre se esgota é condicional ao `kof_spawn_count == 0` cumulativo. Depois que o processo usa `spawn` do Kof, esse gate permanece fechado porque as pilhas dos workers não são examinadas. `await` não redefine o contador.
- Ainda não agende jobs nativos do Kof nem chame o GC manual em torno de estado ativo de workers para contornar o gate. Comece com uma thread de simulação/renderização do Kof. As próprias threads de áudio/driver de uma biblioteca podem operar somente sobre a memória que lhes pertence, sem reter ponteiros do heap do Kof nem chamar código Kof.
- Pré-aloque arrays de entidades, buffers de eventos, memória temporária de colisão e listas de renderização. Não faça alocação de classes por projétil, criação de lambdas transitórias, registro de strings ou churn de coleções genéricas no loop de quadros.
- O código-fonte do otimizador lista folding constante, eliminação de efeitos mortos, alcançabilidade e limpeza de saltos. Ele não é um pipeline de otimização da classe do LLVM. `as` e `ld` não fornecem otimização de alto nível de loops/vetorização. O nativo não é automaticamente mais rápido que o JIT da JVM.
- Pequenas sondagens estabelecem a viabilidade da linguagem, não um orçamento de FPS ou um platô de memória. Exija um soak limitado de alocação/GC e temporização de jogabilidade representativa antes de se comprometer com grandes multidões.
- Não fixe os layouts internos de objetos/cabeçalhos/arrays com base na documentação. A página MEMORY_MODEL mais antiga ainda descreve um cabeçalho de alocação de 16 bytes, enquanto o código atual do alocador adiciona 32 bytes.

Fontes: [RuntimeMemory.java:71–185](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeMemory.java#L71-L185), [RuntimeConcurrency.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeConcurrency.java), [otimizador](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/backend/Optimizer.java#L34-L97).## Limites da biblioteca padrão

As superfícies relevantes incluem coleções, JSON, arquivos/caminhos/diretórios, matemática, tempo, RNG, configuração/logging, processos, concorrência e testes. Use a biblioteca padrão de alto nível apenas para caminhos frios, depois de verificar o comportamento do alvo.

As medições orientadas pelo curso estabelecem pequenas operações de instância `File.writeBytes/readBytes/readRange` com bytes zero/de bit alto incorporados, `Double` `math.sqrt/lerp/pow`, ambas as ordens de argumentos de `List.reduce`, `.size()` em um mapa e valores nulos ausentes versus valores zero presentes no mapa. Use a matemática integrada em vez de manter a solução histórica de Newton para raiz quadrada do curso.

**Não presuma paridade da biblioteca padrão:** o JSON nativo de registros fracionários com campos mistos corrompeu valores no formato medido; `split("\\|")` de regex da JVM e a divisão nativa retornaram resultados diferentes. Essas são verificações de correção de conteúdo/salvamento, não razões para usar a JVM silenciosamente. A busca de `Map` nativo percorre as chaves linearmente ([RuntimeEnum.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/runtime/RuntimeEnum.java#L109-L157)); a complexidade didática de O(1) de uma tabela hash não é a complexidade medida nem derivada do código-fonte.

`kof.ui` é uma API voltada para UI/Canvas, não um renderizador de jogos 3D. Os jogos Kof existentes complementam a entrada ausente do navegador com JavaScript. A disponibilidade de `kof.media` não comprova áudio posicional de baixa latência.

`kof.gpu` é uma integração especializada com **compute** do Vulkan (chamadas de matriz/matvec), não um renderizador de swapchain/material/malha. Seu código-fonte descreve explicitamente stubs nativos de fallback e rejeição em JS; não o proponha como a camada gráfica nativa do KOOKIE. [KofGpu.java](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofGpu.java).

## Licenciamento

O compilador/ferramentas Kof e o Kof Editor são GPLv3. O upstream declara explicitamente que programas Kof escritos pelos usuários podem usar sua própria licença e não precisam se tornar GPL somente pelo uso do compilador: [LICENSING.md](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/distribution/LICENSING.md).

Mantenha a declaração do upstream junto ao registro da versão. Redistribuir modificações do compilador/editor, incorporar componentes do runtime, copiar código-fonte de jogos/irmãos e incluir assets são questões separadas. Revise o material exato incorporado e os avisos antes da distribuição; este documento não concede uma nova licença nem uma autorização jurídica.

## Como atualizar este conhecimento

1. Fixe o SHA do código-fonte e o hash do executável separadamente; não execute um `lib/kof.jar` antigo e não explicado a partir de um checkout do código-fonte.
2. Leia `VERSION`, os metadados da versão, as alterações na referência da linguagem e o código-fonte de FFI/alocador antes de acreditar nas tabelas da página inicial.
3. Execute novamente apenas as sondagens focadas afetadas por uma atualização do compilador; adicione a carga de trabalho real do mecanismo assim que ela existir.
4. Registre resultados e falhas em RESEARCH_PROBES em vez de substituir observações históricas por afirmações atuais.
5. Use o [curso humano](https://koflang.github.io/learn), o [corpus de treinamento](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63/training) e a [referência formal](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/language-reference) em conjunto. Resolva divergências com a implementação fixada e a execução.