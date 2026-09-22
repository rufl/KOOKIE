# Mapa de reutilização: ZYLVE, DINX e CUBSHIP

Data da pesquisa: 2026-09-22. Inspeção somente leitura de árvores de trabalho irmãs ativas; sem alterações no código-fonte, compilações, testes ou execuções gráficas. Outros trabalhos estão ativos nesses projetos, portanto os intervalos de linhas são um instantâneo de localização, não uma versão fixada. Transfira **comportamento e invariantes para `.kf`**, não engines Zig/Rust inteiras nem seus objetos ABI.

## Divisão de responsabilidades recomendada

| Projeto de origem | Melhores lições para KOOKIE | Não importar por inteiro |
|---|---|---|
| DINX | Intenção de entrada de shooter, política de pulo, handles de recursos nativos, agrupamento de renderização, publicação de trabalho segura contra revisões obsoletas | Wrappers Zig de Flecs/Sokol, coordenador gigante da engine, auxiliares incompletos de colisão/corpus |
| ZYLVE | Identidade de itens de ARPG, inventário/progressão atômicos, bordas de entrada em passo fixo, ordenação de renderização, preparação de edição ao vivo | Balanceamento específico do jogo, limites minúsculos de coleta, assets proprietários/de terceiros, arquivos gigantes de runtime |
| CUBSHIP | Kernels de geometria, contratos de disparo/dano, buscas de IA limitadas, saves seccionados | Agendamento/posse de entidades do Bevy, serialização Rust, supostas garantias de replay/física não estabelecidas pelo código-fonte |

## DINX

### D1. Intenção do controlador e política de pulo — primeiro marco do shooter

Fonte: [player_controller_runtime.zig](../../DINX/src/core/player_controller_runtime.zig), especialmente `PlayerControllerBoundaryPolicy`, `shouldCoyoteJump`, `JumpAssist`, `stepBox3DPlayerIntent`, `accelerateHorizontal` (aproximadamente linhas 19–116, 329–489).

Preservar:

- Normalização da entrada e política explícita de aceleração/frenagem.
- O pulo coyote exige um novo pressionamento dentro de uma janela de tempo finita e não negativa.
- O pressionamento armazenado é consumido uma vez; a liberação do pulo reduz a velocidade para cima, não durante a queda.
- Posse distinta da intenção do controlador e da resolução de colisão.

Não copie o ajuste cegamente: a aceleração se aproxima de um vetor de velocidade-alvo, em vez da aceleração aérea baseada em projeção do Quake. KOOKIE precisa de perfis de movimento explícitos por jogo.

[engine.zig](../../DINX/src/core/engine.zig), por volta de 7888–7918, tem um **subloop de física** com acumulador de 60 Hz, limite de recuperação de dois passos, contabilização do tempo descartado e dívida fracionária. Isso não é evidência de que todo sistema de gameplay do DINX use passo fixo. Escolha uma política de relógio para KOOKIE, em vez de combinar políticas incompatíveis dos projetos irmãos.

### D2. Handles e ciclos de vida de recursos — primeiro marco de ABI

[physics_backend_runtime.zig](../../DINX/src/core/physics_backend_runtime.zig), `HandleIndex`, por volta de 707–770: busca `(id,generation)`, sentinela slot+1, endereçamento aberto limitado, remoção por deslocamento para trás em vez do acúmulo de tombstones. A tabela usa mascaramento de potência de dois; preserve essa invariante se for transferida.

Útil para tokens de recursos SDL e referências a entidades da engine. A implementação não é um alocador ECS/free-list denso pronto. Kof deve ser o proprietário do armazenamento de seus componentes; ponteiros nativos permanecem sob posse do adaptador.

### D3. Extração e agrupamento de renderização — após os primeiros desenhos corretos

[actor_batch.zig](../../DINX/src/render/actor_batch.zig), `Runtime`, `submit`, `flush`, por volta de 25–81 e 326–423:

