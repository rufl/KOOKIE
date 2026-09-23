# Memória de trabalho do KOOKIE

Última pesquisa e instalação de ferramentas: 2026-09-22. Leia [README](README.md) e depois [ENGINE_PLAN](docs/ENGINE_PLAN.md). A implementação G0 agora inclui um contrato verificado de tokens de recursos; a instalação das ferramentas não é a implementação do engine.

## Intenção do usuário

Criar um engine para boomer shooters / looter shooters / ARPG FPS usando **código-fonte nativo Kof `.kf` para toda a lógica portátil do engine/jogo/ferramentas**. Bibliotecas externas de gráficos/plataforma e código indispensável de ABI/shader são exceções, não permissão para construir o engine em outra linguagem. Aproveitar lógica útil de ZYLVE, DINX, CUBSHIP. O trabalho atual iniciou a implementação G0 limitada; a engine nativa de gráficos/áudio ainda não foi implementada.

## Identidades de pesquisa fixadas

- Kof4j: `22a186b9bf9df37c03809ba6ef4af85085386f63`, VERSION `0.4.9-beta`.
- Release executado: `kof-0.4.9-beta-linux-x86_64`, publicado em 2026-09-20; SHA-256 do jar independente `01fbda96e550bd0e115c53769a849284c221d6103aaa0e84bbcc63553fc5d2ca`.
- Kof Editor: `bed6ae7d567b090497a447583a10b8522acaf66a`, VERSION `0.1.4-beta`; agora instalado com um launcher restrito ao projeto e isolado da rede, e verificado visualmente em X11 privado.
- Não inferir o estado do release a partir do README 0.4.0 ou do site 0.4.1. O SHA do código-fonte e o jar do release são identificados separadamente, sem assumir equivalência binária.
- Curso completo: [`lunalully/curso-completo-de-kof@d6fc8318e77f30ab0d6be87055d86a7eb63960d3`](https://github.com/lunalully/curso-completo-de-kof/tree/d6fc8318e77f30ab0d6be87055d86a7eb63960d3), baseline 0.3.7-beta. O snapshot do [portal oficial](https://koflang.github.io/docs) foi gerado em 2026-09-17; várias páginas diferem do código-fonte fixado do compilador. Consulte [KOF_COURSE](docs/KOF_COURSE.md).
- Minecraft Java26.3, lançado em 2026-09-15; SHA-1 exato dos metadados de versão `96c00d95a31328714d3811cfade2804bb050e455`. Usa SDL3/LWJGL3.4.3 e JOML1.10.9; matriz de código-fonte/versão/licença em [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Clones/jars temporários de pesquisa ficaram em `/tmp/kookie-*`; não são dependências do projeto. As evidências duráveis e todas as fontes das sondas estão em [RESEARCH_PROBES](docs/RESEARCH_PROBES.md), [COURSE_PROBES](docs/COURSE_PROBES.md) e [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- A CLI ativa agora é um reparo local das ferramentas compilado a partir do código-fonte, não o release original de pesquisa: SHA-256 do JAR `9a4c133d773058a0ea3b3bf503511439e67bbb8efb80a2d5ab848dbc8274b548`. As fontes persistentes do compilador/editor/cliente, Maven 3.9.16, caminhos de instalação, correções de protocolo e limites de verificação estão documentados em [KOF_EDITOR](docs/KOF_EDITOR.md#local-installation). O OpenJDK 27 existente e os pré-requisitos nativos foram reutilizados. Nenhum reparo do runtime nativo/engine está implícito.

## Decisões propostas

- Linux x86-64 nativo primeiro; oráculo diferencial JVM. Outros SOs/arquiteturas não são prometidos.
- SDL3 + SDL_GPU, primeiro Vulkan/SPIR-V; adaptador ABI escalar verificado e fino até que exista FFI de buffer Kof. SDL3 3.4.16 foi instalado para a sonda de consulta de versão; os gráficos não foram testados.
- Uma thread de simulação Kof; tick de 60 Hz, renderização interpolada independentemente, proposta de recuperação em quatro etapas.
- Arrays de componentes tipados + IDs de geração, colisão cápsula/BVH 3D real, uma única autoridade de dano/morte/recompensa.
- Política de renderização, content cooker, UI do jogo e ferramentas para criadores pertencentes ao Kof; exceção explícita para shaders HLSL/GPU.
- Os sistemas completos de looter/ARPG são o marco G3, não serão abandonados após uma demonstração de boomer-shooter. O fluxo de criação é o G4. Consulte o plano para o escopo/aceitação exatos.
- Nenhum fallback automático para JVM, nenhum engine C oculto, nenhum fork do editor como pré-requisito.

## Fatos a não esquecer

1. As funções usam `Int f(Int x)` / `f(Int x): Int`, **não fun/fn**. `record` e `class X(...)` são imutáveis/no estilo de records; classes mutáveis usam campos + construtor explícito. Não há variáveis ordinárias no nível superior, literais de array nem pressupostos de safe-call/coalesce do Kotlin.
2. Módulos/imports `.kf` funcionam. A importação de diretórios foi medida na JVM/nativo; `run` coleta irmãos e rejeita várias funções `main()` (`PKG002`). Escopos de entrada de aplicações são separados.
3. O `extern` nativo **escalar** funciona agora; as antigas afirmações gerais de que “FFI nativo não é suportado” estão desatualizadas. sqrt → `3.0`, SDL_GetVersion → `3004016` foram medidos em ambos os alvos.
4. `extern upload(Float[])` → `FFI001` em ambos os alvos medidos. Structs/ponteiros/out-buffers/variádicos e callbacks nativos estão fora do gate escalar suportado. IDs inteiros de recursos devem ser tokens reais de registro do adaptador, não conversões de ponteiros.
5. O caminho automático do coletor x86 nativo é controlado por `kof_spawn_count == 0` **cumulativo**. Aguardar uma tarefa não o reabre. Não contornar usando GC manual inseguro. Threads de bibliotecas nunca devem manter/chamar estado do heap Kof.
6. A execução nativa empacotada avisou que o pruning do runtime não consegue encontrar `NativeRuntime.java` fora do módulo do compilador; o fallback de runtime completo foi executado. As pequenas alegações de tamanho binário do upstream não foram verificadas para este caminho de release.
7. A otimização do compilador nativo é limitada; o JIT da JVM pode superá-la. Nenhuma preparação de FPS/memória/gráficos do engine foi medida.
8. `kof.gpu` é computação matricial especializada, não um engine de gráficos 3D. O Kof Canvas é orientado a navegador; janelas nativas WebKitGTK/Jaylib não implicam execução em ELF nativo.
9. O teste FFI `InitWindow` com formato raylib do upstream usa um fixture C que imprime, não uma janela real. Nossa consulta de versão SDL igualmente prova apenas sua chamada exata.
10. As sondas orientadas pelo curso passaram nos exemplos de overload/default/captura aninhada, arrays 2D de Int, getters diretos de records de ponto flutuante, matemática com Double, ambas as ordens de argumentos de reduce e valores zero versus ausentes de mapas na JVM/nativo.
11. `File.writeBytes/readBytes/readRange` binário preservou `00 7f 80 ff` em ambos. Isso prova um pequeno caminho de API de instância, não FFI em massa, comportamento com arquivos grandes ou durabilidade de salvamento atômico.
12. O JSON nativo de records mistos de Int/Double/String estava errado: codificou 1.25 como 0.0, decodificou Double incorreto/String vazia; o round-trip na JVM passou. Condicione a persistência/conteúdo JSON nativos ao reparo e a uma prova específica do schema.
13. O `split` nativo não é uma divisão por regex da JVM: o pipe escapado produziu um elemento em vez de três. Evite presumir semântica compartilhada do parser.
14. Defeito crítico no handler nativo: após um try/catch normal, uma asserção falha posterior reentrou nesse catch e saiu com 0. A redução de código-fonte salta além de `KofTryEnd`. Uma asserção false simples falha corretamente. Não institucionalizar uma solução alternativa de fluxo de controle; corrigir/revalidar o compilador antes de depender de limpeza/exceções/testes.
15. Erros de limites nativos terminam sem catch/finally; limpeza explícita de throw/return de String passou nas sondas mais restritas. Validar índices e entradas do adaptador antes do acesso; asserções são throws capturáveis da linguagem, não um canal independente de falha de testes.
16. JOML1.10.9 do Minecraft26.3 funcionou com `--deps` da JVM Kof: comprimento/produto escalar de vetor e translação de matriz imprimiram `5.0,25.0,5.0,4.0`. O mesmo código-fonte/nativo rejeitou ambas as importações Java com `PKG006`. Isso prova o caminho restrito de matemática Java, não JNI/gráficos nem uso de JAR nativo.
17. Snapshots broad-phase autoritativos agora atravessam uma fila de transporte de capacidade fixa e validada; overflow rejeita sem descartar payloads enfileirados, e dequeue/apply atualiza a geometria do cliente com guardas de sequência.
18. O smoke GPU headless agora cobre profundidade de sobreposição dois e recriação limpa do dispositivo com reconstrução de recursos em cache; callbacks reais de perda e retirement continuam não implementados.
19. O transporte nativo UDP usa framing SipHash autenticado sobre um payload
fixo de 78 palavras, exige provisionamento explícito de chave não nula antes da
abertura e valida protocolo/tamanho/sequência com preservação de inteiros com
sinal e timeout de recebimento de 1.000 ms; gestão de chaves de produção ainda
não foi implementada.
20. A recuperação GPU agora expõe transições unavailable/ready/lost/failed e rejeita recuperação sem dispositivo headless ativo; a notificação de perda é um marcador explícito da sonda, não um callback SDL de perda de dispositivo.
21. Uma janela GPU reivindicada agora exige formato de swapchain válido pela sonda de capacidades de apresentação; o caminho Xvfb ainda não consegue reivindicar apresentação DRI3.
22. O transporte nativo pode ligar sockets UDP pareados no localhost, exige uma
chave SipHash de teste e um peer IPv4 antes de trocar frames autenticados, e
limpa o material da chave ao fechar; gestão de chaves de produção ainda não foi
implementada.
23. O relatório de capacidades de recuperação GPU é sensível ao estado: ready expõe reopen limpo e o marcador explícito de perda, lost expõe apenas reopen, e unavailable/failed não expõem capacidades; a SDL3 instalada não expõe callback de perda de dispositivo.
24. `RemoteSessionEndpoint` valida IPv4/porta e chaves SipHash não nulas, congela alterações de peer/chave enquanto ativo, permite troca de chave apenas inativo e está ligado à fronteira de chave via ambiente e a um smoke de peer UDP externo real; orquestração de sessão e armazenamento de segredos de produção ainda não foram implementados.
25. `RemoteSessionLink` bloqueia snapshots broad-phase até a ativação do endpoint e exige sequências de envio/recebimento estritamente crescentes; a sonda nativa isolada envia e aplica um snapshot através do link, enquanto a orquestração em loop de sessão real ainda não foi implementada.

## Cuidados do editor
Consulte [KOF_EDITOR](docs/KOF_EDITOR.md). A UI interativa é substancialmente implementada em JS dentro de `.kf`; trata-se de um scanner independente, sem reutilização do frontend do compilador. A execução copia o arquivo ativo para uma raiz temporária fixa e fixa a JVM. Nenhuma integração real de cliente LSP/DAP foi encontrada. Os endpoints do sistema de arquivos/shell do host são irrestritos e não autenticados.

Com o compilador inspecionado, o código-fonte `web.sh` omite o host, e o handler legado atende em `0.0.0.0` por padrão. O `--host 127.0.0.1` explícito se aplica ao **modo de handler legado**, não ao modo `web.app()+main`; o loopback ainda não constitui autorização/proteção de Origin. Prefira o uso em um scratch isolado, não as ações de Git/Run do monorepo. O scanner nativo antigo R1 está explicitamente encerrado no próprio registro histórico do editor.

## Evidências de jogos

- **DoomKof:** raycaster publicado com código-fonte, gameplay em `.kf`; JVM desktop Jaylib JNI 5.5.0-2/raylib, navegador alternativo Canvas+JS. A licença do código-fonte não foi estabelecida. Nenhuma versão nativa-ELF verificada.
- **Byte Eater / kofman:** jogo de navegador MIT publicado com código-fonte, KofJS/kof.ui Canvas, backend web JVM, ponte de teclado em JS implementada manualmente.
- **Pong:** demo de raylib reportada/com vídeo vinculado no issue #431 do Kof4j; o código-fonte do jogo e o destino exato de execução não foram verificados.
- O Tetris integrado é um jogo de terminal em runtime Java; a lista de jogos do KofOS contém planos não portados.
- A pesquisa não estabeleceu a existência de um shooter Kof nativo distribuído nem de um pacote de binding SDL/Sokol pronto. Esta é uma evidência negativa delimitada, não uma prova de que nada exista.

## Mapa de reutilização

- DINX: intenção/política de salto do controlador, handles seguros para geração, identidades/ordem exatas dos lotes de renderização, admissão por revisão/presença de vizinhos.
- ZYLVE: identidade de itens, transações atômicas de item/moeda/RNG, semântica de habilidades/status, bordas de entrada em passo fixo, fila de renderização/hash espacial, publicação em estágios de edição ao vivo.
- CUBSHIP: geometria SAT isolada, contratos de transição de arma/dano, busca de IA limitada e salvamentos seccionados.
- **Não** herdar “sweep” somente de endpoint, colisão do jogador por raio na cintura, pools de loot pequenos fixos/descartes silenciosos, autoridades de armas duplicadas, IDs ECS brutos nos salvamentos, reprodução de eventos rotulada incorretamente como replay determinístico ou inspetores de corpus rotulados incorretamente como cozinheiros de mapas.
- DINX MIT; aviso privado/interno para o jogo completo do ZYLVE; a alegação MIT do README do CUBSHIP não conta com um empacotamento completo dos avisos inspecionados. A permissão do usuário não libera ativos de terceiros. Registre a revisão/hash do código-fonte e as licenças no momento da portabilidade.
- Minecraft: não é um ECS arquetípico convencional. Reutilizar a separação entre definição/instância, patches de substituição de itens, codecs validados, snapshots de extração e ciclos de vida de vozes de áudio. Priorizar subconjuntos MIT de JOML/Brigadier, contratos de armazenamento de Artemis/Ashley, layout do owo e ciclos de vida de instâncias do Flywheel; consulte [MINECRAFT_SYSTEMS](docs/MINECRAFT_SYSTEMS.md).
- Conjunto de bibliotecas recomendado: SDL3/SDL_GPU; SDL_shadercross/DXC offline; OpenAL Soft para áudio FPS de produção (SDL3_mixer é a alternativa básico-espacial); SDL3_image para decodificação de imagens; FreeType/HarfBuzz para serviços de texto; zstd para pacotes preparados. G0 continua sendo somente SDL, com áudio enfileirado. Os limites completos, a disponibilidade local, as licenças e os gates de adoção estão em [ENGINE_PLAN](docs/ENGINE_PLAN.md#recommended-library-set-2026-09-22).
- A física do Jolt, a navegação Recast/Detour e as UIs RmlUi/ImGui continuam sendo alternativas condicionais de subsistemas estrangeiros que exigem aprovação explícita de propriedade, não dependências adotadas. Nenhuma portabilidade integral de mods. Sodium PolyForm Shield, Physics Mod All Rights Reserved e os componentes fechados do VSCore/Krunch não são fontes permissivas para reutilização.

## Próxima ação e limite de comprovação

A prova GPU do G0 aceita um quad texturizado SDL_GPU offscreen indexado
isolado, uploads explícitos de buffers de vértices/índices, submissão de draw
SPIR-V, recursos GPU em cache por dispositivo e telemetria de espera da fence
através de um render node. O smoke mais recente mediu 1675 microssegundos para
três draws contra o orçamento declarado de frame a 60 Hz de 16.667
microssegundos em `renderD128`, incluindo uma amostra de 527 microssegundos de
espera da fence. Uma sonda de sobreposição submeteu quatro frames em dois slots
de destino, aposentou todas as fences e observou profundidade máxima em voo de
dois. A recriação limpa do dispositivo reconstruiu os recursos em cache e
concluiu um draw após a recuperação. O caminho de janela ainda reporta
`gpu-unavailable` porque Xvfb não oferece apresentação DRI3; uma sonda de
capacidade informa o formato de swapchain e os modos de apresentação quando um
dispositivo de janela pode ser reivindicado. O G1 agora também possui staging
limitado de frame com seis vértices, consultas determinísticas limitadas de
coleções/BVH de triângulos com remoção/rebuild e revisões de geometria,
traversal autoritativo de slide/step de cápsula sobre oito obstáculos limitados
ordenados, operações de limpeza/reconfiguração, snapshots broad-phase
transportados por fila de capacidade fixa com dequeue/apply no cliente e
guardas de sequência, rejeição de consultas obsoletas e admissão de movimento
espacial combinando colisões de cápsula e broad-phase. O adaptador também possui
uma sonda UDP nativa de peer entre sockets localhost pareados com um
`RemoteSessionEndpoint` validado, abertura nativa atômica de peer IPv4, endereço/
porta configurável e chaves SipHash de teste, validação de sequência/tamanho,
timeout de recebimento de 1.000 ms, além de estados explícitos de recuperação GPU
e bitmask de capacidades para reopen limpo/marcador de perda. Em seguida:
adicionar apresentação isolada compatível com DRI3, ligar `RemoteSessionLink` a um
loop real de rede/sessão e adicionar armazenamento/rotação de segredos de
produção, adicionar callbacks/retirement reais para perda do dispositivo e
reexecutar o reproduzível de exceção nativa após upgrade do compilador. O defeito
do handler de exceções nativas continua sendo um gate do compilador.

Evidências de pesquisa anteriores: sondas originais de core/import/FFI escalar,
18 programas orientados pelo curso (36 execuções, duas verificações) e o par
de sucesso da JVM/rejeição de importação nativa do JOML. As fontes/resultados
completos estão nos documentos de pesquisa vinculados. Essas sondas de
pesquisa foram somente para JVM/nativo x86, sem jogos/editor/servidor ou
gráficos iniciados. A verificação de instalação posterior exercitou a CLI do
compilador, LSP/DAP e o editor/servidor isolado real; ela não verificou a pilha
gráfica do engine nem executou uma suíte completa.

Todas as verificações gráficas usam `overzeer-isolated-display` ou equivalente revisado, com sockets privados, timeout e limpeza de processos; nunca o desktop do desenvolvedor. A matriz completa somente na etapa final anterior ao commit, com permissão do usuário. Os documentos de pesquisa e as ferramentas/configurações locais foram entregues; nenhum código-fonte/ativo de engine/jogo irmão foi modificado ou copiado.