# Backlog de implementação G0

[English](../../docs/G0_BACKLOG.md)

Esta é a sequência ativa e limitada de implementação após os commits iniciais de pesquisa e contratos.

Este backlog histórico G0 registra a qualificação da engine e dos pacotes, não
uma release de demo voltada ao jogador. O gate D1 aberto está em
[Prontidão da release demo](DEMO_RELEASE.md).

## Concluído

- Fontes Kof modulares `core`/`session` e sonda escalar de SDL3.
- Documentação bilíngue e gate de verificação antes do push.
- Tokens de recursos pertencentes ao Kof, verificados por slot, geração e tipo.
- Smoke focado JVM/nativo e contratos comportamentais nomeados.
- Ciclo escalar `SDL_Init(0)`/`SDL_Quit()` exercitado na JVM/nativo.
- Estado Kof de foco/redimensionamento/fechamento e FIFO de áudio com capacidade limitada.
- Adaptador C SDL estreito com tokens verificados de janela/áudio/GPU e flattening escalar de eventos.
- Transferência PCM limitada para stream de efeitos SDL_mixer, sem callback para o Kof.
- Sonda do adaptador nativo aplicando eventos reais do adaptador ao estado Kof e executando o primeiro caminho de upload/draw de textura SPIR-V.
- Contrato limitado de staging de frame Kof medido em 15 escritas escalares para um triângulo texturizado de três vértices, com verificações de ownership de publish/discard.
- Reproduzível do lifetime de exceção nativa e controles negativos registrados no gate de verificação.
- Adaptador nativo expõe timing decorrido de draw GPU após retirement com GPU ocioso.
- Relógio de fixed-step G1, comandos de input limitados com transições de borda fire/jump, sincronização de snapshot servidor/cliente em loopback e storage limitado de componentes inteiros.
- Admissão de dois clientes em loopback G1, sequência de input por cliente,
  rejeição de snapshots antigos ou duplicados, substituição de revisões novas no
  mesmo tick, movimento autoritativo limitado e clamp de câmera/input.
- Smoke nativo isolado aceitou ciclo de vida da janela oculta, flattening de resize/focus, áudio dummy, teardown de tokens obsoletos e limpeza de processos; a GPU ficou indisponível para apresentação em janela.
- Histórico limitado de snapshots do cliente com interpolação inteira e limites explícitos de autoridade de predição/reconciliação.
- Consultas escalares limitadas de colisão com resolução de movimento no limite e rejeição de posicionamento fora dos limites.
- Histórico limitado de inputs de predição (capacidade oito) com replay após reconciliação autoritativa; o estado do servidor continua autoritativo.
- Consultas limitadas de sweep de segmento 3D inteiro em volume alinhado aos eixos, rejeitando penetração inicial e traversal acima do orçamento.
- Consultas limitadas de triângulo inteiro com rejeição de triângulo degenerado e resolução na amostra anterior.
- Movimento limitado do centro de cápsula com limites expandidos pelo raio e admissão compartilhada de jogador/projétil/linha de visão.
- Dispositivo SDL_GPU offscreen isolado e draw indexado de quad SPIR-V aceitos com uploads explícitos de buffers de vértices/índices e recursos GPU em cache por dispositivo; o smoke ficou dentro do orçamento declarado de 16.667 microssegundos por frame.
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
- O smoke nativo isolado autorizado executa pelo adaptador SDL: transporte de
  sessão autenticado, recuperação GPU headless e áudio passam.
- O gate integrado de apresentação usa `scripts/verify_presentation.sh` por um
  wrapper revisado configurado em `KOOKIE_PRESENTATION_ISOLATION_WRAPPER`.
  A evidência valida resize/foco, draw GPU, áudio, screenshot e saída limpa sem
  registrar o host operacional neste repositório.
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
- O P2 de publicação de save durável contra crash foi implementado pelo
  adaptador nativo POSIX/Windows. `BoundedSessionSaveCoordinator` continua sendo
  a fronteira Kof-first de path arbitrário: codifica progressão de nível e
  autoridade G3, prepara, carrega/restaura seções validadas e descarta staging
  interrompido. O `BoundedHostSessionSaveCoordinator` seguro para PE Windows
  mantém codificação, migração e rollback no Kof, transfere palavras wire
  limitadas por chamadas integrais verificadas e deixa staging/leitura dos
  bytes do schema e publicação durável no adaptador nativo, sem FFI de `File` ou
  `String`. O gate Kof POSIX e o gate player-facing G7 de gameplay de gansos
  executam stage → publicação nativa → confirmação → restauração;
  `scripts/verify_pe_durable_save.sh` repete o mesmo ciclo Kof-first pelo PE
  gerado sob Wine, e o smoke de apresentação G0 repete o ciclo após Play e
  uma sessão nova. O gate Windows compila em cross-target e executa o
  adaptador contra fixtures brutos de bytes antigo/novo sob Wine. Flush/sync do
  arquivo, substituição atômica no mesmo diretório e durabilidade do diretório
  são fases explícitas. A execução
  Windows é um smoke de console, não evidência de NTFS Windows nativo. Os gates
  interrompem antes do sync do arquivo, depois do sync do arquivo, depois do
  rename e depois do sync do diretório; provam que o save anterior permanece
  válido antes da substituição e que o novo save completo permanece válido
  depois dela, incluindo a limpeza de staging truncado. O owner de apresentação
  G0 vincula publicação à saída do gameplay/fechamento da janela e restauração
  ao início/reentrada do processo; um owner de save de servidor dedicado
  continua sendo uma fronteira separada.
