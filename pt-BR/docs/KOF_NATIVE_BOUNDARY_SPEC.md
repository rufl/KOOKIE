# Fronteira nativa Kof e ABI batch síncrona do KOOKIE

[English](../../docs/KOF_NATIVE_BOUNDARY_SPEC.md)

Status: **PROPOSTO**. Decisão: `D-KOF-NATIVE-BOUNDARY`.

Este documento define a fronteira entre semântica do engine pertencente ao Kof
e mecanismos nativos de plataforma. É um contrato comportamental para os
adapters do KOOKIE, não uma ABI C pública e estável do Kof.

Os termos RFC 2119 são normativos: **MUST**, **MUST NOT**, **SHOULD**,
**SHOULD NOT** e **MAY**. O texto em português preserva os identificadores
normativos em inglês.

## 1. Contrato de ownership

### Kof DEVE possuir

- gameplay, simulação, tick fixo e estado autoritativo;
- semântica de pacotes/mensagens, agregação de payload e política de protocolo;
- admissão de conteúdo, codecs e checksums pertencentes ao engine;
- câmera, projeção, visibilidade, ordenação, batching e política de passes;
- layout de UI, runs semânticos de texto, política de sound cues e gerações de
  recursos;
- envelope de save, schema, migration, seleção de slot e política de publicação;
- validação dos valores antes da passagem pela fronteira nativa.

### C nativo DEVE possuir

- handles e chamadas de SDL3, SDL_GPU e SDL_mixer;
- sockets POSIX/Winsock, estruturas de endereço e syscalls de timeout;
- descritores/handles seguros, fsync ou `FlushFileBuffers`, rename atômico e
  proteção de path/reparse;
- shaping/rasterização FreeType/HarfBuzz e storage nativo de pixels/depth;
- threads de worker, filas e storage nativo de conclusão;
- detecção CPUID/NEON/AVX2/SSE2 e kernels intrinsics;
- glue de entrada/saída PE e setup/teardown de bibliotecas estrangeiras.

C MUST NOT virar dono de gameplay, algoritmos de cena, admissão de asset,
ordenação de render, schema de save, autoridade de pacote ou composição de UI.

### Zig DEVE possuir

- mecânica segura de download/update de release;
- HTTP/TLS, extração de archives, verificação de assinatura e launch de processo;
- cross-compilation, link PE e glue de packaging.

O launcher não é candidato a esta ABI batch de runtime. Política pura de
manifest MAY ser compartilhada no futuro somente se uma implementação Kof
cross-target for provada e não houver duas autoridades de segurança.

## 2. Baseline FFI existente

1. Chamadas escalares `extern` são a fronteira padrão para handles, status,
   contagens, gerações e descriptors pequenos.
2. Ponteiros nativos MUST NOT ser convertidos em IDs inteiros de recurso. Tokens
   inteiros são índices em registries nativos com validação e geração.
3. `Int[]`, `Float[]`, records e collections genéricas Kof MUST NOT ser passados
   para C assumindo layout contíguo ou estável.
4. `Buffer(U8)` está qualificado atualmente somente para uso síncrono e limitado
   em JVM e native x86-64. Claims de outros targets não são qualificação KOOKIE.
5. O ponteiro de Buffer é válido somente durante a chamada `extern`. C MUST NOT
   retê-lo, enfileirá-lo, entregá-lo a callback estrangeiro ou usá-lo depois do
   retorno.
6. Qualquer operação nativa assíncrona ou retida MUST copiar para storage próprio
   de C antes do retorno da chamada.
7. Exceções MUST NOT atravessar a fronteira C. Falha é resultado escalar
   limitado mais getter existente de diagnóstico/status.
A qualificação local P1 agora prova preenchimento por `buffer.poke8` do Kof,
uma chamada nativa INOUT limitada e copy-back na JVM e no native x86-64. Isso
não qualifica uma ABI batch de produção para GPU, áudio, transporte ou
persistência.

## 3. Contrato comum Batch V1

Batch V1 é uma família de chamadas por subsistema que compartilha as mesmas
regras de validação. Não é um struct nativo empacotado e não expõe headers de
objetos Kof nem detalhes de allocator.

### 3.1 Campos do descriptor

Toda chamada batch DEVE validar os campos escalares abaixo quando aplicáveis:

| Campo | Significado | Regra |
|---|---|---|
| `kind` | Identificador do schema do payload | Somente valor conhecido; kind desconhecido é rejeitado. |
| `schemaVersion` | Versão do schema | V1 é `1`; não reinterpretar silenciosamente. |
| `byteLength` | Bytes válidos no Buffer | `0 <= byteLength <= cap do subsistema`. |
| `elementCount` | Records ou words | Não negativo e limitado. |
| `stride` | Bytes por elemento fixo | Schemas fixos exigem stride exato. |
| `capacity` | Capacidade do destino | DEVE cobrir o payload solicitado. |
| `generation` | Geração de recurso/publicação | Deve coincidir com a geração ativa quando exigido. |
| `checksum` | Checksum calculado por Kof | Deve coincidir com os bytes declarados antes do commit. |

