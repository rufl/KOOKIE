# Fronteira reutilizável de UI e mídia em Kof/KofScript

Este documento fixa a responsabilidade da UI reutilizável no KOOKIE e o caminho
de migração para a biblioteca padrão oficial do Kof4j. É um contrato de
arquitetura, não um segundo framework de UI.

## Decisão

Usar primeiro os primitivos oficiais do Kof4j:

- `kof.ui` é dono de cores, temas, janelas, widgets, handles de layout,
  componentes, estado, eventos, Canvas e tokens de design.
- `kof.media` é dono das operações de mídia em arquivo/handle: `Image.open`,
  `Audio.openWav`, `Video.open`, `Mic.record/list`, metadados e exportação de
  bytes de imagem/áudio.
- KOOKIE é dono da skin visual do GatoGanso, manifests de assets publicados,
  apresentação nativa em `FrameStaging` e composição específica do jogo.
- KofScript é dono de descritores semânticos limitados. Não retém handles de
  `kof.ui` nem ponteiros nativos; um host Kof/KofJS consome os descritores.

A implementação atual de `kof.ui` no Kof4j renderiza em KofJS e mantém
intencionalmente handles no-op em JVM/native. A API atual de `kof.media` não
possui banco de cues de som de baixa latência nem método de reprodução. Por
isso o KOOKIE adiciona somente um adaptador semântico de cues/fila sobre o
contrato limitado existente de `QueuedAudio`. Ele não duplica `kof.ui`, não
decodifica mídia e não cria outro renderer.

## Auditoria da ABI do 0.5.0-beta

