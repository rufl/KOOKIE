# Changelog

Este arquivo registra as mudanças importantes do KOOKIE em linguagem direta. Ele não promete que um milestone terminou; o plano e as verificações focadas continuam sendo a fonte de verdade.

## 2026-09-29
### Slice de feedback de combate confirmado

- Conectamos resultados autoritativos aceitos de hitscan e shotgun de alvo
  único a uma fila monotônica e limitada de apresentação/áudio de impacto.
  Backpressure de apresentação não desfaz dano autoritativo e expõe a contagem
  de descartes; eventos confirmados também entram no histórico limitado de
  apresentação do replay.
- Estendemos o HUD semântico com marcadores estruturais de acerto e eliminação,
  além de alertas de dano nas bordas em altura total. O feedback expira por tick
  de simulação, sequências duplicadas são rejeitadas e a geometria inativa
  permanece degenerada dentro da alocação fixa. O HUD agora usa 174 vértices e
  a cena criada completa usa 252, abaixo do limite nativo existente de 256.
- Encaminhamos a eliminação autoritativa real de `G1Demo` pelo HUD e pela sonda
  de apresentação nativa. O áudio SDL agora recebe o clip `201` desse evento
  com ganho `100`, em vez de um clip de amostra sem relação.

### HUD semântico e dogfood visual

- Substituímos três barras numéricas sem rótulo por painéis escuros limitados:
  tracks emolduradas de vida e munição, ícones estruturais de vida/cartucho,
  pips de encounter e mira responsiva ao foco. Estados crítico e sem foco
  mudam a geometria, não apenas a cor.
- Expandimos o orçamento persistente da cena SDL_GPU de 128 para 256 vértices e
  substituímos a textura de debug de quatro cores por uma paleta semântica de
  16 cores para mundo/HUD.
- Adicionamos um runtime de pacote Linux `presentation` com o executável Kof de
  arena/HUD, adaptador SDL, shaders SPIR-V e bibliotecas de runtime resolvidas.
  O launcher relocável ancora o carregamento de assets no próprio pacote.
- Adicionamos cobertura observável do estado do HUD. Todos os 72 testes de
  código-fonte passam na JVM e no nativo; os smokes de pacote
  arquivo/checksum/procedência passam para os runtimes nativo, JVM e
  apresentação.

## 2026-09-28
### Lote atual de qualificação

- Substituímos o wire estreito de interação por um protocolo de gameplay
  limitado e com checksum para movimento, disparo, interação, desconexão e
  reconexão. O estado autoritativo agora carrega posições dos dois jogadores,
  vida, moeda, máscara de progressão e geração/motivo/diagnóstico do ciclo de
  vida.
- Adicionamos admissão por tick exato do servidor para disparo,
  movimento/interação remotos e uma recompensa terminal hitscan em moeda
  controlada pelo servidor. Três processos na JVM e no nativo agora comprovam
  movimento, morte mais 25 de moeda, progressão até revisão 4, geração 2 após
  reconexão e diagnóstico explícito de comando obsoleto.
- Fechamos o gate G1 do shooter autoritativo com um cenário executável na JVM e
  no nativo: servidor a 60 Hz admite dois clientes loopback, expõe correção de
  predição de quatro unidades e reconciliação, resolve uma eliminação com uma
  arma/inimigo e prova que a perda de foco não deixa movimento ou disparo
  enfileirados.
- Adicionamos uma arena 3D real criada com 78 vértices e 26 triângulos, rampa
  caminhável, dois degraus e salas inferior/superior empilhadas. Snapshots do
  broad-phase agora carregam limites explícitos com revisão/dados dos
  triângulos, permitindo ao cliente consultar os mesmos andares.
- Adicionamos staging de câmera/mundo/HUD com capacidade fixa e caminho nativo
  SDL_GPU persistente para vértices/upload da cena. Uma sonda GPU isolada
  renderizou 78 vértices da arena mais 18 do HUD numérico, leu um frame P6
  320×240 e manteve capacidades durante 64 frames determinísticos.
- Removemos a alocação por sweep do controlador de contato. O sidecar de replay
  passou a comportar 1.296 palavras para manter atômicos o estado da arena de
  32 triângulos e o histórico limitado de apresentação; o bundle de replay que
  falhava agora passa.
- Checks JVM/nativo passam, o marcador focado de runtime G1 é idêntico nos dois
  alvos e todos os 71 testes passam em cada alvo.

- O gate de apresentação isolada validou janela real, input, áudio, draw GPU,
  captura de screenshot e saída limpa sem tocar o desktop ativo.
- O gate final de LAN externa autenticada validou dois clientes independentes,
  autenticação, sequências monotônicas, saídas limpas e identidades distintas.
  Detalhes operacionais e evidências permanecem fora do repositório.
