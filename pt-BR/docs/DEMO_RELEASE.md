# Prontidão da release de demo jogável

[English](../../docs/DEMO_RELEASE.md)

Esta página é a autoridade para diferenciar um artefato de qualificação de uma
demo do KOOKIE voltada a jogadores. O projeto possui evidência forte de engine
limitada, mas uma cena de qualificação renderizada não é gameplay.

## Estado público atual

A release pública mais recente é [`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34),
publicada em 2026-09-30. Ela contém um único arquivo de apresentação SDL
assinado para Linux x86-64, construído a partir do commit
`4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`. Ela antecede a qualificação atual
de PE/SDL nativo Windows e a correção do gate P95 da CI hospedada. Nenhum
arquivo atual de demo Windows foi publicado.

A árvore de fontes atual possui estes caminhos aptos a release:

- Empacotamento de apresentação nativa SDL3/SDL_GPU para Linux x86-64 com
  SDL_mixer, procedência assinada e smoke fora do checkout.
- Ligação de gameplay Kof PE nativo Windows x86-64 ao shell SDL e ao pacote de
  apresentação SDL_GPU, com produtos SPIR-V/DXIL e gates de artefato
  reproduzíveis.
- Smoke em Wine do shell nativo Windows com marcadores de gameplay. O smoke
  visual de apresentação continua opcional e exige GPU isolada capaz de DRI3;
  ligação de pacote ou saída Xvfb não é evidência de apresentação visual.
- Pipeline de pacote dogfood Linux assinado e pacote Windows JVM separado para
  compatibilidade/qualificação. O pacote JVM não é fallback do jogo nativo.

## O que “demo jogável” significa neste milestone

Uma fatia vertical limitada G1 é suficiente. Ela não precisa incluir todo o
roadmap de looter/ARPG, hospedagem WAN pública, modding geral ou todos os
importadores de fonte. Nos dois alvos suportados, ela precisa:

1. iniciar a partir de um pacote extraído limpo, sem toolchain Kof ou checkout;
2. entrar em uma sessão real de servidor local mais cliente local;
3. mapear teclado e mouse para registros `InputCommand` limitados e olhar da
   câmera;
4. mover, saltar, mirar e disparar pela sessão autoritativa;
5. mostrar pelo menos um encontro, dano, morte, feedback e estado de HUD;
6. oferecer um fim/reinício determinístico; e
7. fechar corretamente após vários ciclos de iniciar/jogar/reiniciar.

A tela `Play` atual não satisfaz essa definição. O shell Kof renderiza a cena
preparada de arena/HUD e trata menu, opções, lobby e Kutter; as ações na tela de
gameplay não são mapeadas para um loop de input/tick da sessão. O shell SDL
Windows também desenha uma tela de jogo estática depois do smoke do marcador PE.
São superfícies de qualificação, não um loop jogável completo.

## Trabalho faltante, ordenado por impacto na release

### P0 — loop jogável compartilhado

- Adicionar um loop voltado ao jogador que leia input da plataforma, gere
  `InputCommand` validado, avance o servidor local autoritativo e aplique
  predição/reconciliação no estado renderizado.
- Ligar teclado, mouse relativo e ao menos um conjunto de controles alternativo
  documentado a movimento, olhar, disparo, salto, interação, pausa e reinício.
  Preservar a perda de foco e a liberação de botões mantidos já cobertas pelos
  contratos da engine.
- Conectar os contratos existentes de combate/sessão/HUD/áudio ao frame de
  apresentação. A primeira demo pode usar uma arena, uma arma e um papel de
  inimigo, mas precisa mostrar transições reais, não apenas um draw estático.
- Definir fim e reset da demo: por exemplo, limpar um encontro, alcançar a saída,
  mostrar o resultado e reiniciar sem relançar o processo.

### P0 — integração de gameplay nativo Windows

- Substituir o caminho estático `draw_game` do Windows pelo mesmo gameplay Kof
  autoritativo usado no Linux. `kookie_kof_gameplay_main` atualmente comprova a
  entrada PE ligada e retorna o marcador do smoke; não é um loop interativo
  completo.
- Mapear eventos de teclado, mouse e janela SDL do Windows para o contrato de
  gameplay compartilhado e provar o pacote PE nativo fora do checkout.
- Executar o smoke de apresentação em hardware/driver Windows suportado. A
  evidência de artefato e marcador em Wine é útil, mas não substitui uma
  afirmação de apresentação nativa Windows.

### P1 — empacotamento e distribuição

- Gerar um novo arquivo de apresentação Linux assinado a partir de árvore limpa
  e fonte pós-G6, publicando arquivo, manifesto, chave pública, assinaturas
  destacadas e `SHA256SUMS` juntos.
- Gerar e publicar um ZIP nativo de apresentação Windows x86-64 assinado, com as
  DLLs SDL exatas, shaders, avisos e procedência.
- Verificar os dois arquivos em máquinas novas fora do checkout: extrair,
  iniciar, jogar, reiniciar, sair e repetir depois de validar assinatura/checksum.
- Documentar o piso de loader/libc/GPU Linux e de GPU/driver Windows x86-64. O
  pacote Linux usa loader/libc do host; SDL3 e SDL_mixer são empacotados, mas
  compatibilidade com qualquer distribuição não é implícita.
- Adicionar notas de release com controles, limitações conhecidas, dependências
  e identidades exatas de commit/toolchain. Assinatura Authenticode é opcional
  para um ZIP dogfood interno, mas ainda falta se o arquivo Windows for voltado
  a usuários comuns sem alertas do SmartScreen.
- Adicionar um workflow de release aprovado manualmente ou um checklist
  operacional explícito. O workflow atual de verificação checa componentes,
  mas não gera nem publica os arquivos atuais de demo Linux e Windows como par.

### P1 — conteúdo e limite do produto demo

- Decidir se a primeira demo envia a arena autoral fixa de qualificação ou um
  pacote de conteúdo separado. O perfil de assets protótipo é opt-in e não está
  automaticamente ligado ao caminho de gameplay da apresentação.
- Empacotar somente assets com termos de redistribuição resolvidos. O asset goose
  do protótipo continua restrito pelos termos upstream e não pode ser rotulado
  como CC0 nem incluído silenciosamente em uma demo pública.
- Declarar explicitamente que LAN/WAN, edição Kutter, KofScript, save/replay e
  progressão ARPG completa são recursos de qualificação/engine, salvo se a demo
  os expuser e suportar de ponta a ponta.

## Matriz de aceitação antes da publicação

| Verificação | Linux x86-64 | Windows x86-64 |
|---|---:|---:|
| Pacote extraído limpo inicia | Obrigatório | Obrigatório |
| Assinatura/checksum/procedência verificados | Obrigatório | Obrigatório |
| Menu/opções/input/áudio/redimensionamento | Obrigatório | Obrigatório |
| Loop real de gameplay autoritativo local | Obrigatório | Obrigatório |
| Dano/morte/HUD/resultado/reinício | Obrigatório | Obrigatório |
| Smoke repetido fora do checkout | Obrigatório | Obrigatório |
| Evidência de apresentação em hardware nativo | GPU Linux suportada | GPU Windows suportada |
| Multiplayer entre hosts | Opcional na primeira demo single-player | Opcional na primeira demo single-player |

## Explicitamente não bloqueia esta demo

Amplitude completa de ARPG, suporte geral a formatos de autoria, segurança WAN
de produção, NAT traversal/relay, HRTF/EFX, áudio em streaming/comprimido,
sandbox geral de extensões, macOS/ARM e cobertura ampla de GPUs continuam sendo
milestones separados. Eles não devem ser usados para chamar a superfície atual
estática de jogável, mas também não precisam bloquear uma demo G1 claramente
limitada.

O plano de implementação acompanha este trabalho como **D1 — Release de demo
jogável** em [ENGINE_PLAN.md](ENGINE_PLAN.md). Os comandos de build e
qualificação continuam em
[RUNNING_AND_PACKAGING.md](RUNNING_AND_PACKAGING.md).
