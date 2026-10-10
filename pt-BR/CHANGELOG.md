# Changelog

Este arquivo registra as mudanças importantes do KOOKIE em linguagem direta. Ele não promete que um milestone terminou; o plano e as verificações focadas continuam sendo a fonte de verdade.

## Não lançado
- Atualizamos a baseline nativa para SDL 3.4.18 e Zig 0.17.0, as versões
  estáveis mais recentes; o SDL_mixer permanece na versão estável mais recente
  3.2.4. As Actions do GitHub agora usam checkout v7, setup-java v6,
  download-artifact v8 e o commit verificado mais recente do setup-zig; a CI
  roda com Temurin 27. Os builds PE/COFF agora passam `-g0` explicitamente para
  manter os caminhos de debug do Zig 0.17.0 fora dos objetos reprodutíveis. O pin
  de fonte Kof `0.5.0-beta` permanece no commit compatível mais novo com Buffer
  porque o arquivo público mais recente ainda falha na qualificação nativa de
  Buffer.
- Endurecemos os consumidores binários nativos do KOOKIE contra o bug de
  palavra parcial de `File.readBytes()` no Kof fixado `0.5.0-beta`: leituras
  limitadas de fontes, saves, replay, pacote e KofScript agora usam
  `readRange`. A verificação de apresentação Linux rejeita status filho
  diferente de zero; os gates Windows PE/pacote/release falham fechado para
  divergências de caminho, classpath, limpeza, reviewer e procedência; falhas
  de capacidade do smoke de release ocorrem antes dos builds.
- Adicionamos `scripts/report_code_mix.py` e uma auditoria de composição das
  fontes. O working tree atual tem 94.374 linhas físicas: 76,85% Kof, 0,59%
  KofScript, 11,36% C/header, 6,96% shell, 2,53% Python, 1,59% Java da ponte
  PE e 0,12% shaders GPU. A fatia somente de runtime tem 86,43% Kof; os
  mecanismos nativos permanecem na fronteira até uma ABI de buffers provar uma
  migração mais rápida e segura.

- Adicionamos uma demo KofJS isolada e um manifesto publicado de assets UI.
  As referências agora usam bindings gerados a partir do manifesto, com IDs
  estáveis, caminhos de runtime relativos ao pacote, SHA-256 minúsculo
  obrigatório e opcionalidade explícita para assets de protótipo. A folha de
  estilos da demo resolve as URLs empacotadas das fontes sem requests 404 de
  fallback. O gate compartilhado `verify_ui_manifest.py` valida os perfis
  `none`, `prototype` e demo.
- Adicionamos um kit retido e limitado de layout/componentes para apps, jogos
  e superfícies do Kutter: `KookieUiLayoutSpec`, `KookieUiPanel`, botões,
  campos de texto, toggles, sliders, feedback de progresso/badge, toolbars,
  tabs e inspectors. O estado dos controles comuns permanece no Kof para
  probes JVM/native determinísticos enquanto KofJS renderiza os mesmos handles;
  o probe G10 e a demo de UI agora exercitam a composição compartilhada.
- Adicionamos `KookieUiSoundCue`/`KookieUiSoundBank` para metadados de cues
  `.ogg`/`.wav` relativos ao pacote, tuplas exatas de publicação dos 14 clipes
  OGG UI registrados, FIFO limitado/ganhos espaciais e metadados determinísticos
  para o adapter nativo. O caminho SDL nativo agora aplica ganhos esquerdo/
  direito às tracks UI registradas; o descritor KofScript carrega o mesmo nó de
  som, clip ID e gain padrão. A demo UI e o probe G10 exercitam as duas camadas.
  SHA-256 do descritor não substitui gate de bytes/licença do arquivo na
  release.