- `bash scripts/verify.sh` passou no commit `bd5c6d1`: lint, LSP, checks
  JVM/native, 70/70 testes em cada alvo, smoke de runtime, smoke de pacote e
  os dois builds do compilador. A execução opcional do adaptador foi adiada
  com segurança uma vez pelo gate de pressão PSI do display isolado.
- `KOOKIE_EXTERNAL_LAN_MODE=processes` passou com o host autenticado e dois
  processos clientes locais, incluindo reconexão e rejeição de frames obsoletos;
  os três roles saíram com `0`. A evidência permanece corretamente
  `externalHostExecution=unproven`, pois todas as identidades estão na mesma
  máquina.
- Construímos e executamos smoke após extração do Linux nativo
  `0.1.0-dogfood.20` (`bd5c6d1`, SHA256
  `e7a121899948740ef059f9f25d5eac5d3be77c45009c127e0739cfbc88fc961f`,
  2426844 bytes), Linux JVM `0.1.0-dogfood.jvm.20` (SHA256
  `714da5e311d6939e1a52e81c4c5d8ba1fa5623cddaadeac8b93e6caa492d169a`,
  433882 bytes) e o arquivo de roles LAN externo (SHA256
  `3b6bb75cc360fa75e67d4f6cba54c0326b4fdf65b5106616f06a07d70d4c516b`,
  1088335 bytes).
- Tentativas anteriores de apresentação falharam de modo fechado quando o
  ambiente isolado não forneceu a capacidade necessária. Diagnósticos
  específicos da máquina permanecem fora do repositório.
- Compatibilidade de deployment e smoke dos pacotes foram validados sem reter
  aqui nomes de endpoints, endereços, serviços ou IDs de deployment.

- Adicionamos qualificação local em processos consciente do alvo:
  `KOOKIE_EXTERNAL_LAN_TARGET=jvm` agora constrói e executa três papéis JVM
  diretos do Kof por `scripts/verify_external_lan.sh`, registra os mesmos
  metadados de identidade/status e valida o mesmo contrato de evidência do
  caminho nativo. O padrão continua `native`; a evidência na mesma máquina
  continua sem provar o DoD entre hosts externos.

- As regressões focadas de LAN consciente do alvo passaram no modo nativo em
  processos, no modo JVM em processos e no modo JVM de processo único. Cada
  execução saiu com `0`, com gameplay autenticado, reconexão, rejeição de
  frames obsoletos e validação de evidência; os modos em processos continuam
  sendo evidência apenas da mesma máquina.

### Transporte LAN externo entre alvos

- Separamos a sonda G0 em um contrato Kof neutro ao alvo, com backend UDP
  nativo e backend UDP JVM direto em Kof por meio das APIs JDK `java.net`;
  ambos compartilham framing autenticado, chave, replay e rejeição de sequência.
- `scripts/verify_external_lan_role.sh` agora constrói roles `native` ou
  `jvm`. `scripts/package_external_lan_roles.sh` gera JARs Windows de host e
  clientes com launchers `.cmd`, sem embutir a chave ou o manifest do run.
- Smokes locais bidirecionais host nativo/clientes JVM e host JVM/clientes
  nativos passam. A evidência de máquinas distintas é validada privadamente e
  permanece fora do repositório; o suporte PE nativo Windows permanece fora do
  G0.


## 2026-09-24

### O que avançou