- A perda de foco agora limpa comandos de jogador pendentes, emite bordas de liberação dos botões mantidos, bloqueia novos inputs enquanto desfocado e rearma corretamente ao recuperar o foco; a cobertura JVM/nativa impede disparos obsoletos.
- A pausa agora redefine a dívida de tempo do fixed-step, desarma comandos de jogador pendentes, bloqueia simulação/input enquanto pausado e retoma sem picos de catch-up; a cobertura JVM/nativa fixa o contrato documentado de pausa.
- `InputReplayRecorder` agora registra comandos de tick resultantes validados (não eventos crus da plataforma) em um FIFO limitado, preserva ordem determinística, rejeita comandos obsoletos/duplicados/inválidos e reproduz ou redefine sem crescimento ilimitado; `LoopbackSession` captura comandos consumidos somente quando explicitamente habilitado e redefine a captura limitada ao desabilitar.

- DXPERF-051 agora possui um mecanismo nativo de despacho seguro para produção: seleção de AVX2/SSE2 em tempo de execução no x86, cobertura de origem NEON no AArch64, fallback escalar verificado, inicialização segura para threads, prova de execução no host/escalar e prova sintática com alvo cruzado AArch64. A integração de buffers do Kof continua bloqueada pelo limite `FFI001` existente; nenhum ganho de velocidade é alegado.
- `BoundedRayTargetWorld` agora fornece seleção limitada de alvos por raio e pellets de shotgun com inteiros, ordenação pelo impacto mais próximo, desempate por ID estável, offsets de dispersão, exclusão da fonte por `SpatialAimContract`, remoção de alvos e rejeição de entradas inválidas; a cobertura JVM/native prova impactos central e deslocado.
- `CombatWorld.resolveShotgunPelletTargets` e os wrappers de sessão do jogador/inimigo agora aceitam exatamente um alvo validado por pellet, preservam IDs repetidos quando vários pellets atingem o mesmo ator, permitem erros de pontaria limitados e publicam eventos de combate ordenados; a cobertura JVM/native prova a ordem dos alvos e rejeita seleções com tamanho incorreto.
- `LoopbackSession.resolvePlayerSpatialShotgun` agora constrói um `SpatialAimContract` compartilhado, deriva offsets de pellet do estado autoritativo de combate, seleciona alvos espaciais e resolve os IDs selecionados pelo caminho autoritativo por pellet; a cobertura JVM/native prova dano por dispersão, exclusão da fonte, remoção de alvo e vida dos alvos.
- `BoundedInteractionWorld` e `LoopbackSession` agora implementam progressão cooperativa de chave/porta/segredo/saída com ativação única, definições limitadas e seladas, alcance pela posição do servidor, admissão por sequência/tick, cancelamento por foco/pausa, pedidos simultâneos determinísticos e snapshots de ativação do cliente. Bundles de checkpoint preservam definições, ativações, pedidos pendentes e sequências.
- Corrigimos agendamento pelo tick real no catch-up e sobreposição de registros espaciais de checkpoint. Sete cenários focados JVM/native e 14 testes existentes afetados por alvo passaram. Replay espacial v2 rejeita layouts v1 irrecuperáveis.
- O replay de interações agora registra até 64 comandos consumidos, reserva capacidade antes da admissão, persiste os comandos em bundles v2 e simula novamente a partir de checkpoints completos. Movimento usa o tick consumido; input mantido e sequência de apresentação sobrevivem a buscas repetidas.
- A progressão do nível agora usa seção 11/versão 1 com identidade de nível/conteúdo e correspondência exata de IDs estáveis. Arquivos de save usam cópias v2 limitadas e com checksum; arquivos v1 genuínos continuam legíveis e o reparo os atualiza. Dezesseis cenários focados e 20 regressões existentes afetadas passam em cada alvo.
- Corrigimos a serialização nativa de campos de rolagem de itens e registros de triângulos não usados; regressões com buffers contaminados impedem memória residual em arquivos de replay.
- A integração de portas agora usa centro/semieixos 3D criados para bloqueio autoritativo por segmento/AABB. Portas abertas deixam de bloquear; portas fechadas geram um cuboide de 36 vértices projetado pela câmera por `FrameStaging`, incluindo caminhos acima e ao lado do volume.
- Substituímos o wire exclusivo de interação por comandos unificados,
  versionados e com checksum para movimento, disparo, interação, desconexão e
  reconexão, além de estado autoritativo com posições, vida, moeda, progressão
  e diagnóstico de conexão.
