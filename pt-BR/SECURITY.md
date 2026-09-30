# Política de segurança

[English](../SECURITY.md)

O KOOKIE é um software experimental, mas autenticação, parsers, pacotes,
persistência e procedência de releases são tratados como fronteiras de
segurança.

## Estado com suporte

Correções de segurança têm como alvo o branch `main` atual e, quando viável, o
release dogfood assinado mais recente. Tags antigos e pacotes modificados
localmente não são linhas de release com suporte.

## Relate uma vulnerabilidade de forma privada

Use o [relato privado de vulnerabilidades do GitHub](https://github.com/rufl/KOOKIE/security/advisories/new).
Não abra uma issue pública para uma vulnerabilidade capaz de expor credenciais,
forjar tráfego autenticado, contornar verificações de pacote/assinatura,
corromper estado durável ou executar entrada não confiável.

Inclua, quando disponível:

- o commit ou tag de release afetado e a plataforma alvo;
- a fronteira envolvida: transporte, parser/cooker, pacote, save/replay,
  assinatura/procedência ou dependência incluída;
- o impacto e a menor entrada ou sequência reproduzível;
- logs focados sem credenciais, chaves de transporte nem dados privados da
  máquina;
- se o problema se reproduz num checkout sem modificações.

Nunca anexe chaves de assinatura, tokens de deploy, segredos de transporte nem
evidência privada entre hosts.

## Resposta e divulgação

Não existe SLA de suporte comercial. Os relatos são triados conforme a
capacidade do mantenedor. Reprodução, escopo e um ponto coordenado de divulgação
são definidos antes da publicação. Uma correção não é considerada completa até
a fronteira afetada ter uma regressão focada ou sonda executável.

Sugestões de hardening não sensíveis e bugs comuns de correção pertencem ao
rastreador público de issues.
