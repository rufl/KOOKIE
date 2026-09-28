# KOOKIE
[English](../README.md)

KOOKIE é uma engine experimental de tiro 3D construída em torno de Kof. O
projeto serve para experimentar boomer shooters, looter shooters e ARPG FPS;
não é um jogo pronto.
As portas têm pré-requisitos. Chamar isto de pronto também.

## Estado honesto

G0 e G1 executam na JVM e no Linux nativo x86-64:

- sessões autoritativas servidor/cliente em loopback a 60 Hz, admissão de dois
  clientes, snapshots e predição/reconciliação observável;
- movimento limitado, contato de cápsula, BVH de triângulos e consultas
  espaciais de projéteis;
- combate determinístico com um caminho integrado de arma/inimigo e seleção de
  pellets de shotgun;
- arena criada com 78 vértices e 26 triângulos, inclinação caminhável, degraus e
  salas empilhadas, replicada com limites explícitos do broad-phase;
- câmera, staging limitado do mundo/HUD e upload de cena SDL_GPU por buffers
  fixos; a perda de foco limpa movimento e disparo enfileirados;
- progressão cooperativa de chave, porta, segredo e saída, replay de comandos e
  saves versionados do nível;
- saves, replays, inventário, equipamento, skills e efeitos de status;
- um adaptador pequeno SDL3/SDL_GPU; regressões de transporte com três processos
  na JVM e no nativo levam a arena completa de 26 triângulos e comandos
  unificados com checksum para movimento, disparo, interação, desconexão e
  reconexão. Os clientes aplicam posições autoritativas, vida de combate, uma
  recompensa terminal em moeda, progressão até a revisão 4 e diagnósticos
  explícitos de ciclo de vida/input obsoleto.

As lacunas importantes continuam reais:

- G2 ainda precisa de simulação/encounters replicados de inimigos,
  predição/reconciliação completa dos jogadores e recuperação de
  entrada/admissão em produção, geometria/colisão 3D completa das portas e
  feedback/áudio integrado;
- a FFI de buffers do Kof está bloqueada por `FFI001`, então o kernel SIMD
  nativo ainda não está ligado aos hot loops pertencentes ao Kof;
- saves duráveis contra crash, content cooker, física completa, áudio de
  produção, soak/desempenho sustentado de G5 e o pipeline de criação continuam
  incompletos.

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

O próximo passo é concluir G2: ampliar o slice qualificado de arena, morte em
combate e chave/porta/segredo/saída com host mais dois clientes para simulação
replicada de jogadores/inimigos, recompensas, diagnósticos limitados de
reconexão, portas 3D completas e feedback/áudio integrado.

Adiado até os gates centrais estarem mais fortes:

- física completa e content cooker;
- schema de save de produção e transporte multiplayer;
- serviços de áudio/imagem/texto de produção;
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