Um subsistema MAY omitir campos sem significado, mas MUST NOT inventar ponteiro
ou length implícito. Aritmética `elementCount * stride` MUST ser verificada
antes da multiplicação e MUST ser igual a `byteLength` em schemas de records
fixos.
Para símbolos específicos de subsistema abaixo, `kind` é fixado pelo nome do
símbolo. `schemaVersion` continua sendo argumento escalar explícito; uma entry
point genérica MUST passar `kind` e `schemaVersion`.

### 3.2 Formas de chamada propostas

O símbolo C exportado pode seguir o naming existente do subsistema, mas seu
comportamento DEVE seguir estas formas:

```kof
Bool kookie_gpu_scene_submit_batch(
    Buffer(U8) payload,
    Int schemaVersion,
    Int byteLength,
    Int vertexCount,
    Int stride,
    Int generation,
    Long checksum
)
Int kookie_transport_receive_wire_batch(
    Buffer(U8) destination,
    Int schemaVersion,
    Int capacity,
    Int generation
)
Bool kookie_transport_send_wire_batch(
    Buffer(U8) wire,
    Int schemaVersion,
    Int byteLength,
    Long checksum
)
Bool kookie_persistence_stage_batch(
    Buffer(U8) bytes,
    Int schemaVersion,
    Int byteLength,
    Long checksum
)
```

Estas são entry points nativas propostas, não aliases de compatibilidade. Uma
chamada receive retorna o número de bytes copiados, ou resultado/status negativo
documentado; Kof lê o copy-back somente após o retorno. Uma chamada send, GPU
submit ou persistence stage DEVE rejeitar antes de mutar estado nativo quando a
validação falhar.

### 3.3 Lifetime e ownership

- Kof possui os arrays semânticos de origem e seu checksum.
- O adapter possui a representação nativa copiada depois do retorno.
- C MUST copiar somente `byteLength` bytes.
- C MUST NOT ler além de `byteLength`, mesmo se a alocação do Buffer for maior.
- C MUST NOT reter o ponteiro Kof.
- Mismatch de generation MUST rejeitar o batch sem publicação parcial.
- Mismatch de checksum MUST rejeitar o batch sem publicação parcial.
- O caminho escalar MUST permanecer disponível até o gate de cutover
  correspondente passar.

### 3.4 Encoding dos bytes

V1 evita deliberadamente arrays de ponto flutuante tipados.

- Schemas de bytes crus não têm endianess adicional.
- Records inteiros fixos usam campos signed 32-bit little-endian (`i32_le`).
- Valores são validados em Kof antes do encoding e defendidos novamente em C.
- Nenhum objeto Kof, header de array, ponteiro de string ou ponteiro nativo é
  serializado.

## 4. Schemas de payload V1

### `GPU_SCENE_VERTEX_V1`

Cada record contém seis campos `i32_le`, stride `24`:

```text
resource, x, y, depth, u, v
```

O payload é staging semântico. C valida capacity e tokens de recurso, copia
para o storage de cena existente e mantém handles e draw submission de SDL_GPU
em C.

A primeira fatia vertical de GPU agora implementa a forma exata
`kookie_gpu_scene_push_vertex_batch_v1(Buffer(U8), schemaVersion, byteLength,
vertexCount, stride, generation, checksum)`. O Kof codifica
`GPU_SCENE_VERTEX_V1` com `buffer.poke8`, calcula o checksum limitado da soma
dos seis campos semânticos e faz uma chamada batch por frame staged. C rejeita
schema, length, stride, generation, checksum e campos inválidos antes da
publicação, depois copia para o storage de cena existente. Os probes do adapter
usam esse caminho primeiro e mantêm a chamada escalar de resource como fallback.

Isso registra o contrato de fonte implementado, não uma alegação de
qualificação runtime native; continuam necessários evidência de captura e p95
específicas do target.

### `GPU_WORLD_VERTEX_V1`

Cada record contém seis campos `i32_le`, stride `24`:

```text
resource, x, y, z, u, v
```

Câmera/projeção, visibilidade, seleção de material e ordem de passes continuam
sendo política Kof. C somente valida, copia, faz upload e submete.

### `GPU_WORDS_V1`

Sequência limitada de words `i32_le`, stride `4`. Cobre staging de textura,
atlas mundial e words de câmera somente quando já existe caminho escalar com
count e capacity declarados. Não dá a C autoridade sobre admissão de textura ou
semântica de câmera.

### `GPU_TEXTURE_BYTES_V1`

Payload opaco limitado de bytes. Kof MUST admitir e calcular checksum do range
de origem antes da chamada. C MAY decodificar formato admitido ou fazer upload
dos bytes, mas MUST NOT virar autoridade de admissão ou cooking do formato de
origem.

### `TRANSPORT_WIRE_V1`

Os bytes atuais do wire, incluindo header existente e resultado MAC, permanecem
compatíveis. Este plano não altera magic, version, ordem de words, campos de
sequência, limites de pacote nem a construção criptográfica.

