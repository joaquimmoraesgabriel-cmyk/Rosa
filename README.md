# Rosa — Comandos de Papel

> Transforme **qualquer IA de código** num time de engenharia completo — com uma
> barra invertida.

```text
\pm  \ux  \tech  \scrum       -> planejam (não tocam no código)
\front \back \devops \data    -> executam
\secops \qa \geral \map \ajuda
```

---

## O problema

Todo dia a mesma ladainha em todo chat de IA:

> "aja como um engenheiro de segurança", "agora escreva só o frontend",
> "não mexa no backend", "me dê o plano antes", "documente o que você fez".

Prompt repetido é contexto jogado fora, resultado inconsistente e projeto que
vira caixa preta.

## A ideia

**Um comando = um papel.** Você digita `\secops auditar as dependências` e o
agente vira SecOps — e *só* SecOps. Digita `\tech revisar a arquitetura` e ele
virou arquiteto, que **não coda**, só decide e explica.

O conjunto dá ao agente:

| Regra global | O que resolve |
|---|---|
| **Modo por papel** | `\pm \ux \tech \scrum` rodam em **plano** (nunca editam arquivo) |
| **Progresso em árvore** | você vê em que etapa o agente está, sempre |
| **Escopo estrito** | `\front` não mexe no backend; `\qa` reporta, não conserta |
| **`.ai_history.md`** | o projeto deixa de ser caixa preta: tudo registrado |
| **`\geral` com aprovação** | o agente escolhe os papéis e **pede OK a cada etapa** |
| **Limites honestos** | o que a IA não consegue é dito, não simulado |

## Portátil para outras IAs (não só Cline)

O catálogo é **agnóstico de ferramenta**; o `gerar.ps1` traduz para o formato de cada uma:

| IA | Onde lê |
|---|---|
| Cline (projeto / global) | `.clinerules/` · `Documents\Cline\Rules\` |
| Cursor | `.cursor/rules/*.mdc` |
| Claude Code | `CLAUDE.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Gemini CLI | `GEMINI.md` |
| Windsurf | `.windsurfrules` |
| Qualquer IA | `AGENTS.md` / `~/.agents/AGENTS.md` |

## Instalação (Windows / PowerShell)

```powershell
.\gerar.ps1                       # gera todos os adaptadores em dist/

# Cline global (vale em TODOS os seus projetos):
Copy-Item .\dist\cline-global\Rules\* "$env:USERPROFILE\Documents\Cline\Rules\" -Force
```

Guia completo por ferramenta: [`adaptadores/README.md`](adaptadores/README.md)
Referência rápida: [`CHEATSHEET.md`](CHEATSHEET.md)

## Estrutura

```
rosa/
├── catalogo/                 <- FONTE DA VERDADE (agnostica de ferramenta)
│   ├── 00-nucleo.md          sintaxe, modos, progresso, aprovacao, escopo
│   ├── 10-planejamento.md    \pm \ux \tech \scrum
│   ├── 20-execucao.md        \front \back \devops \data \secops \qa
│   ├── 30-geral-e-map.md     \geral (com aprovacao) + \map
│   ├── 40-limites.md         o que a IA NAO consegue + o que VOCE faz
│   └── 50-ajuda.md           o comando \ajuda (manual completo)
├── adaptadores/README.md     onde cada IA le regras + como instalar
├── gerar.ps1                 gera o formato de cada IA em dist/
├── CHEATSHEET.md             referencia rapida (1 pagina)
└── dist/                     SAIDA GERADA (nao editar na mao)
```

Editou regra? Mexa **só** em `catalogo/` e rode `.\gerar.ps1` de novo.

## Uso

```text
\pm    definir a visão e priorizar o roadmap por mercado
\ux    pesquisar com usuários e desenhar a interface
\tech  ditar a arquitetura e resolver o problema difícil
\scrum quebrar isso em histórias e remover impedimentos
\front construir só a tela
\back  construir só a lógica, banco, auth e pagamentos
\devops docker, CI/CD, nuvem, monitoramento
\data  modelar, indexar e acelerar o banco
\secops segurança + LGPD/GDPR
\qa    testes automatizados e manuais
\geral decidir por mim qual papel usar e pedir aprovação a cada etapa
\map   atualizar o .ai_history.md
\ajuda o manual completo
```

Nada depois do comando? O agente pergunta o objetivo em vez de inventar.

## Status e roadmap

- [x] Catálogo com 13 comandos (PT-BR)
- [x] Gerador multi-ferramenta (`gerar.ps1`) validado
- [ ] Adaptador Cursor validado em uso real
- [ ] Versão `EN` do catálogo
- [ ] Comandos de papel extras: `\marketing`, `\legal`, `\suporte`
- [ ] Instalador `instalar.ps1` (copia para o destino certo de cada IA)
- [ ] Publicação no GitHub + página de instalação

> Este projeto **não é** o conjunto de regras instalado globalmente na sua
> máquina — aquele é uma *deploy* deste catálogo. Aqui fica a fonte.

## Licença

MIT — veja [`LICENSE`](LICENSE).
