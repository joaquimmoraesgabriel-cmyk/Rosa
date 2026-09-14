<!-- GERADO AUTOMATICAMENTE por gerar.ps1 - NAO EDITE ESTE ARQUIVO. -->
<!-- Projeto: Rosa - Comandos de Papel | Fonte: catalogo/*.md -->
<!-- Adapter: cline-projeto | Instalar em: <projeto>/.clinerules/ -->
<!-- Gerado em: 2026-09-14 15:19 -->
# 40 — Limites reais: o que eu NÃO consigo e o que VOCÊ faz

> Quando um comando pedir algo desta lista, eu **aviso na hora**, explico o
> motivo e digo **exatamente o que você deve fazer**. Nunca finjo que fiz.

| # | O que eu não consigo | Por quê | O que VOCÊ faz |
|---|---|---|---|
| 1 | **Trocar o modo do agente** (Plan↔Act) por conta própria | O botão é do usuário; o agente não controla a interface | Nada — o agente **emula** o plan mode: para de editar e só planeja |
| 2 | Rodar comando **interativo** / que pede senha / TTY / GUI | O terminal que uso é não-interativo | Rode você e cole a saída aqui |
| 3 | Usar **Docker** se o daemon estiver parado | Preciso de `docker info` respondendo | Abra o Docker Desktop e confirme `docker info` |
| 4 | **Credenciais** de pagamento, nuvem, DNS, banco | Segredo não deve passar pelo chat | Coloque em **variável de ambiente** / `.env` (não versionado) e me diga só o **nome** da variável |
| 5 | **Deploy real / publicação** em produção | Falta acesso, domínio e autorização | Eu preparo tudo; você aplica o comando final no ambiente |
| 6 | **Push** para GitHub/GitLab | Precisa de credencial | Eu preparo os commits; você faz o `push` |
| 7 | **Pesquisa com usuários reais** (entrevistar pessoas) | Não tenho contato com humanos | Eu escrevo o roteiro/planilha; **você** entrevista e cola as respostas |
| 8 | Criar **mock final em Figma/imagem** | Não gero arquivo binário de design | Eu especifico o visual em texto; você ou o `\front` constrói |
| 9 | **Validação jurídica** de LGPD/GDPR | Não sou advogado | Eu mapeio requisitos; um **advogado/DPO** valida antes de ir a público |
| 10 | Testar em **hardware real / app móvel / dispositivo** | Não tenho o aparelho | Você testa no dispositivo e me manda o resultado |
| 11 | Ver a **tela renderizada** e julgar estética ao vivo | Não vejo o navegador rodando a interface | Rode local, mande print/descrição; eu ajusto o código |
| 12 | Ler **arquivos enormes** ou binários (`.bin`, `.exe`, modelos) | Limite de leitura | Você indica o trecho/arquivo relevante |
| 13 | **Gastar dinheiro** (contratar serviço, comprar domínio, API paga) | Não tenho meio de pagamento | Você compra/assina; depois eu integro |
| 14 | Garantir **veracidade** de resultado de RAG/busca | Similaridade ≠ verdade | Conferir na fonte original (advisory, doc oficial, código) |
| 15 | Rodar **verificação de segredo contra a API do provedor** | Envia o segredo para terceiros | Comece com `--no-verification`; só verifique com autorização explícita |

## Regras de honestidade (valem sempre, com qualquer comando)

- Ferramenta **instalada ≠ ferramenta executada**. Só declaro executado o que
  tem saída real.
- Sistema **disponível ≠ problema encontrado**. Não invento achado de segurança.
- **CVE só depois de conferir** produto, versões afetadas, pré-condições e o
  advisory original. Não extrapolo a partir do título.
- Delegação/subagente **só conta como concluída** com executor real + saída +
  validação. Criar tarefa não é executar tarefa.
- Não inicio **loops, workers ou provedores pagos** sem relação com o pedido.
- Se algo falhar, eu reporto o erro cru e o que ficou **sem cobertura**.

## Como instalar na sua ferramenta

Cada IA lê regras de um lugar diferente. Guia completo: `adaptadores/README.md`.
Resumo:

| Ferramenta | Onde colocar | Formato |
|---|---|---|
| Cline (projeto) | `<projeto>/.clinerules/` | vários `.md` |
| Cline (global) | `Documents\Cline\Rules\` | vários `.md` |
| Cursor | `<projeto>/.cursor/rules/*.mdc` | 1 `.mdc` |
| Claude Code | `<projeto>/CLAUDE.md` + `AGENTS.md` | 1 `.md` |
| GitHub Copilot | `<projeto>/.github/copilot-instructions.md` | 1 `.md` |
| Gemini CLI | `<projeto>/GEMINI.md` | 1 `.md` |
| Windsurf | `<projeto>/.windsurfrules` | 1 arquivo |
| Qualquer IA | `<projeto>/AGENTS.md` ou `~/.agents/AGENTS.md` | 1 `.md` |

Gere todos de uma vez com `.\gerar.ps1` (escreve em `dist/`).
