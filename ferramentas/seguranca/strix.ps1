#requires -Version 5.1
<#
.SYNOPSIS
  Wrapper do Strix (pentest autonomo com IA) para o comando \secops.

.DESCRIPTION
  O Strix e DIFERENTE das outras ferramentas do \secops:

  - e um AGENTE de IA -> precisa de LLM (variaveis STRIX_LLM e LLM_API_KEY);
  - GASTA DINHEIRO (tokens) -> tem teto com --max-budget;
  - monta a pasta do projeto no sandbox em modo ESCRAVEL e EDITA seus arquivos
    de verdade. A doc oficial diz, com estas palavras: "commit or stash first";
  - so pode rodar em alvo que VOCE possui ou tem autorizacao escrita para testar.

  Por isso este script EXIGE tres coisas antes de rodar qualquer coisa:
    1. -Autorizo        -> voce confirma que tem autorizacao para o alvo;
    2. -Alvo            -> o alvo (pasta local, URL, dominio, IP, spec de API);
    3. STRIX_LLM + LLM_API_KEY no ambiente -> a chave e SUA (nunca passa pelo chat).

  E, se o alvo for uma pasta local com alteracoes nao commitadas, exige
  -AceitarEdicao, porque o agente pode reescrever os seus arquivos.

.PARAMETER Alvo
  O que testar: pasta local, URL, dominio, IP ou spec OpenAPI/Postman.

.PARAMETER Modo
  quick | standard | deep. Padrao: quick (mais barato).

.PARAMETER MaxBudget
  Teto de gasto em dolares. Padrao: 5.

.PARAMETER MaxTurns
  Teto de turnos por agente. Opcional.

.PARAMETER Instrucao
  Foco do teste (ex.: "Focar em IDOR e bypass de autenticacao").

.PARAMETER Autorizo
  Obrigatorio. Confirma que voce tem autorizacao para testar o alvo.

.PARAMETER AceitarEdicao
  Obrigatorio quando o alvo local tem alteracoes nao commitadas ou nao e git.

.EXAMPLE
  $env:STRIX_LLM='openrouter/z-ai/glm-5.3'; $env:LLM_API_KEY='...'
  .\strix.ps1 -Alvo .\meu-projeto -Autorizo -Modo quick -MaxBudget 3
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Alvo,
    [ValidateSet('quick','standard','deep')][string]$Modo = 'quick',
    [ValidateRange(0.01, 10000)][double]$MaxBudget = 5,
    [int]$MaxTurns = 0,
    [string]$Instrucao,
    [switch]$Autorizo,
    [switch]$AceitarEdicao,
    [switch]$Simular
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ------------------------------------------------- 1) autorizacao explicita
if (-not $Autorizo) {
    Write-Host ''
    Write-Host '[PARADO] Falta -Autorizo.' -ForegroundColor Red
    Write-Host '         O Strix testa ATACANDO o alvo de verdade. So rode em sistema' -ForegroundColor Red
    Write-Host '         que voce possui ou tem autorizacao ESCRITA para testar.' -ForegroundColor Red
    Write-Host '         Teste sem autorizacao e ilegal na maioria das jurisdicoes.' -ForegroundColor Red
    Write-Host ''
    Write-Host '         Se voce tem autorizacao, repita com -Autorizo.' -ForegroundColor Yellow
    exit 3
}

# ------------------------------------------------- 2) LLM configurado
$faltando = @()
if (-not $env:STRIX_LLM)   { $faltando += 'STRIX_LLM' }
if (-not $env:LLM_API_KEY) { $faltando += 'LLM_API_KEY' }
if ($faltando.Count -gt 0) {
    Write-Host ''
    Write-Host ('[PARADO] Falta configurar o LLM: ' + ($faltando -join ', ')) -ForegroundColor Red
    Write-Host '         O Strix e um agente de IA: sem modelo ele nao roda.' -ForegroundColor Red
    Write-Host ''
    Write-Host '         O QUE VOCE FAZ (a chave nao passa pelo chat):' -ForegroundColor Yellow
    Write-Host "           `$env:STRIX_LLM  = 'openrouter/z-ai/glm-5.3'   # ou outro provedor" -ForegroundColor Yellow
    Write-Host "           `$env:LLM_API_KEY = 'sua-chave'                # sua, local" -ForegroundColor Yellow
    Write-Host '         Alternativa gerenciada: strix cloud login (sem chave local)' -ForegroundColor Yellow
    Write-Host ''
    exit 4
}

# ------------------------------------------------- 3) binario e docker
$strixCmd = Get-Command strix -ErrorAction SilentlyContinue
if (-not $strixCmd) {
    Write-Host '[PARADO] O comando "strix" nao esta no PATH.' -ForegroundColor Red
    Write-Host '         Instale: curl -sSL https://strix.ai/install | bash' -ForegroundColor Yellow
    Write-Host '         No Windows o instalador coloca em %USERPROFILE%\.strix\bin' -ForegroundColor Yellow
    exit 5
}
Write-Host ('[ok] strix em: ' + $strixCmd.Source) -ForegroundColor Green

