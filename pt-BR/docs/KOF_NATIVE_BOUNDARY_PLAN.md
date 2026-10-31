# Plano de migração da fronteira nativa Kof do KOOKIE

[English](../../docs/KOF_NATIVE_BOUNDARY_PLAN.md)

Status: **PROPOSTO**. Este plano é o documento de execução da decisão
`D-KOF-NATIVE-BOUNDARY`. Ele não autoriza uma reescrita ampla de C/Zig.

Fronteira normativa e ABI batch: [Fronteira nativa Kof e ABI batch síncrona](KOF_NATIVE_BOUNDARY_SPEC.md).

Pin de fonte atual: Kof oficial `0.6.9` no commit
`f02cd8233fb28cb225ac6e75ccd7d860add796ba`.

## 1. Resumo da decisão

1. Kof continua sendo a autoridade do comportamento de CPU pertencente ao
   engine: política de protocolo, simulação, admissão de conteúdo, extração de
   renderização, layout, schema de save e decisões de ciclo de vida.
2. C continua sendo a autoridade dos mecanismos de sistema operacional e de
   bibliotecas estrangeiras: handles SDL3/SDL_GPU/SDL_mixer, sockets,
   filesystem durável, FreeType/HarfBuzz, threads de worker, intrinsics SIMD e
   glue de entrada PE.
3. `Buffer(U8)` é uma fronteira síncrona, limitada e de copy-in/copy-back. Não é
   ABI de arrays tipados, ponteiro retido, transferência assíncrona de
   ownership nem contrato de callback de GPU/áudio.
4. O primeiro alvo é semântica pura e um caminho batch medido. Não são alvos o
   launcher, pipeline de shaders, threads, dispositivo de áudio, rasterização
   de fontes nem handles de GPU.
5. Chamadas escalares existentes permanecem como fallback durante a
   qualificação. Só são removidas depois dos gates deste documento; nenhum
   alias permanente de compatibilidade será adicionado.

## 2. Evidências e limites

A composição medida por `scripts/report_code_mix.py` na working tree atual é:

| Grupo | Linhas | Participação |
|---|---:|---:|
| Kof (`.kf`) | 83.128 | 77,89% |
| KofScript (`.ks`) | 764 | 0,72% |
| C/header | 8.660 | 8,11% |
| Ferramentas shell | 8.103 | 7,59% |
| Ferramentas Python | 4.346 | 4,07% |
| Ponte PE Java | 1.504 | 1,41% |
| Shader GPU | 215 | 0,20% |

Isso é composição física de fonte, não uma afirmação de performance.

O archive Linux oficial do Kof `0.6.9` tem SHA-256
`8da8f9efc7c55b6e5314248b90a0ac62d900117f4a3503af8dadf6ce82a20577`.
O gate de identidade do archive passou. A verificação estática passou: 181
arquivos Kof no lint, diagnósticos LSP em 145 arquivos e 164 testes JVM.
Passaram também os gates de exceções, SIMD Buffer limitado, LAN externo,
interações, save durável, gameplay goose, save PE e servidor/rede dedicados.
O `scripts/verify.sh` completo chega a `verify_kof_web_server.sh`, mas falha na
asserção de replicação da coleta de café; portanto, a matriz completa não está
verde. As provas de sintaxe cross-target passaram, mas runtime cross-target e
hardware continuam sem qualificação.

**Resultado local atual:** identidade do archive oficial Kof `0.6.9` e gates
locais de static/JVM, SIMD, exceções, native, pacote e servidor dedicado
passaram. A matriz completa continua bloqueada pela asserção de replicação da
coleta de café no multiplayer web; runtime cross-target e hardware também
continuam sem qualificação.

## 3. Escopo

### Dentro do escopo

- qualificar e, se aceito, pinar o commit atual da branch upstream `lab`;
- extrair semântica de transporte do código de mecanismo nativo;
- qualificar uma ABI batch síncrona explícita;
- substituir um caminho representativo de staging GPU depois de medir;
- opcionalmente fazer batch do staging limitado de persistência;
- documentar a fronteira semântica/raster do SVG;
- remover caminhos escalares obsoletos somente depois do gate correspondente.

### Fora do escopo

- mover `launcher/kookie_launcher.zig` para Kof;
- substituir cross-compilation, link PE ou packaging em Zig;
- mover SDL, SDL_GPU, SDL_mixer, Winsock/POSIX, fsync/rename,
  FreeType/HarfBuzz, threads de worker ou intrinsics SIMD;
- transformar arrays tipados Kof em contrato de layout de memória C;
- introduzir ponteiros nativos retidos ou callbacks no estado do engine;
- substituir o pipeline de shader por um compilador de shader Kof em runtime;
- mudar o wire format do transporte ou a construção criptográfica.

## 4. Frentes de trabalho

### P0 — Pin upstream e baseline

**Entradas:** `scripts/update_kof_lab.py`, `scripts/kof_pin.sh` e
referências ativas de CI/documentação.

**Passos:**

1. Rodar `python3 scripts/update_kof_lab.py --check` imediatamente antes da
   mudança.
