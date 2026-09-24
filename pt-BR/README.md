# KOOKIE
[English](../README.md)

KOOKIE é uma engine experimental de tiro 3D construída em torno de Kof. O
projeto serve para experimentar boomer shooters, looter shooters e ARPG FPS;
não é um jogo pronto.

## Estado honesto

A fundação útil está executando e sendo testada na JVM e no Linux nativo
x86-64:

- sessões autoritativas fixed-step e snapshots;
- movimento limitado, colisão, BVH e consultas de projéteis espaciais;
- combate determinístico, incluindo seleção de pellets de shotgun;
- saves, replays, inventário, equipamento, skills e efeitos de status;
- um adaptador pequeno SDL3/SDL_GPU e sondas de transporte localhost
  autenticado.

As lacunas importantes continuam reais:

- apresentação em janela exige um host isolado com suporte DRI3;
- a FFI de buffers do Kof está bloqueada por `FFI001`, então o kernel SIMD
  nativo ainda não está ligado aos hot loops pertencentes ao Kof;
- saves duráveis contra crash, multiplayer de produção, content cooker, física
  completa, áudio de produção e um pipeline completo de criação ainda não estão
  prontos.

Se uma afirmação não tem um teste ou uma sonda focada por trás, ela não é
apresentada como concluída.

## Como executar

Instale `kof` e Python 3. Depois execute o gate focado:

```bash
python3 scripts/lint_kf.py src probes
python3 scripts/lsp_verify.py src
kof test src --target jvm
kof test src --target native
```

O gate local completo é:

```bash
bash scripts/verify.sh
```

Testes gráficos devem usar o wrapper de display isolado do repositório. Os
testes SDL offscreen cobrem ciclo de vida e recursos GPU; eles não provam que
uma janela real consegue apresentar. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` somente
em um host capaz de fornecer apresentação isolada. Defina
`KOOKIE_SCREENSHOT_PATH=/caminho/absoluto.ppm` para guardar um frame capturado.

## O que estamos construindo

O comportamento de CPU da engine, do jogo e das ferramentas permanece em
`.kf`. O código nativo fica limitado a adaptadores pequenos, fronteiras de ABI,
shaders e glue de bootstrap. Não há uma engine substituta escondida em C,
Java, Rust ou Zig.

O primeiro alvo nativo suportado é Linux x86-64. A JVM é um alvo de comparação,
não um substituto do comportamento nativo. A fronteira gráfica é SDL3 +
SDL_GPU, inicialmente com Vulkan/SPIR-V.

## Roadmap

A próxima tarefa concreta é executar o caminho de screenshot DRI3 em um host
isolado capaz de apresentação. O trabalho de gameplay e combate limitado está
à frente do conteúdo de produção, networking e ferramentas.

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