- Auditamos a pinagem ativa do Kof4j `0.5.0-beta`,
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`: `Buffer(U8)` é uma fronteira de
  bytes síncrona em JVM/nativo x86-64 e passa a fixture SIMD INOUT local. A
  fonte fixada afirma suporte cross, enquanto a documentação mais nova do
  `main` ainda informa Native `FFI001`; o KOOKIE mantém staging escalar/próprio
  até uma fixture em lote por target provar uma fronteira portátil da engine.
- Adicionamos o caminho de performance P0 do servidor dedicado: o benchmark
  direto do tick mantém seu gate p95 existente, enquanto um perfil limitado de
  64 amostras reporta percentis de relógio, colisão, IA, projéteis, itens e
  finalização. Históricos de snapshots e impactos de inimigos agora removem
  entradas por ring buffer de `head/count`, sem deslocar arrays completos ao
  atingir a capacidade.
- Adicionamos a primeira fatia da biblioteca interna de UI para Kof/KofJS:
  metadados limitados de assets SVG/PNG com texto alternativo obrigatório,
  papéis de texto Jared Lite/Pixand, tokens de superfícies escuras, ícones SVG
  intrínsecos limitados, composições reutilizáveis `bindMenu` e `bindHud` e a
  fachada composável `KookieUiDocument`. O probe G10 focado qualifica execução
  JVM/native e saída de type-check/build KofJS.
- Adicionamos a companheira de GUI em KofScript `src/ui/kookie_ui.ks`:
  descritores semânticos limitados de texto/asset/ícone com validação da
  publicação e ciclo de vida determinístico. O gate de UI agora executa essa
  companheira em JVM/native; a renderização baseada em handles permanece na
  fachada Kof/KofJS porque os runtimes atuais de KofScript não expõem handles
  `kof.ui`.
- Recriamos o skin nativo da UI da engine sobre os tokens compartilhados de
  Kof/KofJS: `KookieUiNativeTheme` agora centraliza superfícies de
  `FrameStaging`, trilhos de foco, cores semânticas e contraste de
  acessibilidade para GameShell, HUD, nameplates e scoreboard. O HUD de
  gameplay agora expõe os rótulos estáveis HP, AMMO, BAG e XP dentro de um
  orçamento limitado de 438 vértices. O atlas SDL e a folha de estilos do host
  usam os mesmos tokens de background/surface/accent/focus/danger/success. Os
  gates focados de multiplayer, fontes e gameplay UI continuam verdes.
- Otimizamos o staging nativo da UI para reduzir custo na fronteira de
  renderização: `FrameStaging` agora escreve quads/triângulos em uma operação
  limitada, spans de primitivas agrupam chamadas de upload Kof/C e as
  capacidades das cenas CPU/GPU crescem com folga para evitar reallocação ou
  reconstrução de buffers em pequenas mudanças de quantidade no HUD/menus. A
  UI de gameplay continua em uma única chamada de draw.
- Os workers nativos de jobs agora executam somente agendamento e conclusão
  de plataforma; o resultado e o checksum do descritor permanecem no
  `BoundedJobGraph` do Kof, removendo o cálculo de engine do worker C.
- O transporte nativo não calcula mais em C a soma do payload recebido; o Kof
  agrega as palavras recebidas, enquanto a fronteira C mantém somente sockets
  e transferência das palavras de wire.
- Adicionamos intake limitado de SVG e SVGZ em formato aberto no Kof: parsing
  de formas estáticas W3C, wire vetorial canônico `SVGC` em ponto fixo,
  preservação de cor/alfa, decodificação gzip e rejeição de scripts, referências
  externas e CSS.

- Os buffers GPU nativos do mundo agora crescem conforme as contagens de
  vértices do lote de cena/mundo enviado, em vez de um orçamento fixo de
  atores; o smoke de apresentação reporta a capacidade do lote atual.
- O carregamento nativo de GLB agora retém todos os triângulos do ganso e do
  gato e aloca arrays da cena e imagens embutidas conforme os tamanhos
  declarados no GLB, sem caps fixos; as superfícies completas não ficam mais
  esburacadas.
- O upload nativo de texturas de modelo agora copia o PNG embutido no GLB do
  gato para uma região UV de tamanho completo; o ganso mantém seus tiles
  procedurais dedicados porque seu GLB não tem imagem embutida.
- A emissão nativa dos modelos de ganso e gato agora aplica o tick da
  animação idle à pose GLB autorada; os animais do gameplay não congelam
  quando estão parados.
- Os rastros de projétil agora são desenhados em profundidade de primeiro
  plano, e o histórico limitado de apresentações de replay gira seus eventos
  em vez de abortar o passo fixo após tiros e tentativas sem munição repetidos.
- Os glifos nativos do menu agora preservam cobertura de borda em tons de
  cinza no SDL_GPU e no shell Windows; as linhas de opções aplicam o tamanho
  de fonte selecionado e mantêm rótulos longos dentro dos painéis.
- O Apply de display agora sincroniza e verifica tamanhos windowed/borderless,
  usa a resolução selecionada em janelas borderless e verifica transições para
  fullscreen exclusivo.
- Os atores GLB nativos agora usam tiles de textura do modelo endereçados por
  UV para corpo/cabeça/pés do ganso e materiais do gato, em vez da paleta da
  arena, preservando uma amostra limitada mais densa das malhas autoradas.
- Os ticks de inimigos autônomos agora toleram a ausência de alvo jogador
  vivo; ciclos repetidos de tiro/morte não abortam mais o loop de passo fixo.
- Mantivemos o texto 7x7 do menu dentro do contrato de clipping nativo: o
  título de exibição `GATOGANSO` agora usa uma escala que cabe, e rótulos
  grandes recortam glifos antes do staging em vez de enviar coordenadas
  rejeitadas ao SDL_GPU.
- O gameplay relativo à câmera agora aplica o yaw horizontal do mouse ao
  movimento WASD; o follow determinístico em terceira pessoa, o zoom no scroll
  e a colisão autorada contra obstáculos continuam ativos.
- Estabilizamos os ticks fixos do gameplay GatoGanso drenando eventos de
  apresentação de arma confirmados e ignorando inimigos autônomos mortos;
  disparos confirmados agora exibem rastros limitados na tela.
- O gameplay SDL agora ativa o modo relativo do mouse enquanto está ativo,
  mantendo WASD e mouselook contínuo no mesmo caminho de entrada com foco.
- A apresentação em primeira pessoa agora oculta o ganso local no passe de
  mundo, projeta overlays de atores com a câmera GPU e seleciona alvos hitscan
  locais pelo raio da mira, não pela menor distância.
- Adicionamos apresentação nativa GLB limitada ao encontro GatoGanso: o perfil
  de conteúdo protótipo agora envia os modelos existentes de ganso e gato
  diretamente ao passe de mundo SDL_GPU, com estado de animação/material por
  ator. Pacotes de apresentação sem conteúdo mantêm o fallback limitado de
  silhuetas procedurais e não redistribuem assets do protótipo.
- Fixamos o workflow de verificação hospedado no commit assinado do
  `mlugg/setup-zig` compatível com Node24 enquanto o `v2` upstream ainda declara
  Node20.
- Fixamos as actions de upload/download de artefatos da release nas versões
  major compatíveis com Node24 e fazemos o job Linux da release exportar seu
  prefixo SDL3 3.4.16 fixado; o SDL3 de sistema mais novo não é mais aceito
  implicitamente.
- Fizemos o gate de empacotamento no Git Bash do Windows usar ACLs NTFS em vez
  de depender dos bits de modo POSIX de `chmod`; chaves Ed25519 transitórias são
  restringidas com `icacls.exe`.
- Tornamos as opções do linker cross do Windows imunes à conversão de caminhos
  do MSYS no Git Bash; `/Brepro` e `/subsystem:console` chegam ao Zig como
  flags do linker.
- Endurecemos o gate Wine da verificação Ubuntu hospedada: habilitamos a
  arquitetura i386, instalamos as duas arquiteturas do Wine e inicializamos um
  prefixo win64 antes do smoke de save durável Windows. Uma instalação somente
  com Wine64 pode falhar antes do teste PE quando
  `syswow64/rundll32.exe` não está disponível.
- Adicionamos entrada OGG Vorbis limitada ao kooker nativo de desenvolvimento
  e empacotado: estado de CRC/sequência/continuação/BOS/EOS das páginas,
  cabeçalhos Vorbis de identificação/comentário/setup, limite de frames
  decodificados e limites opcionais de loop em frames são validados antes de
  reter o payload preservado byte a byte. O caminho `stb_vorbis` fixado do
  SDL_mixer pré-decodifica música OGG e os SFX de UI distribuídos; controles
  explícitos de início/fim/quantidade em frames evitam loops com lacunas por
  aproximação de relógio.
- Fechamos a lacuna sensível à pressão do p95 do servidor dedicado G5. A carga
  autoritativa agora usa um passo escalar de inimigo sem um registro
  `EnemyAttackDecision` por tick, armazena slots/coordenadas estáveis do alvo
  dos projéteis em cache e agrupa blocos de checksum dos pickups e deltas da
  cena de referência. A saída JVM/nativa continua com checksum `217802` e
  `520690`; o gate nativo focado com 128 ticks de aquecimento e 512 medidos
  passou em p50/p95/p99/máximo de `3805/3925/3958/4936us` sob o orçamento de
  `4000us`. A verificação do pacote usa a mesma janela de qualificação.
- Fechamos a lacuna de empacotamento Linux da ponte de save segura para PE:
  `libkookie_persistence_adapter.so` agora é distribuída ao lado do adaptador
  SDL, fazendo staging, publicação e confirmação usarem o mesmo estado nativo
  de persistência em vez de depender de uma biblioteca FFI ausente.
- Concluímos o contrato limitado de publicação de save durável contra crash do
  P2. O `BoundedSessionSaveCoordinator` Kof agora codifica progressão de nível
  e autoridade G3, prepara paths arbitrários, carrega/restaura seções
  validadas, descarta staging interrompido e expõe a fronteira explícita
  `stage → publicação nativa → confirmPublished`. O gate Kof POSIX exercita
  esse caminho de ponta a ponta; o adaptador nativo descarrega os dados do
  arquivo, faz substituição atômica no mesmo diretório e descarrega os
  metadados do diretório em POSIX e Windows. Adicionamos cobertura E2E de
  interrupção antes/depois do sync, depois do rename, depois do sync do
  diretório e recuperação de staging truncado em
  `scripts/verify_durable_save.sh` e
  `scripts/verify_durable_save_windows.sh`; o gate player-facing G7 de gansos
  agora publica e restaura uma sessão recém-construída, incluindo o inventário,
  e o owner de apresentação G0 publica ao sair do gameplay ou fechar a janela e
  restaura ao iniciar/reentrar no processo. Um owner de save de servidor
  dedicado permanece como milestone de integração separado.
- Adicionamos a ponte `BoundedHostSessionSaveCoordinator` segura para PE. O
  Kof mantém a codificação das seções, validação do schema, migração e
  rollback; chamadas integrais verificadas transferem palavras wire limitadas
  ao adaptador nativo para staging/leitura dos bytes do arquivo e publicação
  durável, sem FFI de `File` ou `String`. O gate nativo G7, o
  `scripts/verify_pe_durable_save.sh` pelo PE/Wine gerado e o smoke de
  apresentação G0 empacotado agora exercitam a ponte segura para PE e seu ciclo
  de apresentação; o trigger de save do servidor dedicado continua separado.
- Corrigimos a regressão da arena G1 expandida: restauramos a geometria de
  colisão da sala elevada, sincronizamos o backend JVM com o limite nativo de
  1.740 palavras / 6.984 bytes por frame e atualizamos o receptor de papel
  externo para a mensagem de estado de gameplay de 24 palavras. Os gates de
  evidência LAN agora validam os 178 triângulos autorais da arena.
- Adicionamos um resolver compartilhado e fail-closed de SDL3/SDL_mixer e o
  caminho fixado `scripts/bootstrap_sdl3_mixer.sh` para hosts que têm SDL 3.4.16,
  mas não têm o pacote de desenvolvimento do SDL_mixer. Os gates Linux de
  pacote, apresentação, LAN e G5 agora aceitam o prefixo preparado, validam os
  metadados exatos 3.4.16/3.2.4 e continuam incluindo somente as bibliotecas
  SDL de runtime revisadas.
- Adicionamos o `kookie-launcher` nativo para Linux e Windows x86_64. Ele
  descobre o pacote publicado mais novo pela API de releases do KOOKIE no
  GitHub, verifica o manifesto Ed25519 embutido e o digest do archive, extrai
  com segurança, ativa atualizações atomicamente, mantém o marcador anterior e
  faz fallback para o pacote ativo em falhas transitórias. Adicionamos o smoke
  test assinado em `scripts/verify_launcher.sh`.
- Impedimos que um pacote dogfood local seja rebaixado quando o canal público
  do GitHub está em uma versão mais antiga ou igual: o launcher lê a identidade
  de `PROVENANCE.txt` e mantém o maior baseline SemVer disponível até existir
  uma release publicada mais nova.
- Corrigimos lançamentos Windows de dogfood/serviço sem `LOCALAPPDATA` ou
  `USERPROFILE`: o launcher agora reutiliza diretamente o diretório de ação
  remota já criado como estado isolado, usando `TEMP`/`TMP` como fallback
  quando a telemetria não está disponível.
- Tornamos a criação do processo filho do launcher segura para serviços de
  dogfood: o jogo embutido não herda handles de captura remota, mantendo a
  criação normal de janelas Windows; lançamentos desktop mantêm stdio herdado.
- Em modo dogfood, o launcher agora captura stdout/stderr do jogo embutido em
  buffers limitados e propaga uma saída não zero; no desktop, mantém o reaper
  destacado e o stdio herdado.

- Adicionamos à shell GatoGanso e à shell nativa Windows uma superfície flexível
  de acessibilidade: escala do HUD em 85/100/115 por cento, visibilidade do
  mapa tático e texto de alto contraste. A apresentação ao vivo aplica escala
  e mapa sem alterar os orçamentos fixos da sobreposição.
- Expandimos o probe limitado de GUI para fazer staging do frame de
  acessibilidade e adicionamos regressão para escala do HUD, visibilidade do
  minimapa e alto contraste ao vivo. O menu principal agora possui linhas
  explícitas para Accessibility e Quit, preservando o acesso ao Kutter.

## 2026-10-02
### Polimento da shell de GUI e qualificação Linux atual

- Adicionamos uma shell em moldura consistente, trilhos nas linhas
  selecionadas, subtítulos por tela, clipping limitado de texto e dicas
  explícitas de teclado nas telas principal, opções, multiplayer e Kutter.
- Expandimos `scripts/verify_multiplayer_ui.sh` para fazer staging das quatro
  telas nos caminhos JVM e nativo; `scripts/verify_goose_game.sh` passa.
- Construímos o artefato local de qualificação `0.1.0-gui.1` a partir do
  commit de fonte `b1d4db92bf3adf166d503ca0eb44d8569498950c`; o SHA-256 do
  arquivo Linux é
  `d9b909a4270fc9ca8fbd46a63bd0a21bc646e819da2ae6c3f89fa143dc1da902`.
  Assinatura determinística, extração e package-smoke passaram. O artefato usa
  uma chave efêmera e não é uma release pública.
- A tentativa de apresentação via overzeer continuou bloqueada por pressão
  total de I/O (`62.54%` bloqueado); não há afirmação de apresentação em
  hardware-alvo.
### Recuperação do orçamento do servidor dedicado

- Armazenamos em cache a contagem de projéteis ativos e atualizamos o checksum
  dinâmico da cena de referência incrementalmente sem alterar o checksum
  determinístico da carga.
- `bash scripts/verify_dedicated_server.sh` agora passa 512 ticks medidos com
  p95 de `3624us`, p99 de `3689us` e máximo de `3899us` sob o orçamento de
  `4000us`.
- Produzimos o pacote local de qualificação somente nativo `0.1.0-perf.2` do
  commit de fonte `87d3bc63b3bbc66c23f796258f5b9ea5147fb0df`; o SHA-256 do
  arquivo é
  `3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
  O package-smoke extraído e a qualificação de p95 do servidor empacotado
  passaram; não é uma release pública.


