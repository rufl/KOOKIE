# Operação de release do KOOKIE

Este é o procedimento concreto para a workstation de qualificação atual e o
workflow do GitHub Actions. Ele não gera nem substitui a chave de assinatura
permanente do proprietário.

## Checkout e paths locais atuais

```bash
cd /home/lich/lichforge/code/monorepo/engines/KOOKIE
source scripts/kof_pin.sh

export KOF_ROOT=/tmp/kof-debug/dist-ci/kof-0.6.5-linux-x86_64
export KOF_ARCHIVE=/tmp/kof-debug/dist-ci/kof-0.6.5-linux-x86_64.tar.gz
export KOOKIE_WINDOWS_SDL_PREFIX=/tmp/kookie-release-deps/sdl/SDL3-3.4.18/x86_64-w64-mingw32
export KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/tmp/kookie-release-deps/mixer/SDL3_mixer-3.2.4/x86_64-w64-mingw32
export KOOKIE_WINDOWS_FREETYPE_PREFIX=/tmp/kookie-release-deps/freetype/x86_64-w64-mingw32
export KOOKIE_WINDOWS_HARFBUZZ_PREFIX=/tmp/kookie-release-deps/harfbuzz/x86_64-w64-mingw32
export KOOKIE_DXC=/tmp/kookie-release-deps/dxc/bin/dxc
export PATH="$KOF_ROOT/bin:$PATH"
export KOOKIE_KOF_SOURCE_COMMIT=8e59b24acc978eb2546509b5cfca867a06e7283a
export KOOKIE_KOF_ARCHIVE_SHA256="$(sha256sum "$KOF_ARCHIVE" | cut -d ' ' -f 1)"
```

`KOF_ARCHIVE` deve ser uma distribuição Kof `0.6.5` construída a partir da
fonte, com metadados normalizados, no commit `lab` fixado.
`scripts/prepare_kof_source.sh` verifica a guarda upstream de ciclos do GC
native antes do Maven; depois o toolchain de release aplica
`patches/kof-native-emitter-performance.patch` (a fonte pinada já contém a
mudança de alocação do emissor native; o patch mantém o desempate
determinístico da alocação de registradores) e verifica o SHA-256
`4898952c8f4130d1b5a9e8effb56b0dd7a58d228596b50f69427639c15843664`.
Nenhum patch local de GC é aplicado. O JAR do compilador deve corresponder ao
build da fonte; o workflow repete `kof version` antes do empacotamento. Os
gates nativos também exigem `pkg-config`, FreeType 2 e HarfBuzz para o
renderer de texto.

O arquivo `/tmp/kookie-release-qualification.pem` existente é efêmero e não
deve ser enviado como identidade da release pública. Use uma chave Ed25519
permanente, controlada pelo proprietário, com modo `0600`, por exemplo:

```bash
export KOOKIE_SIGNING_KEY="$HOME/.config/kookie/release/kookie-ed25519.pem"
test -f "$KOOKIE_SIGNING_KEY"
test "$(stat -c '%a' "$KOOKIE_SIGNING_KEY")" = 600
```

## Readiness e configuração dos secrets

O repositório contém um verificador fail-closed. Ele não imprime o conteúdo da
chave:

```bash
bash scripts/check_release_readiness.sh \
  --repo rufl/KOOKIE \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
```

Depois que os dois runners self-hosted e o environment
`kookie-demo-release` existirem, o mesmo comando pode configurar o secret de
assinatura controlado pelo proprietário:

```bash
bash scripts/check_release_readiness.sh \
  --repo rufl/KOOKIE \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --set-github-secrets
```

O comando configura somente `KOOKIE_SIGNING_KEY_PEM`. O job hospedado
`toolchain` constrói o archive Kof fixado uma vez por execução, publica
`SHA256SUMS` e `SOURCE_COMMIT`, e os dois jobs de alvo verificam esse artefato
antes de empacotar. `KOOKIE_KOF_ARCHIVE_SHA256` continua sendo um valor de
ambiente por job do pacote, não um secret estático do repositório.

