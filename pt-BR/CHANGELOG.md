# Changelog

Este arquivo registra as mudanças importantes do KOOKIE em linguagem direta. Ele não promete que um milestone terminou; o plano e as verificações focadas continuam sendo a fonte de verdade.

## 2026-09-24

### O que avançou

- Adicionamos seleção determinística de alvos por raio usando inteiros: impacto mais próximo, desempate por ID estável, offsets de dispersão, armazenamento limitado e rejeição segura de consultas inválidas.
- O resultado da seleção espacial de pellets agora pode seguir o caminho normal de combate sem criar uma segunda autoridade de dano. `CombatWorld.resolveShotgunPelletTargets` aceita exatamente um alvo validado por pellet, inclusive vários impactos no mesmo ator.
- Adicionamos wrappers de sessão para jogador e inimigo, permitindo que os alvos escolhidos por pellet atravessem o caminho normal de combate e eventos.
- A cobertura JVM/native agora verifica raios centrais, pellets deslocados, remoção de alvos, ordem dos eventos, IDs repetidos e seleções com tamanho incorreto.
- Adicionamos despacho SIMD nativo seguro para produção, com seleção AVX2/SSE2 no x86, cobertura de origem NEON no AArch64 e fallback escalar verificado. O caminho do host, o caminho escalar e a origem AArch64 foram comprovados.
- Mantivemos os limites importantes explícitos: a FFI de buffers em massa do Kof continua bloqueada por `FFI001`, então o kernel SIMD não é apresentado como ganho de velocidade da engine.
- Atualizamos o roadmap em inglês e português brasileiro para que o status não fique defasado.

### Verificações

- Suíte de regressão JVM: 62/62 passou.
- Suíte de regressão nativa: 62/62 passou.
- Lint do Kof e diagnósticos do LSP: passaram.
- Prova SIMD: caminho AVX2 do host, caminho escalar forçado e sintaxe com alvo AArch64 passaram.

### Ainda falta

- A integração espacial automática do shotgun ainda precisa de um contrato único de raio do ator e mira.
- Saves realmente duráveis contra crash ainda precisam de substituição atômica e primitivas de flush/sync do filesystem.
- O Kof precisa de FFI de buffers antes que o SIMD nativo possa atender hot loops pertencentes ao Kof.
- A apresentação em janela ainda precisa de um host isolado com suporte DRI3 utilizável.
- Multiplayer de produção, content cooking, áudio de produção e a stack completa de física continuam no roadmap.

## Trabalho anterior

- Construímos as fundações limitadas de G0/G1 para sessão, fixed-step, snapshots, colisão, replay, saves, inventário, progressão, inimigos, projéteis e adaptador SDL.
- Adicionamos sondas de transporte UDP autenticado em localhost, verificações de recuperação SDL_GPU headless, captura de apresentação em replay e contratos determinísticos de combate/eventos.
