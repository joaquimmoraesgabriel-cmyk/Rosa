<!-- GERADO AUTOMATICAMENTE por gerar.ps1 - NAO EDITE ESTE ARQUIVO. -->
<!-- Projeto: Rosa - Comandos de Papel | Fonte: catalogo/*.md -->
<!-- Adapter: cline-global | Instalar em: Documents\Cline\Rules\ -->
<!-- Gerado em: 2026-09-15 14:25 -->
# 70 — `\recon` — Reconhecimento para bug bounty (EXECUÇÃO REAL)

> Comando do papel `\secops`, mas com foco em **recon**: mapear o alvo antes de
> testar. É a etapa que **realmente separa** quem ganha bounty de quem só roda
> scanner e recebe "duplicado".

## 0. Regra zero — legal e honestidade

- **Só rode em alvo AUTORIZADO.** Isso significa: você é o dono, OU o alvo está
  **dentro do escopo** de um programa e a **policy permite** essa atividade.
- Não existe "achei por acidente". Fora de escopo = **ban + risco jurídico**.
- A **policy do programa manda**, não a plataforma. Ler a policy é etapa 0.
- Ferramenta instalada ≠ ferramenta executada. Só declaro o que tem saída real.
- Resultado de recon **não é vulnerabilidade**. É superfície de ataque.
- **Não sou advogado.** Nada aqui é orientação jurídica.

## 1. O pipeline

```
subfinder → dnsx → httpx → katana / gau → nuclei
   subs      DNS     vivos     URLs/endpoints    templates
```

| # | Etapa | Ferramenta | Imagem (VERIFICADA) | Para que serve |
|---|---|---|---|---|
| 1 | Subdomínios | subfinder | `projectdiscovery/subfinder:latest` ✅ | enumeração passiva (fontes públicas) |
| 2 | DNS | dnsx | `projectdiscovery/dnsx:latest` ✅ | resolver, validar, filtrar morto |
| 3 | Vivos | httpx | `projectdiscovery/httpx:latest` ✅ | status, título, tecnologia |
| 4 | Crawl | katana | `projectdiscovery/katana:latest` ✅ | achar endpoints, JS, params |
| 5 | Histórico | gau | `sxcurity/gau:latest` ✅ | URLs antigas (Wayback/CommonCrawl) |
| 6 | Scan | nuclei | `projectdiscovery/nuclei:latest` ✅ | templates conhecidos |
| 7 | Portas | naabu | `projectdiscovery/naabu:latest` ✅ | portas abertas |
| 8 | TLS | tlsx | `projectdiscovery/tlsx:latest` ✅ | certificados → mais subdomínios |
| 9 | Fuzzing | ffuf | `secsi/ffuf:latest` ✅ | diretórios e parâmetros |
| 10 | XSS | dalfox | `hahwul/dalfox:latest` ✅ | XSS refletido/DOM |
| 11 | JWT | jwt_tool | `ticarpi/jwt_tool:latest` ✅ | falhas de JWT |
| 12 | DAST | Zap | `zaproxy/zap-stable:latest` ✅ | varredura dinâmica geral |

> ✅ = imagem verificada com `docker manifest inspect` nesta máquina.

**NÃO existem como imagem pública** (verificado — `denied`/`not found`):
`ffuf/ffuf` e `ghcr.io/ffuf/ffuf` · `projectdiscovery/interactsh` ·
`goffinet/sqlmap`.
Para esses, instale local (Go/Python) ou use outra fonte — ou trabalhe manual.
**Não inventei nome de imagem; só listo o que respondi como existente.**

> Go **não** está instalado nesta máquina, então tudo roda via **Docker** — mesmo
> padrão do `scan.ps1`. Nada é instalado no sistema.

## 2. Portões (param antes de qualquer pacote sair)

O motor é `recon.ps1` (em `ferramentas/recon/`, e publicado no global como
`recon-toolkit\recon.ps1`). Ele **para** se:

1. Faltar `-Autorizo` → confirma que o alvo é seu ou está **dentro do escopo** autorizado.
2. Faltar `-Alvo` (domínio/arquivo de escopo) → sem escopo explícito, não roda.
3. `docker info` não responder → para e pede o Docker Desktop.
4. `-Simular` → monta e mostra os comandos **sem executar**.
5. `-Etapas` inválida → para (não adivinha).

**Nunca** aponto recon para domínio que o usuário não declarou como autorizado.

## 3. Onde ficam os resultados

```
recon-out/<alvo>/<carimbo>/
├── 01-subs.txt        subdomínios
├── 02-dns.txt         resolvidos
├── 03-vivos.txt       hosts HTTP vivos
├── 04-urls.txt        URLs (katana + gau)
├── 05-nuclei.jsonl    achados de template
└── RELATORIO.md       resumo + o que ficou SEM cobertura
```

A pasta `recon-out/` **não** é versionada (resultado de alvo de terceiro).

## 4. Sub-modos do `\recon`

| Você digita | O que eu faço |
|---|---|
| `\recon subs <domínio>` | Só subfinder (+dnsx) |
| `\recon vivos <domínio>` | subs → dnsx → httpx |
| `\recon urls <domínio>` | vivos → katana + gau |
| `\recon scan <domínio>` | pipeline completo até nuclei |
| `\recon porta <host>` | naabu (portas) |
| `\recon cert <domínio>` | tlsx (certificados → subs novos) |
| `\recon oob` | subir um interactsh para provar blind bugs |
| `\recon fuzz <url>` | ffuf (dirs/params) — **cuidado com volume** |
| `\recon relatorio` | consolidar `recon-out/` num resumo |

## 5. Disciplina de bounty (o que paga)

1. **Ler a policy** do programa antes de tudo (escopo, se automação é permitida,
   rate limits, o que é considerado duplicado).
2. **Recon largo, teste estreito.** Achar o ativo esquecido é 80% do trabalho.
3. **Rate limit.** Volume alto = derrubar o alvo = ban. Sempre conservador.
4. **Especializar.** IDOR + authz + SSRF + race condition pagam; XSS refletido
   simples quase sempre é duplicado.
5. **Provar.** Sem PoC reproduzível, é "informative". Com PoC, é pago.
6. **Tripé do relatório:** impacto de negócio + passos mínimos + evidência.
7. Nunca enviar relatório gerado em massa por IA — queima a reputação.