- A identidade exata da geometria permanece fixada durante um frame; buffers deformáveis são atualizados somente quando é seguro.
- A compatibilidade do lote inclui geometria/modo de índice/visão/sampler/iluminação não instanciada.
- Barreiras de sobreposição projetada preservam a ordem quando o agrupamento poderia alterar o comportamento de profundidade.
- A exaustão do buffer de instâncias pode recair para desenhos imediatos, em vez de descartar silenciosamente atores aceitos.

Transfira esses contratos, não as structs de Sokol/Zig. Buscas pareadas limitadas não devem crescer até se tornarem um renderizador quadrático sem limite. [ecs_query_runtime.zig](../../DINX/src/core/ecs_query_runtime.zig) também ilustra ciclos de vida de consultas vinculados ao mundo e writeback pertencente/compartilhado, mas é específico do Flecs, não uma implementação ECS independente.

### D4. Rejeição de resultados obsoletos e persistência — marco de escala

- [terrain_streaming_task.zig](../../DINX/src/world/terrain_streaming_task.zig), `Task`/`Demand.matches`, por volta de 9–47, 99–133: admissão por seed/configuração/época/distância/camada; resultado pertencente sem mutação do mundo ativo.
- [meshing_snapshot.zig](../../DINX/src/world/meshing_snapshot.zig), por volta de 143–164, 284–302: snapshot pertencente do centro/emenda; as épocas do centro e dos vizinhos **e a presença** determinam a validade. Carregar ou expulsar um vizinho invalida emendas obsoletas mesmo sem uma edição.
- [region_store.zig](../../DINX/src/world/region_store.zig), por volta de 22–45, 93–103, 416–459: arena somente de acréscimo, sincronização do payload antes da publicação do índice, renomeação atômica do manifesto, compactação/agrupamento limitados. Seu contrato de durabilidade é especificamente um comportamento POSIX local, não automaticamente multiplataforma.
- [native_tooling.zig](../../DINX/src/core/native_tooling.zig), `JobRequest`/`JobResult`, por volta de 239–325: solicitação de operação versionada, autoridade sobre o executável pertencente à configuração de um provedor confiável, resultados terminais explícitos, metadados de formato/tamanho/hash do artefato. Um schema não é, por si só, um sandbox nem uma prova de que o hash foi verificado.

Inicialmente, mantenha KOOKIE em uma única thread; esses são modelos de posse/revisão para trabalhos futuros, **não um motivo para habilitar o spawn nativo do Kof devido à sua restrição de GC**.

### Não confunda estes itens com sistemas concluídos

- [physics.zig](../../DINX/src/core/physics.zig), `sweepAabbAgainstVoxel` por volta de 65–113, retorna imediatamente se o destino não se sobrepõe. **[INFERENCE]** uma passagem rápida pode não ser detectada; este não é o solver contínuo de cápsula necessário.
- [ugc/dinxmap.zig](../../DINX/src/ugc/dinxmap.zig), por volta de 1563–1633, conta construções de fixtures legadas. A ferramenta de corpus do Quake verifica intervalos/estatísticas de lumps BSP, não um compilador completo de brushes junto com um loader de runtime. Não afirme que existe um pipeline Quake pronto com base em uma verificação de corpus.

## ZYLVE

### Z1. Identidade de itens e transações atômicas — marco central de looter/ARPG

Fontes: [item_types.zig](../../ZYLVE/src/item_types.zig), `Instance`, composição e visibilidade de atributos (aproximadamente 307–550); [inventory.zig](../../ZYLVE/src/inventory.zig), identidade/posse (85–134, 165–257); [item_progression.zig](../../ZYLVE/src/item_progression.zig), resultados de transações (70–264); [arpg_progression.zig](../../ZYLVE/src/arpg_progression.zig), armazenamento/habilidades/XP/aflições.- Identidade estável da instância separada da definição do item, inclusive após movimentações entre equipamento e inventário.
- Resultados de falha explícitos; validação antes da mutação de item/moeda/materiais/RNG.
- O estágio de aposta agrupa inventário e RNG/moeda, realizando o commit apenas quando o item cabe. Falhas de capacidade não devem consumir dinheiro nem avançar o estado aleatório.
- A visibilidade das estatísticas de itens ocultos/não identificados/quebrados é explícita, não vazada acidentalmente pela UI de comparação.
- A ativação de habilidades valida aprendizado/configuração de habilidades/mana/recarga, depois confirma custos e recarga em conjunto.
- As regras de duração/renovação de status e os limites de resistência são políticas nomeadas.