Ele não atualiza o secret de assinatura quando a chave ou o archive local são
inválidos. O `RELEASE_QUALIFICATION.json` pareado também registra exatamente
`kofArchiveSha256` e `kofCompilerSha256` e rejeita um par Linux/Windows cujas
identidades de artefato Kof sejam diferentes.

## Bootstrap de um comando

`scripts/bootstrap_release.sh` é a entrada única para a sequência segura e
repetível. Ele valida a chave permanente e o archive Kof, cria o environment
com aprovadores obrigatórios, configura o secret de assinatura, verifica os
dois runners self-hosted e pode disparar a qualificação.

Somente dry-run/readiness:

```bash
bash scripts/bootstrap_release.sh \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
```

Configurar o GitHub e qualificar. Defina `RELEASE_VERSION` como a versão
candidata:

Substitua `release-admin` pelo login real do usuário no GitHub; não é um valor
literal.

```bash
RELEASE_VERSION=0.1.0-demo.N
bash scripts/bootstrap_release.sh --apply \
  --reviewer release-admin \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --version "$RELEASE_VERSION" \
  --qualify
```

Depois que os dois smokes nativos de alvo passarem:

```bash
RELEASE_VERSION=0.1.0-demo.N
bash scripts/bootstrap_release.sh --apply \
  --reviewer release-admin \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --version "$RELEASE_VERSION" \
  --qualify \
  --linux-presentation-smoke \
  --windows-presentation-smoke \
  --publish --confirm-hardware-evidence
```

Adicionar `--publish` exige a confirmação explícita
`--confirm-hardware-evidence` e ainda pausa na aprovação do environment no
GitHub. O script não pode criar hosts físicos de runner nem inventar uma chave
de assinatura permanente; ele termina exibindo os URLs de configuração.

## Contrato dos runners

O workflow exige dois runners self-hosted x86-64 **online** com estes labels:

```text
self-hosted, linux, x64, kookie-demo-release
self-hosted, windows, x64, kookie-demo-release
```

Ambos precisam de suporte ao shell do Git conforme o sistema, Python 3,
OpenSSL, `glslc`, `spirv-val` e o checkout do repositório. O job hospedado
`toolchain` constrói o Kof `0.6.5` a partir de
`8e59b24acc978eb2546509b5cfca867a06e7283a`; cada job self-hosted baixa,
verifica esse archive exato e adiciona seu binário `kof` ao `PATH`. Archive Kof
pré-instalado, secret de digest do compilador Kof e Zig pré-instalado não fazem
parte do contrato dos runners de release.

O runner Linux também precisa de:

- arquivos de desenvolvimento SDL3 fixados em
  `$HOME/.local/share/kookie-deps/sdl/SDL3-3.4.18`;
- o sandbox revisado `overzeer-isolated-display` e `gamescope`;
- um nó `/dev/dri/renderD*` utilizável e o nó DRM primário pareado para o
  compositor headless do Gamescope.

O wrapper versionado `scripts/linux_gamescope_isolated_display` compõe essas
peças em um display Wayland/Xwayland headless privado, e o job de release usa
o backend X11 do SDL através do servidor Xwayland do Gamescope dentro dele. O
workflow prepara o prefixo fixado do SDL_mixer quando a entrada `pkg-config`
está ausente.

