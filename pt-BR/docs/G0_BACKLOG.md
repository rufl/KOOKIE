# Backlog de implementação G0

[English](../../docs/G0_BACKLOG.md)

Esta é a sequência ativa e limitada de implementação após os commits iniciais de pesquisa e contratos.

## Concluído

- Fontes Kof modulares `core`/`session` e sonda escalar de SDL3.
- Documentação bilíngue e gate de verificação antes do push.
- Tokens de recursos pertencentes ao Kof, verificados por slot, geração e tipo.
- JVM/native smoke e dois testes nomeados de regressão.
- Ciclo escalar `SDL_Init(0)`/`SDL_Quit()` exercitado na JVM/nativo.
- Estado Kof de foco/redimensionamento/fechamento e FIFO de áudio com capacidade limitada.

## Próximo lote

1. Adicionar um adaptador ABI nativo pequeno para armazenar ponteiros pertencentes ao SDL atrás de tokens inteiros verificados. Sem propriedade de gameplay, ponteiros crus, callbacks ou buffers em massa.
2. Comprovar criação e desmontagem de uma janela SDL a partir do ELF nativo usando o wrapper de display isolado do repositório.
3. Achatar eventos SDL reais para o estado Kof de foco/redimensionamento/fechamento. O loop Kof continua autoritativo.
4. Comprovar um único ciclo de dispositivo de áudio enfileirado sem adicionar uma segunda autoridade de mixer.
5. Medir staging escalar para um draw texturizado limitado antes de escolher uma mudança de FFI de buffers.
6. Reexecutar o reproduzível do manipulador de exceções nativo e os controles negativos com o compilador fixado antes de confiar na limpeza por exceção.
7. Registrar toda falha medida ou limite de aceitação nas duas árvores de idioma.

## Adiado

- Renderer de malha texturizada e pipeline de shaders além do primeiro draw de smoke.
- Mapeamento de entrada, câmera, loopback servidor/cliente e predição.
- Colisão, armas, inimigos, cooking de conteúdo, schema de saves e transporte multiplayer.
- Áudio de produção, serviços de imagem/texto, compressão de pacotes e bibliotecas estrangeiras de física/UI.

Não substitua uma capacidade nativa bloqueada por fallback JVM, engine C oculta, stub de falso sucesso ou scaffold gráfico não verificado.
