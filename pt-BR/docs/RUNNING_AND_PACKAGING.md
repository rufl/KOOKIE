# Executando e empacotando o KOOKIE

[English](../../docs/RUNNING_AND_PACKAGING.md)

Esta página mantém os detalhes de build, pacote e qualificação fora da página
inicial do projeto. O KOOKIE é experimental: estes comandos exercitam contratos
de evidência limitados, não uma promessa de suporte de produção.

## Execução para desenvolvimento

Instale [Kof 0.5.0-beta](https://github.com/KofLang/Kof4j) e Python 3 e execute
a demo autoritativa na raiz do repositório:

```bash
kof run src/main.kf --target native
```

O alvo JVM existe para qualificação diferencial local:

```bash
kof run src/main.kf --target jvm
```

Ele não é um fallback distribuível. Os arquivos de release do KOOKIE não
incluem nem exigem uma JVM.

Execute a sonda focada de gameplay e replay com:

```bash
bash scripts/verify_interactions.sh
```

## Cooker de conteúdo

O launcher de desenvolvimento admite somente os subconjuntos de fonte
limitados e documentados. Ele rejeita entradas inválidas, grandes demais ou
incompatíveis sem publicar um produto bem-sucedido.

```bash
scripts/kookie_cooker.sh cook map level.map level.kmesh
scripts/kookie_cooker.sh cook dust3d model.ds3 model.glb model.kmesh
scripts/kookie_cooker.sh cook blockbench character.bbmodel character.kchar
scripts/kookie_cooker.sh cook png texture.png texture.rgba.png
scripts/kookie_cooker.sh cook wav effect.wav effect.pcm16.wav
scripts/kookie_cooker.sh package 4 level.kmesh data/level.kmesh level.kpkg
scripts/kookie_cooker.sh inspect-package level.kpkg
scripts/kookie_cooker.sh validate-package creator.kpkg
```

Os formatos de fonte são entradas de autoria, não formatos de pacote do
runtime. Os arquivos Linux incluem um `kookie-cooker` nativo para os comandos
`cook` acima; a montagem e a inspeção de pacotes continuam no launcher de
desenvolvimento JVM.

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
- `kookie-cooker`, cooker nativo e limitado de fontes;
- `kookie-simd-bench`, sonda de paridade e tempo escalar/SIMD.

O servidor informa contagens, orçamentos de trabalho, tempos
p50/p95/p99/máximo por tick, faixa de RSS, checksum e estabilidade lógica de
recursos. Ele é ferramenta de qualificação, não um serviço de hospedagem de
produção empacotado. A decisão de rota SIMD é saída de medição para sua carga
de redução exata, não uma afirmação de ganho geral.

## Pacote de apresentação SDL para Linux

Gere a apresentação persistente SDL3/SDL_GPU usada para qualificação visual
isolada e deploy dogfood pelo ZEER:

```bash
KOOKIE_RUNTIME=presentation \
KOOKIE_VERSION=0.1.0-dogfood.N \
KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c \
KOOKIE_KOF_ARCHIVE_SHA256=<sha256-verificado-da-distribuicao> \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime presentation --target linux-x86_64
```

Esse perfil exige SDL 3.4.16, SDL_mixer 3.2.4, `glslc`, compilador C e
`pkg-config`. O arquivo contém a aplicação Kof de menu/jogo, adaptador SDL,
shaders SPIR-V, SDL3 e SDL_mixer. Ele usa o loader dinâmico e a libc do host.

### Controles

- Menu principal: setas ou WASD.
- Selecionar: Enter, Espaço ou clique do mouse.
- Voltar: Escape.
- Opções: 1280×720 até 2560×1440, janela/sem borda/tela cheia exclusiva,
  volumes separados para efeitos e música e três tamanhos de texto.
- Multiplayer: Host, Join e Leave com campos editáveis de IPv4 e porta.

Mudanças de vídeo só são efetivadas em Apply. Os pacotes do lobby usam tags
SipHash e sequências contra replay. Uma chave compartilhada configurada de 128
bits autentica peers; o fallback local apenas detecta corrupção acidental. O
lobby não fornece criptografia nem identidade pública.

## Shell Windows x86-64

Gere o shell nativo a partir dos pacotes oficiais de desenvolvimento MinGW do
SDL 3.4.16 e SDL_mixer 3.2.4:

```bash
KOOKIE_WINDOWS_SDL_PREFIX=/caminho/para/SDL3/x86_64-w64-mingw32 \
KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/caminho/para/SDL3_mixer/x86_64-w64-mingw32 \
KOOKIE_SIGNING_KEY=/caminho/seguro/kookie-ed25519.pem \
scripts/package_kookie.sh --runtime native --target windows-x86_64
```

O ZIP contém `kookie.exe`, `SDL3.dll`, `SDL3_mixer.dll`, licenças e procedência.
Ele não contém JDK. O shell de menu/opções/lobby é interativo e persistente,
mas Kof ainda não gera código de gameplay PE para Windows. Linux continua como
o alvo nativo autoritativo de gameplay.

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

## Isolamento da qualificação gráfica

Nunca execute verificações gráficas do KOOKIE contra o desktop ativo ou os
monitores físicos. Forneça um wrapper de isolamento descartável e revisado por
`KOOKIE_PRESENTATION_ISOLATION_WRAPPER`; ele deve oferecer sockets privados de
display e sessão, timeout limitado e limpeza completa da árvore de processos.

Verificações SDL offscreen comprovam ciclo de vida e recursos GPU, não
apresentação numa janela real. Use `KOOKIE_SDL_VIDEO_DRIVER=x11` somente num
ambiente isolado capaz de apresentar. Defina
`KOOKIE_SCREENSHOT_PATH=/caminho/absoluto.ppm` para reter um frame qualificado.
