# Changelog

Este arquivo registra as mudanças importantes do KOOKIE em linguagem direta. Ele não promete que um milestone terminou; o plano e as verificações focadas continuam sendo a fonte de verdade.

## 2026-09-24

### O que avançou

- Adicionamos replay limitado dos comandos de interação consumidos, reserva de posições de captura e arquivos de replay v2 com leitura de v1 genuíno. A reprodução simula até 4096 ticks a partir de checkpoint completo, com jogador de movimento explícito e interações de ambos os jogadores.
- Adicionamos seção 11/versão 1 de save do nível com IDs estáveis e validação de nível/versão do conteúdo. O arquivo de schema v2 usa o tamanho real do envelope e checksums independentes; preservamos capacidades configuradas, recuperação de uma cópia, reparo e compatibilidade v1.
- Corrigimos campos não inicializados de inventário/triângulos em checkpoints, preservamos input mantido nas buscas e capturamos movimento no tick realmente consumido. O replay agora encaminha registros completos de input; bits de disparo nativos e sequências de apresentação repetidas foram verificados.
- Conectamos a ativação das portas criadas ao bloqueio do movimento escalar autoritativo e à geometria do cliente em `FrameStaging`. Portas fechadas bloqueiam a travessia do plano X; portas abertas deixam de bloquear. O contrato de colisão da arena 3D continua inacabado.
- Adicionamos ciclo limitado de desconexão/reconexão de clientes no loopback. A reconexão preserva posição autoritativa e marcas d'água de sequência, limpa input pendente e rejeita comandos obsoletos; a prova LAN autenticada real continua separada.
- Adicionamos reconexão da sessão remota com sequência preservada. As marcas d'água de envio/recebimento do broad-phase sobrevivem ao fechamento e reabertura, a sonda UDP nativa autenticada retoma na sequência 9 e snapshots antigos continuam rejeitados. A prova LAN com dois clientes ainda é um gate separado.
- Adicionamos um construtor reproduzível de arquivo dogfood Linux x86-64 com procedência, `SHA256SUMS` e smoke do binário extraído. O empacotamento Windows falha fechado até que o Kof exponha um alvo PE real e prova de assinatura/runtime; o arquivo é apenas interno porque KOOKIE não declarou licença nem registro de aplicação no OVERZEER.
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
- A apresentação em janela ainda precisa de um host isolado com suporte DRI3 utilizável.
- Multiplayer de produção, content cooking, áudio de produção e a stack completa de física continuam no roadmap.
- Compilação nativa para Windows, runtime relocável, avisos de licença e registro do KOOKIE no OVERZEER continuam como pré-requisitos de release. Nenhum pacote ou deploy foi declarado pronto.

## Trabalho anterior

- Construímos as fundações limitadas de G0/G1 para sessão, fixed-step, snapshots, colisão, replay, saves, inventário, progressão, inimigos, projéteis e adaptador SDL.
- Adicionamos sondas de transporte UDP autenticado em localhost, verificações de recuperação SDL_GPU headless, captura de apresentação em replay e contratos determinísticos de combate/eventos.
