# Memória de trabalho do KOOKIE

As fundações limitadas executam; os gates de aceitação G0, G1, G2 e G3 estão completos, e G4 possui seu primeiro slice vertical transacional.

## Lote atual de qualificação

- `G1Demo` é o caminho único e executável da aceitação G1 na JVM e no nativo.
  Ele cobre servidor autoritativo a 60 Hz, dois clientes loopback, correção de
  predição/reconciliação observável, uma eliminação com arma/inimigo,
  recuperação da perda de foco e feedback confirmado da eliminação chegando ao
  HUD e ao áudio enfileirado.
- `G1Arena` contém 78 vértices e 26 triângulos para piso inferior, rampa,
  plataforma superior, dois degraus e salas empilhadas. Snapshots do servidor
  incluem limites explícitos e todos os triângulos; consultas do cliente aos
  andares superior/inferior passam.
- O staging de mundo, porta e HUD semântico usa 486 vértices fixos: 78 da
  arena, 36 da porta e 372 do HUD para tracks emolduradas de vida/munição,
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
- Checks e 77/77 cenários-fonte passam na JVM e no nativo; os marcadores
  executáveis de runtime G1 permanecem idênticos.
- G0 continua fechado: apresentação isolada e evidência LAN externa autenticada
  passam. Identidades, endereços, fingerprints, IDs de deployment e evidência
  operacional permanecem fora do repositório.
- A regressão G2 de três processos na JVM e no nativo transporta todos os 26
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
- G4 está em andamento. O primeiro slice publica pacote selado, manifesto de
  extensão, declarações de hooks confiáveis, definições de inimigos e produtos
  alinhados de geometria/colisão/navegação/replicação sob uma identidade exata
  de compatibilidade. Edições obsoletas/inválidas preservam a geração anterior,
  e um segundo encontro com dois jogadores orientado por definições executa.
  Execução de hooks, formatos-fonte restantes, carregamento externo de pacotes,
  ferramentas de edição, recarregamento ao vivo em etapas e qualificação do
  transporte continuam abertos.

## Lote de implementação mais recente

- Adicionamos `BoundedTrustedModuleRegistry`: no máximo 32 declarações de hooks
  estáticos, cada uma vinculada à capability/contribuição do manifesto, fase e
  orçamentos limitados de comandos/eventos, seladas na ordem de
  dependência/carga/prioridade.
- Adicionamos `BoundedCreatorPublication` e `BoundedContentCompatibility`: uma
  transação verificada por revisão vincula checksums de pacote, extensão, hook,
  definição e quatro produtos; uma identidade wire de 13 palavras rejeita
  divergências de API/rede/conteúdo, e falhas preservam a geração ativa.
- Adicionamos `G4CreatorDemo`, um encontro distinto com dois jogadores, elite
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
- Linux x86-64 agora possui um construtor reproduzível de arquivo dogfood
  interno com `SHA256SUMS` e JSON de procedência. O empacotamento Windows
  nativo continua fechado: não há alvo Kof Windows, prova PE/runtime nem
  entradas de assinatura. KOOKIE não possui licença pública.
- `kof info --json` atual reporta 0.4.9-beta em
  `~/.local/share/kof4j/0.4.9-beta`; nenhum alvo nativo Windows foi
  estabelecido.
- Pacotes reproduzíveis usam metadados de procedência do próprio projeto. A
  compatibilidade com endpoints de deployment permanece fora deste
  repositório. KOOKIE não possui licença pública.

## Intenção do usuário

Construir uma engine de boomer shooter / looter shooter / ARPG FPS com **código-fonte nativo Kof `.kf` para a lógica portátil da engine, do jogo e das ferramentas**. Bibliotecas externas de gráficos/plataforma e código estreito de ABI/shader são permitidos quando necessários. Aproveitar ideias de ZYLVE, DINX e CUBSHIP sem dependências ocultas. Preferir lotes maiores e coerentes com provas focadas; manter milestones incompletos explícitos.

