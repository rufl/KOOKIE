# Changelog

Este arquivo registra as mudanças importantes do KOOKIE em linguagem direta. Ele não promete que um milestone terminou; o plano e as verificações focadas continuam sendo a fonte de verdade.

## Não lançado
- Adicionamos o servidor native de qualificação HTTP/WebSocket sob posse do Kof
  em `apps/web_server/main.kf`. Ele possui as rotas HTTP limitadas, upgrade RFC
  6455, framing Kof, handshake, movimento autoritativo da cena completa e
  contadores vivos de health/metrics; `native/kookie_web_server.c/.h` continua
  um adaptador estreito de mecanismo TCP/I/O e SHA-1.
  `scripts/verify_kof_web_server.sh` agora cobre health, metrics, upgrade,
  comandos da cena e rejeição de requisição malformada.
- Corrigimos a qualificação de apresentação native D1 para
  `content_profile=none`: a pose GLB autorada é obrigatória quando os modelos
  estão empacotados, enquanto o fallback procedural documentado dos atores é
  aceito quando os modelos prototype são excluídos. O gate do pacote Linux agora
  passa extração, smoke do pacote e apresentação isolada no host qualificado.
- Tornamos o empacotamento de release Linux determinístico e mais seguro:
  os builds native locais do Kof no pacote desativam o emissor de locais em
  registradores fixado, cuja saída variava entre invocações e cujo caminho de
  scratch de chamadas tem gaps conhecidos de correção. O caminho de release
  agora usa o emissor baseado em slots de frame até a correção upstream do
  compilador.
- Corrigimos a inicialização WebGL2 e a captura de screenshots no navegador:
  a exportação da geometria de água agora copia limites/estilos estruturados
  sem lançar exceção durante a inicialização, e o renderer expõe
  `captureScreenshot` ao cliente de sessão.
- Concluímos a fatia limitada de cena 3D no navegador: o gateway WebSocket
  agora serve um snapshot autoritativo de 68 palavras com estado do jogador e
  câmera, quatro atores, um projétil, um pickup e payload de VFX com posição do
  evento, além de comandos limitados de movimento, olhar, pulo e tiro. O
  cliente KofJS renderiza texturas base-color embutidas ou anexas dos GLBs,
  transforms de nós autorados, materiais WebGL2/GLSL ES 3.00 com bandas toon e
  sheets de VFX anexos para eventos autoritativos reais. WebGL2 é obrigatório
  para a cena 3D; o cliente falha fechado quando o renderer não está disponível.
- A qualificação de captura do navegador usa somente WebGL2: lê o framebuffer
  preservado por `readPixels` e expõe dimensões, checksum, pixels não pretos,
  bytes PPM em base64 e os metadados `authoritative`, `sceneSource` e
  `sceneTick`. Capturas desconectadas são explicitamente marcadas como preview.
- Ampliamos o campo autoritativo de VFX do navegador para IDs nativos de asset
  `0..15`; o gateway agora emite slash (5), flare (6) e explosão (8) para
  ações aceitas de melee, tiro e especial. O loader WebGL2 publica os 16 PNGs
  de partículas, flipbooks e predrawn, mantendo leitura dos estilos legados 1/2.
- Substituímos a aproximação independente por eixo da velocidade FPS por wish
  vector normalizado em ponto fixo, projeção e aceleração. Coyote time, buffer
  de pulo, controle aéreo e frenagem suave continuam no controlador Kof
  autoritativo; a diagonalização tem regressão JVM/nativa.
- O renderer WebGL2 de atores agora consome o estado autoritativo para uma
  elevação procedural determinística nos estados de repouso, movimento e
  ataque, acompanhando as pistas de estado limitadas da apresentação nativa
  sem fingir fazer skin dos esqueletos autorados do ganso/gato. Animação GLB
  esquelética continua o limite explícito de paridade.
- Limite de paridade conhecido: nativo e navegador consomem as mesmas malhas e
  materiais GLB autorados, transforms de nós e direção dos atores, mas o
  navegador ainda não faz skin das animações de esqueleto do ganso/gato; o
  backlog marca skin esquelético como o próximo corte explícito de paridade.
- A integração de corpos físicos agora zera os componentes de velocidade
  bloqueados por contatos de cápsula estáticos ou dinâmicos, sem carregar
  velocidade obsoleta para dentro dos colisores; a regressão cobre a resposta
  dinâmica bloqueada.
- Adicionamos `scripts/dev_test.sh` ao loop interno rápido priorizando JVM:
  ele executa a suíte de regressão de 144 testes de `src/main.kf` sem
  montagem, linkedição, empacotamento ou gates de apresentação nativos;
  defina `KOOKIE_DEV_TARGET=native` para uma iteração específica do nativo.
- As execuções locais de `scripts/verify.sh` agora reutilizam por padrão
  artefatos canônicos JVM/nativos no cache do usuário; os manifestos de
  identidade invalidam artefatos antigos quando a fonte ou as entradas do
  compilador Kof fixado mudam.
