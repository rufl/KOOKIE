# Memória de trabalho do KOOKIE

As fundações limitadas executam; os gates de implementação G0–G6 estão completos dentro dos limites de qualificação abaixo. A release de demo voltada ao jogador D1 continua aberta.

## Lote atual de qualificação

- `G1Demo` é o caminho único e executável da aceitação G1 na JVM e no nativo.
  Ele cobre servidor autoritativo a 60 Hz, dois clientes loopback, correção de
  predição/reconciliação observável, uma eliminação com arma/inimigo,
  recuperação da perda de foco e feedback confirmado da eliminação chegando ao
  HUD e ao áudio enfileirado.
- `G1Arena` contém 142 vértices únicos e 178 triângulos em um footprint de
  320 por 280: corredores interligados, cobertura em L e uma sala elevada.
  Snapshots do servidor incluem limites explícitos e todos os triângulos;
  consultas do cliente à sala elevada, corredores e cobertura passam.
- O staging de mundo, porta e HUD semântico usa capacidades persistentes:
  534 vértices triangulados da arena, 36 da porta e 372 do HUD para tracks
  emolduradas de vida/munição,
  ícones estruturais, glifo de conexão distinguível pela forma, carga
  ativa/reserva do encounter, mira responsiva ao foco, marcadores de
  acerto/eliminação, alertas laterais de dano, estado estrutural de
  inventário/equipamento/skill/loot, sinais de elite/chefe distinguíveis pela
  forma e um rail do criador fonte→validação→publicação. O feedback expira por
  tick e rejeita sequências duplicadas. A ponte SDL_GPU mantém buffers
  persistentes e uma paleta semântica de 16 cores; a prova sem crescimento por
  frame fica limitada às capacidades inalteradas.
- Sweeps de contato reutilizam o array de offsets. Sidecars de replay agora
  comportam 1.296 palavras, cobrindo o estado de 32 triângulos e o histórico
  limitado de apresentação.
- A linha de base retida de 84 cenários passou na JVM e no nativo; três
  cenários focados posteriores de entrada Blockbench, PNG e WAV também passam
  nos dois alvos. A suíte atual de qualificação da fonte limitada totaliza 94
  cenários na JVM e no nativo. A matriz completa não foi executada sem a
  permissão de pre-commit.
- G0 continua fechado: apresentação isolada e evidência LAN externa autenticada
  passam. Identidades, endereços, fingerprints, IDs de deployment e evidência
  operacional permanecem fora do repositório.
- A regressão G2 de três processos na JVM e no nativo transporta todos os 178
  triângulos da arena, comandos unificados com checksum e estado autoritativo
  limitado do encounter. Os clientes aplicam ID/estado/alvo/vida/posição,
  contagens ativa/reserva e o impacto confirmado mais recente. O caminho
  qualificado comprova estado terminal `7`, vida `0`, sequência de impacto `2`,
  25 moedas, revisão 4, geração 2 após reconexão e diagnóstico explícito de
  input obsoleto.
- G3 está encerrado no gate de aceitação atual. A morte do inimigo controla
  loot determinístico gerado no mundo, admissão remota de
  coleta/equipamento/progressão, modificadores de combate por
  equipamento/status e loot/XP/moeda de chefe. Os tipos de estado 7/8 com
  checksum replicam autoridade completa por jogador e drops por loopback e por
  processos externos na mesma máquina na JVM/no nativo; a seção 12 do save
  preserva drops e reivindicações de recompensa. Execução entre máquinas
  continua não comprovada.
- G4 está completo para seu contrato limitado. Assinaturas de hooks tipadas
  cobrem sessão/jogador/inimigo/loot/publicação do editor; o kooker admite os
  subconjuntos documentados de GLB, Dust3D, Aseprite, VOX, brushes convexos,
  Blockbench 5.0, PNG, WAVE PCM e OGG Vorbis pela CLI JVM de desenvolvimento e
  pela CLI nativa de entrada Linux empacotada; o reload de `.kpkg` valida estado
  candidato de pacote/registros antes da troca; o workspace Kutter fornece
  edição, play-in-editor e undo/redo limitado; e produtos GPU só ativam no
  limite de frame após a fence de upload. Uma oferta de 18 palavras e uma
  resposta de 7 transportam a identidade exata de compatibilidade de 13
  palavras pelo transporte autenticado de papéis remotos antes do gameplay.
  Esse handshake passou com host e clientes em três namespaces de rede Linux
  isolados e pilhas IPv4 distintas. Compatibilidade geral de formatos, reload
  arbitrário de código/shader, editor de produção e qualificação recente em
  três máquinas físicas ficam fora desta afirmação.

## Lote de netcode em passo fixo

- O protocolo atual envia até três inputs ordenados por passo fixo, carrega o
  ACK do snapshot mais recente e só aposenta o histórico após ACK autoritativo
  do input. Bundles/ACKs tipados validam checksums e rejeitam estado obsoleto
  ou fora de ordem.
