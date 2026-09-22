# Contratos G0 do adaptador escalar

[English](../../docs/G0_SCALAR_ADAPTER.md)

Status: **implementado e exercitado na JVM/nativo**. Este incremento comprova a chamada escalar do ciclo de vida SDL e os contratos de estado pertencentes ao Kof; não afirma uma janela SDL nativa nem um dispositivo de áudio.

## Limite do ciclo de vida SDL

`src/platform/sdl.kf` vincula somente chamadas SDL escalares:

- `SDL_GetVersion(): Int` para a sonda de versão existente;
- `SDL_Init(Int): Bool`;
- `SDL_Quit(): void`.

`SdlLifecycle` possui a flag de inicialização no lado Kof. Rejeita flags negativos, torna a inicialização repetida idempotente e torna o encerramento explícito. `probes/g0_platform/main.kf` chama `SDL_Init(0)` e `SDL_Quit()` nos dois alvos quando `/usr/lib/libSDL3.so` está instalado. `0` solicita deliberadamente nenhum subsistema SDL; isso evita afirmar que a inicialização de vídeo/áudio foi comprovada.

Nenhum ponteiro SDL, struct, união de evento, callback, janela, dispositivo GPU ou dispositivo de áudio atravessa este limite. A limitação medida da FFI permanece: chamadas extern escalares funcionam, enquanto arrays/structs/ponteiros/buffers de saída/callbacks não formam uma binding portável.

## Estado de janela e entrada

`WindowStateTracker` é um contrato de estado pertencente ao Kof para o futuro adaptador de polling:

- foco aceita somente `0` ou `1`;
- redimensionamento aceita somente dimensões positivas;
- fechamento é monotônico para o estado da sessão/frame atual;
- `snapshot()` devolve uma cópia do estado escalar por meio de `WindowState`.

Ele não consulta SDL nem cria uma janela nativa. O futuro adaptador deve achatar eventos SDL nessas transições escalares na thread principal do Kof.

## Estado de áudio enfileirado

`QueuedAudio` é um contrato FIFO limitado, não um backend de áudio:

- ciclo de vida explícito `open()`/`close()`;
- admissão de token de clip positivo e ganho em `[0, 100]`;
- rejeição de overflow por capacidade fixa;
- dequeue FIFO com metadados copiados de clip/ganho;
- nenhum callback para dentro do Kof e nenhuma autoridade estrangeira de mixer.

A classe armazena deliberadamente identidades inteiras de clips, não ponteiros. Um futuro adaptador de áudio SDL poderá consumir entradas verificadas da fila após comprovar um ciclo de vida real de dispositivo.

## Prova de regressão

`src/main.kf` contém o caminho de smoke executável e dois testes nomeados:

- `resource token lifecycle`;
- `platform state and audio queue lifecycle`.

O gate executa os dois testes e compara a saída de smoke JVM/nativa. Quando a biblioteca SDL3 local está disponível, ele também executa a sonda de plataforma escalar; a CI informa um skip explícito quando essa biblioteca de sistema opcional não está disponível:

```bash
kof check src --target jvm
kof check src --target native
kof test src --target jvm
kof test src --target native
kof run src/main.kf --target jvm
kof run src/main.kf --target native
kof run probes/g0_platform/main.kf --target jvm
kof run probes/g0_platform/main.kf --target native
```

Os dois alvos passam nos contratos Kof. A execução nativa ainda emite o aviso conhecido de fallback para runtime completo fora do checkout do compilador. A JVM pode emitir o aviso do JDK sobre acesso nativo restrito para a busca SDL direta; o resultado do ciclo de vida continua bem-sucedido.

## Próximo limite de comprovação

O próximo spike somente nativo deve usar display isolado e comprovar criação/desmontagem de janela SDL, polling de eventos, transições de foco/redimensionamento e um ciclo de vida de dispositivo de áudio enfileirado a partir do ELF emitido. Deve adicionar um adaptador ABI C estreito para dados de ponteiro/struct/evento, em vez de converter ponteiros SDL em tokens inteiros. Não rotule estes contratos Kof como prova de dispositivo ou GPU.
