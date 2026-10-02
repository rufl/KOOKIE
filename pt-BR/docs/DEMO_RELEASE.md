# Prontidão da release de demo jogável

[English](../../docs/DEMO_RELEASE.md)

Esta página é a autoridade para diferenciar um caminho de fonte qualificado,
um artefato de qualificação e uma demo do KOOKIE voltada a jogadores. A fonte
atual contém uma fatia jogável limitada, mas um probe de fonte ou um gate de
ligação de pacote não é uma release pública até que um arquivo limpo seja
exercitado no hardware-alvo.

## Estado público atual

A release pública mais recente é [`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34),
publicada em 2026-09-30. Ela contém um único arquivo de apresentação SDL
assinado para Linux x86-64, construído a partir do commit
`4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`. Ela antecede o caminho atual de
apresentação, o lobby/tela de placar Kof-first, o protocolo de input/ACK em
passo fixo, compensação de lag e interpolação, a qualificação PE/SDL nativa
Windows e a correção do gate PE da CI hospedada. Nenhum arquivo atual de demo
Windows foi publicado.

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
- Ligação de gameplay Kof PE nativo Windows x86-64 ao shell SDL e ao pacote de
  apresentação SDL_GPU, com produtos SPIR-V/DXIL e gates reproduzíveis. O gate
  de artefato assinado passou com MinGW SDL3/SDL_mixer e DXC fixados; não há
  evidência de hardware Windows alvo retida.
- Smoke em Wine do shell nativo Windows com marcadores de gameplay. O smoke
  visual de apresentação continua opcional e exige GPU isolada capaz de DRI3;
  ligação de pacote ou saída Xvfb não é evidência de apresentação visual.
- Pipeline de pacote dogfood Linux assinado e pacote Windows JVM separado para
  compatibilidade/qualificação. O pacote JVM não é fallback do jogo nativo.


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

A apresentação pública continua sendo um artefato de qualificação porque
antecede a árvore de fontes atual. O caminho da fonte agora está implementado:
`Play` inicia um encounter autoritativo local; `Host/Join` admite um segundo
jogador pelo lobby explícito; três bots gansos atacam; snapshots do host
replicam jogadores/bots; `Tab` mostra a tela limitada de jogadores
autoritativa do host; e os caminhos de input/ACK em passo fixo, rewind e
interpolação são limitados na sessão e na apresentação. Ainda faltam pacote de
árvore limpa, gameplay interativo fora do checkout e evidência de hardware
antes de uma release pública.

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
  linhas selecionadas, subtítulos por tela, clipping limitado de texto e dicas
  explícitas de teclado nas telas principal, opções, multiplayer e Kutter. O
  probe expandido `scripts/verify_multiplayer_ui.sh` faz staging dos quatro
  frames de tela nos caminhos JVM e nativo.

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

- Os helpers de input/ACK em passo fixo, fixação do peer, rewind e interpolação
  remota têm cobertura nos checks G6 focados; isso não substitui gameplay no
  host-alvo.
- `bash scripts/verify_goose_game.sh` prova o caminho focado de gameplay dos
  gansos.

### P0 — qualificação da release Linux

- Gerar um novo arquivo `presentation` Linux assinado a partir de árvore limpa,
  com o lobby/placar e gameplay local atuais.
- A qualificação de 2026-10-02 passou
  `scripts/verify_linux_presentation_package.sh` no checkout atual:
  artefato assinado, extração segura e package-smoke. Usou um prefixo
  temporário fixado de SDL_mixer 3.2.4 e não substitui o builder de árvore limpa
  nem a evidência de hardware-alvo.
- Verificar o arquivo final fora do checkout em um Linux suportado novo:
  assinatura/checksum, extração, inicialização, `Play`, movimento/olhar/disparo,
  dano, reinício, saída e relançamento repetido.
- Executar o smoke de GPU isolado com capacidade de apresentação e reter
  máquina, driver, wrapper, screenshot e saída. A imagem de sistema padrão não
  possui os arquivos de desenvolvimento SDL3_mixer; configure um prefixo
  SDL_mixer 3.2.4 fixado antes de invocar o gate do pacote.
- O Xvfb/DRM isolado desta workstation reportou `No DRI3 support detected` e
  `No supported SDL_GPU backend`; isso não é evidência de apresentação em
  hardware Linux.
- Documentar o piso de loader/libc/GPU testado. SDL3 e SDL_mixer são
  empacotados, mas compatibilidade com qualquer distribuição não é implícita.

- `scripts/verify_linux_presentation_package.sh` verifica o arquivo assinado
  extraído e pode executar a apresentação empacotada pelo wrapper isolado.
- `scripts/build_demo_release.sh` é o builder de release em árvore limpa: gera
  dois pacotes byte-a-byte idênticos, verifica assinaturas/procedência, extrai
  fora do checkout e executa o smoke do pacote.

### P0 — qualificação da release Windows

- Gerar um ZIP `presentation` Windows x86-64 assinado a partir da árvore atual,
  incluindo Kof PE nativo, DLLs SDL3/SDL_mixer, shaders, avisos e procedência.
- A qualificação de 2026-10-02 passou
  `scripts/verify_windows_presentation.sh` com prefixos MinGW SDL3/SDL_mixer
  e DXC fixados. Isso comprova apenas o artefato PE/SDL/SPIR-V/DXIL assinado e
  reprodutível; as dependências temporárias e o gate do artefato não comprovam
  apresentação em hardware Windows.
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
- `scripts/build_demo_release.sh` escreve o ZIP Windows final em árvore limpa,
  manifesto, assinaturas, `SHA256SUMS` e resumo de build após a verificação de
  dois builds determinísticos.
- Reter evidência nativa Windows de GPU/input/áudio. Wine prova o caminho do
  pacote; o smoke visual opcional exige GPU isolada capaz de DRI3.
- Decidir se a distribuição para usuários comuns exige assinatura Authenticode;
  distribuição sujeita ao SmartScreen ainda precisa dela.



### P1 — distribuição pareada e operação de release

- Publicar arquivos Linux e Windows correspondentes com a mesma identidade de
  fonte/toolchain limpa, manifestos, chave pública, assinaturas destacadas e
  `SHA256SUMS`.
- Execute `.github/workflows/release_demo.yml` com `publish=false` para
  qualificar artefatos; o caminho aprovado `publish=true` gera e publica o par
  Linux/Windows somente após aprovação do ambiente `kookie-demo-release`.
  Runners self-hosted precisam dos labels `kookie-demo-release`, `linux`/`windows`
  e `x64`; `.github/actionlint.yaml` declara o label customizado para lint local.
- O workflow não substitui evidência nativa do hardware-alvo; anexe essa
  evidência ao registro da release antes de aprovar a publicação.
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


## Decisão atual de release — 2026-10-02

Os gates de artefato/pacote Linux e Windows passam no lote atual de
qualificação. Agora existem artefatos locais de árvore limpa para os dois
alvos, mas D1 continua bloqueado por:

- um build pareado publicável da fonte atual com assinaturas e procedência de
  release; os artefatos locais de qualificação Linux e Windows usaram chaves
  temporárias e foram construídos separadamente;
- smoke interativo fora do checkout de `Play` → encounter → reinício/saída nos
  dois alvos, repetido a partir de uma extração nova;
- verificação em host novo/piso de runtime e evidência retida de máquina,
  driver, input e áudio;
- execução em GPU/driver Linux com capacidade de apresentação; o ambiente
  isolado desta workstation não oferece DRI3 nem backend SDL_GPU suportado;
- evidência de apresentação em hardware Windows nativo, incluindo input, áudio,
  redimensionamento e comportamento de GPU/driver. O smoke opcional de
  apresentação em Wine isolado chegou ao SDL nativo, mas saiu com código 70 e
  `kookie_gpu_open: No supported SDL_GPU backend found!`;
- decisão de Authenticode/SmartScreen para Windows e notas finais da release;
- evidência multiplayer entre hosts novos se Host/Join/WAN continuar sendo uma
  afirmação pública.



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
streaming/comprimido, sandbox geral de extensões, macOS/ARM e cobertura ampla
de GPUs continuam milestones separados. Eles não devem ampliar a afirmação
deste jogo de gansos limitado, mas não bloqueiam a implementação delimitada na
fonte.

O plano de implementação acompanha este trabalho como **D1 — Release de demo
jogável** em [ENGINE_PLAN.md](ENGINE_PLAN.md). Os comandos de build e
qualificação continuam em
[RUNNING_AND_PACKAGING.md](RUNNING_AND_PACKAGING.md).
