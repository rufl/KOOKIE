# Contribuindo com o KOOKIE

[English](../CONTRIBUTING.md)

O KOOKIE mantém em código-fonte Kof `.kf` todo comportamento portátil de CPU da engine, do jogo e das ferramentas. Bibliotecas externas de plataforma/GPU/áudio e glue estreito de ABI/shaders são exceções explícitas. Leia `README.md`, `MEMORY.md` e o documento relevante em `docs/` antes de alterar o código.

## Idioma

As páginas e a documentação pública são mantidas em inglês e português brasileiro. Mantenha o arquivo correspondente em `pt-BR/` sincronizado sempre que uma página ou documento mudar.

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
5. a saída de smoke de runtime JVM/nativo para o contrato verificado de tokens de recursos;
6. builds do compilador para JVM e nativo.

O LSP Kof atual analisa cada documento aberto como um módulo temporário de
arquivo único. Por isso o gate registra os diagnósticos conhecidos de pacote
`PKG004`/`PKG006` e falha para qualquer outro erro de LSP. A correção completa
de pacotes/imports é coberta pelas verificações do compilador JVM/nativo.

Não faça commit de artefatos de build, credenciais, dependências baixadas ou caches gerados. Verificações gráficas precisam usar um display isolado descartável e nunca o desktop ativo. Os limites das verificações nativas permanecem documentados em `docs/ENGINE_PLAN.md`.