### Atualização da qualificação da release demo

- Registramos o resultado atual da qualificação: o gate de pacote de
  apresentação Linux assinado/package-smoke passou com um prefixo temporário
  fixado de SDL_mixer 3.2.4, e o gate de artefato de apresentação PE/SDL nativo
  Windows assinado passou com MinGW SDL3/SDL_mixer e DXC fixados.
- Esclarecemos que esses são checks de artefato/pacote apenas. D1 ainda exige um
  par Linux/Windows de árvore limpa, smoke interativo fora do checkout de
  jogar/reiniciar/sair, verificação em host novo/piso de runtime, evidência de
  GPU Linux nativa, evidência de hardware Windows nativo, política/notas finais
  da release e evidência multiplayer entre hosts se anunciada.
- Adicionamos `.github/actionlint.yaml` com metadados para o label customizado
  do runner self-hosted `kookie-demo-release`.

### Encontros locais novos ao pressionar Play

- Toda transição de `Play` no menu principal agora emite uma solicitação
  única de entrada no gameplay. A apresentação a consome antes do primeiro
  tick e cria um encontro autoritativo novo com bots; a entrada multiplayer
  após `READY` usa o mesmo caminho.
- O smoke focado da apresentação agora processa e avança o primeiro tick fixo
  de gameplay depois desse reset, separando no diagnóstico nativo falhas de
  admissão de input de falhas do tick autoritativo.
- Limitamos corpos, corações e placas de nome dos gansos aos limites nativos da
  tela para que rótulos na borda não rejeitem uploads de vértices da GPU.

### Passe de gameplay mundial em 3D completo

- Substituímos a projeção inteira falsa para a tela por um passe GPU em
  world-space. Kof envia coordenadas autorais `(x,y,z)`; o vertex shader
  SDL_GPU nativo aplica uma matriz view-projection em perspectiva e depth D16.
- Adicionamos um atlas de materiais texturizado gerado e um stream de vértices
  mundial separado para superfícies da arena e portas de interação. O piso
  inferior, as plataformas elevadas e as salas superiores autorais agora são
  renderizados como geometria room-over-room; atores/HUD continuam em um passe
  de overlay separado.

### Compatibilidade de pipeline Windows D3D12

- Declaramos explicitamente a quantidade de targets de cor e de samplers
  fragment SDL_GPU ao criar os pipelines do menu e da cena. O D3D12
  rejeitava os metadados incompletos anteriores com `0x80070057`; as
  assinaturas de saída dos vértices HLSL nativos continuam ordenadas conforme
  o contrato SDL_GPU D3D12, e o diagnóstico de backend e pipeline permanece
  disponível para o smoke no hardware.
- Preservamos o payload textual de throws Kof não capturados no runtime PE,
  para que as asserções da apresentação nativa mostrem a mensagem real da
  falha.


### Qualificação Linux em árvore limpa

- Uma execução local de 2026-10-02 produziu `0.1.0-linux-e2e.1` a partir do
  commit de fonte `1678a7de671866d94080718c367ab05875a92c2d`, verificou a saída
  determinística do pacote assinado, o package smoke fora do checkout e o smoke
  focado de gameplay goose. O arquivo usou uma chave temporária de
  qualificação, portanto não é um artefato de release público.
- A apresentação isolada chegou ao shell nativo, mas reportou ausência de DRI3
  e de backend SDL_GPU suportado antes do timeout 124. A evidência de
  apresentação Linux em hardware-alvo continua aberta.

### Qualificação Windows em árvore limpa