2. Se o candidato for adotado, aplicar com
   `--expected-commit 7c237861a9035d84b1f7ec4cfddd89daef4c6ddd` e
   `--expected-version 0.6.6`; nunca atualizar uma referência `lab` móvel de
   forma implícita.
3. Construir o archive exato e registrar commit de origem e hash do archive.
4. Rodar novamente os gates static/JVM, SIMD e native/package com a fonte exata.
5. Atualizar a documentação ativa somente depois de o novo baseline passar ou
   de seus limites estarem registrados de forma explícita.

**Gate de saída:** todas as referências ativas nomeiam
`7c237861a9035d84b1f7ec4cfddd89daef4c6ddd` e os resultados exatos da
qualificação, incluindo o limite restante do native/package, estão registrados.
Nenhuma migração chama a fonte de “latest” antes desse gate.

### P1 — Qualificação da ABI batch

**Entradas:** `docs/KOF_NATIVE_BOUNDARY_SPEC.md`, o probe SIMD atual e os
fixtures C nativos.

**Passos:**

1. Provar que um payload de bytes gerenciado por Kof pode ser preenchido e
   passado a uma chamada nativa sem cópia FFI byte a byte. Se a superfície Kof
   atual não conseguir fazer isso, parar a migração de produção e registrar a
   capacidade upstream ausente.
2. Adicionar fixture limitado de copy-in/copy-back para payloads válidos,
   vazios, máximos e malformados.
3. Verificar cópia imediata para storage próprio de C e rejeição de descriptors
   inválidos.
4. Rodar o fixture em JVM e native x86-64. Manter fallback escalar nos demais
   alvos.

**Gate de saída:** o fixture prova lifetime, limites, cópia, checksum, casos
zero/máximo e paridade escalar. Comentário de fonte ou afirmação upstream não é
suficiente.

**Status atual:** o gate focado `scripts/verify_simd_dispatch.sh` passou com o
arquivo Kof `0.6.6` exato e fixado em JVM e native x86-64. O fixture reportou
`buffer-fixture-sum=809`, `buffer-inout-sum=1231`, totais scalar/SIMD iguais,
rota SIMD selecionada e a prova de sintaxe AArch64. Isso qualifica somente a
fronteira síncrona limitada de producer/copy-back; ownership assíncrono ou de
payload retido genérico continua sem qualificação.


### P2 — Extração da semântica de transporte

**Arquivos candidatos:** `native/kookie_transport.c`,
`native/kookie_transport.h`,
`probes/g0_external_transport_backends/transport_jvm.kf`,
`probes/g0_external_transport_backends/transport_native.kf` e um módulo comum
proposto `src/session/transport_codec.kf`.

**Passos:**

1. Inventariar o código nativo em mecanismo de socket/endereço/timeout versus
   semântica de pacote, sequência, agregação de payload e validação.
2. Mover para Kof o codec comum de endianess e payload somente quando vectors
   JVM/nativo passarem byte a byte contra as implementações atuais.
3. Manter em C criação de socket, endereços de peer, timeout e
   `sendto`/`recvfrom`.
4. Tratar ownership de MAC/chave como gate de segurança separado. Não expor
   material de chave a Kof apenas para remover uma função C. Até esse gate,
   C pode manter framing/MAC enquanto Kof possui semântica de mensagem e
   agregação.
5. Adicionar transporte bruto limitado em bytes somente pela ABI batch; não
   passar `Byte[]` ou `Int[]` assumindo layout C.

**Gate de saída:** vectors LAN/loopback continuam wire-compatible; casos de
payload malformado, replay, sequência stale e peer errado mantêm resultados;
nenhuma chave ou versão de wire muda.

**Status atual:** `src/session/transport_codec.kf` possui os helpers comuns de
endianess/payload; o backend JVM o chama, enquanto C mantém socket, framing,
MAC e chave. O gate completo atual passou a paridade LAN externa JVM/native,
codec, sequência stale/replay e ownership do peer. O gate de saída P2 local
agora está verde; claims de host separado e WAN mais ampla permanecem fora
desse resultado.

### P3 — Um vertical slice de batch GPU

**Primeiro candidato:** staging de vértices de cena pelo descriptor batch
`GPU_SCENE_VERTEX_V1`, mantendo
`kookie_gpu_scene_push_vertex_resource` como fallback escalar; não shaping de
texto, áudio ou handles de dispositivo.

**Passos:**

1. Manter `FrameStaging` e a política de render/pass em Kof.
2. Codificar payload limitado `GPU_SCENE_VERTEX_V1` conforme a especificação
   da ABI.
3. Adicionar entrada C que valida o descriptor, copia para storage próprio e
   alimenta o caminho SDL_GPU existente.
4. Executar caminho escalar e batch sobre o mesmo fixture de frame.
5. Comparar contagem de vertices, checksum, draw count, gerações de recursos e
   captura. Medir chamadas de fronteira, alocações e p95 do frame.
6. Fazer cutover somente se o batch passar os thresholds go/no-go.

