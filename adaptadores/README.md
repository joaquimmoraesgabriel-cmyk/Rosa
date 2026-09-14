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
| `cursor` | `cursor/.cursor/rules/rosa-comandos.mdc` | `<projeto>/.cursor/rules/` |
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
- Formato **MDC** (`*.mdc`) dentro de `.cursor/rules/`, com *front-matter* YAML.
- `alwaysApply: true` garante que as regras valem sempre; use `globs:` para
  restringir a certos caminhos.

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
