# Contribuindo com o KOOKIE

[English](../CONTRIBUTING.md)

O KOOKIE mantém em código-fonte Kof `.kf` todo comportamento portátil de CPU da engine, do jogo e das ferramentas. Bibliotecas externas de plataforma/GPU/áudio e glue estreito de ABI/shaders são exceções explícitas. Leia `README.md`, `MEMORY.md` e o documento relevante em `docs/` antes de alterar o código.

Se a mudança afetar o limite da release voltada ao jogador, leia também
[Prontidão da release demo](docs/DEMO_RELEASE.md); a qualificação da engine ou
do pacote, sozinha, não significa que a demo Windows/Linux seja jogável.

## Idioma

As páginas e a documentação pública são mantidas em inglês e português brasileiro. Mantenha o arquivo correspondente em `pt-BR/` sincronizado sempre que uma página ou documento mudar.
Para uma visão rápida do trabalho recente, leia [CHANGELOG.md](CHANGELOG.md). Mantenha o changelog e o arquivo correspondente em inglês úteis para quem está chegando ao projeto: descreva o comportamento que mudou, a verificação que o sustenta e o limite que continua.


## Dependências e licenciamento

O KOOKIE usa MIT. Todo componente de fonte ou runtime distribuído em um pacote
KOOKIE deve ter licença permissiva revisada. Ferramentas de build/qualificação
podem usar outras licenças somente quando não são vinculadas, copiadas ou
exigidas em runtime. Fixe versões e hashes, atualize
`THIRD_PARTY_NOTICES.txt` e faça o gate de fechamento de dependências rejeitar
qualquer biblioteca não revisada.

## Gate de verificação

Antes de cada push, execute a verificação na raiz do repositório:

```bash
bash scripts/verify.sh
```

O gate executa:

1. o linter de fontes Kof do repositório;
2. diagnósticos do LSP Kof para todo `.kf` em `src/` e `probes/`;
3. verificações do compilador Kof nos alvos JVM e nativo;
4. a suíte nomeada de regressão Kof nos alvos JVM e nativo;
5. saída de smoke de runtime JVM/nativo para os contratos verificados de recursos e estado;
6. build opcional do adaptador SDL nativo e smoke em display isolado quando as dependências de sistema e o gate de pressão permitirem;
7. builds do compilador para JVM e nativo.

A CI hospedada usa máquinas virtuais compartilhadas, então o workflow define
`KOOKIE_SERVER_P95_BUDGET_US=8000` para um gate tolerante ao escalonamento do
servidor headless. O orçamento local e de soak continua em 4000 microssegundos;
um sucesso na CI hospedada não substitui evidência de desempenho registrada.
O LSP Kof atual analisa cada documento aberto como um módulo temporário de
arquivo único. Por isso o gate registra os diagnósticos conhecidos de pacote
`PKG004`/`PKG006` e falha para qualquer outro erro de LSP. A correção completa
de pacotes/imports é coberta pelas verificações do compilador JVM/nativo.

### Loop interno de desenvolvimento

Use a suíte de regressão JVM enquanto itera na lógica Kof:

```bash
bash scripts/dev_test.sh
```

A execução padrão roda os 144 testes de `src/main.kf` sem montagem,
linkedição, empacotamento e gates de apresentação nativos. Use
`KOOKIE_DEV_TARGET=native bash scripts/dev_test.sh` para uma verificação
específica do nativo. Isto é um gate de iteração, não substitui
`verify.sh`.

A verificação completa reutiliza artefatos canônicos JVM/nativos em
`${XDG_CACHE_HOME:-$HOME/.cache}/kookie/canonical`; os manifestos de identidade
invalidam o cache quando a árvore de fontes ou o toolchain Kof fixado muda.
Defina `KOOKIE_CANONICAL_BUILD_CACHE_DIR` para substituir esse local.

### Gate local de empacotamento

Os checks de release exigem a distribuição Kof exata usada por `kof` e os
metadados do toolchain Zig fixado usados pelo check de falha fechada do
Windows. Quando o diretório do arquivo contiver `SHA256SUMS` e
`SOURCE_COMMIT`, configure o shell atual antes do gate completo:

```bash
source scripts/configure_kof_archive.sh /path/to/kof-0.6.5-linux-x86_64.tar.gz
export KOOKIE_ZIG_VERSION=0.17.0
export KOOKIE_ZIG_ARCHIVE_SHA256=1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026
bash scripts/verify.sh
```

O digest do arquivo é gerado a cada build do Kof porque os metadados do tar
variam; `configure_kof_archive.sh` verifica esse digest e o commit Kof fixado
antes de exportar as entradas do pacote. `verify.sh` executa o mesmo preflight
de identidade antes de iniciar a matriz estática e de runtime, mais demorada.
Durante o smoke do pacote, `verify_package.sh` reutiliza um cache por execução
para os builds nativos do servidor, do kooker de conteúdo e do benchmark SIMD
entre os archives nativo e de apresentação. O cache é temporário e nunca é
tratado como artefato de release.

Quando um contrato de sessão ou replay mudar, atualize juntas as páginas
correspondentes em inglês e português e os comentários próximos no código-fonte.
Documente explicitamente revisões de estado no mesmo tick e as regras de época de
checkpoint/rewind; não deixe essas invariantes somente no teste de regressão.

Não faça commit de artefatos de build, credenciais, dependências baixadas ou caches gerados. Verificações gráficas precisam usar um display isolado descartável e nunca o desktop ativo. Os limites das verificações nativas permanecem documentados em `docs/ENGINE_PLAN.md`.