- Uma execução local de 2026-10-02 produziu `0.1.0-windows-e2e.1` do commit
  de fonte `1678a7de671866d94080718c367ab05875a92c2d` com o commit de fonte Kof
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`. O SHA-256 do arquivo é
  `c8153ae34b2a1ea7f8c85411df95393c02573fc433a477c539153459975e80a4`.
- A verificação fora do checkout passou os builds duplicados determinísticos,
  assinaturas destacadas, `SHA256SUMS`, extração segura do ZIP, o header PE `MZ`
  de `kookie.exe`, os campos de árvore limpa/apresentação Windows no manifesto
  e as entradas SPIR-V/DXIL empacotadas. A chave temporária de qualificação
  significa que este não é um artefato de release público.
- O smoke opcional de apresentação em Wine isolado chegou ao SDL nativo, mas
  saiu com código 70 e
  `kookie_gpu_open: No supported SDL_GPU backend found!`. A evidência de GPU,
  input e áudio Windows alvo continua aberta.

### Revisões autoritativas de snapshot no mesmo tick

- Corrigimos a admissão de snapshots autoritativos para substituir revisões
  novas no mesmo tick do servidor, continuando a rejeitar ticks e sequências
  antigos.
- Resetamos os watermarks do histórico de rewind quando o replay restaura um
  checkpoint anterior, preservando o avanço em passo fixo após o rollback.

## 2026-10-01
### Netcode híbrido em passo fixo

- Adicionamos o histórico de input em passo fixo inspirado no UZDoom: clientes
  repetem até três inputs ordenados, incluem o último ACK de snapshot e só
  aposentam o histórico após ACK autoritativo de input.
- Adicionamos mensagens tipadas de bundle/ACK com validação limitada, checksum,
  rejeição de ordem/estado obsoleto e helpers determinísticos de interpolação.
- Fixamos o transporte nativo autenticado ao endereço do peer admitido após o
  handshake, rejeitando datagramas de chave válida vindos de endpoints
  inesperados.
- Mantivemos o envelope UDP autenticado portátil em vez de importar QUIC; a
  semântica de canais é inspirada em QUIC, não é compatível com QUIC.
- Adicionamos um histórico autoritativo limitado de 12 ticks para validar o
  alcance de hitscan, derivando o rewind do atraso confirmado por snapshot em
  vez de confiar na distância enviada pelo cliente.
- Integramos interpolação de seis ticks do jogador remoto à apresentação nativa
  e expusemos métricas determinísticas de contagem, média e maior correção da
  predição.
- Adicionamos testes G6 focados para derivação do tick de lag compensation,
  distâncias históricas, janelas de interpolação e contagem de correções.


### Qualificação Windows PE/SDL G6

- Corrigimos o ciclo de vida do módulo do adaptador SDL Windows: chamadas FFI
  do Kof podem fechar a arena nativa de cada chamada sem descarregar o estado
  fixado do adaptador.
- Expandimos o subconjunto alcançável de lowering Kof PE/COFF para os grafos
  atuais de gameplay e apresentação: classes, campos, objetos, arrays, valores
  integral/Boolean/String, controle, impressão, indexação de String e FFI
  integral.
- Adicionamos pacotes nativos Windows reproduzíveis: o shell SDL liga o objeto
  Kof PE alcançável de `src/`, e o perfil de apresentação liga gameplay Kof PE
  nativo ao adaptador SDL3/SDL_mixer GPU com produtos SPIR-V/DXIL.
- O smoke isolado do shell nativo em Wine passou os marcadores de gameplay e
  `KOOKIE native Kof PE gameplay verified`. O smoke visual de apresentação
  continua opcional e exige GPU isolada capaz de DRI3; o wrapper Xvfb padrão não
  é evidência de apresentação.
- Tornamos o gate PE hospedado no GitHub resistente a diferenças de versão do
  `file`, validando diretamente headers COFF/PE em vez de comparar o texto
  específico da descrição do objeto.

### Lobby multiplayer Kof-first e tela de placar

- Adicionamos o ciclo limitado de `MatchLobbyState` para Host/Join fixo de dois
  jogadores, identidade de sala/nome, contagem de peers, ping, erros de
  transporte e estado explícito ready/unready.
- Adicionamos `MatchScoreboardState` limitado e autoritativo pelo host, com
  ordenação determinística, snapshots versionados/com checksum, rejeição de
  estado obsoleto/duplicado/adulterado e decode seguro contra capacidade.
- Adicionamos o card de lobby Kof e a tela de jogadores por `Tab`, com jogador,
  status, score, vida, K/D e ping honesto. O gameplay agora espera os dois
  jogadores conectados selecionarem `READY`.
- Adicionamos `scripts/verify_multiplayer_ui.sh` e integramos o probe focado ao
  caminho de verificação do repositório.

### Automação do pacote da primeira demo

- Adicionamos `scripts/verify_linux_presentation_package.sh` para extração
  assinada, smoke do pacote e smoke de apresentação isolado opcional.
- Adicionamos `scripts/build_demo_release.sh` para dois builds determinísticos
  em árvore limpa, validação de procedência/assinaturas e smoke por alvo.
- Adicionamos o `.github/workflows/release_demo.yml`, com builder/publicador
  pareado Linux/Windows aprovado manualmente.
- Corrigimos o launcher de apresentação Linux para entrar na raiz do pacote
  antes de resolver o adaptador SDL incluído; o smoke agora roda fora do
  diretório extraído.
- Normalizamos ordem, ownership e timestamps do tar Linux para que builds
  repetidos de apresentação sejam byte-a-byte idênticos; o smoke roda fora da
  raiz extraída.
- Os arquivos de apresentação agora incluem `DEMO_CONTROLS.txt` e impõem o
  limite `content_profile=none` da primeira demo.
- Corrigimos a qualificação de apresentação nativa: o HUD do shooter agora
  aceita os atores ganso com 100 de vida, o envio da cena GPU conta os
  vértices staged em vez da capacidade reservada do frame, e o marcador estrito
  de evidência só é emitido depois que as verificações de renderização/captura
  do menu principal passam.
- Rejeitamos digest de distribuição Kof sintético composto só de zeros; o smoke
  do pacote protótipo agora usa a identidade registrada da distribuição fixada.
- Endurecemos o caminho WAN simples: o rendezvous agora exige chave
  compartilhada explícita e não nula, preserva salas existentes de dois
  jogadores e possui smoke autenticado do punchthrough direto com framing UDP
  compatível entre Linux e Windows.

### Prontidão da release de demo jogável

- O artefato público mais recente `0.1.0-dogfood.34` continua sendo um dogfood
  de apresentação Linux x86-64 assinado do commit
  `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`; ele antecede o caminho atual de
  apresentação/lobby/placar e nenhum arquivo atual de demo Windows é público.
- A fonte atual cobre `Play` local, `Host/Join` fixo de dois jogadores,
  prontidão explícita e tela determinística de jogadores. O trabalho D1 restante
  é empacotamento de apresentação Linux/Windows em árvore limpa, smoke repetido
  fora do checkout de jogar/reiniciar/sair, verificação em hosts novos e
  evidência de apresentação em hardware nativo.

### Estabilidade do gate de desempenho headless na CI

- Tornamos explícito e configurável o orçamento P95 do servidor dedicado por
  `KOOKIE_SERVER_P95_BUDGET_US`. As verificações locais e de soak mantêm o
  padrão de 4000 microssegundos; a CI hospedada usa teto de 8000 microssegundos
  para absorver ruído de escalonamento sem alterar a meta registrada.


## 2026-09-30

### Artefatos Kof-first, sandbox e caminhos do compilador Windows

- Adicionamos produtos canônicos limitados de grafos, comportamento, hierarquia
  de cena, esqueleto e grafo de animação, incluindo codecs determinísticos,
  validação de reabertura, publicação por revisão e entrada de hierarquia/skin
  GLB.
- Adicionamos envelopes de artefatos offline e uma VM KofScript de pilha
  limitada, com prova estática de fluxo/pilha/recursos, capacidades explícitas
  de comandos/eventos e aplicação atômica na sessão autoritativa. O builder
  KofScript emite um artefato que os runtimes Kof JVM e nativo reabrem e
  executam de forma idêntica.
- Adicionamos um pacote JVM reproduzível para Windows com runtime OpenJDK x64
  fixado por SHA-256, árvore legal preservada, JAR executável canônico e ZIP
  determinístico assinado; o gate focado recompila e compara todos os artefatos
  assinados.
- Adicionamos uma ponte estrita do compilador a partir da IR Kof otimizada para
  um subconjunto limitado de topo com inteiros/String/fluxo de controle. Ela
  emite C11 determinístico, COFF AMD64 e PE de console por Zig fixado, verifica
  paridade semântica contra Kof JVM e rejeita classes, heap/arrays, exceções,
  FFI e IR SDL com `PE001`. Neste registro histórico, o caminho nativo de
  gameplay Windows ainda não estava qualificado; a entrada de 2026-10-01 acima
  registra a qualificação PE/SDL limitada posterior.

### Caminhos limitados de expansão G6

- Adicionamos jobs nativos com cópia de escalares, quantidade limitada de
  workers, publicação por ordinal e dobra determinística de conclusões.
- Adicionamos descritores/artefatos KofScript vinculados ao pacote, ativação
  encenada que preserva o programa anterior em falhas e execução autoritativa
  na sessão.
- Adicionamos hierarquia, transformações e registro de assets persistentes no
  Kutter, com save/open binário canônico e rollback em arquivo inválido.
- Adicionamos canal WAN de janela fixa com retransmissão limitada, pressão
  determinística de perda/latência, entrega ordenada, rejeição de replay e
  backpressure.
- Adicionamos `scripts/verify_g6_runtime.sh` e probes focados para os quatro
  caminhos.
- Adicionamos pacote reproduzível de apresentação SDL Windows com SDL3,
  SDL_mixer, SPIR-V/DXIL e OpenJDK 27 fixado. A evidência estática do pacote é
  retida; a qualificação completa de gameplay em Wine isolado está registrada
  na entrada de 2026-10-01 acima.


### Página inicial GitHub e superfície de contribuição

- Refizemos o README da raiz como página progressiva do projeto, com o logo
  KOOKIE fornecido, cinco badges úteis, rotas rápidas, um diagrama de
  arquitetura, tabelas limitadas de capacidades/evidências e limitações
  explícitas.
- Adicionamos uma imagem social discreta de 1280×640 construída com o logo
  fornecido, movemos os comandos detalhados de execução/pacote para um guia
  pareado e adicionamos orientações pareadas de relato de segurança.
- Adicionamos formulários de bug/proposta em inglês e português brasileiro,
  além de um template bilíngue e conciso de pull request. Descrição do
  repositório, tópicos de descoberta e relato privado de vulnerabilidades
  completam a superfície automatizável do GitHub; a imagem social versionada
  está pronta para o upload que o GitHub oferece somente pelo navegador.

### Entrada WAVE PCM limitada e kooker nativo empacotado

- Adicionamos um leitor RIFF/WAVE estrito para tag PCM `0x0001` mono/estéreo,
  amostras de 8 ou 16 bits em 8–96 kHz, limitado a 2 MiB, 32 chunks,
  30 segundos e 1 MiB de PCM canônico. Ele valida comprimentos RIFF/chunks,
  taxa de bytes, alinhamento de bloco e padding zero; remove `JUNK`, `PAD ` e
  `LIST/INFO` limitados; e rejeita semântica comprimida, float, extensível,
  RF64, cues/loops e desconhecida.
- Adicionamos saída PCM16 determinística e reaberta, com checksums de fonte,
  amostras normalizadas, metadados e canônico, por
  `kooker cook wav`. Os arquivos Linux agora incluem o kooker Kof
  nativo; o smoke do pacote verifica normalização, reabertura idempotente,
  rejeição de entrada malformada e ausência de dependências gráficas fora do
  checkout.
- Corrigimos o ciclo de vida do launcher JVM de desenvolvimento para remover
  sua árvore temporária de módulos após comandos aceitos e rejeitados, em vez
  de deixá-la em `/tmp`.
- Corrigimos as URLs padrão do manifesto de pacote para o diretório real do
  release GitHub versionado e rejeitamos diretórios customizados sem HTTPS.

### Entrada limitada de imagens PNG independentes

- Adicionamos um leitor PNG independente de até 1 MiB, 64 chunks e 256×256 para
  imagens não entrelaçadas de 8 bits em escala de cinza, truecolor, indexadas,
  escala de cinza com alpha e RGBA. Ele verifica o CRC de cada chunk e o Adler
  do zlib, reúne chunks `IDAT` consecutivos, reverte filtros 0–4 e resolve
  `PLTE`/`tRNS` em RGBA exato.
- Adicionamos saída PNG RGBA8 determinística e reaberta, com checksums de fonte,
  pixels, metadados e canônico por `kooker cook png`. `tEXt` validado é
  removido; Adam7, APNG, outras profundidades e outros chunks auxiliares ou
  desconhecidos são rejeitados em vez de perder semântica da imagem. A saída
  de atlas do Aseprite agora usa o mesmo encoder canônico.

### Entrada limitada de personagens do Blockbench

- Adicionamos um leitor de Blockbench `.bbmodel` 5.0 implementado de forma
  independente para personagens somente com cubos, hierarquias limitadas de
  ossos UUID e clips numéricos de posição/rotação/escala. Ele limita bytes da
  fonte, tokens, ossos, cuboides, profundidade da hierarquia, clips e keyframes;
  UUIDs duplicados/desconhecidos, Molang, efeitos e interpolação incompatível
  são rejeitados deterministicamente.
- Adicionamos saída `KCHR` v1 little-endian reaberta, com registros em ponto
  fixo de cuboides, hierarquia e keyframes, além de checksums de
  fonte/personagem/ossos/animação/produto. `kooker cook blockbench`
  grava o produto pronto para pacote; uma entrada rejeitada não grava saída.
  Pixels de textura e dados UV/material por face não fazem parte deste primeiro
  contrato `KCHR`.

### Integração SIMD com Buffer do Kof

- Fixamos builds de CI e release no commit de fonte
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c` do Kof 0.5.0-beta; o arquivo de
  release anterior da mesma versão antecede o suporte nativo a `Buffer(U8)`.
  A procedência do pacote agora registra o commit de fonte do Kof, o SHA-256 da
  distribuição e o SHA-256 do JAR do compilador.
- Adicionamos reduções verificadas de bytes sem sinal aos caminhos AVX2, SSE2,
  NEON e escalar, além da entrada FFI Kof limitada
  `kookie_simd_sum_u8_buffer`. A sonda C cobre entrada vazia e limites de cauda
  de vetor pelas rotas selecionada e escalar forçada.
