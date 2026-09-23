# Backlog de implementação G0

[English](../../docs/G0_BACKLOG.md)

Esta é a sequência ativa e limitada de implementação após os commits iniciais de pesquisa e contratos.

## Concluído

- Fontes Kof modulares `core`/`session` e sonda escalar de SDL3.
- Documentação bilíngue e gate de verificação antes do push.
- Tokens de recursos pertencentes ao Kof, verificados por slot, geração e tipo.
- Smoke JVM/nativo e três testes nomeados de regressão.
- Ciclo escalar `SDL_Init(0)`/`SDL_Quit()` exercitado na JVM/nativo.
- Estado Kof de foco/redimensionamento/fechamento e FIFO de áudio com capacidade limitada.
- Adaptador C SDL estreito com tokens verificados de janela/áudio/GPU e flattening escalar de eventos.
- Transferência PCM limitada de silêncio e clip determinístico para um stream de áudio SDL sem callbacks.
- Sonda do adaptador nativo aplicando eventos reais do adaptador ao estado Kof e executando o primeiro caminho de upload/draw de textura SPIR-V.
- Contrato limitado de staging de frame Kof medido em 15 escritas escalares para um triângulo texturizado de três vértices, com verificações de ownership de publish/discard.
- Reproduzível do lifetime de exceção nativa e controles negativos registrados no gate de verificação.
- Adaptador nativo expõe timing decorrido de draw GPU após retirement com GPU ocioso.
- Relógio de fixed-step G1, comandos de input limitados com transições de borda fire/jump, sincronização de snapshot servidor/cliente em loopback e storage limitado de componentes inteiros.
- Admissão de dois clientes em loopback G1, sequência de input por cliente, rejeição de snapshot obsoleto, movimento autoritativo limitado e clamp de câmera/input.
- Smoke nativo isolado aceitou ciclo de vida da janela oculta, flattening de resize/focus, áudio dummy, teardown de tokens obsoletos e limpeza de processos; a GPU ficou indisponível para apresentação em janela.
- Histórico limitado de snapshots do cliente com interpolação inteira e limites explícitos de autoridade de predição/reconciliação.
- Consultas escalares limitadas de colisão com resolução de movimento no limite e rejeição de posicionamento fora dos limites.
- Histórico limitado de inputs de predição (capacidade oito) com replay após reconciliação autoritativa; o estado do servidor continua autoritativo.
- Consultas limitadas de sweep de segmento 3D inteiro em volume alinhado aos eixos, rejeitando penetração inicial e traversal acima do orçamento.
- Consultas limitadas de triângulo inteiro com rejeição de triângulo degenerado e resolução na amostra anterior.
- Movimento limitado do centro de cápsula com limites expandidos pelo raio e admissão compartilhada de jogador/projétil/linha de visão.
- Dispositivo SDL_GPU offscreen isolado e draw indexado de quad SPIR-V aceitos com uploads explícitos de buffers de vértices/índices e recursos GPU em cache por dispositivo; o smoke mais recente mediu 1675 microssegundos para três draws contra o orçamento declarado de 16.667 microssegundos em `renderD128`, com uma amostra de 527 microssegundos de espera da fence.
- O relógio fixed-step expõe o orçamento declarado de frame a 60 Hz para as verificações de aceitação da GPU.
- O staging de frame aceita um quad texturizado de seis vértices dentro de um orçamento limitado de 30 escritas escalares.
- Coleções limitadas de triângulos usam um BVH binário determinístico de capacidade fixa com seleção do hit mais próximo, remoção/rebuild, revisões de geometria e diagnósticos de traversal.
- O movimento limitado de cápsula retorna resultados autoritativos de slide/step sobre uma coleção de oito obstáculos de step ordenados deterministicamente, com operações de limpeza/reconfiguração.
- Sessões autoritativas possuem a coleção limitada de triângulos broad-phase, passam sua revisão de geometria com snapshots de consulta, rejeitam consultas obsoletas, expõem um contrato limitado de payload inteiro e aplicam payloads em uma coleção do cliente com guardas de sequência.
- Filas limitadas de transporte broad-phase copiam payloads validados para armazenamento fixo de pacotes, rejeitam overflow sem descartar dados enfileirados e conduzem a replicação do cliente por dequeue/apply.
- A admissão de movimento espacial combina limites de cápsula com consultas de triângulos broad-phase e rejeita revisões de geometria obsoletas.
- O smoke isolado de sobreposição GPU submete quatro frames em dois slots de destino, aposenta todas as fences e reporta a profundidade máxima em voo.
- O smoke de recuperação GPU headless destrói e recria o dispositivo, reconstrói recursos em cache e conclui um draw após a recuperação.
- O transporte nativo UDP de peer envia e recebe frames broad-phase inteiros autenticados entre sockets de datagrama pareados no localhost; o framing SipHash cobre versão do protocolo, tamanho, sequência e palavras com sinal, com chaves de teste configuráveis, timeout fixo de recebimento de 1.000 ms e limites de pacote.
- O estado de recuperação GPU expõe unavailable/ready/lost/failed e um bitmask de capacidades sensível ao estado: ready suporta reopen limpo e o marcador explícito de perda, enquanto lost retém apenas reopen; rejeita recuperação sem dispositivo headless ativo e reconstrói recursos após a recuperação.
- A sonda de capacidade de apresentação GPU informa formato de swapchain e modos suportados quando um dispositivo de janela é reivindicado; Xvfb ainda não consegue reivindicar o caminho de apresentação.

## Próximo lote

1. Adicionar um caminho de apresentação isolado compatível com DRI3 para screenshots de janela; Xvfb continua incompatível com apresentação.
2. Reexecutar o reproduzível do handler de exceções nativas após upgrade do compilador; o gate atual continua observado e passando.
3. Integrar o frame UDP autenticado com um endpoint de sessão remoto e gestão de chaves de produção; configuração IPv4 do peer e limites do endpoint já estão cobertos.
4. Adicionar callbacks reais SDL/perda do dispositivo e semântica de retirement de recursos; o caminho atual usa um marcador explícito de perda.
5. Registrar cada nova falha medida ou limite de aceitação nas duas árvores de idioma.

## Adiado

- Física completa, armas, inimigos, cooking de conteúdo, schema de save e transporte multiplayer.
- Áudio de produção, serviços de imagem/texto, compressão de pacotes e bibliotecas estrangeiras de física/UI.


Não substitua uma capacidade nativa bloqueada por fallback JVM, engine C oculta, stub de falso sucesso ou scaffold gráfico não verificado.