- Execuções com três processos na JVM e no nativo comprovam movimento emitido
  pelo cliente, morte hitscan autoritativa do inimigo mais 25 moedas, estado e
  vida terminais do encounter, feedback confirmado mais recente, revisão 4 de
  chave/porta/segredo/saída, geração 2 após reconexão e diagnóstico explícito
  de geração obsoleta. O host envia estado de gameplay com 20 palavras
  específico por destinatário, lotes ordenados de feedback `6 + 11F` e uma
  mensagem de encounter `20 + 8N` com checksum, papel e posição 3D para até 32
  inimigos.
- As qualificações combinadas de código-fonte e interação encerram os contratos
  G2 de papéis contínuos hitscan/projétil/shotgun,
  predição/reconciliação, entrada/recuperação segura por geração, volume 3D das
  portas, recuperação de feedback e espacialização estéreo Kof→SDL. A execução
  local dos papéis não é evidência WAN nem substitui o gate de release entre
  hosts distintos.

- O contrato de transporte da sonda G0 agora é neutro ao alvo, com backend UDP
  nativo e backend UDP JVM direto em Kof por meio das APIs JDK `java.net`.
  Ambos compartilham framing autenticado, chave, replay e rejeição de
  sequência. Smokes locais em ambas as direções passam; isso não prova
  identidades entre hosts distintos.
- A fronteira JVM do Kof foi medida diretamente com imports JDK de
  `DatagramSocket`, `DatagramPacket` e `InetAddress`, incluindo envio e
  recebimento em runtime. Os mesmos imports continuam rejeitados no alvo
  nativo; este backend é intencionalmente exclusivo da JVM. Veja
  `docs/KOF_LANGUAGE.md`.
- `KOOKIE_EXTERNAL_LAN_MODE=processes` agora constrói e inicia host, cliente-A
  e cliente-B como processos nativos separados. O runner
  `scripts/verify_external_lan_role.sh` aceita `KOOKIE_EXTERNAL_LAN_TARGET=native`
  ou `jvm`, além de `KOOKIE_EXTERNAL_LAN_HOST_IPV4`, chave compartilhada e
  timeout de recebimento.
- `scripts/package_external_lan_roles.sh` gera o pacote Windows JVM com JARs
  de host/clientes e launchers `.cmd`, sem embutir a chave ou o manifesto. Os
  launchers registram identidade, fingerprint da chave, run-ID e status de
  saída no log; papéis nativos e JVM podem ser misturados para qualificação do
  protocolo.
- A evidência JSON da LAN externa agora registra status de autenticação,
  sequências positivas recebidas pelo host para cada cliente, status de saída
  de cada papel e identidades de host/cliente. O validador rejeita ausência de
  sequência, autenticação ou status de saída, em vez de tratar marcadores de
  gameplay isolados como prova.
- Os logs de papel entre hosts agora incluem identidade, fingerprint de
  máquina com hash, fingerprint da chave de transporte e IPv4 configurado.
  A validação `separate-hosts` exige os três papéis, fingerprints de chave
  coincidentes e três máquinas distintas antes de marcar a execução externa
  como comprovada; o modo multi-processo na mesma máquina continua sem prova
  externa.
- A qualificação entre hosts passou com dois clientes identificados de forma
  independente, material de autenticação correspondente, sequências positivas e
  saídas limpas. Nomes, endereços, fingerprints, run IDs e evidência bruta
  permanecem fora do repositório.
- O verificador local em múltiplos processos agora aceita
  `KOOKIE_EXTERNAL_LAN_TARGET=native` ou `jvm`. O modo JVM constrói e inicia
  três papéis JVM diretos do Kof e usa os mesmos metadados de papel e validador
  de evidência do modo nativo; isso amplia a regressão local entre alvos sem
  declarar prova entre hosts distintos.

- Um manifesto compartilhado de execução agora vincula o run-ID, os três
  papéis, portas, revisão de origem e fingerprint da chave. A coleta entre
  hosts exige esse manifesto e rejeita logs misturados ou de outra execução.
- `scripts/verify_presentation.sh` grava evidência local legível por máquina e
  preserva `adapter.log` quando a apresentação não pode ser comprovada. A
  evidência gerada é dado operacional e não deve ser commitada.
- O validador fail-closed aceita somente janela real com capacidade positiva,
  marcador de draw, screenshot P6 válido e saída limpa.
