# KOOKIE
[English](../README.md)

KOOKIE é uma engine experimental de tiro 3D construída em torno de Kof. O
projeto serve para experimentar boomer shooters, looter shooters e ARPG FPS;
não é um jogo pronto.
As portas têm pré-requisitos. Chamar isto de pronto também.

## Estado honesto

G0, G1, G2, G3 e a implementação limitada de G4 executam na JVM e no Linux nativo x86-64:

- sessões autoritativas servidor/cliente em loopback a 60 Hz, admissão de dois
  clientes, snapshots e predição/reconciliação observável;
- movimento limitado, contato de cápsula, BVH de triângulos e consultas
  espaciais de projéteis;
- combate determinístico com um caminho integrado de jogador/inimigo, seleção
  limitada por pellet e snapshots autoritativos de encounter com até 32 estados
  de inimigos e o impacto confirmado mais recente chegando ao HUD/áudio;
- arena criada com 78 vértices e 26 triângulos, inclinação caminhável, degraus e
  salas empilhadas, replicada com limites explícitos do broad-phase;
- câmera, staging limitado do mundo e HUD semântico de combate com painéis de
  vida/munição, glifo de conexão, carga ativa/reserva do encounter, mira
  responsiva ao foco, marcadores de acerto/eliminação, alertas laterais de dano,
  estado por formas de inventário/equipamento/skill/loot, sinais estruturais de
  ameaça de elite/chefe e um rail de criador fonte→validação→publicação; o
  SDL_GPU envia a cena fixa de 486 vértices de arena/porta/HUD (372 do HUD) sem
  crescer buffers por frame;
- progressão cooperativa de chave, porta 3D, segredo e saída, replay de comandos
  e saves versionados do nível;
- saves, replays, inventário, equipamento, skills e efeitos de status;
- fluxo autoritativo G3 de eliminação→drop gerado→coleta/equipamento→mudança
  de atributo/skill→recompensa de chefe, schemas por destinatário para
  inventário/equipamento/progressão e loot no mundo, além de save/reload
  atômico das rolagens e reivindicações de recompensa;
- manifestos públicos limitados de extensões, dependências, capacidades e
  contribuições determinísticas de conteúdo, mais regras seladas orientadas por
  dados para combate, comportamento, loot, progressão e moeda de elites/chefes;
- um caminho G4 transacional que vincula checksums de pacote, extensão,
  implementação/versão de hook confiável, definição de inimigo e produtos
  alinhados numa identidade de compatibilidade de 13 palavras; edições
  obsoletas preservam a geração ativa, enquanto um runtime vinculado à geração
  executa o hook compilado de recompensa de elite após uma eliminação
  confirmada e aplica seu comando limitado de moeda exatamente uma vez;
- hooks confiáveis assinam eventos tipados de início de sessão, conexão de
  jogador, derrota de inimigo, coleta de loot e publicação do editor; somente
  pares registrados de implementação/versão estática executam sob limites de
  fase e saída;
- o cooker de arquivos admite um subconjunto limitado de GLB indexado, `.ds3`
  do Dust3D com seu GLB texturizado exportado, `.ase`/`.aseprite` RGBA de 32
  bits, modelos e chunks de cena `.vox`, e brushes convexos de `.map` no estilo
  Quake em grade inteira; ele emite geometria/colisão canônicas, atlas
  PNG/metadados e checksums prontos para pacote;
- arquivos `.kpkg` validam cabeçalhos, caminhos lógicos, intervalos/hashes de
  chunks e payloads dos registros antes de uma geração externa substituir a
  ativa; reloads inválidos mantêm ativos o pacote e os registros anteriores;
- a tela Creator expõe edição limitada de mundo/entidade/arma/loot, inspeção de
  colisão e IA, play-in-editor e undo/redo verificados por revisão. A publicação
  troca atomicamente os produtos de geometria/colisão/navegação/render;
- o reload nativo em etapas mantém a cena ativa intacta enquanto monta a
  candidata, aguarda a conclusão síncrona da fence de upload antes de reutilizar
  o buffer GPU persistente e ativa no limite de frame; referências da geração
  no Kof controlam a aposentadoria;
