# Plano do engine KOOKIE

Status: **arquitetura proposta e gates de aceitação; nenhuma implementação do engine ainda**.

Baseline de pesquisa: 2026-09-22, Kof 0.4.9-beta. A arquitetura do projeto está em
[ARCHITECTURE.md](ARCHITECTURE.md). Consulte [evidências de linguagem/runtime](KOF_LANGUAGE.md),
[sondagens iniciais](RESEARCH_PROBES.md), [análise aprofundada do curso](KOF_COURSE.md),
[sondagens orientadas pelo curso](COURSE_PROBES.md), [precedentes de jogos](GAME_ECOSYSTEM.md),
[descobertas sobre o editor](KOF_EDITOR.md) e [mapa de portabilidade do monorepo](MONOREPO_REUSE.md).

## 1. Produto e responsabilidade não negociável

Construir um **engine de primeira pessoa 3D verdadeiro, orientado a conteúdo** que ofereça suporte a três perfis de jogo sobre a mesma base de simulação/renderização/conteúdo:

| Perfil | Pontos fortes necessários |
|---|---|
| Boomer shooter | Mira responsiva com o mouse, aceleração/controle aéreo, padrões de projéteis legíveis, chaves/portas/segredos, espaços de combate interconectados criados por autoria, troca rápida de armas |
| Looter shooter | Instâncias de itens geradas aleatoriamente, arquétipos e afixos de armas de fogo, equipamento/inventário, modificadores de elite, ciclos repetíveis de encontro/recompensa, integridade dos salvamentos |
| ARPG FPS | Habilidades ativas, custos de recarga/recurso, árvores de progressão, tipos de dano/resistências, efeitos temporizados/acumuláveis, sinergias de builds, chefes e builds orientadas por equipamentos |

Esses são conjuntos de regras configuráveis, não três forks. Um perfil boomer pode desabilitar saque/progressão sem manter uma segunda implementação de movimento, colisão ou renderizador.

### Regra de responsabilidade das fontes

Todo comportamento de CPU pertencente ao engine está em `.kf`: loop, armazenamento de entidades, matemática, movimento, colisão, IA, combate, saque, decisões de animação, extração/ocultação/ordenação de renderização/política de passes, política de áudio, salvamentos, preparação de conteúdo, IU de runtime, lógica de autoria e código do jogo.

Fronteira não-Kof permitida, mantida pequena e passível de revisão:

1. Bibliotecas externas de plataforma/GPU/áudio/codec não modificadas, inicialmente SDL3.
2. Marshalling da ABI C que Kof atualmente não consegue expressar: handles nativos, uniões de structs/eventos, ponteiros, transferência de buffers e configuração/desmontagem de bibliotecas. Nenhum algoritmo de gameplay ou de cena.
3. Código-fonte/binários de shaders de GPU: Kof atualmente não fornece um destino geral de shaders gráficos com suporte. HLSL/SPIR-V e variantes de backend geradas são uma exceção gráfica explícita, não código de engine de CPU oculto em outro lugar.
4. Ferramentas externas de compilação/linkedição/shaders e glue declarativo mínimo de build/bootstrap. O comportamento do cooker/editor pertencente ao KOOKIE continua sendo Kof, não aplicações em Python/JS/Zig/Rust.

O compilador/runtime existente do Kof é uma dependência de ferramenta upstream escrita parcialmente em Java/assembly. Corrigir um defeito do compilador upstream é diferente de mover o gameplay do KOOKIE para Java. Qualquer alteração mantida no compilador deve ser fixada, documentada e enviada ao upstream quando for prático.

**Atalhos proibidos:** um engine Java/Bevy/Zig controlado por scripts `.kf`; lógica de jogo JS escrita manualmente e armazenada em strings Kof; uma implementação C de `engine_tick`/`render_world`; converter inteiros em ponteiros nativos arbitrários; duplicar o gameplay em uma segunda linguagem para fazer a demo funcionar.

Este plano não escolhe uma licença pública nem autoriza a redistribuição de assets de projetos irmãos. Resolva a titularidade/notificações antes de publicar ports.

## 2. Decisão de plataforma e gráficos

### Baseline proposto: SDL3 + SDL_GPU

- Primeiro runtime: **Kof nativo Linux x86-64 ELF**.
- Oráculo de desenvolvimento: JVM para pequenas sondagens diferenciais em Kof puro, não um fallback silencioso de produção.
- Backend gráfico inicial: SDL_GPU Vulkan com shaders SPIR-V offline.
- SDL gerencia janela/eventos/mouse relativo/gamepads/temporização/acesso ao dispositivo de áudio. Kof é responsável pelo loop principal e pelo estado do jogo.
- SDL_GPU gerencia recursos do dispositivo, command buffers, sincronização de uploads, pipelines, submissão de draw/compute e apresentação. Kof decide o que submeter e em que ordem.
- Use uma única implementação de renderizador inicialmente. Não construa backends SDL, Sokol, raylib, OpenGL e Vulkan simultaneamente.

**Por quê:** capacidade para 3D completo/instancing/compute para multidões de projéteis e efeitos de ARPG, modelo moderno de backend para desktop, superfície robusta de entrada para shooters, uma dependência de plataforma e experiência existente com SDL_GPU no ZYLVE. Este é um julgamento de design, **não uma evidência medida de que SDL_GPU seja mais rápido para Kof**.

### Alternativas consideradas

| Candidato | Adequação | Decisão |
|---|---|---|
| SDL3 + SDL_GPU | Abstração de Vulkan/D3D12/Metal; entrada por polling/loop principal; recursos de GPU/compute; precedente do ZYLVE | Spike nativo preferido |
| SDL3 + `sokol_gfx` | API de GPU compacta; reutilização dos conceitos de batching do DINX; pode manter o loop de plataforma SDL | Alternativa viável se as restrições de hardware/shaders do SDL_GPU falharem; adiciona integração entre duas bibliotecas |
| `sokol_app` + `sokol_gfx` | Baixa sobrecarga, gráficos portáveis, familiaridade com o DINX | O Kof nativo atualmente não consegue fornecer callbacks persistentes; o ciclo de vida do app exigiria responsabilidade adicional da ponte. Não é o primeiro caminho |
| raylib / Jaylib | Rota mais curta para exemplos; precedente real do DoomKof; matemática/modelos/áudio incluídos | Boa opção de comparação/prototipagem, mas Jaylib significa JVM e muitas structs do raylib ainda exigem trabalho de ABI nativa. Não substitui o plano de renderizador pertencente ao engine |
| Vulkan direto | Controle máximo | Trabalho excessivo de driver/sincronização/shaders antes do comportamento do shooter; nenhuma necessidade demonstrada |
| LWJGL | Bindings maduros para JVM | Alternativa específica do destino, não evidência de interoperabilidade com Kof nativo |
| Kof Canvas / WebKitGTK | Ecossistema 2D/navegador existente | Fronteira inicial de runtime/3D em tempo real incorreta; o navegador não é o destino nativo |
| Bevy/wgpu por meio de shim Rust | Stack CUBSHIP existente | Viola a responsabilidade do engine se a arquitetura de simulação/renderização permanecer em Rust |

Sokol continua sendo uma opção plausível; não foi rejeitado como incapaz de lidar com shooters. Sua lista de backends evolui, portanto fixe os headers/ferramentas de shaders se for selecionado, em vez de depender de tabelas de capacidades desatualizadas.