$tmpDocker = Join-Path $env:TEMP ('rosa-strix-docker-' + [guid]::NewGuid().ToString('N') + '.txt')
cmd /c ('docker info > "' + $tmpDocker + '" 2>&1') | Out-Null
$dockerOk = ($LASTEXITCODE -eq 0)
if (Test-Path -LiteralPath $tmpDocker) { Remove-Item -LiteralPath $tmpDocker -Force }
if (-not $dockerOk) {
    Write-Host '[PARADO] O Docker nao respondeu (o Strix roda o alvo num sandbox Docker).' -ForegroundColor Red
    Write-Host '         Abra o Docker Desktop e rode de novo.' -ForegroundColor Red
    exit 6
}
Write-Host '[ok] Docker respondeu (sandbox do Strix).' -ForegroundColor Green

# ------------------------------------------------- 4) alvo local protegido
$alvoEhPasta = Test-Path -LiteralPath $Alvo -PathType Container
if ($alvoEhPasta) {
    $alvoFinal = (Resolve-Path -LiteralPath $Alvo).Path
    $ehGit = Test-Path -LiteralPath (Join-Path $alvoFinal '.git')
    $sujo = $false
    if ($ehGit) {
        $porcelain = ''
        try { $porcelain = (& git -C $alvoFinal status --porcelain 2>$null | Out-String) } catch { }
        if ($porcelain -and $porcelain.Trim().Length -gt 0) { $sujo = $true }
    }
    if ($sujo) {
        Write-Host ''
        Write-Host '[ATENCAO] O alvo e pasta local com alteracoes NAO COMMITADAS.' -ForegroundColor Red
        Write-Host '          O Strix monta a pasta no sandbox em modo ESCRAVEL e o agente' -ForegroundColor Red
        Write-Host '          EDITA os seus arquivos de verdade. Sem commit, nao ha como voltar.' -ForegroundColor Red
        if (-not $AceitarEdicao) {
            Write-Host ''
            Write-Host '          Faca commit/stash e rode de novo, ou repita com -AceitarEdicao.' -ForegroundColor Yellow
            exit 7
        }
        Write-Host '          -AceitarEdicao informado: seguindo sob sua responsabilidade.' -ForegroundColor Yellow
    } elseif (-not $ehGit) {
        Write-Host '[!!] O alvo NAO e um repositorio git: se o agente editar algo, nao ha volta.' -ForegroundColor Yellow
        if (-not $AceitarEdicao) {
            Write-Host '     Rode com -AceitarEdicao para confirmar que voce aceita esse risco.' -ForegroundColor Yellow
            exit 7
        }
    } else {
        Write-Host '[ok] Alvo local: repositorio git limpo.' -ForegroundColor Green
    }
} else {
    $alvoFinal = $Alvo
}

# ------------------------------------------------- 5) confirmacao de custo
Write-Host ''
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host ' STRIX - pentest autonomo com IA' -ForegroundColor Cyan
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host (' Alvo        : ' + $alvoFinal)
Write-Host (' Modo        : ' + $Modo)
Write-Host (' Teto de US$ : ' + $MaxBudget) -ForegroundColor Yellow
if ($MaxTurns -gt 0) { Write-Host (' Max turns   : ' + $MaxTurns) }
if ($Instrucao)      { Write-Host (' Instrucao   : ' + $Instrucao) }
Write-Host ''
Write-Host ' Isto GASTA DINHEIRO (tokens do seu LLM) e pode demorar bastante:' -ForegroundColor Yellow
Write-Host ' modo deep pode levar de 1 a 4 horas.' -ForegroundColor Yellow
Write-Host ''

# ------------------------------------------------- 6) preparar e rodar
$dirBase = if ($alvoEhPasta) { $alvoFinal } else { (Get-Location).Path }
$relatorios = Join-Path $dirBase 'security-reports'
if (-not (Test-Path -LiteralPath $relatorios)) { New-Item -ItemType Directory -Force -Path $relatorios | Out-Null }

$carimbo  = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$logSaida = Join-Path $relatorios ("{0}-strix.log" -f $carimbo)
$logErro  = Join-Path $relatorios ("{0}-strix.log.erro.txt" -f $carimbo)

$argumentos = @('-n', '-t', $alvoFinal, '-m', $Modo,
                '--max-budget', $MaxBudget.ToString([System.Globalization.CultureInfo]::InvariantCulture))
if ($MaxTurns -gt 0) { $argumentos += @('--max-turns', $MaxTurns) }
if ($Instrucao)      { $argumentos += @('--instruction', $Instrucao) }

