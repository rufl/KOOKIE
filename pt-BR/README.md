# KOOKIE
[English](../README.md)

As páginas e a documentação pública são mantidas em português brasileiro e inglês. Mantenha as alterações correspondentes sincronizadas em `pt-BR/`.


Pesquisa e planejamento para uma **engine de tiro 3D nativa e focada em Kof**: boomer shooters, looter shooters e ARPG FPS.

**Estado atual:** a implementação G0 foi iniciada. Um núcleo Kof modular mínimo,
um codec de teste do envelope de sessão, um registry verificado de tokens de
recursos, um contrato escalar de ciclo de vida SDL, estado limitado de
janela/áudio e um adaptador nativo SDL estreito existem. As verificações do
compilador e os testes de contrato Kof passam na JVM/nativo. O smoke nativo de
janela/áudio está conectado, mas sua execução em display isolado continua sob
gate de pressão; SDL_GPU, renderização texturizada e transporte multiplayer não
foram implementados.

## Direção proposta

- Toda a lógica de CPU pertencente à engine e o comportamento de autoria/cozimento em **`.kf`**.
- Runtime inicial: **Kof nativo Linux x86-64**, com a JVM usada como alvo de comparação durante o desenvolvimento.
- Biblioteca preferida de plataforma/renderização: **SDL3 + SDL_GPU**, primeiro Vulkan/SPIR-V.
- Não-Kof limitado a bibliotecas externas indispensáveis, pequeno marshaling de ABI, shaders de GPU e um glue mínimo de ferramentas/bootstrap. Nenhuma engine C/Java/Rust/Zig oculta.
- Aproveitar algoritmos e contratos de DINX, ZYLVE e CUBSHIP; não transplantar suas engines nem presumir direitos sobre seus assets.

Esta é uma stack proposta, não uma binding gráfica comprovada. A FFI escalar de Kof funciona; limitações de buffer/struct/pointer, correção dos manipuladores de exceção e comportamento do coletor nativo precisam ser resolvidos antes de assumir um workload sustentado de shooter.

## Documentação

| Documento | Finalidade |
|---|---|
| [MEMORY.md](MEMORY.md) | Referência curta para retomada: decisões, versões, ressalvas e próxima ação |
| [Linguagem Kof](docs/KOF_LANGUAGE.md) | Sintaxe, tipos, módulos, alvos, ferramentas, FFI, GC, desempenho e licenciamento |
| [Editor Kof](docs/KOF_EDITOR.md) | Arquitetura/workflows reais, defeitos atuais, limitações históricas e limite de segurança |
| [Jogos e gráficos](docs/GAME_ECOSYSTEM.md) | DoomKof, Byte Eater, Pong relatado, bibliotecas reais e limites da pesquisa |
| [Sistemas do Minecraft](docs/MINECRAFT_SYSTEMS.md) | Stack Java26.3 atual; reutilização de ECS/UI/física/áudio/renderização, licenças, limites do porte nativo e interop JOML medida |
| [Reutilização do monorepo](docs/MONOREPO_REUSE.md) | Caminhos de origem específicos, invariantes reutilizáveis, não-exemplos e ressalvas de propriedade |
| [Sondas executadas](docs/RESEARCH_PROBES.md) | Fontes `.kf` pequenas completas, comandos, resultados, falhas e limites das provas |
| [Análise aprofundada do curso](docs/KOF_COURSE.md) | Cobertura do curso/documentação oficial, divergência de versões, algoritmos, ferramentas e implicações para a engine |
| [Sondas orientadas pelo curso](docs/COURSE_PROBES.md) | 18 programas completos e resultados medidos na JVM/nativo, incluindo falhas de serialização e exceção |
| [Plano da engine](docs/ENGINE_PLAN.md) | Arquitetura, decisão de biblioteca, regras de propriedade, sistemas do gênero, pipeline de criação e gates de milestone |
| [Tokens de recursos G0](docs/G0_RESOURCE_TOKENS.md) | Contrato verificado de ciclo de vida por slot/geração/tipo e prova de regressão |
| [Backlog G0](docs/G0_BACKLOG.md) | Sequência ativa de implementação limitada e escopo adiado |
| [Adaptador escalar G0](docs/G0_SCALAR_ADAPTER.md) | Contratos escalares de ciclo SDL e de estado Kof de janela/áudio com limites de prova |

[Documentação em inglês](../docs/) espelha todos os documentos em português.


## Descobertas que mudam o plano