Adapte em vez de transplantar: o KOOKIE precisa de armas de fogo orientadas por definição, conjuntos de afixos/faixas de raridade e perfis de gênero. Copiar todo o inventário antes do commit é barato para o inventário pequeno e limitado do ZYLVE; para armazenamentos maiores, prepare apenas os espaços afetados e reserve capacidade, preservando a semântica atômica.

Limitação importante: [world3d_simulation.zig](../../ZYLVE/src/world3d_simulation.zig), `dropEnemyLoot` em torno de 4217–4290, usa mapeamentos fixos de níveis/afixos e um pequeno conjunto de coleta. Isso **não** é um gerador geral de saque rolado com múltiplos afixos. Algumas falhas de saque extra são ignoradas. Não herde a perda silenciosa nem suas tabelas de balanceamento. O código antigo de encaixes aceita menos tipos de gemas que o esquema; escolha uma autoridade coerente, não os dois caminhos.

### Z2. Entrada em passo fixo e separação de eventos — primeiro marco de jogabilidade

[runtime3d.zig](../../ZYLVE/src/runtime3d.zig), em torno de 5480–5600:

- Pulsos de 1/60 de segundo, recuperação atrasada limitada, limpeza da dívida durante pausa/estúdio/congelamento.
- Bordas de salto/avanço rápido/recarga/interação/habilidade de disparo único consumidas somente depois que um passo de simulação realmente acontece.
- Movimento/disparo mantidos disponíveis para os passos subsequentes.
- Os resultados da simulação precedem o consumo da apresentação/eventos.

[world3d_simulation.zig](../../ZYLVE/src/world3d_simulation.zig), `damageEnemyOwned` em torno de 1381–1435, ilustra um proprietário compartilhado de dano/recompensa. O KOOKIE deve impor uma única transição vivo→morto, um único resultado de saque/XP e efeitos cosméticos separados. Não transporte comportamentos específicos de chefes do jogo para um serviço genérico de dano.

### Z3. Núcleos pequenos e conscientes de alocação — primeiros ports

- [render_queue.zig](../../ZYLVE/src/render_queue.zig), linhas 1–99: metadados de passe/estado/profundidade; agrupamento opaco e ordenação transparente do mais distante para o mais próximo; desempate determinístico; estouro explícito. Copie os contratos de ordenação, não um limite de 512 entradas nem uma política de descarte silencioso.
- [spatial_hash.zig](../../ZYLVE/src/spatial_hash.zig), linhas 1–115: broadphase limitado, baseado em arrays, com saída pertencente ao chamador. Os resultados são células candidatas, **não interseções exatas com o raio**. Respeite os limites de coordenadas e a inserção única; sempre aplique uma narrow phase.

### Z4. Edição ao vivo, pacotes e salvamentos — marco de autoria

- [terrain/live_edit.zig](../../ZYLVE/src/terrain/live_edit.zig), `Session.stage`/`commit` em torno de 244–303: prepare todo o trabalho sujeito a falhas antes da publicação, rejeite revisões obsoletas e consumo duplicado, confirme sem alocação.
- [runtime_map_domain.zig](../../ZYLVE/src/runtime_map_domain.zig), em torno de 227–281: produtos dependentes publicados juntos no limite do frame; tokens de sessão/coordenador rejeitam resultados de sessões anteriores.
- [content_package.zig](../../ZYLVE/src/content_package.zig), em torno de 36–106: envelope/faixas/caminhos limitados, rejeição de duplicatas, verificações de corrupção e admissão somente de dados. Sua soma de verificação não é autenticação criptográfica.
- [savegame.zig](../../ZYLVE/src/savegame.zig), em torno de 12–25, 85–155: campos versionados explícitos, arquivo de preparação, sincronização e então renomeação. Não copie memória bruta nem quantidades fixas de mundo; a durabilidade do diretório ainda precisa de comprovação por plataforma.