- Adicionamos replay limitado dos comandos de interação consumidos, reserva de posições de captura e arquivos de replay v2 com leitura de v1 genuíno. A reprodução simula até 4096 ticks a partir de checkpoint completo, com jogador de movimento explícito e interações de ambos os jogadores.
- Adicionamos seção 11/versão 1 de save do nível com IDs estáveis e validação de nível/versão do conteúdo. O arquivo de schema v2 usa o tamanho real do envelope e checksums independentes; preservamos capacidades configuradas, recuperação de uma cópia, reparo e compatibilidade v1.
- Corrigimos campos não inicializados de inventário/triângulos em checkpoints, preservamos input mantido nas buscas e capturamos movimento no tick realmente consumido. O replay agora encaminha registros completos de input; bits de disparo nativos e sequências de apresentação repetidas foram verificados.
- Conectamos a ativação das portas criadas ao bloqueio do movimento escalar autoritativo e à geometria do cliente em `FrameStaging`. Portas fechadas bloqueiam a travessia do plano X; portas abertas deixam de bloquear. O contrato de colisão da arena 3D continua inacabado.
- Adicionamos ciclo limitado de desconexão/reconexão de clientes no loopback. A reconexão preserva posição autoritativa e marcas d'água de sequência, limpa input pendente e rejeita comandos obsoletos; a prova LAN autenticada real continua separada.
- Adicionamos reconexão da sessão remota com sequência preservada. As marcas d'água de envio/recebimento do broad-phase sobrevivem ao fechamento e reabertura, a sonda UDP nativa autenticada retoma na sequência 9 e snapshots antigos continuam rejeitados. A prova LAN com dois clientes ainda é um gate separado.
- Adicionamos arquivos dogfood reproduzíveis para Linux x86-64 nos runtimes Kof nativo e JVM com JAR executável, com procedência, `SHA256SUMS` e smoke do binário extraído. O empacotamento Windows continua falhando fechado até que o Kof exponha um alvo PE real e prova de assinatura/runtime.
- Corrigimos a verificação SIMD AArch64 no CI Ubuntu que selecionava headers da libc x86 do host. O Clang agora usa seus próprios headers C11 freestanding; a verificação cruzada continua obrigatória e não comprova vinculação nem execução AArch64.
- Adicionamos progressão cooperativa de chave/porta/segredo/saída, comandos limitados por tick, estado do cliente e restauração de checkpoint em arquivo. Pausa/perda de foco cancela interações pendentes; pedidos duplicados não premiam um segredo duas vezes.
- Corrigimos inputs de catch-up e cooldowns de armas que usavam o tick final do frame em vez do tick real da simulação.
- Corrigimos registros sobrepostos de replay espacial que sobrescreviam a coordenada Z e deixavam memória nativa no payload. O estado espacial agora usa a versão 2; layouts corrompidos da versão 1 são rejeitados, sem tentar adivinhar dados perdidos.
- Adicionamos seleção determinística de alvos por raio usando inteiros: impacto mais próximo, desempate por ID estável, offsets de dispersão, armazenamento limitado, exclusão da fonte por `SpatialAimContract` e rejeição segura de consultas inválidas.
- O contrato compartilhado de mira agora está conectado ao combate autoritativo de shotgun do jogador sem criar uma segunda autoridade de dano. `LoopbackSession.resolvePlayerSpatialShotgun` deriva offsets da arma, seleciona um alvo por pellet e resolve o resultado por `CombatWorld.resolveShotgunPelletTargets`.
- Adicionamos tratamento limitado de erro de pontaria, remoção de alvos e wrappers de sessão para que os alvos selecionados atravessem o caminho normal de combate e eventos.
- A cobertura JVM/native agora verifica raios centrais, pellets deslocados, exclusão da fonte, dano por dispersão, remoção de alvos, ordem dos eventos, IDs repetidos e seleções com tamanho incorreto.
- Adicionamos despacho SIMD nativo seguro para produção, com seleção AVX2/SSE2 no x86, cobertura de origem NEON no AArch64 e fallback escalar verificado. O caminho do host, o caminho escalar e a origem AArch64 foram comprovados.
- Mantivemos os limites importantes explícitos: a FFI de buffers em massa do Kof continua bloqueada por `FFI001`, então o kernel SIMD não é apresentado como ganho de velocidade da engine.
- Atualizamos o roadmap em inglês e português brasileiro para que o status não fique defasado.

### Verificações

- Correção de CI: SIMD do host, escalar forçado, sintaxe AArch64, validação do workflow e sonda de interações JVM/native passaram localmente.
- Lote atual: 18 cenários focados passaram na JVM e no nativo por `scripts/verify_interactions.sh`; 20 regressões existentes afetadas passaram em cada alvo.
- As reproduções de catch-up e replay espacial com dois atores falharam antes das correções e passaram depois.
- Buffers de checkpoint contaminados e busca de checkpoint com disparo mantido falharam antes das correções e passaram depois.
- Lote anterior de combate: 63/63 testes por alvo, mais verificações SIMD host/escalar/AArch64. A suíte completa não foi repetida localmente neste lote.

### Ainda falta

- Saves realmente duráveis contra crash ainda precisam de substituição atômica e primitivas de flush/sync do filesystem.
- O Kof precisa de FFI de buffers antes que o SIMD nativo possa atender hot loops pertencentes ao Kof.
- A apresentação em janela exige um host isolado com capacidade adequada.
- Multiplayer de produção, content cooking, áudio de produção e a stack completa de física continuam no roadmap.
- Compilação nativa para Windows, runtime relocável e avisos de licença continuam como pré-requisitos de release. Nenhum pacote ou deploy foi declarado pronto.

## Trabalho anterior

- Construímos as fundações limitadas de G0/G1 para sessão, fixed-step, snapshots, colisão, replay, saves, inventário, progressão, inimigos, projéteis e adaptador SDL.
- Adicionamos sondas de transporte UDP autenticado em localhost, verificações de recuperação SDL_GPU headless, captura de apresentação em replay e contratos determinísticos de combate/eventos.