O runner Windows precisa de Git Bash, Windows PowerShell 5, `pkg-config`, um
prefixo MinGW com FreeType e HarfBuzz e `dxc`; a configuração do release
resolve esses prefixes de texto por `pkg-config` e descobre `dxc` pelo `PATH`
ou por locais instalados conhecidos antes de exportar as variáveis exigidas.
O workflow baixa e verifica, em cada release, os archives oficiais de
desenvolvimento MinGW do SDL3 `3.4.18` (SHA-256
`049b9dd711e3fb3f8d84feb998dfec54a75e17cf539c4a80ff4d058d839771cf`) e do
SDL_mixer `3.2.4` (SHA-256
`2ff5f59be4683e0afb4339c4fa73c6228651e52d37b040ecf80da08edb3cecd6`). Os
prefixos de texto configurados devem fornecer headers, import libraries MinGW,
`freetype2.pc`/`harfbuzz.pc` e todas as DLLs de runtime de FreeType e HarfBuzz
exigidas por `package_kookie.sh`. Ele também baixa e verifica o archive oficial
Zig `0.17.0` para Windows com SHA-256
`b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428` e usa o
wrapper versionado `scripts/windows_isolated_display`. O smoke nativo Windows
também registra a identidade PNP, o nome e a versão do driver do primeiro
adaptador PCI de vídeo como evidência do hardware alvo.
Os pacotes de apresentação também carregam os JSONs de runtime de líquido e
power-ups autorados pelo projeto em `config/runtime`; isso é separado do
perfil opcional de conteúdo prototype e mantém a sonda native executável no
pacote dogfood com `content-profile=none`.

Ambos os runners de apresentação nativa devem definir as variáveis não vazias
`KOOKIE_PRESENTATION_HARDWARE_ID` e `KOOKIE_PRESENTATION_GPU_DRIVER`. Esses
valores identificam o alvo físico e o driver usados na evidência autoritativa;
valores ausentes falham o gate.

No Windows, o serviço do runner precisa usar o `bash.exe` do Git for Windows,
não o shim do WSL. Mantenha os caminhos das ferramentas no escopo da máquina;
o NTFS não expõe bits de modo POSIX de forma confiável, então o gate restringe
as chaves Ed25519 transitórias com `icacls.exe`. O gate do pacote Windows
também exclui da conversão de caminhos do MSYS as opções do linker que começam
com `-Wl,/`.

### Preflight e cache dos runners

Antes do empacotamento, o workflow executa
`scripts/runner_preflight.sh release-linux` ou
`scripts/runner_preflight.sh release-windows`. O preflight registra SO, CPU,
memória e disco livre no resumo do job e rejeita um runner sem o archive Kof,
Zig, SDL, shaders, runtime de texto ou DXC exigido pelo alvo.

O workflow cacheia somente archives imutáveis, usando versão e SHA-256 na
chave. Cada cache hit é hashado novamente antes da extração. O cache não
substitui as verificações `SHA256SUMS`/`SOURCE_COMMIT` do Kof nem o preflight
de GPU/display da release.

O `verify.yml` hospedado constrói o archive Kof uma vez por execução. Os jobs
static/JVM, native/package e Windows JVM consomem exatamente esse archive em
paralelo. A verificação native possui timeout separado e maior porque a
geração de código native do Kof é materialmente mais lenta.

Crie `kookie-demo-release` em **Settings → Environments** e adicione
aprovadores obrigatórios antes de permitir `publish=true`.

## Disparo

Primeiro qualifique os artefatos. Defina `RELEASE_VERSION` como a versão
candidata:

```bash
RELEASE_VERSION=0.1.0-demo.N
SOURCE_COMMIT="$(git rev-parse HEAD)"
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f source_commit="$SOURCE_COMMIT" \
  -f publish=false \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

Acompanhe a execução e retenha o commit imutável da fonte:

```bash
QUALIFICATION_RUN="$(gh run list \
  --repo rufl/KOOKIE \
  --workflow release_demo.yml \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')"
gh run watch "$QUALIFICATION_RUN" --repo rufl/KOOKIE
SOURCE_COMMIT="$(gh run view "$QUALIFICATION_RUN" \
  --repo rufl/KOOKIE --json headSha --jq .headSha)"
```

Depois que a execução de qualificação terminar com `releaseEligible=true`,
dispare o mesmo commit imutável com `publish=true`. O workflow de publicação
faz checkout de `SOURCE_COMMIT`, recompila os dois artefatos a partir dele,
gera e assina seu próprio `RELEASE_QUALIFICATION.json` final e pausa na
aprovação do environment antes de criar a prerelease pública:

```bash
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f source_commit="$SOURCE_COMMIT" \
  -f publish=true \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

A release pública deve usar a chave permanente. A chave local de qualificação,
os paths locais em `/tmp` e os archives candidatos locais não são
infraestrutura de release.
