# Backlog de implementação G0

[English](../../docs/G0_BACKLOG.md)

Esta é a sequência ativa e limitada de implementação após os commits iniciais de pesquisa e contratos.

## Concluído

- Fontes Kof modulares `core`/`session` e sonda escalar de SDL3.
- Documentação bilíngue e gate de verificação antes do push.
- Tokens de recursos pertencentes ao Kof, verificados por slot, geração e tipo.
- Smoke JVM/nativo e dois testes nomeados de regressão.
- Ciclo escalar `SDL_Init(0)`/`SDL_Quit()` exercitado na JVM/nativo.
- Estado Kof de foco/redimensionamento/fechamento e FIFO de áudio com capacidade limitada.
- Adaptador C SDL estreito com tokens verificados de janela/áudio e flattening escalar de eventos.
- Sonda do adaptador nativo e conexão opcional da verificação em display isolado.

## Próximo lote

1. Reexecutar o smoke do adaptador nativo após o gate de pressão permitir; registrar aceitação de janela e áudio dummy.
2. Aplicar os campos achatados de tipo/dados de evento ao `WindowStateTracker` no loop principal Kof.
3. Adicionar um caminho limitado de transferência PCM da fila de áudio Kof sem callbacks nem segunda autoridade de mixer.
4. Adicionar configuração de dispositivo/janela SDL_GPU atrás do mesmo ciclo de vida explícito do adaptador e comprovar a ordem de desmontagem.
5. Medir staging escalar para um draw texturizado limitado antes de escolher uma mudança de FFI de buffers.
6. Reexecutar o reproduzível do manipulador de exceções nativo e os controles negativos com o compilador fixado antes de confiar na limpeza por exceção.
7. Registrar toda falha medida ou limite de aceitação nas duas árvores de idioma.

## Adiado

- Renderer de malha texturizada e pipeline de shaders além do primeiro draw de smoke.
- Mapeamento de entrada, câmera, loopback servidor/cliente e predição.
- Colisão, armas, inimigos, cooking de conteúdo, schema de saves e transporte multiplayer.
- Áudio de produção, serviços de imagem/texto, compressão de pacotes e bibliotecas estrangeiras de física/UI.

Não substitua uma capacidade nativa bloqueada por fallback JVM, engine C oculta, stub de falso sucesso ou scaffold gráfico não verificado.