A baseline ativa de qualificação do KOOKIE é o fonte do Kof4j
[`bf17ac7e`](https://github.com/KofLang/Kof4j/tree/bf17ac7e736471c8a04b4153e5b0f607be75e70c).
A CLI local reporta `kof 0.5.0-beta`.

A implementação fixada e a documentação upstream mais recente não são
idênticas:

- [`KofBuffer.java`](https://github.com/KofLang/Kof4j/blob/bf17ac7e736471c8a04b4153e5b0f607be75e70c/kof-compiler/src/main/java/dev/kof/compiler/KofBuffer.java)
  expõe `buffer.alloc(Int)` e `Buffer.bytes()` em JVM, JS e nativo
  x86-64; os comentários da fonte também afirmam suporte a riscv64/aarch64.
- [`CompilerFfiBinding.java`](https://github.com/KofLang/Kof4j/blob/bf17ac7e736471c8a04b4153e5b0f607be75e70c/kof-compiler/src/main/java/dev/kof/compiler/CompilerFfiBinding.java)
  baixa `Buffer(U8)` como token `B` e ponteiro de payload síncrono na
  implementação nativa fixada. `scripts/verify_simd_dispatch.sh` exercita
  cópia de entrada/retorno e uma redução INOUT em JVM e nativo x86-64.
- A [documentação ABI do `main` mais recente](https://github.com/KofLang/Kof4j/blob/317d9f6b1c3e27032cc955a05f859f6c627d9338/learn/stdlib/buffer.md)
  ainda marca Native como `FFI001`. O suporte cross é, portanto, uma
  afirmação da fonte upstream, não um resultado de qualificação do KOOKIE.
- [`RUNTIME_ABI.md`](https://github.com/KofLang/Kof4j/blob/bf17ac7e736471c8a04b4153e5b0f607be75e70c/docs/runtime/RUNTIME_ABI.md)
  é um contrato comportamental do runtime, não uma ABI C pública estável.
  O KOOKIE não deve copiar headers de objetos, layouts de arrays ou detalhes
  do alocador para uma biblioteca de engine.

Decisão no KOOKIE: usar `Buffer(U8)` somente em fixtures síncronas, limitadas
e qualificadas por target, como a sonda SIMD. Não inferir uma ABI tipada de
vértices/áudio, reter o ponteiro do payload nem entregá-lo a trabalho que
sobrevive à chamada. Manter `FrameStaging`, `QueuedAudio` e wires de conteúdo
como arrays limitados possuídos pelo Kof; o nativo copia para sua própria
memória.

Um upload em lote futuro poderá usar descritor explícito de cópia de entrada
com schema, comprimento em bytes/palavras, stride, capacidade, generation e
checksum. Ele precisa de fixtures C específicas por target e deve preservar o
adaptador escalar verificado até ownership, lifetime e frame-time serem medidos.
Nenhum ponteiro cru, array Kof retido ou segundo renderer atravessa a fronteira.

## Mapa de responsabilidade

| Concern | Dono reutilizável atual | Destino no Kof4j | Fronteira |
| --- | --- | --- | --- |
| Composição row/column/stack/panel | Helpers de skin `KookieUiLayout*` | Primitivos de layout `kof.ui` | A skin escolhe tokens; Kof4j possui os handles |
| Botões, campos, toggles, sliders e feedback | `kookie_ui_components.kf` | Widgets/componentes `kof.ui` | Composição de jogo/editor fica local até existir API genérica upstream |
| Fontes e tipografia | `font_catalog.kf`, `KookieUiText` | `kof.ui.Font` e tokens de design | Arquivos/catálogo de fontes continuam assets do pacote |
| Referências SVG/PNG | `KookieUiAsset`, manifest gerado | `kof.ui.Image`/`Icon`, `kof.media.ImageData` | Manifest verifica publicação; runtime decodifica |
| Intake de áudio | Intake WAV/OGG em `content` | `kof.media.Audio` | Decodificação e empacotamento ficam na fronteira de conteúdo |
| Efeitos sonoros da UI | `KookieUiSoundCue` + `KookieUiSoundBank` | Futura API de playback/cues em `kof.media` | Fila transporta clip IDs; adapter nativo possui decode/playback |
| UI em KofScript | `KookieUiScriptDocument` | Futuro pacote oficial de descritores | Sem handles, sem ponteiros, estado limitado |
| HUD nativo de gameplay | `kookie_ui_native.kf` + `FrameStaging` | Não é substituto de `kof.ui` | Um renderer nativo existente e budgets fixos |

## Primeira fatia implementada

`src/ui/kookie_ui_audio.kf` adiciona um contrato reutilizável e neutro quanto ao
target:

- `KookieUiSoundCue` valida source `.ogg`/`.wav` relativo ao pacote, label
  semântico não vazio, digest SHA-256 minúsculo, clip ID nativo positivo e gain
  padrão em `0..100`.
- `KookieUiSoundBank` registra um conjunto limitado antes de abrir, enfileira
  efeitos one-shot ou espaciais via `core.QueuedAudio`, preserva FIFO e expõe
  clip/gains consumidos para o adapter nativo. Não decodifica arquivos nem
  retém handles SDL.
- `kookie_ui_audio_catalog.kf` é a fronteira de publicação nativa:
  `kookieUiPublishedSoundCue` vincula tuplas exatas de source/digest aos 14
  clip IDs OGG nativos, e `kookieUiSoundBankAddPublished` admite somente esses
  cues. `KookieUiSoundBank.add()` genérico continua disponível para adapters
  externos e publicação WAV futura.

`src/ui/kookie_ui.ks` expõe o mesmo sound node no descritor KofScript:
`bindSound(..., defaultGain)`, `nodeClipId()` e `nodeGain()`, além das constantes
de tipo OGG/WAV. O descritor só registra dados semânticos e participa das regras
existentes de checksum/ciclo de vida.

## Migração para o Kof4j

### Fase 1 — repositório atual

1. Reutilizar `kof.ui` e `kof.media`, sem adicionar intrinsics no compilador.
2. Manter no KOOKIE somente skin/tokens/manifests e composição fina.
3. Usar o adaptador de sound cues para efeitos nativos do jogo; manter
   validação de arquivo e staging do pacote separados do playback.
4. Manter descritores KofScript limitados e consumidos pelo host.

### Fase 2 — contribuição upstream

1. Propor um contrato de som neutro quanto ao target em `kof.media` somente após
   definir ownership, close, gain, loop, espacialização e falhas para KofJS,
   JVM e native.
2. Mover descritores genéricos e testes para o Kof4j somente quando KofScript
   possuir uma fronteira oficial de import/module para eles. Até lá, o gate local
   por concatenação é o ponto de integração honesto.
3. Mover comportamento genérico de layout/widget para `kof.ui`; manter no
   KOOKIE apenas tokens GatoGanso, IDs de assets e composição de jogo.
4. Substituir cada wrapper local nos callsites e só então remover o wrapper
   obsoleto. Não adicionar aliases nem shims de compatibilidade.

### Invariantes de aceite

- Um renderer de UI autoritativo por target.
- Nenhuma autoridade de jogo, ponteiro nativo ou decoder escondido em classe
  reutilizável de UI.
- Referências raster/vector/audio publicadas são relativas ao pacote e têm
  digest verificado na fronteira de publicação.
- Kof e KofScript expõem estado semântico e regras de rejeição equivalentes.
- Probes JVM/native permanecem determinísticos mesmo com `kof.ui` no-op.
- KofJS é o único target que afirma renderização real de `kof.ui` até os outros
  contratos de target serem fechados no Kof4j.