- A janela de snapshots aceita uma revisão com sequência maior no mesmo tick e
  substitui a última amostra sem abrir uma lacuna de interpolação; ticks ou
  sequências antigos continuam rejeitados. Restaurar checkpoint limpa amostras
  de rewind do futuro descartado antes do próximo tick.
- O transporte nativo autenticado fixa o endpoint do peer admitido após o
  handshake. Continua sendo um envelope UDP autenticado limitado, com semântica
  inspirada em QUIC, não QUIC/TLS nem relay de produção.
- O host retém 12 ticks de histórico de posição autoritativa e deriva o rewind
  de hitscan do atraso confirmado pelo snapshot. Jogadores remotos renderizam
  seis ticks atrás do tick vivo; a predição expõe métricas determinísticas de
  contagem, média e maior correção.

## Lote de conclusão G5

- Release e CI agora constroem o commit de fonte exato `bf17ac7e7364` do Kof
  0.5.0-beta. A evidência upstream fornecida cobre `Buffer(U8, INOUT)` no
  x86-64 nativo e nos cross paths suportados; o KOOKIE não repete essa matriz.
  O benchmark JVM/nativo empacotado do KOOKIE agora valida a ABI exata de
  buffer e a redução `u8`. Um lote nativo registrado reduziu 64 MiB em
  233.350.224 ns no código escalar Kof e 1.073.834 ns via AVX2; isso não é uma
  afirmação de ganho no gameplay.
- A cena limitada completa tem 192 vértices criados, 64 triângulos de colisão
  carregados, 64 inimigos, 256 projéteis, 512 itens, 24 luzes e 64 efeitos. O
  soak de 30 minutos a 60 Hz manteve p95 de simulação em 3,202 ms e RSS dentro
  de 128 KiB após aquecimento.
- Dois clientes autenticados na mesma máquina recebem estado completo a cada
  tick. A montagem em quatro chunks é transacional e protegida por checksum; o
  cliente B reconecta na geração 2 sem aceitar rollback.
- O SDL_GPU envia 984 instâncias de triângulo em hardware em um draw. No
  dispositivo Intel Arrow Lake Vulkan 26.2.3 registrado, 600 frames
  1920×1080 mediram p50/p95/p99/máximo de 0,304/0,645/0,845/1,089 ms; o
  readback visual passou.
- Publicação de save durável contra crash, migrações em várias etapas, replay
  v3 vinculado à identidade e pacotes de árvore limpa assinados com Ed25519
  encerram o G5 limitado. Desempenho em várias máquinas/WAN e outros
  hardwares/SOs não é afirmado.
- Os arquivos Linux agora constroem nativamente o mesmo ponto de entrada Kof do
  kooker de conteúdo. O smoke do pacote exercita canonicalização WAVE PCM e
  OGG Vorbis, reabertura idempotente, rejeição de entrada malformada e denylist
  de dependências gráficas fora do checkout.

## Lote de qualificação Windows PE/SDL

- O backend Windows PE agora reduz o grafo atual alcançável de gameplay/
  apresentação: classes/campos, objetos, arrays, valores
  integral/Boolean/String, controle, impressão, indexação de String e FFI
  integral. A saída standalone é PE de console; a saída de biblioteca exporta
  `kookie_kof_gameplay_main`.
- O pacote nativo Windows reproduzível liga o objeto Kof completo de `src/` ao
  shell SDL3/SDL_mixer sem Java. O smoke isolado em Wine passa os marcadores de
  gameplay e `KOOKIE native Kof PE gameplay verified`.
- O pacote de apresentação reproduzível liga gameplay Kof PE nativo ao
  adaptador SDL3/SDL_mixer GPU e preserva produtos SPIR-V/DXIL. O gate do
  artefato passa; o smoke visual opcional em Wine exige GPU isolada capaz de
  DRI3 e não é inferido do ambiente Xvfb padrão.
- O pacote Windows JVM separado continua sendo perfil de compatibilidade, não
  fallback do gameplay PE nativo. PE nativo permanece AMD64/Windows; IR de
  ponto flutuante, exceções capturáveis e concorrência continuam falhando com
  `PE001`.

## Estado público do dogfood e da demo jogável