- uma oferta de compatibilidade de 18 palavras e uma resposta de 7 palavras
  transportam a identidade exata de conteúdo de 13 palavras antes de snapshots
  ou comandos de gameplay. Divergências e frames corrompidos falham de forma
  segura com resposta diagnóstica;
- um adaptador pequeno SDL3/SDL_GPU; regressões de transporte com três processos
  na JVM e no nativo levam a arena completa de 26 triângulos, comandos
  unificados com checksum para movimento/disparo/interação/ciclo de vida,
  baselines por destinatário de gameplay, autoridade G3 do jogador e loot no
  mundo, feedback multiplayer ordenado e estado autoritativo limitado do
  encounter;
- um shell persistente e redimensionável em 1280×720, com menus pixel old
  school, mouse/teclado, opções transacionais de vídeo/áudio/texto e lobby
  simples de host/join/leave marcado por SipHash;
- papéis contínuos de inimigos hitscan/projétil/shotgun, predição de movimento
  no cliente com replay de inputs ainda não confirmados, recuperação de
  reconexão segura por geração, colisão/geometria visual 3D completa das portas
  e recuperação de lacunas/duplicatas em lotes de feedback;
- atenuação por distância e pan estéreo relativos ao listener calculados no
  Kof, com PCM sem alocação em buses separados de efeitos e música no
  SDL_mixer.
- um runner `kookie-server` sem gráficos no pacote Linux pré-aloca 64 inimigos,
  256 projéteis móveis e 512 itens coletáveis, aplica orçamentos por tick de
  16/64/128 para IA/projéteis/itens e informa percentis nativos de tempo por
  tick e amostras de RSS;
- um gate autenticado de escala na mesma máquina executa a carga exata com um
  host, dois processos clientes, admissão de conteúdo, checkpoints limitados,
  desconexão e reconexão segura por geração.

As lacunas importantes continuam reais:

- a qualificação G3 entre processos continua na mesma máquina. O handshake G4
  passou com host e dois clientes em três namespaces de rede Linux isolados,
  com pilhas IPv4 distintas; não há um bundle G4 recente retido em três
  máquinas físicas;
- o suporte de autoria é intencionalmente limitado, não compatibilidade geral
  com os formatos: uma primitiva GLB indexada e produtos canônicos têm no máximo
  256 vértices/triângulos, a entrada VOX aceita 20 voxels, e os subconjuntos
  documentados de Aseprite, Dust3D e brushes rejeitam construções incompatíveis;
- reload ao vivo cobre produtos validados de cena/render, não código Kof,
  shaders, plugins de editor ou streaming ilimitado de recursos;
- a FFI de buffers do Kof está bloqueada por `FFI001`, então o kernel SIMD
  nativo ainda não está ligado aos hot loops pertencentes ao Kof;
- a carga headless sem colisão atingiu p95 nativo de simulação de
  1,245 ms/tick em 512 ticks medidos e depois passou um soak em tempo real de
  30 minutos com p95 de 1,891 ms/tick e 128 KiB de crescimento/faixa de RSS
  após aquecimento na estação Linux registrada; a cena média com colisão criada
  manualmente, as luzes/efeitos dinâmicos e a meta de frame em 1080p continuam
  sem qualificação;
- a prova de transporte de escala usa loopback na mesma máquina com replicação
  por checkpoint, não gameplay remoto completo por tick nem evidência recente
  em várias máquinas;
- saves duráveis contra crash, física completa, áudio comprimido/em streaming
  e HRTF/EFX, autoria G6 mais rica e extensões de runtime em sandbox continuam
  incompletos.
- o shell Windows nativo é interativo e persistente, mas o Kof ainda não gera
  gameplay PE para Windows; a tela Play não comprova execução autoritativa Kof
  nesse sistema.

Se uma afirmação não tem um teste ou uma sonda focada por trás, ela não é
apresentada como concluída.

## Como executar

Instale `kof` e Python 3. Execute o cenário G1 de ponta a ponta:

```bash
kof run src/main.kf --target native
```

Execute a sonda focada de gameplay/replay:

```bash
bash scripts/verify_interactions.sh
```

