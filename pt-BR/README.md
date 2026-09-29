# KOOKIE
[English](../README.md)

KOOKIE é uma engine experimental de tiro 3D construída em torno de Kof. O
projeto serve para experimentar boomer shooters, looter shooters e ARPG FPS;
não é um jogo pronto.
As portas têm pré-requisitos. Chamar isto de pronto também.

## Estado honesto

G0, G1, G2, G3 e o primeiro slice vertical limitado de G4 executam na JVM e no Linux nativo x86-64:

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
- um primeiro caminho G4 transacional que vincula checksums de pacote, extensão,
  hook confiável, definição de inimigo e geometria/colisão/navegação/replicação
  numa identidade de compatibilidade de 13 palavras; edições obsoletas ou
  inválidas preservam a geração ativa, e um segundo exemplo com dois jogadores
  usa somente APIs públicas de definições, extensões e sessão;
- um adaptador pequeno SDL3/SDL_GPU; regressões de transporte com três processos
  na JVM e no nativo levam a arena completa de 26 triângulos, comandos
  unificados com checksum para movimento/disparo/interação/ciclo de vida,
  baselines por destinatário de gameplay, autoridade G3 do jogador e loot no
  mundo, feedback multiplayer ordenado e estado autoritativo limitado do
  encounter;
- papéis contínuos de inimigos hitscan/projétil/shotgun, predição de movimento
  no cliente com replay de inputs ainda não confirmados, recuperação de
  reconexão segura por geração, colisão/geometria visual 3D completa das portas
  e recuperação de lacunas/duplicatas em lotes de feedback;
- atenuação por distância e pan estéreo relativos ao listener calculados no
  Kof, com envio PCM esquerdo/direito sem alocação pelo adaptador de áudio SDL
  nativo.

As lacunas importantes continuam reais:

- a qualificação G3 entre processos continua na mesma máquina, a admissão da
  identidade de conteúdo G4 ainda ocorre no mesmo processo, e execução entre
  máquinas continua não comprovada;
- G4 continua aberto para execução de hooks confiáveis, toda a entrada
  suportada de cooker para malhas/brushes/fontes, carregamento externo de
  pacotes, inspector/editores e recarregamento em etapas seguro para a GPU;
- a FFI de buffers do Kof está bloqueada por `FFI001`, então o kernel SIMD
  nativo ainda não está ligado aos hot loops pertencentes ao Kof;
- saves duráveis contra crash, física completa, áudio comprimido/em streaming
  e HRTF/EFX, soak/desempenho sustentado de G5 e o pipeline completo de criação
  continuam incompletos.

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

Gere o pacote nativo Linux de apresentação SDL_GPU usado para qualificação
visual isolada e deployment dogfood via ztash:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.presentation.1 \
scripts/package_kookie.sh
```

Ele contém o executável Kof de arena/HUD de combate, adaptador SDL, shaders
SPIR-V e bibliotecas Linux resolvidas. Impactos autoritativos confirmados
acionam o mesmo marcador limitado do HUD e clip SDL sintetizado exercitado pela
sonda. É uma superfície de qualificação, não um jogo interativo completo.

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

O comportamento de CPU da engine, do jogo e das ferramentas permanece em
`.kf`. O código nativo fica limitado a adaptadores pequenos, fronteiras de ABI,
shaders e glue de bootstrap. Não há uma engine substituta escondida em C,
Java, Rust ou Zig.

O primeiro alvo nativo suportado é Linux x86-64. A JVM é um alvo de comparação,
não um substituto do comportamento nativo. A fronteira gráfica é SDL3 +
SDL_GPU, inicialmente com Vulkan/SPIR-V.

## Roadmap

G3 está fechado no gate de aceitação atual: o caminho multiplayer autoritativo
de eliminação→drop gerado→coleta/equipamento→mudança de atributo/skill→
recompensa de chefe→salvar/recarregar executa na JVM e no nativo; os tipos de
estado `7`/`8` atravessam processos autenticados na mesma máquina com host mais
dois clientes; e registros limitados de manifesto/capacidade/contribuição
instanciam definições completas e seladas de elites/chefes. Isso não comprova
execução entre máquinas nem o cooker, hooks de módulos confiáveis, transações
do editor e publicação em etapas do G4. G2 continua coberto pela suíte de
código-fonte, sonda focada de interação, qualificação por processos e sonda
SDL_GPU/áudio isolada.

Adiado até os gates centrais estarem mais fortes:

- física completa e content cooker;
- schema de save de produção e reforço de transporte dedicado/WAN;
- serviços de áudio em streaming/HRTF, imagem e texto;
- compressão de pacotes e bibliotecas estrangeiras de física/UI.

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

As notas de pesquisa registram versões do compilador, links upstream, SHAs
fixados e limites das provas. Repositórios irmãos foram inspecionados somente
para leitura; nenhuma licença de origem ou asset foi alterada aqui. Consulte
[CONTRIBUTING.md](CONTRIBUTING.md) antes de adicionar dependências ou mudar a
fronteira de verificação.