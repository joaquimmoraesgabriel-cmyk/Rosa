<!-- GERADO AUTOMATICAMENTE por gerar.ps1 - NAO EDITE ESTE ARQUIVO. -->
<!-- Projeto: Rosa - Comandos de Papel | Fonte: catalogo/*.md -->
<!-- Adapter: cline-global | Instalar em: Documents\Cline\Rules\ -->
<!-- Gerado em: 2026-09-15 14:25 -->
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

| Ferramenta | Para que serve | Onde roda |
|---|---|---|
| Semgrep | Análise estática de código (padrões de bug e segurança) | Docker `semgrep/semgrep:latest` |
| TruffleHog | Segredos em arquivos **e** no histórico git | Docker `trufflesecurity/trufflehog:latest` |
| Nuclei | Varredura em alvo **autorizado** | Docker `projectdiscovery/nuclei:latest` |
| Strix | **Pentest autônomo com IA** (ataca de verdade e valida com PoC) | Binário local `strix` (não é Docker puro) |

Semgrep, TruffleHog e Nuclei são **estáticos/baratos**. O Strix é **outra
categoria** — veja a seção 3.b antes de pensar em rodá-lo.

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
.\ferramentas\seguranca\scan.ps1 -Alvo <PROJETO>     # Semgrep + TruffleHog (+ Nuclei)
.\ferramentas\seguranca\strix.ps1 -Alvo <ALVO> -Autorizo   # Strix (leia a secao 7)
```

---

## 3.b. Strix — pentest autônomo com IA (cuidados especiais)

O Strix é um **agente de IA** que ataca o alvo de verdade e valida com PoC.
Ele **não** é um scanner comum. Três características mudam tudo:

| Característica | Consequência |
|---|---|
| Precisa de **LLM** (`STRIX_LLM` + `LLM_API_KEY`) | sem modelo, não roda. A chave é **sua** e **nunca** passa pelo chat |
| **Gasta dinheiro** (tokens) | sempre rodar com `--max-budget`. O teto é obrigatório na prática |
| Monta a pasta do projeto **ESCREVÍVEL** no sandbox e **edita seus arquivos** | a doc oficial diz: *"commit or stash first"* |
| Só pode rodar em alvo **autorizado** | teste sem autorização é **ilegal** na maioria das jurisdições |

**Como o Rosa liga isso** (`ferramentas/seguranca/strix.ps1`) — 4 portões que
**param** antes de qualquer coisa:

1. `-Autorizo` (você confirma que tem autorização) → senão, para.
2. `STRIX_LLM` + `LLM_API_KEY` no ambiente → senão, para e diz o que você faz.
3. `strix` no PATH + `docker info` respondendo → senão, para.
4. Alvo local com alterações **não commitadas** → para e pede `-AceitarEdicao`.

Existe também `-Simular`: **mostra o comando e não executa nada, sem gastar nada.**

**Exit codes do Strix (importante na hora de interpretar):**

| Código | Significado |
|---|---|
| `0` | concluído **sem** vulnerabilidades (headless) |
| `1` | erro fatal (ex.: faltando variável, Docker fora, config inválida) |
| `2` | **vulnerabilidades encontradas** — **não** é erro, e **não** é confirmação humana |

**Artefatos:** cada run grava `strix_runs/<run>/` com `vulnerabilities.json`,
`vulnerabilities.csv`, `findings.sarif` (SARIF 2.1.0) e Markdown por achado.

**Modos:** `quick` (minutos, bom para CI) · `standard` (30–60 min) ·
`deep` (1–4 h, é o padrão do Strix — mas aqui o padrão é `quick`, por custo).

> **Nunca** trato exit `2` como "vulnerabilidade confirmada". O PoC diz que o
> agente achou; **eu** leio e trio antes de classificar.

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
| `\secops strix <alvo>` | Pentest autônomo com IA — **exige sua autorização + chave LLM** (seção 3.b) |

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
