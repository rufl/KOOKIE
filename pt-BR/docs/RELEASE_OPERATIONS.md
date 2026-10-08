# Operação de release do KOOKIE

Este é o procedimento concreto para a workstation de qualificação atual e o
workflow do GitHub Actions. Ele não gera nem substitui a chave de assinatura
permanente do proprietário.

## Checkout e paths locais atuais

```bash
cd /home/lich/lichforge/code/monorepo/engines/KOOKIE

export KOF_ROOT=/tmp/kof-debug/dist-ci/kof-0.5.0-beta-linux-x86_64
export KOF_ARCHIVE=/tmp/kof-debug/dist-ci/kof-0.5.0-beta-linux-x86_64.tar.gz
export KOOKIE_WINDOWS_SDL_PREFIX=/tmp/kookie-release-deps/sdl/SDL3-3.4.16/x86_64-w64-mingw32
export KOOKIE_WINDOWS_SDL_MIXER_PREFIX=/tmp/kookie-release-deps/mixer/SDL3_mixer-3.2.4/x86_64-w64-mingw32
export KOOKIE_DXC=/tmp/kookie-release-deps/dxc/bin/dxc
export PATH="$KOF_ROOT/bin:$PATH"
export KOOKIE_KOF_SOURCE_COMMIT=bf17ac7e736471c8a04b4153e5b0f607be75e70c
export KOOKIE_KOF_ARCHIVE_SHA256="$(sha256sum "$KOF_ARCHIVE" | cut -d ' ' -f 1)"
```

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
`kookie-demo-release` existirem, o mesmo comando pode cadastrar os dois secrets
necessários no repositório:

```bash
bash scripts/check_release_readiness.sh \
  --repo rufl/KOOKIE \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --set-github-secrets
```

O comando configura:

- `KOOKIE_SIGNING_KEY_PEM` a partir do arquivo de chave permanente;
- `KOOKIE_KOF_ARCHIVE_SHA256` a partir do archive Kof exato fornecido aos dois
  runners de release.

Ele não atualiza secrets quando a chave ou o archive local são inválidos.

## Bootstrap de um comando

`scripts/bootstrap_release.sh` é a entrada única para a sequência segura e
repetível. Ele valida a chave permanente e o archive Kof, cria o environment
com aprovadores obrigatórios, configura os dois secrets do repositório,
verifica os dois runners self-hosted e pode disparar a qualificação.

Somente dry-run/readiness:

```bash
bash scripts/bootstrap_release.sh \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
```

Configurar o GitHub e qualificar:

Substitua `release-admin` pelo login real do usuário no GitHub; não é um valor
literal.

```bash
bash scripts/bootstrap_release.sh --apply \
  --reviewer release-admin \
  --signing-key "$KOOKIE_SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE" \
  --version 0.1.0-dogfood.37 \
  --qualify
```

Adicionar `--publish` exige a confirmação explícita
`--confirm-hardware-evidence` e ainda pausa na aprovação do environment no
GitHub. O script não pode criar hosts físicos de runner nem inventar uma chave
de assinatura permanente; ele termina exibindo os URLs de configuração.

## Contrato dos runners

Registre dois runners self-hosted x86-64 **online** com estes labels:

```text
self-hosted, linux, x64, kookie-demo-release
self-hosted, windows, x64, kookie-demo-release
```

Ambos precisam de Kof `0.5.0-beta` no commit
`bf17ac7e736471c8a04b4153e5b0f607be75e70c`, Python 3, OpenSSL, `glslc`, Zig
`0.16.0` e o archive Kof exato cujo digest está em
`KOOKIE_KOF_ARCHIVE_SHA256`.

O runner Linux também precisa dos arquivos de desenvolvimento SDL3, do
caminho de preparação do SDL_mixer fixado e de um wrapper de display isolado
para o smoke opcional. O runner Windows também precisa dos prefixes MinGW do
SDL3 e SDL_mixer e de `KOOKIE_DXC`.
No Windows, o serviço do runner precisa usar o `bash.exe` do Git for Windows,
não o shim do WSL. Mantenha os caminhos das ferramentas no escopo da máquina;
o NTFS não expõe bits de modo POSIX de forma confiável, então o gate restringe
as chaves Ed25519 transitórias com `icacls.exe`.

Crie `kookie-demo-release` em **Settings → Environments** e adicione
aprovadores obrigatórios antes de permitir `publish=true`.

## Disparo

Primeiro qualifique os artefatos:

```bash
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version=0.1.0-dogfood.37 \
  -f publish=false \
  -f run_linux_presentation_smoke=false \
  -f run_windows_wine_smoke=false
```

Acompanhe a execução:

```bash
gh run watch "$(gh run list \
  --repo rufl/KOOKIE \
  --workflow release_demo.yml \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')" \
  --repo rufl/KOOKIE
```

Somente depois de reter o par limpo, a evidência nos hardwares-alvo e a
aprovação do environment, publique:

```bash
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version=0.1.0-dogfood.37 \
  -f publish=true \
  -f run_linux_presentation_smoke=false \
  -f run_windows_wine_smoke=false
```

A release pública deve usar a chave permanente. A chave local de qualificação,
os paths locais em `/tmp` e os archives candidatos locais não são
infraestrutura de release.
