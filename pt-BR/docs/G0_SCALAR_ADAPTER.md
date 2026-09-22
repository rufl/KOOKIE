# Contratos G0 do adaptador escalar

[English](../../docs/G0_SCALAR_ADAPTER.md)

Status: **implementado e exercitado no compilador JVM/nativo**. Este incremento adiciona um adaptador C SDL estreito e contratos de estado pertencentes ao Kof. O smoke nativo de janela/áudio está conectado, mas sua execução em display isolado foi adiada por pressão; nenhum dispositivo GPU ou draw texturizado é afirmado.

## Limite do ciclo de vida SDL

`src/platform/sdl.kf` vincula chamadas SDL escalares:

- `SDL_GetVersion(): Int` para a sonda de versão;
- `SDL_Init(Int): Bool`;
- `SDL_Quit(): void`.

`SdlLifecycle` possui a flag de inicialização no lado Kof. Rejeita flags negativos, torna a inicialização repetida idempotente e torna o encerramento explícito. `probes/g0_platform/main.kf` chama `SDL_Init(0)` e `SDL_Quit()` nos dois alvos quando `/usr/lib/libSDL3.so` está instalado. `0` solicita deliberadamente nenhum subsistema SDL; isso não comprova inicialização de vídeo/áudio.

A binding direta do Kof ainda não transporta ponteiro SDL, struct, união de evento, callback, janela ou dispositivo de áudio. A limitação medida da FFI Kof permanece: chamadas extern escalares funcionam, enquanto arrays/structs/ponteiros/buffers de saída/callbacks não formam uma binding portável.

## Adaptador nativo estreito

`native/kookie_sdl_adapter.c` é o glue ABI permitido para o limite bloqueado de ponteiros/structs. Ele possui ponteiros SDL e expõe somente resultados escalares verificados:

- criação/destruição de janela com tokens por slot+geração+tipo;
- rejeição de token de janela obsoleto ou de tipo incorreto;
- `SDL_PollEvent` achatado para tipo de evento mais dois campos escalares;
- abertura/fechamento do dispositivo de playback padrão com tokens por slot+geração+tipo;
- encerramento explícito que destrói janelas pertencentes ao adaptador e fecha o áudio.

O adaptador não retém ponteiros Kof, callbacks, estado de gameplay, entidades nem buffers de amostras de áudio. `probes/g0_native_adapter/main.kf` exercita criação/destruição de janela oculta, polling escalar de eventos, abertura/fechamento de dispositivo playback dummy e rejeição de token obsoleto.

## Estado de janela e entrada

`src/core/window_state.kf` fornece o contrato de estado pertencente ao Kof:

- foco aceita somente `0` ou `1`;
- redimensionamento aceita somente dimensões positivas;
- fechamento é monotônico para o estado da sessão/frame atual;
- `snapshot()` devolve uma cópia do estado escalar por meio de `WindowState`.

O adaptador nativo agora achata eventos SDL, mas aplicar eventos ao estado ainda é o próximo limite de integração. O loop Kof continua autoritativo.

## Estado de áudio enfileirado

`src/core/audio_queue.kf` é um contrato FIFO limitado:

- ciclo de vida explícito `open()`/`close()`;
- admissão de token de clip positivo e ganho em `[0, 100]`;
- rejeição de overflow por capacidade fixa;
- dequeue FIFO com metadados copiados de clip/ganho;
- nenhum callback para dentro do Kof e nenhuma autoridade estrangeira de mixer.

O adaptador nativo comprova apenas abertura/fechamento do dispositivo. Os dados da fila ainda não são enviados ao SDL; o próximo passo de áudio deve escolher um contrato limitado de transferência PCM sem introduzir uma segunda autoridade de mixer.

## Prova de regressão

`src/main.kf` contém o caminho de smoke executável e dois testes nomeados:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`.

O gate também verifica a sonda do adaptador nativo Kof. Quando headers SDL3, `gcc`, `pkg-config` e `overzeer-isolated-display` estão disponíveis, ele compila o adaptador, emite o ELF nativo da sonda e o executa pelo wrapper de display isolado com áudio dummy. Quando essas dependências faltam, a CI registra um skip explícito. A tentativa atual em display isolado foi adiada pelo gate de pressão do wrapper; ela precisa ser repetida antes de chamar o smoke gráfico/áudio de aceito.

```bash
bash scripts/verify.sh
kof check probes/g0_native_adapter/main.kf --target native
```

As sondas escalares locais passaram na JVM/nativo. As verificações de fonte Kof, testes e builds passam na JVM/nativo. A execução nativa ainda emite o aviso conhecido de fallback para runtime completo fora do checkout do compilador; a JVM pode emitir o aviso do JDK sobre acesso nativo restrito para a busca SDL direta.

## Próximo limite de comprovação

Reexecute o smoke nativo do adaptador em display isolado e registre a aceitação de janela/áudio. Em seguida, aplique os eventos achatados ao `WindowStateTracker`, adicione uma transferência PCM limitada e meça a configuração de janela/dispositivo SDL_GPU. Não converta ponteiros SDL em tokens inteiros, adicione callbacks para dentro do Kof nem rotule estes contratos como prova de GPU/renderização texturizada.