Gere o pacote de apresentação SDL_GPU persistente para Linux:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.presentation.1 \
scripts/package_kookie.sh
```

Ele contém o aplicativo Kof com menus/gameplay, adaptador SDL, shaders SPIR-V,
SDL3 e SDL_mixer. O launcher usa o runtime do sistema, sem empacotar o loader
dinâmico ou libc. Pacotes JVM distribuíveis são rejeitados; JVM fica restrita
à qualificação diferencial local.

Todo arquivo Linux também contém `kookie-server` e seu adaptador nativo de
tempo/RSS independente de gráficos. Sua execução roda uma carga headless
limitada configurável em runtime e informa contagens, orçamentos, tempos
p50/p95/p99/máximo por tick, faixa/crescimento de RSS, checksum e estabilidade
lógica de recursos. A qualificação autenticada focada com host mais dois
clientes continua sendo uma sonda, não um serviço de servidor dedicado de
produção empacotado.

Cozinhe arquivos de autoria e monte ou inspecione pacotes externos de um chunk
com a CLI de desenvolvimento exclusiva da JVM:

```bash
scripts/kookie_cooker.sh cook map level.map level.kmesh
scripts/kookie_cooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kookie_cooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kookie_cooker.sh inspect-package level.kpkg
scripts/kookie_cooker.sh validate-package creator.kpkg
```

O cooker rejeita entradas grandes demais, malformadas ou incompatíveis sem
gravar um resultado bem-sucedido. Formatos-fonte não são formatos de pacote de
runtime.

Gere o shell Windows x86-64 nativo com os pacotes de desenvolvimento MinGW
oficiais de SDL 3.4.16 e SDL_mixer 3.2.4:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/caminho/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/caminho/SDL3_mixer/x86_64-w64-mingw32 \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

O `.zip` contém `kookie.exe`, as duas DLLs, licenças e procedência, sem JDK ou
teste de matriz de cores que fecha sozinho. A janela permanece aberta até o
usuário sair. Use setas ou WASD, Enter/Espaço, Esc e clique. As opções cobrem
resolução, modo janela/borderless/fullscreen, volumes separados e tamanho de
texto. O lobby oferece Host, Join, Leave, IPv4/porta editáveis e estado da
conexão. Pacotes têm tags SipHash e sequências contra replay. Uma chave secreta
compartilhada de 128 bits autentica os peers; o fallback local público apenas
detecta corrupção acidental. Não há criptografia nem identidade pública.

O gate completo fica para a verificação final pré-commit (no Pi, após `/precommit-matrix`):

```bash
bash scripts/verify.sh
```

Para uma regressão local do transporte JVM em múltiplos processos, execute:

```bash
KOOKIE_EXTERNAL_LAN_TARGET=jvm \
KOOKIE_EXTERNAL_LAN_MODE=processes \
bash scripts/verify_external_lan.sh
```

Use `KOOKIE_EXTERNAL_LAN_TARGET=native` (o padrão) para o caminho nativo.
Ambos produzem o mesmo contrato de evidência; a evidência local na mesma
máquina continua com `externalHostExecution=unproven`.

Testes gráficos devem usar um wrapper de display isolado revisado, definido em
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`. Os testes SDL offscreen cobrem ciclo de
vida e recursos GPU; eles não provam que uma janela real consegue apresentar.
Use `KOOKIE_SDL_VIDEO_DRIVER=x11` somente em um host capaz de fornecer
apresentação isolada. Defina `KOOKIE_SCREENSHOT_PATH=/caminho/absoluto.ppm` para
guardar um frame capturado.

## O que estamos construindo

O comportamento autoritativo de CPU da engine e do jogo permanece em `.kf`.
Código nativo fica limitado a adaptadores, fronteiras ABI, shaders e bootstrap
de plataforma. Enquanto o Kof não possui alvo PE, o shell Windows nativo cuida
somente de menu, opções, lobby e apresentação; ele não substitui a engine.

O primeiro alvo de gameplay nativo autoritativo é Linux x86-64. JVM é um alvo
local de comparação, não um fallback distribuível. SDL3 + SDL_GPU forma a
fronteira gráfica e SDL_mixer mantém buses de efeitos e música.

## Roadmap

