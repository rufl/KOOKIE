# Biblioteca de UI do KOOKIE

`src/ui/kookie_ui.kf` é a primeira fatia interna de apresentação para Kof e
KofJS. É uma fachada pequena sobre `kof.ui`, não um fork da stdlib do Kof. A
organização aproveita as fronteiras úteis de ZLAY, ZFONT, ZPIX, ZDOM e ZWEB,
mas mantém a posse no código-fonte do KOOKIE.

O contrato de GUI tem duas camadas de fonte. `src/ui/kookie_ui.kf` possui a
fachada Kof/KofJS baseada em handles e a composição de renderização.
`src/ui/kookie_ui.ks` é a companheira sandbox de KofScript: emite um descritor
semântico limitado `KookieUiScriptDocument` com nós de texto, asset e ícone,
validação de checksum/caminho/texto alternativo da publicação e estado de ciclo
de vida determinístico. Os runtimes KofScript atuais não expõem handles
`Window`, `Label`, `Image` ou `Icon`; a camada de script não renderiza nem retém
handles nativos, e um host Kof/KofJS consome o descritor.

As duas camadas expõem `bindMenu` e `bindHud`: Kof/KofJS constrói superfícies
compostas de `View`/`Column`/`Row`, enquanto KofScript emite os nós de texto
ordenados correspondentes para um adaptador host.

## Contrato

| Responsabilidade | Superfície KOOKIE | Dono |
| --- | --- | --- |
| Layout e superfícies | `kookieUi*Style`, `View`, `Column`, `Row` | DOM do Kof/KofJS |
| Papéis de fonte | `kookieUiFontBody`, `kookieUiFontDisplay`, `KookieUiText` | estilo Kof + CSS do host |
| Assets SVG/PNG | `KookieUiAsset` | `Image` no KofJS; host/adaptador nativo fora desta fatia |
| Ícones vetoriais embutidos | `KookieUiIcon` | registro intrínseco de SVG do Kof |
| Texto de acessibilidade | argumento `alt` não vazio no construtor, `bindAssetDescription`, `bindIconDescription` | árvore de labels do Kof |
| Composição da janela | `KookieUiDocument` | `Window` do Kof |
| Views reutilizáveis de menu/HUD | `bindMenu`, `bindHud` | composição compartilhada Kof/KofJS |
| Componentes retidos | `KookieUiLayoutSpec`, `KookieUiPanel`, controles comuns e superfícies de editor | composição compartilhada Kof/KofJS |
| Descritor sandbox de KofScript | `KookieUiScriptDocument` | descritor semântico limitado consumido por um host Kof/KofJS |
| Efeitos sonoros da UI | `KookieUiSoundCue`, `KookieUiSoundBank` | adaptador de fila limitada sobre áudio nativo |

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
- KofScript: `KookieUiScriptDocument` é a camada semântica limitada. Ela não
  possui handles `kof.ui` e não renderiza sozinha; o host deve mapear seus
  descritores para a fachada Kof/KofJS baseada em handles.

### Skin nativo da engine

`src/ui/kookie_ui_native.kf` é o contraparte nativo da mesma paleta, métricas
de fonte e semântica de foco. Ele não cria um segundo renderer:
`KookieUiNativeTheme` possui as cores/recursos semânticos e os helpers limitados
escrevem diretamente no contrato existente de `FrameStaging`.

Os menus da engine (`GameShell`) agora usam esse skin para superfícies,
trilhos de seleção, cores de texto, barras de volume e contraste. O HUD de
gameplay acrescenta os rótulos estáveis `HP`, `AMMO`, `BAG` e `XP` às camadas
de vida/build/encontro/combate; nameplates, minimapa e scoreboard usam os
mesmos primitivos nativos e a mesma configuração de contraste. A geometria
continua pré-alocada e limitada; o orçamento do HUD é de 438 vértices.

O atlas nativo mapeia os mesmos tokens para a paleta do pacote:
background `#0f172a`, surface `#0f1f2b`, accent `#d97706`, focus `#15803d`,
danger `#dc2626` e success `#22c55e`. Isto é somente estilo de apresentação;
a autoridade de simulação/sessão não muda.

### Orçamento de renderização

`FrameStaging` escreve quads e triângulos em uma operação limitada, preservando
a mesma ordem de vértices e o orçamento escalar sem repetir validação por
vértice. A apresentação nativa reconhece esses spans e usa chamadas de cena em
lote. As capacidades das cenas CPU/GPU crescem com folga, evitando reconstruir
buffers GPU a cada pequena mudança de quantidade ao alternar HUD e menus. O UI
de gameplay continua em uma única chamada de draw; a geometria do mundo fica
no passe separado com depth test.

### Layout e kit de componentes

`src/ui/kookie_ui_components.kf` adiciona uma camada limitada de componentes
retidos para apps, jogos e superfícies do Kutter/editor:

| Camada | Superfície reutilizável |
| --- | --- |
| Layout | `KookieUiLayoutSpec`, `KookieUiLayout`, `KookieUiPanel` |
| Controles | `KookieUiButton`, `KookieUiTextField`, `KookieUiToggle`, `KookieUiSlider` |
| Feedback | `KookieUiProgressBar`, `KookieUiBadge` |
| Composição | `KookieUiToolbar`, `KookieUiTabs`, `KookieUiInspector` |

`KookieUiLayoutSpec` possui direção, gap/padding limitados, alinhamento,
semântica de preenchimento e uma descrição CSS determinística.
`KookieUiLayout` aplica o contrato a filhos `Column`/`Row`; `KookieUiPanel`
adiciona variantes de superfície sem criar outro renderer. Os controles comuns
mantêm estado no Kof e no handle KofJS, portanto os probes JVM/native não
dependem de propriedades no-op de `kof.ui`. Botões expõem
`pressed`/`consumePressed`, toggles expõem `checked`, sliders limitam a faixa
declarada, e tabs/inspectors rejeitam overflow de capacidade.

O kit é neutro em relação ao host: KofJS renderiza os handles, enquanto o
gameplay nativo continua usando `kookie_ui_native.kf` e `FrameStaging`. Os
controles mantêm alvo mínimo de toque de 44px, rótulos visíveis e a paleta
semântica escura compartilhada. `KookieUiToolbar`, `KookieUiTabs` e
`KookieUiInspector` cobrem as superfícies comuns de editores de jogos sem
importar autoridade do editor ou ponteiros nativos para o pacote de UI.

Exemplo:

```kof
var layout = kookieUiColumnLayout(8, 12)
var panel = KookieUiPanel(kookieUiPanelRaised(), layout)
var play = KookieUiButton("PLAY", kookieUiButtonPrimary())
var health = KookieUiProgressBar(0, 100, 75)
var inspector = KookieUiInspector(8)
inspector.addEntry("Mode", "Play")
panel.bindColumn(Column(listOf(play.widget(), health.widget(), inspector.widget())))
document.bindView(panel.widget())
```

`kof.ui.Style` exige declarações CSS literais no compilador atual. O estado de
layout continua exato no spec limitado, enquanto os presets renderizados de
KofJS usam estilos estáticos tokenizados; isso mantém os builds JVM/native/
KofJS determinísticos sem criar um runtime CSS dinâmico não verificado.

Use `scripts/verify_ui_library.sh` para o check focado. Ele executa o probe em
JVM/native, executa a companheira KofScript em JVM/native e faz
type-check/build do artefato KofJS. Uma janela KofJS interativa permanece viva
até o host fechá-la; por isso o check não finge que uma saída temporizada da
CLI é prova de renderização.

### Cues de som e fronteira com o Kof4j

`src/ui/kookie_ui_audio.kf` é a fatia de áudio reutilizável.
`KookieUiSoundCue` mantém path `.ogg`/`.wav` relativo ao pacote, SHA-256
minúsculo, label semântico, clip ID nativo e gain. `KookieUiSoundBank` admite
no máximo 32 cues antes de abrir, rejeita IDs/clip IDs duplicados, enfileira
reprodução FIFO ou espacial via `core.QueuedAudio` e expõe metadados consumidos
para o adapter nativo. Não decodifica arquivos nem retém handles SDL.

`src/ui/kookie_ui_audio_catalog.kf` é a fronteira de publicação nativa:
`kookieUiPublishedSoundCue` verifica tuplas exatas de source/digest para os 14
clip IDs OGG nativos da UI, e `kookieUiSoundBankAddPublished` admite somente
esses cues. `KookieUiSoundBank.add()` genérico continua disponível para cues
WAV genéricos ou adapter externo futuro. O SHA-256 do descritor não substitui
um gate de bytes/licença na release.

O adapter SDL nativo consome os gains resultantes por
`kookie_audio_play_ui_clip_spatial`, que aplica `MIX_SetTrackStereo` à track UI
pré-decodificada registrada. A companheira KofScript expõe o mesmo nó semântico
com `bindSound(..., defaultGain)`, `nodeClipId()` e `nodeGain()`. As duas
camadas continuam descritores/adapters: `kof.media` possui arquivos e handles
de mídia, enquanto uma futura API upstream de playback precisa definir
ownership, close, gain, loop, espacialização e falha por target antes desta
fatia migrar para o Kof4j. Veja
[`KOF4J_UI_MIGRATION.md`](KOF4J_UI_MIGRATION.md) para a auditoria da ABI
0.5.0-beta e a fronteira de migração de buffers.


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

O kit de componentes é a camada retida atual; novas superfícies devem reutilizar
esses contratos antes de introduzir outro renderer, estado de autoridade ou
ponteiro nativo.