SDL_GPU também tem limitações: piso de recursos de GPU moderno, layouts rigorosos de recursos de shaders, nenhum backend geral para navegador na rota proposta, nenhuma promessa de ray tracing/mesh shaders de ponta. A portabilidade do SDL não implica saída PE/Mach-O nativa do Kof. O suporte a Windows/macOS/ARM/navegador continua sendo uma expansão com gates separados, não uma alegação de entrega inicial.Fontes: [contrato de GPU do SDL](https://wiki.libsdl.org/SDL3/CategoryGPU), [modo de mouse relativo](https://wiki.libsdl.org/SDL3/SDL_SetWindowRelativeMouseMode), [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross), [Sokol](https://github.com/floooh/sokol), [raylib](https://github.com/raysan5/raylib), [licença do SDL](https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt).

### Avaliação do reaproveitamento do Minecraft moderno

[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md) registra a stack atual do Java26.3 e os candidatos. Sua migração para SDL3 apoia nossa escolha de plataforma, **não** é uma alegação de que o Minecraft usa SDL_GPU. A separação da API Renderpearl não estabelece uma concessão de reutilização de código aberto. As lições atuais de renderização são estado de frame extraído, anexos de passe explícitos, gerações de recursos, visibilidade/agrupamento e tempos de vida persistentes de instâncias.

Priorize ports de matemática/comandos `.kf` limitados de JOML/Brigadier, armazenamento tipado inspirado em Artemis/Ashley, contratos de definição/patch de item/codec no estilo Minecraft, layout inspirado em owo e ciclos de vida de instâncias inspirados em Flywheel. JOML1.10.9 foi medido na JVM Kof; o nativo rejeitou suas importações Java. Não importe JARs nem runtimes completos de mods como bibliotecas do motor nativo.

Mantenha o áudio SDL enfileirado para G0. Para a stack de FPS de produção, **recomende OpenAL Soft** para som posicional, HRTF e EFX; SDL3_mixer é a alternativa mais simples/básica para espacialização, não um segundo backend obrigatório. Esta é uma recomendação de seleção de biblioteca, não um backend de áudio implementado nem uma licença de redistribuição adotada. A física Jolt e as UIs RmlUi/ImGui ainda exigem aprovação explícita da propriedade dos subsistemas estrangeiros.

### Conjunto de bibliotecas recomendado (2026-09-22)

Critério de seleção: adequação a um shooter nativo no Linux, APIs estreitas
mantidas, clareza da licença e compatibilidade com a propriedade de `.kf` —
não uma alegação não medida de desempenho máximo. Adote em etapas; não vincule
todos os candidatos ao G0.

| Área | Escolha recomendada | Limite / motivo |
|---|---|---|
| Plataforma e gráficos | **SDL3 + SDL_GPU** | Uma única stack de janela/entrada/gamepad/GPU; 3D e compute. Kof possui a extração, o culling, o agrupamento e os passes. Licença zlib. Mantenha Sokol como alternativa somente se o spike de GPU/ABI falhar |
| Compilação de shaders | **SDL_shadercross + DXC**, SPIRV-Cross e SPIRV-Tools conforme exigido pelo build | HLSL → SPIR-V offline para Linux; refletir layouts de recursos. Ferramentas de build, não compiladores de shaders obrigatórios no runtime distribuído. O ShaderC instalado sozinho não é o pipeline HLSL selecionado |
| Áudio de produção | **OpenAL Soft** | Fontes/listener 3D, atenuação/Doppler, HRTF e EFX. Kof mantém cues, admissão/prioridade de vozes, consultas de oclusão do mundo e política de efeitos configurada. A biblioteca realiza a mixagem/DSP espacial; esta é uma delegação explícita do mecanismo de áudio |
| Decodificação de imagens | **SDL3_image** | Decodificar inicialmente PNGs produzidos em buffers de pixels limitados. Mantenha a admissão de formatos, decisões de espaço de cor/material, o cooking e os uploads para a GPU sob a política do Kof. Biblioteca zlib; dependências opcionais de codecs têm seus próprios avisos |
| Renderização de texto | **FreeType**, depois **HarfBuzz** ao implementar texto com shaping | Apenas serviços de rasterização e shaping. Kof possui os widgets, o layout, o foco e a política de cache de glifos. Fallback de fontes, bidi/quebra de linhas, IME e acessibilidade não são resolvidos simplesmente vinculando essas bibliotecas |
| Compressão de pacotes | **Zstandard (`libzstd`)** | Adicionar no estágio de pacote cozido, não por frame. Use blocos limitados e endereçáveis independentemente, comprimentos decodificados declarados e limites do decodificador; compressão não é integridade/autenticação. Opção de licença BSD |

**Detalhes da escolha de áudio.** OpenAL não é um decodificador de arquivos de
áudio. Comece com uma política restrita de entrada PCM WAV usando o
`SDL_LoadWAV` existente; adicione um único decodificador de áudio comprimido
somente quando os requisitos de música em streaming justificarem isso. Não
execute SDL_mixer e OpenAL como autoridades concorrentes de dispositivo/mixer.
OpenAL Soft é LGPL-2.0-or-later, com dados HRTF separados sob Apache-2.0 no
código-fonte inspecionado: revise os avisos, a fonte correspondente e as
obrigações de relinking para a distribuição real. Se essa troca não for
desejada e áudio espacial básico for suficiente, escolha SDL3_mixer em vez
disso (zlib, SDL >= 3.4.0). Seu licenciamento mais simples não licencia
automaticamente todos os decodificadores opcionais.

**Mantenha estas bibliotecas do motor no Kof:** armazenamento tipado de
entidades/componentes; uma pequena biblioteca de matemática usando ports MIT
seletivos de JOML; movimentação/colisão de shooter; IA/navegação sob a regra
atual; combate/saques/estados; esquemas de conteúdo e admissão de fontes para
glTF/mapas de brush, Dust3D, LibreSprite e MagicaVoxel; UI do jogador e lógica
de autoria. Não adicione um ECS estrangeiro nem chame uma biblioteca C de
matemática uma vez por operação vetorial. GLB é o resultado canônico de
intercâmbio 3D, enquanto a entrada de formatos-fonte continua sendo uma
preocupação do cooker validado; o gate nativo de JSON permanece.

**Alternativas de alto valor que exigem uma decisão de propriedade:**

| Biblioteca | Por que é atraente | Por que não é adotada silenciosamente |
|---|---|---|
| **Jolt Physics** (MIT) | Melhor atalho geral de física avaliado: shape casts, colisão, corpos rígidos e personagens virtuais | Transfere o comportamento de colisão/solver/controlador para fora do Kof. Se aprovada, nomeie as partes delegadas e mantenha a intenção de movimento, as armas/danos e a autoridade do tick fixo no Kof |
| **Recast + Detour** (zlib) | Geração de navmesh mais pathfinding/consultas; útil para ambientes 3D multiníveis | Recast move o cooking de navegação para fora do Kof; Detour move a navegação de runtime para fora. DetourCrowd adicionalmente possui a evasão/movimentação e não deve substituir o controlador do shooter |
| **Dear ImGui** (MIT) | Forte atalho para inspetor/editor de depuração; integração com SDL3/SDL_GPU | Estado estrangeiro de widget/layout não é apenas uma adaptação de desenho. Adicione somente com uma exceção explícita para a UI de autoria |
| **RmlUi** (MIT) | Forte alternativa de UI retida para jogador/menu/inventário; backend real para SDL_GPU | Comportamento estrangeiro de layout/widgets; exige adaptação de callbacks/spans em C++. Não é um navegador nem uma solução completa de acessibilidade |

Construir manualmente colisão robusta de cápsula varrida, cooking de navmesh e
uma UI rica é uma consequência importante da regra atual de propriedade. Essas
alternativas poderiam reduzir esse trabalho; um wrapper de token inteiro não
torna seus algoritmos Kof. Não porte implementações inteiras de Jolt/Recast/UI
apenas para mudar a linguagem.**Ferramentas externas de autoria/depuração:** Blender para ativos de origem glTF/GLB,
TrenchBroom para autoria de mapas de brushes, RenderDoc junto com as camadas de
validação do Vulkan para diagnóstico da GPU. Estas são ferramentas de desenvolvimento,
não implementações de CPU pertencentes ao engine. Defina os contratos de
sessão/protocolo independentes do transporte de G0. Adie a escolha de uma biblioteca
de rede de terceiros até que a fatia de LAN exija uma; um transporte ainda não fornece
replicação, predição ou simulação autoritativa.

**Disponibilidade local observada:** `pacman -Q` e `pkg-config` encontraram SDL3
3.4.16, OpenAL 1.25.2, FreeType 2.14.3, HarfBuzz 14.5.0 e zstd 1.5.7.
SDL3_image, SDL3_mixer e SDL_shadercross estavam ausentes do banco de pacotes
consultado e dos módulos do pkg-config. Este inventário não comprova a integração
nativa com Kof, a compatibilidade dos dispositivos ou a conclusão do trabalho de
binding. Nenhuma biblioteca foi instalada nem dispositivo foi aberto durante esta
seleção.

**Ordem de adoção:** resolver o gate de correção do compilador nativo → comprovar
SDL_GPU/entrada/áudio enfileirado e transferência verificada de tokens/buffers →
adicionar serviços de imagem/texto → integrar o backend de áudio de produção escolhido
→ adicionar compressão de pacotes quando o formato estiver estabelecido. Fixe hashes
de artefatos, opções de build, avisos transitivos e ABI do adaptador a cada adoção.
Não há um framework separado de backend/plugin nem uma promessa de desempenho
implícita nesta lista curta.

Fontes primárias: [SDL GPU](https://wiki.libsdl.org/SDL3/CategoryGPU),
[shadercross](https://github.com/libsdl-org/SDL_shadercross) e sua
[opção de build do DXC](https://github.com/libsdl-org/SDL_shadercross/blob/main/CMakeLists.txt),
[OpenAL Soft](https://github.com/kcat/openal-soft/tree/8d2d2e2ed1f51df960e7eb4bb26b64625c873c0d),
[API WAV do SDL](https://wiki.libsdl.org/SDL3/SDL_LoadWAV),
[SDL_image](https://github.com/libsdl-org/SDL_image),
[licenciamento do FreeType](https://freetype.org/license.html),
[shaping do HarfBuzz](https://harfbuzz.github.io/what-is-harfbuzz.html),
[zstd](https://github.com/facebook/zstd),
[Jolt 5.6.0](https://github.com/jrouwe/JoltPhysics/tree/v5.6.0),
[Recast/Detour](https://github.com/recastnavigation/recastnavigation).
As fontes versionadas da UI e os limites adicionais de licenciamento estão em
[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md).

## 3. A fronteira FFI deve ser comprovada primeiro

O Kof nativo atual aceita chamadas `extern` escalares; arrays/estruturas/ponteiros/buffers
de saída e callbacks nativos estão bloqueados. Medimos a versão real do SDL e as
chamadas de libm, **não a inicialização gráfica**.

### Contrato do adaptador

As categorias de API propostas abaixo são contratos de design, não funções existentes:

| Categoria | Dados que atravessam a fronteira | Quem possui o comportamento |
|---|---|---|
| Ciclo de vida | Versão da ABI, capacidades, criação/destruição, status/erro | O adaptador possui os recursos do SDL; o Kof possui as decisões do ciclo de vida da aplicação |
| Entrada | Evento de polling; tipo marcado; campos escalares; texto normalizado copiado como String | O adaptador apenas achata SDL_Event; bindings, comandos e política de foco pertencem ao Kof |
| Recursos | Token inteiro tipado; campos escalares do descritor; liberação explícita | O registro do adaptador possui os ponteiros nativos; a política de tempo de vida de ativos/recursos pertence ao Kof |
| Uploads | Token de staging, deslocamento/quantidade, tuplas escalares fixas; posteriormente buffers em massa seguros, se houver suporte | O adaptador empacota/transfere bytes; o Kof cria/valida os dados e a semântica do conteúdo |
| Comandos | Iniciar/finalizar passe, associar pipeline/recurso, viewport/scissor, draw/dispatch | Seleção de passe, ordem de classificação, visibilidade e agrupamento pertencem ao Kof |
| Áudio | Token de clipe/stream decodificado, dados enfileirados, controles de ganho/canal | O Kof possui a política de alocação/prioridade e espacialização de vozes; o SDL possui o dispositivo/fila para G0, e os mecanismos de mixagem/DSP espacial/codec configurados pertencem à biblioteca de produção selecionada |
| Diagnóstico | Status numérico e texto de erro copiado | Nenhuma exceção deve se desenrolar através da fronteira C/Kof |

Regras:

- Tokens são identidades de slot+geração+tipo, nunca bits de ponteiro bruto em `Long`. Rejeite tokens obsoletos/de tipo incorreto, estouro de limites e liberações duplicadas.
- O registro do adaptador **não** possui entidades, inventário, mundo de colisão, estado de animação ou o grafo de cena.
- Os setters de descritores são traduções mecânicas para estruturas do SDL; eles não devem ocultar culling, ordenação, seleção de materiais ou agendamento de frames.
- Strings são copiadas na fronteira da chamada; nunca retenha endereços do heap do Kof. Retorne o texto de erro com um tempo de vida estável/de cópia explícito.
- Afinidade com a thread principal para eventos/janela/trabalho da GPU. Nenhum callback do Kof mantido pelo C. Threads estrangeiras de áudio/driver só podem tocar dados pertencentes à biblioteca/ao adaptador.
- Desmontagem explícita após a aposentadoria segura da GPU, não finalizadores do GC. Frames-em-voo exigem fences/ciclagem; um objeto Kof que se torna inalcançável não significa que um buffer da GPU não esteja mais em uso.
- A versão da ABI do adaptador e as versões das bibliotecas são verificadas na inicialização; incompatibilidades falham claramente, não por meio de um renderer que não faz nada.

### Estratégia honesta de upload

O primeiro cubo pode usar chamadas escalares de staging. Uma matriz/instância é escrita
como uma tupla fixa por chamada, não como dezesseis chamadas FFI individuais. Cargas
estáticas de vértices/índices são enviadas uma vez; dados dinâmicos usam buffers de
staging reutilizáveis e limitados. O Kof possui a política de empacotamento e o layout
de recursos; o lado C apenas copia a tupla especificada para posições verificadas do
buffer.

Para cargas em massa de ativos, uma cópia de intervalo-de-arquivo-para-staging de
baixo nível pode evitar FFI por byte **somente** quando o Kof tiver validado/cozinhado
o formato, o deslocamento e o tamanho; o adaptador não deve se tornar um parser/cooker
de ativos. Pequenas sondagens de `File.writeBytes/readBytes/readRange` preservaram
bytes zero/de bit alto na JVM/nativo. Casos de erro grandes/por intervalo e o staging
real do adaptador ainda não foram comprovados; o caminho do adaptador ainda é proposto,
não implementado.

A sobrecarga do staging escalar é uma **medição de aprovação/reprovação**. Se uploads
representativos de draw/instância/animação não atingirem o orçamento, prefira uma
adição upstream de FFI de buffer devidamente especificada (formato do elemento,
comprimento, tempo de vida de empréstimo/cópia, propriedade e regras de GC). Não
codifique frames binários como strings JSON/Base64 nem presuma que um cast de ponteiro
resolva a transferência em massa. Não transforme o shim em um renderer C para passar
em um benchmark.

### Gates de inicialização nativa e GCA inicialização real de vídeo/GPU/áudio do SDL deve ser executada a partir do ELF nativo emitido. A entrada/runtime nativa direta do Kof pode interagir de maneira diferente com a inicialização de libc/TLS/drivers do que um executável C convencional. Uma chamada de versão escalar não comprova nem a inicialização nem a segurança de callbacks/threads.

Comece com **uma thread Kof**. O código-fonte mostra que a auto-GC nativa é desabilitada após qualquer `spawn` do Kof; não use threads de trabalho nem coleta manual como solução alternativa. Pré-aloque arrays quentes/scratch e, em seguida, meça o comportamento da memória incluindo as alocações inevitáveis do runtime. Se o nativo não puder satisfazer os gates, documente a falha e corrija o compilador/ABI ou revisite explicitamente a escolha do alvo. Nunca altere silenciosamente o alvo de distribuição para JVM.

### Gate de correção do compilador

As sondagens orientadas pelo curso expuseram um defeito no tempo de vida do tratador de exceções nativo: uma asserção que falhava após um try/catch concluído normalmente reentrava naquele catch anterior e saía falsamente com sucesso. A redução do código-fonte salta além de `KofTryEnd`; [KOF_COURSE](KOF_COURSE.md) registra o caminho e [COURSE_PROBES](COURSE_PROBES.md) preserva o reproduzível e os controles. Resolva isso em um compilador fixado e revalide a conclusão normal, os lançamentos posteriores e a limpeza de recursos antes de depender de testes nativos baseados em exceções ou do tratamento do ciclo de vida. Uma solução alternativa baseada em retorno não prova que um tratador foi corretamente desvinculado.

Falhas nativas de limites também foram encerradas sem catch/finally, enquanto o lançamento explícito de String e a limpeza por retorno passaram em sondagens mais restritas. Valide todos os índices/capacidades/entradas de token antes do acesso; falhas fatais não são falhas recuperáveis de pool. Não alegue limpeza para um caminho de término do processo.

## 4. Arquitetura do runtime

```text
SDL event/time polling
        ↓
Client input snapshot → tick-stamped command
        ↓
Serialized loopback/LAN transport
        ↓
Authoritative server session (.kf)
        ├─ fixed-step world
        │   ├─ movement + collision
        │   ├─ weapons + projectiles + damage/statuses
        │   ├─ AI + encounters
        │   ├─ loot + progression + interactions
        │   └─ state changes + bounded domain events
        ↓
Authoritative snapshots/events
        ↓
Client prediction + reconciliation (.kf)
        ↓
Render/audio/UI extraction (.kf)
        ↓
Visibility + sorting + batching + pass orchestration (.kf)
        ↓
Thin scalar/buffer ABI adapter → SDL_GPU / SDL audio
```
### Núcleo mais módulos estáticos

KOOKIE usa um **monólito modular**: um único runtime autoritativo do Kof montado a partir de módulos explícitos e vinculados estaticamente. Esse é o formato de núcleo mais módulos no estilo Iceball, sem introduzir uma ABI de plugin dinâmica ou múltiplas autoridades de runtime.

`core` é deliberadamente pequeno e estável em relação às dependências. Ele é proprietário dos dados primitivos e dos contratos: IDs, armazenamento tipado, matemática, relógio, comandos, eventos, RNG, limites de alocação, regras de revisão/geração e tipos de resultado compartilhados. Core não importa código de gameplay, renderização, áudio, UI, editor ou handles nativos.

Os módulos são proprietários de capacidades verticais completas e só podem depender de camadas inferiores:

```text
core
 ├─ content contracts ── world/collision ── gameplay ── arpg
 ├─ presentation contracts ── render
 ├─ domain events ── audio
 └─ UI snapshots ── ui
```

Os módulos `render`, `audio` e `ui` consomem snapshots somente leitura do mundo e eventos. Eles nunca mutam o estado autoritativo da simulação. `editor` e `cooker` usam os mesmos contratos de consulta de conteúdo/mundo, mas publicam alterações por meio de transações verificadas por revisão. `platform` é um módulo adaptador, não um módulo de simulação.

Os módulos são, antes de tudo, limites de código-fonte/build, não binários carregados independentemente. Cada módulo expõe contratos pequenos e orientados a dados e mantém os auxiliares de implementação privados por convenção. A raiz da aplicação compõe módulos para os pontos de entrada do jogador, do cooker e do studio. Carregamento dinâmico, callbacks arbitrários, service locators e uma ABI pública de plugin ficam adiados até que dois consumidores reais comprovem uma necessidade.

Isso é preferível aos dois extremos:

- Um runtime monolítico único simplificaria o primeiro executável, mas rapidamente confundiria a propriedade, criaria ciclos de importação e tornaria os três perfis de jogo difíceis de compor ou testar.
- Plugins dinâmicos acrescentariam complexidade de ABI/versionamento/tempo de vida/threading antes que os gates de FFI nativo e correção do runtime do Kof fossem comprovados.

A primeira implementação pode manter os módulos em um único build e um único processo. O limite ainda é imposto por meio da direção das dependências, snapshots somente leitura, comandos/eventos tipados e publicação explícita de transações.
### Arquitetura de extensão

A extensibilidade é um contrato de primeira classe, não acesso aos componentes internos do engine. KOOKIE tem duas APIs:

1. Uma API de módulo interno privada, otimizada para o engine e autorizada a mudar.
2. Uma API de extensão pública versionada, composta por handles, definições, consultas, comandos, eventos, registries e snapshots. Extensões nunca recebem ponteiros brutos ou referências mutáveis para arrays centrais.

O modelo de extensão tem três níveis:

```text
Tier 1: data packages
  items, weapons, enemies, encounters, levels, materials, UI data,
  localization, recipes, progression and schemas

Tier 2: trusted Kof modules
  new components, systems, AI, world generation, editor tools and commands
  compiled into the application through the static module composition root

Tier 3: optional sandboxed runtime behavior
  only after the core API and failure budgets are proven; restricted to
  declared capabilities and explicit host calls, never engine authority
```

Cada extensão tem um manifesto contendo uma identidade com namespace, versões de API/schema, dependências, capacidades, declarações de conteúdo, ordem de carregamento, função de rede e migrações de salvamento. IDs de conteúdo usam namespaces (`mod:item_name`); slots de runtime e tokens de recursos nativos nunca aparecem em dados persistentes.

A API pública oferece:

- Contribuição de registry para definições, componentes, comandos e serializadores.
- Consultas somente leitura do mundo e buffers de comandos limitados.
- Hooks de sistemas específicos por fase com ordenação determinística.
- Assinatura de eventos de domínio com filtros e orçamentos declarados.
- Geração de mundo/encontros por meio de geradores semeados e limitados.
- Extração de renderização/áudio/UI por meio de snapshots e comandos pertencentes ao engine.
- Registro de migração de salvamento e codec de rede.
- Negociação explícita de capacidades e diagnósticos de conflitos.As extensões não mutam o mundo durante callbacks arbitrários. Um sistema lê
o snapshot aprovado/visão de consulta, emite comandos e recebe um ponto de
commit determinístico. A ordenação é primeiro por dependência, depois pela
prioridade declarada e, então, pelo ID com namespace. Conflitos, esgotamento de
capacidade, conteúdo inválido e capacidades ausentes falham de modo seguro,
com um diagnóstico acionável.

O primeiro SDK de extensão distribuído deve usar módulos `.kf` confiáveis
compilados estaticamente no player/cooker/studio. Esse é o caminho mais seguro
diante das limitações nativas atuais do Kof, preservando ao mesmo tempo uma API
estável voltada a mods. Uma camada posterior de scripts ou bytecode em runtime
pode oferecer mods sem recompilação, mas deve usar os mesmos contratos públicos,
limites de capacidade, declarações de salvamento/rede e orçamentos
determinísticos. Ela não deve se tornar uma segunda autoridade de gameplay.

Módulos internos podem acessar arrays otimizados diretamente. Extensões
públicas só podem usar handles, consultas, comandos, eventos e snapshots
estáveis. Isso mantém o mecanismo rápido sem obrigar toda refatoração interna a
se tornar uma promessa permanente de modding.
### Modelo de sessão com multiplayer em primeiro lugar

Toda partida é uma sessão de rede. Um jogador é um servidor local em modo
listen mais um cliente local conectado pelo mesmo transporte de loopback usado
pelo jogo em LAN; não existe um caminho de simulação privilegiado para
jogador único.

```text
single-player:
  player process
    ├─ authoritative server world
    ├─ client presentation world
    └─ serialized loopback protocol

LAN host:
  host process ─ server world + local client
  peer processes ─ client worlds

dedicated server:
  headless server world
  peer processes ─ client worlds
```

O servidor é responsável pela simulação autoritativa, identidade do conteúdo,
resultados do RNG, dano, inventário, saque, progressão, persistência do mundo,
execução de extensões com autoridade do servidor e decisões de admissão. Um
cliente é responsável pela captura de entrada, apresentação local, previsão de
ações explicitamente permitidas e reconciliação. Os resultados do cliente são
propostas, nunca resultados autoritativos.

O primeiro contrato de transporte é independente do transporte:

- Canal de controle confiável e ordenado para handshake, entrada/saída,
  comandos que exigem entrega, metadados de conteúdo/sessão e erros de
  migração.
- Canal não confiável e sequenciado para entrada e snapshots, no qual o estado
  mais recente substitui o mais antigo.
- Campos explícitos de tick, sequência, confirmação, baseline e revisão do
  conteúdo.
- Tamanhos de pacote, trabalho de decodificação, filas e contagens de
  entidades limitados.
- Nenhum ponteiro nativo, slot de runtime ou memória bruta de objetos Kof na
  rede.

O caminho de loopback deve serializar e decodificar mensagens em vez de passar
referências diretamente. Isso comprova a fronteira real entre cliente e
servidor no modo de jogador único e impede que o jogo local oculte bugs de
replicação.

A admissão da sessão verifica as versões do protocolo/API, a identidade da
compilação do mecanismo, os hashes dos pacotes de conteúdo, os manifestos de
extensão, os requisitos de capacidade e o esquema de salvamento compatível
antes de um cliente entrar no mundo. O servidor rejeita incompatibilidades com
um diagnóstico; ele não reduz silenciosamente a autoridade do gameplay.

As extensões declaram as funções `server`, `client`, `shared` ou `data`:

- Extensões `server` podem registrar sistemas autoritativos, geração do mundo,
  esquemas de replicação, comandos e migrações de salvamento.
- Extensões `client` podem registrar auxiliares de previsão, extração de
  renderização/áudio/UI e assets de apresentação.
- Extensões `shared` fornecem definições e codecs exigidos por ambos os lados;
  elas devem obedecer às regras determinísticas.
- Extensões `data` contribuem com conteúdo validado sem comportamento executável.

Nenhuma extensão pode tornar autoritativa uma decisão exclusiva do cliente. O
servidor e o cliente devem carregar definições compatíveis com namespace, e o
estado replicado das extensões deve usar esquemas declarados em vez de arrays
internos serializados.

A previsão é seletiva, não uma promessa de lockstep de ponto flutuante entre
plataformas. Os clientes preveem o movimento local e outros comandos
explicitamente aprovados, mantêm o histórico de entrada e então fazem a
reconciliação com os snapshots do servidor. Dano, inventário, saque,
progressão, encontros e persistência do mundo continuam sob responsabilidade
do servidor.




### Armazenamento de entidades/componentes

Comece com arrays de componentes explícitos, não com um framework ECS geral
pesado em reflexão:

- Identidade de entidade verificada por geração; alocador de lista livre; listas densas de iteração ativa.
- Arrays tipados separados para dados de transformação/velocidade/vida/colisor/arma/projétil/IA/status; definições imutáveis e frias fora do estado do tick.
- Preserve IDs estáveis entre referências; salvamentos usam IDs persistentes e definições, não slots densos ou tokens SDL.
- Criações/destruições estruturais adiadas para um limite de tick conhecido; nenhuma invalidação de iterador durante a travessia de dano/colisão.
- Separe os campos de presença/atividade dos componentes; evite semântica de primitivos anuláveis em pools de acesso intenso.
- A capacidade do pool e o comportamento de estouro devem ser explícitos. O estado crítico de dano/morte/saque não pode desaparecer silenciosamente. Rejeite conteúdo/spawns excessivos de forma determinística, reserve capacidade antes de confirmar transações ou mantenha um resultado pendente limitado. Efeitos cosméticos podem ser descartados com uma contagem observável.

Use registros/classes Kof para configuração e resultados frios. Para kernels
matemáticos, opere em campos escalares/arrays pertencentes ao chamador; não
crie objetos vetoriais temporários por colisão/raio/partícula.

### Relógio e entrada

Decisão inicial: **simulação a 60 Hz**, renderização independente com
interpolação; no máximo **quatro** etapas de recuperação. Limite o débito de
entrada a uma janela limitada documentada; contabilize o tempo de simulação
descartado em vez de entrar em espiral indefinidamente. Não há promessa de
lockstep determinístico de ponto flutuante entre plataformas.

- Comandos de disparo único persistem até que um tick real os consuma; eles não são repetidos em cada tick de recuperação.
- Movimento/disparo mantidos são amostrados para cada tick. O delta do mouse é uma entrada angular, não uma velocidade multiplicada por dt; atribua seu delta acumulado exatamente uma vez ou distribua-o explicitamente entre os ticks de comando pendentes, nunca o duplique.
- A perda de foco limpa a entrada mantida, libera a captura e impede disparos obsoletos. A pausa redefine o débito acumulado do relógio e desarma as ações de disparo único pendentes de acordo com o perfil do jogo.
- A interpolação da renderização nunca muta o estado autoritativo. A apresentação opcional tardia da câmera não deve alterar a mira registrada usada pelos acertos.
- O replay registra os comandos de tick resultantes, não os eventos brutos da plataforma nem os tempos de quadro.### Ordenação dos ticks

Uma ordem documentada: consumir comandos → atualizar prazos do temporizador/status e intenções de IA → movimento/colisão → resolução de armas/projéteis → dano/morte/recompensas centralizados → interações/transações de inventário → alterações adiadas de entidades → snapshot/eventos de saída. A ordem por ID estável resolve empates em tempos iguais.

Os prazos de status/armas usam ticks inteiros. Os ticks de DOT têm regras explícitas de expiração inclusiva/exclusiva e não são ignorados apenas porque um quadro renderizado foi longo. Registre e teste a regra escolhida.

## 5. Movimento, colisão do mundo e física

Use colisão estática real de triângulos/convexos 3D com um **jogador cápsula cinemático**, não uma restrição de mundo baseada em raycaster nem uma biblioteca geral de corpos rígidos como autoridade inicial.

Módulos de colisão pertencentes ao Kof:

- Testes de raio/segmento, limites de broadphase varridos, construção/travessia de BVH de triângulos, redução do impacto mais próximo.
- Contato e varredura contínua de cápsula/convexo, iterações limitadas de deslizamento, tolerância de skin, sondagem do chão, limite de inclinação e sequência de subir/avançar/descer degraus.
- Broadphase de atores dinâmicos mais narrow phase; projéteis de esfera/cápsula varridos; teletransportes têm recuperação de sobreposição separada.
- Movimento de comprimento zero, início em penetração, tangência de arestas, contatos opostos e passagem em alta velocidade são casos explícitos. Nunca use apenas a sobreposição no destino.
- Plataformas de portas estáticas/móveis modeladas com transformações próprias e dados de consulta consistentes. O jogador, a LOS da IA, as balas e a seleção do editor consultam o mesmo mundo cozido autoritativo.

Os perfis de movimento definem atrito/aceleração no chão, aceleração no ar, limites de velocidade, buffer de salto/tempo de coyote, política de bunnyhop/dash e agachamento. Tome emprestados os contratos de intenção/salto do DINX; implemente a aceleração semelhante à de Quake baseada em projeção como um perfil deliberado, em vez de rotular incorretamente a aceleração de aproximação vetorial.

Uma biblioteca de corpos rígidos não é inicialmente necessária. Se posteriormente for exigida para pilhas/veículos/destruição, avalie-a como uma exceção explícita de biblioteca externa; nunca mova a autoridade do jogador/combate para ela por padrão.

## 6. Renderizador e apresentação

Renderizador inicial: renderização forward opaca/mascarada, buffer de profundidade, suporte a lightmap estático ou iluminação por vértice, luzes dinâmicas limitadas, malhas estáticas instanciadas, sprites/billboards, viewmodel em primeira pessoa, decals/partículas e HUD. O 3D verdadeiro permite salas empilhadas, inclinação, rampas, encontros verticais e inimigos em malha.

- O Kof executa culling de frustum/espacial, listas de visibilidade, agrupamento de materiais/malhas/pipelines, ordenação de transparência e orquestração das passagens de renderização.
- Recursos estáticos são mantidos; buffers de quadro/staging são reutilizados. A criação e destruição dinâmica de recursos é proibida durante o jogo estável.
- Passagens básicas: profundidade/opaca + sombras opcionais limitadas, transparência/efeitos, viewmodel, pós-processamento/mapeamento de tons, UI. Não introduza complexidade deferred/clustered até que populações de luzes medidas exijam isso.
- Estilos de baixa resolução/pixelados, de paleta/iluminação limitada e modernos mais limpos são perfis de material/pós-processamento, não simuladores de mundo alternativos.
- Convenção única de coordenadas: metros, Y para cima, mundo destro, câmera apontando para -Z. Construa conversão explícita de projeção/clipping para a convenção documentada de clipping/profundidade do SDL_GPU; não transponha/inverta de forma ad hoc. Valide juntos a orientação de culling, normais, orientação, intervalo de profundidade e origem das texturas.
- Fontes de shader em HLSL, SPIR-V offline para a primeira plataforma; fixe o SDL_shadercross e faça reflexão/validação das ligações de vértice/uniformes. Produtos adicionais de shader para backends somente quando o alvo correspondente for exercitado.
- Primeiro caminho de animação: sprite/billboard ou malha rígida; depois avaliação do estado/interpolação de animação do Kof e da pose esquelética, shader de skinning na GPU. A admissão de pose de referência/índice/peso permanece no cooker. Nenhum parsing de assets por quadro.
- A lógica e o layout de HUD/menu/inventário/sobreposição de depuração são `.kf`, renderizados pelo engine. A rasterização externa de texto/fontes pode ser uma dependência estreita de biblioteca; não comece com um editor/runtime de UI completo baseado em webview.

Alvos como FOV do viewmodel, recuo/balanço, clarões de boca do cano, feedback de acerto, cores de raridade legíveis e ícones de status são recursos do engine, não motivos para colocar a lógica de apresentação no adaptador C.

## 7. Modelo de combate e ARPG

### Armas e dano

Separe `WeaponDef` imutável do estado de runtime de carregador/recarga/recarga temporizada/giro/rajada e dos modificadores da instância do item. Ofereça hitscan, projéteis varridos, dispersão de espingarda e dano em área por meio de caminhos compartilhados de consulta/dano.

- Uma máquina de estados de gatilho; nenhum sistema de disparo antigo/novo concorrente.
- ID estável por disparo e fluxo de RNG explícito; o consumo de munição e a criação do disparo aceito são confirmados juntos.
- Um único caminho de resolução de `DamageRequest` aplica escalonamento da fonte, crítico, armadura/resistência, escudo/vida, aplicação de status e transição de morte em uma ordem documentada.
- Canais de dano e fórmulas de mitigação são orientados por dados, mas versionados. Não combine silenciosamente as suposições incompatíveis de armadura antes da resistência do CUBSHIP e de fórmula do ZYLVE.
- Exatamente uma transição vivo→morto é responsável por XP, saque e crédito de missão; a apresentação consome eventos e nunca concede recompensas.
- Afixos de inimigos/chefes podem modificar hooks definidos sem loops arbitrários de procs recursivos no mesmo quadro. Limites de profundidade/taxa de proc são explícitos.

### Saque, inventário e progressão

- `ItemDef` identifica um template; `ItemInstance` armazena ID estável, seed, nível do item, raridade, afixos selecionados/valores rolados e estado mutável de condição/soquete.
- Seleção de saque: tabela de encontro → item-base ponderado → raridade → pool elegível de prefixo/sufixo/modificador → rolagens com exclusões/restrições de tier. Use fluxos de RNG separados por sistema; preserve os resultados nos saves.
- A ordem de composição dos afixos é explícita: base → valor fixo → porcentagem aditiva → grupos multiplicativos → limites/arredondamento. Recalcule em alterações de equipamento/definição, não a cada quadro.
- Inventário/equipamento/baú/crafting usam validação + reserva + confirmação atômica. Inventário cheio, IDs duplicados, moeda insuficiente e slots incompatíveis deixam itens, moeda e RNG inalterados.
- As definições de habilidade declaram pré-requisitos/limites de rank/custos/recargas/tags; as instâncias de personagem possuem ranks/loadout/XP/recursos.
- As definições de status especificam regras de atualização/substituição/adicionar acúmulo, limite de duração e programação de ticks. Morte/reset/carregamento limpam ou mantêm efeitos intencionalmente.
- Salve as rolagens dos itens, não apenas o estado atual do RNG, para que a migração de balanceamento/conteúdo não role novamente o equipamento silenciosamente.Pegue emprestadas as invariantes de transação/identidade de ZYLVE, não seus nomes fixos de armas, tamanhos reduzidos de inventário ou tabelas fixas de drops por nível. Esses sistemas fazem parte da engine planejada, não foram adiados para fora do escopo após uma demonstração de tiro.

### IA e encontros

Comece com máquinas de estado determinísticas: idle/patrol/investigate/chase/attack/recover/stagger/dead; arquétipos de combate corpo a corpo, projéteis e hitscan. A percepção do Kof usa candidatos espaciais, distância ao quadrado/cosseno do FOV, LOS compartilhada e memória de ameaça marcada por tick.

Primeiro, navegação com waypoints/portais criados manualmente; depois, um pipeline real de navmesh/A* compilado, com expansões limitadas e `pending/success/failure` explícitos. Distribua as atualizações dispendiosas de percepção/caminho ao longo dos ticks; use agendamento fixo e arrays temporários próprios, sem threads de trabalho do Kof até que sejam seguras para o GC. Volumes de encontro, orçamentos de ondas, fases de chefes, admissão de surgimento e gatilhos de chaves/portas/segredos são orientados por dados.

## 8. Conteúdo, fluxo de trabalho do criador e persistência

### Pipeline de conteúdo

Fontes editáveis → **Kof cooker** → pacote versionado da engine → carregamento validado em tempo de execução.

Formatos de fonte iniciais: manifesto do projeto e definições de entidades/encontros/itens
em dados estruturados legíveis; malhas estáticas/materiais em um subconjunto
documentado de glTF; Dust3D `.ds3`; LibreSprite `.ase`/`.aseprite`; MagicaVoxel `.vox`;
imagens/áudio em um conjunto de formatos deliberadamente pequeno e compatível. Esses
são formatos de entrada offline, não formatos de pacote em tempo de execução. Valide
geometria finita, índices de triângulos, dimensões de voxels/referências de paleta,
limites de quadros de sprites, metadados de animação, limites de tamanho/quantidade,
referências de recursos, transformações e sinalizadores de colisão. Bibliotecas
nativas de decodificação podem fornecer pixels/PCM, mas não semântica de
cena/loot/colisão.

### Compatibilidade de entrada de assets externos

O Kof cooker preserva a fonte original e o registro da ferramenta/versão, então
normaliza o resultado para o contrato de pacote canônico:

| Fonte | Resultado de entrada obrigatório |
|---|---|
| Dust3D `.ds3` | Validar os dados de malha/UV/esqueleto exportados e produzir GLB, além de materiais e colisão opcional |
| LibreSprite `.ase`/`.aseprite` | Extrair quadros/camadas/tags/slices limitados e produzir atlas PNG, metadados versionados e definições de animação |
| MagicaVoxel `.vox` | Analisar modelos voxel/paleta limitada e chunks de cena compatíveis, e produzir malha/GLB determinística, além de materiais e colisão voxel opcional |

Use GLB para intercâmbio de runtime 3D e PNG mais metadados versionados para
intercâmbio de runtime de sprites. OBJ/FBX são alternativas de conversão, não
contratos de runtime. Chunks, modos de cor/profundidade, recursos de animação ou
convenções de coordenadas não compatíveis falham com um diagnóstico ou exigem uma
regra de normalização explícita; eles nunca passam adiante como dados ambíguos.
Publique somente depois que os limites de tamanho decodificado, índice, paleta,
quadro, transformação e números finitos forem aprovados.

Dust3D é uma ferramenta externa de autoria com licença MIT. LibreSprite é GPLv2 e
não pode ser incorporado ao KOOKIE; use exportação externa ou um leitor de formato
implementado de forma independente, com avisos separados. MagicaVoxel é freeware
proprietário; não inclua sua aplicação. Aceitar arquivos `.vox` fornecidos pelo
usuário e ler o formato documentado não concede direitos de redistribuição da
ferramenta.

Para autoria de boomer-shooter, adicione um subconjunto textual de brushes no estilo
Quake, `.map`: recorte/triangulação de planos de brushes convexos, tradução de
entidades/propriedades, mapeamento de materiais e colisão/visibilidade derivadas.
TrenchBroom pode ser uma ferramenta externa de autoria; nosso cooker `.kf` continua
sendo a autoridade de importação. Isso **não** promete compatibilidade com
WAD/BSP/QuakeC/source ports. Mapas-fonte não são assets dos jogos originais
distribuídos.

Contrato do pacote compilado: magic, versões de schema/ferramenta/conteúdo, IDs
estáveis, offsets/comprimentos de chunks, hashes de dependências, endianness
explícito, limites e verificações de corrupção. Rejeite traversal, IDs duplicados,
payloads sobrepostos/fora do intervalo e overrun de descompressão. Não serialize a
memória de objetos do Kof nem cabeçalhos de arrays internos.

O JSON nativo de registros mistos Int/Double/String falhou no round-trip medido,
incluindo valores numéricos/string corrompidos; getters diretos de registros foram
aprovados. Antes de adotar JSON nativo para definições, glTF ou saves, exija um
reparo do compilador/runtime e uma prova específica do schema de round-trip, entrada
malformada e limites. Não trunque floats, não troque silenciosamente o cooker para
JVM nem mova a semântica de conteúdo para o adaptador. A IO de arquivos binários
passou por uma pequena sondagem, mas não é um formato/codec alternativo
implementado.

O código-fonte atual rejeita `process.run`/`process.spawn` nativos com `PROC001`.
Portanto, ferramentas externas de shaders/conversão precisam da orquestração mínima
de build permitida ou de uma capacidade de plataforma comprovada separadamente; o
cooker `.kf` nativo não pode presumir que os exemplos de processos do curso
funcionem. Ele ainda é responsável pelas decisões de validação e compilação de
conteúdo.

### Ferramentas de autoria da engine

Não faça fork do Kof Editor primeiro. Construa ferramentas `.kf` que usem as mesmas
bibliotecas de runtime:

1. Cook/validate/package de linha de comando e um template de projeto jogável.
2. Inspector/console dentro da engine, ferramentas de surgimento/armas/loot e visualização de colisão/IA.
3. Edição de mundo/entidades, navegador de assets, editores de encontros/itens/habilidades, desfazer/refazer e play-in-editor.
4. Prepare todo trabalho de edição/cook sujeito a falhas, depois verifique a revisão e publique os produtos de mundo/colisão/nav/render juntos em um limite de quadro. Nunca mostre geometria nova com colisão obsoleta.

O recarregamento de dados/shaders pode ser compatível após a validação e a retirada
segura para a GPU. A iteração inicial de código `.kf` é rebuild/restart, não uma
substituição arbitrária de código em tempo real prometida. Não introduza uma segunda
linguagem de script.

### Saves e replay

- Seções de save versionadas: personagem/progressão, instâncias e propriedade de itens, persistência do mundo, estado de missões/encontros, streams explícitos de RNG e IDs de conteúdo.
- Faça o snapshot em um limite de tick definido; prepare o arquivo, valide/verifique o checksum, faça flush/sync, substituição atômica e aplique uma política de durabilidade do diretório apropriada ao alvo. Recupere-se de gravações interrompidas; a detecção de corrupção não é autenticação.
- Migrações operam sobre schemas, nunca sobre slots/ponteiros brutos. Seções obrigatórias desconhecidas/mais novas falham com um erro útil e deixam o save antigo intacto.
- O replay armazena a versão da engine/conteúdo, o snapshot/seed inicial, comandos de tick e checkpoints/diagnósticos de hash. Buscar uma posição restaura um checkpoint e então simula novamente. Eventos de apresentação com timestamp não são suficientes.
- Política de mods: código `.kf` confiável exige rebuild e tem autoridade sobre o host; mods somente de dados têm admissão limitada de caminho/schema. Não chame código confiável de sandbox.A rede é um requisito de primeira classe, não um recurso posterior de cooperação. Preserve uma simulação de servidor autoritativa, comandos de tick serializáveis, snapshots, predição/reconciliação e codecs independentes do transporte desde G0. O modo para um jogador usa a mesma sessão servidor/cliente por loopback; o host de LAN e o servidor dedicado são composições dos mesmos módulos de sessão. Não prometa lockstep de ponto flutuante entre alvos: replique comandos, estado autoritativo e esquemas de extensão declarados.

## 9. Layout de origem proposto

Os diretórios abaixo são **limites futuros de responsabilidade**, não arquivos criados por esta pesquisa. A ligação final de entradas/raízes de módulos é estabelecida no marco G0; o Kof `run` coleta automaticamente fontes irmãs, portanto várias funções `main` não podem simplesmente existir sob uma única raiz coletada indiscriminadamente.

```text
src/
  core/          ids, arrays, math, clock, commands, events, RNG
  platform/      Kof extern declarations and checked resource wrappers
  session/       server/client roles, admission, ticks, snapshots, prediction
  net/           wire messages, codecs, channels, sequence/ack/baseline state
  world/         entity state, spatial queries, level state, collision
  render/        extraction, culling, materials, batching, pass policy
  animation/     clips, pose state, interpolation
  audio/         voice policy, spatialization, event mapping
  gameplay/      movement, weapons, damage, AI, encounters, interactions
  arpg/          item definitions/instances, stats, loot, skills, progression
  content/       schemas, validation, package readers, migrations
  extensions/    manifests, registries, capabilities, public API adapters
  ui/            HUD, menus, inventory, debug/authoring views
apps/            player host/client, dedicated server, cooker, studio
samples/         boomer arena and looter/ARPG encounter projects
native/          only indispensable ABI/library adaptation
shaders/         GPU-only source and generated backend products
content/         authored source assets/definitions with provenance
```

Nenhum `runtime.kf` monolítico controla todos os sistemas. Nenhum contêiner de serviços genérico ou ABI de plugin antes que dois consumidores concretos o exijam. Os módulos de sessão e rede dependem dos contratos do núcleo; os módulos do servidor controlam a autoridade; os módulos do cliente consomem snapshots e emitem comandos de entrada; os callbacks do renderizador nunca modificam o mundo.



## 10. Marcos e aceitação observável

Nenhuma promessa de calendário; cada marco possui evidências executáveis. Um marco bem-sucedido autoriza o próximo escopo, não é uma declaração de que o mecanismo completo existe.

| Marco | Trabalho | Aceitação / condição de interrupção |
|---|---|---|
| **G0 — Viabilidade nativa e da sessão** | Fixar compilador/artefato/SDL; resolver o defeito do manipulador de exceções; estabelecer build modular; definir envelope de transmissão/codecs; adaptador escalar/tokens de recursos; inicialização nativa real; medições de memória/FFI | Sondas corrigidas de ciclo de vida/limpeza do manipulador nativo são aprovadas, incluindo controles negativos. ELF nativo abre uma janela SDL_GPU isolada, desenha geometria texturizada, trata redimensionamento/foco/mouse relativo, reproduz um pequeno clipe de áudio enfileirado e fecha corretamente. O transporte de loopback consegue codificar/decodificar mensagens limitadas de controle/entrada/snapshot sem referências ou ponteiros brutos. A falha bloqueia o compromisso com a arquitetura nativa/de sessão |
| **G1 — Base do shooter autoritativo** | IDs/arrays de componentes, tick do servidor a 60 Hz, comandos de entrada do cliente, mundos de servidor/cliente em loopback, baseline de snapshot, cápsula/BVH, câmera, renderizador/HUD, uma arma/inimigo | O modo para um jogador conclui uma sessão real servidor→loopback→cliente. A predição/reconciliação do cliente é observável. Um segundo cliente pode ser admitido pelo mesmo harness de protocolo. A arena 3D real criada suporta inclinações/escadas/salas empilhadas; a perda de foco não pode manter o disparo/movimento preso. Nenhum crescimento de pool por frame |
| **G2 — Fatia de boomer-shooter em LAN** | Adaptador de transporte LAN, hitscan/projétil/escopeta, várias funções de inimigos, portas/chaves/segredos, feedback/áudio, definições de encontros, tratamento de entrada/saída | O host e pelo menos dois clientes concluem início→luta→chave/porta→segredo→saída pela LAN. O servidor controla dano/morte/recompensas. Desconexão/reconexão e entrada obsoleta são limitadas e diagnosticadas. Os perfis de movimento continuam ajustáveis sem alterações no renderizador |
| **G3 — Fatia de looter / ARPG** | Itens/afixos gerados, inventário/equipamento, XP/habilidades/efeitos de status, elites/chefes, salvamentos autoritativos, registros de extensões e esquemas replicados | Multiplayer conclui eliminação→drop gerado→coleta/equipamento→mudança observável de atributo/habilidade→recompensa de chefe→salvar/recarregar. O inventário cheio não pode perder item/moeda/RNG. A mesma seed/conteúdo produz o mesmo resultado no servidor. Os clientes não podem criar dano, itens, moeda ou progressão |
| **G4 — Pipeline de criação e extensão** | Kof cooker, formatos de malha/brush compatíveis, validação de pacotes, manifestos de modificação de dados, módulos de extensão Kof confiáveis, inspetor/editores, recarregamento em etapas | Um segundo jogo multiplayer distinto é construído a partir de definições/extensões sem editar o código do núcleo do mecanismo. Servidor/cliente rejeitam manifestos incompatíveis de pacote/API/mod. Conteúdo inválido deixa o mundo em execução anterior intacto; as revisões de geometria/colisão/navegação/replicação permanecem alinhadas |
| **G5 — Escala e lançamento** | Orçamentos de IA, batching/instancing, animação, streaming apenas quando necessário, servidor dedicado headless, migrações/reprodução, reforço de reconexão/admissão, empacotamento/avisos | A carga de trabalho de referência em LAN atende aos orçamentos declarados; o servidor dedicado é executado sem gráficos; as contagens de memória/recursos estabilizam; o pacote é executado fora do checkout do código-fonte; a recuperação de reconexão/sessão e a compatibilidade de extensões são comprovadas |
| **G6 — Expansão** | SO/backend/arquitetura adicionais, jobs seguros, transporte WAN, editor mais completo, extensões em runtime isoladas | Cada extensão comprova compatibilidade real de runtime/ABI/conteúdo; nenhuma alegação de portabilidade, WAN, sandbox ou plataforma é inferida do suporte da dependência |

A evidência atual está em [G0_BACKLOG](G0_BACKLOG.md). Sessões limitadas, gameplay, saves/replay e sondas SDL_GPU offscreen executam; apresentação isolada em janela, aceitação de desempenho/recursos sustentados e a arena jogável completa continuam pendentes. Gatilhos cooperativos de chave/porta/segredo/saída agora passam pela admissão autoritativa por tick e snapshots do cliente, mas ainda não controlam colisão/geometria das portas nem concluem o gate G2 em LAN.

### Hipóteses iniciais de desempenho, não números alcançados

Cena de referência para o primeiro estágio de escala: 64 inimigos ativos, 256 projéteis em movimento, 512 itens coletáveis, luzes/efeitos dinâmicos limitados e um nível médio criado manualmente. Mantenha uma variante de estresse mais pesada após a correção da linha de base; não alegue escalabilidade arbitrária da população.

Metas a medir em CPU/GPU/driver/resolução/build explicitamente registrados: simulação a 60 Hz, trabalho de simulação p95 ≤4 ms/tick, quadro p95 ≤8.33 ms para uma meta de renderização de 120 Hz a 1080p e nenhum crescimento monotônico de recursos/RSS em um soak limitado de 30 minutos após o aquecimento. Registre p99/máximo e os custos de GC/upload, não apenas o FPS médio. Um resultado abaixo da meta altera capacidade/conteúdo/implementação com base nos perfis; não justifica mover a jogabilidade para fora do Kof.

Esses limites são metas de projeto. A correção pode ser testada sob renderização por software, mas os tempos do renderizador de software não podem certificar as metas de hardware. As provas de gráficos/entrada devem ser serializadas dentro de um ambiente de exibição isolado e descartável.

## 11. Riscos de verificação e decisão

### Estratégia de prova focada

- Linguagem/ABI: pequenas sondas executáveis `.kf` cobrindo exatamente os novos tipos, imports, tempos de vida de escalares/buffers e caminhos de bibliotecas nativas.
- Caminhos de falha do compilador: compare externamente as saídas/status de saída; uma saída nativa verde pode ocultar uma asserção capturada. Mantenha controles negativos de tentativa normal→lançamento posterior e distinções entre falhas fatais e capturáveis. Não reutilize as receitas de asserção autocapturável do curso.
- Colisão: passagem através de parede fina, sobreposição inicial, limites de inclinação/degrau e deslizamento em cantos; mantenha regressões focadas para defeitos plausíveis.
- Simulação: consumo de evento de disparo único com zero/múltiplos ticks, política de dívida por sobrecarga, transições de pausa/foco.
- Combate: atomicidade de munição+disparo, prazos de recarga, expiração/compensação de DOT, uma transição de morte/recompensa.
- Economia: conservação e exclusividade de itens, reversão de falha, reversão de RNG, consistência de salvar/carregar/migrar.
- GPU: verificação real da superfície para shader/textura/culling/profundidade, redimensionamento/minimização/foco e desmontagem de recursos. Nunca substitua verificações de fonte ou um fixture de impressão de `InitWindow` por uma janela real.
- Ferramentas: rejeição de conteúdo malformado e de resultados obsoletos de edição/cook, preservando o mundo válido anterior.

Regra de exibição do repositório: use `overzeer-isolated-display` ou um wrapper equivalente revisado, com sockets privados de exibição/sessão, timeouts limitados e limpeza completa da árvore de processos. Nunca interaja com a área de trabalho/monitores do desenvolvedor. Xvfb simples ou apenas remover DISPLAY não é suficiente para testes gráficos. Não execute a matriz completa durante a implementação; execute a matriz final pré-commit somente com a autorização de execução única do usuário.

### Registro de riscos

| Risco | Evidência atual | Ação / estágio de liberação |
|---|---|---|
| FFI não possui buffers/estruturas/ponteiros/callbacks nativos em lote | Rejeição de fonte + array medida | Adaptador escalar mínimo; medir overhead de upload; propor contrato de buffer upstream se necessário |
| Inicialização do runtime C nativo/driver | Apenas chamadas de versão/libm medidas | Prova G0 de GPU/áudio/entrada SDL real; não inferir a partir de fixtures de ABI simulados |
| Coletor nativo após spawn | Estágio de spawn cumulativo na fonte do alocador | Uma única thread Kof; soak prolongado; nenhum bypass inseguro de GC manual |
| Desempenho da geração de código nativo | Pipeline mínimo de otimização | Medir arrays/matemática/FFI representativos; usar batching/pré-alocação; não reescrever a jogabilidade em C |
| Redução do runtime de distribuição | Aviso reproduzido fora do checkout do compilador | Corrigir upstream ou medir/aceitar explicitamente a dependência/tamanho do runtime completo antes da liberação |
| Manipulador nativo de exceção obsoleto | A asserção posterior reentrou em um try/catch concluído e saiu com 0; o lowering ignora a remoção do manipulador | Resolver/revalidar antes de confiar na limpeza de exceções G0 ou nos resultados dos testes; nenhum shim de fluxo de controle |
| Paridade de JSON/split nativo | JSON de registros mistos fracionários corrompeu valores; split com pipe escapado diferiu da JVM | Reparar/provar esquemas exatos de conteúdo/salvamento e contratos do parser antes de depender de G3/G4 |
| Linguagem/documentação divergem rapidamente | Curso 0.3.7 / páginas mais antigas do portal / versão 0.4.9 | SHA da fonte + digest executável; atualizar por meio de sondas de comportamento focadas, não alegações baseadas apenas em compilação |
| Confiabilidade/segurança do editor | Execução de arquivo único, UI em JS, manipuladores privilegiados não autenticados | CLI + editor separado com capacidade de LSP; nenhuma dependência de fork do editor |
| Pipeline de criação torna-se um segundo engine | Monólitos irmãos/múltiplas autoridades | Contratos compartilhados de runtime/query/conteúdo `.kf`; publicação em estágios no limite do quadro |
| Suposições sobre licenças/recursos | Direitos mistos entre projetos irmãos; fonte DoomKof sem licença | Preservar a proveniência, resolver concessões, possuir/testar os recursos inicialmente |
| Portabilidade nativa alegada em excesso | A saída nativa examinada é um ELF Linux | Estágios de plataforma separados; a lista de backends SDL não equivale ao suporte de executáveis Kof |

## 12. Primeiro incremento de implementação

**G0 está em andamento.** A fundação modular/de sessão inicial agora existe:

- `src/core/foundation.kf`: contratos de protocolo/tick do núcleo escalar.
- `src/session/loopback.kf`: codec de verificação do envelope limitado de cinco palavras.
- `src/main.kf`: um único ponto de entrada Kof modular.
- `probes/g0_platform/main.kf`: sonda de plataforma SDL3 escalar isolada.

As execuções focadas em JVM/nativo passam para o smoke da sessão e para a sonda escalar direta de
`SDL_GetVersion()`. O backend nativo ainda emite o aviso conhecido de redução do runtime completo. A primeira tentativa expôs um defeito de boxing de registro/array entre pacotes do Kof e um defeito de verificador de extern escalar encapsulado; a implementação agora mantém o limite do módulo público inicial baseado em contratos escalares/de arrays e isola a FFI direta em sua própria sonda. Esses defeitos do compilador continuam sendo estágios upstream, não soluções alternativas do engine a serem generalizadas.

Próximas ações de G0:

1. Preservar essas sondas como regressões focadas e estabelecer o contrato verificado de tokens/recursos sem casts de ponteiros.
2. Provar a inicialização real de janela/GPU/áudio do SDL a partir do ELF nativo sob o wrapper de exibição isolado.
3. Medir o staging de tuplas escalares e o comportamento de memória limitado em uma única thread.
4. Corrigir ou colocar explicitamente em estágio os defeitos do compilador nativo antes de adicionar a implementação completa de sessão/mundo.