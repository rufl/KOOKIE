# Editor Kof: o que aprender, usar e evitar

Data da pesquisa e instalação: 2026-09-22. A auditoria da fonte original abaixo precedeu a instalação. A [instalação local](#instalação-local) posterior inclui verificações reais do compilador, do protocolo e da janela nativa isolada.

Fonte fixada: [`KofLang/Kof-Editor@bed6ae7d567b090497a447583a10b8522acaf66a`](https://github.com/KofLang/Kof-Editor/tree/bed6ae7d567b090497a447583a10b8522acaf66a), `VERSION` = `0.1.4-beta`. Referência cruzada do compilador: [Kof4j 22a186b9](https://github.com/KofLang/Kof4j/tree/22a186b9bf9df37c03809ba6ef4af85085386f63), 0.4.9-beta. O empacotamento upstream pode selecionar compiladores mais antigos. A combinação instalada localmente foi verificada apenas para os fluxos de trabalho listados abaixo, não para todos os recursos upstream.

## Arquitetura real

```text
core scanner/theme + front.kf + web.kf
                │ scripts/web-combine.sh
                ▼
       build/editor-web.kf
                │ kof serve (JVM)
                ▼
 legacy handle(method,path,body) HTTP server
                │
                ▼
 handwritten HTML/CSS/JavaScript served from Kof strings
                │
                ▼
 browser or Linux WebKitGTK native window
```

O backend, o scanner e a lógica de temas contêm código Kof real. No entanto, `pageJs()` em `src/ui/web/web.kf` contém **JavaScript escrito manualmente** substancial, que implementa estado do documento, edição de texto, abas, atalhos de teclado, conclusão, formatação e atualizações do DOM. Um arquivo `.kf` contendo strings JavaScript não é uma implementação totalmente em Kof desses comportamentos.

“Janela nativa” significa WebKitGTK hospedando a interface web, **não** o editor compilado para ELF nativo do Kof. A demonstração separada do console principal exercita a funcionalidade de lexer/buffer/tema; ela não é a interface gráfica.

A interface web usa uma área de texto transparente sobre texto destacado, margem e minimapa. Seu buffer é um estado de documento JavaScript, não o buffer `List<String>` da demonstração `src/core/buffer.kf`. O combinador web exclui esse buffer e o highlighter.

O scanner do editor é uma implementação `.kf` separada que segue o comportamento do lexer do compilador. Ele não é o frontend Java real do compilador importado para o editor. O Static Pages introduz outro pequeno tokenizer JavaScript. As versões da linguagem podem divergir entre os três.

Fontes: [implementação web](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/ui/web/web.kf), [combinador web](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/web-combine.sh), [scanner](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/core/lexer.kf), [buffer principal](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/core/buffer.kf).

## Inventário de recursos

| Área | A fonte implementa | Limite |
|---|---|---|
| Edição | Abas, explorador, margem, minimapa, quebra de linha, salvamento automático, paleta, snippets | Repintura/tokenização do documento inteiro; não é um modelo de editor incremental maduro |
| Temas | Seis paletas; esquema granular; importação/exportação de Kof JSON/YAML | Referência útil de processamento de dados Kof; evite copiar código GPL sem revisar a licença |
| Problemas | Tokens de erro do lexer | Não são diagnósticos semânticos/de tipo |
| Verificação | Subprocesso real `kof check`, painel de saída | Ação separada, não um LSP continuamente conectado |
| Conclusão | Palavras estáticas em JS + símbolos regex do documento | Não é conclusão de membros tipados |
| Navegação | Estrutura/t busca de texto do documento ativo baseada em tokens | Não é resolução de símbolos do projeto |
| Renomeação | Substituição de palavras com limite no documento atual | Pode atingir símbolos/comentários/strings não relacionados |
| Formatação | Função de formatação em JavaScript do navegador | Não é o formatador do compilador, embora também exista um auxiliar de formatação Kof não utilizado |
| Execução | Copia o arquivo ativo para um diretório temporário compartilhado; invoca o compilador | Perde módulos/configurações/recursos irmãos; alvo JVM fixo |
| Terminal | Comando shell executado uma vez | Sem PTY/sessão persistente; o tratamento do cwd não é confiável |
| Git | Status/diff/stage/commit via CLI | Ambiguidade do cwd do repositório e `git add -A` abrangente; inseguro para trabalho em monorepo compartilhado |
| Depuração | Nenhuma implementação de fonte de cliente LSP/DAP ou de pontos de interrupção encontrada | A disponibilidade das ferramentas do compilador não é integração do editor |

### Detalhes críticos do fluxo de trabalho

- `front.kf` copia apenas o arquivo ativo para `/tmp/kof-editor-run` fixo, removendo primeiro os arquivos `.kf` existentes nesse local. **[INFERENCE]** sessões simultâneas entram em conflito e a execução de mecanismos com vários arquivos não é fiel.
- O alternador de alvo da interface de Execução pode exibir JVM/JS, mas `/api/run` passa o literal `"jvm"` para `kofRun`. Isso é um defeito atual na fonte do editor, não uma limitação do compilador nativo.
- Verificação/Execução gravam primeiro o caminho de documento fornecido (`saveTempDoc` tem um nome enganoso) e depois compilam. Não são verificações inofensivas contra um buffer não salvo isolado.
- Os comandos do backend invocam `kof` a partir de `PATH`; definir apenas a variável `KOF` do script de inicialização não fixa o compilador desse subprocesso.
- A conclusão/formatação altera o estado da área de texto por caminhos diferentes dos estados normais de entrada/salvamento. **[INFERENCE]** estado de documento obsoleto pode ser salvo/restaurado; nenhuma prova de execução foi coletada. Evite transformações não salvas até que sejam testadas.
- O terminal constrói um comando com cwd como prefixo, mas envia o comando original. **[INFERENCE]** o cwd exibido não estabelece o cwd real do subprocesso. Use um terminal real para compilações.
- Nove modelos de linguagem não estabelecem nove parsers de sintaxe ativos: `/tokenize` despacha para o lexer Kof.

Fonte: [front.kf](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/ui/front.kf), [handlers web](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/src/ui/web/web.kf#L1903-L1984).

## Segurança: ferramenta de host privilegiada, não um sandbox

**Verificado na fonte:** as rotas do editor aceitam caminhos arbitrários para leitura/gravação e texto shell arbitrário para `/api/exec` e `/api/gitcmd`. Nenhuma autenticação, restrição de workspace ou verificação de Origin/CSRF aparece nesses handlers. Alguns caminhos de sistema de arquivos/Git são interpolados em comandos shell sem escape adequado. Um diretório selecionado no explorador não é um limite de segurança do sistema de arquivos.**Exposição derivada do código-fonte com o compilador inspecionado:** `scripts/web.sh` passa apenas `--port`. O Kof 0.4.9 `CmdServe` define `host = "0.0.0.0"` por padrão; o caminho legado `handle(...)` do editor passa esse host para `KofHttpServer.serve`, que cria o socket do servidor. Seu dispatch chama o handler diretamente. Portanto, o script upstream emparelhado com este compilador está configurado para escutar em todas as interfaces, não apenas no localhost. Imprimir uma URL localhost não altera o binding. Nenhum exploit foi executado. O launcher local abaixo não usa essa configuração exposta.

Para **este modo de handler legado**, passar explicitamente `--host 127.0.0.1` altera o endereço de binding. Isso ainda não adiciona autenticação, verificações de Origin ou confinamento ao workspace. Um ambiente descartável e isolado da rede, com apenas um workspace temporário, é o ambiente de pesquisa preferencial. Não execute este editor contra projetos não confiáveis, não o exponha a uma LAN nem permita que ele faça commits de alterações no monorepo.

Não confunda isso com o modo `web.app()` + `main()` do Kof: esse caminho controla seu próprio servidor e ignora as flags de host/porta da CLI. Esse não é o caminho atual de disponibilização do Kof Editor.

Evidências do compilador: [análise padrão/de flags de CmdServe](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdServe.java#L39-L84), [ramificação legada de serve](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-cli/src/main/java/dev/kof/cli/CmdServe.java#L177-L218), [KofHttpServer](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/kof-compiler/src/main/java/dev/kof/compiler/KofHttpServer.java#L39-L58).

## Fluxos de trabalho de código-fonte e pacotes

Essas interfaces upstream foram registradas durante a auditoria original do código-fonte; elas **não são o launcher local instalado**. A instalação usou `web-combine.sh` e disponibilização explícita via loopback dentro de um namespace de rede privado. Não execute o comando de servidor sem confinamento abaixo como fluxo de trabalho normal no desktop.

```sh
# Core console demonstration, not editor UI
KOF=/absolute/path/to/kof bash scripts/run.sh --no-pause
KOF=/absolute/path/to/kof bash scripts/build.sh

# Compile/serve the actual UI explicitly; set PATH for child compiler commands too
bash scripts/web-combine.sh
/absolute/path/to/kof serve build/editor-web.kf --port 8080 --host 127.0.0.1

# Upstream installer/package interfaces, not recommendations to run blindly
KOF=/absolute/path/to/kof bash scripts/install.sh
KOF_JAR=/absolute/path/to/kof.jar bash scripts/package-editor.sh
```

As dependências variam: Bash, Kof/JVM, navegador ou host WebKitGTK; Git para ações do Git, shell para processos, `zenity` opcional para seleção de pastas e o utilitário `script`. Um JDK incorporado à distribuição do compilador não torna o pacote do editor autocontido.

Inconsistências observadas no código-fonte:

- O instalador do código-fonte contém um caminho específico do autor, `/home/mel/.../kof-webview`, depois fixa `~/.local/bin/kof` e possui portas configuráveis/fixadas inconsistentes.
- Seu launcher calcula uma URL de arquivo aberto, mas não passa essa URL para o lançamento do WebView.
- O empacotador atual incorpora o código-fonte em um JAR de compilador copiado; ele não é uma compilação nativa do editor. O caminho de extração Unix parece produzir `editor/editor/src.kf` ao lançar `editor/src.kf` **[INFERÊNCIA; não reproduzida]**.
- Os empacotamentos/fluxos de trabalho misturam a tag de lançamento do compilador `0.2.6-beta` com nomes de assets `0.2.5-beta`. Não presuma que um pacote baixado use o compilador atual.
- O antigo `release.sh --jvm` fixa nomes de JAR alpha. `--native` pode suprimir uma falha de compilação e ainda criar um arquivo com nome de nativo sem um executável nativo. A existência do arquivo não é prova de execução.
- A descrição de lançamento por tag do README difere do empacotamento atual de CI manual/por push. Os scripts históricos do Swing mencionados na documentação estão ausentes do diretório de scripts inspecionado.

Fontes: [instalador](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/install.sh), [empacotador](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/package-editor.sh), [lançamento legado](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/release.sh), [fluxo de trabalho de lançamento atual](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/.github/workflows/release.yml).

## Static Pages é um modo separado

`static-snapshot.sh` captura HTML/CSS/JS do servidor e substitui chamadas HTTP por um shim de JavaScript escrito manualmente para fetch/sistema de arquivos. Isso **não** é a compilação de todo o editor por meio do KofJS.

O modo de demonstração integrado não pode compilar/executar processos nem realizar operações reais do Git. Navegadores compatíveis podem conceder acesso a um diretório selecionado pelo usuário por meio das APIs File System Access, mas ainda não possuem um compilador Kof. Uma resposta no estilo “demo: no compiler”, indicando sucesso, não é evidência de compilação. O tokenizer do navegador é uma implementação diferente e não pode certificar a validade semântica.

Fonte: [static-snapshot.sh](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/scripts/static-snapshot.sh).

## Falhas históricas do compilador não são garantias atuais

O README ainda descreve uma falha do lexer nativo contra o Kof 0.2.3-beta. Seu próprio [registro de restrições](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/docs/08-restricoes-kof.md) encerra explicitamente R1, citando correções no collector/resolution de referências e a paridade relatada com o core. Esses são relatos históricos do upstream, não um benchmark do engine 0.4.9.

Não herde proibições antigas sobre importações de módulos, nomes de campos, ordem de métodos ou sintaxe de incremento sem um reproducer atual. Da mesma forma, atualizar o Kof não corrige a cópia de arquivos temporários controlada pelo editor, alvos fixados, quoting do shell ou caminhos de pacotes.

## Decisão para o desenvolvimento do KOOKIE

Use a CLI do compilador fixada a partir da raiz real do projeto/entrada, junto com um editor existente configurado como cliente de `kof lsp`. O Kof Editor é material opcional para estudo da linguagem, **não um pré-requisito para o desenvolvimento do engine e não o editor de mundos proposto**.A documentação atual upstream do LSP descreve diagnósticos, conclusão/ajuda de assinatura da stdlib, hover, definições, referências, formatação e renomeação de projetos. Ela também documenta limitações da varredura de texto: a navegação/renomeação entre arquivos não é um índice semântico totalmente tipado e pode afetar ocorrências não relacionadas com o mesmo nome. Visualize previamente as refatorações. A extensão gerada de gramática/comandos do VS Code não estabelece automaticamente um cliente LSP conectado.

A documentação upstream descreve DAP de JVM/nativo por meio de JDWP/GDB/MI; o Kof Editor não integra esses recursos. As sessões do depurador CLI instalado foram posteriormente exercitadas após reparos locais de protocolo; consulte o limite de verificação abaixo.

```sh
kof editor list
kof editor detect
kof editor status
kof lsp
```

As ferramentas de desenvolvimento externas não violam a propriedade do mecanismo `.kf`. Não copie para o KOOKIE a interface do editor em JS dentro de strings, a duplicação ad hoc do compilador, o shell HTTP privilegiado ou a solução alternativa de build concatenada.

Referências: [contrato do LSP](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/tooling/LSP.md), [ferramentas do editor](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/editors/overview.md), [escopo do VS Code](https://github.com/KofLang/Kof4j/blob/22a186b9bf9df37c03809ba6ef4af85085386f63/docs/editors/vscode.md), [licença GPLv3 do editor](https://github.com/KofLang/Kof-Editor/blob/bed6ae7d567b090497a447583a10b8522acaf66a/LICENSE).

## Instalação local

Todos os acréscimos são locais ao usuário. Nenhuma substituição de pacote do sistema, inicialização automática da área de trabalho, serviço de editor em segundo plano ou alteração nas configurações globais da IDE foi feita.

| Componente | Local de instalação / versão |
|---|---|
| CLI do Kof | `~/.local/bin/kof` → `~/.local/share/kof4j/0.4.9-beta/bin/kof` |
| Código-fonte do compilador | Checkout persistente em `~/.local/share/kof4j/0.4.9-beta/source`, fixado no SHA acima mais o patch local das ferramentas |
| JAR do compilador | SHA-256 `9a4c133d773058a0ea3b3bf503511439e67bbb8efb80a2d5ab848dbc8274b548`; **não** é o JAR de release não modificado |
| Maven | `~/.local/bin/mvn`, Apache Maven 3.9.16; SHA-512 do arquivo oficial verificado |
| Java | OpenJDK 27 existente no sistema; o código-fonte do compilador requer Java 25 ou mais recente |
| Kof Editor | `~/.local/bin/kof-editor`, código-fonte 0.1.4-beta em `~/.local/share/kof-editor/source` |
| WebView nativo | Compilado a partir do código-fonte C do Kof4j fixado, usando WebKitGTK 4.1 / GTK 3 existentes |
| Cliente LSP / DAP | MrCode existente, extensão local instalada `lich-local.kof-lsp-client@0.1.0`; `vscode-languageclient` 9.0.1 |
| Pré-requisitos nativos | GCC 16.2, binutils 2.47, GDB 17.2, pkg-config, SDL3 3.4.16, cabeçalhos/carregador Vulkan, ShaderC e SPIRV-tools existentes |
| Outros pré-requisitos | Git, Bash, curl, unzip, Python, bubblewrap e ferramentas DBus existentes |

```sh
kof version
mvn --version

# Run from the real entry/project directory; relative assets keep that cwd.
kof check main.kf --target native
kof run main.kf --target native
kof run main.kf --target jvm

# Kof Editor: explicitly choose the only project exposed to its backend.
kof-editor --workspace /absolute/project /absolute/project/main.kf
kof-editor --check --workspace /absolute/project

# LSP-capable development workflow; reload an already-open MrCode window.
mrcode /home/lich/lichforge/code/monorepo/engines/KOOKIE
```

No MrCode, confie apenas em projetos cuja execução do compilador/depurador você autorizar. A extensão reconhece `.kf` e `.kof`; ela inicia `kof lsp` por stdio em vez de abrir um terminal. Use **Kof: Select Target**, **Run Active File**, **Check Active File**, **Build Active File Directory** e **Format Active Document**. `.vscode/tasks.json` fornece seleção explícita de destino e tarefas do projeto; `.vscode/launch.json` fornece configurações F5 de JVM/nativo. A análise do LSP ainda usa a semântica JVM upstream; a verificação nativa é uma tarefa CLI separada. A extensão é desabilitada em espaços de trabalho não confiáveis e virtuais.

### Confinamento local do editor

A entrada da área de trabalho usa KOOKIE por padrão; a CLI pode selecionar outro projeto. O inicializador inicia o backend JVM e a janela real do WebKitGTK dentro do bubblewrap, com rede privada e namespaces privados de PID/IPC/UTS, além de uma sessão DBus privada. Apenas o projeto selecionado pode ser gravado em `/workspace`; os arquivos do sistema/compilador/editor são somente leitura. O diretório inicial do host, as credenciais SSH e os projetos não relacionados não são expostos. O backend `127.0.0.1:8765` existe apenas dentro dessa rede privada, não no loopback do host nem na LAN. Os comandos do compilador usam a instalação fixada. O estado e `server.log` ficam em `~/.local/state/kof-editor/workspaces/`.

Isso confina os manipuladores privilegiados upstream; **não** corrige a autenticação, o escaping do shell, o cwd do Git ou o comportamento de execução JVM de arquivo único. Não use o Git/terminal integrado com conteúdo não confiável. O Git remoto e os downloads ficam intencionalmente indisponíveis dentro da rede privada. Use o MrCode e um terminal real para projetos nativos ou com vários arquivos. Fechar o inicializador recolhe os grupos de processos do servidor/janela.

### Reparos locais nas ferramentas e limite de verificação

O compilador não modificado expunha defeitos de ferramentas reproduzíveis. O patch local do código-fonte mantém buffers LSP de sincronização completa após edições, remove buffers fechados e emite tipos de conclusão numéricos. O DAP agora emite `initialized` assim que o backend está pronto, conclui a configuração antes de confirmar o lançamento, relata a saída da JVM pertencente ao processo e desconecta JVMs anexadas sem encerrá-las. A avaliação nativa coloca a expressão GDB/MI entre aspas como um único argumento. Nenhuma semântica do compilador/runtime foi alterada.

Verificado:

- CLI final instalada: verificação, build e execução JVM/nativa; acesso relativo a arquivos e `math.sqrt(81.0)` retornando `9.0`.
- LSP stdio instalado: diagnósticos inválidos, limpeza após edições, conclusão, hover e formatação usando o buffer atualizado.
- DAP JVM instalado e DAP nativo com GDB real: inicialização/configuração, breakpoint em `.kf`, frame da pilha de origem, continuação e término. Foram observados o `value = 41` local da JVM e a avaliação nativa `40 + 2 = 42`.
- Grupo focado de regressão do compilador: 46 testes, zero falhas/erros/ignorados.
- Janela nativa real do Kof Editor: inspecionada visualmente em X11 isolado; abrir/salvar/verificar/executar no backend funcionou. A exclusão do diretório inicial do host, a montagem somente leitura do compilador e o namespace de rede privado foram verificados.
- Host de extensão real do MrCode: associação de `.kf`/`.kof`, limpeza de diagnósticos, conclusão, hover e formatação; a execução JVM/nativa preservou o acesso relativo a arquivos, e ambas as sessões F5 pararam na linha 3 e terminaram após a continuação. O breakpoint nativo também foi inspecionado visualmente.Recibos, rastros de protocolo e capturas de tela do editor/IDE são mantidos em
`~/.local/state/kof-tooling-verification/`. As verificações gráficas usaram o wrapper
`overzeer-isolated-display.sh` revisado, com sockets privados, duração limitada,
execução serializada, controle de pressão e limpeza da árvore de processos — não o
desktop ativo. Nenhuma matriz de testes abrangente do repositório foi executada.

O smoke test nativo não retornou variáveis locais para sua variável local constante
simples; somente a avaliação de expressões nativas está estabelecida, não uma
inspeção abrangente de variáveis. O stepping/avaliação da JVM, todas as solicitações
LSP, o KofJS no navegador, todos os menus do editor e a pilha de gráficos/áudio do
mecanismo não foram verificados por esta instalação.
O MrCode emitiu uma notificação de erro genérica e sem atribuição durante a depuração
automatizada; o rastreamento DAP capturado não continha solicitações com falha ou sem
resposta, e ambas as sessões foram concluídas. Isso não afirma que todas as
notificações do IDE estejam resolvidas.
O adaptador nativo também relata seu código de saída como uma string no evento upstream
capturado; consumidores estritos podem exigir trabalho adicional no protocolo.
A poda do runtime nativo ainda emite um aviso quando sua pesquisa relativa à origem
falha e emite o runtime completo; a execução nativa que preserva o cwd foi aprovada
com esse aviso.
Os riscos de duração do manipulador nativo, JSON de registros fracionários e
`spawn`/GC cumulativos registrados na pesquisa continuam sendo bloqueadores G0 do
mecanismo, não correções da instalação.

Para manutenção, mantenha o JSON da instalação, o JAR upstream original e
`artifacts/tooling-fixes.patch` em `~/.local/share/kof4j/0.4.9-beta/`.
Uma reinstalação upstream pode sobrescrever o JAR corrigido: reaplique/revise o patch,
execute os testes LSP/DAP focados e repita os fluxos de trabalho instalados antes de
mudar de versão. O código-fonte do editor, o launcher e a proveniência são mantidos em
`~/.local/share/kof-editor/`; o código-fonte do cliente, o lockfile e o VSIX instalável
em `~/.local/share/kof-lsp-client/`.