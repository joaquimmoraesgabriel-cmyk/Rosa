# Adaptadores — instalar o Rosa na sua IA

O catálogo (`catalogo/*.md`) é **agnóstico de ferramenta**. Cada IA lê regras de
um lugar e num formato diferente. O `gerar.ps1` transforma o catálogo no formato
certo e escreve tudo em `dist/`.

```powershell
.\gerar.ps1                 # gera todos os adaptadores em dist/
.\gerar.ps1 -Ferramenta cursor
```

## Onde cada IA lê as regras (fontes oficiais)

| Adapter | Arquivo gerado em `dist/` | Instalar em |
|---|---|---|
| `cline-projeto` | `cline-projeto/.clinerules/*.md` | `<projeto>/.clinerules/` |
| `cline-global` | `cline-global/Rules/*.md` | `Documents\Cline\Rules\` (Windows) |
| `cursor` | `cursor/.cursor/rules/rosa/*.mdc` | `<projeto>/.cursor/rules/rosa/` |
| `cursor` (global) | `cursor/USER-RULES.txt` | colar em Cursor > Settings > Rules > User Rules |
| `claude-code` | `claude-code/CLAUDE.md` | `<projeto>/CLAUDE.md` |
| `copilot` | `copilot/.github/copilot-instructions.md` | `<projeto>/.github/` |
| `gemini` | `gemini/GEMINI.md` | `<projeto>/GEMINI.md` |
| `windsurf` | `windsurf/.windsurfrules` | `<projeto>/.windsurfrules` |
| `agents` | `agents/AGENTS.md` | `<projeto>/AGENTS.md` ou `~/.agents/AGENTS.md` |
| `unico` | `UNICO-completo.md` | colar em qualquer IA (chat, system prompt) |

## Detalhes por ferramenta

### Cline
- **Projeto:** todos os arquivos `.md`/`.txt` dentro de `.clinerules/` na raiz do
  projeto são combinados automaticamente em toda conversa daquele projeto.
- **Global:** o Cline usa `Documents\Cline\Rules` (Windows), `~/Documents/Cline/Rules`
  (macOS/Linux). Se não achar no Linux/WSL, tente `~/Cline/Rules`.
- O Cline também detecta automaticamente `.cursorrules`, `.windsurfrules` e
  `AGENTS.md` — por isso vale a pena gerar mais de um adapter.

### Cursor

Regras de projeto são arquivos **`.mdc`** em `.cursor/rules/` — e um arquivo
**`.md` ali é IGNORADO** (não tem front-matter). Por isso geramos `.mdc`.

O front-matter precisa ser a **linha 1** do arquivo. Os três campos:

| Campo | Papel |
|---|---|
| `alwaysApply: true` | Regra **sempre** incluída. É o que usamos: os comandos precisam estar sempre disponíveis |
| `description` | Texto que o Agente lê para decidir se puxa a regra (modo "Apply Intelligently") |
| `globs` | Anexa a regra só quando um arquivo do padrão está no contexto |

Geramos **6 regras** em `.cursor/rules/rosa/` (uma por assunto do catálogo),
todas com `alwaysApply: true`. Assim elas aparecem **separadas** no painel de
Rules do Cursor e você pode desligar uma que não usa (ex.: `50-ajuda`) para
economizar contexto — sem perder os outros comandos.

**Instalar no projeto:**

```powershell
Copy-Item .\dist\cursor\.cursor '<SEU-PROJETO>\.cursor' -Recurse -Force
```

**Instalar global (todos os projetos):** no Cursor isso se chama **User Rules**
— não é pasta, é uma caixa de texto no app.

1. `.\gerar.ps1 -Ferramenta cursor`
2. Abra `dist\cursor\USER-RULES.txt` e copie **tudo**
3. Cursor → Settings → **Customize → Rules → User Rules** → cole e salve

> O Cursor também lê `AGENTS.md` na raiz do projeto **e em subpastas** (o mais
> específico vence) — alternativa mais simples ao `.cursor/rules`.
> Precedência das regras: **Team > Project > User**.
> Regras não são importadas sozinhas de um repositório: isso exige um *plugin*
> com `.cursor-plugin/marketplace.json`.

### Claude Code
- Lê `CLAUDE.md` na raiz do projeto (e `AGENTS.md` em versões recentes).
- Sem *front-matter*: markdown puro.

### GitHub Copilot
- Lê `.github/copilot-instructions.md` no repositório.

### Gemini CLI
- Lê `GEMINI.md` na raiz do projeto.

### Windsurf
- Lê `.windsurfrules` (texto puro) na raiz do projeto.

### Padrão AGENTS.md (genérico)
- Formato aberto e **multi-ferramenta**: `AGENTS.md` no projeto ou
  `~/.agents/AGENTS.md` global. É a melhor aposta para "qualquer IA".

## Instalar em todos os projetos (Cline global)

```powershell
.\gerar.ps1 -Ferramenta cline-global
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Documents\Cline\Rules" | Out-Null
Copy-Item .\dist\cline-global\Rules\* "$env:USERPROFILE\Documents\Cline\Rules\" -Force
```

## Observação sobre tamanho

As regras são carregadas **em toda conversa**. O conjunto completo tem cerca de
25 KB (~7 mil tokens). Se o custo de contexto incomodar, use só `00-nucleo.md` +
`10`/`20`/`30`/`40` (o `50-ajuda.md` é o mais dispensável).