1. **Divergência de versões:** o compilador/release examinado é 0.4.9-beta, enquanto o README/site obtidos anunciam versões mais antigas. Fixe a origem e o executável separadamente.
2. **Existem jogos:** [DoomKof](https://github.com/M-Tesla/DoomKof) possui gameplay em `.kf` com JVM Jaylib/raylib ou Canvas do navegador; [Byte Eater](https://github.com/lavdev/kofman) usa KofJS/Canvas. Nenhum deles estabelece um FPS nativo-ELF distribuído.
3. **Interop nativa real:** nossas sondas `.kf` chamaram libm e SDL3 instalado na JVM/nativo x86-64. A FFI de array de float foi corretamente rejeitada com `FFI001`.
4. **Risco do runtime nativo:** o gate atual de GC automático fecha após `spawn` de Kof. Comece com uma única thread; pré-alocação é útil, mas não é prova de estabilidade em execução prolongada.
5. **O editor não é uma IDE nativa totalmente em Kof:** um comportamento interativo substancial é escrito manualmente em JS servido a partir de strings `.kf`. A execução copia um documento e fixa a JVM; as rotas privilegiadas do host não têm autenticação. Use a CLI do compilador e um editor com capacidade de LSP configurado separadamente para o trabalho na engine.
6. **Verificações mais profundas do compilador encontraram bloqueadores:** o JSON de registro fracionário nativo falhou; uma asserção após um try/catch concluído normalmente reentrou no manipulador antigo e saiu falsamente com sucesso. Não confie na saída “PASS” do curso nem em afirmações gerais de paridade entre alvos.
7. **A reutilização do Minecraft é seletiva:** Java26.3 agora usa SDL3, mas seus mods não são bibliotecas de engine independentes. JOML1.10.9 foi executado a partir da JVM Kof com `--deps`; o nativo rejeitou suas importações Java. Prefira portes limitados de matemática/comandos e contratos de dados/ciclo de vida; Jolt, RmlUi ou ImGui exigiriam escolhas explícitas de propriedade de subsistemas estrangeiros.

## Ferramentas locais instaladas

`kof`, `mvn` e `kof-editor` estão no PATH do usuário. O Kof4j 0.4.9-beta possui uma
correção local fixada de LSP/DAP; o Kof Editor 0.1.4-beta usa um iniciador restrito ao projeto e
à rede privada. O MrCode existente possui um cliente real de linguagem Kof, tarefas de formatação e CLI
e configurações de depuração JVM/nativa. Recarregue sua janela após a instalação.
Consulte [instalação, comandos, segurança e limites das provas](docs/KOF_EDITOR.md#local-installation).

## Verificação antes do push

Execute o mesmo gate localmente e nas GitHub Actions:

```bash
bash scripts/verify.sh
```
Ele executa o linter das fontes Kof, diagnósticos do LSP, verificações do
compilador JVM/nativo, testes de regressão nomeados, smoke de runtime
JVM/nativo, o smoke opcional do adaptador SDL nativo quando dependências e
pressão permitirem e builds JVM/nativo. Consulte [CONTRIBUTING.md](CONTRIBUTING.md)
para o contrato.
O smoke do adaptador usa `SDL_VIDEODRIVER=offscreen` por padrão e passa o
primeiro node `/dev/dri/renderD*` disponível ao wrapper isolado. Sobrescreva
com `KOOKIE_RENDER_NODE=/dev/dri/renderD129`; use
`KOOKIE_SDL_VIDEO_DRIVER=x11` somente ao testar um caminho de janela
apresentável.

Essa configuração não resolve os bloqueadores do runtime nativo abaixo.

## Próximo incremento

A viabilidade nativa G0 está implementada. O smoke nativo do adaptador em
display isolado agora aceita ciclo de vida da janela oculta, flattening de
resize/focus, áudio dummy, teardown de tokens obsoletos, limpeza de processos,
um quad texturizado SDL_GPU offscreen indexado com uploads explícitos de
buffers de vértices/índices, recursos GPU em cache por dispositivo e
telemetria de espera da fence dentro do orçamento declarado de frame de 16.667
microssegundos; a amostra mais recente mediu 1675 microssegundos para três
draws em `renderD128`, incluindo uma amostra de 527 microssegundos de espera da
fence. Uma sonda de sobreposição submeteu quatro frames em dois slots de
destino, aposentou todas as fences e observou profundidade máxima em voo de
dois. A recriação limpa do dispositivo reconstruiu os recursos em cache e
concluiu um draw após a recuperação. A apresentação em janela ainda reporta
`gpu-unavailable` porque o caminho Xvfb não oferece suporte de apresentação
DRI3; uma sonda de capacidade informa o formato de swapchain e os modos de
apresentação quando um dispositivo de janela pode ser reivindicado. G1 agora
inclui autoridade fixed-step, comandos de input limitados e transições de
borda, admissão de dois clientes em loopback, rejeição de input obsoleto por
cliente, validação de sequência de snapshots, movimento autoritativo limitado,
clamp de câmera/input, storage limitado de componentes inteiros, histórico
limitado de snapshots com interpolação, replay limitado de inputs de predição,
consultas escalares de colisão, sweeps inteiros de segmento e triângulo 3D,
movimento de cápsula expandido pelo raio, consultas determinísticas limitadas
de coleções/BVH de triângulos com remoção/rebuild e revisões de geometria,
obstáculos de step de cápsula ordenados em oito slots com operações de
sequência, uma fila de transporte broad-phase de capacidade fixa com rejeição
de overflow, rejeição de consultas obsoletas e admissão de movimento espacial
combinando colisões de cápsula e broad-phase. O adaptador também possui uma
sonda UDP nativa de peer entre sockets localhost pareados com configuração
`RemoteSessionEndpoint` validada para endereço/porta IPv4, framing SipHash
autenticado, provisionamento explícito de chave não nula antes da abertura via
`KOOKIE_TRANSPORT_KEY_HEX` ou um `KOOKIE_TRANSPORT_KEY_FILE` em modo 0600 ou
mais restritivo, rotação explícita de chave do transporte fechado, congelamento
recebimento de 1.000 ms. A sonda da sessão autoritativa conduz três ticks
broad-phase autenticados, e eventos SDL de reset/perda aposentam recursos GPU
pelo event pump antes da recuperação. Um caminho de janela DRI3 protegido por
capacidade agora renderiza um frame de swapchain e captura um checksum de
screenshot quando a apresentação está disponível. Em seguida: executar esse
caminho em um host isolado compatível com apresentação e reexecutar o
reproduzível de exceção nativa após upgrade do compilador. Use o wrapper
descartável de display isolado do repositório para verificação gráfica.
Não crie primeiro um grande esqueleto de engine não testado.

## Procedência

Pesquisa registrada em 2026-09-22. Os links primários, SHAs upstream fixados, hash do executável e as distinções entre afirmações medidas/derivadas da origem/propostas estão nos documentos. Árvores irmãs foram inspecionadas somente para leitura e podem mudar. Nenhuma licença de origem/asset foi atribuída ou alterada.