- Documentamos a configuração do gate local de empacotamento:
  `scripts/configure_kof_archive.sh` verifica o digest do arquivo Kof por build
  e o commit-fonte fixado, enquanto os metadados do Zig fixado são exigidos
  pelo check de falha fechada do Windows.
- `scripts/verify.sh` agora falha em segundos quando a configuração do toolchain
  de empacotamento está incompleta, em vez de executar toda a matriz antes de
  informar a ausência do arquivo ou da identidade do Zig.
- Os checks de identidade do pacote agora fazem hash de todo arquivo regular
  sob `src/`, em acordo com a identidade do cache canônico e protegendo módulos
  Kof não rastreados contra reutilização de artefatos antigos.
- Requalificamos o pin Kof `0.6.5` construído da fonte pelo gate local completo:
  os checks de pacote, PE/Wine, LAN externo e renderer Vulkan passaram. O plano
  de fronteira native agora registra as evidências locais P0/P2/P3 e seus
  limites específicos de alvo.
- `verify_package.sh` agora reutiliza builds nativos temporários do servidor,
  kooker de conteúdo e SIMD entre os smokes de pacote nativo e de apresentação;
  o smoke caiu de 426,6 s para 230,0 s.
- Preservamos o contrato de estilos literais do KofJS em
  `apps/web_alpha/main.kf` ao dividir declarações CSS longas em linhas de
  fonte escapadas; os gates de lint e do build do alpha do navegador agora
  passam juntos.
- Reexecutamos a qualificação da fronteira batch com o Kof `0.6.5` exato e
  fixado: copy-in/copy-back em JVM/native x86-64 passou com somas de fixture
  `809` e `1231`, os totais scalar/SIMD coincidiram, a rota SIMD foi
  selecionada e a prova de sintaxe AArch64 passou. Isso qualifica somente a
  fronteira síncrona limitada de `Buffer(U8)`; ownership retido ou assíncrono
  de payload continua sem qualificação.
- Reconciliamos as páginas de arquitetura e da fronteira Kof4j com o vertical
  slice GPU local concluído: Intel `Graphics (ARL)`, uma draw call, 984
  instâncias e p95 de frame de `1710` microssegundos. Evidência de hardware
  adicional e apresentação cross-platform continuam gates de release D1.
- Corrigimos o passo do pin Kof no workflow de release para declarar
  `shell: bash` no Windows. A execução self-hosted anterior falhou antes de
  gerar artefatos porque o runner invocou um comando `powershell` ausente; o
  runner agora está online e os pré-requisitos remotos de release passam.




- Adicionamos a fatia limitada de cliente/renderizador do navegador:
  `session/web_session_protocol.kf` agora carrega marcador de snapshot de cena
  e comando de sonda de cena. `apps/web_alpha` publica um cliente WebSocket com
  ciclo de vida, entrada por teclado/botão, estado autoritativo validado, HUD
  acessível e renderer WebGL2 direto
  (`apps/web_alpha/webgl_renderer.js`) para jogador, três atores, barras de
  vida, VFX e projéteis. O navegador exige WebGL2 para a cena 3D e falha
  fechado quando o renderer está indisponível.
  `scripts/kookie_websocket_session.py` fornece o gateway local sem
  dependências externas, com terminação TLS opcional, autoridade limitada de
  tick/estado, admissão opcional por bearer pelos subprotocolos WebSocket
  `kookie.v1` / `bearer.<token>` e rotas limitadas `/healthz` e `/metrics`.
  `--auth-token-file` oferece o mesmo contrato de admissão a partir de um
  arquivo regular com modo `0600` ou mais restritivo e relê a credencial a cada
  upgrade; a opção é mutuamente exclusiva com `--auth-token`.
  `scripts/verify_websocket_session.py` cobre handshake, heartbeat, eco de jogo,
  snapshots legados de comandos, snapshots de cena, qualificação WSS,
  rejeição/admissão autenticada nos modos de flag e arquivo de credencial,
  respostas de health/metrics e rejeição de frames malformados. Continua sendo
  gateway de qualificação, não o caminho de produção de identidade/sessão,
  observabilidade, operações WSS ou servidor autoritativo.

- O cliente do navegador pede um snapshot de cena limitado após a admissão e
  rejeita mensagens vazias, com checksum inválido ou fora de ordem antes de
  fechar a sessão.

- Adicionamos `src/session/runtime_plan.kf`, um contrato limitado de rotas Kof
  para clientes KofJS no navegador, WebView zero-native, desktop native e
  Android. Ele separa IPC tipado de controle do tráfego serializado de jogo,
  reserva WebRTC para host par-a-par com ICE/STUN/TURN e mantém UDP native como
  opcional explícito. A matriz de rotas está documentada nas páginas de
  arquitetura em inglês e português; operações WSS de produção, sinalização
  WebRTC e o host zero-native continuam sendo fatias de entrega não
  implementadas.

- Polimos o shell de menus native: as linhas compactas de opções agora limitam
  a escala do texto ao espaço visual, a seleção ganhou trilhos superior/inferior
  de foco, e as linhas de acessibilidade seguem o tamanho configurado sem
  sobreposição.
