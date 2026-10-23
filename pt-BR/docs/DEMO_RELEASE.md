# Prontidão da release de demo jogável

[English](../../docs/DEMO_RELEASE.md)

Esta página é a autoridade para diferenciar um caminho de fonte qualificado,
um artefato de qualificação e uma demo do KOOKIE voltada a jogadores. A fonte
atual contém uma fatia jogável limitada, mas um probe de fonte ou um gate de
ligação de pacote não é uma release pública até que um arquivo limpo seja
exercitado no hardware-alvo.

## Estado público atual

O dogfood público mais recente é
[`0.1.0-dogfood.63`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.63),
construído a partir do commit de fonte
`3bd382a072817fe545ae9a80abfd1dd344878ada`. É um par de pré-releases
assinado para Linux/Windows x86-64. Candidatos novos continuam tendo como
autoridade somente o `RELEASE_QUALIFICATION.json` assinado de cada um.

O commit base do repositório para este trabalho de qualificação é
`285fc927c265e9ff0ae25fd01a15035cb6972ad2`. A última execução registrada do
Verify KOOKIE
[`38978943862`](https://github.com/rufl/KOOKIE/actions/runs/38978943862)
passou pelo build do Kof pinado, verificações estática/JVM, verificações
native/package, verificações do backend PE e pacote JVM Windows no commit
candidato anterior.

O candidato `0.1.0-dogfood.64` foi despachado em
[`38981016223`](https://github.com/rufl/KOOKIE/actions/runs/38981016223) a
partir desse commit, com os dois smokes de apresentação native habilitados. O
toolchain Kof e o pacote Linux passaram; o job de apresentação Windows rodou no
`kookie-windows-01` e falhou antes de gerar artefatos porque o runner não
encontrou o comando `powershell`. A correção do workflow agora declara
`shell: bash` para esse passo do pin Kof. Nenhuma release `.64` foi publicada.
A publicação ainda exige uma nova execução a partir da fonte commitada, os
dois registros de evidência de apresentação com sucesso e a aprovação do
ambiente `kookie-demo-release`.


Novos candidatos usam o Kof `0.6.6` construído a partir da branch `lab`, no
commit `7c237861a9035d84b1f7ec4cfddd89daef4c6ddd`; o workflow constrói a
distribuição a partir da fonte porque o pin não usa archive público do 0.6.6.
O digest do patch de release é
`4898952c8f4130d1b5a9e8effb56b0dd7a58d228596b50f69427639c15843664`.

### Qualificação de engenharia da working tree atual

O gate focado de apresentação nativa passou pelo
`scripts/verify_presentation.sh` no ticket 31 da fila. O smoke usou X11 sob
gamescope, uma janela real em `/dev/dri/renderD128`, capacidade positiva de
present, áudio, captura PPM e saída limpa. A evidência está em
`build/kookie-presentation-wrapper.json`; o log identifica Intel `Graphics
(ARL)` via Vulkan.

Isto é evidência de engenharia, não uma identidade de release: o ticket 31
precede o commit de código corrigido `206bc08`, o smoke de pacote usa uma chave de
qualificação efêmera, e a publicação Linux/Windows extraída de forma limpa
junto da apresentação Windows-alvo ainda são necessárias para promover D1. O
resultado da fila não é declarado como evidência de hardware A770.


O jogo voltado ao jogador se chama **GatoGanso**. A apresentação usa `Pixand`
para texto de UI limitado e `Jared Lite` para display/título; os dois arquivos
de fonte e o aviso da SIL Open Font License seguem no pacote.

### Registro histórico de qualificação local — 2026-10-12

O commit de fonte `69b16d9312ebe6b86c34fda1f665ad1b8665558b` produziu os
artefatos pareados de qualificação, determinísticos, assinados e verificados
fora do checkout:

- Linux `0.1.0-linux-e2e.3`: SHA-256 do arquivo
  `d35443f514e7a21c3bfd1dadb170c76658944959de37b99084070a9908191cb1`;
  SHA-256 do manifesto
  `238e98a8704c9b295cac22a081332dca52852290199d4df1771731473afec1b8`;
  extração, launcher, assinatura/checksum, shader e smoke do pacote passaram.
- Windows `0.1.0-windows-e2e.3`: SHA-256 do arquivo
  `c6d80779f960339752bfa8a5848b515f46827ddfc11a3e3cfd788e5e81dce7f6`;
  SHA-256 do manifesto
  `3654307e3b11836908eddaf4c3d56114b495097cf0a3ceee4d8bbe67c960e36c`;
  PE `MZ`, extração, launcher, assinatura/checksum, SPIR-V/DXIL e qualificação
  do pacote passaram.
- Ambos os manifestos registram o commit de fonte Kof
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`, o SHA-256 do JAR do compilador
  `6634e1bf80334cc2518c50f9d1a05e2da92ff318282775ba58a087891e2420a6` e o
  SHA-256 da distribuição Kof local, usada apenas para qualificação:
  `111ab2abb44bf2dbedddacee054cb0afedcfc7e63d8f67c03fd53835d80a4230`.
- O arquivo público Linux do Kof 0.5.0-beta
  [`kof-0.5.0-beta-linux-x86_64.tar.gz`](https://github.com/KofLang/Kof4j/releases/download/kof-0.5.0-beta-linux-x86_64/kof-0.5.0-beta-linux-x86_64.tar.gz)
  tem SHA-256
  `f93f02eb62af584ea49ffb44efdbf54f970bdb9570f16fdc48ccc28242798ca9` e
  pertence ao commit de release `317d9f6b1c3e27032cc955a05f859f6c627d9338`.
  Ele não é intercambiável com a fonte histórica de qualificação fixada em
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`; os pacotes históricos mantiveram
  a distribuição Kof construída a partir da fonte fixada.
  Uma reconstrução limpa dessa fonte Kof fixada produziu o arquivo com SHA-256
  `29a5fddb0100cdb660abf96508360c51ff17bb4b6b295e60c9fe93a7624c0af0` e
  passou no gate SIMD G6 de Buffer na JVM/no nativo. Repetir apenas o
  empacotamento do Kof produziu
  `2ced9feda3641bcab09c809a7b4604f63f0f9440a79d6e483a1b731e603552d2`,
  embora os arquivos expandidos fossem idênticos byte a byte; nenhum dos dois
  arquivos gerados é usado como identidade de release pública.
- A apresentação Linux isolada falhou fechado com exit `124` porque este host
  informa `No DRI3 support detected` e `No supported SDL_GPU backend found`.
  O smoke de compatibilidade Windows em Wine falhou fechado com exit `70` pelo
  mesmo backend SDL_GPU ausente. A apresentação em hardware Windows nativo não
  foi executada; nenhuma evidência de hardware é reivindicada.
- O gate G5 autenticado de host e dois clientes passou. A amostra atual do
  servidor dedicado mediu p95 de `6.9 ms` contra o orçamento declarado de
  `4 ms`; ela não substitui a qualificação Linux x86-64 de timing/soak retida.


A árvore de fontes atual possui estes caminhos aptos a release:

- `Play` inicia um encounter autoritativo local servidor listen/cliente com
  input limitado de teclado/mouse, três bots, HUD/nomes, dano e reset
  determinístico ao sair e entrar novamente em `Play`.
- `Multiplayer > Host/Join` admite uma sessão fixa de dois jogadores, mostra
  sala/peer, exige `READY` explícito dos dois peers conectados e publica um
  placar `Tab` limitado e autoritativo pelo host.
- A sessão usa bundles de input em passo fixo com ACKs de snapshot/input, fixa
  o endpoint do peer autenticado, faz rewind de hitscan por uma janela limitada
  de 12 ticks, interpola jogadores remotos seis ticks atrás e expõe métricas de
  correção da predição. Uma sequência de estado maior pode revisar a amostra
  autoritativa mais recente no mesmo tick para diagnósticos de ciclo de vida ou
  de comando obsoleto; ticks e sequências antigos continuam rejeitados. O
  caminho WAN IPv4/UDP direto continua best-effort e não é compatível com QUIC.
- Empacotamento de apresentação nativa SDL3/SDL_GPU para Linux x86-64 com
  SDL_mixer, procedência assinada e smoke fora do checkout. Em 2026-10-02, o
  builder de árvore limpa produziu `0.1.0-linux-e2e.1` a partir do commit de
  fonte `1678a7de671866d94080718c367ab05875a92c2d`, com o commit de fonte Kof
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`; verificou builds determinísticos
  duplicados, assinaturas/checksums, extração segura e package smoke, e
  `scripts/verify_goose_game.sh` passou. O SHA-256 do arquivo foi
  `e3dddf0eab08b2d4ced71bc5c1b2e2f5e593bfe20af01b8e9c5594d2d9ed6536`.
  Esta qualificação local usou uma chave Ed25519 efêmera e um prefixo fixado de
  SDL_mixer 3.2.4, portanto não é uma identidade de release pública. A
  execução isolada de apresentação reportou `No DRI3 support detected` e `No
  supported SDL_GPU backend found` antes do timeout 124; a evidência de
  hardware-alvo continua necessária.
- Ligação de gameplay Kof PE nativo Windows x86-64 ao adaptador SDL3/SDL_mixer
  e ao pacote de apresentação SDL_GPU, com produtos SPIR-V/DXIL e gates
  reproduzíveis. O gate de artefato assinado passou com MinGW SDL3/SDL_mixer e
  DXC fixados; não há evidência de hardware Windows alvo retida.
- Um cross-build atual, limpo e em worktree destacado no host Linux produziu
  `0.1.0-d1-win-cross.1` a partir do commit de fonte
  `2b0ef88fff8f284939691a4cac1c535a2ecfb607`, com o commit de fonte Kof
  `7c237861a9035d84b1f7ec4cfddd89daef4c6ddd`. O SHA-256 do arquivo é
  `c1dc8b215ab0602bf8ce6b4b927769cff82215afaedebdade323ba5ab8af32e6`;
  o SHA-256 do manifesto é
  `d28eac7d12930917cdf4e0133191085f13075689d399f61a787e10e2b87927c0`.
  Builds duplicados, assinaturas destacadas, `SHA256SUMS`, extração ZIP segura,
  PE `MZ`, o conjunto de DLLs SDL3/SDL_mixer/FreeType/HarfBuzz empacotado e
  as entradas SPIR-V/DXIL passaram. O manifesto registra SDL3 3.4.18,
  SDL_mixer 3.2.4, HarfBuzz 14.6.0, o conjunto fixado de pacotes MSYS2 de
  FreeType/HarfBuzz, DXC 1.9.2609 e Zig 0.17.0. Isto fecha somente a lacuna
  de dependências e do pacote estático: o build usou o cross-compiler Zig
  Linux, portanto launch nativo Windows, input/áudio/GPU e evidência de
  hardware-alvo continuam sem execução. A chave foi efêmera e
  `releaseEligible=false`.
- Smoke em Wine do runtime Kof SDL nativo Windows com marcadores de gameplay. O
  smoke visual nativo Windows está disponível por
  `KOOKIE_RUN_NATIVE_PRESENTATION=1` e pelo
  `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER` revisado; Wine, ligação de
  pacote e saída Xvfb não são evidência visual do alvo.
- Pipeline de pacote dogfood Linux assinado e pacote Windows JVM separado para
  compatibilidade/qualificação. O pacote JVM não é fallback do jogo nativo.

Este checkout fornece o caminho de qualificação dogfood:
`Play` inicia um encounter autoritativo local; `Host/Join` admite um segundo
jogador pelo lobby explícito de pronto; três bots gansos atacam jogadores;
snapshots do host replicam jogadores/bots; `Tab` mostra a tela limitada de
jogadores autoritativa do host; e os caminhos de input/ACK em passo fixo,
rewind e interpolação são limitados na sessão e na apresentação. A evidência
de pacote e hardware é específica de cada candidato e só é autoritativa pelo
manifesto de qualificação assinado.



## O que “demo jogável” significa neste milestone

Uma fatia vertical limitada G1 é suficiente. Ela não precisa incluir todo o
roadmap de looter/ARPG, hospedagem WAN pública, modding geral ou todos os
importadores de fonte. Nos dois alvos suportados, ela precisa:

1. iniciar a partir de um pacote extraído limpo, sem toolchain Kof ou checkout;
2. entrar na sessão autoritativa local servidor listen/cliente por `Play`;
3. mapear teclado e mouse para registros `InputCommand` limitados e olhar da
   câmera;
4. mover, saltar, mirar e disparar pela sessão autoritativa;
5. mostrar um encounter, dano, feedback de morte e estado de HUD;
6. oferecer saída ou reinício determinístico; e
7. fechar corretamente após vários ciclos de iniciar/jogar/reiniciar.

Se o multiplayer for anunciado na mesma release dogfood, também são exigidos
`Host/Join`, o gate de dois jogadores `READY`, o placar `Tab` e evidência
entre hosts para a afirmação LAN/WAN suportada.

O arquivo de apresentação registrado no lote histórico `.38` inicia um
encounter autoritativo local por `Play`; `Host/Join` admite o segundo jogador
pelo lobby explícito; três bots gansos atacam; snapshots do host replicam
jogadores/bots; e `Tab` mostra a tela limitada autoritativa do host. Os gates
de artefato pareado, checksum e assinatura passaram. Esta árvore de fontes não
deve herdar a identidade desse lote: interação fora do checkout e evidência de
hardware-alvo são gates de release para cada candidato novo.

### Contrato executável de evidência D1

- O smoke Linux define `KOOKIE_RUN_PRESENTATION=1`, exige
  `KOOKIE_PRESENTATION_ISOLATION_WRAPPER` revisado e um nó real
  `/dev/dri/renderD*`, e executa o pacote extraído. Falta de isolamento ou GPU
  falha fechado; Xvfb, Wine e GPU headless não substituem esse gate.
- O smoke Windows nativo define `KOOKIE_RUN_NATIVE_PRESENTATION=1`, exige
  `KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER` e executa `kookie.exe`
  extraído por esse wrapper com display/sessão nativos.
- `scripts/validate_presentation_evidence.py` exige capacidade de apresentação,
  tempo positivo de draw GPU, áudio aberto, checksum da captura, PPM P6
  limitado e os markers de gameplay/restart D1 e G0/G1/G2/G4/Kutter. A
  evidência de release também exige `KOOKIE_PRESENTATION_HARDWARE_ID` e
  `KOOKIE_PRESENTATION_GPU_DRIVER` não vazios; grava hardware-alvo, driver,
  máquina, SO, wrapper, comando, hash do log e hash da captura em `evidence.json`.
- O `evidence.json` gerado carrega o `source_commit` exato do pacote;
  `build_release_qualification.py` rejeita evidência de outra revisão.
- A evidência também registra os SHA-256 exatos do archive e do manifesto do
  package; o gate nativo Windows não recompila outro package para apresentação.
- `release_demo.yml` envia o artefato de evidência Linux quando o smoke Linux
  está habilitado e o artefato Windows quando o smoke nativo Windows está
  habilitado. `run_windows_wine_smoke` continua sendo apenas evidência de
  compatibilidade do pacote.

### Manifesto canônico de qualificação

`scripts/build_demo_release.sh` escreve `QUALIFICATION_MANIFEST.json` ao lado
de cada artefato determinístico. Ele registra o digest do manifesto do pacote e
marca a apresentação de hardware como `not-run`; isso é apenas qualificação de
artefato.

O workflow de publicação escreve e assina o par
`RELEASE_QUALIFICATION.json`. Esse é o registro canônico da release: contém as
identidades dos dois pacotes e as evidências Linux/Windows retidas. A
publicação agora falha sem os dois smokes nativos com `status=passed` e sem
`releaseEligible=true`. `BUILD_SUMMARY.txt` e as notas em prosa são
informativos, não autoridade de release.


## Trabalho restante, ordenado por impacto na release

### Fechado na árvore de fontes atual — não é evidência de release

- O caminho SDL nativo lê teclado/mouse mantidos, avança a sessão autoritativa,
  reconcilia o cliente conectado e renderiza bots, nomes, corações e HUD.
- `Play` redefine o encounter limitado quando o usuário volta ao menu e o
  inicia novamente.
- `Multiplayer > Host/Join` possui ciclo fixo de dois jogadores, estado
  explícito ready/unready, identidade/ping/erro limitados e snapshots de placar
  determinísticos. `bash scripts/verify_multiplayer_ui.sh` prova modelo,
  codec, limites da sobreposição e probe JVM/nativo.
- A shell de GUI agora possui hierarquia em moldura consistente, trilhos nas
  linhas selecionadas, subtítulos por tela, clipping limitado e dicas explícitas
  de teclado nas telas principal, opções, multiplayer, acessibilidade e Kutter.
  O menu principal expõe Play, Multiplayer, Options, Accessibility, Kutter e
  Quit. Acessibilidade altera a escala do HUD (85/100/115 por cento), a
  visibilidade do mapa tático e o texto de alto contraste, preservando os
  orçamentos fixos de staging. O probe expandido
  `scripts/verify_multiplayer_ui.sh` faz staging de cinco frames da shell nos
  caminhos JVM e nativo; `scripts/verify_font_ui.sh` cobre o caminho de
  fontes/título empacotado.

- O skin nativo da UI é compartilhado entre menus e gameplay por
  `src/ui/kookie_ui_native.kf`: superfícies/trilhos do GameShell, rótulos
  semânticos do HUD (`HP`, `AMMO`, `BAG`, `XP`), nameplates e scoreboard agora
  usam um contrato único de paleta/foco/contraste. O orçamento de staging do
  HUD é de 438 vértices e continua pré-alocado.

- O caminho nativo da UI agora agrupa primitivas limitadas de quad/triângulo na
  fronteira Kof/C e cresce as capacidades das cenas CPU/GPU com folga. Mudanças
  de quantidade em menus/HUD evitam expansão de chamadas por vértice e
  reconstrução repetida de buffers GPU, mantendo uma única chamada de draw para
  a UI de gameplay.

- O build atual de qualificação da GUI produziu
  `0.1.0-gui.1` a partir do commit de fonte
  `b1d4db92bf3adf166d503ca0eb44d8569498950c`; o SHA-256 do arquivo Linux é
  `d9b909a4270fc9ca8fbd46a63bd0a21bc646e819da2ae6c3f89fa143dc1da902`.
  Builds duplicados determinísticos, assinaturas, extração e package-smoke
  passaram. Usou o prefixo temporário fixado de SDL_mixer 3.2.4 e uma chave
  efêmera, portanto é um artefato local de qualificação, não uma release
  pública. A tentativa isolada de apresentação via overzeer foi bloqueada de
  forma fail-closed por PSI de I/O cheio (`62.54%` bloqueado) e não retém
  evidência de apresentação em hardware; uma tentativa completa separada
  também parou no orçamento sensível à pressão do p95 da simulação
  (`4153us > 4000us`).

- O gate focado do servidor dedicado agora passa 512 ticks medidos com p95 de
  `3624us`, p99 de `3689us` e máximo de `3899us` sob o orçamento de simulação
  de `4000us`; o excesso anterior do orquestrador completo foi sensível à
  pressão.

- O commit de fonte atual
  `87d3bc63b3bbc66c23f796258f5b9ea5147fb0df` também produziu o pacote nativo
  local `0.1.0-perf.2`; o SHA-256 do arquivo é
  `3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
  O package-smoke extraído passou, e o servidor dedicado empacotado passou o
  gate de p95 de 4ms (`3396us` na execução retida). Este não é um artefato
  de release público.

- Os helpers de input/ACK em passo fixo, fixação do peer, rewind e interpolação
  remota têm cobertura nos checks G6 focados; isso não substitui gameplay no
  host-alvo.
- `bash scripts/verify_goose_game.sh` prova o caminho focado de gameplay dos
  gansos.

### P0 — qualificação da release Linux

- O artefato Linux de apresentação de cada candidato só é válido quando seu
  manifesto de pacote aparece em `QUALIFICATION_MANIFEST.json`. Empacotamento
  determinístico, assinaturas, extração segura e package-smoke são gates de
  artefato; não implicam qualificação de hardware.
- Restam os gates Linux fora do checkout: iniciar/reiniciar/sair em um sistema
  suportado novo e executar o smoke real de GPU com apresentação definido acima.
  Eles devem reter máquina, driver, wrapper, screenshot, log e saída. Isso é
  separado do gate de artefato/pacote.
- Verificar o arquivo final fora do checkout em um Linux suportado novo:
  assinatura/checksum, extração, inicialização, `Play`, movimento/olhar/disparo,
  dano, reinício, saída e relançamento repetido.
- Executar o smoke de GPU isolado com capacidade de apresentação e reter
  máquina, driver, wrapper, screenshot e saída. A imagem de sistema padrão não
  possui os arquivos de desenvolvimento SDL3_mixer; configure um prefixo
  SDL_mixer 3.2.4 fixado antes de invocar o gate do pacote.

- Uma qualificação atual com árvore suja também passou
  `scripts/verify_linux_presentation_package.sh` de ponta a ponta: pacote
  assinado, extração segura, self-test do launcher, smoke do pacote e
  apresentação isolada em Intel(R) Graphics (ARL) com Mesa 26.2.4-arch1.1 em
  `/dev/dri/renderD128`. Ela registrou capacidades de present `11`, draw da GPU
  de `14658us`, checksum de screenshot `321528432` e saída limpa. Isso não é
  evidência de release: usou `KOOKIE_ALLOW_DIRTY_PACKAGE=1` e chave de assinatura
  efêmera; ela não é uma identidade de release.
- A nova execução do builder de árvore limpa passou
  `scripts/build_demo_release.sh --target linux-x86_64` com a versão
  `0.1.0-d1-fix.1`, commit de fonte
  `5201286aa67c718b6d10460bff203ebf0118aada`, commit de fonte Kof
  `7c237861a9035d84b1f7ec4cfddd89daef4c6ddd` e SHA-256 do arquivo
  `f292e7a975c9563de7409eb3bfa06c13249cdb7d4de834ef181f487107916cc5`.
  Builds duplicados, assinaturas/checksums, extração segura e smoke do pacote
  passaram.
- Esse artefato de árvore limpa passou então o gate de GPU do pacote extraído
  no mesmo host Intel(R) Graphics (ARL)/Mesa 26.2.4-arch1.1 em
  `/dev/dri/renderD128`: capacidades de present `11`, draw da GPU `15285us`,
  checksum de screenshot `321528432` e saída limpa. Os registros de evidência
  informam SHA-256 do arquivo
  `f292e7a975c9563de7409eb3bfa06c13249cdb7d4de834ef181f487107916cc5` e do
  manifesto `6096f5c054dee0cea1475f69e8bf963e7586a1540bd25af8aa4e13e737eb6d8e`.
  Esta é evidência de qualificação local, não uma release pública: a chave é
  efêmera e ainda é necessária a extração em um sistema suportado novo.


- A tentativa isolada anterior com Xvfb/DRM reportou `No DRI3 support detected` e
  `No supported SDL_GPU backend`; essa tentativa continua não sendo evidência de
  apresentação Linux em hardware.
- Documentar o piso de loader/libc/GPU testado. SDL3 e SDL_mixer são
  empacotados, mas compatibilidade com qualquer distribuição não é implícita.

- `scripts/verify_linux_presentation_package.sh` verifica o arquivo assinado
  extraído e pode executar a apresentação empacotada pelo wrapper isolado.
- `scripts/build_demo_release.sh` é o builder de release em árvore limpa: gera
  dois pacotes byte-a-byte idênticos, verifica assinaturas/procedência, extrai
  fora do checkout e executa o smoke do pacote.

### P0 — qualificação da release Windows

- O artefato Windows de apresentação de cada candidato só é válido quando seu
  manifesto de pacote aparece em `QUALIFICATION_MANIFEST.json`.
  `scripts/verify_windows_presentation.sh` prova qualificação PE/SDL/SPIR-V/
  DXIL assinada e reprodutível; não prova apresentação em hardware Windows.
- Restam os gates Windows fora do checkout: iniciar e repetir
  `Play`/reinício/saída em hardware suportado, depois executar o smoke pelo
  wrapper nativo e reter evidência de GPU/input/áudio. Wine continua sendo
  apenas evidência de compatibilidade.
- Uma execução de `scripts/build_demo_release.sh` em worktree destacado limpo
  produziu `0.1.0-windows-e2e.1` do commit de fonte
  `1678a7de671866d94080718c367ab05875a92c2d` com o commit de fonte Kof
  `bf17ac7e736471c8a04b4153e5b0f607be75e70c`. O SHA-256 do arquivo é
  `c8153ae34b2a1ea7f8c85411df95393c02573fc433a477c539153459975e80a4`.
  A verificação fora do checkout passou determinismo de builds duplicados,
  assinaturas destacadas, `SHA256SUMS`, extração segura do ZIP, header PE `MZ`
  de `kookie.exe`, campos de árvore limpa/apresentação Windows no manifesto e
  entradas SPIR-V/DXIL empacotadas. A chave de qualificação era temporária;
  portanto, este não é um artefato de release público.
- Um smoke opcional de apresentação em Wine isolado chegou ao shell SDL nativo,
  mas saiu com código 70 e
  `kookie_gpu_open: No supported SDL_GPU backend found!`. Isso é evidência
  apenas do ambiente e não substitui evidência de apresentação em hardware
  Windows.
- Verificar extração, inicialização e ciclos repetidos de `Play`/reinício/saída
  fora do checkout em hardware e drivers Windows suportados.
- `scripts/build_demo_release.sh` escreve o arquivo de destino, manifesto do
  pacote, assinaturas, `SHA256SUMS`, `BUILD_SUMMARY.txt` e
  `QUALIFICATION_MANIFEST.json` após dois builds determinísticos.
- Reter evidência nativa Windows de GPU/input/áudio. Wine prova o caminho do
  pacote; o smoke visual opcional exige GPU isolada capaz de DRI3.
- Decidir se a distribuição para usuários comuns exige assinatura Authenticode;
  distribuição sujeita ao SmartScreen ainda precisa dela.



### P1 — distribuição pareada e operação de release

- A publicação deve incluir o `RELEASE_QUALIFICATION.json` pareado e assinado,
  os manifestos dos pacotes-alvo, chave pública, assinaturas destacadas e
  `SHA256SUMS`.
- Execute `.github/workflows/release_demo.yml` com `publish=false` para
  qualificações futuras; o caminho aprovado `publish=true` exige aprovação do
  ambiente `kookie-demo-release` antes de publicar o par Linux/Windows.
- Um dispatch de publicação deve passar o `source_commit` imutável da
  qualificação aprovada; todos os checkouts dos packages usam esse commit,
  enquanto o ref do dispatch apenas seleciona a definição do workflow.
- Runners self-hosted precisam dos labels `kookie-demo-release`, `linux`/`windows`
  e `x64`; `.github/actionlint.yaml` declara o label customizado para lint local.
- A publicação não substitui evidência nativa do hardware-alvo. Anexe os
  artefatos de evidência Linux e Windows do contrato executável D1 antes de
  promover o pacote dogfood a release player-facing.
- Adicionar notas de release com controles, pisos suportados, limitações,
  identidades exatas de fonte/toolchain e o limite de networking multiplayer
  best-effort.

### P1 — conteúdo e limite do produto

- A primeira demo envia a arena autoral fixa com `content_profile=none`; o
  pacote separado de conteúdo protótipo continua opt-in e não faz parte do
  artefato da release.
- Resolver os termos de redistribuição de cada asset empacotado. O asset goose
  do protótipo continua restrito pelos termos upstream e não é incluído aqui.
- Omitir o gato Prildarill do pacote de release até haver confirmação explícita
  de redistribuição independente do arquivo bruto; ele permanece restrito ao
  protótipo.
- Se o multiplayer for anunciado publicamente, executar evidência LAN/WAN entre
  hosts novos. O rendezvous e o hole punch UDP continuam networking dogfood
  best-effort: sem relay, recuperação de NAT simétrico, segurança WAN de
  produção ou proteção DDoS.
- Tela de resultado/vitória, conteúdo mais amplo, save/replay, Kutter,
  KofScript e progressão ARPG completa são polish ou escopo separado; não
  bloqueiam a demo local limitada quando saída/reinício estiver demonstrado.


## Decisão anterior de D1 — 2026-10-07

Foi executada uma nova qualification D1 a partir de um checkout KOOKIE limpo.
O gate de release continua **bloqueado**; nenhuma release pública player-facing
é reivindicada.

Passou:

- `scripts/build_demo_release.sh --target linux-x86_64` produziu o artefato
  local determinístico e assinado `0.1.0-d1-e2e.1`, a partir do commit de fonte
  `9d9cfe784e534fe34a0e30694198435ce90a7546`; SHA-256 do arquivo:
  `edf553e256bc9fa34b58a2217c3db87a207765fbb4cdc058cb5703130c1d5738`.
- Passaram os gates de build duplicado Linux, assinaturas destacadas,
  checksums, extração segura e package smoke. O artefato foi extraído e
  testado fora do checkout em
  `/home/lich/lichforge/ztash-releases/kookie-d1-e2e-extracted`.
- Passaram os probes focados de launcher, interação/recovery, goose game e UI
  multiplayer.
- O pacote Windows nativo existente `0.1.0-dogfood.60` passou
  `--package-smoke` em Wine isolado fora do checkout. O manifesto declara
  `runtime=native` e `windows_presentation=false`; isso não é evidência de
  apresentação D1.

Bloqueios:

- O smoke de apresentação Linux chegou ao shell SDL nativo, mas reportou
  `No DRI3 support detected` e
  `No supported SDL_GPU backend found!`; portanto `Play`/encounter/restart/quit
  não foi certificado em hardware capaz de apresentar.
- `scripts/verify_windows_presentation.sh` não conseguiu construir o artefato
  pareado da fonte atual: `KOOKIE_WINDOWS_SDL_PREFIX` não está definido, e
  `KOOKIE_WINDOWS_SDL_MIXER_PREFIX`, `KOOKIE_DXC` e `dxc` não estão disponíveis.
- O artefato Linux usou uma chave Ed25519 efêmera porque
  `KOOKIE_SIGNING_KEY` permanente não estava disponível. É artefato de
  qualification, não identidade de release.
- A URL pública candidata retornou HTTP `404`; não existe publicação pareada,
  decisão Authenticode/SmartScreen, evidência nativa de hardware Windows ou
  evidência multiplayer entre hosts novos.

As ações D1 restantes são smoke interativo extraído fora do checkout, evidência
Linux em GPU capaz de apresentação, evidência de apresentação Windows nativa
pelo wrapper revisado e notas/política para promover a pré-release dogfood a
release player-facing.



## Matriz de aceitação antes da publicação

| Verificação | Linux x86-64 | Windows x86-64 |
|---|---:|---:|
| Pacote extraído limpo inicia | Obrigatório | Obrigatório |
| Assinatura/checksum/procedência verificados | Obrigatório | Obrigatório |
| Menu/opções/input/áudio/redimensionamento | Obrigatório | Obrigatório |
| Loop real de gameplay autoritativo local | Obrigatório | Obrigatório |
| Dano/morte/HUD/saída ou reinício | Obrigatório | Obrigatório |
| Smoke repetido fora do checkout | Obrigatório | Obrigatório |
| Evidência de apresentação em hardware nativo | GPU Linux suportada | GPU Windows suportada |
| Lobby/ready/placar `Tab` multiplayer | Obrigatório se anunciado | Obrigatório se anunciado |
| Multiplayer entre hosts | Obrigatório se anunciado para o dogfood WAN simples | Obrigatório se anunciado para o dogfood WAN simples |


## Explicitamente não bloqueia esta demo

Amplitude completa de ARPG, suporte geral a formatos de autoria, relay,
recuperação de NAT simétrico, segurança WAN de produção, HRTF/EFX, áudio em
streaming e codecs fora do conjunto limitado OGG Vorbis/WAVE, sandbox geral de
extensões, macOS/ARM e cobertura ampla de GPUs continuam milestones separados.
Eles não devem ampliar a afirmação deste jogo de gansos limitado, mas não
bloqueiam a implementação delimitada na fonte.

O plano de implementação acompanha este trabalho como **D1 — Release de demo
jogável** em [ENGINE_PLAN.md](ENGINE_PLAN.md). Os comandos de build e
qualificação continuam em
[RUNNING_AND_PACKAGING.md](RUNNING_AND_PACKAGING.md).