- Adicionamos um benchmark de `Buffer(U8)` de 1 MiB pertencente ao Kof, com
  paridade JVM/nativo e medição de rota por 64 rodadas. No host Intel Arrow
  Lake-P registrado, a redução escalar Kof nativa levou 233.350.224 ns e a rota
  AVX2 levou 1.073.834 ns (217,3x somente para essa carga).
- Arquivos Linux nativos e de apresentação agora incluem
  `kookie-simd-bench`, sua biblioteca de dispatch independente de gráficos e
  cobertura no smoke do pacote. Isso encerra o pré-requisito de
  ABI/benchmark representativo, não a integração no gameplay de produção nem
  uma afirmação geral de velocidade da engine.

### Conclusão limitada de G5 e robustez de release

- Atualizamos todos os gates de release e CI para o Kof `0.5.0-beta` exato,
  fixamos o SHA-256 do arquivo Linux x86-64 em
  `f93f02eb62af584ea49ffb44efdbf54f970bdb9570f16fdc48ccc28242798ca9` e
  migramos os contratos de fonte exercitados nos builds JVM e nativo.
- Adicionamos a cena de referência limitada completa: 192 vértices criados,
  64 triângulos de colisão, 64 inimigos ativos, 256 projéteis móveis,
  512 itens, 24 luzes dinâmicas e 64 efeitos. O servidor carrega todos os
  triângulos e mantém tetos por tick de 16/64/128 para
  IA/projéteis/itens.
- Corrigimos a carga de colisão omitida pela carga dedicada, removemos riscos
  de spill de argumentos do backend nativo nos caminhos de distância, segmento
  e impacto dos projéteis e mudamos seu broad phase da rejeição somente pela
  travessia limitada das folhas da BVH sem alocação por consulta.
- Replicamos o estado de referência completo a cada tick para dois processos
  clientes autenticados na mesma máquina. As atualizações em quatro chunks são
  transacionais: entrada inconsistente, repetida ou com checksum global
  inválido não substitui parcialmente a view ativa. O cliente B desconecta e
  retorna na geração 2.
- Substituímos o desenho expandido na CPU por um draw real de triângulos
  instanciados na GPU: 2.952 atributos staged tornam-se 984 instâncias. O gate
  isolado em hardware renderizou 600 frames em 1920×1080 no Vulkan 26.2.3,
  `Intel(R) Graphics (ARL)`, com p50/p95/p99/máximo de envio de
  0,304/0,645/0,845/1,089 ms. O readback revisado visualmente reteve SHA-256
  `20b37c94927b04689071200346f1e98f3498ce6408697bae697535773f15f5d4`.
- A execução nativa focada da simulação registrou p50/p95/p99/máximo de
  1,518/1,623/1,717/1,757 ms. Uma execução ritmada de 30 minutos mediu
  108.000 ticks após 600 de aquecimento em 2,489/3,202/3,721/23,645 ms, com
  assinatura de recursos estável e 128 KiB de crescimento/faixa de RSS em
  181 amostras.
- Adicionamos publicação de save staged e validada com fsync do
  arquivo/rename/fsync do diretório e recuperação de escrita interrompida;
  migração de save em várias etapas; identidade e checksum global no replay v3;
  e guardas contra rollback em save, replay e reconexão.
- O empacotamento de release agora exige árvore limpa, identidade exata do Kof
  e chave Ed25519 privada do owner. Ele assina o arquivo, manifesto de
  procedência e conjunto de checksums, incorpora a chave pública e registra o
  commit, toolchain/digest, save durável e contratos de replay.
- A verificação adversarial upstream independente fornecida em 2026-09-30
  aprovou `Buffer(U8, INOUT)` mais token FFI no x86-64 nativo e nos cross paths
  suportados nos commits `b4c2b734a`, `381f6fab0` e `bf17ac7e7` (evidência
  `c73556f5a`). O KOOKIE não repetiu essa matriz; Script, JavaScript, Android,
  riscv32 e MCU continuam em `FFI001`, e nenhum ganho SIMD é afirmado.


## 2026-09-29

### Tempo headless e transporte de escala G5 limitados

- Adicionamos `BoundedDedicatedServer`, uma carga de passo fixo sem gráficos
  que usa os módulos reais de inimigos, projéteis e loot no mundo. A linha de
  base contém 64 inimigos, 256 projéteis móveis e 512 itens sob tetos móveis por
  tick de 16 estados de IA, 64 slots de projéteis e 128 slots de itens.
- Removemos buscas repetidas de posição espacial dos hot paths de
  inimigos/projéteis e evitamos alocar resultados de sweep quando a carga não
  contém obstáculos criados manualmente.
- Extraímos o UDP autenticado do adaptador SDL para
  `libkookie_headless_adapter.so`. A mesma biblioteca independente de gráficos
  agora fornece tempo monotônico, amostras de RSS, pacing em tempo real e
  períodos configuráveis de aquecimento/medição ao servidor Linux empacotado.
- Adicionamos mensagens limitadas de solicitação/estado, admissão consciente de
  geração e views de cliente para a carga dedicada. Um gate nativo focado
  executa um host e dois processos clientes por admissão de compatibilidade,
  quatro checkpoints, desconexão e reconexão na geração 2.
- JVM e nativo produzem checksum `797255` e assinatura de recursos `675172`
  após 256 ticks. Na estação Linux registrada, uma amostra nativa de 512 ticks
  após 128 de aquecimento registrou p50/p95/p99/máximo de
  1,186/1,245/1,269/2,195 ms e 64 KiB de crescimento/faixa de RSS. Uma execução
  ritmada de 30 minutos mediu então 108.000 ticks após 600 de aquecimento com
  1,216/1,891/2,182/4,110 ms e 128 KiB de crescimento/faixa de RSS em
  181 amostras. Isso qualifica o subconjunto headless sem colisão, não a cena
  com colisão/render criada manualmente, gameplay em várias máquinas nem tempo
  de frame em 1080p.
- Pacotes Linux contêm o binário do servidor e seu adaptador headless; o smoke
  de pacote verifica a telemetria fora do checkout e rejeita dependências
  gráficas do servidor.

### Conclusão do pipeline limitado G4 do criador

- Expandimos módulos confiáveis do caminho de morte da elite para assinaturas
  tipadas de início de sessão, conexão de jogador, derrota de inimigo, coleta
  de loot e publicação do editor. Pares estáticos de implementação/versão
  continuam vinculados à geração, ordenados por fase e limitados por capacidade.
- Adicionamos entrada offline limitada de projetos Dust3D com GLB texturizado
  validado, arquivos Aseprite RGBA de 32 bits raw/zlib, modelos/paleta/chunks de
  cena MagicaVoxel e brushes convexos em grade inteira no estilo Quake.
  Identidades canônicas de geometria, colisão, atlas PNG, metadados, material,
  entidade e visibilidade são produzidas deterministicamente; construções
  incompatíveis falham com diagnóstico do formato.
- Adicionamos `scripts/kooker.sh` com comandos de arquivo `cook`,
  `package` de um chunk, `inspect-package` e `validate-package`.
- Adicionamos envelope `.kpkg` little-endian e loader externo com caminhos
  lógicos, intervalos/hashes de chunks e registros de
  extensão/definição/hooks limitados. O reload valida o estado candidato
  primeiro; rejeição preserva pacote, registros e geração ativos.
- Adicionamos a tela Kutter e `BoundedKutterWorkspace` para mutações de
  mundo/entidade/arma/loot verificadas por revisão, inspeção de colisão/IA,
  play-in-editor e undo/redo limitado. Identidades de geometria, colisão,
  navegação e render são publicadas em uma transação.
- Adicionamos máquinas de estado coordenadas no Kof e no adaptador SDL. O
  adaptador monta uma cena candidata separada, aguarda a conclusão síncrona da
  fence de upload antes de reutilizar o buffer GPU persistente e então ativa no
  limite de frame. Referências no Kof controlam a aposentadoria da geração
  antiga.
- Adicionamos o handshake de controle de compatibilidade ao transporte de
  papéis remotos. Uma oferta de 18 palavras leva a identidade exata de 13
  palavras; uma resposta de 7 palavras aceita ou rejeita com diagnóstico antes
  de snapshots ou gameplay.
- Todos os 84 cenários-fonte focados passam na JVM e no nativo. A sonda de
  papéis autenticada também passou com host e dois clientes em namespaces de
  rede Linux separados e pilhas IPv4 distintas, incluindo reconexão e o
  handshake de compatibilidade. Isso não é evidência de três máquinas físicas.
- O caminho de preservação e ativação de candidata do Kutter também renderizou
  por SDL_GPU headless isolado em 320×240. O checksum do frame final foi
  `28.585.778` (SHA-256 do PPM
  `c9c17e6de93dfd13ac04ee70896a2739be0ba5cf70c9c65b06e924b430064a6d`);
  a revisão visual não encontrou clipping, sobreposição nem rótulos ilegíveis.
  O Xvfb isolado não pôde qualificar apresentação em janela porque não oferece
  DRI3; portanto, esta afirmação fica limitada ao caminho GPU offscreen real de
  render/reload.

### Shell nativo persistente, menus e pacotes permissivos

- Substituímos o teste Windows de matriz de cores que fechava sozinho e o
  pacote com JDK embutido por um único `kookie.exe` nativo com SDL3 e
  SDL_mixer. A janela high-DPI redimensionável cobre maximizar, restaurar,
  modo janela, borderless e fullscreen exclusivo.
