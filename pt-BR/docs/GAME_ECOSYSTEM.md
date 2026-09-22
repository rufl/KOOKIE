# Jogos feitos com Kof e suas pilhas gráficas

Data da pesquisa: 2026-09-22. Pesquisa somente na Internet/API/código-fonte; nenhum desses jogos foi compilado ou executado aqui.

## Resposta

**Sim: foram encontrados dois jogos concretos feitos com Kof e publicados com código-fonte**, incluindo um raycaster semelhante a um FPS. Um terceiro demo de Pong é relatado em uma issue upstream. Nenhum dos materiais inspecionados comprova um shooter lançado e com qualidade de produção usando o backend ELF nativo do Kof.

| Projeto | Classificação | Rota real de gráficos/runtime | Confiança |
|---|---|---|---|
| [DoomKof](https://github.com/M-Tesla/DoomKof) | Protótipo de FPS com raycast por software inspirado em Doom | simulação `.kf` → JVM → **Jaylib JNI 5.5.0-2 → raylib**; `.kf` alternativo → KofJS → **Canvas2D do navegador com JS escrito manualmente** | Código-fonte/build verificados; não executado |
| [kofman / Byte Eater](https://github.com/lavdev/kofman) | Jogo de arcade para navegador no estilo Pac-Man | `.kf` → **kof.ui / KofJS / Canvas2D + DOM**; backend JVM `kof.web`; integração de teclado em JS | Código-fonte/build verificados; não executado |
| [Pong by tomast1337](https://github.com/KofLang/Kof4j/issues/431#issuecomment-5722558116) | Jogo experimental vinculado a um vídeo | O autor relata **Kof + raylib**; a discussão descreve uma ponte em C | Nenhum código-fonte/build do jogo localizado; destino/versão exatos não verificados; vídeo não assistido |
| Kof4j `tetris.run()` | Easter egg de terminal incluído | chamada Kof → **runtime Java + terminal ANSI / stty** | Código-fonte da implementação verificado; a lógica do jogo não está em `.kf` |

As APIs de releases do GitHub retornaram arrays vazios para DoomKof e kofman durante a pesquisa. Isso não significa que eles não possam ser executados a partir do código-fonte, nem que não exista um release em outro lugar. Nenhum título KofLang para Steam/itch foi identificado na busca delimitada.

## DoomKof: o precedente mais relevante

Snapshot: [`d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb`](https://github.com/M-Tesla/DoomKof/tree/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb), commit 2026-08-29.

O README o chama de um experimento simples. Ele é um raycaster inspirado em Doom, **não um port original de Doom, um engine compatível com WAD nem uma prova de 3D completo**.

### O que é realmente Kof

[`src/engine.kf`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/src/engine.kf) contém o estado do mapa/jogo, colisão/avanço dos raios, inimigos, disparos, itens coletáveis e dados das colunas de renderização. A configuração observada inclui um mapa 16×16, escala de ponto fixo 256, 64 colunas e apresentação 640×400. Funções representativas: `ray`, `fillColumn`, `fire`, `boot`, `tick`, `tickView`.

Esta é uma lógica de jogo significativa em Kof, não apenas um iniciador em Kof ao redor de outro engine.

### Evidências de gráficos no desktop

[`src-raylib/main.kf`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/src-raylib/main.kf) importa:

```text
com.raylib.Raylib
com.raylib.Helpers
org.bytedeco.javacpp.BytePointer
```

Ele chama `InitWindow`, `SetTargetFPS(24)`, leitura de entrada/cursor, `DrawRectangle`, `DrawText`, `BeginDrawing`, `EndDrawing`, `CloseWindow`. O renderizador de colunas é implementado por meio dessas primitivas de desenho.

[`scripts/run-raylib.sh`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/scripts/run-raylib.sh) fixa `uk.co.electronstudio.jaylib:jaylib:5.5.0-2`, compila com `--target=jvm --classpath` e, em seguida, invoca o Java com as classes compiladas e o Jaylib no classpath. [`DEPENDENCIES.md`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/DEPENDENCIES.md) identifica o JNI Jaylib, não o Jaylib-FFM.

**Conclusão:** uma janela nativa do sistema operacional apoiada pelo raylib, mas o código Kof é executado na JVM. Isso não é evidência de `--target native`.

### Evidências de gráficos no navegador

[`scripts/build-js-play.sh`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/scripts/build-js-play.sh) compila o Kof do engine para JS e ajusta as exportações. [`web/play.mjs`](https://github.com/M-Tesla/DoomKof/blob/d5ab99fec4a96e3cd43a91a9ccafc79a6c7865eb/web/play.mjs) importa essas exportações, obtém um contexto Canvas2D e desenha paredes/sprites/arma/HUD/minimapa. Ele também controla a integração de teclado/mouse/ponteiro do DOM e o agendamento dos frames.

A rota do navegador, portanto, contém uma quantidade substancial de apresentação/entrada escrita manualmente em JS. Não a use como prova do nosso objetivo mais rigoroso de manter toda a lógica do engine em Kof.

### Compatibilidade histórica e reutilização

O projeto tem como alvo Kof 0.2.1-beta/JDK 21 e relata soluções alternativas antigas para problemas do compilador/classpath/constantes/chamadas `void`. Trate-as como observações datadas do projeto, não como limitações atuais do 0.4.9. Nenhum arquivo de licença foi encontrado na árvore inspecionada, e os metadados de licença do GitHub eram nulos. Estude a arquitetura, mas não copie o código-fonte sem resolver a questão da permissão.

## kofman / Byte Eater

Snapshot: [`d0d0d1bdb83653d58f9a21e8552775b7d4839699`](https://github.com/lavdev/kofman/tree/d0d0d1bdb83653d58f9a21e8552775b7d4839699), commit 2026-09-11. Licença MIT no repositório.

### Arquitetura real

- [`Makefile`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/Makefile): build do frontend KofJS, cópia dos sprites, ajuste da entrada web, servidor JVM.
- [`game.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/game/game.kf): janela/labels/Canvas da UI do Kof, intervalo de 100 ms, atualização da jogabilidade, desenho e HUD.
- [`simulation.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/game/simulation.kf): movimentação, inimigos, colisão, modo amedrontado, morte/reset e progressão.
- [`draw_ops.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/game/draw_ops.kf): operações de desenho inteiras e simples que separam a simulação/construção da cena dos handles do Canvas.
- [`server.kf`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/src/server/server.kf): rotas REST de integridade/pontuação, arquivos estáticos e `app.listen(8080)`.
- [`assets/web-input.js`](https://github.com/lavdev/kofman/blob/d0d0d1bdb83653d58f9a21e8552775b7d4839699/assets/web-input.js): ponte de teclado para botões escrita manualmente em JS.

Os gráficos usam Canvas2D/DOM do navegador, não SDL, Sokol, raylib ou LWJGL. O processo JVM serve HTTP; ele não renderiza o jogo.A manchete “100% Kof” precisa de uma ressalva: a jogabilidade e o backend são Kof, mas a entrada do navegador e a cola de compilação incluem JS/shell. A linha de base do README é 0.3.2-beta. Ele diz explicitamente que o cliente do jogo não envia pontuações por conta própria; o envio REST é demonstrado separadamente. As afirmações sobre o runtime no navegador presentes no README não foram reproduzidas aqui.

**Lição para o KOOKIE:** simulação pura somada a comandos de desenho extraídos é útil. Um jogo de labirinto a 10 Hz com comandos genéricos de desenho em listas não é um modelo de desempenho para um FPS; aproveite a separação, não as limitações nem as soluções temporárias do compilador.

## Pong, FFI nativa e o que os testes upstream comprovam

[Problema #431](https://github.com/KofLang/Kof4j/issues/431), aberto em 2026-09-17, descreve uma falha inicial de `extern` direto para raylib no Kof 0.4.2-beta. O autor publicou [“pong in kof+raylib”](https://github.com/KofLang/Kof4j/issues/431#issuecomment-5722558116) com um vídeo anexado. Outro comentário descreve uma ponte em C. Nenhum código-fonte independente, versão exata da raylib, licença ou comando de demonstração reproduzível foi encontrado.

O problema foi encerrado em 2026-09-20, após a chegada da FFI nativa escalar. Não repita o relatório original como uma ausência geral atual de FFI nativa. Por outro lado, o encerramento do problema não comprova uma integração gráfica de produção que tenha sido inspecionada.

Detalhe importante da fonte: o [`FfiNativeE2ETest`](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/test/java/dev/kof/compiler/FfiNativeE2ETest.java#L32-L69) upstream define seu **próprio** fixture C `InitWindow`, que imprime os argumentos. Ele testa uma ABI compatível com raylib; não abre uma janela real da raylib.

Nossa consulta separada de versão do SDL3 comprova uma chamada real a uma biblioteca escalar, mas também não cria uma janela. Consulte [RESEARCH_PROBES](RESEARCH_PROBES.md).

## O suporte gráfico oficial não é uma stack pronta para FPS

- Tutorial [`kof.ui` Canvas](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/learn/35-kof-ui.md): renderização DOM/KofJS, com caminhos de UI no-op para JVM/nativo. A fonte confirma `document.createElement("canvas")` / `getContext("2d")` no navegador e métodos de desenho JVM de placeholder.
- [`kof-ui-widgets`](https://github.com/KofLang/kof-ui-widgets/tree/7f359825f86093e98a75c846696e0813301f306c): widgets e gráficos `.kf`; o [documento de destinos](https://github.com/KofLang/kof-ui-widgets/blob/7f359825f86093e98a75c846696e0813301f306c/docs/targets.md) distingue a renderização real no navegador/webview dos no-ops na JVM/nativo.
- [`KofGpu.java`](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofGpu.java): computação matricial Vulkan especializada, não um renderizador de frames. Os auxiliares Vulkan em C e os shaders de computação GLSL não estabelecem um renderizador de jogos nativo.
- [`KofTetris.java`](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofTetris.java) e a [implementação do runtime](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/jvm/JvmStringMiscRuntime.java#L123-L197): jogo de terminal exclusivo da JVM implementado no código-fonte do runtime Java.
- [Registro de aplicações do KofOS](https://github.com/KofLang/KofOS/blob/7a5d40b426e7f7c8708853225a7f94d3ce6f830d/docs/apps_and_modules.md): os nomes de jogos Snake/Tetris/Pac-Man/Pong e outros herdados do VibeOS são explicitamente **não portados**. Não conte planos como jogos em Kof.

## Escopo da pesquisa e evidências negativas

A descoberta utilizou pesquisas gerais na web em inglês/português, pesquisas diretas nas organizações/repositórios do GitHub, fontes candidatas de build/renderização, endpoints de releases e discussões de issues upstream. A pesquisa pública na web, sozinha, não encontrou os dois exemplos mais fortes; as pesquisas nos READMEs do GitHub os encontraram.

Consultas representativas na web pública:

```text
KofLang Kof4j game graphics engine
"KofLang" jogos OR jogo OR motor OR biblioteca OR gráfico
"KofLang" OR "Kof4j" "SDL" OR "raylib" OR "sokol" OR "LWJGL" OR "OpenGL"
"Kof" "linguagem" "jogo" -"King of Fighters" -SNK -mugen
"KofLang" OR "Kof4j" site:itch.io OR site:store.steampowered.com
```

Escopo/resultados da pesquisa pela API do GitHub no momento da pesquisa:

| Consulta de repositório/README | Resultados / interpretação |
|---|---|
| `Kof4j in:readme` | 20, incluindo DoomKof e kofman |
| `KofLang in:readme` | 14, principalmente ferramentas/aplicações e kofman |
| `kof raylib in:readme` | 3; DoomKof e projetos C/C++ não relacionados |
| `Kof4j SDL in:readme`, `KofLang SDL in:readme` | 0 cada |
| Kof4j/KofLang equivalente + LWJGL ou OpenGL | 0 cada |
| `KofLang sokol in:readme` | 0 |

A [API da organização](https://api.github.com/orgs/KofLang/repos?per_page=100&type=all) retornou dez repositórios públicos: Kof4j, koflang.github.io, Kof-Editor, kof-docker-image, kof-agent, kof-ui-widgets, kof-docs, Kof-editor-theme-maker, KofOS, KofWatch. Nenhum mecanismo de jogo oficial dedicado estava presente nessa lista.

Endpoints reproduzíveis: [pesquisa no README do Kof4j](https://api.github.com/search/repositories?q=Kof4j+in%3Areadme&per_page=100), [pesquisa no README do KofLang](https://api.github.com/search/repositories?q=KofLang+in%3Areadme&per_page=100), [pesquisa por raylib](https://api.github.com/search/repositories?q=kof+raylib+in%3Areadme&per_page=100), [releases do DoomKof](https://api.github.com/repos/M-Tesla/DoomKof/releases?per_page=100), [releases do kofman](https://api.github.com/repos/lavdev/kofman/releases?per_page=100).

Falsos positivos excluídos: projetos de King of Fighters (incluindo jogos em C/SDL), nomes de proprietários como K0F, jogos de luta não relacionados em C++/raylib e forks do compilador confundidos com jogos. “Kof” é um termo de pesquisa especialmente ruidoso.

Essas pesquisas não são buscas globais exaustivas e autenticadas de código. Projetos privados/não indexados, nomes diferentes, branches e releases fora do GitHub podem ter sido perdidos. Conclusão correta: **nenhum pacote nativo reutilizável de Kof para SDL/Sokol/LWJGL ou shooter nativo distribuído foi estabelecido dentro deste escopo**, e não “nenhum existe”.

## Consequência para o plano do mecanismo

Use esses projetos como evidência de que Kof pode expressar lógica de jogos e interoperar com gráficos, não como prova de que os problemas de runtime nativo, carregamento de assets e tempo de frame estão resolvidos. Mantenha a lógica do mecanismo de CPU do KOOKIE genuinamente em `.kf`; avalie explicitamente a ABI gráfica restrita do SDL3. Nenhum renderizador de navegador, alternância de runtime Jaylib, Tetris em Java ou mecanismo C oculto deve ser rotulado como uma implementação de shooter nativo totalmente em Kof.## Pesquisa relacionada ao ecossistema Java

[MINECRAFT_SYSTEMS](MINECRAFT_SYSTEMS.md) avalia separadamente o Minecraft Java26.3, suas dependências reais, bibliotecas de mods e alternativas independentes em ECS, GUI, física, som e renderização. Estes não são jogos Kof adicionais. Inclui uma sondagem real da JVM do Kof JOML1.10.9 e um controle de rejeição de importação nativa; a integração de gráficos/áudio/física continua não testada.