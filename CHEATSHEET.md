# 🗂️ CHEATSHEET — Comandos de Papel (Rosa)

Referência de **1 página**. Manual completo dentro da IA: digite `\ajuda`.

## Os 13 comandos

| Comando   | Papel                 | Modo | O que faz em 1 linha |
|-----------|-----------------------|------|----------------------|
| `\pm`     | Product Manager       | PLAN | Visão, priorização por mercado, ponte dev↔negócio |
| `\ux`     | UX / Pesquisa         | PLAN | Pesquisa com usuários, fluxos, desenho da interface |
| `\tech`   | Arquiteto / Tech Lead | PLAN | Arquitetura, ADRs, trade-offs, plano (não coda) |
| `\scrum`  | Scrum Master          | PLAN | Histórias, backlog, cerimônias, impedimentos |
| `\front`  | Frontend              | ACT  | Só a parte visual: telas, componentes, a11y |
| `\back`   | Backend               | ACT  | Só a lógica: APIs, banco, auth, pagamentos |
| `\devops` | DevOps / SRE          | ACT  | Docker, CI/CD, nuvem, escala, monitoramento |
| `\data`   | Data Engineer         | ACT  | Modelagem, índices, pipelines, performance |
| `\secops` | SecOps / Privacidade  | ACT  | Segurança, LGPD/GDPR, `security-reports/` |
| `\qa`     | QA                    | ACT  | Testes automatizados e manuais, relatório de bug |
| `\geral`  | Roteador              | ACT  | **A IA escolhe os papéis** e pede OK a cada etapa |
| `\map`    | Cartógrafo            | ACT  | Cria/atualiza `.ai_history.md` |
| `\ajuda`  | Manual                | ACT  | Lista completa de tudo |

**PLAN** = planeja e nunca edita arquivo. **ACT** = executa de verdade.

## Sintaxe

```text
\comando <o que você quer>     ex.: \secops auditar as dependências
\comando                       ex.: \pm      -> a IA pergunta o objetivo
```

## Regras que valem em TODOS os comandos

1. 📊 **Progresso em árvore** no início de toda resposta (`[x] [~] [ ] [!]`).
2. 🚧 **Escopo estrito** — cada papel só faz o seu.
3. 📜 **`.ai_history.md`** — toda mudança real é registrada.
4. 🔒 **PLAN nunca edita** — mesmo se a ferramenta estiver em Act.
5. 🙅 **Limites honestos** — o que a IA não pode fazer, ela diz.

## Qual usar? (regra de bolso)

| Sua situação | Comando |
|---|---|
| Ideia, estratégia, preço | `\pm` |
| Tela, fluxo, experiência | `\ux` |
| Decisão técnica, arquitetura | `\tech` |
| Organizar time/tarefas | `\scrum` |
| Construir a tela | `\front` |
| Construir a lógica | `\back` |
| Colocar no ar | `\devops` |
| Dados e banco | `\data` |
| Proteger / LGPD | `\secops` |
| Testar | `\qa` |
| **Não sei** | `\geral` |
| Documentar o que foi feito | `\map` |
| Ver esta lista dentro da IA | `\ajuda` |

## Instalar (Cline, vale em todos os projetos)

```powershell
Copy-Item .\dist\cline-global\Rules\* "$env:USERPROFILE\Documents\Cline\Rules\" -Force
```

Outras IAs (Cursor, Claude Code, Copilot, Gemini, Windsurf, AGENTS.md):
veja [`adaptadores/README.md`](adaptadores/README.md).