- Adicionamos menu pixel old school, opções transacionais de
  vídeo/áudio/texto e lobby Host/Join/Leave com IPv4/porta editáveis e estado
  explícito. Mouse e teclado usam as mesmas ações.
- Adicionamos o shell Kof persistente equivalente à apresentação Linux SDL_GPU
  e preservamos a cena limitada de gameplay G1.
- Migramos o áudio nativo para streams separados de efeitos e música no
  SDL_mixer, com volumes independentes.
- Licenciamos o KOOKIE sob MIT e limitamos componentes distribuídos de
  fonte/runtime a licenças permissivas. Os pacotes incluem MIT e avisos de
  terceiros, não empacotam loader/libc no Linux e rejeitam runtime JVM.
- O artefato Windows nativo agora inicia `kookie.exe`. Verificações Wine
  isoladas exercitaram telas principal, opções e multiplayer, redimensionar,
  maximizar e restaurar; o smoke de pacote carregou SDL 3.4.16 e SDL_mixer
  3.2.4 sem abrir janela.

### Execução de hooks confiáveis vinculada à geração

- Declarações de hooks confiáveis agora vinculam um ID de implementação
  estática compatível e sua versão binária ao checksum selado do módulo.
  Implementações ausentes, versões incompatíveis e fases divergentes falham de
  forma segura antes da publicação.
- Adicionamos `BoundedTrustedHookRuntime`: uma geração publicada e seus
  checksums exatos de extensão/módulo são vinculados antes que ticks monotônicos
  executem hooks em ordem determinística de fases. Orçamentos por hook e
  capacidades globais de comandos/eventos são verificados antes da emissão,
  preservando a saída da fase anterior quando há rejeição.
- Adicionamos aplicação autoritativa única de comandos limitados dos hooks.
  Destinatários desconectados, comandos incompatíveis e overflow de moeda são
  rejeitados sem mutação parcial nem reaplicação.
- O exemplo G4 com dois jogadores agora executa o hook compilado de recompensa
  de elite depois da morte confirmada do inimigo. Ele emite evento tipado e
  adiciona quatro moedas pela sessão autoritativa sobre a recompensa de cinco
  moedas definida por dados.
- Testes focados cobrem fase/versão de implementação incorretas, rejeição por
  orçamento e capacidade, gerações publicadas divergentes, ticks monotônicos,
  overflow e aplicação exatamente uma vez.
- Todos os 78 cenários-fonte passam na JVM e no nativo; checks, lint e LSP do
  Kof passam.


### Primeiro slice transacional G4 de publicação do criador

- Adicionamos `BoundedTrustedModuleRegistry` para no máximo 32 declarações de
  hooks compilados estaticamente, vinculadas a contribuições do manifesto, fase
  e orçamentos de comandos/eventos. A ordem de dependência/carga/prioridade é
  determinística e o checksum selado vincula o registro exato de extensões.
- Adicionamos `BoundedKutterPublication`, verificada por revisão, e uma
  identidade wire `BoundedContentCompatibility` de 13 palavras cobrindo
  engine/API/rede, pacote, manifesto, módulo, definição, geração e produtos
  alinhados de geometria/colisão/navegação/replicação. Transações obsoletas,
  divergentes ou inválidas preservam a geração ativa anterior.
- Adicionamos `G4KutterDemo`, um encontro distinto com dois jogadores por APIs
  públicas, elite orientada por dados e declaração de módulo confiável. A morte
  determinística emite estado válido de encounter, autoridade por jogador e
  loot no mundo.
- Estendemos o HUD fixo de 312 para 372 vértices e a cena completa de 426 para
  486 com um rail fonte→validação→publicação e marcas de sucesso/falha
  distinguíveis pela forma. A coroa do chefe ficou mais compacta e continua
  estruturalmente distinta do diamante de elite.
- Uma captura isolada revelou corrupção de coordenadas apenas no nativo nos
  antigos métodos de staging de criador/ameaças com muitas variáveis locais.
  Helpers pequenos de coordenadas fixas agora mantêm exatos o cap de publicação,
  o sinal de compatibilidade, o diamante de elite e a coroa de chefe; asserções
  JVM/nativas vinculam seus vértices estruturais.
- Todos os 77 cenários-fonte passam na JVM e no nativo; checks, lint e LSP do
  Kof passam.
- A apresentação SDL_GPU Wayland isolada passa em 320×240 com capability de
  apresentação `11`, draw de 11.270 µs e checksum de frame `30.358.034`. A
  revisão visual confirmou conteúdo limitado aos painéis, sinais legíveis e
  distinguíveis pela forma para fonte/validação/publicação/sucesso e coroa de
  chefe, sem clipping nem sobreposição nesses painéis.
- Qualificamos o dogfood Linux de apresentação `0.1.0-dogfood.27` a partir de
  `82bf57d69083` (SHA256
  `ad4a57ee4f92cf8da93d7d29b8002d95656327d35438c54f29a2b8e8d056abce`,
  4.281.751 bytes). O smoke fora do checkout vinculou versão, build e arquivo
  exatos. O arquivo extraído também encerrou com código `0` num display isolado
  revisado com compositor aninhado, informou capability `11`, desenhou em
  9.087 µs e reproduziu o checksum de frame `30.358.034`; sua captura
  persistida foi idêntica byte a byte à captura da verificação da fonte.


### Encerramento G3: extensões limitadas, chefes por dados e HUD de ameaças

- Adicionamos `BoundedExtensionRegistry` com manifests versionados, dependências
  e capabilities declaradas, contribuições com namespace, resolução
  determinística de carga/prioridade, checksums imutáveis e diagnósticos
  fail-closed.
- Adicionamos definições completas e seladas de elite/chefe para combate,
  comportamento, loot determinístico por instância, progressão e moeda. A
  admissão do inimigo definido faz preflight da capacidade de ator/recompensa
  e commit atômico.
- Migramos o demo G1, o caminho G3 de save/reload e a sonda autenticada de
  transporte externo JVM/nativo para instanciar essas definições em vez de
  configurar recompensas de elite/chefe por inimigo.
- Estendemos o HUD fixo de 264 para 312 vértices e a cena completa de 378 para
  426 com sinais estruturais de diamante de elite, coroa de chefe, contagem e
  derrota. A apresentação deriva esses sinais do tipo autoritativo do inimigo
  sem crescimento de capacidade por frame.
- Todos os 75 cenários-fonte passam na JVM e no nativo. Lint/LSP de Kof,
  transporte autenticado na mesma máquina na JVM/no nativo e apresentação
  SDL_GPU Wayland isolada passam. A captura 320×240 informou capability de
  apresentação `11`, desenhou em 10.789 µs e produziu checksum `30.593.757`; a
  revisão visual não encontrou clipping, sobreposição de painéis nem estado de
  ameaça ambíguo dependente apenas de cor.
- Qualificamos o dogfood Linux de apresentação `0.1.0-dogfood.26` a partir de
  `2abfeb172b61` (SHA256
  `325c4f9cf82ff42ed6e72898012d6e56afdb09f75a078a99f033a0519f50d3ac`,
  4.232.726 bytes). O smoke fora do checkout vinculou versão, build e arquivo
  exatos. O arquivo também encerrou com código `0` num display isolado revisado
  com compositor aninhado, informou capability `11`, desenhou em 5.104 µs e
  reproduziu o checksum de frame `30.593.757`.

### Replicação G3 entre processos e polimento do HUD semântico

- Estendemos o HUD semântico fixo de 174 para 264 vértices com estados limitados
  de inventário preenchido/cheio, equipamento, XP/rank da skill e loot ranqueado
  no mundo. Cada estado usa forma estrutural além de cor; slots inativos
  permanecem degenerados na cena fixa de arena/porta/HUD com 378 vértices.
- O demo de apresentação agora deriva esse painel do caminho autoritativo real
  de eliminação G3, drop rank 3, skill e recompensa em moeda.
- Encaminhamos autoridade do jogador tipo `7` e loot no mundo tipo `8` por
  processos autenticados na mesma máquina com host mais dois clientes na JVM e
  no nativo. O validador comprova item/equipamento `900`, rank de skill `1` e
  zero drops após a coleta; execução entre máquinas continua não comprovada.
- Todos os 74 cenários-fonte passam na JVM e no nativo. Lint/LSP de Kof, a sonda
  focada de interação e as regressões de transporte entre processos na JVM/no
  nativo passam.
- Qualificamos o dogfood Linux de apresentação `0.1.0-dogfood.25` a partir de
  `a02c7c1edd58` (SHA256
  `15f74f040f02a6faadea161057f8b8184323b9b5ccf9b1c3fe10d8dbf0bbab6a`,
  4.207.580 bytes). O smoke fora do checkout vinculou versão, build e arquivo
  exatos. O pacote de apresentação também encerrou com código `0` num display
  isolado revisado com compositor aninhado, informou capacidade de apresentação
  `11`, desenhou em 83.543 µs e produziu um frame 320×240 validado com checksum
  `29.772.824`; a revisão visual não encontrou clipping nem sobreposição do HUD.

### Primeiro slice vertical autoritativo G3 de loot/progressão

- Conectamos a única transição vivo→morto a rolagens completas determinísticas,
  drops limitados no mundo, admissão remota de coleta/equipamento/progressão,
  modificadores de combate por equipamento/status e preflight atômico de
  loot/XP/moeda do chefe. Inventário cheio preserva drop, moeda e identidade do
  RNG.
