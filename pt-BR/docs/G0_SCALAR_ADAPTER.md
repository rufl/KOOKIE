# Contratos G0 do adaptador escalar

[English](../../docs/G0_SCALAR_ADAPTER.md)

Status: **implementado e exercitado na JVM/nativo e em apresentação isolada com janela real**. A fronteira C estreita cobre ciclo de vida SDL, clips sintetizados limitados, upload/draw SPIR-V da cena e estado de eventos pertencente ao Kof. A sonda nativa atual de apresentação reporta capacidade válida de swapchain, desenha e captura a cena criada de 252 vértices e consome o clip `201` do evento autoritativo de combate; evidências específicas da máquina permanecem fora do repositório.


## Limite do ciclo de vida SDL

`src/platform/sdl.kf` vincula chamadas SDL escalares:

- `SDL_GetVersion(): Int` para a sonda de versão;
- `SDL_Init(Int): Bool`;
- `SDL_Quit(): void`.

`SdlLifecycle` possui a flag de inicialização no lado Kof. Rejeita flags negativos, torna a inicialização repetida idempotente e torna o encerramento explícito. `probes/g0_platform/main.kf` chama `SDL_Init(0)` e `SDL_Quit()` nos dois alvos quando `/usr/lib/libSDL3.so` está instalado. `0` solicita deliberadamente nenhum subsistema SDL; isso não comprova inicialização de vídeo/áudio.

A binding direta do Kof ainda não transporta ponteiro SDL, struct, união de evento, callback, janela, dispositivo GPU ou dispositivo de áudio. A limitação medida da FFI Kof permanece: chamadas extern escalares funcionam, enquanto arrays/structs/ponteiros/buffers de saída/callbacks não formam uma binding portável.

## Adaptador nativo estreito

`native/kookie_sdl_adapter.c` é o glue ABI permitido para o limite bloqueado de ponteiros/structs. Ele possui ponteiros SDL e expõe somente resultados escalares verificados:

- criação/destruição de janela com tokens por slot+geração+tipo;
- rejeição de token de janela obsoleto ou de tipo incorreto;
- `SDL_PollEvent` achatado para tipo de evento mais dois campos escalares;
- abertura/fechamento de stream de áudio playback padrão com tokens por slot+geração+tipo;
- transferência PCM limitada de silêncio e clip para o stream SDL, sem callback;
- criação/claim/release/destruição de dispositivo SDL_GPU SPIR-V atrás de token verificado;
- primeiro shader, upload de textura, sampler, pipeline e draw para swapchain;
- ordem explícita de encerramento: liberar claim GPU, destruir dispositivo GPU, destruir janelas, destruir stream de áudio.

O adaptador não retém ponteiros Kof, callbacks, estado de gameplay, entidades nem buffers de amostras pertencentes ao Kof. `probes/g0_native_adapter/main.kf` exercita criação/destruição de janela oculta, polling real de eventos SDL para `WindowStateTracker`, enfileiramento sintético de resize/foco, ciclo GPU opcional com o primeiro upload/draw, abertura/fechamento de dispositivo playback dummy, transferência PCM limitada de silêncio e clip e rejeição de token obsoleto.

## Estado de janela e entrada

`src/core/window_state.kf` fornece o contrato de estado pertencente ao Kof:

- foco aceita somente `0` ou `1`;
- redimensionamento aceita somente dimensões positivas;
- fechamento é monotônico para o estado da sessão/frame atual;
- `applyNativeEvent(kind, dataA, dataB)` mapeia os tipos de adaptador `1..4` para transições de fechamento, resize e foco;
- `snapshot()` devolve uma cópia do estado escalar por meio de `WindowState`.

O adaptador achata eventos SDL, enquanto o Kof possui a política de transição e o loop autoritativo. A sonda consulta a saída do adaptador e aplica tipos de evento e payloads escalares a um `WindowStateTracker` Kof; o smoke isolado continua sendo o limite de aceitação para comportamento gerado pelo SO.

## Estado de áudio enfileirado

`src/core/audio_queue.kf` é um contrato FIFO limitado:

- ciclo de vida explícito `open()`/`close()`;
- admissão de token de clip positivo e ganho em `[0, 100]`;
- rejeição de overflow por capacidade fixa;
- dequeue FIFO com metadados copiados de clip/ganho;
- nenhum callback para dentro do Kof e nenhuma autoridade estrangeira de mixer.

O adaptador nativo comprova um ciclo real de stream de áudio SDL, transferência limitada de silêncio e variantes determinísticas de clips sintetizados (`clipId=1` e clips de impacto `201`–`203`, no máximo 480 frames estéreo F32). A sonda de apresentação agora seleciona o clip `201` a partir do evento confirmado da eliminação autoritativa. A FFI escalar ainda não transporta um buffer de amostras pertencente ao Kof; o próximo limite de áudio é propriedade explícita do buffer e mixagem de produção, não uma segunda autoridade de gameplay.

## Ciclo de vida GPU

O adaptador solicita suporte SPIR-V, cria um dispositivo SDL_GPU, faz claim de uma janela SDL, envia a paleta semântica e vértices limitados da cena por transfer buffers, submete o draw de swapchain, aguarda o GPU ficar ocioso e libera os recursos. O caminho revisado de display isolado já registrou `gpu-open`, capacidade positiva de swapchain, conclusão do draw, captura de screenshot e saída limpa; ambientes indisponíveis continuam falhando de modo fechado como `gpu-unavailable`.

## Prova de regressão

`src/main.kf` contém o caminho de smoke executável e três testes nomeados:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`;
- `frame staging ownership and scalar measurement`.

`scripts/verify_exception.sh` preserva o reproduzível do lifetime de exceções nativas e seus controles negativos JVM/nativo: a JVM termina na asserção falha; o nativo atualmente chega a `unreachable` com exit 0. Isso é um registro de defeito do compilador, não uma garantia de limpeza do engine.

O gate também verifica a sonda do adaptador nativo Kof. Quando headers SDL3, `gcc`, `glslc`, `pkg-config` e um `KOOKIE_PRESENTATION_ISOLATION_WRAPPER` revisado estão disponíveis, ele compila o adaptador e os shaders SPIR-V, emite o ELF nativo da sonda e o executa pelo wrapper com áudio dummy. Quando essas dependências faltam, a CI registra um skip explícito.

```bash
bash scripts/verify.sh
```

O gate materializa links temporários para os pacotes Kof canônicos ao compilar sondas independentes e os remove ao sair. Checks, testes e builds Kof passam na JVM/nativo. O adaptador C compila com `-Wall -Wextra -Werror`; shaders compilam por `glslc`; staging fixo da cena, timing positivo de draw, captura de screenshot e teardown de recursos são exercitados dentro do display isolado.

A sonda drena eventos SDL preexistentes por um helper nativo escalar limitado.
Manter o loop de drain em C evita uma falha medida do compilador nativo em que
atribuir um `Int` extern dentro daquele loop Kof emitia uma chamada inválida a
`kof_unbox_int`; o crash estava no código gerado da sonda, não no SDL.

## Próximo limite de comprovação

O trabalho de produção agora começa além de G0: propriedade explícita dos
buffers de amostra entre Kof/nativo, mixagem/espacialização, notificação real de
perda de dispositivo SDL e retirement limitado de recursos sob carga
sustentada. Não converta ponteiros SDL em tokens inteiros, adicione callbacks
para dentro do Kof nem infira esses contratos a partir da sonda qualificada de
cena/clip.
