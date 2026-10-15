# Observabilidade dos builds no CI

[English](../../docs/CI_BUILD_OBSERVABILITY.md)

Builds native do Kof passam por `scripts/kof_observed.sh`, chamado pelo helper
`kookie_kof_observed` de `scripts/kof_pin.sh`. O wrapper fornece comando com
limite, linhas periódicas de progresso, log completo e ETA histórico.

## Uso local

```bash
source scripts/kof_pin.sh
kookie_kof_observed local-jvm \
  kof build probes/g0_platform/main.kf \
  --target jvm --output /tmp/kookie-jvm
```

O wrapper imprime linhas como:

```text
kof-observed: name=canonical-native state=start timeout=1800s heartbeat=30s estimate=unknown basis=none log=...
kof-observed: name=canonical-native state=running elapsed=30s eta=unknown timeout-in=1770s
kof-observed: name=canonical-native state=passed duration=... log=...
```

A primeira execução bem-sucedida não tem ETA histórico. As seguintes usam a
média arredondada das últimas cinco execuções bem-sucedidas do mesmo pin Kof e
stage. ETA é orientação, não progresso interno do compilador; `overdue+Ns`
significa que a estimativa histórica foi excedida enquanto o timeout continua
ativo.

## Controles

| Variável | Padrão | Significado |
|---|---:|---|
| `KOOKIE_KOF_BUILD_TIMEOUT_SECONDS` | `1800` | Timeout rígido de cada comando Kof. |
| `KOOKIE_KOF_BUILD_HEARTBEAT_SECONDS` | `30` | Intervalo de progresso. |
| `KOOKIE_KOF_BUILD_KILL_AFTER_SECONDS` | `30` | Graça após timeout. |
| `KOOKIE_KOF_BUILD_ESTIMATE_SECONDS` | unset | Semente explícita de ETA para uma execução. |
| `KOOKIE_BUILD_LOG_DIR` | `/tmp/kookie-build-logs` | Diretório dos logs completos. |
| `KOOKIE_KOF_BUILD_HISTORY_DIR` | `$XDG_CACHE_HOME/kookie` | Diretório de `build-times.tsv`. |

Os jobs native do Verify e de release sobrescrevem
`KOOKIE_KOF_BUILD_TIMEOUT_SECONDS` para `2700` segundos (45 minutos); o job
native/package do Verify recebe timeout externo de 150 minutos. Stages
individuais podem sobrescrever o valor por
`KOOKIE_KOF_BUILD_TIMEOUT_<STAGE>_SECONDS`; o helper normaliza o nome do stage
para maiúsculas com underscores.

`KOOKIE_KOF_BUILD_HISTORY_FILE` pode substituir diretamente o arquivo de
histórico. Durações só são registradas após exit code zero; timeout não vira uma
base falsa para ETA.

O workflow Verify publica os logs como artifact
`kookie-kof-build-diagnostics-*`. O cache do build canônico também guarda o
histórico para que execuções futuras exibam ETA. Os jobs de release Linux/Windows
publicam artifacts próprios de diagnóstico.

O wrapper não infere porcentagem concluída porque Kof não oferece um protocolo
estável e legível por máquina para progresso da compilação native. Os sinais
confiáveis são stage, tempo decorrido, ETA histórico, contagem regressiva do
timeout, exit code e caminho do log completo.