No primeiro cutover C MAY continuar responsável por framing e MAC/keys. Mover
codec ou MAC para Kof exige gate separado de ownership de chave e segurança. A
ABI batch sozinha MUST NOT expor material de chave a Kof.

O payload máximo atual é limitado por `KOOKIE_TRANSPORT_MAX_WORDS` e pelo
limite de header existente. O adapter MUST rejeitar lengths acima do cap de
wire configurado.

### `SAVE_BYTES_V1`

Range limitado de bytes de save produzido pelo codec Kof. C grava exatamente os
bytes copiados e continua responsável por paths seguros, durabilidade, publicação
atômica e fault injection. Kof continua responsável por schema, checksum,
migration e política de slot.

## 5. Contrato de migração do transporte

1. `native/kookie_transport.c` MUST manter runtime de socket, peers, timeout e
   I/O OS até decisão explícita posterior.
2. Kof MAY possuir agregação e validação comuns de payload em um módulo comum
   proposto `src/session/transport_codec.kf` somente após vectors JVM/nativo
   coincidirem byte a byte.
3. MAC e keys MUST permanecer onde a revisão de segurança os colocar. Nenhuma
   migração é justificada apenas para reduzir linhas C.
4. Peer errado, header malformado, MAC inválido, sequência stale, replay e
   overflow de capacity MUST manter resultados e diagnósticos atuais.
5. A versão do wire MUST NOT mudar nesta migração.
6. Backend JVM e backend nativo MAY usar I/O diferente, mas MUST expor a mesma
   semântica de mensagem e as mesmas regras de rejeição Kof.

## 6. Contrato de migração GPU e persistência

- Kof MUST produzir o mesmo descriptor semântico de frame/save nos caminhos
  escalar e batch.
- C MUST validar e copiar antes de qualquer operação assíncrona de GPU/áudio/
  arquivo.
- C MUST NOT fazer parsing de gameplay, scene graph, schema de save ou layout
  de UI.
- Um caminho batch MUST expor fallback escalar determinístico para targets não
  qualificados.
- O primeiro alvo batch GPU é vertex de cena. Shaping de texto, streams de
  áudio, recovery de device-loss e recursos GPU retidos não fazem parte da V1.
- Batch de persistência MUST NOT enfraquecer fsync/`FlushFileBuffers`, rename
  atômico, segurança de path ou recovery de publicação interrompida.

## 7. Erro e atomicidade

Um batch rejeitado MUST:

- retornar `false`, count negativo ou resultado/status limitado existente;
- deixar o estado de publicação/destino nativo inalterado;
- evitar writes parciais visíveis a draw, send, save ou recovery posteriores;
- reportar diagnóstico limitado suficiente para o probe Kof identificar a classe
  da rejeição.

O adapter MUST rejeitar valores negativos, overflow inteiro, schema não
suportado, stride errado, overflow de capacity, mismatch de generation,
mismatch de checksum e payload acima do limite do subsistema.

## 8. Matriz de qualificação

| Superfície | JVM | Native x86-64 | PE/outros targets |
|---|---|---|---|
| Externs escalares | qualificados pelo gate static/JVM existente | qualificados pelos probes nativos | gate específico por target |
| Copy-in/copy-back `Buffer(U8)` | qualificado pelo fixture SIMD | qualificado pelo fixture SIMD | não qualificado até medição |
| Batch de cena GPU | obrigatório antes do cutover | obrigatório antes do cutover | fallback escalar |
| Batch de wire de transporte | obrigatório se o backend usar | obrigatório se o backend usar | mecanismo atual/escalar |
| Batch de persistência | obrigatório se o backend usar | obrigatório se o backend usar | fallback escalar |
| Ponteiro/callback retido | proibido | proibido | proibido |
| Ownership assíncrono de Buffer Kof | proibido | proibido | proibido |

Um target não é qualificado porque o compilador contém uma implementação ou a
documentação faz uma afirmação. Ele é qualificado somente por fixture executável
e pelo gate KOOKIE correspondente.

## 9. Testes exigidos antes de remover caminhos escalares

1. Descriptors válidos, vazios, máximos e malformados.
2. Paridade exata de saída e checksum entre batch e escalar.
3. Avanço de generation, generation stale e cancelamento.
4. Tamanho de copy-back e preservação de bytes zero/high-bit.
5. Vectors de wire, MAC, replay, sequência stale e peer errado.
6. Contagem de vertices, generation de recurso, draw count e captura de frame.
7. Falha de checksum de save, stage interrompido, recovery e publicação atômica.
8. Rodadas repetidas de warmup/medição registrando chamadas de fronteira,
   alocações, p95 e memória residente máxima.
9. Execução JVM e native x86-64; fallback escalar explícito nos demais alvos.

A entry point escalar só pode ser removida quando todos os callers estiverem
migrados, a matriz relevante estiver verde e o gate correspondente do plano
estiver registrado.