- Adicionamos o tipo `7` de estado de autoridade por jogador/destinatário e o
  tipo `8` de loot no mundo, ambos com checksum. Clientes recebem rolagens
  completas do inventário, equipamento, skills, status e drops 3D ranqueados
  sem criar resultados.
- Adicionamos a seção 12 de save para drops no mundo e identidades de
  reivindicações de loot/moeda. `decodeG3Authority` restaura jogador e runtime
  atomicamente; resolver novamente a morte salva do chefe não duplica
  recompensas.
- Dividimos novas chamadas nativas largas de definição de arma, admissão de
  inimigo, configuração de recompensa e posição do drop em chamadas limitadas
  ou entrada estruturada após o encaminhamento nativo corromper argumentos
  finais.
- Todos os 74 cenários-fonte passam na JVM e no nativo. A sonda focada de
  interação passa nos dois alvos, e o smoke de pacote valida arquivos Linux
  nativo/JVM e de apresentação, checksums, procedência, runtime e o gate nativo
  Windows que falha fechado.
- Pacotes de apresentação agora incluem um `kookie-smoke.bin` nativo separado;
  `kookie --package-smoke` o seleciona sem abrir display. A automação de deploy
  valida dependências Kof/runtime empacotadas em modo headless, enquanto o
  lançamento normal continua selecionando o executável SDL_GPU para display
  isolado.
- G3 permanece aberto para o transporte entre processos dos tipos de estado
  `7`/`8`, registros públicos limitados de extensões e regras completas
  orientadas por dados para elites/chefes.

### Slice LAN boomer-shooter G2 concluído

- Adicionamos papéis contínuos e replicados de inimigos hitscan, projétil e
  shotgun. Eles se movem, redirecionam para o jogador vivo mais próximo e
  replicam papel, alvo, vida e posição 3D inteira em mensagens limitadas de
  encounter `20 + 8N`.
- Concluímos predição/reconciliação do movimento do cliente com replay ordenado
  de inputs ainda não confirmados. A entrada agora publica baselines por
  destinatário no tick zero de gameplay, feedback e encounter; a reconexão
  avança a geração da conexão e reinicia as épocas de input, predição e
  feedback antes da admissão de sequência.
- Substituímos planos escalares de portas por volumes 3D criados de
  segmento/AABB e cuboides de 36 vértices projetados pela câmera. A cena nativa
  fixa agora usa 78 vértices da arena, 36 da porta e 174 do HUD.
- Adicionamos lotes ordenados de feedback multiplayer `6 + 11F` com validação da
  mensagem inteira, rejeição de duplicatas/lacunas e recuperação pelo baseline
  da geração. Atenuação e pan estéreo relativos ao listener são calculados no
  Kof; o adaptador SDL nativo enfileira ganhos PCM esquerdo/direito sem
  alocação.
- Todos os 73 cenários-fonte passam na JVM e no nativo. A sonda de interação, a
  qualificação com host mais dois clientes na JVM/no nativo e o adaptador
  SDL_GPU/áudio headless isolado passam; a captura GPU incluiu a porta 3D e
  produziu checksum `29.811.635`.

### Replicação autoritativa de encounter de inimigos

- Adicionamos uma mensagem de estado do encounter com checksum e
  `20 + 8N` palavras para até 32 inimigos, abaixo do limite autenticado de 300
  palavras. Ela carrega contagens ativa/reserva, ID/papel/estado/alvo/vida/
  posição de cada inimigo e o impacto confirmado mais recente; o cliente
  rejeita estado malformado ou obsoleto.
- O disparo remoto agora resolve pela autoridade real de combate/encounter dos
  inimigos, não por um ator fictício de combate entre jogadores. O dano
  terminal libera o slot, concede a recompensa de 25 moedas no servidor e
  replica estado `7`, vida `0` e sequência de impacto `2`.
- Respostas do host agora enviam estado de jogador/progressão e do encounter aos
  dois clientes autenticados. A admissão no cliente atualiza filas limitadas de
  apresentação/áudio sem deixar backpressure desfazer o estado.
- Polimos o HUD fixo de 174 vértices com glifo de conexão distinguível pela
  forma e track de carga ativa/reserva. Conexão e reserva mudam geometria além
  da cor; a cena completa continua com 252 vértices.
- Todos os 73 cenários-fonte passam em JVM/nativo; a sonda de interação e as
  regressões locais com host mais dois clientes também passam em JVM/nativo.
  O validador LAN exige marcadores terminais de encounter/estado/vida e impacto
  confirmado.
- Qualificamos o dogfood Linux de apresentação `0.1.0-dogfood.23` do commit
  `d89a16461e6d` (SHA256
  `43250c6763d9ef98d81e9ed3541a1c335139636e8852cbe2501a008cd5b30d7c`,
  3.808.495 bytes). O arquivo encerrou com código `0` num display isolado
  revisado com compositor Wayland aninhado, reportou capacidade de apresentação
  `11`, desenhou em 23.844 µs e produziu um frame 320×240 validado com checksum
  `29.309.607`.

### Slice de feedback de combate confirmado

- Conectamos resultados autoritativos aceitos de hitscan e shotgun de alvo
  único a uma fila monotônica e limitada de apresentação/áudio de impacto.
  Backpressure de apresentação não desfaz dano autoritativo e expõe a contagem
  de descartes; eventos confirmados também entram no histórico limitado de
  apresentação do replay.
- Estendemos o HUD semântico com marcadores estruturais de acerto e eliminação,
  além de alertas de dano nas bordas em altura total. O feedback expira por tick
  de simulação, sequências duplicadas são rejeitadas e a geometria inativa
  permanece degenerada dentro da alocação fixa. O HUD agora usa 174 vértices e
  a cena criada completa usa 252, abaixo do limite nativo existente de 256.
- Encaminhamos a eliminação autoritativa real de `G1Demo` pelo HUD e pela sonda
  de apresentação nativa. O áudio SDL agora recebe o clip `201` desse evento
  com ganho `100`, em vez de um clip de amostra sem relação.
- Qualificamos o dogfood Linux de apresentação `0.1.0-dogfood.22` do commit
  `82ccdd5` (SHA256
  `3fa7b256ccec83104c33799dd2ac723381135f60ab6aecc5551d013c0280a474`,
  3.802.863 bytes). O arquivo saiu com `0` num display isolado revisado com
  compositor Wayland aninhado, reportou capacidade de apresentação `11`,
  desenhou em 8.399 µs e produziu um frame 320×240 validado com checksum
  `29.150.337`.

### HUD semântico e dogfood visual

- Substituímos três barras numéricas sem rótulo por painéis escuros limitados:
  tracks emolduradas de vida e munição, ícones estruturais de vida/cartucho,
  pips de encounter e mira responsiva ao foco. Estados crítico e sem foco
  mudam a geometria, não apenas a cor.
- Expandimos o orçamento persistente da cena SDL_GPU de 128 para 256 vértices e
  substituímos a textura de debug de quatro cores por uma paleta semântica de
  16 cores para mundo/HUD.
- Adicionamos um runtime de pacote Linux `presentation` com o executável Kof de
  arena/HUD, adaptador SDL, shaders SPIR-V e bibliotecas de runtime resolvidas.
  O launcher relocável ancora o carregamento de assets no próprio pacote.
- Adicionamos cobertura observável do estado do HUD. Todos os 72 testes de
  código-fonte passam na JVM e no nativo; os smokes de pacote
  arquivo/checksum/procedência passam para os runtimes nativo, JVM e
  apresentação.

## 2026-09-28
### Lote atual de qualificação

- Substituímos o wire estreito de interação por um protocolo de gameplay
  limitado e com checksum para movimento, disparo, interação, desconexão e
  reconexão. O estado autoritativo agora carrega posições dos dois jogadores,
  vida, moeda, máscara de progressão e geração/motivo/diagnóstico do ciclo de
  vida.
- Adicionamos admissão por tick exato do servidor para disparo,
  movimento/interação remotos e uma recompensa terminal hitscan em moeda
  controlada pelo servidor. Três processos na JVM e no nativo agora comprovam
  movimento, morte mais 25 de moeda, progressão até revisão 4, geração 2 após
  reconexão e diagnóstico explícito de comando obsoleto.
- Fechamos o gate G1 do shooter autoritativo com um cenário executável na JVM e
  no nativo: servidor a 60 Hz admite dois clientes loopback, expõe correção de
  predição de quatro unidades e reconciliação, resolve uma eliminação com uma
  arma/inimigo e prova que a perda de foco não deixa movimento ou disparo
  enfileirados.
- Adicionamos uma arena 3D real criada com 78 vértices e 26 triângulos, rampa
  caminhável, dois degraus e salas inferior/superior empilhadas. Snapshots do
  broad-phase agora carregam limites explícitos com revisão/dados dos
  triângulos, permitindo ao cliente consultar os mesmos andares.
- Adicionamos staging de câmera/mundo/HUD com capacidade fixa e caminho nativo
  SDL_GPU persistente para vértices/upload da cena. Uma sonda GPU isolada
  renderizou 78 vértices da arena mais 18 do HUD numérico, leu um frame P6
  320×240 e manteve capacidades durante 64 frames determinísticos.
- Removemos a alocação por sweep do controlador de contato. O sidecar de replay
  passou a comportar 1.296 palavras para manter atômicos o estado da arena de
  32 triângulos e o histórico limitado de apresentação; o bundle de replay que
  falhava agora passa.
- Checks JVM/nativo passam, o marcador focado de runtime G1 é idêntico nos dois
  alvos e todos os 71 testes passam em cada alvo.

- O gate de apresentação isolada validou janela real, input, áudio, draw GPU,
  captura de screenshot e saída limpa sem tocar o desktop ativo.