- Refinamos o kit de UI Kof/KofJS com bordas explícitas em painéis/controles,
  alvos de 44px, espaçamento de corpo legível, faixas reais de progresso,
  transições de visibilidade para modal/toast, selects limitados e keybind como
  rótulo não interativo.
- A apresentação prototype agora falha fechada quando a textura embutida do
  GLB de ganso ou gato está ausente/inválida; os botões melee e special
  selecionado também dirigem o estado visível de ataque da malha/VFX animal.
- Adicionamos o contrato autoritativo de ações do gameplay Kof: Ctrl para
  agachar/rolar, mouse esquerdo para melee, mouse direito para o
  special/power-up selecionado, dashes direcionais por dois toques,
  double jump no segundo Espaço e glide no ar. Roll, dash, double jump e
  glide usam uma stamina compartilhada com recuperação lenta por tick fixo;
  bundles, replay, apresentação nativa e HUD carregam esse estado limitado.
- As consultas de colisão triangular agora usam interseção contínua limitada
  por ponto fixo entre segmento e triângulo, em vez de depender apenas de
  amostras inteiras. O spring arm da câmera não pula mais rampas ou superfícies
  diagonais autoradas entre amostras; cada candidato discreto da câmera é
  revalidado e recua para o alvo se a quantização o colocar além da superfície.
- Recolocamos a malha do animal local no staging do gameplay native. A câmera
  de follow com spring arm agora mostra o personagem jogável em terceira pessoa,
  incluindo o movimento vertical do pulo; o caminho dos GLBs enviados de ganso
  e gato continua selecionado quando o perfil de conteúdo `prototype` é
  empacotado.
- O smoke da apresentação native agora cobre um salto em passo fixo e os cinco
  animais do gameplay, em vez de fixar o caminho em primeira pessoa com quatro
  atores.
