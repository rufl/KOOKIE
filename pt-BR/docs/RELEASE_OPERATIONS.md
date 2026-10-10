# Operação de release do KOOKIE

Este é o procedimento concreto para a workstation de qualificação atual e o
workflow do GitHub Actions. Ele não gera nem substitui a chave de assinatura
permanente do proprietário.

## Checkout e paths locais atuais

```bash
cd /home/lich/lichforge/code/monorepo/engines/KOOKIE

export KOF_ROOT=/tmp/kof-debug/dist-ci/kof-0.5.0-beta-linux-x86_64
export KOF_ARCHIVE=/tmp/kof-debug/dist-ci/kof-0.5.0-beta-linux-x86_64.tar.gz
export KOOKIE_WINDOWS_SDL_PREFIX=/tmp/kookie-release-deps/sdl/SDL3-3.4.18/x86_64-w64-mingw32
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

Registre dois runners self-hosted x86-64 **online** com estes labels:

```text
self-hosted, linux, x64, kookie-demo-release
self-hosted, windows, x64, kookie-demo-release
```

Ambos precisam de Kof `0.5.0-beta` no commit
`bf17ac7e736471c8a04b4153e5b0f607be75e70c`, Python 3, OpenSSL, `glslc`, Zig
`0.17.0` e o archive Kof exato cujo digest está em
`KOOKIE_KOF_ARCHIVE_SHA256`.
O runner deve expor esse arquivo em `KOOKIE_KOF_ARCHIVE`; os jobs de release
recalculam o SHA-256 antes do build, em vez de confiar apenas no metadata.
O workflow de verificação hospedado baixa o archive oficial do Zig 0.17.0 por
HTTPS, verifica o SHA-256
`1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026` e só então
o adiciona ao `PATH`; ele não depende de uma action baseada em Node.
O runner Linux da release expõe o SDL3 3.4.18 fixado em
`$HOME/.local/share/kookie-deps/sdl/SDL3-3.4.18`; o workflow exporta
`KOOKIE_SDL3_PREFIX` antes de preparar o SDL_mixer. Um SDL3 de sistema mais
antigo ou não revisado não é substituto.

O runner Linux também precisa dos arquivos de desenvolvimento SDL3, do
caminho de preparação do SDL_mixer fixado e de um wrapper de display isolado
para o smoke opcional. O runner Windows também precisa dos prefixes MinGW do
SDL3 e SDL_mixer e de `KOOKIE_DXC`. O smoke nativo Windows também exige um
`KOOKIE_WINDOWS_PRESENTATION_ISOLATION_WRAPPER` revisado, com display/sessão
privada, timeout limitado e limpeza da árvore de processos.
Ambos os runners de apresentação nativa devem definir variáveis de ambiente não
vazias `KOOKIE_PRESENTATION_HARDWARE_ID` e
`KOOKIE_PRESENTATION_GPU_DRIVER`. Esses valores identificam o hardware físico e
o driver usados na evidência autoritativa; valores ausentes falham o gate de
release.

No Windows, o serviço do runner precisa usar o `bash.exe` do Git for Windows,
não o shim do WSL. Mantenha os caminhos das ferramentas no escopo da máquina;
o NTFS não expõe bits de modo POSIX de forma confiável, então o gate restringe
as chaves Ed25519 transitórias com `icacls.exe`.
O gate do pacote Windows também exclui da conversão de caminhos do MSYS no Git
Bash as opções do linker que começam com `-Wl,/`.

Crie `kookie-demo-release` em **Settings → Environments** e adicione
aprovadores obrigatórios antes de permitir `publish=true`.

## Disparo

Primeiro qualifique os artefatos. Defina `RELEASE_VERSION` como a versão
candidata:

```bash
RELEASE_VERSION=0.1.0-demo.N
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f publish=false \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
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

Somente depois que `RELEASE_QUALIFICATION.json` for gerado com
`releaseEligible=true` e a aprovação do environment for concedida, publique a
mesma candidata:

```bash
RELEASE_VERSION=0.1.0-demo.N
gh workflow run release_demo.yml \
  --repo rufl/KOOKIE \
  --ref main \
  -f version="$RELEASE_VERSION" \
  -f publish=true \
  -f run_linux_presentation_smoke=true \
  -f run_windows_wine_smoke=false \
  -f run_windows_presentation_smoke=true
```

A release pública deve usar a chave permanente. A chave local de qualificação,
os paths locais em `/tmp` e os archives candidatos locais não são
infraestrutura de release.