**Gate de saída:** paridade semântica e de captura, nenhum ponteiro retido,
nenhuma regressão p95 além da tolerância especificada e fallback escalar ainda
passando.

**Status atual:** os três probes de adapter codificam um batch
`GPU_SCENE_VERTEX_V1` `Buffer(U8)` por frame staged; C valida o descriptor em
duas passagens e copia para storage de cena próprio. O gate completo otimizado
passou o adapter native e o renderer de referência Vulkan em
`Intel(R) Graphics (ARL)`, com uma draw call, 984 instâncias e p95 de
`1710` microssegundos. Isto é evidência Linux local; hardware adicional e
apresentação multiplataforma continuam sendo gates separados.


### P4 — Batch opcional de persistência

**Arquivos candidatos:** `native/kookie_persistence_adapter.c/.h` e o caminho
existente de `BoundedDurableSaveFileCodec/publication`.

Mover somente a chamada de staging limitado de bytes. Kof mantém envelope,
schema, migration, checksum e política de slot. C mantém validação de caminho,
open seguro, fsync ou `FlushFileBuffers`, rename atômico e fault handling.

**Gate de saída:** testes de publicação interrompida, checksum inválido,
recovery e rename durável continuam idênticos; nenhum loop byte a byte é
substituído sem redução medida de chamadas de fronteira.

**Decisão:** nenhum cutover P4 foi selecionado. O adapter de persistência faz
staging com checks de índice/ordem e mantém fault injection, flush, rename e
recovery em C; o gate native de pré-requisito não está verde e nenhuma redução
de chamadas de fronteira foi medida.

### P5 — Split semântico opcional de SVG

`src/content/svg_intake.kf` e `native/kookie_ui_renderer.c` têm responsabilidades
de parsing de shapes sobrepostas. Uma frente futura pode mover admissão e
normalização de shapes para Kof, mas DEVE deixar FreeType/HarfBuzz, buffers de
pixels/depth e rasterização em C.

Esta frente não bloqueia as demais e NÃO DEVE atrasar os gates de transporte ou
batch.

**Decisão:** nenhum cutover P5 foi selecionado. O Kof já possui admissão SVG,
normalização e checksums canônicos; C possui FreeType/HarfBuzz, buffers de
pixel/depth e rasterização. O split proposto não adicionaria uma fronteira
batch qualificada e continua não bloqueante.

### P6 — Limpeza e documentação

Depois de cada cutover aceito:

- remover implementação obsoleta e comentários stale;
- remover entry point escalar quando nenhum caller qualificado restar;
- não manter alias apenas por compatibilidade;
- atualizar páginas de arquitetura, plano, spec e changelog em inglês/português;
- registrar pin, comando, alvo e limite restante exatos.

## 5. Gates de aceite

| Gate | Requisito |
|---|---|
| Baseline | Fonte Kof, pin e archive exatos registrados; static/JVM e SIMD passam; limites native/package explícitos. |
| Comportamento | Batch e escalar produzem a mesma saída, rejeição e estado de lifecycle. |
| Wire | Bytes de transporte, resultados de MAC, sequência/replay e status permanecem compatíveis. |
| Lifetime | C nunca retém ponteiro de Buffer Kof; trabalho assíncrono usa cópia própria de C. |
| Limites | Casos negativo, zero, overflow, stride, capacity, generation, checksum e tamanho máximo são determinísticos. |
| Performance | O workload escolhido reduz chamadas de fronteira em pelo menos 10x ou melhora p95 em pelo menos 5%; p95 NÃO DEVE regredir mais de 2% contra o escalar. |
| Alvos | JVM e native x86-64 medidos; alvos não qualificados mantêm comportamento escalar. |
| Ownership | Nenhum gameplay, política de cena, admissão de asset, composição de shader, durabilidade OS ou scheduler de threads migra para C. |
| Limpeza | Caminhos obsoletos, aliases e comentários enganosos são removidos após o cutover. |

Os thresholds de performance são critérios go/no-go para cutover de produção,
não afirmação de performance de hardware antes da medição.

## 6. Rollback e falhas

Um gate falho interrompe somente a frente afetada. O caminho escalar continua
sendo a implementação funcional até o batch ser provado. Não esconda mismatch
afrouxando validação, alterando checksum, alargando caps ou adicionando fallback
que mude ownership silenciosamente.

Se a fonte Kof atual não conseguir preencher `Buffer(U8)` eficientemente,
registre a capacidade ausente e mantenha arrays Kof limitados com o adapter
escalar verificado. Isso é um resultado aceito; emulação byte a byte do batch
proposto não é.

## 7. Não-decisões explícitas

- Não reescrever `kookie_launcher.zig` em Kof.
- Não substituir pool de threads C, syscalls de socket, primitivas duráveis de
  filesystem, handles SDL, FreeType/HarfBuzz ou kernels SIMD.
- Não tokenizar ponteiros brutos.
- Não criar renderer C genérico ou parser de asset para justificar benchmark.
- Não prometer ABI pública com base em `RUNTIME_ABI.md`; a fronteira do engine é
  comportamental e qualificada por alvo.