- O Verify KOOKIE passou para o commit de fonte
  `e8cad301b566607a3b8095a219d05441de3240e5` em
  [`38978943862`](https://github.com/rufl/KOOKIE/actions/runs/38978943862).
  O próximo candidato dogfood `0.1.0-dogfood.64` está no dispatch
  [`38981016223`](https://github.com/rufl/KOOKIE/actions/runs/38981016223);
  o empacotamento Linux passou, enquanto o job Windows aguarda o runner offline
  `kookie-windows-01`, portanto nenhuma release `.64` é declarada.

- Atualizamos o patch de release do Kof para o commit fonte
  `8e59b24acc978eb2546509b5cfca867a06e7283a`: a fonte pinada já contém a
  otimização de alocação do emissor native, então o patch agora carrega apenas
  o desempate determinístico do grafo de interferência e tem digest
  `4898952c8f4130d1b5a9e8effb56b0dd7a58d228596b50f69427639c15843664`.

- O backend PE/COFF agora emite `<limits.h>` no preâmbulo C gerado, mantendo
  válida a validação de faixa de arquivos baseada em `LONG_MAX` tanto na
  compilação host independente quanto na toolchain Windows pinada.

- O wrapper rastreado de apresentação Linux agora retorna o status de
  "gate de segurança indisponível" do repositório quando
  `overzeer-isolated-display` ou `gamescope` não está disponível; assim, a CI
  genérica registra um skip explícito de apresentação em vez de falhar o job
  native antes do smoke de release no hardware-alvo.

- Atualizamos o gate de proveniência do pacote prototype para a árvore atual
  com 42 assets e 152 arquivos; o gate ainda estava fixado no baseline
  anterior de 142 arquivos.

- O staging PE/COFF agora usa consistentemente o stripper COFF portátil em
  Python, em vez de variantes de `objcopy` do host; isso evita índices de
  símbolos `.llvm_addrsig` inválidos no gate native hospedado e mantém a
  remoção de CodeView necessária para objetos reprodutíveis.

- O backend PE do Windows agora traduz as operações de concatenação, igualdade
  e substring de `String` do grafo de apresentação, leituras limitadas de
  existência/faixa de arquivos, armazenamento de bytes `Buffer(U8)` e chamadas
  FFI com ponteiro de buffer, em vez de rejeitar essas operações alcançáveis
  com `PE001`.
- A compilação native de release no Windows agora adiciona o diretório de
  includes do HarfBuzz MinGW pinado, compatível com o layout upstream do
  header `hb-ft.h`.
- O verificador do artefato de apresentação Windows agora resolve a raiz do
  repositório pelo próprio caminho do script, sem depender de `ROOT_DIR`
  herdado na CI.
- Os pacotes de apresentação agora carregam os JSONs de runtime autorados do
  projeto em `config/runtime`; a sonda native prefere esse caminho empacotado
  e usa o caminho da árvore-fonte como fallback nas sondas locais.
- O smoke de apresentação native agora envia o fallback procedural limitado
  dos animais quando os modelos opcionais não estão disponíveis e registra a
  capacidade de staging do minimapa antes do primeiro frame.
- O caminho de draw GPU native agora aguarda todos os fences de frames em voo
  antes de reutilizar o transfer buffer compartilhado do mundo, evitando perda
  de dispositivo Vulkan no Windows quando frames sucessivos enviam geometria.
- Os uniforms de iluminação do mundo agora seguem o layout de uniforms de
  fragmento do SDL GPU (`set=3`, slot 0), e os draws de screenshot enviam os
  mesmos dados antes de renderizar. Isso evita bindings inválidos de
  descritores Vulkan no Windows.
- O toolchain de release aplica
  `patches/kof-native-emitter-performance.patch` ao fonte pinado do Kof
  `0.6.5`. Ele remove o split/join do buffer inteiro no caminho de
  constantes do emissor native e torna determinísticos entre processos JVM os
  desempates de spill do alocador de registradores native; o digest exato do
  patch faz parte da identidade do cache Kof.
- O pin ativo da lab do Kof agora é resolvido de `refs/heads/lab` por
  `scripts/update_kof_lab.py`; ele acompanha o commit
  `a14a7cd47d74192dcc977c9d4cbf87d407694560` e mantém o commit imutável na CI.
  O workflow agendado `update_kof_lab.yml` abre um PR de qualificação quando a
  lab avança.
- Comandos Kof native e de empacotamento agora passam por
  `scripts/kof_observed.sh`: heartbeat de 30 segundos, timeout local padrão de
  30 minutos (45 minutos nos jobs native do Verify e de release), graça de
  encerramento limitada, logs completos e ETA histórico das últimas cinco
  execuções bem-sucedidas. A CI publica o artifact de diagnóstico.
- Os workflows Verify e de release agora resolvem a versão e o commit-fonte do
  Kof em runtime a partir de `scripts/kof_pin.sh`, em vez de duplicar o pin no
  YAML dos workflows; assim, a atualização agendada da lab pode enviar sua PR
  de qualificação com o token do GitHub App do repositório. O Verify também
  instala `libxcursor-dev`, exigido pelo backend X11 do SDL3.
- O job native do Verify agora se chama `Native/package verification`, prepara
  os prefixes pinados do SDL3 3.4.18 e SDL_mixer 3.2.4, instala os
  pré-requisitos `glslc` e `spirv-tools` exigidos pela paridade LAN externa e
  publica a saída native completa junto dos logs observados dos comandos Kof.
- Os jobs de release Linux e Windows agora persistem o diretório `bin` do Kof
  baixado e o forçam à frente de entradas antigas do `PATH` dos runners
  self-hosted; o resumo de cache do Windows declara Bash explicitamente nos
  runners Git Bash, e o resolvedor de ferramentas procura DXC e
  pkg-config/pkgconf no Windows Kits e via `where.exe`.
- Os jobs de release agora mantêm diagnósticos e histórico do Kof fora do
  checkout, para que a própria passagem de reprodutibilidade não suje a árvore
  de fontes. O Windows valida os archives SDL pinados antes de extraí-los com
  o `tar` do Git Bash, evitando diferenças do `tarfile` do Python nos runners
  self-hosted.
- `scripts/install_kof_lab.sh` constrói o commit atual da lab, valida que a
  ref mutável não avançou, depois atualiza o pin rastreado e atualiza
  atomicamente o launcher local `kof`, sem apagar instalações antigas.
- A arena de deathmatch G1 foi reconstruída como um greybox de boomer shooter
  sem temática opressiva, com rotas inferiores conectadas, faixas laterais
  elevadas, torres, galerias cobertas, travessias da piscina central, uma
  travessia do canal de água a leste e um pátio de céu aberto. O orçamento
  autorado fica em 140 vértices e 190 triângulos, abaixo do limite de 192
  triângulos da colisão.
- Quads autorados agora usam índices; a colisão autorada carrega todos os
  triângulos antes de reconstruir o BVH uma única vez; e frames de gameplay
  somente geométricos não reservam buffers de texto. As evidências LAN externas
  agora esperam a arena de 190 triângulos.
- O CI/CD P1 agora constrói o toolchain Kof fixado uma vez por execução de
  verificação, separa os gates static/JVM, native/package e Windows JVM,
  cacheia toolchains Maven/Zig/JRE/SDL com revalidação SHA-256, reutiliza
  artefatos JVM/native vinculados à fonte e ao toolchain, registra preflight dos
  runners e duração dos gates e falha fechado em divergências de identidade do
  build. O gate static/JVM com o pin exato passa; a qualificação completa
  native/package continua dependente do runner.
- O gate ativo do Kof acompanha o toolchain `0.6.5` construído a partir do
  commit fixado da `lab` do Kof,
  `a14a7cd47d74192dcc977c9d4cbf87d407694560`. A guarda upstream de ciclos do
  GC native é verificada por `scripts/prepare_kof_source.sh`; o patch local
  obsoleto do 0.6.4 não é mais aplicado. As medições restantes de desempenho/UI
  do 0.6.4 continuam históricas até serem executadas novamente contra o 0.6.5.
- O candidato da `lab` do Kof revisado anteriormente,
  `3a6454c0acce1c74d015bd45c4a52bb149a025c6`, continua sendo evidência
  histórica; sua descoberta de UI KofScript com aridade mista e a regressão
  LEA/SIMD anterior não são afirmações sobre o pin atual da lab.
- `scripts/verify.sh` mantém o gate do runner de testes por arquivo do Kof na
  JVM; o `kof build` native final é o gate de compilação nativa, constrói `src`
  uma vez por alvo JVM/native e executa os artefatos emitidos no smoke final,
  evitando compilação nativa duplicada por `check`/`test`/`run`.
- O benchmark G6 de Buffer/SIMD do Kof agora materializa as reduções escalar e
  nativa antes da validação, evitando avaliação FFI nativa mista repetida e
  mantendo os totais e as verificações de tempo JVM/native.
- P1 agora qualifica semântica de producer/copy-back de `Buffer(U8)` com uma
  chamada C INOUT limitada em JVM e native x86-64; o fixture registra as somas
  `809` e `1231` e mantém explícito o fallback escalar.
- P2 moveu os helpers de endianess e codec de payload para
  `src/session/transport_codec.kf`; o gate LAN externo JVM passou em 9
  segundos. A compilação LAN externa native excedeu o limite local de 600
  segundos; portanto a paridade wire e o gate de ownership MAC/chave continuam
  sem qualificação.
- P3 implementa encoding batch `GPU_SCENE_VERTEX_V1` nos três probes de
  adapter nativo e valida/copia em C antes do upload SDL_GPU, mantendo fallback
  escalar. Static/JVM passou; a qualificação runtime do adapter/GPU native não é
  alegada porque builds native do Kof excederam o timeout local e não havia
  dispositivo GPU headless disponível.
- A verificação local final com o pin exato do Kof passou o `static-jvm` em 65
  segundos, com 140/140 testes JVM, e passou o gate SIMD dispatch em 10
  segundos. O gate completo native/package não terminou em 900 segundos no
  host atual; portanto nenhum passe native/package é alegado aqui.
- Drops de loot agora exibem beams verticais cruzados e animados com cores por
  rank; arranhões de gato e bicadas de ganso agora usam VFX distintos no mundo.
- A customização do lobby agora escolhe ganso ou gato junto com apelido e cor;
  o handshake nativo replica a espécie selecionada.
- A tipografia agora usa Pixand no texto de corpo e Jared Lite no texto de
  display em Kof, CSS e renderização nativa FreeType/HarfBuzz; os TTFs originais
  e o aviso da SIL Open Font License continuam empacotados.

- O protótipo agora carrega definições JSON limitadas de corpos d'água, física
  líquida e objetos flutuáveis. As superfícies geram geometria marcador para
  caustics animados e passe toon; transições de entrada geram VFX de respingo
  configurável; o movimento FPS submerso aplica gravidade, buoyancy, drag,
  impulso de nado e limites de velocidade configurados; o HUD expõe um medidor
  O2 configurável; objetos flutuáveis e densos resolvem de forma diferente no
  mesmo mundo líquido.
- O protótipo agora expõe seis power-ups limitados via JSON: canecas de café
  aumentam a velocidade, jetpacks aumentam o impulso de pulo, megafones armam
  buzinas do ganso, kits de mergulho reduzem o consumo de O2 submerso,
  melancias armam uma metralhadora temporária de sementes para gansos e bolas
  de lã armam a maça do gato para causar dano próximo e bloquear projéteis.
  O bater de asas do ganso reduz dano de queda; gatos podem rolar para evitar
  projéteis, dar dash e fazer pulo duplo; gansos podem fazer pulo duplo, bater
  asas e dar chute para cancelar dash. Pickups geram marcadores diamante no
  mundo e um painel ativo no HUD.
- O gameplay nativo agora renderiza a geometria GLB limitada do ganso e do gato
  com seleção correta de UV/material, incluindo o atlas de textura embutido do gato.
- A geometria do mundo agora recebe iluminação de ponto animada e uma sombra blob
  low-poly sob cada animal visível.
- O movimento de inimigos/objetos agora compartilha gravidade, atrito, contato
  estático e colisão dinâmica por broad phase dentro de limites.
- Acertos bem-sucedidos nos inimigos agora exibem por alguns ticks um overlay
  vermelho de dano para feedback imediato ao jogador.
- O gameplay dos gansos agora exibe um coração limitado e uma placa de nome
  acima de cada jogador e bot, com nomes determinísticos para bots e cor de
  jogador opcional.
- O combate demo agora usa 100 de vida, 20 de dano por acerto normal e 40 de
  dano crítico; um jogador com vida cheia sobrevive exatamente a cinco acertos.
- As opções multiplayer e o handshake do lobby agora transportam perfis
  validados de apelido e cor de ponta a ponta.
- O movimento FPS do ganso agora suporta um salto no ar e flap limitado por
  intervalo enquanto o salto permanece pressionado.
- As placas de nome dos gansos agora limitam a origem do texto aos limites lógicos nativos da tela, evitando que atores na borda esquerda abortem o upload da cena de gameplay.
- Os menus nativos agora compartilham uma grade de cabeçalho mais segura, margens laterais maiores e linhas de opções mais altas, evitando colisões do texto ampliado com os painéis.
- As linhas de lobby e Kutter agora reservam faixas compactas próprias abaixo dos metadados do cabeçalho, mantendo o status separado dos painéis acionáveis.
- Os probes do adaptador native do Kof 0.6.4 agora compilam, linkam e executam a partir de uma raiz de pacote isolada, em acordo com `extern "./build/..."`; a verificação do renderer G5 agora passa flags e bibliotecas de compilação do FreeType/HarfBuzz como argumentos distintos.
- A câmera de follow em terceira pessoa agora mantém dois world units de folga das superfícies de colisão autoradas, preservando o easing do spring arm existente.
- O render nativo SDL_GPU agora usa o alvo de depth D16 com teste `LESS` e escrita de depth, colocando as texturas das paredes em uma ordenação de profundidade determinística.
- As tunables do movimento FPS agora são nomeadas e centralizadas: o braking
  no chão e no ar faz easing da velocidade, o perfil de salto busca 300 ms de
  airtime e as janelas de coyote/jump buffer têm 100 ms no fixed step.
- Substituímos o atlas nativo de UI gerado no build por runs semânticos UTF-16.
  A apresentação SDL agora faz shaping com HarfBuzz e rasterização em runtime
  das fontes TTF empacotadas com FreeType; a largura lógica de quatro unidades
  e o avanço de cinco preservam o contrato de layout 16:9.
- A UI nativa agora renderiza a marca SVG empacotada do Gatoganso pelo
  adaptador SDL; o caminho CSS/SVG do KofJS permanece inalterado.
- O gate de dependências nativas e a procedência do release agora registram
  versões de FreeType e HarfBuzz e hashes dos runtimes nativos empacotados da
  apresentação.
- Fortalecemos o runner de desktop privado Windows para iniciar a apresentação
  nativa pelo `cmd.exe` sem handles padrão herdados, desabilitar a conversão
  de paths do MSYS para argumentos nativos, executar scripts `.cmd` temporários
  por paths nativos, capturar a saída com redirecionamento explícito e falhar
  cedo se o host de comandos isolado não iniciar.
- A proveniência do release agora registra bytes dos runtimes SDL empacotados,
  archives SDL Windows fixados, os archives Zig Linux/Windows fixados e as
  identidades das ferramentas Java/GLSL/SPIR-V/DXC usadas no PE nativo; o
  qualificador final verifica esses campos e todas as assinaturas contra a
  chave pública confiável do release.
- O gate Windows usa o package determinístico exato enviado como artifact,
  vincula a evidência aos digests do archive e do manifesto e testa o wrapper
  de desktop privado antes do smoke PE.
- A publicação agora exige `source_commit` imutável; qualificação e publicação
  não podem derivar silenciosamente para um `main` mais novo.
- Atualizamos o gate de release e CI do Kof para o commit de fonte `0.6.4`
  `aaab7523ea6fddc818beee27ab46ccbb9fd9734a`. O archive Linux público
  upstream é `kof-0.6.4-linux-x86_64.tar.gz`, com SHA-256
  `c1ffdaa9222237f9e0ed254d88683306d75c0280f3163fc9a35187ca3d01f136`;
  a CI de release constrói seu próprio archive da fonte. A preparação aplica
  e verifica `scripts/kof-0.6.4-native-gc-cycle.patch` (SHA-256
  `073287ac363bbc5f28ae8b6b62d60239d1d06bb9e5a148ac6dc712fd8116714e`) para
  que blocos já marcados saiam da worklist do GC nativo em vez de recolocar
  grafos cíclicos.
- Revalidamos a pinagem do archive oficial Zig `0.17.0` com SHA-256
  `1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026`.
- O workflow de release agora constrói a distribuição Kof fixada uma vez em um
  job hospedado `toolchain` e passa o archive verificado aos dois alvos
  self-hosted; o digest Kof estático do repositório não faz mais parte do
  readiness de release. A preparação Windows fixa o archive oficial Zig
  `0.17.0` no SHA-256
  `b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428`.
- A preparação Windows agora baixa os archives oficiais de desenvolvimento
  MinGW do SDL3 `3.4.18` e do SDL_mixer `3.2.4` em cada execução e verifica
  seus pins SHA-256 antes da compilação, impedindo que um prefixo SDL antigo do
  runner self-hosted passe pelo gate de headers.
- O gate de apresentação Windows agora executa o entrypoint `--package-smoke`
  do PE extraído antes de abrir o desktop isolado, separando falhas de
  carregador/runtime das falhas de apresentação gráfica.
- O smoke nativo Windows agora passa o package extraído por uma variável de
  ambiente herdada, em vez de um argumento de caminho do Git Bash, evitando a
  conversão de argumentos do MSYS antes de o wrapper de desktop privado iniciar
  o PE.
- Corrigimos a chamada do desktop privado Windows para passar diretamente os
  argumentos `-c` do Bash; o wrapper já fornece `bash.exe`, então um segundo
  `bash` fazia o filho sair com 127 antes de iniciar o PE.
- Corrigimos a operação de release: a execução com `publish=true` cria e assina
  o manifesto final de qualificação e depois aguarda o gate do environment; ela
  não exige um manifesto de uma qualificação anterior.
- O gate de apresentação Windows agora testa o desktop privado e o caminho do
  package extraído antes de iniciar o smoke GPU, tornando falhas do wrapper ou
  do caminho explícitas em vez de reportar somente o status do filho.
- O gate Windows agora valida e apresenta o package exato emitido pela etapa de
  build determinístico, em vez de recompilar um package de smoke não publicado.
- Adicionamos wrappers revisados de apresentação: Gamescope headless isolado
  no Linux e desktop privado no Windows, com captura da identidade da GPU alvo
  e limpeza limitada da árvore de processos.
- Corrigimos a inicialização da apresentação nativa sem conteúdo: a descoberta
  opcional de GLB verifica a existência do arquivo antes da leitura, então
  assets de protótipo ausentes selecionam o fallback limitado em vez de
  desreferenciar um resultado de arquivo inválido.
- Corrigimos o staging e o smoke da apresentação nativa: runs semânticos UTF-16
  agora atravessam a fronteira do adaptador, a marca SVG é renderizada pelo
  renderer nativo de UI, eventos de janela SDL são drenados antes das
  asserções de teclas sintéticas, a geometria do menu reserva capacidade GPU
  explicitamente e o smoke de release percorre o caminho real do menu principal
  até o Kutter.
- Restauramos o staging determinístico do objeto PE com stripping COFF do LLVM,
  fallback para `objcopy` do GNU e um stripper COFF portátil em Python quando as
  ferramentas standalone não estão disponíveis. O Zig 0.17.0 emite uma seção
  CodeView contendo o caminho do cache mesmo com `-g0`; removê-la mantém os
  builds PE repetidos byte a byte idênticos.


- Revalidamos o reproduzível de lifetime de exceções com Kof `0.6.0`: a
  asserção deliberadamente falha com status 1 na JVM e no native; o falso
  sucesso histórico do native em `0.5.0-beta` continua marcado como histórico.
- Aplicamos o patch downstream de GC native do Kof `0.6.0`,
  `scripts/kof-0.6.0-native-gc.patch`
  (SHA-256 `641a2591690d4fbd569faf4771d550cd05320218eb7c0290f61957fc4097607e`).
  Ele torna idempotente o caminho de blocos já marcados nos caminhos de mark
  por lista e bitmap; sem ele, alocações repetidas de `LoopbackSession` no
  native podem entrar em loop em `kof_gc_mark_transitive`.
- Adicionamos `scripts/kof-as/as`, selecionado por `scripts/kof_pin.sh`, para
  encaminhar a assembly native grande do Kof ao assembler integrado do Clang,
  delegando outras invocações de assembler ao `as` do sistema.
- Elevamos a tolerância de plateau de RSS do servidor dedicado para 4 MiB
  para a linha de base estável de 2116 KiB do allocator native do Kof
  `0.6.0`; a verificação independente de plateau de recursos continua obrigatória.

- Corrigimos as regressões nativas de camera no CI inicializando explicitamente
  o slot zero da tabela de seno pertencente ao Kof; a projeção da mira e a
  seleção do raio sob o crosshair agora passam a suíte nativa completa de 120
  testes. Os dois testes foram marcados com `camera` para reprodução focada.
- Vinculamos a evidência de apresentação de hardware ao `source_commit`
  exato do pacote; a qualificação agora rejeita `evidence.json` de outra
  revisão e valida os commits do pacote/Kof como SHA-1 minúsculo.
- Adicionamos um pipeline offline único de produtos de shader em
  `scripts/shader_pipeline.py`: produtos GLSL catalogados são compilados para
  SPIR-V, validados com `spirv-val`, refletidos contra contratos de
  vértice/recursos e emitidos com um header de metadados SDL_GPU gerado. O
  empacotamento Windows também emite os produtos HLSL/DXIL existentes pelo
  mesmo manifesto.
- O adapter SDL agora recebe contagens de recursos e entry points do manifesto
  gerado, em vez de declarações de shader hard-coded. O smoke de pacote valida
  os artefatos de shader e registra o digest do manifesto na proveniência da
  release.
- Removemos o shell interativo C de Windows de 1.481 linhas: os dois
  empacotamentos nativos de Windows agora entram na apresentação Kof, mantendo
  C/PE/SDL somente na fronteira de plataforma e ABI.
- Migramos para `src/content/glb_model.kf` a descoberta dos arquivos GLB do
  protótipo, a entrada limitada de bytes, o JSON, a hierarquia, as meshes, a
  normalização, os UVs e o staging dos modelos. O adapter SDL recebe somente
  os bytes PNG validados do gato por uma ABI escalar de staging.
- Atualizamos os checks do loader e do pacote para exercitar o leitor Kof e o
  conteúdo empacotado; as sondas Kof JVM/nativa preservam as contagens de
  goose/cat (708/2.400 vértices expandidos).
- Migramos para Kof a matemática de câmera/projeção da GPU, a geração de
  texturas de mundo/materiais, o mapeamento de recursos UI/mundo para UVs e a
  seleção de passes. O adapter SDL agora recebe apenas palavras de matriz,
  palavras de textura, UVs codificados/normalizados e flags explícitos de
  passe antes do upload/desenho nativo.
- Migramos para `BoundedDurableSaveFileCodec` o envelope redundante do save
  durável, o checksum e a seleção do slot; o adapter nativo agora transfere
  apenas bytes limitados e executa somente a durabilidade segura de arquivo,
  fsync e rename.
- Fixamos todas as GitHub Actions de terceiros nos workflows de release e
  verificação em SHAs imutáveis e corrigimos o loader de save durável para que
  uma falha em `ferror()` não pule `fclose()` nem deixe um stream aberto.
- Endurecemos a admissão do transporte UDP nativo e JVM: somente datagramas
  autenticados podem promover o último remetente; peers configurados rejeitam
  outros endpoints; envios/replays nativos rejeitam endpoint sem peer; e a
  leitura nativa da chave rejeita symlinks, hard links e permissões de
  grupo/outros; o IPv4 do ambiente é estrito.
- Corrigimos o readiness de release para reconhecer a regra de proteção de
  environment `required_reviewers` em minúsculas do GitHub.
- O bootstrap de release agora exige os smokes nativos Linux e Windows, e
  confirma que o `HEAD` local coincide com `main` remoto antes de despachar.
- O bootstrap agora passa esse commit verificado como `source_commit`; todos os
  checkouts dos packages usam uma revisão imutável, enquanto o ref do dispatch
  seleciona apenas a definição do workflow.
- A CI hospedada baixa o archive oficial do Zig 0.17.0 com SHA-256 fixado, sem
  depender da action baseada em Node20.
- A documentação de operações passa todos os flags de qualificação e smoke
  nativo exigidos pelo gate de publicação.
- O `RELEASE_QUALIFICATION.json` pareado agora carrega exatamente os SHA-256 do
  archive Kof e do JAR do compilador e rejeita pares Linux/Windows com
  identidades de artefato Kof divergentes.
- Concluímos o gate externo de processos do G3: o host agora salva e recarrega
  pelo schema sua moeda, item gerado, equipamento, skill e recompensa já
  reivindicada depois do caminho eliminação→drop→coleta→equipamento. O
  validador de evidência externa exige esse round trip junto dos tipos de
  estado `7`/`8` do destinatário; builds nativos de roles agora executam no
  diretório de runtime para resolver a ABI relativa do adapter SDL no modo
  multiprocesso. A qualificação continua na mesma máquina; hosts físicos
  separados não são reivindicados.



- Adicionamos manifestos assinados de qualificação da release. Os builders
  emitem `QUALIFICATION_MANIFEST.json` com evidência de hardware marcada como
  `not-run`; a publicação agora monta e assina o
  `RELEASE_QUALIFICATION.json` pareado e recusa publicação sem evidência nativa
  Linux e Windows aprovada. O conteúdo de protótipo agora declara política de
  modelos nativos obrigatórios em vez de aceitar silenciosamente o fallback
  procedural.

- Atualizamos a baseline nativa para SDL 3.4.18 e Zig 0.17.0, as versões
  estáveis mais recentes; o SDL_mixer permanece na versão estável mais recente
  3.2.4. As Actions do GitHub agora usam checkout v7, setup-java v6,
  download-artifact v8 e o commit verificado mais recente do setup-zig; a CI
  roda com Temurin 27. Os builds PE/COFF agora passam `-g0` explicitamente para
  manter os caminhos de debug do Zig 0.17.0 fora dos objetos reprodutíveis. O pin
  de fonte Kof `0.5.0-beta` permanece em `bf17ac7e736471c8a04b4153e5b0f607be75e70c`;
  o archive marcado mais recente em `317d9f6b1c3e27032cc955a05f859f6c627d9338`
  falha na qualificação nativa de Buffer (`FFI001`).
- Endurecemos os consumidores binários nativos do KOOKIE contra o bug de
  palavra parcial de `File.readBytes()` no Kof fixado `0.5.0-beta`: leituras
  limitadas de fontes, saves, replay, pacote e KofScript agora usam
  `readRange`. A verificação de apresentação Linux rejeita status filho
  diferente de zero; os gates Windows PE/pacote/release falham fechado para
  divergências de caminho, classpath, limpeza, reviewer e procedência; falhas
  de capacidade do smoke de release ocorrem antes dos builds.
- Adicionamos `scripts/report_code_mix.py` e uma auditoria de composição das
  fontes. O working tree atual tem 94.940 linhas físicas: 78,69% Kof, 0,69%
  KofScript, 8,52% C/header, 7,16% shell, 3,24% Python, 1,58% Java da ponte
  PE e 0,12% shaders GPU. A fatia somente de runtime tem 89,40% Kof; os
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

- Naquele momento, o artefato público mais recente era
  `0.1.0-dogfood.34`, um dogfood de apresentação Linux x86-64 assinado do
  commit `4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`; ele antecede o caminho
  atual de apresentação/lobby/placar. O registro público atual é mantido em
  `pt-BR/docs/DEMO_RELEASE.md`.
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
