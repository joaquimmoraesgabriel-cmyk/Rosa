<!-- GERADO AUTOMATICAMENTE por gerar.ps1 - NAO EDITE ESTE ARQUIVO. -->
<!-- Projeto: Rosa - Comandos de Papel | Fonte: catalogo/*.md -->
<!-- Adapter: cline-global | Instalar em: Documents\Cline\Rules\ -->
<!-- Gerado em: 2026-09-15 14:25 -->
# 50 — `\ajuda` — Manual completo dos comandos

**Missão:** quando o usuário digitar `\ajuda`, entregar a **lista completa e
detalhada** de todos os comandos: o que cada um faz, em qual modo roda, o que
**não** faz e um exemplo de uso.

**Variações aceitas**

| Você digita        | O agente responde                          |
|--------------------|--------------------------------------------|
| `\ajuda`           | Manual completo (todos os comandos)        |
| `\ajuda \secops`   | Só o comando pedido, em detalhe            |
| `\ajuda instalar`  | Como instalar na ferramenta atual          |
| `\ajuda progresso` | Como funciona o bloco de progresso         |
| `\ajuda mapa`      | Como funciona o `.ai_history.md`           |
| `\ajuda geral`     | Como funciona o controle de aprovação      |

**Modo:** ACT, mas **somente leitura** — o `\ajuda` nunca altera arquivos do projeto.
**Nunca:** inventar comando que não existe. Se o usuário pedir um comando
inexistente, dizer que não existe e mostrar os mais parecidos.

---

## Conteúdo obrigatório da resposta ao `\ajuda`

### 1. Visão geral

> São **13 comandos**: 4 em **PLAN** (planejam, não tocam no código) e 9 em
> **ACT** (executam). Todo comando aceita texto livre depois dele:
> `\comando <o que eu quero>`. Comando sozinho = o agente pergunta o objetivo.

### 2. Tabela-resumo

| Comando   | Papel                    | Modo | Coda? | Em uma frase |
|-----------|--------------------------|------|-------|--------------|
| `\pm`     | Product Manager          | PLAN | não   | Visão do produto, priorização por mercado, ponte dev↔negócio |
| `\ux`     | UX / Pesquisa            | PLAN | não   | Pesquisa com usuários, fluxos e o desenho da interface |
| `\tech`   | Arquiteto / Tech Lead    | PLAN | não   | Arquitetura, ADRs, trade-offs e plano de implementação |
| `\scrum`  | Scrum Master             | PLAN | não   | Histórias, backlog, cerimônias, impedimentos e métricas |
| `\front`  | Frontend Engineer        | ACT  | sim   | Só a parte visual: telas, componentes, acessibilidade |
| `\back`   | Backend Engineer         | ACT  | sim   | Só a lógica invisível: APIs, banco, auth, pagamentos |
| `\devops` | DevOps / SRE             | ACT  | sim   | Docker, CI/CD, nuvem, escala e monitoramento |
| `\data`   | Data Engineer            | ACT  | sim   | Modelagem, índices, pipelines e performance de banco |
| `\secops` | SecOps / Privacidade     | ACT  | sim   | Segurança, LGPD/GDPR e relatórios em `security-reports/` |
| `\qa`     | QA                       | ACT  | sim   | Testes automatizados e manuais + relatório de bug |
| `\geral`  | Roteador                 | ACT  | conforme | O agente escolhe os papéis e pede aprovação a cada etapa |
| `\map`    | Cartógrafo               | ACT  | docs  | Cria/atualiza `.ai_history.md` (o projeto não vira caixa preta) |
| `\ajuda`  | Manual                   | ACT  | docs  | Esta lista |

### 3. Ficha detalhada de cada comando

Para **cada** comando, imprimir exatamente estes campos:

```
### \comando — Papel (MODO)
- FAZ:        <3 a 6 entregáveis principais>
- NÃO FAZ:    <o que pertence a outro papel>
- ENTREGA:    <artefato concreto: código / documento / relatório>
- EXEMPLO:    \comando <frase de uso real>
- DICA:       <quando usar em vez de outro comando>
```

Referência de conteúdo: `10-planejamento.md` (PLAN), `20-execucao.md` (ACT),
`30-geral-e-map.md` (`\geral` e `\map`), `40-limites.md` (limites reais),
`60-seguranca.md` (procedimento do `\secops`).

### 4.b. Sub-modos do `\secops` (vale no manual do comando)

| Você digita | O que acontece |
|---|---|
| `\secops scan` | Semgrep + TruffleHog no projeto + relatório em `security-reports/` |
| `\secops segredos` | Só TruffleHog (arquivos + histórico git) |
| `\secops codigo` | Só Semgrep |
| `\secops web <url>` | Nuclei — **só** em alvo seu/autorizado |
| `\secops lgpd` | Revisão de LGPD/GDPR (mapa de requisitos) |
| `\secops threat` | Threat modeling (STRIDE) |
| `\secops incidente` | Runbook de incidente |
| `\secops relatorio` | Consolidar `security-reports/` num resumo |

### 4. Como decidir qual usar (regra de bolso)

- Ideia/estratégia/preço → `\pm`
- Tela/fluxo/experiência → `\ux`
- Arquitetura/decisão técnica → `\tech`
- Organizar o time/tarefas → `\scrum`
- Construir a tela → `\front` · a lógica → `\back`
- Colocar no ar → `\devops` · organizar dados → `\data`
- Proteger/conformidade → `\secops` · testar → `\qa`
- **Não sei qual usar** → `\geral` (o agente escolhe por você)

### 5. Regras globais que valem em TODOS os comandos

1. **Progresso em árvore** no início de toda resposta (`[x] [~] [ ] [!]`).
2. **Escopo estrito** — cada papel só faz o seu.
3. **`.ai_history.md`** — toda mudança real é registrada (`\map`).
4. **Modo** — comandos PLAN nunca editam arquivos, mesmo em Act.
5. **Limites honestos** — o que o agente não consegue é dito, não simulado.