## Identidades de pesquisa fixadas

- Kof4j: `22a186b9bf9df37c03809ba6ef4af85085386f63`, VERSION `0.4.9-beta`.
- Release executado: `kof-0.4.9-beta-linux-x86_64`, publicado em 2026-09-20; SHA-256 do jar independente `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`.
- Kof Editor: `bed6ae7d567b090497a447583a10b8522acaf66a`, VERSION `0.1.4-beta`; agora instalado com um launcher restrito ao projeto e isolado da rede, e verificado visualmente em X11 privado.
- Não inferir o estado do release a partir do README 0.4.0 ou do site 0.4.1. O SHA do código-fonte e o jar do release são identificados separadamente, sem assumir equivalência binária.
- Curso completo: [`lunalully/curso-completo-de-kof@d6fc8318e77f30ab0d6be87055d86a7eb63960d3`](https://github.com/lunalully/curso-completo-de-kof/tree/d6fc8318e77f30ab0d6be87055d86a7eb63960d3), baseline 0.3.7-beta. O snapshot do [portal oficial](https://koflang.github.io/docs) foi gerado em 2026-09-17; várias páginas diferem do código-fonte fixado do compilador. Consulte [KOF_COURSE](docs/KOF_COURSE.md).
- Minecraft Java26.3, lançado em 2026-09-15; SHA-1 exato dos metadados de versão `96c00d95a31328714d3811cfade2804bb050e455`. Usa SDL3/LWJGL3.4.3 e JOML1.10.9; matriz de código-fonte/versão/licença em [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Clones/jars temporários de pesquisa ficaram em `/tmp/kookie-*`; não são dependências do projeto. As evidências duráveis e todas as fontes das sondas estão em [RESEARCH_PROBES](docs/RESEARCH_PROBES.md), [COURSE_PROBES](docs/COURSE_PROBES.md) e [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- A CLI ativa agora é um reparo local das ferramentas compilado a partir do código-fonte, não o release original de pesquisa: SHA-256 do JAR `9a4c133d773058a0ea3b3bf503511439e67bbb8efb80a2d5ab848dbc8274b548`. As fontes persistentes do compilador/editor/cliente, Maven 3.9.16, caminhos de instalação, correções de protocolo e limites de verificação estão documentados em [KOF_EDITOR](docs/KOF_EDITOR.md#local-installation). O OpenJDK 27 existente e os pré-requisitos nativos foram reutilizados. Nenhum reparo do runtime nativo/engine está implícito.

## Decisões propostas

- Linux x86-64 nativo primeiro; oráculo diferencial JVM. Outros SOs/arquiteturas não são prometidos.
- SDL3 + SDL_GPU, primeiro Vulkan/SPIR-V; adaptador ABI escalar verificado e fino até que exista FFI de buffer Kof. SDL3 3.4.16 foi instalado para a sonda de consulta de versão; os gráficos não foram testados.
- Uma thread de simulação Kof; tick de 60 Hz, renderização interpolada independentemente, proposta de recuperação em quatro etapas.
- Arrays de componentes tipados + IDs de geração, colisão cápsula/BVH 3D real, uma única autoridade de dano/morte/recompensa.
- Política de renderização, content cooker, UI do jogo e ferramentas para criadores pertencentes ao Kof; exceção explícita para shaders HLSL/GPU.
- Os sistemas completos de looter/ARPG são o marco G3, não serão abandonados após uma demonstração de boomer-shooter. O fluxo de criação é o G4. Consulte o plano para o escopo/aceitação exatos.
- Nenhum fallback automático para JVM, nenhum engine C oculto, nenhum fork do editor como pré-requisito.

## Fatos a não esquecer

1. As funções usam `Int f(Int x)` / `f(Int x): Int`, **não fun/fn**. `record` e `class X(...)` são imutáveis/no estilo de records; classes mutáveis usam campos + construtor explícito. Não há variáveis ordinárias no nível superior, literais de array nem pressupostos de safe-call/coalesce do Kotlin.
2. Módulos/imports `.kf` funcionam. A importação de diretórios foi medida na JVM/nativo; `run` coleta irmãos e rejeita várias funções `main()` (`PKG002`). Escopos de entrada de aplicações são separados.
3. O `extern` nativo **escalar** funciona agora; as antigas afirmações gerais de que “FFI nativo não é suportado” estão desatualizadas. sqrt → `3.0`, SDL_GetVersion → `3004016` foram medidos em ambos os alvos.
4. `extern upload(Float[])` → `FFI001` em ambos os alvos medidos. Structs/ponteiros/out-buffers/variádicos e callbacks nativos estão fora do gate escalar suportado. IDs inteiros de recursos devem ser tokens reais de registro do adaptador, não conversões de ponteiros.
5. O caminho automático do coletor x86 nativo é controlado por `kof_spawn_count == 0` **cumulativo**. Aguardar uma tarefa não o reabre. Não contornar usando GC manual inseguro. Threads de bibliotecas nunca devem manter/chamar estado do heap Kof.
6. A execução nativa empacotada avisou que o pruning do runtime não consegue encontrar `NativeRuntime.java` fora do módulo do compilador; o fallback de runtime completo foi executado. As pequenas alegações de tamanho binário do upstream não foram verificadas para este caminho de release.
7. A otimização do compilador nativo é limitada; o JIT da JVM pode superá-la. Nenhuma preparação de FPS/memória/gráficos do engine foi medida.
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

27. O despacho SIMD nativo agora seleciona AVX2/SSE2 no x86, possui caminho de origem NEON no AArch64 e mantém um fallback escalar verificado. `FFI001` ainda impede a integração de buffers do Kof, então isso não é um ganho de velocidade medido da engine.
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
    definições de elite/chefe falham fechado antes do início da sessão. Hooks
    de módulos confiáveis, saída do cooker e reload em estágios continuam no
    G4.



## Cuidados do editor
Consulte [KOF_EDITOR](docs/KOF_EDITOR.md). A UI interativa é substancialmente implementada em JS dentro de `.kf`; trata-se de um scanner independente, sem reutilização do frontend do compilador. A execução copia o arquivo ativo para uma raiz temporária fixa e fixa a JVM. Nenhuma integração real de cliente LSP/DAP foi encontrada. Os endpoints do sistema de arquivos/shell do host são irrestritos e não autenticados.

Com o compilador inspecionado, o código-fonte `web.sh` omite o host, e o handler legado atende em `0.0.0.0` por padrão. O `--host 127.0.0.1` explícito se aplica ao **modo de handler legado**, não ao modo `web.app()+main`; o loopback ainda não constitui autorização/proteção de Origin. Prefira o uso em um scratch isolado, não as ações de Git/Run do monorepo. O scanner nativo antigo R1 está explicitamente encerrado no próprio registro histórico do editor.

## Evidências de jogos

- **DoomKof:** raycaster publicado com código-fonte, gameplay em `.kf`; JVM desktop Jaylib JNI 5.5.0-2/raylib, navegador alternativo Canvas+JS. A licença do código-fonte não foi estabelecida. Nenhuma versão nativa-ELF verificada.
- **Byte Eater / kofman:** jogo de navegador MIT publicado com código-fonte, KofJS/kof.ui Canvas, backend web JVM, ponte de teclado em JS implementada manualmente.
- **Pong:** demo de raylib reportada/com vídeo vinculado no issue #431 do Kof4j; o código-fonte do jogo e o destino exato de execução não foram verificados.
- O Tetris integrado é um jogo de terminal em runtime Java; a lista de jogos do KofOS contém planos não portados.
- A pesquisa não estabeleceu a existência de um shooter Kof nativo distribuído nem de um pacote de binding SDL/Sokol pronto. Esta é uma evidência negativa delimitada, não uma prova de que nada exista.

## Mapa de reutilização

- DINX: intenção/política de salto do controlador, handles seguros para geração, identidades/ordem exatas dos lotes de renderização, admissão por revisão/presença de vizinhos.
- ZYLVE: identidade de itens, transações atômicas de item/moeda/RNG, semântica de habilidades/status, bordas de entrada em passo fixo, fila de renderização/hash espacial, publicação em estágios de edição ao vivo.
- CUBSHIP: geometria SAT isolada, contratos de transição de arma/dano, busca de IA limitada e salvamentos seccionados.
- **Não** herdar “sweep” somente de endpoint, colisão do jogador por raio na cintura, pools de loot pequenos fixos/descartes silenciosos, autoridades de armas duplicadas, IDs ECS brutos nos salvamentos, reprodução de eventos rotulada incorretamente como replay determinístico ou inspetores de corpus rotulados incorretamente como cozinheiros de mapas.
- DINX MIT; aviso privado/interno para o jogo completo do ZYLVE; a alegação MIT do README do CUBSHIP não conta com um empacotamento completo dos avisos inspecionados. A permissão do usuário não libera ativos de terceiros. Registre a revisão/hash do código-fonte e as licenças no momento da portabilidade.
- Minecraft: não é um ECS arquetípico convencional. Reutilizar a separação entre definição/instância, patches de substituição de itens, codecs validados, snapshots de extração e ciclos de vida de vozes de áudio. Priorizar subconjuntos MIT de JOML/Brigadier, contratos de armazenamento de Artemis/Ashley, layout do owo e ciclos de vida de instâncias do Flywheel; consulte [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Conjunto de expansão recomendado: SDL3/SDL_GPU; SDL_shadercross/DXC offline; OpenAL Soft opcional quando requisitos posteriores de HRTF/Doppler/EFX excederem o caminho estéreo SDL implementado em G2; SDL3_image para imagens; FreeType/HarfBuzz para texto; zstd para pacotes preparados. Limites, disponibilidade, licenças e gates estão no [ENGINE_PLAN](docs/ENGINE_PLAN.md#recommended-library-set-2026-09-22).
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

G3 está concluído no gate atual e passa em todos os 75 cenários-fonte na
JVM/no nativo. O caminho sob autoridade do servidor de eliminação→drop
gerado→coleta/equipamento→mudança observável de dano/skill→recompensa de
chefe→save/reload em arquivo de schema executa sem resultados criados pelo
cliente ou recompensas duplicadas. Os tipos de estado 7/8 atravessam processos
autenticados na mesma máquina com host mais dois clientes nos dois alvos.
Manifests públicos limitados, capabilities e contribuições determinísticas
agora instanciam regras completas e seladas de elite/chefe de forma atômica.
Execução entre máquinas continua não comprovada; G4 mantém cooker, hooks de
módulos confiáveis, transações do editor e publicação em estágios. G5 mantém a
aceitação sustentada de carga, RSS e orçamento de frame; `FFI001` ainda
bloqueia chamadas Kof com buffers em massa para o kernel SIMD opcional.

Evidências de pesquisa anteriores: sondas originais de core/import/FFI escalar,
18 programas orientados pelo curso (36 execuções, duas verificações) e o par
de sucesso da JVM/rejeição de importação nativa do JOML. As fontes/resultados
completos estão nos documentos de pesquisa vinculados. Essas sondas de
pesquisa foram somente para JVM/nativo x86, sem jogos/editor/servidor ou
gráficos iniciados. A verificação de instalação posterior exercitou a CLI do
compilador, LSP/DAP e o editor/servidor isolado real; ela não verificou a pilha
gráfica do engine nem executou uma suíte completa.

Todas as verificações gráficas usam um wrapper revisado configurado por `KOOKIE_PRESENTATION_ISOLATION_WRAPPER`, com sockets privados, timeout e limpeza de processos; nunca o desktop do desenvolvedor. A matriz completa somente na etapa final anterior ao commit, com permissão do usuário. Os documentos de pesquisa e as ferramentas/configurações locais foram entregues; nenhum código-fonte/ativo de engine/jogo irmão foi modificado ou copiado.