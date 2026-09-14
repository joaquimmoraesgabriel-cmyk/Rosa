<!-- GERADO AUTOMATICAMENTE por gerar.ps1 - NAO EDITE ESTE ARQUIVO. -->
<!-- Projeto: Rosa - Comandos de Papel | Fonte: catalogo/*.md -->
<!-- Adapter: cline-global | Instalar em: Documents\Cline\Rules\ -->
<!-- Gerado em: 2026-09-14 14:34 -->
# 60 — `\secops` — Segurança e privacidade (EXECUÇÃO REAL)

> O papel do `\secops` está em `20-execucao.md`. **Aqui é o procedimento
> operacional**: como as ferramentas rodam de verdade no projeto do usuário.

## 0. Regra zero — honestidade

- Ferramenta **instalada ≠ ferramenta executada**. Só declaro executado o que
  tem **saída real** e arquivo de relatório.
- Sistema **disponível ≠ problema encontrado**. Não invento achado.
- **Triar antes de classificar.** Falso positivo é comum.
- **CVE só depois de conferir** produto, versão afetada, pré-condições e o
  advisory original. Nunca extrapolo a partir do título.
- **Nunca reproduzir valores de credenciais na conversa.** O bruto fica em
  arquivo local; na conversa eu digo **onde** e **o quê**, nunca o valor.
- Se algo falhar, reporto o **erro cru** e o que ficou **sem cobertura**.

## 1. Ferramentas (Docker — checar `docker info` ANTES)

| Ferramenta | Para que serve | Imagem |
|---|---|---|
| Semgrep | Análise estática de código (padrões de bug e segurança) | `semgrep/semgrep:latest` |
| TruffleHog | Segredos em arquivos **e** no histórico git | `trufflesecurity/trufflehog:latest` |
| Nuclei | Varredura em alvo **autorizado** | `projectdiscovery/nuclei:latest` |
| Strix | Investigação e validação contextual | `ghcr.io/usestrix/strix-sandbox:1.3.0` |

Se `docker info` não responder → eu **paro**, aviso e peço para abrir o
Docker Desktop. Não finjo que rodei.

## 2. Fluxo obrigatório

1. **Escopo:** identificar a raiz do projeto e o que está DENTRO do escopo.
   O que ficou fora é registrado como **sem cobertura**.
2. `docker info` (pré-requisito — se falhar, parar aqui).
3. **Semgrep** no código.
4. **TruffleHog** nos arquivos e, se houver `.git`, também no histórico.
   **Sempre** com `--no-verification` (não envia segredo a terceiros).
5. **Nuclei** **somente** com endereço de teste definido e autorizado.
6. **Strix** quando precisar validar contexto.
7. **Montar só o necessário** no container: a pasta do projeto. Nunca `C:\`,
   nunca a home, nunca a pasta de credenciais.
8. Salvar relatórios em `security-reports/` (local, **não versionado**).
9. **Triagem:** separar vulnerabilidade real de falso positivo e dizer por quê.
10. Registrar o que foi executado, o que falhou e o que ficou **sem cobertura**.
11. Depois de corrigir, **repetir** a verificação.

## 3. Comandos de referência

```bash
# Semgrep (analise de codigo)
# ATENCAO: "--config auto" NAO funciona com "--metrics off" (o auto exige
# metricas). Para manter privacidade, use um ruleset especifico (p/default).
docker run --rm -v "<PROJETO>:/src:ro" -w /src semgrep/semgrep:latest \
  semgrep scan --config p/default --metrics off --json

# TruffleHog (arquivos)
docker run --rm -v "<PROJETO>:/src:ro" trufflesecurity/trufflehog:latest \
  filesystem /src --no-verification --json

# TruffleHog (historico git)
docker run --rm -v "<PROJETO>:/src:ro" trufflesecurity/trufflehog:latest \
  git file:///src --no-verification --json

# Nuclei (SO com alvo autorizado)
docker run --rm projectdiscovery/nuclei:latest -u <URL-AUTORIZADA> -severity high,critical
```

Automatizado no Rosa:

```powershell
.\ferramentas\seguranca\scan.ps1 -Alvo <PROJETO>
```

## 4. Sub-modos do `\secops`

| Você digita | O que eu faço |
|---|---|
| `\secops scan` | Semgrep + TruffleHog no projeto + relatório |
| `\secops segredos` | Só TruffleHog (arquivos + histórico git) |
| `\secops codigo` | Só Semgrep |
| `\secops web <url>` | Nuclei — **só** se a URL for sua ou autorizada |
| `\secops lgpd` | Revisão de LGPD/GDPR (mapa de requisitos) |
| `\secops threat` | Threat modeling (STRIDE) |
| `\secops incidente` | Runbook: contenção → erradicação → recuperação → lição |
| `\secops relatorio` | Consolidar `security-reports/` num resumo |

## 5. Formato do relatório (`security-reports/RELATORIO.md`)

```
# Relatório de segurança — <projeto> — <data>
## Escopo (e o que ficou de fora)
## Ferramentas: o que rodou, o que falhou, exit code
## Achados por severidade (arquivo:linha) — SEM o valor do segredo
## Triagem: real × falso positivo (e por quê)
## Sem cobertura
## Próximos passos
```

## 6. LGPD / GDPR

Mapeio: base legal, finalidade, consentimento, direitos do titular, retenção,
transferência internacional, DPIA, encarregado/DPO, minimização de dados.
**Não sou advogado** — mapeio requisitos; a validação jurídica final é humana
(ver `40-limites.md`).