- O gate final de LAN externa autenticada validou dois clientes independentes,
  autenticação, sequências monotônicas, saídas limpas e identidades distintas.
  Detalhes operacionais e evidências permanecem fora do repositório.
- `bash scripts/verify.sh` passou no commit `bd5c6d1`: lint, LSP, checks
  JVM/native, 70/70 testes em cada alvo, smoke de runtime, smoke de pacote e
  os dois builds do compilador. A execução opcional do adaptador foi adiada
  com segurança uma vez pelo gate de pressão PSI do display isolado.
- `KOOKIE_EXTERNAL_LAN_MODE=processes` passou com o host autenticado e dois
  processos clientes locais, incluindo reconexão e rejeição de frames obsoletos;
  os três roles saíram com `0`. A evidência permanece corretamente
  `externalHostExecution=unproven`, pois todas as identidades estão na mesma
  máquina.
- Construímos e executamos smoke após extração do Linux nativo
  `0.1.0-dogfood.20` (`bd5c6d1`, SHA256
  `e7a121899948740ef059f9f25d5eac5d3be77c45009c127e0739cfbc88fc961f`,
  2426844 bytes), Linux JVM `0.1.0-dogfood.jvm.20` (SHA256
  `714da5e311d6939e1a52e81c4c5d8ba1fa5623cddaadeac8b93e6caa492d169a`,
  433882 bytes) e o arquivo de roles LAN externo (SHA256
  `3b6bb75cc360fa75e67d4f6cba54c0326b4fdf65b5106616f06a07d70d4c516b`,
  1088335 bytes).
- Tentativas anteriores de apresentação falharam de modo fechado quando o
  ambiente isolado não forneceu a capacidade necessária. Diagnósticos
  específicos da máquina permanecem fora do repositório.
- Compatibilidade de deployment e smoke dos pacotes foram validados sem reter
  aqui nomes de endpoints, endereços, serviços ou IDs de deployment.

- Adicionamos qualificação local em processos consciente do alvo:
  `KOOKIE_EXTERNAL_LAN_TARGET=jvm` agora constrói e executa três papéis JVM
  diretos do Kof por `scripts/verify_external_lan.sh`, registra os mesmos
  metadados de identidade/status e valida o mesmo contrato de evidência do
  caminho nativo. O padrão continua `native`; a evidência na mesma máquina
  continua sem provar o DoD entre hosts externos.

- As regressões focadas de LAN consciente do alvo passaram no modo nativo em
  processos, no modo JVM em processos e no modo JVM de processo único. Cada
  execução saiu com `0`, com gameplay autenticado, reconexão, rejeição de
  frames obsoletos e validação de evidência; os modos em processos continuam
  sendo evidência apenas da mesma máquina.

### Transporte LAN externo entre alvos

- Separamos a sonda G0 em um contrato Kof neutro ao alvo, com backend UDP
  nativo e backend UDP JVM direto em Kof por meio das APIs JDK `java.net`;
  ambos compartilham framing autenticado, chave, replay e rejeição de sequência.
- `scripts/verify_external_lan_role.sh` agora constrói roles `native` ou
  `jvm`. `scripts/package_external_lan_roles.sh` gera JARs Windows de host e
  clientes com launchers `.cmd`, sem embutir a chave ou o manifest do run.
- Smokes locais bidirecionais host nativo/clientes JVM e host JVM/clientes
  nativos passam. A evidência de máquinas distintas é validada privadamente e
  permanece fora do repositório; o suporte PE nativo Windows permanece fora do
  G0.


## 2026-09-24

### O que avançou

- Adicionamos replay limitado dos comandos de interação consumidos, reserva de posições de captura e arquivos de replay v2 com leitura de v1 genuíno. A reprodução simula até 4096 ticks a partir de checkpoint completo, com jogador de movimento explícito e interações de ambos os jogadores.
- Adicionamos seção 11/versão 1 de save do nível com IDs estáveis e validação de nível/versão do conteúdo. O arquivo de schema v2 usa o tamanho real do envelope e checksums independentes; preservamos capacidades configuradas, recuperação de uma cópia, reparo e compatibilidade v1.
- Corrigimos campos não inicializados de inventário/triângulos em checkpoints, preservamos input mantido nas buscas e capturamos movimento no tick realmente consumido. O replay agora encaminha registros completos de input; bits de disparo nativos e sequências de apresentação repetidas foram verificados.
- Conectamos a ativação das portas criadas ao bloqueio do movimento escalar autoritativo e à geometria do cliente em `FrameStaging`. Portas fechadas bloqueiam a travessia do plano X; portas abertas deixam de bloquear. O contrato de colisão da arena 3D continua inacabado.
- Adicionamos ciclo limitado de desconexão/reconexão de clientes no loopback. A reconexão preserva posição autoritativa e marcas d'água de sequência, limpa input pendente e rejeita comandos obsoletos; a prova LAN autenticada real continua separada.
- Adicionamos reconexão da sessão remota com sequência preservada. As marcas d'água de envio/recebimento do broad-phase sobrevivem ao fechamento e reabertura, a sonda UDP nativa autenticada retoma na sequência 9 e snapshots antigos continuam rejeitados. A prova LAN com dois clientes ainda é um gate separado.
- Adicionamos arquivos dogfood reproduzíveis para Linux x86-64 nos runtimes Kof nativo e JVM com JAR executável, com procedência, `SHA256SUMS` e smoke do binário extraído. O empacotamento Windows continua falhando fechado até que o Kof exponha um alvo PE real e prova de assinatura/runtime.
- Corrigimos a verificação SIMD AArch64 no CI Ubuntu que selecionava headers da libc x86 do host. O Clang agora usa seus próprios headers C11 freestanding; a verificação cruzada continua obrigatória e não comprova vinculação nem execução AArch64.
- Adicionamos progressão cooperativa de chave/porta/segredo/saída, comandos limitados por tick, estado do cliente e restauração de checkpoint em arquivo. Pausa/perda de foco cancela interações pendentes; pedidos duplicados não premiam um segredo duas vezes.
- Corrigimos inputs de catch-up e cooldowns de armas que usavam o tick final do frame em vez do tick real da simulação.
- Corrigimos registros sobrepostos de replay espacial que sobrescreviam a coordenada Z e deixavam memória nativa no payload. O estado espacial agora usa a versão 2; layouts corrompidos da versão 1 são rejeitados, sem tentar adivinhar dados perdidos.
- Adicionamos seleção determinística de alvos por raio usando inteiros: impacto mais próximo, desempate por ID estável, offsets de dispersão, armazenamento limitado, exclusão da fonte por `SpatialAimContract` e rejeição segura de consultas inválidas.
- O contrato compartilhado de mira agora está conectado ao combate autoritativo de shotgun do jogador sem criar uma segunda autoridade de dano. `LoopbackSession.resolvePlayerSpatialShotgun` deriva offsets da arma, seleciona um alvo por pellet e resolve o resultado por `CombatWorld.resolveShotgunPelletTargets`.
- Adicionamos tratamento limitado de erro de pontaria, remoção de alvos e wrappers de sessão para que os alvos selecionados atravessem o caminho normal de combate e eventos.
- A cobertura JVM/native agora verifica raios centrais, pellets deslocados, exclusão da fonte, dano por dispersão, remoção de alvos, ordem dos eventos, IDs repetidos e seleções com tamanho incorreto.
- Adicionamos despacho SIMD nativo seguro para produção, com seleção AVX2/SSE2 no x86, cobertura de origem NEON no AArch64 e fallback escalar verificado. O caminho do host, o caminho escalar e a origem AArch64 foram comprovados.
- Mantivemos os limites importantes explícitos: a FFI de buffers em massa do Kof continua bloqueada por `FFI001`, então o kernel SIMD não é apresentado como ganho de velocidade da engine.
- Atualizamos o roadmap em inglês e português brasileiro para que o status não fique defasado.

### Verificações

- Correção de CI: SIMD do host, escalar forçado, sintaxe AArch64, validação do workflow e sonda de interações JVM/native passaram localmente.
- Lote atual: 18 cenários focados passaram na JVM e no nativo por `scripts/verify_interactions.sh`; 20 regressões existentes afetadas passaram em cada alvo.
- As reproduções de catch-up e replay espacial com dois atores falharam antes das correções e passaram depois.
- Buffers de checkpoint contaminados e busca de checkpoint com disparo mantido falharam antes das correções e passaram depois.
- Lote anterior de combate: 63/63 testes por alvo, mais verificações SIMD host/escalar/AArch64. A suíte completa não foi repetida localmente neste lote.

### Ainda falta

- Saves realmente duráveis contra crash ainda precisam de substituição atômica e primitivas de flush/sync do filesystem.
- O Kof precisa de FFI de buffers antes que o SIMD nativo possa atender hot loops pertencentes ao Kof.
- A apresentação em janela exige um host isolado com capacidade adequada.
- Multiplayer de produção, content cooking, áudio de produção e a stack completa de física continuam no roadmap.
- Compilação nativa para Windows, runtime relocável e avisos de licença continuam como pré-requisitos de release. Nenhum pacote ou deploy foi declarado pronto.

## Trabalho anterior

- Construímos as fundações limitadas de G0/G1 para sessão, fixed-step, snapshots, colisão, replay, saves, inventário, progressão, inimigos, projéteis e adaptador SDL.
- Adicionamos sondas de transporte UDP autenticado em localhost, verificações de recuperação SDL_GPU headless, captura de apresentação em replay e contratos determinísticos de combate/eventos.
