# Executando e empacotando o KOOKIE

[English](../../docs/RUNNING_AND_PACKAGING.md)

Esta página mantém os detalhes de build, pacote e qualificação fora da página
inicial do projeto. O KOOKIE é experimental: estes comandos exercitam contratos
de evidência limitados, não uma promessa de suporte de produção.

## Execução de fonte/desenvolvimento

Instale [Kof 0.5.0-beta](https://github.com/KofLang/Kof4j) para executar o
entrypoint autoritativo da fonte na raiz do repositório:

```bash
kof run src/main.kf --target native
```

Este comando é um caminho de qualificação em console. Ele não inicia o jogo
interativo empacotado. O próprio `kof run` não exige Python 3; Python é usado
atualmente pelo lint do repositório, validação de pacote/procedência,
validação de evidências e tooling de rendezvous.

O pacote de apresentação publicado é autossuficiente: jogadores iniciam seu
entrypoint `kookie`/`kookie.exe` sem instalar Kof ou Python. Um launcher
auto-instalável, autoatualizável e com canais stable/beta/alpha/canary ainda não
foi publicado; consulte [Prontidão da release demo](DEMO_RELEASE.md) para os
gates atuais de pacote e hardware-alvo.

### Limite do launcher

O launcher solicitado para o fluxo do jogador ainda não foi implementado nem
publicado. Mantenha duas responsabilidades separadas:

- **Launcher do jogador:** baixa e inicia somente pacotes KOOKIE assinados. Não
  deve instalar o compilador Kof nem exigir Python em runtime.
- **Bootstrap de desenvolvimento:** opcionalmente instala o toolchain Kof exato
  e fixado necessário para qualificação da fonte e então executa os comandos de
  desenvolvimento.

Stable, beta, alpha e canary são canais de release, não checkouts arbitrários
de branches Git. Cada canal precisa de um manifesto assinado contendo alvo,
versão, URL do artefato, SHA-256, assinatura, identidade do Kof e metadados
mínimos de runtime. O launcher deve embutir a chave pública de release, validar
HTTPS junto com a assinatura do manifesto e o hash do artefato, preparar a
atualização em um diretório novo, trocar atomicamente, manter uma versão para
rollback e exigir opt-in explícito para canais não-stable. Nunca deve executar
um download `latest` sem assinatura nem substituir uma instalação em execução.

O repositório atualmente não possui binários nativos do launcher, manifestos de
canal assinados, artefatos Kof publicados para esses canais nem política
Authenticode para Windows. Até existirem, execuções diretas da fonte exigem
Kof; os gates completos de qualificação, pacote e evidências exigem Python
adicionalmente, enquanto o pacote assinado continua sendo o caminho do usuário.


O alvo JVM é usado para qualificação diferencial local e para o pacote de
compatibilidade Windows explícito:

```bash
kof run src/main.kf --target jvm
```

Ele não é fallback silencioso do Linux nem do perfil de apresentação SDL
nativo. Somente `--runtime jvm --target windows-x86_64` distribui uma JVM.

Execute a sonda focada de gameplay e replay com:

```bash
bash scripts/verify_interactions.sh
```

Execute a sonda focada de gansos contra bots, sessão e overlay com:

```bash
bash scripts/verify_goose_game.sh
```

Execute a sonda focada do lobby multiplayer e do placar com:

```bash
bash scripts/verify_multiplayer_ui.sh
```

## Kooker de conteúdo

O launcher de desenvolvimento admite somente os subconjuntos de fonte
limitados e documentados. Ele rejeita entradas inválidas, grandes demais ou
incompatíveis sem publicar um produto bem-sucedido.

```bash
scripts/kooker.sh cook map level.map level.kmesh
scripts/kooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kooker.sh cook blockbench character.bbmodel character.kchar
scripts/kooker.sh cook png texture.png texture.rgba.png
scripts/kooker.sh cook wav effect.wav effect.pcm16.wav
scripts/kooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kooker.sh inspect-package level.kpkg
scripts/kooker.sh validate-package kutter.kpkg
```

Os formatos de fonte são entradas de autoria, não formatos de pacote do
runtime. Os arquivos Linux incluem um `kooker` nativo para os comandos
`cook` acima; a montagem e a inspeção de pacotes continuam no launcher de
desenvolvimento JVM.

## Produtos KofScript offline e sandbox

O wrapper KofScript emite artefatos canônicos de comportamento, animação e
bytecode de sandbox sem duplicar seus schemas de runtime:

```bash
scripts/kookie_kofscript_builder.sh behavior build/enemy.kofart
scripts/kookie_kofscript_builder.sh animation build/player-animation.kofart
scripts/kookie_kofscript_builder.sh script build/bounty.kofart
```

Execute um artefato de sandbox contra um evento de domínio admitido em qualquer
alvo Kof:

```bash
scripts/kookie_kofscript_runtime.sh build/bounty.kofart 7 1 3 1 42 2 20
KOOKIE_KOFSCRIPT_RUNTIME_TARGET=native \
  scripts/kookie_kofscript_runtime.sh build/bounty.kofart 7 1 3 1 42 2 20
```

A VM tem fluxo somente para a frente, orçamentos fixos de
pilha/instruções/saídas e saídas protegidas por máscaras de capacidade. Ela não
tem opcode de filesystem, rede, handle nativo nem array bruto; a carga do
artefato ocorre fora da sandbox.

## Pacote Linux assinado

O builder de release exige uma árvore de fonte limpa, identidade exata do
código-fonte Kof, digest verificado da distribuição Kof e uma chave Ed25519
privada do owner:

```bash
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64
```

A chave privada deve ser um arquivo regular com modo `0600`. O builder emite
um arquivo direcionado ao Linux, assinaturas separadas do arquivo e do
manifesto, `SHA256SUMS`, uma chave pública e JSON de procedência. A procedência
vincula o commit limpo, o commit fixado do código-fonte Kof, o hash do JAR do
compilador e o hash do arquivo da distribuição.

Todo arquivo Linux também contém:

- `kookie-server`, servidor de carga limitada independente de gráficos;
- `kooker`, kooker nativo e limitado de fontes;
- `kookie-simd-bench`, sonda de paridade e tempo escalar/SIMD.

O servidor informa contagens, orçamentos de trabalho, tempos
p50/p95/p99/máximo por tick, faixa de RSS, checksum e estabilidade lógica de
recursos. Ele é ferramenta de qualificação, não um serviço de hospedagem de
produção empacotado. A decisão de rota SIMD é saída de medição para sua carga
de redução exata, não uma afirmação de ganho geral.

## Pacote de conteúdo protótipo

O primeiro perfil de conteúdo adiciona um catálogo de assets limitado e
assinado em `content/prototype`. Ele inclui modelos GLB convertidos dos pacotes
modular e Classic64, o goose animado solicitado, PNGs VFX autorais, derivados
PNG limitados para runtime, saídas RGBA8 do kooker e os avisos de licença
originais. A opção é explícita para manter os pacotes existentes sem conteúdo:

```bash
KOOKIE_VERSION=0.1.0-dogfood.prototype \
KOOKIE_BUILD_ID=prototype-content \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target linux-x86_64 \
  --content prototype
```

`assets/prototype/manifest.json` vincula caminhos de origem, SHA-256 dos
arquivos de origem, saídas convertidas, grades de frames e avisos de licença.
`PROVENANCE.txt` e o JSON assinado registram o digest determinístico da árvore
de conteúdo protótipo e as contagens de assets/arquivos.

Os avisos modular, Brackeys VFX e Classic64 identificam fontes CC0. A página do
goose não é CC0: permite uso comercial e edição, mas proíbe revender ou
redistribuir o arquivo do modelo. Ele permanece limitado ao protótipo por
solicitação explícita; não redistribua esse asset como CC0.

O catálogo protótipo também contém a fonte e o GLB do gato low-poly atribuído a
Prildarill. A página de origem permite uso e edição e diz que crédito não é
obrigatório; o KOOKIE mantém a atribuição voluntariamente. Não há licença SPDX
nem concessão explícita de redistribuição do arquivo bruto, portanto a fonte e
o GLB do gato permanecem apenas protótipo e não devem ser anunciados como CC0
ou como um pacote de assets independente.

## Pacote de apresentação SDL para Linux

Gere a apresentação persistente SDL3/SDL_GPU usada para qualificação visual
isolada e releases dogfood assinados:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64
```

Para smoke de extração e assinaturas de um pacote em árvore limpa:

```bash
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/verify_linux_presentation_package.sh
```

Para um artefato de release, gere dois pacotes byte-a-byte idênticos e escreva
o conjunto verificado em um diretório de saída vazio:

```bash
KOOKIE_VERSION=0.1.0-demo.N \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/build_demo_release.sh \
  --target linux-x86_64 \
  --version 0.1.0-demo.N \
  --output /tmp/kookie-demo-linux
```

O builder exige árvore limpa e não afirma evidência de GPU nativa do alvo.
O lote de qualificação de 2026-10-02 passou
`verify_linux_presentation_package.sh` com um prefixo temporário fixado de
SDL_mixer 3.2.4. Verificou arquivo assinado, extração segura e package-smoke no
checkout atual; não comprovou GPU Linux com capacidade de apresentação nem a
release pareada final em árvore limpa.

Esse perfil exige SDL 3.4.16, SDL_mixer 3.2.4, `glslc`, compilador C e
`pkg-config`. O arquivo contém a aplicação Kof de menu/jogo, adaptador SDL,
shaders SPIR-V, SDL3 e SDL_mixer. Ele usa o loader dinâmico e a libc do host.
Arquivos de apresentação também incluem `DEMO_CONTROLS.txt`; a primeira demo
usa o perfil de conteúdo `none` e não redistribui assets do protótipo.

### Controles

- Menu principal: setas ou WASD.
- Selecionar: Enter, Espaço ou clique do mouse.
- Voltar: Escape.
- `Play`: encounter autoritativo local servidor listen/cliente; voltar com
  Escape e entrar novamente em `Play` redefine o encounter limitado.
- Opções: 1280×720 até 2560×1440, janela/sem borda/tela cheia exclusiva,
  volumes separados para efeitos e música e três tamanhos de texto.
- Acessibilidade: escala do HUD (`SMALL` 85%, `MEDIUM` 100%, `LARGE` 115%),
  visibilidade do mapa tático e texto de alto contraste. As mudanças entram ao
  vivo na shell de apresentação e mantêm os orçamentos fixos de staging.
- Multiplayer: Host, Join e Leave com campos editáveis de IPv4 e porta.
  Depois que o peer conectar, selecione `READY` nos dois clientes antes de
  abrir o gameplay; o lobby mostra identidade limitada, contagem de jogadores
  e placeholder honesto de ping até existir RTT.
- Durante o gameplay, `Tab` alterna a tela de jogadores com nome, status, score,
  vida, K/D e ping. `--` significa que o RTT ainda não está disponível.

Mudanças de vídeo só são efetivadas em Apply. Os pacotes do lobby usam tags
SipHash e sequências contra replay. Uma chave compartilhada configurada de 128
bits autentica peers; o fallback local apenas detecta corrupção acidental. O
lobby não fornece criptografia nem identidade pública.
### Qualificação da GUI

O polimento da shell e as configurações de acessibilidade são cobertos pelos
probes limitados de modelo/staging:

```bash
bash scripts/verify_font_ui.sh
bash scripts/verify_multiplayer_ui.sh
bash scripts/verify_goose_game.sh
```

O probe de multiplayer faz staging das telas principal, opções, acessibilidade,
multiplayer e Kutter nos caminhos JVM e nativo. A validação gráfica DEVE usar
`overzeer-isolated-display`; Xvfb simples ou o desktop ativo não são evidência.

Na workstation atual, a tentativa isolada de 2026-10-02 foi bloqueada de forma
fail-closed por pressão total de I/O (`62.54%` bloqueado), e o orquestrador
completo excedeu separadamente o orçamento sensível à pressão do p95 da
simulação (`4153us > 4000us`). O pacote local `0.1.0-gui.1` passou extração
assinada e package-smoke, mas a evidência nativa de apresentação GPU continua
aberta.

O gate focado do servidor dedicado agora passa 512 ticks medidos com p95 de
`3624us`, p99 de `3689us` e máximo de `3899us` sob o orçamento declarado de
`4000us`. O excesso anterior do orquestrador completo foi sensível à pressão e
continua registrado separadamente do bloqueio de apresentação na GPU-alvo.

O commit de fonte atual também possui o pacote local de qualificação somente
nativo `0.1.0-perf.2`, com SHA-256 do arquivo
`3d40aa2c012e610c460379c5ca0c62ecf0cc30b6bba57165bfe45c2dee8c8014`.
O package-smoke extraído e o gate de p95 do servidor dedicado empacotado
passaram; ele não é uma release pública nem um artefato de apresentação.

### Sessão WAN simples de gansos

Execute o rendezvous UDP autenticado em um host Linux alcançável:

```bash
KOOKIE_TRANSPORT_KEY_HEX=00112233445566778899aabbccddeeff \
python3 scripts/kookie_rendezvous.py --bind 0.0.0.0 --port 47101
```

O rendezvous recusa chave ausente, malformada ou composta só de zeros e nunca
expulsa uma sala existente de dois jogadores quando um terceiro usa o mesmo
código.

Inicie o cliente Linux ou Windows `presentation` com a mesma chave:

```bash
export KOOKIE_WAN_RENDEZVOUS=1
export KOOKIE_RENDEZVOUS_HOST_IPV4=203.0.113.20
export KOOKIE_ROOM_CODE=4107
export KOOKIE_PLAYER_NAME_ID=1
export KOOKIE_TRANSPORT_KEY_HEX=00112233445566778899aabbccddeeff
./kookie
```

Use `Multiplayer > Host` em um cliente e `Multiplayer > Join` no outro.
Depois que ambos mostrarem o peer conectado, selecione `READY` nos dois
clientes para abrir o gameplay. `Tab` abre a tela determinística de jogadores;
Escape volta ao menu e selecionar `Play` inicia um encounter local novo.

O rendezvous autentica o envelope UDP fixo, registra cada endpoint público,
envia o endpoint do peer e não retransmite tráfego. Depois disso os clientes
enviam datagramas autenticados diretamente para um hole punch UDP simples.
É best-effort: NAT simétrico, UDP bloqueado ou algumas topologias CGNAT exigem
encaminhamento de porta ou endereço LAN direto. Não há relay, criptografia,
serviço de identidade ou proteção DDoS de produção. Deixe
`KOOKIE_WAN_RENDEZVOUS` ausente para o modo LAN direto.

O gameplay usa snapshots autoritativos tipados e bundles de input em passo
fixo. Cada bundle repete até três inputs ordenados e carrega o último ACK de
snapshot; o host retorna um ACK de input. Ticks mais novos substituem snapshots
antigos, enquanto uma sequência de estado maior pode substituir a amostra mais
recente no mesmo tick para diagnósticos de ciclo de vida ou de comando obsoleto.
Esta é a camada limitada de confiabilidade sobre o envelope UDP autenticado. O
wire não é compatível com QUIC.

O host retém um histórico limitado de posições de 12 ticks para compensação de
latência do hitscan. Ele deriva o tick de rewind do atraso confirmado pelo
snapshot e usa a distância histórica entre origem e alvo; clientes renderizam
posições remotas seis ticks atrás do tick vivo. Esses limites são determinísticos
e não fornecem semântica sub-tick de QUIC.

Restaurar um checkpoint anterior de replay limpa as amostras de rewind do futuro
descartado antes de retomar o avanço em passo fixo.

O pacote Linux também contém `kookie-rendezvous.py`; o rendezvous roda em Linux
enquanto os dois clientes podem rodar em Linux ou Windows.


### Executar o dogfood Linux publicado atualmente

O pacote público mais recente é
[`0.1.0-dogfood.34`](https://github.com/rufl/KOOKIE/releases/tag/0.1.0-dogfood.34).
É um build dogfood de apresentação Linux x86-64 assinado, da fonte no commit
`4fdc25d7ed377c72cdcb7cf0f4ed35ea992cc947`; ele antecede a ponte atual de
input/sessão, o netcode em passo fixo, o lobby/placar e a qualificação PE/SDL
nativa Windows. Baixe os sete assets da release e valide o conjunto de checksums

```bash
sha256sum --check SHA256SUMS
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.34-linux-x86_64.pub.pem \
  -in SHA256SUMS -sigfile SHA256SUMS.sig
openssl pkeyutl -verify -rawin -pubin \
  -inkey kookie-0.1.0-dogfood.34-linux-x86_64.pub.pem \
  -in kookie-0.1.0-dogfood.34-linux-x86_64.tar.gz \
  -sigfile kookie-0.1.0-dogfood.34-linux-x86_64.tar.gz.sig
tar -xzf kookie-0.1.0-dogfood.34-linux-x86_64.tar.gz
cd kookie-0.1.0-dogfood.34-linux-x86_64
./kookie
```

O arquivo inclui SDL3, SDL_mixer e os adaptadores nativos, mas usa o
loader/libc dinâmico do host e exige uma GPU Linux suportada para apresentação.
Esse commit publicado antecede a ponte de input/sessão da árvore de fontes, o
caminho de input/ACK em passo fixo, o rewind com compensação de lag, a
interpolação remota, o rendezvous WAN, o lobby fixo Host/Join, o gate explícito
de pronto e a tela de jogadores. Gere novamente o perfil de apresentação para
obter o caminho jogável atual de gansos; o arquivo público não contém essas
mudanças.

## Pacotes Windows x86-64

### Compilador Kof PE/COFF alcançável

A ponte fixada do compilador reduz o grafo alcançável da IR Kof otimizada para
C11 determinístico e usa Zig 0.16.0 para emitir um objeto COFF AMD64 e um PE
de console Windows:

```bash
scripts/kof_pe_build.sh caminho/para/main.kf --output build/kof-pe
scripts/verify_kof_pe_backend.sh
```

A saída standalone contém `kof-module.c`, `kof-module.obj` e `kof-module.exe`.
Com `--library`, a saída contém o módulo C/objeto e a entrada exportada
`kookie_kof_gameplay_main` para um host nativo. O gate retido gera duas vezes,
verifica reprodutibilidade byte a byte e cabeçalhos PE/COFF, compara a saída
gerada com o oráculo Kof JVM e comprova a rejeição de IR de ponto flutuante com
`PE001`.

O alvo alcançável cobre o grafo atual de gameplay/apresentação do KOOKIE:
classes e campos, alocação de objetos e arrays, valores
inteiros/Boolean/String, locais, aritmética, desvios, loops,
`print`/`println`, `length`/`charAt` de String e FFI integral. Ele continua
fail-closed para IR de ponto flutuante, exceções capturáveis/concorrência e FFI
não integral. As alocações geradas duram até o processo terminar; o alvo é
para a carga de gameplay limitada, não para um serviço sem limite.

### Shell SDL nativo

Gere o shell nativo a partir dos pacotes oficiais de desenvolvimento MinGW do
SDL 3.4.16 e SDL_mixer 3.2.4:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/caminho/para/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/caminho/para/SDL3_mixer-3.2.4/x86_64-w64-mingw32 \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

O pacote liga o objeto PE do gameplay Kof completo de `src/` ao
`kookie.exe`, junto ao shell nativo SDL3/SDL_mixer de menu/lobby. Ele contém
`kookie.exe`, as DLLs SDL, licenças e procedência; não contém JDK. O smoke do
pacote imprime `KOOKIE native Kof PE gameplay verified` após inicializar SDL.

### Runtime Kof JVM incluído

O perfil de compatibilidade empacota o artefato JVM do Kof com um runtime
OpenJDK Windows x64 exato:

```bash
KOOKIE_WINDOWS_JAVA_ARCHIVE=/caminho/para/OpenJDK27U-jre_x64_windows_hotspot_27_35.zip \
KOOKIE_WINDOWS_JAVA_ARCHIVE_SHA256=e9cf542d5ffe2a894637b18c27a7802853976deaa3abe3e04dfbb8a307a145dd \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
SOURCE_DATE_EPOCH=<timestamp-unix> \
scripts/package_kookie.sh --runtime jvm --target windows-x86_64
```

O builder verifica o digest do arquivo, caminhos ZIP seguros, metadados de
release Windows x86-64, o PE `java.exe` e os arquivos legais preservados do
runtime. Ele gera e executa o smoke de um `kookie.jar` executável canônico e
escreve um ZIP assinado, ordenado deterministicamente e com timestamps
normalizados. O pacote contém `kookie.cmd`, `kookie.jar`, `runtime/`,
`JAVA_RUNTIME.txt`, licenças e procedência; a máquina de destino não precisa de
Java instalado separadamente. `runtime/legal` e `runtime/NOTICE` são a
autoridade para as licenças do OpenJDK incluído.

Esse perfil executa o núcleo Kof sem gráficos. Ele não substitui o shell SDL
nativo do Windows nem afirma ter backend de gameplay/apresentação SDL no
Windows. `scripts/verify_windows_jvm_package.sh` gera o pacote duas vezes,
compara todos os artefatos assinados, verifica as assinaturas e executa o JAR
empacotado.

### Pacote de apresentação PE/SDL_GPU nativo

O perfil de apresentação reduz o probe nativo de apresentação SDL e seu grafo
de gameplay alcançável para PE, liga estaticamente o adaptador SDL3/SDL_mixer e
inclui os produtos de shader SPIR-V e DXIL:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/caminho/para/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/caminho/para/SDL3_mixer-3.2.4/x86_64-w64-mingw32 \
KOOKIE_DXC=/caminho/para/dxc \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
SOURCE_DATE_EPOCH=<timestamp-unix> \
scripts/package_kookie.sh --runtime presentation --target windows-x86_64
```

`glslc` deve estar no `PATH`. `scripts/verify_windows_presentation.sh` gera o
pacote duas vezes, compara todos os artefatos assinados, valida caminhos ZIP
seguros e licenças e verifica o PE nativo, as import libraries SDL e as
entradas SPIR-V/DXIL. `KOOKIE_RUN_WINE=1` adiciona o smoke completo opcional,
exigindo `wine` e `overzeer-isolated-display`.

Para o artefato Windows publicável, use o builder determinístico de árvore
limpa:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/caminho/para/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/caminho/para/SDL3_mixer-3.2.4/x86_64-w64-mingw32 \
KOOKIE_DXC=/caminho/para/dxc \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/build_demo_release.sh \
  --target windows-x86_64 \
  --version 0.1.0-demo.N \
  --output /tmp/kookie-demo-windows
```

O lote de qualificação de 2026-10-02 passou
`verify_windows_presentation.sh` com prefixes MinGW SDL3/SDL_mixer e DXC
fixados. Isso comprova somente o caminho de artefato PE/SDL/SPIR-V/DXIL
assinado e reprodutível; evidência nativa Windows de input/áudio/GPU/driver e
smoke interativo fora do checkout continuam sendo gates de release.

O comando escreve arquivo assinado, manifesto, chave pública, assinaturas
destacadas, `SHA256SUMS` e `BUILD_SUMMARY.txt`. Evidência nativa de
inicialização/input/áudio/GPU Windows continua sendo gate separado de hardware.

Em um host isolado capaz de DRI3, o smoke executa a mesma entrada Kof PE nativa
que possui a janela SDL, staging de cena GPU, fila de áudio, reload do kutter
e os marcadores de gameplay. O pacote não tem dependência JVM. Esta é evidência
específica do alvo; não deve ser generalizada para outras combinações de
SO/GPU ou para qualificação de WAN/segurança.

### Workflow de release demo pareada

`.github/workflows/release_demo.yml` é um workflow disparado manualmente e
aprovado manualmente. Ele gera os pacotes Linux e Windows de forma
independente e só publica uma pré-release pareada depois da aprovação do
ambiente `kookie-demo-release`.

O workflow exige runners self-hosted com labels `kookie-demo-release`,
`linux`/`windows` e `x64`. Ambos precisam de Kof `0.5.0-beta` no commit de
fonte fixado, Python 3, OpenSSL, `glslc`, Zig 0.16.0 e o digest fixado da
distribuição Kof. O runner Linux também precisa dos arquivos de
desenvolvimento SDL3/SDL_mixer e de um wrapper de display isolado para o smoke
opcional. O runner Windows também precisa dos prefixes MinGW SDL3/SDL_mixer e
de `KOOKIE_DXC`.

Configure os secrets de ambiente `KOOKIE_SIGNING_KEY_PEM` e
`KOOKIE_KOF_ARCHIVE_SHA256`. Use `publish=false` para qualificação somente de
artefatos. Use `publish=true` apenas depois de reter evidência nativa Linux e
Windows de inicialização/input/áudio/GPU no registro da release.

### Sondas runtime G6

```bash
bash scripts/verify_g6_runtime.sh
```

O comando qualifica jobs seguros, ativação de KofScript em pacote/sessão,
reabertura persistente do Kutter e o canal WAN de janela fixa. WAN significa
endpoint IPv4/UDP direto autenticado, retry e backpressure limitados; não há
alegação de NAT traversal, relay, confidencialidade ou resistência a DDoS.

## Papéis para qualificação em LAN externa

Gere separadamente o bundle de papéis JVM para Windows:

```bash
scripts/package_external_lan_roles.sh \
  --version 0.1.0-external-lan.1 \
  --build-id "${KOOKIE_BUILD_ID:-local}" \
  --output release/external-lan
```

O arquivo contém JARs de host/cliente e launchers `.cmd` para Windows, mas não
inclui chave de transporte nem manifesto de execução. Ele é ferramenta de
qualificação entre hosts, não um pacote de produto KOOKIE. Evidência operacional
fica fora deste repositório. Revalide um bundle local com:

```bash
python3 scripts/verify_external_lan_evidence_bundle.py \
  /caminho/para/external-lan-evidence.tar.gz
```

Execute a regressão multiprocesso na mesma máquina com:

```bash
KOOKIE_EXTERNAL_LAN_TARGET=jvm \
KOOKIE_EXTERNAL_LAN_MODE=processes \
bash scripts/verify_external_lan.sh
```

Use `KOOKIE_EXTERNAL_LAN_TARGET=native` para o caminho nativo. Evidência na
mesma máquina continua como `externalHostExecution=unproven`.

## Gate de verificação do repositório

O gate completo é uma verificação final de pre-commit. Em sessões Pi, ele exige
a permissão única `/precommit-matrix` do usuário:

```bash
bash scripts/verify.sh
```

Durante a implementação, execute somente a menor verificação focada que
comprove o comportamento alterado.

O gate do GitHub Actions também executa `scripts/verify_kof_pe_backend.sh`.
As verificações PE leem diretamente os headers COFF/PE; não dependem do texto
específico que `file` emite para um objeto COFF AMD64.

## Isolamento da qualificação gráfica

Nunca execute verificações gráficas do KOOKIE contra o desktop ativo ou os
monitores físicos. Forneça um wrapper de isolamento descartável e revisado por
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`; ele deve oferecer sockets privados de
display e sessão, timeout limitado e limpeza completa da árvore de processos.

Verificações SDL offscreen comprovam ciclo de vida e recursos GPU, não
apresentação numa janela real. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` somente num
ambiente isolado capaz de apresentar. Defina
`KOOKIE_SCREENSHOT_PATH=/caminho/absoluto.ppm` para reter um frame qualificado.
