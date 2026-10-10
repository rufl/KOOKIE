# Política de documentação

[English](../../docs/DOCUMENTATION.md)

- Toda página pública tem uma versão correspondente em inglês e português brasileiro. Mantenha o par no mesmo commit.
- O inglês fica em `README.md` ou `docs/`; o português fica em `pt-BR/` ou `pt-BR/docs/`.
- Preserve comandos medidos, pins de origem, hashes e limites de comprovação. Não traduza identificadores de código, caminhos, nomes de comandos ou produtos upstream.
- Escreva o status como um colega escreveria: diga o que funciona, o que foi realmente verificado e o que continua bloqueado. Evite linguagem de milestone que pareça mais completa do que a evidência.

A baseline ativa de fonte/CI é o Kof `0.5.0-beta` no commit
`bf17ac7e736471c8a04b4153e5b0f607be75e70c`. A documentação atual da sessão deve
descrever ordenação estrita por tick, revisões no mesmo tick com sequência de
estado mais nova e histórico de rewind novo após restaurar checkpoint. As páginas
de pesquisa mantêm intencionalmente seus snapshots datados de toolchain; atualize
escopo e limites de evidência sem reescrever medições históricas.

O README da raiz é a página inicial.
[Execução e empacotamento](RUNNING_AND_PACKAGING.md) reúne comandos de
desenvolvimento, release, kooker e qualificação. [Prontidão da release demo](DEMO_RELEASE.md)
é a autoridade para a diferença entre qualificação da engine e uma demo jogável
Windows/Linux. O [CHANGELOG](../../pt-BR/CHANGELOG.md) é o histórico curto e
humano; [MEMORY](../../pt-BR/MEMORY.md) é a nota para retomar o trabalho;
`CONTRIBUTING.md` define o gate de verificação. A sequência G0 limitada e ativa
está em [G0_BACKLOG](G0_BACKLOG.md), com detalhes de tokens de recursos e
adaptador escalar em [G0_RESOURCE_TOKENS](G0_RESOURCE_TOKENS.md) e
[G0_SCALAR_ADAPTER](G0_SCALAR_ADAPTER.md).
A fronteira reutilizável de UI/mídia e a ABI upstream 0.5.0-beta auditada de
forma independente estão registradas em
[KOF4J_UI_MIGRATION](KOF4J_UI_MIGRATION.md); ela distingue intencionalmente o
pin de CI acima do `main` upstream revisado.
