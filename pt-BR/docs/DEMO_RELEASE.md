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
apresentação, o lobby/tela de placar Kof-first, a qualificação PE/SDL nativa
Windows e a correção do gate P95 da CI hospedada. Nenhum arquivo atual de demo
Windows foi publicado.

A árvore de fontes atual possui estes caminhos aptos a release:

- `Play` inicia um encounter autoritativo local servidor listen/cliente com
  input limitado de teclado/mouse, três bots, HUD/nomes, dano e reset
  determinístico ao sair e entrar novamente em `Play`.
- `Multiplayer > Host/Join` admite uma sessão fixa de dois jogadores, mostra
  sala/peer, exige `READY` explícito dos dois peers conectados e publica um
  placar `Tab` limitado e autoritativo pelo host.
- Empacotamento de apresentação nativa SDL3/SDL_GPU para Linux x86-64 com
  SDL_mixer, procedência assinada e smoke fora do checkout.
- Ligação de gameplay Kof PE nativo Windows x86-64 ao shell SDL e ao pacote de
  apresentação SDL_GPU, com produtos SPIR-V/DXIL e gates reproduzíveis.
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
replicam jogadores/bots; e `Tab` mostra a tela limitada de jogadores
autoritativa do host. Ainda faltam pacote novo e evidência de hardware antes de
uma release pública.


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
- `bash scripts/verify_goose_game.sh` prova o caminho focado de gameplay dos
  gansos.

### P0 — qualificação da release Linux

- Gerar um novo arquivo `presentation` Linux assinado a partir de árvore limpa,
  com o lobby/placar e gameplay local atuais.
- Verificar o arquivo fora do checkout em um Linux suportado novo:
  assinatura/checksum, extração, inicialização, `Play`, movimento/olhar/disparo,
  dano, reinício, saída e relançamento repetido.
- Executar o smoke de GPU isolado com capacidade de apresentação e reter
  máquina, driver, wrapper, screenshot e saída. O ambiente atual não possui o
  header de desenvolvimento SDL3_mixer, então essa evidência não é reproduzida
  aqui.
- Documentar o piso de loader/libc/GPU testado. SDL3 e SDL_mixer são
  empacotados, mas compatibilidade com qualquer distribuição não é implícita.

### P0 — qualificação da release Windows

- Gerar um ZIP `presentation` Windows x86-64 assinado a partir da árvore atual,
  incluindo Kof PE nativo, DLLs SDL3/SDL_mixer, shaders, avisos e procedência.
- Verificar extração, inicialização e ciclos repetidos de `Play`/reinício/saída
  fora do checkout em hardware e drivers Windows suportados.
- Executar `scripts/verify_windows_presentation.sh`; seus checks de
  reprodutibilidade e PE/SDL/SPIR-V/DXIL são evidência de artefato, não de
  hardware nativo.
- Reter evidência nativa Windows de GPU/input/áudio. Wine prova o caminho do
  pacote; o smoke visual opcional exige GPU isolada capaz de DRI3.
- Decidir se a distribuição para usuários comuns exige assinatura Authenticode;
  distribuição sujeita ao SmartScreen ainda precisa dela.

### P1 — distribuição pareada e operação de release

- Publicar arquivos Linux e Windows correspondentes com a mesma identidade de
  fonte/toolchain limpa, manifestos, chave pública, assinaturas destacadas e
  `SHA256SUMS`.
- Adicionar workflow de release aprovado manualmente ou checklist operacional
  que gere, verifique e publique os dois arquivos como par. A CI atual verifica
  componentes, mas não publica o par atual de demos.
- Adicionar notas de release com controles, pisos suportados, limitações,
  identidades exatas de fonte/toolchain e o limite de networking multiplayer
  best-effort.

### P1 — conteúdo e limite do produto

- Decidir se a primeira demo envia apenas a arena autoral fixa ou um pacote de
  conteúdo separado. O perfil de assets protótipo continua opt-in.
- Resolver termos de redistribuição de cada asset empacotado. O asset goose do
  protótipo continua restrito pelos termos upstream e não pode ser rotulado CC0
  nem incluído silenciosamente.
- Se o multiplayer for anunciado publicamente, executar evidência LAN/WAN entre
  hosts novos. O rendezvous e o hole punch UDP continuam networking dogfood
  best-effort: sem relay, recuperação de NAT simétrico, segurança WAN de
  produção ou proteção DDoS.
- Tela de resultado/vitória, conteúdo mais amplo, save/replay, Kutter,
  KofScript e progressão ARPG completa são polish ou escopo separado; não
  bloqueiam a demo local limitada quando saída/reinício estiver demonstrado.


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
