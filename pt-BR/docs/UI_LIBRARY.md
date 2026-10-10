# Biblioteca de UI do KOOKIE

`src/ui/kookie_ui.kf` é a primeira fatia interna de apresentação para Kof e
KofJS. É uma fachada pequena sobre `kof.ui`, não um fork da stdlib do Kof. A
organização aproveita as fronteiras úteis de ZLAY, ZFONT, ZPIX, ZDOM e ZWEB,
mas mantém a posse no código-fonte do KOOKIE.

## Contrato

| Responsabilidade | Superfície KOOKIE | Dono |
| --- | --- | --- |
| Layout e superfícies | `kookieUi*Style`, `View`, `Column`, `Row` | DOM do Kof/KofJS |
| Papéis de fonte | `kookieUiFontBody`, `kookieUiFontDisplay`, `KookieUiText` | estilo Kof + CSS do host |
| Assets SVG/PNG | `KookieUiAsset` | `Image` no KofJS; host/adaptador nativo fora desta fatia |
| Ícones vetoriais embutidos | `KookieUiIcon` | registro intrínseco de SVG do Kof |
| Texto de acessibilidade | argumento `alt` não vazio no construtor, `bindAssetDescription`, `bindIconDescription` | árvore de labels do Kof |
| Composição da janela | `KookieUiDocument` | `Window` do Kof |

A fachada possui metadados, limites e composição. Ela não decodifica bytes de
imagem, rasteriza fontes, altera estado de gameplay nem retém ponteiros nativos.

## Exemplo

```kof
import ui

main() {
    var document = KookieUiDocument("GatoGanso", 960, 540)
    var title = KookieUiText(
        "GATOGANSO", kookieUiTextRoleDisplay(), 32, true,
        kookieUiForeground())
    var logo = kookieUiPublishedUiGatogansoMark()
    var hearts = kookieUiPublishedUiPlayerHearts()

    document.bindText(title)
    document.bindAsset(logo, 32)
    document.bindAssetDescription(logo)
    document.bindAsset(hearts, 48)
    document.bindAssetDescription(hearts)
    document.show()
}
```

Os construtores publicados em `src/ui/published_assets.kf` são gerados a partir
de `assets/ui/manifest.json`; os chamadores devem usá-los em vez de copiar IDs,
caminhos ou digests para o código da aplicação. A fonte é verificada com:

```bash
python3 scripts/generate_ui_manifest_kf.py --check \
  assets/ui/manifest.json src/ui/published_assets.kf
```

`KookieUiAsset.accepted()` valida o formato da referência: ID não vazio,
caminho de runtime seguro e relativo ao pacote, texto alternativo, tipo/extensão
e uma string SHA-256 minúscula de 64 caracteres. Não lê bytes, consulta o
manifesto nem verifica a integridade do arquivo.

`assets/ui/manifest.json` é o contrato de publicação. Os gates de pacote e da
demo resolvem IDs pelas entradas `runtime_path` e verificam o digest declarado
antes de servir ou admitir conteúdo. Um chamador que constrói
`KookieUiAsset` diretamente ainda precisa usar um registro desse fluxo de
publicação verificado; `accepted()` sozinho não prova que o ID foi publicado
nem que os bytes correspondem ao digest. Entradas de protótipo podem faltar no
pacote `none`, mas precisam existir e ter hash validado no pacote `prototype`.
O manifesto declara separadamente que a demo UI isolada exige sua entrada de
protótipo; por isso o gate da demo falha se o PNG não for preparado.
O gate compartilhado `scripts/verify_ui_manifest.py` valida o mesmo manifesto
contra a árvore de runtime preparada nos perfis `none`, `prototype` e demo.
O perfil `none` pode omitir somente o PNG de corações de protótipo; os outros
perfis precisam conter todos os assets declarados e corresponder a cada digest.
`publication.optional_asset_ids` é a lista autoritativa dessa exceção.

A árvore-fonte pode preparar os assets autorados nos caminhos de runtime do
manifesto:

```bash
python3 scripts/stage_ui_manifest.py \
  assets/ui/manifest.json . build --profile prototype
```

Os assets-fonte ainda precisam passar pelo pipeline antes da publicação nativa:

```bash
scripts/kooker.sh cook png input.png output.rgba.png
scripts/kooker.sh cook svg input.svg output.svgc
scripts/kooker.sh cook svgz input.svgz output.svgzc
```

## Fontes e renderização

Os papéis distribuídos são:

- corpo: `Jared Lite`, `fonts/jared-lite.ttf`;
- display: `Pixand`, `fonts/pixand.ttf`.

Carregue `assets/ui/kookie-ui.css` no host KofJS antes do módulo gerado. As
URLs relativas das fontes funcionam na árvore-fonte (`assets/fonts`) e em um
host de pacote que mantenha o CSS em `assets/ui` e as fontes empacotadas em
`fonts`:

```html
<link rel="stylesheet" href="assets/ui/kookie-ui.css">
```

`KookieUiText` aplica família, altura de linha, tamanho, peso e cor ao mesmo
handle de `Label`. O `Font` do Kof 0.5.0-beta registra metadados, mas não anexa
a fonte CSS a um Label; esta fatia usa portanto o caminho de estilo suportado,
sem alegar que uma atribuição isolada é renderizada.

## Fronteira dos alvos

- KofJS: `Window`, `Label`, `Image`, `Icon`, `View`, `Column` e `Row` viram
  nós DOM e renderizam na página gerada. SVG usa `Image` nativo do navegador ou
o caminho de ícone intrínseco; PNG usa `Image`.
- JVM/native: o mesmo código compila e a fachada mantém metadados/estado
  determinísticos. Os handles `kof.ui` são no-op por contrato do Kof. O HUD de
  gameplay SDL continua usando `FrameStaging` e o adaptador nativo verificado;
  esta biblioteca não cria silenciosamente um segundo renderer nativo.

Use `scripts/verify_ui_library.sh` para o check focado. Ele executa o probe em
JVM/native e faz type-check/build do artefato KofJS. Uma janela KofJS
interativa permanece viva até o host fechá-la; por isso o check não finge que
uma saída temporizada da CLI é prova de renderização.

## Acessibilidade e estilo

- Todo asset raster/vetorial admitido por esta fatia exige texto alternativo
  não vazio.
- Esta fatia não modela assets decorativos; use assets semânticos somente com
  texto significativo e monte o label de descrição correspondente quando o
  conteúdo comunicar significado.
- Preserve o contraste da paleta escura e o foco visível definido em
  `assets/ui/kookie-ui.css`.
- Use o conjunto intrínseco de ícones SVG em controles, não emoji ou glifos de
  texto.
- Mantenha a composição em `View`/`Column`/`Row`; não coloque autoridade de
  jogo ou handles nativos neste pacote.

A próxima camada pode adicionar componentes retidos e layout mais rico somente
depois que os limites atuais de handles, assets e alvos permanecerem estáveis.