G3 está fechado no gate de aceitação atual: o caminho multiplayer autoritativo
de eliminação→drop gerado→coleta/equipamento→mudança de atributo/skill→
recompensa de chefe→salvar/recarregar executa na JVM e no nativo; os tipos de
estado `7`/`8` atravessam processos autenticados na mesma máquina com host mais
dois clientes; e registros limitados de manifesto/capacidade/contribuição
instanciam definições completas e seladas de elites/chefes. O gate G4 limitado
agora inclui eventos tipados de hooks, os subconjuntos documentados de fontes e
a CLI de arquivos, carga segura de pacotes externos, ferramentas transacionais
do Creator, reload no limite de frame protegido por fence e transporte de
oferta/resposta de compatibilidade. O handshake passou em três namespaces de
rede Linux isolados, com pilhas IPv4 distintas. Isso não afirma compatibilidade
geral de formatos, reload arbitrário de código, editor de produção ou
qualificação recente em três máquinas físicas. G2 continua coberto pela suíte
de código-fonte, sonda focada de interação, qualificação por processos e sonda
SDL_GPU/áudio isolada.
O trabalho G5 limitado agora inclui o runner sem gráficos no pacote, trabalho
espacial móvel, telemetria nativa de tempo/RSS e um protocolo autenticado de
checkpoint/reconexão com host mais dois clientes na carga declarada de
64 inimigos/256 projéteis/512 itens e tetos de 16/64/128 unidades de trabalho.
JVM e nativo produzem checksum `797255` e assinatura de recursos `675172` após
256 ticks. Uma amostra nativa de 512 ticks atingiu p95 de simulação de
1,245 ms/tick e crescimento/faixa de RSS de 64 KiB. Uma execução separada em
tempo real por 30 minutos mediu 108.000 ticks após 600 de aquecimento com
p50/p95/p99/máximo de 1,216/1,891/2,182/4,110 ms e 128 KiB de
crescimento/faixa de RSS em 181 amostras. Isso qualifica apenas o subconjunto
headless sem colisão. G5 continua aberto para a cena média criada manualmente,
gameplay remoto completo, tempo/batching/instancing de render em 1080p e o
reforço restante de persistência/recuperação.


Adiado até os gates centrais estarem mais fortes:

- física completa e perfis mais amplos de formatos/cooker;
- schema de save de produção e reforço de transporte dedicado/WAN;
- serviços de áudio em streaming/HRTF, imagem e texto;
- compressão de pacotes, autoria mais rica e bibliotecas estrangeiras de física/UI.

## Documentação

- [Memória do projeto](MEMORY.md): decisões, ressalvas e próxima ação.
- [Backlog G0](docs/G0_BACKLOG.md): trabalho concluído, trabalho ativo e
  escopo adiado.
- [Plano da engine](docs/ENGINE_PLAN.md): arquitetura e gates de milestone.
- [Notas da linguagem Kof](docs/KOF_LANGUAGE.md): sintaxe, alvos, FFI e
  fronteiras do runtime.
- [Sondas executadas](docs/RESEARCH_PROBES.md): comandos, resultados e limites
  das provas.
- [Changelog](CHANGELOG.md): histórico recente do projeto.

A [documentação em inglês](../docs/) espelha a documentação em português.

## Regras de trabalho

Prefira um contrato executável pequeno a um scaffold grande e não testado.
Mantenha as mudanças limitadas, determinísticas e reversíveis. Não esconda um
bloqueador nativo atrás de um fallback JVM nem declare uma capacidade gráfica
que não foi exercitada em um host compatível.

## Licença e procedência

O código e os programas gerados do KOOKIE usam a
[Licença MIT](../LICENSE). Os componentes distribuídos de fonte/runtime são
permissivos: SDL 3.4.16 e SDL_mixer 3.2.4 usam zlib. Versões, fontes e avisos
completos estão em
[THIRD_PARTY_NOTICES.txt](../THIRD_PARTY_NOTICES.txt).

O compilador Kof é uma ferramenta externa de build, não é distribuído e
permite licença própria aos programas gerados. Java fica restrito à
qualificação local. Consulte [CONTRIBUTING.md](CONTRIBUTING.md) antes de
adicionar dependências ou mudar a fronteira de verificação.