# Sistemas do Minecraft Java moderno: reutilização com Kof

Data da pesquisa: **2026-09-22**. Esta é uma avaliação de bibliotecas/arquitetura, não um engine implementado nem uma comparação de desempenho medida. Linux nativo x86-64 e comportamento de CPU pertencente ao Kof continuam sendo a baseline em [ENGINE_PLAN](ENGINE_PLAN.md). A propriedade estrangeira de ECS/GUI/física é uma alternativa possível que exige aprovação explícita; esta pesquisa não a aprova silenciosamente.

**Melhores candidatos imediatos:** ports seletivos sob MIT da matemática do JOML e do Brigadier; armazenamento Kof inspirado em Artemis/Ashley; definições/componentes/codecs de conteúdo no estilo Minecraft; layout inspirado em owo; ciclos de vida de instâncias inspirados em Flywheel; um único backend nativo de áudio. Jolt é o atalho mais forte avaliado se a propriedade da física estrangeira for aceita. RmlUi e Dear ImGui também reduzem trabalho de UI se a propriedade estrangeira de widgets/layout for aceita.

## 1. Baseline atual, não uma stack da era 1.21

O [manifesto oficial de versões](https://piston-meta.mojang.com/mc/game/version_manifest_v2.json) identificou a **Java Edition 26.3**, lançada em **2026-09-15**, como a mais recente no momento da pesquisa. Os [metadados exatos da versão](https://piston-meta.mojang.com/v1/packages/96c00d95a31328714d3811cfade2804bb050e455/26.3.json) baixados corresponderam ao SHA-1 `96c00d95a31328714d3811cfade2804bb050e455`; eles especificam Java **25**, `java-runtime-epsilon`. Nenhum JAR de cliente/servidor nem asset do Minecraft foi baixado ou executado.

Dependências nomeadas nesses metadados:

| Dependência | Versão distribuída | O que isso estabelece |
|---|---|---|
| JOML | 1.10.9 | Dependência Java autônoma de matemática |
| Brigadier | 1.3.11 | Parser/dispatcher autônomo de comandos |
| DataFixerUpper | 10.0.21 | Biblioteca de codecs/migração de schemas |
| Módulos LWJGL | 3.4.3 | Core, **SDL**, OpenAL, OpenGL, Vulkan, FreeType, STB, ShaderC, SPVC, VMA, jemalloc |
| fastutil | 8.5.18 | Coleções primitivas Java, não um ECS |
| ICU4J | 78.3 | Serviços de Unicode/texto, não um toolkit de GUI |
| Netty | 4.2.16.Final | Bibliotecas de rede, não semântica de replicação do jogo |
| JOrbis | 0.0.17 | Dependência Java de Vorbis, não um engine de áudio completo |
| text2speech | 1.19.12 | Integração de narração, não áudio posicional |
| `at.yawk.lz4:lz4-java` | 1.10.1 | Binding/biblioteca de compressão Java, não schema de salvamento |

Não há dependência nomeada de Ashley, Artemis, Dominion, Bullet, Jolt ou PhysX. A ausência de uma dependência, sozinha, não prova a arquitetura interna de entidades/física.

### Mudanças materiais atuais

- **SDL3 substitui GLFW** para janela, entrada e integração de plataforma. Bindings físicos de gameplay usam scancodes SDL; atalhos de edição de texto usam keycodes; o modo de mouse do gameplay é sempre relativo. Isso apoia a escolha existente de SDL3, mas **não significa que o Minecraft use SDL_GPU**. [Release oficial 26.3](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-3).
- OpenGL **e Vulkan são implementados**. As [notas da versão 26.2](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-2) introduziram o Vulkan experimental e disseram que Default significava Prefer OpenGL. A 26.3 trata os dois backends e ShaderC para ambos; o default de runtime não foi exercitado independentemente aqui. O [anúncio anterior do Vulkan](https://www.minecraft.net/en-us/article/another-step-towards-vibrant-visuals-for-java-edition) sozinho não prova um backend ativo.
- O **guia de migração vanilla 26.2→26.3** identifica uma separação da API de renderização, de Blaze3D para **Renderpearl** (`api`, `backend`, `frontend`). Outros auxiliares de Blaze3D permanecem. Separar um pacote não prova uma licença open source reutilizável. [Primer NeoForge 26.3](https://docs.neoforged.net/primer/docs/26.3/).
- O terreno usa MultiDrawIndirect nos dispositivos suportados, com caminhos de draw separado ainda descritos. Improved Transparency usa OIT aproximado; a Mojang alerta para artefatos e custo adicional potencial. Nenhum recurso é pré-requisito para este engine FPS.
- A versão do data pack é **121.0** e a do resource pack é **97.1**. Vários formatos de predicado/loot/provider mudaram; não implemente o sistema atual copiando exemplos JSON da 1.21 sem revisão.

**Limites da evidência:** páginas de prosa não versionadas do Fabric lidas aqui se identificam como **26.2**; várias páginas conceituais do NeoForge são **26.1**. Notas exatas da 26.3 e referências versionadas da Fabric API são usadas quando disponíveis. APIs de mapeamento antigas da 1.21.8 abaixo são explicitamente históricas, não uma auditoria completa da fonte 26.3.

**Limite de licença:** a Mojang parou de ofuscar versões recentes, mas afirmou explicitamente que a [EULA não mudou](https://www.minecraft.net/en-us/article/removing-obfuscation-in-java-edition). Código legível não é código de biblioteca licenciado permissivamente. A [página de atribuições do produto](https://www.minecraft.net/en-us/attribution) mistura edições, dependências históricas e produtos: entradas como EnTT, bgfx ou FMOD não estabelecem uso atual na **Java Edition**. Brigadier/DFU/JOML licenciados separadamente são diferentes do código de gameplay/renderização da Mojang.

## 2. Três rotas de integração

| Rota | O que funciona em princípio | Custo/fronteira real |
|---|---|---|
| Kof JVM + biblioteca Java | Classes Java no classpath de dependências | A matemática de construtor/método do JOML foi exercitada abaixo. Outras bibliotecas Java continuam sem teste; reflexão, genéricos, callbacks de interface, JNI e classpath exigem provas separadas. Não satisfaz distribuição nativa-ELF por si só |
| Kof nativo + biblioteca C/C++ | Adaptador escalar estreito e verificado sobre subsistema estrangeiro permitido | A FFI nativa atual não passa arrays arbitrários, structs, ponteiros, buffers de saída ou callbacks. O adaptador possui memória/recursos nativos; o Kof recebe tokens verificados e valores copiados. Interfaces virtuais C++ exigem adaptadores reais |
| Port `.kf` nativo ou implementação independente | Algoritmos selecionados e contratos de dados/ciclo de vida | Melhor para CPU portátil pertencente ao engine. Traduzir fonte Java não traz JVM/reflexão/JNI. Ports derivados da fonte conservam obrigações da licença upstream |

Um adaptador de tokens **não** torna um JAR Java nativo. Embutir uma JVM ou mover gameplay para um engine estrangeiro é uma decisão arquitetural separada. `spawn` nativo atualmente desabilita GC automático; comece com uma thread Kof. Threads de bibliotecas estrangeiras não podem reter referências ao heap Kof nem chamar Kof. Consulte [KOF_LANGUAGE](KOF_LANGUAGE.md) e [COURSE_PROBES](COURSE_PROBES.md).

## 3. ECS, registries, componentes, dados e IA

### O que o Minecraft realmente contribui

**O Java vanilla não é uma referência de ECS archetype convencional.** O [tutorial de entidade da Fabric 26.2](https://docs.fabricmc.net/develop/entities/first-entity) usa subclasses de entidade e `EntityType` registrados; a [documentação de entidades da NeoForge 26.1](https://docs.neoforged.net/docs/entities/) descreve herança de `Entity` e `tick`/`baseTick`/`rideTick` por instância. O [EntityIndex histórico 1.21.8](https://maven.fabricmc.net/docs/yarn-1.21.8+build.1/net/minecraft/world/entity/EntityIndex.html) mapeia IDs/UUIDs a objetos de entidade. Isso é diferente de iteração por colunas de componentes.

Separações úteis para um FPS looter:

- **Definições versus instâncias:** registries namespaced contêm definições compartilhadas; instâncias de entidade/item contêm estado mutável. Persista IDs estáveis de conteúdo, não índices densos transitórios de ECS.
- **Defaults de item mais patches:** [componentes de dados de item](https://docs.fabricmc.net/develop/items/custom-data-components), introduzidos em [1.20.5](https://www.minecraft.net/en-us/article/minecraft-java-edition-1-20-5), substituem tags não estruturadas de stacks por valores tipados e validados. Um protótipo com patches de override/remoção serve para afixos, cargas e durabilidade. Isso não substituiu todo NBT nem transformou entidades do mundo em ECS. [Contratos de componentes 26.1](https://docs.neoforged.net/docs/items/datacomponents/).
- **Persistência versus codecs de rede:** são contratos diferentes. Validação, referências e migrações não são automaticamente replicação eficiente.
- **Efeitos orientados a dados:** IDs de operação registrados, predicados e contexto de avaliação tipado permitem que dados configurem comportamento pertencente ao Kof. Um novo tipo JSON não implementa seu efeito automaticamente.
- **Memórias/sensores/comportamentos de IA:** a [API Brain histórica 1.21.8](https://maven.fabricmc.net/docs/yarn-1.21.8+build.1/net/minecraft/entity/ai/brain/Brain.html) compartilha resultados de percepção por memórias, com sensores e atividades/tarefas priorizadas. Reaproveite um blackboard tipado, expiração e cadência de sensores — não a hierarquia de entidades do Minecraft nem um ECS geral alegado.

A 26.3 separa providers de contexto inteiro/float, amplia referências de ID/tag/registry inline, remove formas dedicadas de referência, renomeia `conditions`→`condition` e `functions`→`modifier` em loot entries e muda o discriminador de predicado `condition`→`type`. **Reaproveite validação/resolução, não a grafia wire em evolução nem casos aritméticos indefinidos documentados.** Defina schema versionado e erros explícitos do KOOKIE.

### Bibliotecas candidatas

| Candidato/classificação | Identidade verificada e licença | Adequação ao Kof/recomendação |
|---|---|---|
| **Brigadier**, dependência real do vanilla | **1.3.11**; [fonte pública inspecionada](https://github.com/Mojang/brigadier/tree/9ba4f13c0fe82b07c08c2dc2d8043f075ffd0d98), **MIT** | Melhor candidato pequeno de port de fonte: leitor de cursor, nós literal/argumento tipado, diagnósticos, uso/completion e dispatch com permissões. Reuso JVM plausível; port nativo de subconjunto limitado |
| **DataFixerUpper**, dependência real do vanilla | **10.0.21**; [fonte pública inspecionada](https://github.com/Mojang/DataFixerUpper/tree/5fc0978694e996cfe68a742b67a0d506c17de3f0), **MIT** | Codecs/migrações JVM úteis. Nativo: camada explícita pequena de codec/schema e migrações sequenciais de save, **não** o engine genérico completo de optics/type-rewrite |
| **Artemis-ODB**, ECS Java independente | **2.3.0**; [source pin](https://github.com/junkdog/artemis-odb/tree/6bb08e44bae8960ac516d9656b2bc0a57f794036), **BSD-2-Clause core**, arquivos de reflexão Apache-2.0 | Melhor referência avaliada de armazenamento/ciclo de vida Java: stores por tipo indexados por ID, queries all/one/exclude, mutação estrutural adiada. Troque reflexão/classes por IDs explícitos e stores tipados Kof |
| **Ashley**, ECS do ecossistema libGDX | **1.7.4**, arquitetura inspecionada no pin **1.7.3**; **Apache-2.0** | Vocabulário simples de Family/query. O POM publicado depende de libGDX core 1.9.9, não necessariamente da janela/backend. Não porte libGDX nem object pooling Java inteiro |
| **Dominion**, ECS archetype Java independente | **0.9.0**, [source pin](https://github.com/dominion-dev/dominion-ecs-java/tree/b5aea3287937c3b4e2f3d31a94f9072c003b5b63), **MIT**, Java17+ | Prioridade menor. Chunks têm colunas de referências a objetos Java, não SoA numérico nativo plano; suporte usa Unsafe/atomics. Não transplante scheduler paralelo nem IDs internos de chunks |

Metadados de release importam: metadados Maven ainda identificam Artemis 2.3.0 e Ashley 1.7.4 apesar de READMEs develop anunciarem versões diferentes. São designs estabelecidos, não sistemas Minecraft recém-lançados. Idade não prova desempenho nem abandono.

**Contrato nativo recomendado:** IDs de entidade verificados por geração, IDs explícitos de tipo de componente, armazenamento tipado por tipo, membership de queries all/any/none e fila de mudanças estruturais aplicada em limites de fase documentados. Escolha um design, não vários engines ECS. Mantenha campos quentes de combate fora de mapas com chave string.

**Riscos de port:** componentes reciclados não podem vazar referências antigas; locais internos de armazenamento não são identidades de save. Offsets UTF-16 do cursor do Brigadier exigem convenção explícita de diagnóstico Kof. Erros comuns de parse devem retornar resultados estruturados, não depender do ciclo de vida quebrado de exceções nativas. Validação inspirada no DFU deve distinguir campo opcional ausente de valor presente malformado e rejeitar resultados parciais inválidos. Ela não corrige o defeito medido no JSON nativo de registros fracionários.

## 4. GUI e texto

O vanilla fornece **contratos**, não um pacote GUI standalone licenciado: [inicialização/extração de Screen 26.2](https://docs.fabricmc.net/develop/rendering/gui/custom-screens), [camadas/foco/narração históricas 1.21.8](https://docs.neoforged.net/docs/1.21.8/gui/screens/) e a migração atual de texto/entrada para SDL3. Separe roteamento de entrada, foco, hit testing, layout, renderização e narração. Texto/preedit não é sequência de teclas físicas.

| Candidato | Identidade/licença | Recomendação e trabalho oculto |
|---|---|---|
| **owo-ui em owo-lib** | **0.13.1+26.2**, **MIT** | Melhor fonte seletiva para layout `.kf`: tamanhos fixos/conteúdo/percentuais, measure/mount/update/draw, foco e tooltips. Fabric/Minecraft/Mixins continuam embutidos; não é standalone nem compatibilidade 26.3 verificada |
| **YACL** | **3.9.7**, **LGPL-3.0-or-later**; builds incluem 26.3 | Reaproveite o contrato de settings: default, aplicado/vinculado, pendente, apply/discard/reset e disponibilidade. Não é toolkit geral de HUD/editor; uma state machine independente evita acoplamento de port |
| **ModernUI + Arc3D** | ModernUI **3.13.0**, Arc3D **2026.2.0**, **LGPL-3.0-or-later** | Alternativa Java real, não toolkit C++ nativo. Possui render/lifecycle/texto próprios; port nativo grande. Dependências e fontes licenciadas exigem auditoria |
| **RmlUi** | **6.3**, **MIT**, C++17 | Atalho mais forte para UI retida se a propriedade estrangeira for aceita; backend SDL3+SDL_GPU real. Callback/span/pointer adapter obrigatório; não é navegador nem solução completa de acessibilidade |
| **Dear ImGui** | **v1.92.9b**, **MIT** | Atalho para editor/debug se a propriedade estrangeira for aceita; backend SDL3+SDL_GPU. Não é sistema completo de UI de jogador, localização ou acessibilidade |

Para uma UI pertencente ao Kof, porte apenas contratos pequenos de layout/foco do owo e implemente independentemente settings pendentes no estilo YACL. Não herde janelas, registries, loaders XML ou o framework de mods inteiro do Minecraft. FreeType rasteriza glifos; HarfBuzz faz shaping. Nenhum dos dois substitui política de bidi/layout, fallback, IME, foco ou narração. Fixe implementações/fontes e audite avisos antes da integração. Nenhuma ponte de fonte Kof foi exercitada.

## 5. Física, colisão e movimentação

APIs históricas de entidade 1.21.8 expõem AABB, ajuste de movimento, step-height e ordem de eixos; `VoxelShape` fornece decomposição em caixas, raycast e clipping por distância de eixo. Isso **não** é evidência de solver geral de corpos rígidos nem controlador de cápsula varrida, e os internos exatos de movimento 26.3 não foram auditados. Mantenha a direção de cápsula/BVH 3D real do KOOKIE; não herde geometria apenas voxel nem regras de tick/tuning do Minecraft.

| Candidato | Identidade/licença | Julgamento de integração |
|---|---|---|
| **Jolt Physics** | **5.6.0**, **MIT**, C++17 | Melhor candidato estrangeiro avaliado: ray/shape queries, malhas triangulares estáticas, corpos rígidos e `CharacterVirtual`. Adaptador nativo ao kernel, não JNI Java. A adoção transfere propriedade de colisão/simulação e exige exceção explícita |
| **jolt-jni** | **6.1.1**, **MIT** | Rota potencial Kof JVM, não testada. Não presuma que incorpora upstream 5.6.0 sem alterações. Kof nativo não precisa dessa camada Java |
| **Bullet / Libbulletjme / Minie** | Minie 9.0.3, Libbulletjme 22.0.3; glue BSD-3-Clause, Bullet zlib, exceção MIT | Alternativa crível, também vista no ecossistema DynamX, não no vanilla. Vincule Bullet diretamente no nativo; não integre Bullet e Jolt simultaneamente |
| **Valkyrien Skies2** | 2.4.11, integração LGPLv3 | Estudo de mundos móveis, não biblioteca standalone limpa. Componentes VSCore/Krunch fechados não têm concessão independente estabelecida |
| **Physics Mod** | 3.2.5 para 26.3, All Rights Reserved | Estudo de detritos/ragdoll visual do cliente, **não fonte reutilizável** nem prova de colisão autoritativa |

O comportamento de parede/escada/aderência do `CharacterVirtual` é propriedade real do controlador, não marshaling. Se escolhido, comece com stepping síncrono e tokens de geração verificados. Callbacks nativos continuam nativos; filtre antes do passo e consulte eventos copiados depois. Mantenha armas, dano, intenção de movimento e autoridade de gameplay em `.kf`.

**Padrão continua sendo colisão Kof**, não uma mudança de dependência de física. Portar um solver Jolt/Bullet/PhysX inteiro para Kof não é tarefa pequena.

## 6. Som e áudio espacial

Os metadados 26.3 confirmam **OpenAL via LWJGL**, não uma versão exata independentemente verificada do OpenAL Soft. A documentação Fabric 26.2 de eventos de som, assets e sons dinâmicos separa eventos lógicos distribuídos pelo servidor de instâncias de reprodução no cliente, ganho por categoria, vozes móveis/em loop e legendas. Assets posicionais devem ser mono; som de UI não precisa passar pelo servidor.

| Candidato | Identidade/licença | Adequação ao Kof nativo |
|---|---|---|
| **OpenAL Soft** | Snapshot fixado, **LGPL-2.0-or-later**; dados HRTF SADIE-II sob Apache-2.0 | Melhor opção 3D avançada associada ao Minecraft: distância/direção/Doppler, HRTF, streaming e filtros/reverb EFX. Adaptador para pointers de contexto/dispositivo e uploads; EFX não rastreia o mundo sozinho |
| **SDL3_mixer** | Snapshot fixado, zlib, SDL >= 3.4.0 | Encaixe mais próximo da stack SDL: áudio cacheado/streaming, grupos, fades, ganho, pitch e panning espacial básico. Não é dependência vanilla |
| **miniaudio** | Snapshot fixado, MIT-0 ou alternativa domínio público | Alternativa permissiva com mixer, node graph, espacialização e decoders. WAV/FLAC/MP3 não implica Ogg embutido. Fixe ABI/build |
| **Sound Physics Remastered** | 1.5.1+26.3, GPLv3 | Estudo de oclusão/absorção/reverb. Acoplado a Minecraft/OpenAL/mod; não traduza sua fonte para um módulo Kof permissivo |

**Escolha:** retenha áudio SDL enfileirado para G0. Para mixer de produção, avalie SDL3_mixer primeiro se espacialização básica bastar; escolha OpenAL Soft se HRTF/EFX forem requisitos reais. miniaudio é uma terceira alternativa de empacotamento/licença, não motivo para três backends.

A biblioteca de áudio possui dispositivo, decodificação, mixagem e DSP. O Kof possui IDs de cue, seleção de asset, buses/categorias, vida das fontes, orçamento/prioridade de vozes, loops/fades/cancelamento, legendas e atualizações limitadas de oclusão. Nenhum dispositivo de áudio foi aberto nesta pesquisa.

## 7. Renderização e tempos de vida de recursos

| Candidato | Identidade/licença | Recomendação |
|---|---|---|
| **JOML** | **1.10.9**, **MIT** | Port seletivo de maior prioridade; uso direto na JVM foi medido. Sobrecargas mutáveis/destination evitam alocação incidental. Defina ordem de multiplicação, aliasing, radianos, handedness e profundidade |
| **Flywheel** | **1.0.6**, **MIT** | Melhor referência permissiva de ciclo de instâncias: persistentes, changed/visible/deleted, model/material/bounds. Runtime depende de Minecraft/loaders/Mixins, não é SDL standalone |
| **Sodium** | 0.9.3-alpha.1 para 26.3, PolyForm Shield 1.0.0 | Estudo arquitetural apenas. Termos restritivos não permitem port casual `.kf`; caminhos GL/Vulkan/Renderpearl atuais tornam resumos antigos obsoletos |
| **LWJGL** | **3.4.3**, BSD-3-Clause, componentes nativos separados | Binding JVM útil, não engine de renderização. Kof nativo deve adaptar APIs C selecionadas diretamente |
| **Iris** | **1.11.4**, LGPLv3, dependência glsl-transformer AGPLv3 | Baixa adequação; acoplamento OptiFine/Sodium/OpenGL e fechamento de licenças. Não é atalho para renderer SDL nativo |

### O que levar para `.kf`

1. **Extração → preparação → desenho.** Extraia transforms interpolados mínimos, IDs de recursos e dados de draw para armazenamento reutilizável. Comece sequencialmente; esse limite não exige threads Kof.
2. **Passes/pipelines e staging explícitos.** O Renderpearl usa attachments explícitos; SDL_GPU já fornece pipelines, command buffers, transfer buffers, passes e fences. Adapte os contratos SDL em vez de clonar suas camadas.
3. **Visibilidade e geometria suja são separadas.** Comece com bounds/frustum conservadores e caches de sala/região, não com requisito de voxel/chunk do Minecraft.
4. **Instâncias persistentes.** O ciclo Flywheel é útil para props, meshes de loot e efeitos repetidos. O Kof decide changed/visible/deleted; o adaptador só empacota/envia registros.
5. **Gerações e aposentadoria.** Prepare/valide substituições, publique gerações no limite do frame, preserve o asset válido anterior quando a preparação falhar e aposente recursos GPU antigos após o último uso.

Não trate GLSL arbitrário do Minecraft como shader SDL compatível. SDL_GPU usa layouts próprios e profundidade `[0,1]`; exemplos GL do JOML exigem escolhas deliberadas de projeção. A FFI escalar atual torna o throughput de staging dinâmico uma medição pendente, não promessa de cópia zero. Nenhum benchmark de renderização, inicialização gráfica ou execução de shader foi feito.

## 8. Fatias de biblioteca Kof recomendadas

Estas são fronteiras propostas, **não pacotes criados nem APIs prometidas**. Mantenha os gates de compilador/ABI G0 primeiro.

| Prioridade | Fatia | Fonte/ideia | Primeiro contrato limitado |
|---|---|---|---|
| 1 | Matemática | Subconjunto MIT do JOML | Vetores, quaternions, transforms, AABB/frustum; destinos do caller e convenção documentada |
| 2 | IDs e armazenamento | Contratos Artemis/Ashley | IDs de geração, arrays tipados, membership de query, mudanças estruturais adiadas |
| 3 | Conteúdo, patches e codecs | Conceitos Minecraft + ideias MIT do DFU | Definições namespaced, patches inherit/override/remove, validação, referências e migrações explícitas |
| 4 | Comandos | Subconjunto MIT do Brigadier | Parser cursor/span, argumentos tipados e dispatch por command-ID com permissão |
| 5 | UI e settings | Subconjunto MIT do owo + estado independente no estilo YACL | Measure/layout, foco, entrada, apply/discard/reset e extração de draw |
| 6 | Dados/render/instâncias | Contratos de extração + subconjunto MIT do Flywheel | Dados de frame, passes, gerações de recurso e instâncias persistentes |
| 7 | Eventos/vozes | Separação de sound-instance do Minecraft | Política de cue/bus/voice/subtitle sobre **um** mixer escolhido |

Blackboards/sensores de IA e contextos de efeitos cabem em marcos posteriores. A colisão cápsula/BVH permanece, salvo exceção de propriedade Jolt/Bullet aprovada. Um rewrite completo de DFU, scheduler Dominion, tradução nativa ModernUI/Arc3D, camada Iris ou transplante Sodium aumentaria o escopo inicial.

## 9. Sonda Kof/JOML executada

Esta é a única prova nova de integração executável de biblioteca nesta pesquisa. Ela usou o artefato JOML real nomeado pelo Minecraft 26.3, não um fixture Java simulado.

- JAR release do Kof: `/tmp/kookie-kof-cli-0.4.9-beta.jar`, SHA-256 `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`.
- Artefato JOML: 1.10.9, 814581 bytes, SHA-1 `438e036486bad66b189bff385dd07dea4f74a146`, SHA-256 `feca4db853371704338621c120acc5cc32300d8af635fa42414b6213301e216b`.
- O diretório isolado continha somente `main.kf` e a declaração de dependência; `kof run` coleta arquivos irmãos.
- `JAVA_TOOL_OPTIONS=--enable-native-access=ALL-UNNAMED` foi propagado; execuções seriais tiveram timeout de 60 segundos e não usaram APIs gráficas, de áudio ou de servidor.

A sonda chamou `Vector3f(3,4,0)`, `length`, `dot`, `Matrix4f.translation` e `transformPosition`. O alvo JVM terminou com 0 e imprimiu:

```text
5.0
25.0
5.0
4.0
```

O alvo nativo terminou com 1, sem stdout, e rejeitou as importações Java com `PKG006` para `org.joml.Vector3f` e `org.joml.Matrix4f`.

**Prova:** imports de classes Java, construtores, argumentos/resultados Float, mutação de objeto e essas operações vetoriais/matriciais funcionam no caminho JVM testado com `--deps`; a mesma declaração não expõe classes Java no nativo. **Não prova:** todos os overloads JOML, callbacks/genéricos, JNI/FFM, desempenho, inicialização gráfica/áudio/física ou integração de outra biblioteca. Nenhum port Kof nativo do JOML foi implementado.

## 10. Regras de licenciamento e adoção

- **Ports permissivos:** JOML/Brigadier/DFU/owo/Flywheel são atraentes, mas preserve avisos aplicáveis. Ashley/reflection derivado de Apache também mantém condições Apache; não relicencie uma tradução de fonte.
- **Integrações copyleft:** OpenAL Soft, YACL, ModernUI e Iris exigem revisão específica do componente/dependência. Link dinâmico não é isenção universal.
- **Concessões restritas/ausentes:** PolyForm Shield do Sodium não é OSS irrestrito; Physics Mod é All Rights Reserved; VSCore/Krunch fechado não foi licenciado pelo wrapper público. Trate-os como evidência arquitetural, não fontes.
- **Assets são separados:** fontes, datasets HRTF, sons, shaders e shader packs têm seus próprios termos. EULA do Minecraft e permissões de assets terceiros não são liberadas por possuir o jogo ou ler a fonte.
- **Fixe a integração real:** registre commit/artefato upstream, opções de build e avisos das dependências ao selecionar um port/backend. “Usado por um mod moderno do Minecraft” não prova compatibilidade 26.3.

A pesquisa usou metadados/notas oficiais da Mojang, APIs versionadas Fabric/NeoForge, metadados/POMs Maven, fontes/licenças fixadas e metadados mantidos pelos autores dos mods. Nenhuma alteração no engine, instalação de dependência, suíte completa, acesso ao desktop ou lançamento do jogo ocorreu.