Write-Host ('[..] Rodando: strix ' + ($argumentos -join ' ')) -ForegroundColor Yellow
Write-Host '     Nao interrompa: o log esta sendo gravado.' -ForegroundColor DarkGray
Write-Host ''

if ($Simular) {
    Write-Host '[SIMULACAO] Nada foi executado e NADA foi gasto.' -ForegroundColor Cyan
    Write-Host ('  O comando que rodaria seria: strix ' + ($argumentos -join ' ')) -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Portoes que passaram: autorizacao (-Autorizo), LLM (STRIX_LLM/LLM_API_KEY),' -ForegroundColor Green
    Write-Host 'binario strix, Docker e alvo local.' -ForegroundColor Green
    exit 0
}

$inicio = Get-Date
$proc = Start-Process -FilePath $strixCmd.Source -ArgumentList $argumentos -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $logSaida -RedirectStandardError $logErro
$codigo  = $proc.ExitCode
$duracao = (Get-Date) - $inicio

# ------------------------------------------------- 7) interpretar exit code
$textoExit = switch ($codigo) {
    0       { 'limpo (nenhuma vulnerabilidade)' }
    1       { 'ERRO FATAL' }
    2       { 'VULNERABILIDADES ENCONTRADAS' }
    default { 'inesperado' }
}
$cor = switch ($codigo) { 0 {'Green'} 2 {'Yellow'} default {'Red'} }
Write-Host ('[' + $codigo + '] Strix: ' + $textoExit) -ForegroundColor $cor

# ------------------------------------------------- 8) artefatos
$execucaoDir = Join-Path $dirBase 'strix_runs'
$artefatos = @()
if (Test-Path -LiteralPath $execucaoDir) {
    $ultimo = Get-ChildItem -LiteralPath $execucaoDir -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($ultimo) {
        $artefatos = @(Get-ChildItem -LiteralPath $ultimo.FullName -Recurse -File | Select-Object -ExpandProperty FullName)
        Write-Host ('[ok] Run: ' + $ultimo.FullName) -ForegroundColor Green
        foreach ($a in $artefatos) { Write-Host ('     - ' + (Split-Path $a -Leaf)) }
    }
}
if ($artefatos.Count -eq 0) {
    Write-Host '[--] Nenhum artefato em strix_runs/ (pode ter falhado antes de gravar).' -ForegroundColor Yellow
}

# ------------------------------------------------- 9) relatorio
$linhas = @(
    '# Relatorio Strix (pentest autonomo com IA)',
    '',
    ('- Alvo: ' + $alvoFinal),
    ('- Modo: ' + $Modo),
    ('- Teto de gasto: US$ ' + $MaxBudget),
    ('- Inicio: ' + $inicio.ToString('yyyy-MM-dd HH:mm:ss')),
    ('- Duracao: ' + [string]::Format('{0:hh\:mm\:ss}', $duracao)),
    ('- Exit code: ' + $codigo + ' (' + $textoExit + ')'),
    ('- Autorizacao: confirmada pelo usuario (-Autorizo)'),
    '',
    '## O que o Strix e (e o que ele NAO e)',
    '',
    'O Strix e um AGENTE de IA que ataca o alvo de verdade e valida com PoC.',
    'Ele GASTA tokens do seu LLM e monta a pasta do projeto em modo ESCREVIVEL',
    'no sandbox (a doc oficial manda commitar antes).',
    'Exit 2 significa "encontrou vulnerabilidade", NAO "confirmado por humano".',
    '',
    '## Artefatos'
)
if ($artefatos.Count -eq 0) { $linhas += '- Nenhum (run pode ter falhado antes de gravar)' }
foreach ($a in $artefatos) { $linhas += ('- ' + $a) }
$linhas += @(
    '',
    '## Triagem - OBRIGATORIA',
    '',
    'Abra vulnerabilities.json e findings.sarif, leia o PoC e confirme o contexto.',
    'Para qualquer CVE, confira produto, versao afetada, pre-condicoes e o advisory.',
    '',
    '## Logs',
    '',
    ('- Saida: ' + $logSaida),
    ('- Erro : ' + $logErro),
    ''
)

$caminhoRel = Join-Path $relatorios ("{0}-STRIX-RELATORIO.md" -f $carimbo)
[System.IO.File]::WriteAllText($caminhoRel, ($linhas -join "`r`n"), $utf8)

Write-Host ''
Write-Host (' Relatorio: ' + $caminhoRel) -ForegroundColor Green
Write-Host ''
if ($codigo -eq 2) {
    Write-Host ' ATENCAO: exit 2 = achou vulnerabilidade. TRIAR antes de classificar.' -ForegroundColor Yellow
}
exit $codigo

