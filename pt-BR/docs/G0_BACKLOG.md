# Backlog de implementação G0

[English](../../docs/G0_BACKLOG.md)

Esta é a sequência ativa e limitada de implementação após os commits iniciais de pesquisa e contratos.

## Concluído

- Fontes Kof modulares `core`/`session` e sonda escalar de SDL3.
- Documentação bilíngue e gate de verificação antes do push.
- Tokens de recursos pertencentes ao Kof, verificados por slot, geração e tipo.
- Smoke JVM/nativo e três testes nomeados de regressão.
- Ciclo escalar `SDL_Init(0)`/`SDL_Quit()` exercitado na JVM/nativo.
- Estado Kof de foco/redimensionamento/fechamento e FIFO de áudio com capacidade limitada.
- Adaptador C SDL estreito com tokens verificados de janela/áudio/GPU e flattening escalar de eventos.
- Transferência PCM limitada de silêncio e clip determinístico para um stream de áudio SDL sem callbacks.
- Sonda do adaptador nativo aplicando eventos reais do adaptador ao estado Kof e executando o primeiro caminho de upload/draw de textura SPIR-V.
- Contrato limitado de staging de frame Kof medido em 15 escritas escalares para um triângulo texturizado de três vértices, com verificações de ownership de publish/discard.
- Reproduzível do lifetime de exceção nativa e controles negativos registrados no gate de verificação.
- Adaptador nativo expõe timing decorrido de draw GPU após retirement com GPU ocioso.
- Relógio de fixed-step G1, comandos de input limitados com transições de borda fire/jump, sincronização de snapshot servidor/cliente em loopback e storage limitado de componentes inteiros.
- Admissão de dois clientes em loopback G1, sequência de input por cliente, rejeição de snapshot obsoleto, movimento autoritativo limitado e clamp de câmera/input.
- Smoke nativo isolado aceitou ciclo de vida da janela oculta, flattening de resize/focus, áudio dummy, teardown de tokens obsoletos e limpeza de processos; a GPU ficou indisponível para apresentação em janela.
- Histórico limitado de snapshots do cliente com interpolação inteira e limites explícitos de autoridade de predição/reconciliação.
- Consultas escalares limitadas de colisão com resolução de movimento no limite e rejeição de posicionamento fora dos limites.
- Histórico limitado de inputs de predição (capacidade oito) com replay após reconciliação autoritativa; o estado do servidor continua autoritativo.
- Consultas limitadas de sweep de segmento 3D inteiro em volume alinhado aos eixos, rejeitando penetração inicial e traversal acima do orçamento.
- Consultas limitadas de triângulo inteiro com rejeição de triângulo degenerado e resolução na amostra anterior.
- Movimento limitado do centro de cápsula com limites expandidos pelo raio e admissão compartilhada de jogador/projétil/linha de visão.
- Dispositivo SDL_GPU offscreen isolado e draw indexado de quad SPIR-V aceitos com uploads explícitos de buffers de vértices/índices e recursos GPU em cache por dispositivo; o smoke mais recente mediu 1675 microssegundos para três draws contra o orçamento declarado de 16.667 microssegundos em `renderD128`, com uma amostra de 527 microssegundos de espera da fence.
- O relógio fixed-step expõe o orçamento declarado de frame a 60 Hz para as verificações de aceitação da GPU.
- O staging de frame aceita um quad texturizado de seis vértices dentro de um orçamento limitado de 30 escritas escalares.
- Coleções limitadas de triângulos usam um BVH binário determinístico de capacidade fixa com seleção do hit mais próximo, remoção/rebuild, revisões de geometria e diagnósticos de traversal.
- O movimento limitado de cápsula retorna resultados autoritativos de slide/step sobre uma coleção de oito obstáculos de step ordenados deterministicamente, com operações de limpeza/reconfiguração.
- Sessões autoritativas possuem a coleção limitada de triângulos broad-phase, passam sua revisão de geometria com snapshots de consulta, rejeitam consultas obsoletas, expõem um contrato limitado de payload inteiro e aplicam payloads em uma coleção do cliente com guardas de sequência.
- Filas limitadas de transporte broad-phase copiam payloads validados para armazenamento fixo de pacotes, rejeitam overflow sem descartar dados enfileirados e conduzem a replicação do cliente por dequeue/apply.
- A admissão de movimento espacial combina limites de cápsula com consultas de triângulos broad-phase e rejeita revisões de geometria obsoletas.
- O smoke isolado de sobreposição GPU submete quatro frames em dois slots de destino, aposenta todas as fences e reporta a profundidade máxima em voo.
- O smoke de recuperação GPU headless destrói e recria o dispositivo, reconstrói recursos em cache e conclui um draw após a recuperação.
- O transporte nativo UDP de peer envia e recebe frames broad-phase inteiros autenticados entre sockets de datagrama pareados no localhost; o provisionamento explícito de uma chave SipHash não nula é obrigatório antes da abertura, `kookie_transport_set_key_from_environment` aceita a fronteira `KOOKIE_TRANSPORT_KEY_HEX` com 32 caracteres hexadecimais, `kookie_transport_set_key_from_file` carrega exatamente 32 caracteres hexadecimais somente de um arquivo regular com modo 0600 ou mais restritivo em `KOOKIE_TRANSPORT_KEY_FILE`, `kookie_transport_rotate_key_from_file` reprovisiona o transporte fechado, `kookie_transport_open_remote_ipv4` liga atomicamente um socket local a peer/porta IPv4 validados, e o framing cobre versão do protocolo, tamanho, sequência e palavras com sinal, com timeout fixo de recebimento de 1.000 ms e limites de pacote.
- `LoopbackSession` agora possui a configuração autoritativa do endpoint remoto, ativação, bloqueio de envio de snapshots, validação monotônica de recebimento e desconexão; a sonda nativa conduz três ticks broad-phase autenticados por essa passagem autoritativa da sessão.
- O estado de recuperação GPU expõe unavailable/ready/lost/failed e um bitmask de capacidades sensível ao estado: ready suporta reopen limpo e eventos de reset/perda, enquanto lost retém apenas reopen; rejeita recuperação sem dispositivo headless ativo e reconstrói recursos após a recuperação.
- Eventos SDL de reset/perda do dispositivo de renderização agora passam pelo event pump, aposentam recursos GPU em cache com segurança nos caminhos de reset ou perda e conduzem a recuperação headless sem o antigo marcador explícito de perda; a sonda nativa exercita rebuild após reset e recuperação após perda.
- O smoke nativo isolado autorizado agora executa pelo adaptador SDL: transporte de sessão autenticado, recuperação GPU headless e áudio passam; a apresentação em janela registra `No DRI3 support detected`, então o caminho de screenshot protegido por capacidade permanece não executado. Esta estação expõe `/dev/dri/renderD128` e `/dev/dri/renderD129`, mas o display isolado baseado em Xvfb não fornece DRI3.
- O limite de runtime DRI3 está registrado nas duas árvores de idioma: o smoke de transporte é executável, enquanto a apresentação em janela ainda requer um host isolado compatível com apresentação.
- Quando uma janela compatível com apresentação está disponível, `KOOKIE_SCREENSHOT_PATH` exporta o frame capturado do swapchain como PPM binário; o caminho continua protegido por capacidade e não é definido por padrão.
- `CombatWorld` agora fornece definições autoritativas limitadas de armas, estado de recarga de magazine/reserva, disparos atômicos protegidos por cooldown, dano com armadura, críticos e exatamente uma transição de vivo para morto por ator; testes JVM/nativos cobrem atomicidade de munição e invariantes de dano/morte.
- `CombatWorld` agora resolve disparos hitscan e projéteis limitados pela mesma autoridade de arma/alcance/dano, consome slots de projéteis deterministicamente e publica eventos sequenciados de hit/morte sem descartar silenciosamente eventos críticos; testes JVM/nativos cobrem rejeição por alcance, atomicidade de munição, aposentadoria de projéteis e ordem de eventos.
- `EnemyStateWorld` agora implementa transições determinísticas idle/patrol/investigate/chase/attack/recover/stagger/dead com percepção e deadlines de ataque inteiros; `EncounterDirector` impõe limites ativos e orçamentos de spawn, com testes JVM/nativos para cooldown, morte terminal e overflow de admissão.
- `AuthoritativeEnemySession` agora vincula estado de inimigos, atores de combate, orçamentos de encounters e eventos de combate sequenciados; ataques inimigos passam pela resolução hitscan autoritativa, enquanto eventos de morte consumidos levam inimigos ao estado terminal e liberam slots de encounter. Testes JVM/nativos cobrem decisões de ataque, consumo sem morte, ponte de morte e orçamento determinístico de respawn.
- O `LoopbackSession` agora possui inputs limitados de percepção de inimigos, executa decisões configuradas de inimigos dentro do tick fixed-step, consome eventos de combate e publica snapshots monotônicos de inimigos com admissão do cliente; testes JVM/nativos cobrem decisões de ataque e estado replicado.
- `EnemySpatialWorld` agora fornece posições limitadas, consultas determinísticas de LOS apoiadas por BVH, movimento resolvido na última amostra livre e gating espacial de ataques de inimigos/projéteis no tick autoritativo; testes JVM/nativos cobrem caminhos livres, obstáculos, movimento bloqueado e dano de projétil.
- A sessão autoritativa de inimigos agora avança projéteis limitados entre ticks fixed-step com sweeps contra obstáculos, resolução terminal do alvo, bloqueio determinístico e aposentadoria de projéteis; os directors de encounter agora suportam zonas limitadas de spawn e admissão posicionada, com cobertura JVM/nativa em ticks diretos e de loopback.
- `EnemyNavigator` agora fornece A* limitado e determinístico de quatro vizinhos sobre a coleção autoritativa de obstáculos, com limites fixos de nós/rotas, desempate estável e resultado explícito de rota ausente; o steering espacial de inimigos avança pelo waypoint selecionado e testes JVM/nativos cobrem a escolha do desvio.
- Projéteis espaciais agora publicam eventos limitados de impacto terminal para acerto, bloqueio por obstáculo e expiração/cancelamento, preservando IDs de projétil/fonte/alvo, posição do impacto e dano aplicado; testes JVM/nativos cobrem o evento de acerto autoritativo.
- O `LoopbackSession` agora coloca snapshots replicados de impacto de inimigos em filas limitadas de apresentação de render e áudio, com mapeamentos determinísticos de clipes para acerto/bloqueio/expiração; snapshots duplicados são rejeitados e testes JVM/nativos cobrem identidade, ordem e consumo de áudio.
- Bordas de disparo do jogador agora alimentam uma fila limitada de apresentação de arma autoritativa, com estado do tiro aceito, transições de munição e supressão de disparo mantido; o adaptador SDL nativo isolado consome clipes de impacto confirmados 201/202/203 pela ponte de áudio.
- `BoundedSaveState` agora valida um payload inteiro limitado da versão 1 e revisão limitada, expõe checksums determinísticos do envelope, rejeita corrupção de capacidade/valor e suporta restauração em memória; `BoundedSaveHistory` publica revisões estritamente crescentes com eviction e restauração determinísticas limitadas; `BoundedSaveWireCodec` enquadra envelopes validados em palavras inteiras limitadas e rejeita corrupção de cabeçalho, tamanho, versão e checksum; I/O de arquivo e migrações continuam adiados.
- A perda de foco agora limpa comandos de jogador pendentes, emite bordas de liberação dos botões mantidos, bloqueia novos inputs enquanto desfocado e rearma corretamente ao recuperar o foco; a cobertura JVM/nativa impede disparos obsoletos.
- A pausa agora redefine a dívida de tempo do fixed-step, desarma comandos de jogador pendentes, bloqueia simulação/input enquanto pausado e retoma sem picos de catch-up; a cobertura JVM/nativa fixa o contrato documentado de pausa.
- `InputReplayRecorder` agora registra comandos de tick resultantes validados (não eventos crus da plataforma) em um FIFO limitado, preserva ordem determinística, rejeita comandos obsoletos/duplicados/inválidos e reproduz ou redefine sem crescimento ilimitado; `LoopbackSession` captura comandos consumidos somente quando explicitamente habilitado e redefine a captura limitada ao desabilitar.

- DXPERF-051 agora possui um mecanismo nativo de despacho seguro para produção: seleção de AVX2/SSE2 em tempo de execução no x86, cobertura de origem NEON no AArch64, fallback escalar verificado, inicialização segura para threads, prova de execução no host/escalar e prova sintática com alvo cruzado AArch64. A integração de buffers do Kof continua bloqueada pelo limite `FFI001` existente; nenhum ganho de velocidade é alegado.

## Próximo lote

1. Executar o caminho de screenshot da janela DRI3 em um host isolado compatível com apresentação; o smoke isolado X11/offscreen foi executado novamente e reportou corretamente `gpu-unavailable`, enquanto Xvfb continua incompatível com apresentação.

## Adiado

- Física completa, cooking de conteúdo, schema de save e transporte multiplayer de produção.
- Áudio de produção, serviços de imagem/texto, compressão de pacotes e bibliotecas estrangeiras de física/UI.


Não substitua uma capacidade nativa bloqueada por fallback JVM, engine C oculta, stub de falso sucesso ou scaffold gráfico não verificado.
