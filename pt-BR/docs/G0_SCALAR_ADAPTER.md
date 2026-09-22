# Contratos G0 do adaptador escalar

[English](../../docs/G0_SCALAR_ADAPTER.md)

Status: **implementado e exercitado no compilador JVM/nativo**. Este incremento adiciona glue C SDL estreito de ciclo de vida de janela/áudio/GPU, transferência PCM limitada de clip, o primeiro caminho de upload/draw texturizado com SPIR-V e contratos de estado de eventos pertencentes ao Kof. O smoke nativo de janela/áudio/GPU está conectado, mas sua execução em display isolado foi adiada por pressão; nenhum draw texturizado aceito é afirmado.

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

O adaptador nativo agora comprova um ciclo real de stream de áudio SDL, transferência limitada de silêncio e um descritor de clip limitado (`clipId=1`, no máximo 480 frames estéreo F32). O adaptador gera esse payload determinístico porque a FFI escalar ainda não transporta um buffer de amostras pertencente ao Kof; o próximo limite de áudio é propriedade explícita do buffer, não uma segunda autoridade de mixer.

## Ciclo de vida GPU

O adaptador solicita suporte SPIR-V, cria um dispositivo SDL_GPU, faz claim da janela SDL oculta, envia uma textura RGBA limitada 2x2 por transfer buffer, faz sampling em um pipeline de triângulo, submete um draw de swapchain, espera o GPU ficar ocioso e libera os recursos. Falha de GPU é reportada como `gpu-unavailable`; a execução bem-sucedida só é aceita quando a sonda isolada registrar `gpu-open` e conclusão.

## Prova de regressão

`src/main.kf` contém o caminho de smoke executável e três testes nomeados:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`;
- `frame staging ownership and scalar measurement`.

`scripts/verify_exception.sh` preserva o reproduzível do lifetime de exceções nativas e seus controles negativos JVM/nativo: a JVM termina na asserção falha; o nativo atualmente chega a `unreachable` com exit 0. Isso é um registro de defeito do compilador, não uma garantia de limpeza do engine.

O gate também verifica a sonda do adaptador nativo Kof. Quando headers SDL3, `gcc`, `glslc`, `pkg-config` e `overzeer-isolated-display` estão disponíveis, ele compila o adaptador e os shaders SPIR-V, emite o ELF nativo da sonda e o executa pelo wrapper de display isolado com áudio dummy. Quando essas dependências faltam, a CI registra um skip explícito. As tentativas atuais em display isolado foram adiadas pelo gate de pressão do wrapper; elas precisam ser repetidas antes de chamar o smoke de janela/áudio/GPU de aceito.
```bash
bash scripts/verify.sh
```
O gate materializa links temporários para o pacote canônico `src/core` enquanto compila a sonda independente e os remove ao sair. As verificações de fonte Kof, testes e builds passam na JVM/nativo. O adaptador C compila com `-Wall -Wextra -Werror`; as fontes de shader compilam por `glslc`; o contrato de frame registra 15 escritas escalares e retirement explícito para o triângulo de três vértices. A função de timing do adaptador mede a submissão completa do draw até o retirement com GPU ocioso; ela permanece não aceita até a sonda isolada registrá-la.

A sonda drena eventos SDL preexistentes por um helper nativo escalar limitado.
Manter o loop de drain em C evita uma falha medida do compilador nativo em que
atribuir um `Int` extern dentro daquele loop Kof emitia uma chamada inválida a
`kof_unbox_int`; o crash estava no código gerado da sonda, não no SDL.

## Próximo limite de comprovação

Reexecute o smoke nativo em display isolado e registre a aceitação de janela/áudio/GPU e o timing decorrido do draw. Compare essa medição com o orçamento de frame; a contagem de tuplas escalares e o contrato de ownership já estão registrados. Não converta ponteiros SDL em tokens inteiros, adicione callbacks para dentro do Kof nem chame o caminho GPU opcional de aceito sem evidência isolada.