- Arquivos reproduzíveis cobrem Kof nativo e a apresentação SDL persistente no
  Linux. O Windows x86-64 agora recebe gameplay Kof PE nativo no shell SDL3 +
  SDL_mixer e no pacote SDL_GPU, sem JDK embutido nos perfis nativos. O pacote
  JVM de roles LAN é somente ferramenta de qualificação/compatibilidade.
  Pacotes do produto incluem avisos MIT/zlib e rejeitam bibliotecas não
  revisadas.

## Evidência externa reproduzível

1. Com `KOOKIE_TRANSPORT_KEY_HEX` definido, criar um manifesto compartilhado
   de execução com a chave de transporte no host operador:
   `python3 scripts/create_external_lan_run_manifest.py /tmp/kookie-lan-run.json`.
   Copiar o manifesto para os três hosts e exportar o
   `KOOKIE_EXTERNAL_LAN_RUN_ID` impresso e
   `KOOKIE_EXTERNAL_LAN_RUN_MANIFEST` em cada host. Iniciar um host com os
   listeners 47101 e 47102, executar cliente-A e cliente-B em hosts distintos
   com a mesma chave e IPv4 do host, e então executar
   `scripts/collect_external_lan_evidence.sh host/probe.log
   client-a/probe.log client-b/probe.log evidence.json` com a variável do
   manifesto definida. Papéis nativos usam `KOOKIE_EXTERNAL_LAN_TARGET=native`;
   papéis JVM usam `jvm` pelo runner ou pelos launchers Windows de
   `scripts/package_external_lan_roles.sh`. Cada log deve preservar identidade,
   máquina, chave, run-ID e status de saída; o collector rejeita manifesto
   ausente/misturado ou fingerprints da mesma máquina. O modo multi-processo
   local prova somente a orquestração.
   O collector também grava um `external-lan-evidence.tar.gz` autocontido com
   manifesto, logs de cada papel, log combinado, JSON de evidência e
   `SHA256SUMS`.

Revisores podem executar `python3
scripts/verify_external_lan_evidence_bundle.py
/caminho/para/external-lan-evidence.tar.gz` para revalidar localmente checksums,
hashes do manifesto/evidência e campos do gate sem acesso à chave de transporte.
O bundle e os logs operacionais não devem ser commitados.

## Qualificação de release

O G0 está encerrado; trabalho posterior exige um novo milestone. Os contratos concluídos continuam registrados aqui.

- O `kof info --json` instalado reporta 0.5.0-beta no Linux x86-64. A
  qualificação de release atual constrói o commit de fonte `bf17ac7e7364`; os
  valores SHA-256 da distribuição construída localmente e do JAR do compilador
  são, respectivamente,
  `f6fd41ed59c461dd968376e8e2dd3f0dc24ee712578d318a7fb3f707bc761bdc`
  e `6634e1bf80334cc2518c50f9d1a05e2da92ff318282775ba58a087891e2420a6`.
  O assembler nativo upstream emite ELF Linux; a ponte Kof PE Windows emite
  PE/COFF AMD64 determinístico para os grafos alcançáveis qualificados de
  gameplay/apresentação.
- A qualificação local de release cobre Linux nativo e o shell de plataforma
  Windows SDL3 + SDL_mixer. O pacote de apresentação Windows liga Kof PE
  nativo ao adaptador SDL_GPU e inclui produtos SPIR-V/DXIL; o smoke do shell
  nativo em Wine verifica marcadores de gameplay e o marcador PE nativo. O
  lote de 2026-10-02 passou o gate de pacote/package-smoke Linux assinado e o
  gate de artefato de apresentação PE/SDL nativo Windows com dependências
  temporariamente fixadas.
- A sessão agora possui redundância limitada de input/ACK em passo fixo,
  fixação de endpoint autenticado, histórico de rewind de hitscan de 12 ticks,
  interpolação remota de seis ticks e métricas de correção da predição; esses
  checks focados não comprovam uma release voltada ao jogador.
- A tag pública mais recente continua somente Linux:
  `0.1.0-dogfood.34`. D1 ainda exige par Linux/Windows de árvore limpa, smoke
  interativo fora do checkout, verificação em host novo, evidência de hardware
  Linux/Windows nativo e política/notas finais. Evidência entre hosts só é
  necessária se o multiplayer for anunciado.
- Registros de deployment e evidência entre hosts são retidos fora deste
  repositório.


## Adiado

- Física completa, cooking de conteúdo, schema de save e transporte multiplayer de produção.
- Áudio de produção, serviços de imagem/texto, compressão de pacotes e bibliotecas estrangeiras de física/UI.


Não substitua uma capacidade nativa bloqueada por fallback JVM, engine C oculta, stub de falso sucesso ou scaffold gráfico não verificado.