JSONL de telemetria é diagnóstico, não replay determinístico. O gravador do KOOKIE precisa de comandos de tick, fluxos RNG explícitos, identidades de conteúdo/build e checkpoints.

## CUBSHIP

### C1. Núcleos de geometria — uso seletivo do cooker/referência

[cubout-core/src/triangles.rs](../../CUBSHIP/cubout-core/src/triangles.rs), `triangle_aabb_intersection` e `voxelize_surface` (18–187): geometria SAT, limites finitos de entrada/buffer, resolução/trabalho de voxel limitados e amostragem de cores/texturas baricêntrica. O cabeçalho afirma explicitamente **somente superfície**, sem preenchimento interior, skins ou importação de animação.

Transporte a matemática diretamente para `.kf` quando for útil. `glam`, `serde_json`, `dot_vox` e as coleções Rust são dependências de implementação, não uma biblioteca chamável por C que devamos ocultar atrás de uma abstração. A voxelização em si é opcional para o KOOKIE; a colisão completa de triângulos estáticos em 3D não exige transformar cada asset em voxels.

### C2. Transições de disparo/dano — referência de contrato

- [weapon_fire_handler.rs](../../CUBSHIP/cubgame/src/architecture/weapon/weapon_fire_handler.rs), em torno de 79–203: aumento de rotação, gatilho, recarga, recarregamento, verificações de carregador/munição, evento de disparo e sequência.
- [cubgame/src/systems.rs](../../CUBSHIP/cubgame/src/systems.rs), em torno de 24–129: consumo de armadura separado do dano à vida/resistência.

Evite semânticas fracas conhecidas: o agendador de DOT emite no máximo um tick atrasado em um frame longo; o sistema de dano não protege por si só os alvos já mortos antes da criação do evento de morte. **[INFERÊNCIA]** importá-los literalmente arrisca causar dano dependente do frame e recompensas de morte repetidas. Seu plugin raiz e o plugin de armas também registram caminhos sobrepostos; não reproduza autoridades duplas.

### C3. IA com orçamento — escalabilidade populacional posterior

- [pathfinding.rs](../../CUBSHIP/cubmind/src/pathfinding.rs), em torno de 84–296: A* em navmesh com orçamento máximo de nós, status de resultado explícito e waypoints.
- [perception.rs](../../CUBSHIP/cubmind/src/perception.rs), em torno de 78–149: consulta de candidatos espaciais, distância/FOV e LOS.

Limitações: “hierárquico” delega para um A* limitado; a ligação entre chunks é aproximada. Caminhos malsucedidos contêm início/fim, mas carregam `Failed`; nunca os siga como uma rota direta válida. Reutilize arrays temporários em vez de alocar uma grade a cada frame/vetor de candidatos por agente; use comparações de FOV por cosseno. Um cooker real de portais/navmesh ainda precisa ser implementado.

### C4. Contratos de salvamento/replay/rede — não são implementações para copiar- [cubsave/src/system.rs](../../CUBSHIP/cubsave/src/system.rs), por volta de 295–355, 435–508: seções serializadas/comprimidas de forma independente, preparação/sincronização/renomeação. O fallback de HMAC existente e as suposições sobre intervalos assinados não constituem um modelo de segurança a ser herdado.
- [cubway/src/net/demo.rs](../../CUBSHIP/cubway/src/net/demo.rs), por volta de 251–313, 393–458: reprodução de eventos com registro de data e hora, não replay determinístico da simulação. A busca move um cursor sem restaurar um checkpoint do mundo.
- [prediction/systems.rs](../../CUBSHIP/cubway/src/net/prediction/systems.rs), por volta de 260–335: reproduzir comandos não confirmados por meio da lógica de movimentação compartilhada é o contrato útil. A movimentação real, por volta de 111–195, usa um raio na altura da cintura e a redefinição do salto mantido, não a colisão com cápsula varrida.
- [cublevel/src/lib.rs](../../CUBSHIP/cublevel/src/lib.rs): o esquema de nível inclui IDs de Entity do Bevy. Os saves/níveis criados no KOOKIE devem usar identificadores estáveis de conteúdo/entidade, não identificadores de handles do ECS em tempo de execução.

