# Contrato G0 de tokens de recursos verificados

[English](../../docs/G0_RESOURCE_TOKENS.md)

Status: **implementado e exercitado nos alvos Kof JVM/nativo**. Este é o primeiro contrato limitado do G0; ainda não é um registry nativo de SDL.

## Contrato

`src/core/resources.kf` define:

- `ResourceToken(slot, generation, kind)`: identidade imutável devolvida ao código Kof;
- `ResourceRegistry(capacity)`: armazenamento de capacidade fixa por slots;
- `acquire(kind)`: aloca o primeiro slot livre ou devolve um token inválido;
- `isValid(token)`: verifica limites do slot, estado ativo, geração e tipo do recurso;
- `release(token)`: invalida o token atual e avança a geração daquele slot;
- `activeCount()` e `capacity()`: observabilidade limitada para admissão/testes.

Um token é uma identidade, não um ponteiro. O slot é um índice do estado pertencente ao adaptador, a geração rejeita reuso obsoleto e o tipo rejeita uso cruzado entre recursos. Uma aquisição inválida usa `slot = -1`, `generation = 0` e `kind = 0`; nenhum endereço nativo é codificado.

## Invariantes

1. Um token recém-adquirido é válido exatamente enquanto o slot estiver ocupado com a mesma geração e tipo.
2. Um token liberado fica obsoleto imediatamente; liberá-lo novamente devolve `false` e não altera o estado.
3. Um token com slot/geração corretos, mas tipo diferente, é rejeitado.
4. Reusar um slot liberado avança sua geração, portanto o token antigo não autoriza acesso ao substituto.
5. Exaustão e tipos não positivos devolvem um token inválido, sem lançar exceção nem criar alias silencioso de recurso.
6. Os índices são verificados antes do acesso aos arrays. O registry não usa falhas nativas de limite como fluxo de controle.
7. A geração volta de forma limitada para `1` após `2.147.483.646`; identidade persistente entre reinícios do processo não é prometida.

A classe atual é deliberadamente pertencente ao Kof e de uma única thread. Ela não expõe payload, ponteiros nativos, handles de GPU/áudio, persistência, segurança entre threads nem recuperação automática. Esses comportamentos continuam sendo contratos do adaptador a comprovar separadamente.

## Prova de regressão

`src/main.kf` contém um caminho de smoke e um `test "resource token lifecycle"` nomeado que cobre:

- aquisição e admissão por contagem ativa;
- rejeição de tipo incorreto;
- liberação e rejeição de token obsoleto;
- rejeição de liberação duplicada;
- mudança de geração ao reutilizar o slot.

Execute na raiz do repositório:

```bash
kof test src --target jvm
kof test src --target native
kof run src/main.kf --target jvm
kof run src/main.kf --target native
```

As suítes JVM e nativa passam com um teste nomeado cada. O compilador nativo ainda emite o aviso documentado de fallback para runtime completo quando executado fora do checkout do compilador; isso não altera o resultado do token.

## Próximo passo do adaptador

Use este contrato no limite do adaptador escalar SDL. O adaptador pode possuir ponteiros nativos atrás de um registry, mas deve expor somente tokens inteiros verificados e metadados escalares copiados. Adicione tipos específicos de recurso, diagnósticos de token obsoleto e aposentadoria segura para GPU antes de conectar o registry ao SDL_GPU ou ao áudio enfileirado. Não persista esses tokens nem trate um cast de inteiro como handle.
