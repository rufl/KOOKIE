# Contratos G0 do adaptador escalar

[English](../../docs/G0_SCALAR_ADAPTER.md)

Status: **implementado e exercitado no compilador JVM/nativo**. Este incremento adiciona glue C SDL estreito de ciclo de vida de janela/áudio/GPU, transferência PCM limitada de silêncio e contratos de estado pertencentes ao Kof. O smoke nativo de janela/áudio/GPU está conectado, mas sua execução em display isolado foi adiada por pressão; nenhum draw texturizado aceito é afirmado.

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
- transferência PCM limitada de silêncio para o stream SDL, sem callback;
- criação/claim/release/destruição de dispositivo SDL_GPU SPIR-V atrás de token verificado;
- ordem explícita de encerramento: liberar claim GPU, destruir dispositivo GPU, destruir janelas, destruir stream de áudio.

O adaptador não retém ponteiros Kof, callbacks, estado de gameplay, entidades nem buffers de amostras pertencentes ao Kof. `probes/g0_native_adapter/main.kf` exercita criação/destruição de janela oculta, enfileiramento sintético de resize/foco SDL e polling escalar, ciclo GPU opcional, abertura/fechamento de dispositivo playback dummy, transferência limitada de silêncio e rejeição de token obsoleto.

## Estado de janela e entrada

`src/core/window_state.kf` fornece o contrato de estado pertencente ao Kof:

- foco aceita somente `0` ou `1`;
- redimensionamento aceita somente dimensões positivas;
- fechamento é monotônico para o estado da sessão/frame atual;
- `applyNativeEvent(kind, dataA, dataB)` mapeia os tipos de adaptador `1..4` para transições de fechamento, resize e foco;
- `snapshot()` devolve uma cópia do estado escalar por meio de `WindowState`.

O adaptador achata eventos SDL, enquanto o Kof possui a política de transição e o loop autoritativo. Os eventos inseridos pela sonda verificam a ABI de flattening; a aceitação de foco/redimensionamento gerados pelo SO continua parte do smoke isolado.

## Estado de áudio enfileirado

`src/core/audio_queue.kf` é um contrato FIFO limitado:

- ciclo de vida explícito `open()`/`close()`;
- admissão de token de clip positivo e ganho em `[0, 100]`;
- rejeição de overflow por capacidade fixa;
- dequeue FIFO com metadados copiados de clip/ganho;
- nenhum callback para dentro do Kof e nenhuma autoridade estrangeira de mixer.

O adaptador nativo agora comprova um ciclo real de stream de áudio SDL e transferência PCM limitada de silêncio. Ele ainda não envia payloads de clips Kof; o próximo passo de áudio deve escolher um contrato limitado de propriedade/transferência PCM sem introduzir uma segunda autoridade de mixer.

## Ciclo de vida GPU

O adaptador solicita suporte SPIR-V, cria um dispositivo SDL_GPU, faz claim da janela SDL oculta e libera o claim antes de destruir o dispositivo. Falha de GPU é reportada como `gpu-unavailable` pela sonda, não convertida em falso sucesso. Nenhum shader, pipeline, transfer buffer, textura ou draw atravessa o limite ainda.

## Prova de regressão

`src/main.kf` contém o caminho de smoke executável e dois testes nomeados:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`.

O gate também verifica a sonda do adaptador nativo Kof. Quando headers SDL3, `gcc`, `pkg-config` e `overzeer-isolated-display` estão disponíveis, ele compila o adaptador, emite o ELF nativo da sonda e o executa pelo wrapper de display isolado com áudio dummy. Quando essas dependências faltam, a CI registra um skip explícito. As tentativas atuais em display isolado foram adiadas pelo gate de pressão do wrapper; elas precisam ser repetidas antes de chamar o smoke de janela/áudio/GPU de aceito.

```bash
bash scripts/verify.sh
kof check probes/g0_native_adapter/main.kf --target native
```

As verificações de fonte Kof, testes e builds passam na JVM/nativo. O adaptador C compila com `-Wall -Wextra -Werror`. A execução nativa ainda emite o aviso conhecido de fallback para runtime completo fora do checkout do compilador; a JVM pode emitir o aviso do JDK sobre acesso nativo restrito para a busca SDL direta.

## Próximo limite de comprovação

Reexecute o smoke nativo em display isolado e registre a aceitação de janela/áudio/GPU. Em seguida, encaminhe eventos reais do SO ao loop Kof, substitua o silêncio por transferência limitada de clips e adicione o primeiro caminho de upload/draw SDL_GPU. Não converta ponteiros SDL em tokens inteiros, adicione callbacks para dentro do Kof nem rotule o código de ciclo de vida do adaptador como prova de renderização texturizada.