- O artefato público mais recente é
  [`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34),
  um arquivo de apresentação Linux x86-64 assinado do commit
  `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`. Ele antecede o caminho atual
  de apresentação, lobby/placar e fonte PE/SDL Windows; nenhum arquivo atual
  de demo Windows é público.
- A fonte atual de apresentação executa `Play` local pela sessão autoritativa
  limitada: input SDL de teclado/mouse, três bots gansos, dano, nomes,
  corações de 20 pontos, HUD e reset ao sair/entrar novamente em `Play`.
- `Host/Join` agora possui admissão fixa de dois jogadores, gate explícito
  ready/unready e tela de jogadores autoritativa do host por `Tab`. O probe de
  lobby/placar valida identidade, ciclo de vida, capacidade, checksum, rejeição
  de estado obsoleto/duplicado, adulteração e ordenação determinística na JVM e
  no nativo.
- D1 continua aberto para um par atual de apresentação Linux/Windows de árvore
  limpa, smoke repetido fora do checkout de jogar/reiniciar/sair, verificação em
  host novo/piso de runtime, evidência nativa de hardware-alvo e operação final
  de release. Ligação de pacote ou marcador PE isolado não é release de demo
  jogável.
- A imagem de sistema Linux padrão não possui o header de desenvolvimento
  SDL3_mixer. Um prefixo temporário fixado de SDL_mixer 3.2.4 permitiu que
  `verify_linux_presentation_package.sh` passasse artefato assinado, extração
  segura e package-smoke em 2026-10-02. O smoke visual Xvfb/DRM isolado
  reportou `No DRI3 support detected` e `No supported SDL_GPU backend`, então
  nenhuma evidência atual de hardware-alvo Linux foi retida.
- O gate de artefato de apresentação Windows de 2026-10-02 passou com
  prefixos temporários fixados de MinGW SDL3/SDL_mixer e DXC, incluindo saídas
  PE/SDL/SPIR-V/DXIL assinadas e reprodutíveis. Nenhuma evidência nativa
  Windows de hardware/input/áudio/GPU foi retida.
- `scripts/build_demo_release.sh` gera dois artefatos de apresentação
  idênticos por alvo a partir de árvore limpa, e o workflow pareado aprovado
  só os publica após aprovação do ambiente; a release pública permanece igual.

## Lote anterior de execução de hooks confiáveis

- Estendemos `BoundedTrustedModuleRegistry`: toda declaração precisa vincular
  um ID de implementação estática compatível e sua versão binária antes do
  fechamento; ambos participam da identidade de compatibilidade.
- Adicionamos `BoundedTrustedHookRuntime` com ticks monotônicos, ordem
  determinística de fases, vínculo à geração/checksums publicados, orçamentos
  por hook, capacidades globais e diagnósticos de rejeição atômica.
- Adicionamos aplicação autoritativa exatamente uma vez dos comandos de hook em
  `LoopbackSession`; destinatários inválidos, comandos incompatíveis e overflow
  agregado de moeda preservam o estado da sessão.
- `G4KutterDemo` agora consome seu módulo publicado: a morte confirmada da
  elite executa o hook de recompensa, emite evento tipado e concede quatro
  moedas acima da recompensa pertencente à definição.

## Lote anterior de publicação do criador

- Adicionamos `BoundedTrustedModuleRegistry`: no máximo 32 declarações de hooks
  estáticos, cada uma vinculada à capability/contribuição do manifesto, fase e
  orçamentos limitados de comandos/eventos, seladas na ordem de
  dependência/carga/prioridade.
- Adicionamos `BoundedKutterPublication` e `BoundedContentCompatibility`: uma
  transação verificada por revisão vincula checksums de pacote, extensão, hook,
  definição e quatro produtos; uma identidade wire de 13 palavras rejeita
  divergências de API/rede/conteúdo, e falhas preservam a geração ativa.
- Adicionamos `G4KutterDemo`, um encontro distinto com dois jogadores, elite
  orientada por extensão/definição e somente APIs públicas do engine. A morte
  determinística publica estado de encounter, autoridade do jogador e loot.
- Estendemos o HUD para 372 vértices fixos com um rail estrutural
  fonte→validação→publicação e marcas separadas de sucesso/falha. O staging de
  criador/ameaças agora usa helpers pequenos de coordenadas fixas para manter
  exatos os vértices estruturais no nativo e na JVM. A cena completa permanece
  abaixo da capacidade nativa de 512 vértices, com 486.
- `BoundedExtensionRegistry` e `BoundedEnemyDefinitionRegistry` continuam como
  fundamentos de manifesto/definição usados por G1, G3, sonda de transporte e
  nova transação do criador.
- O gate focado tem 77 cenários JVM/nativos. Checks, lint e LSP do Kof passam.
  A apresentação SDL_GPU Wayland isolada passa em 320×240 com capability de
  apresentação `11`, draw de 11.270 µs e checksum de frame `30.358.034`; a
  revisão visual não encontrou clipping nem sobreposição nos painéis de
  criador/ameaças. A matriz completa do repositório não foi executada localmente.

## Lotes anteriores

- Comandos de interação consumidos agora persistem em bundles de replay v2 e são simulados entre checkpoints completos. A captura reserva 64 posições; a reprodução cobre até 4096 ticks, um stream explícito de movimento e interações dos dois jogadores. Desative a captura antes de reproduzir; exporte antes de desativar.
- A progressão do nível usa seção 11/versão 1, identidade de nível/conteúdo e IDs estáveis exatos. O arquivo de schema v2 suporta capacidades configuradas até 12 seções × 160 palavras e cópias duplicadas com checksum; arquivos v1 genuínos continuam legíveis. Isso não equivale a publicação durável contra crash nem autenticação.
- Corrigimos campos não inicializados de inventário/triângulos em checkpoints nativos, ticks de movimento consumidos, input mantido nas buscas e encaminhamento de registros completos de replay. Dezoito cenários focados e 20 regressões afetadas passaram na JVM/native; nenhuma matriz completa local foi executada.
- Uma chamada nativa com muitos argumentos encaminhados por getters perdeu o argumento de disparo em uma reprodução focada. O replay agora enfileira o `InputCommand` existente em vez de reconstruir a chamada longa; não declaramos reparo do compilador.
- O ciclo de vida do host loopback preserva posição e marcas d'água de sequência na reconexão, limpa comandos pendentes e rejeita input obsoleto; a regressão LAN autenticada agora cobre esse pré-requisito com dois clientes.
- A reconexão da sessão remota preserva as marcas d'água de envio/recebimento do broad-phase ao fechar e reabrir; a sonda UDP nativa retoma na sequência 9 e rejeita snapshots antigos, e o slice LAN de três processos passa na JVM e no nativo.
- Linux x86-64 possui arquivos nativos e de apresentação assinados com
  Ed25519, procedência vinculada ao commit/toolchain, `SHA256SUMS` e licença MIT.
  O shell SDL nativo Windows continua separado da qualificação de gameplay Kof
  JVM descrita abaixo; nenhum alvo PE Kof completo foi estabelecido.

- O perfil de compatibilidade de apresentação Windows agora passa o gate de
  pacote assinado reproduzível e um smoke completo em Wine isolado sobre host
  capaz de DRI3. O gameplay Kof JVM alcançou HUD, cena 3D e reload do criador;
  o adaptador SDL nativo adquiriu a janela, reportou capacidades de
  apresentação e capturou um frame de 1280×720. Lowering nativo PE/Kof completo
  para Windows continua separado desta qualificação.
- `kof info --json` atual reporta 0.5.0-beta. O gate fixa o arquivo Linux
  x86-64 em
  `f93f02eb62af584ea49ffb44efdbf54f970bdb9570f16fdc48ccc28242798ca9`;
  nenhum alvo Kof PE para Windows foi estabelecido.
- O pacote Linux executa o servidor sem gráficos e o smoke fora do checkout.
  A procedência dos pacotes e o histórico operacional permanecem fora deste
  repositório.

## Intenção do usuário

Construir uma engine de boomer shooter / looter shooter / ARPG FPS com **código-fonte nativo Kof `.kf` para a lógica portátil da engine, do jogo e das ferramentas**. Bibliotecas externas de gráficos/plataforma e código estreito de ABI/shader são permitidos quando necessários. Preferir lotes maiores e coerentes com provas focadas; manter milestones incompletos explícitos.

## Identidades de pesquisa fixadas

- Toolchain atual de build do KOOKIE: fonte Kof `0.5.0-beta`
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`; SHA-256 da distribuição Linux
  x86-64 construída localmente
  `f6fd41ed59c461dd968376e8e2dd3f0dc24ee712578d318a7fb3f707bc761bdc`
  e SHA-256 do JAR do compilador
  `6634e1bf80334cc2518c50f9d1a05e2da92ff318282775ba58a087891e2420a6`.
  A identidade anterior do arquivo oficial
  `f93f02eb62af584ea49ffb44efdbf54f970bdb9570f16fdc48ccc28242798ca9`
  antecede o contrato nativo de Buffer e não é mais a entrada de build do
  KOOKIE.
- Kof4j: `22a186b9bf9df37c03809ba6ef4af85085386f63`, VERSION `0.4.9-beta`.
- Release executado: `kof-0.4.9-beta-linux-x86_64`, publicado em 2026-09-20; SHA-256 do jar independente `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`.
- Kof Editor: `bed6ae7d567b090497a447583a10b8522acaf66a`, VERSION `0.1.4-beta`; agora instalado com um launcher restrito ao projeto e isolado da rede, e verificado visualmente em X11 privado.
- Não inferir o estado do release a partir do README 0.4.0 ou do site 0.4.1. O SHA do código-fonte e o jar do release são identificados separadamente, sem assumir equivalência binária.
- Curso completo: [`lunalully/curso-completo-de-kof@d6fc8318e77f30ab0d6be87055d86a7eb63960d3`](https://github.com/lunalully/curso-completo-de-kof/tree/d6fc8318e77f30ab0d6be87055d86a7eb63960d3), baseline 0.3.7-beta. O snapshot do [portal oficial](https://koflang.github.io/docs) foi gerado em 2026-09-17; várias páginas diferem do código-fonte fixado do compilador. Consulte [KOF_COURSE](docs/KOF_COURSE.md).
- Minecraft Java26.3, lançado em 2026-09-15; SHA-1 exato dos metadados de versão `96c00d95a31328714d3811cfade2804bb050e455`. Usa SDL3/LWJGL3.4.3 e JOML1.10.9; matriz de código-fonte/versão/licença em [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Clones/jars temporários de pesquisa ficaram em `/tmp/kookie-*`; não são dependências do projeto. As evidências duráveis e todas as fontes das sondas estão em [RESEARCH_PROBES](docs/RESEARCH_PROBES.md), [COURSE_PROBES](docs/COURSE_PROBES.md) e [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- A CLI ativa é a distribuição Kof 0.5.0-beta fixada por fonte em
  `~/.local/share/kof4j/0.5.0-beta-bf17ac7e`, usando o runtime Java do host e
  o SHA-256 do JAR do compilador
  `6634e1bf80334cc2518c50f9d1a05e2da92ff318282775ba58a087891e2420a6`.
  A distribuição oficial anterior continua instalada lado a lado, mas não
  consegue compilar o benchmark nativo `Buffer(U8)` do KOOKIE.

## Decisões propostas

- Linux x86-64 nativo primeiro; oráculo diferencial JVM. Outros SOs/arquiteturas não são prometidos.
- SDL3 3.4.16 + SDL_GPU Vulkan/SPIR-V é a fronteira gráfica; SDL_mixer 3.2.4
  controla os buses. O benchmark Kof empacotado valida a ABI de buffer em lote
  e escolhe entre as rotas medidas de redução SIMD e escalar. O gameplay
  permanece no caminho escalar Kof até que o profiling identifique uma carga
  de produção em lote com a mesma propriedade e amortização.
- Uma thread de simulação Kof; tick de 60 Hz, renderização interpolada independentemente, proposta de recuperação em quatro etapas.
- Arrays de componentes tipados + IDs de geração, colisão cápsula/BVH 3D real, uma única autoridade de dano/morte/recompensa.
- Política de renderização, content kooker, UI do jogo e ferramentas para criadores pertencentes ao Kof; exceção explícita para shaders HLSL/GPU.
- Os sistemas completos de looter/ARPG são o marco G3, não serão abandonados após uma demonstração de boomer-shooter. O fluxo de criação é o G4. Consulte o plano para o escopo/aceitação exatos.
- Nenhum fallback automático para JVM, nenhum engine C oculto, nenhum fork do editor como pré-requisito.

## Fatos a não esquecer

1. As funções usam `Int f(Int x)` / `f(Int x): Int`, **não fun/fn**. `record` e `class X(...)` são imutáveis/no estilo de records; classes mutáveis usam campos + construtor explícito. Não há variáveis ordinárias no nível superior, literais de array nem pressupostos de safe-call/coalesce do Kotlin.
2. Módulos/imports `.kf` funcionam. A importação de diretórios foi medida na JVM/nativo; `run` coleta irmãos e rejeita várias funções `main()` (`PKG002`). Escopos de entrada de aplicações são separados.
3. O `extern` nativo **escalar** funciona agora; as antigas afirmações gerais de que “FFI nativo não é suportado” estão desatualizadas. sqrt → `3.0`, SDL_GetVersion → `3004016` foram medidos em ambos os alvos.
4. O `Buffer(U8, INOUT)` mais token FFI do Kof 0.5.0-beta passou na verificação independente fornecida para x86-64 nativo/cross. Script/JS/Android/riscv32/MCU ainda retornam `FFI001`; structs/ponteiros/variádicos e callbacks nativos continuam fora do contrato geral. IDs de recursos devem ser tokens reais do adaptador, não casts de ponteiros.
5. O caminho automático do coletor x86 nativo é controlado por `kof_spawn_count == 0` **cumulativo**. Aguardar uma tarefa não o reabre. Não contornar usando GC manual inseguro. Threads de bibliotecas nunca devem manter/chamar estado do heap Kof.
6. A execução nativa empacotada avisou que o pruning do runtime não consegue encontrar `NativeRuntime.java` fora do módulo do compilador; o fallback de runtime completo foi executado. As pequenas alegações de tamanho binário do upstream não foram verificadas para este caminho de release.
7. A otimização do compilador nativo continua limitada; o JIT da JVM pode superá-la. Tempos representativos da simulação limitada e renderização em hardware agora estão registrados para G5, sem generalização para outras cargas ou plataformas.
8. `kof.gpu` é computação matricial especializada, não um engine de gráficos 3D. O Kof Canvas é orientado a navegador; janelas nativas WebKitGTK/Jaylib não implicam execução em ELF nativo.
9. O teste FFI `InitWindow` com formato raylib do upstream usa um fixture C que imprime, não uma janela real. Nossa consulta de versão SDL igualmente prova apenas sua chamada exata.
10. As sondas orientadas pelo curso passaram nos exemplos de overload/default/captura aninhada, arrays 2D de Int, getters diretos de records de ponto flutuante, matemática com Double, ambas as ordens de argumentos de reduce e valores zero versus ausentes de mapas na JVM/nativo.
11. `File.writeBytes/readBytes/readRange` binário preservou `00 7f 80 ff` em ambos. Isso prova um pequeno caminho de API de instância, não FFI em massa, comportamento com arquivos grandes ou durabilidade de salvamento atômico.
12. O JSON nativo de records mistos de Int/Double/String estava errado: codificou 1.25 como 0.0, decodificou Double incorreto/String vazia; o round-trip na JVM passou. Condicione a persistência/conteúdo JSON nativos ao reparo e a uma prova específica do schema.
13. O `split` nativo não é uma divisão por regex da JVM: o pipe escapado produziu um elemento em vez de três. Evite presumir semântica compartilhada do parser.
14. Defeito crítico no handler nativo: após um try/catch normal, uma asserção falha posterior reentrou nesse catch e saiu com 0. A redução de código-fonte salta além de `KofTryEnd`. Uma asserção false simples falha corretamente. Não institucionalizar uma solução alternativa de fluxo de controle; corrigir/revalidar o compilador antes de depender de limpeza/exceções/testes.
15. Erros de limites nativos terminam sem catch/finally; limpeza explícita de throw/return de String passou nas sondas mais restritas. Validar índices e entradas do adaptador antes do acesso; asserções são throws capturáveis da linguagem, não um canal independente de falha de testes.
16. JOML1.10.9 do Minecraft26.3 funcionou com `--deps` da JVM Kof: comprimento/produto escalar de vetor e translação de matriz imprimiram `5.0,25.0,5.0,4.0`. O mesmo código-fonte/nativo rejeitou ambas as importações Java com `PKG006`. Isso prova o caminho restrito de matemática Java, não JNI/gráficos nem uso de JAR nativo.
17. Snapshots broad-phase autoritativos agora atravessam uma fila de transporte de capacidade fixa e validada; overflow rejeita sem descartar payloads enfileirados, e dequeue/apply atualiza a geometria do cliente com guardas de sequência.
18. O smoke GPU headless agora cobre profundidade de sobreposição dois e recriação limpa do dispositivo com reconstrução de recursos em cache; callbacks reais de perda e retirement continuam não implementados.
19. O transporte nativo UDP usa framing SipHash autenticado sobre um payload
fixo de 300 palavras, suficiente para 32 triângulos limitados, exige
provisionamento explícito de chave não nula antes da abertura e valida
protocolo/tamanho/sequência com preservação de inteiros com sinal e timeout de
recebimento de 1.000 ms; gestão de chaves de produção ainda não foi implementada.
20. A recuperação GPU agora expõe transições unavailable/ready/lost/failed e rejeita recuperação sem dispositivo headless ativo; a notificação de perda é um marcador explícito da sonda, não um callback SDL de perda de dispositivo.
21. Uma janela GPU reivindicada agora exige formato de swapchain válido pela sonda de capacidades de apresentação; o caminho Xvfb ainda não consegue reivindicar apresentação DRI3.
22. O transporte nativo pode ligar sockets UDP pareados no localhost, exige uma
chave SipHash de teste e um peer IPv4 antes de trocar frames autenticados, e
limpa o material da chave ao fechar; gestão de chaves de produção ainda não foi
implementada.
23. O relatório de capacidades de recuperação GPU é sensível ao estado: ready expõe reopen limpo e o marcador explícito de perda, lost expõe apenas reopen, e unavailable/failed não expõem capacidades; a SDL3 instalada não expõe callback de perda de dispositivo.
24. `RemoteSessionEndpoint` valida IPv4/porta e chaves SipHash não nulas, congela alterações de peer/chave enquanto ativo, permite troca de chave apenas inativo e é usado pela orquestração real dos papéis host/cliente; a distribuição de segredos de produção permanece externa.
25. `RemoteSessionLink` bloqueia snapshots até a ativação do endpoint e exige sequências de envio/recebimento estritamente crescentes. A qualificação com três processos na JVM/no nativo leva gameplay, feedback e estado do encounter pelo loop real da sessão.
26. `BoundedRayTargetWorld` faz seleção limitada de alvos por raio/pellet com inteiros, impacto mais próximo e desempate por ID estável, exclusão da origem via `SpatialAimContract` e remoção de alvos. `CombatWorld.resolveShotgunPelletTargets` e os wrappers de sessão preservam um alvo por pellet, inclusive impactos repetidos e misses limitados. `LoopbackSession.resolvePlayerSpatialShotgun` conecta essa seleção ao combate autoritativo dos jogadores.

27. O dispatch SIMD nativo seleciona AVX2/SSE2 no x86, possui caminho NEON AArch64 e mantém fallbacks escalares verificados. O benchmark Kof empacotado direciona um `Buffer(U8)` de 1 MiB pelo dispatcher por 64 rodadas e preserva a paridade escalar nas caudas de vetor. O lote AVX2 nativo registrado foi 217,3x mais rápido que a redução escalar Kof nativa para essa carga exata; nenhum ganho de gameplay ou geral da engine é inferido.
28. O gate focado atual tem 75 testes JVM/nativos, além de lint/LSP do Kof e da prova SIMD host/escalar/AArch64. Consulte o [CHANGELOG](CHANGELOG.md) para o histórico curto e humano.
29. Impactos autoritativos aceitos entram no histórico monotônico e limitado de
    apresentação/áudio e em lotes ordenados de feedback `6 + 11F`. A validação
    da mensagem inteira, a rejeição de duplicatas/lacunas e os baselines por
    geração impedem apresentação parcial ou obsoleta sem desfazer dano.
30. O estado do encounter usa mensagem dinâmica com checksum de
    `20 + 8N` palavras, limitada a 32 inimigos e ao transporte compartilhado de
    300 palavras. Cada entrada replica ID estável, papel, estado, alvo, vida e
    posição 3D.
31. G2 está concluído: papéis contínuos hitscan/projétil/shotgun, replay de
    inputs de predição ainda não confirmados, entrada/recuperação segura por
    geração, colisão de portas por segmento/AABB 3D mais renderização de 36
    vértices, recuperação completa de feedback e atenuação/pan estéreo
    pertencentes ao Kof enviados pelo SDL.
32. O limite público de conteúdo do G3 é um registro limitado e imutável, não
    uma ABI de plugins: manifests declaram versões, dependências, capabilities,
    ordem de carga, migrações, schema de rede e procedência; contribuições e
    definições de elite/chefe falham fechado antes do início da sessão. G4
    adiciona hooks confiáveis vinculados à geração, produtos determinísticos do
    kooker e reload em estágios de pacote/GPU.
33. A redução nativa atual pode corromper um resultado escalar de `extern`
    retido em variável local entre chamadas posteriores; retornar diretamente
    um Bool de `extern` também chegou a `kof_unbox_bool` com valor inválido. Por
    isso, a configuração headless e a recepção do transporte consomem
    resultados imediatamente em campos validados de objetos antes de outra
    chamada. Essa é uma solução focada para o compilador, não seu reparo nem
    permissão para generalizar a ABI.
34. Reter um slot espacial ou `SpatialPositionResult` entre chamadas
    posteriores no loop contínuo de projéteis passou na JVM, mas quebrou
    impactos terminais, eventos de impacto e apresentação no nativo. Preserve
    a forma comprovada das chamadas de coordenadas; `EnemySpatialWorld.find`
    mantém internamente o último ID/slot para remover buscas repetidas sem expor
    esse defeito da redução nativa.



## Cuidados do editor
Consulte [KOF_EDITOR](docs/KOF_EDITOR.md). A UI interativa é substancialmente implementada em JS dentro de `.kf`; trata-se de um scanner independente, sem reutilização do frontend do compilador. A execução copia o arquivo ativo para uma raiz temporária fixa e fixa a JVM. Nenhuma integração real de cliente LSP/DAP foi encontrada. Os endpoints do sistema de arquivos/shell do host são irrestritos e não autenticados.

Com o compilador inspecionado, o código-fonte `web.sh` omite o host, e o handler legado atende em `0.0.0.0` por padrão. O `--host 127.0.0.1` explícito se aplica ao **modo de handler legado**, não ao modo `web.app()+main`; o loopback ainda não constitui autorização/proteção de Origin. Prefira o uso em um scratch isolado, não as ações de Git/Run do monorepo. O scanner nativo antigo R1 está explicitamente encerrado no próprio registro histórico do editor.

## Evidências de jogos

- **DoomKof:** raycaster publicado com código-fonte, gameplay em `.kf`; JVM desktop Jaylib JNI 5.5.0-2/raylib, navegador alternativo Canvas+JS. A licença do código-fonte não foi estabelecida. Nenhuma versão nativa-ELF verificada.
- **Byte Eater / kofman:** jogo de navegador MIT publicado com código-fonte, KofJS/kof.ui Canvas, backend web JVM, ponte de teclado em JS implementada manualmente.
- **Pong:** demo de raylib reportada/com vídeo vinculado no issue #431 do Kof4j; o código-fonte do jogo e o destino exato de execução não foram verificados.
- O Tetris integrado é um jogo de terminal em runtime Java; a lista de jogos do KofOS contém planos não portados.
- A pesquisa não estabeleceu a existência de um shooter Kof nativo distribuído nem de um pacote de binding SDL/Sokol pronto. Esta é uma evidência negativa delimitada, não uma prova de que nada exista.

## Restrições de design adotadas

- Intenção/política de salto do controlador, handles seguros para geração, identidades/ordem exatas dos lotes de renderização e admissão por revisão/presença de vizinhos permanecem contratos explícitos.
- Identidade de itens, transações atômicas de item/moeda/RNG, semântica de habilidades/status, bordas de entrada em passo fixo, fila de renderização/hash espacial e publicação em estágios de edição ao vivo permanecem contratos explícitos.
- Geometria SAT isolada, contratos de transição de arma/dano, busca de IA limitada e salvamentos seccionados permanecem contratos explícitos.
- **Não** herdar “sweep” somente de endpoint, colisão do jogador por raio na cintura, pools de loot pequenos fixos/descartes silenciosos, autoridades de armas duplicadas, IDs ECS brutos nos salvamentos, reprodução de eventos rotulada incorretamente como replay determinístico ou inspetores de corpus rotulados incorretamente como cozinheiros de mapas.
- Todo código ou asset de terceiros copiado ou traduzido exige proveniência rastreável, revisão de origem fixada e análise de licença/avisos antes da distribuição.
- Minecraft: não é um ECS arquetípico convencional. Reutilizar a separação entre definição/instância, patches de substituição de itens, codecs validados, snapshots de extração e ciclos de vida de vozes de áudio. Priorizar subconjuntos MIT de JOML/Brigadier, contratos de armazenamento de Artemis/Ashley, layout do owo e ciclos de vida de instâncias do Flywheel; consulte [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Conjunto de expansão recomendado: SDL3/SDL_GPU; SDL_shadercross/DXC offline; OpenAL Soft opcional quando requisitos posteriores de HRTF/Doppler/EFX excederem o caminho estéreo SDL implementado em G2; SDL3_image para imagens; FreeType/HarfBuzz para texto; zstd para pacotes preparados. Limites, disponibilidade, licenças e gates estão no [ENGINE_PLAN](docs/ENGINE_PLAN.md#conjunto-de-bibliotecas-recomendado-2026-09-22).
- A física do Jolt, a navegação Recast/Detour e as UIs RmlUi/ImGui continuam sendo alternativas condicionais de subsistemas estrangeiros que exigem aprovação explícita de propriedade, não dependências adotadas. Nenhuma portabilidade integral de mods. Sodium PolyForm Shield, Physics Mod All Rights Reserved e os componentes fechados do VSCore/Krunch não são fontes permissivas para reutilização.

## Próxima ação e limite de comprovação

G1 comprova o caminho limitado do shooter autoritativo, não um jogo pronto:
simulação servidor→loopback→cliente, admissão do segundo cliente, reconciliação,
input seguro na perda de foco, contato 3D criado, extração de câmera/HUD e
render/readback SDL_GPU nativo executam. A afirmação de ausência de crescimento
por frame limita-se a capacidades de staging inalteradas em 64 frames
determinísticos e buffers nativos persistentes; não é um resultado de
RSS/desempenho por 30 minutos.

G2 está concluído: host mais dois clientes trocam baselines de gameplay por
destinatário, lotes ordenados de feedback e estado contínuo de encounter com
vários papéis. Os clientes predizem movimento, reproduzem inputs ainda não
confirmados na reconciliação e reiniciam épocas após reconexão; as sondas de
interação, processos e SDL isolado passam.

G3 continua concluído no gate atual. O caminho sob autoridade do servidor de
eliminação→drop gerado→coleta/equipamento→mudança observável de dano/skill→
recompensa de chefe→save/reload em arquivo de schema executa sem resultados
criados pelo cliente ou recompensas duplicadas. Os tipos de estado 7/8
atravessam processos autenticados na mesma máquina com host mais dois clientes
nos dois alvos. Manifests públicos limitados, capabilities e contribuições
determinísticas instanciam regras completas e seladas de elite/chefe de forma
atômica.

G4 está completo para a implementação limitada resumida acima. Sua troca de
compatibilidade usa o transporte de papéis de produção e processos separados,
mas a qualificação retida não é uma execução recente em três máquinas.

G5 está completo para o contrato Linux x86-64 limitado. A carga de referência
carrega 64 triângulos de colisão criados e executa 64 inimigos,
256 projéteis móveis, 512 itens, 24 luzes e 64 efeitos sob orçamentos móveis
16/64/128. A amostra nativa registrou p50/p95/p99/máximo de
1,518/1,623/1,717/1,757 ms. A execução ritmada com 600 de aquecimento e
108.000 ticks registrou 2,489/3,202/3,721/23,645 ms e faixa de RSS de
128 KiB, preservando a assinatura `520690`.

Um host autenticado replica estado completo a cada tick para dois processos
clientes; a montagem transacional em quatro chunks rejeita replay/adulteração
e o cliente B retorna na geração 2. O SDL_GPU desenha 984 instâncias em
hardware numa chamada; a execução Vulkan 1920×1080 registrou p95 de envio de
limpa encerram a robustez de release. A evidência permanece na mesma máquina,
com população fixa e uma estação. G6 agora possui probes de expansão limitada e
gates de pacote Windows PE/SDL nativos; várias máquinas/WAN, outros OSs/GPUs e
escala arbitrária continuam sem alegação.

G6 está qualificado para seu contrato limitado declarado: ligação de gameplay
Windows PE nativo, gates de pacote shell/apresentação SDL, probes de
KofScript/Kutter/WAN e evidência de CI estão retidos. Isso não transforma o
shell de apresentação estático em uma demo jogável; D1 continua sendo o gate
de release voltado ao jogador.

Evidências de pesquisa anteriores: sondas originais de core/import/FFI escalar,
18 programas orientados pelo curso (36 execuções, duas verificações) e o par
de sucesso da JVM/rejeição de importação nativa do JOML. As fontes/resultados
completos estão nos documentos de pesquisa vinculados. Essas sondas de
pesquisa foram somente para JVM/nativo x86, sem jogos/editor/servidor ou
gráficos iniciados. A verificação de instalação posterior exercitou a CLI do
compilador, LSP/DAP e o editor/servidor isolado real; ela não verificou a pilha
gráfica do engine nem executou uma suíte completa.

Todas as verificações gráficas usam um wrapper revisado configurado por `KOOKIE_PRESENTATION_ISOLATION_WRAPPER`, com sockets privados, timeout e limpeza de processos; nunca o desktop do desenvolvedor. A matriz completa somente na etapa final anterior ao commit, com permissão do usuário.