## Pilhas gráficas observadas

| Projeto | Evidência no código-fonte | Significado |
|---|---|---|
| ZYLVE | [c.zig](../../ZYLVE/src/c.zig), SDL_CreateGPUDevice com SPIR-V em runtime3d, passes de renderização da SDL GPU | SDL3 GPU; precedente Linux/Vulkan. Os assets SPIR-V existentes não oferecem suporte automaticamente a Metal/D3D12 |
| DINX | [render/renderer.zig](../../DINX/src/render/renderer.zig), zsokol.gfx/app; o build seleciona GL/D3D11 | Precedente do Sokol; também possui rasterizadores de software. Wrappers Zig não são uma ABI Kof reutilizável |
| CUBSHIP | [Cargo.toml](../../CUBSHIP/Cargo.toml), Bevy 0.18/wgpu 27/Avian 0.6; Bevy RenderDevice/RenderQueue | Pilha Rust/Bevy; não é uma camada gráfica externa fina para o KOOKIE |

## Licenciamento e propriedade

- **DINX:** [LICENSE](../../DINX/LICENSE) fornece termos MIT e alerta que os avisos de terceiros permanecem separados. Preserve a atribuição para códigos substanciais copiados/traduzidos; o corpus de mapas e os assets são separados.
- **ZYLVE:** [README](../../ZYLVE/README.md), por volta de 251–256, limita o jogo inteiro ao uso privado/interno. Nenhuma autorização geral de redistribuição pública foi estabelecida. A autorização do usuário permite pesquisar/utilizar lógica de propriedade para este projeto; ela não libera arte, som, fontes ou código de terceiros/comerciais.
- **CUBSHIP:** [README](../../CUBSHIP/README.md) declara MIT, mas o empacotamento da licença na raiz/no crate direto inspecionado estava incompleto. Resolva os direitos/avisos reais antes da distribuição. cubout-core preserva explicitamente a propriedade original, em vez de conceder novos direitos.

Cada port deve registrar o caminho de origem, a revisão/hash no momento do port, o comportamento reutilizado, as semânticas alteradas e os avisos mantidos. A pesquisa não copiou código nem assets de projetos irmãos e não atribuiu uma licença ao KOOKIE.

## Sequência de port e antipadrões

1. Papéis da sessão, IDs estáveis, comandos com tick, codecs de loopback, consumo de bordas de entrada, tick fixo e metadados de itens de renderização.
2. Snapshots autoritativos de servidor/cliente, predição/reconciliação, intenção de movimentação e colisão contínua agora correta, uma única autoridade de disparo/dano/morte.
3. Admissão/replicação em LAN, identidades de itens, transações atômicas de inventário/atributos/habilidades e loot orientado por definições.
4. Publicação de cooker/editor com revisão, saves versionados, checkpoints de replay e manifests/esquema de extensões com migração.
5. IA com orçamento, streaming, escala de servidor dedicado e transporte mais amplo somente depois que o slice representativo de multiplayer funcionar.

Evite coordenadores de runtime monolíticos, lógica pertencente à engine em shims estrangeiros, autoridades concorrentes de ECS/armas, capacidades herdadas minúsculas, overflow silencioso de gameplay, fingir que checksum equivale a autenticação, fingir que o modo para um jogador pode ignorar a replicação e confiar em nomes/rótulos de backlog em vez do comportamento.
Exemplos de projetos irmãos são evidências de design, não certificação de desempenho ou correção para o port.