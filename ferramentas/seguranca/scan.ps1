#requires -Version 5.1
<#
.SYNOPSIS
  Scan de seguranca REAL do projeto — motor do comando \secops.

.DESCRIPTION
  Roda Semgrep e TruffleHog (e Nuclei, se voce informar um alvo autorizado) via
  Docker e salva os relatorios em security-reports/.

  REGRAS DE SEGURANCA DESTE SCRIPT:
  - Checa "docker info" ANTES de tudo e para se o Docker estiver desligado.
  - Monta APENAS a pasta do projeto (-v "<alvo>:/src"), nunca C:\ nem a home.
  - TruffleHog SEMPRE com --no-verification (nao envia segredo a terceiros).
  - Nuclei SO roda se -NucleiUrl for informado (alvo seu e autorizado).
  - Nao imprime valor de segredo: o bruto fica em arquivo local e o resumo usa
    apenas localizacao (arquivo/linha) e o campo REDIGIDO quando existir.

.PARAMETER Alvo
  Raiz do projeto a auditar. Padrao: diretorio atual.

.PARAMETER Relatorios
  Pasta de saida dos relatorios. Padrao: <Alvo>\security-reports

.PARAMETER NucleiUrl
  URL de teste AUTORIZADA. Sem ela o Nuclei nao roda.

.PARAMETER PularSemgrep
  Nao rodar o Semgrep.

.PARAMETER PularTrufflehog
  Nao rodar o TruffleHog.

.PARAMETER PularGit
  Nao varrer o historico git (apenas o file system).

.EXAMPLE
  .\scan.ps1

.EXAMPLE
  .\scan.ps1 -Alvo C:\dev\meu-projeto -PularGit

.EXAMPLE
  .\scan.ps1 -NucleiUrl https://staging.meusite.com
#>
[CmdletBinding()]
param(
    [string]$Alvo,
    [string]$Relatorios,
    [string]$NucleiUrl,
    [switch]$PularSemgrep,
    [switch]$PularTrufflehog,
    [switch]$PularGit
)

$ErrorActionPreference = 'Continue'

$IMG_SEMGREP = 'semgrep/semgrep:latest'
$IMG_TRUFFLE = 'trufflesecurity/trufflehog:latest'
$IMG_NUCLEI  = 'projectdiscovery/nuclei:latest'

# ------------------------------------------------------------------ alvo
if (-not $Alvo) { $Alvo = (Get-Location).Path }
$Alvo = (Resolve-Path -LiteralPath $Alvo -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $Alvo -PathType Container)) { throw "Alvo nao e uma pasta: $Alvo" }

# o caminho entra numa linha de comando do cmd: recusar metacaracteres
if ($Alvo -match '[&%^!]') {
    throw ("O caminho do alvo contem caractere que quebra o cmd (& % ^ !): " + $Alvo + "`nMova o projeto para um caminho simples.")
}
$AlvoMount = $Alvo.TrimEnd('\')

if (-not $Relatorios) { $Relatorios = Join-Path $Alvo 'security-reports' }
if (-not (Test-Path -LiteralPath $Relatorios)) { New-Item -ItemType Directory -Force -Path $Relatorios | Out-Null }
$Relatorios = (Resolve-Path -LiteralPath $Relatorios).Path

$carimbo = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$utf8    = New-Object System.Text.UTF8Encoding($false)

function Dizer([string]$Texto) {
    Write-Host $Texto
    $script:linhas.Add($Texto) | Out-Null
}

# ------------------------------------------------------------------ docker
function Testar-Docker {
    $tmp = Join-Path $env:TEMP ('rosa-docker-' + [guid]::NewGuid().ToString('N') + '.txt')
    cmd /c ('docker info > "' + $tmp + '" 2>&1') | Out-Null
    $codigo = $LASTEXITCODE
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    return ($codigo -eq 0)
}

function Invocar-Docker {
    param(
        [Parameter(Mandatory)][string]$Argumentos,
        [Parameter(Mandatory)][string]$Saida
    )
    $erro  = $Saida + '.erro.txt'
    $linha = 'docker ' + $Argumentos + ' > "' + $Saida + '" 2> "' + $erro + '"'
    cmd /c $linha | Out-Null
    return [int]$LASTEXITCODE
}

function Contar-LinhasJson([string]$Caminho) {
    if (-not (Test-Path -LiteralPath $Caminho)) { return 0 }
    $n = 0
    foreach ($l in (Get-Content -LiteralPath $Caminho -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        try { $null = $l | ConvertFrom-Json; $n++ } catch { }
    }
    return $n
}

# ================================================================== inicio
$linhas = New-Object System.Collections.Generic.List[string]

Write-Host ''
Write-Host 'Rosa - scan de seguranca (motor do \secops)' -ForegroundColor Cyan
Write-Host ("Alvo       : {0}" -f $Alvo)
Write-Host ("Relatorios : {0}" -f $Relatorios)
Write-Host ''

if (-not (Testar-Docker)) {
    Write-Host '[PARADO] O Docker nao respondeu (docker info falhou).' -ForegroundColor Red
    Write-Host '         Abra o Docker Desktop e rode de novo. NADA foi executado.' -ForegroundColor Red
    $caminhoParado = Join-Path $Relatorios ("{0}-RELATORIO.md" -f $carimbo)
    $textoParado = @(
        '# Relatorio de seguranca',
        '',
        ("- Alvo: " + $Alvo),
        ("- Data: " + (Get-Date -Format 'yyyy-MM-dd HH:mm')),
        '',
        '## NAO EXECUTADO',
        '',
        '- Docker indisponivel (docker info falhou).',
        '- Sem cobertura: Semgrep, TruffleHog, Nuclei, Strix.',
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($caminhoParado, $textoParado, $utf8)
    Write-Host ("Relatorio do nao-executado: " + $caminhoParado)
    exit 2
}
Write-Host '[ok] Docker respondeu.' -ForegroundColor Green
Write-Host ''

$executadas   = New-Object System.Collections.Generic.List[string]
$semCobertura = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------------------------ Semgrep
$nSemgrep = -1
if ($PularSemgrep) {
    $semCobertura.Add('Semgrep (pulado por -PularSemgrep)') | Out-Null
    Write-Host '[--] Semgrep: pulado.'
} else {
    $saidaSg = Join-Path $Relatorios ("{0}-semgrep.json" -f $carimbo)
    Write-Host '[..] Semgrep rodando (pode demorar na 1a vez)...' -ForegroundColor Yellow
    $argSg = 'run --rm -v "' + $AlvoMount + ':/src:ro" -w /src ' + $IMG_SEMGREP +
             ' semgrep scan --config p/default --metrics off --json'
    $codSg = Invocar-Docker -Argumentos $argSg -Saida $saidaSg
    if ($codSg -eq 0) {
        try   { $nSemgrep = @((Get-Content -LiteralPath $saidaSg -Raw -Encoding UTF8 | ConvertFrom-Json).results).Count }
        catch { $nSemgrep = -1 }
        Write-Host ("[ok] Semgrep: {0} achado(s)" -f $nSemgrep) -ForegroundColor Green
        $executadas.Add(("Semgrep | exit 0 | achados: {0} | {1}" -f $nSemgrep, (Split-Path $saidaSg -Leaf))) | Out-Null
    } else {
        Write-Host ("[!!] Semgrep FALHOU (exit {0}) - veja {1}.erro.txt" -f $codSg, (Split-Path $saidaSg -Leaf)) -ForegroundColor Red
        $executadas.Add(("Semgrep | exit {0} | FALHOU" -f $codSg)) | Out-Null
        $semCobertura.Add(("Semgrep (falhou, exit {0})" -f $codSg)) | Out-Null
    }
}

# --------------------------------------------------------------- TruffleHog
$nTruffleFs  = -1
$nTruffleGit = -1
if ($PularTrufflehog) {
    $semCobertura.Add('TruffleHog (pulado por -PularTrufflehog)') | Out-Null
    Write-Host '[--] TruffleHog: pulado.'
} else {
    # 1) arquivos
    $saidaTf = Join-Path $Relatorios ("{0}-trufflehog-arquivos.jsonl" -f $carimbo)
    Write-Host '[..] TruffleHog nos arquivos...' -ForegroundColor Yellow
    $argTf = 'run --rm -v "' + $AlvoMount + ':/src:ro" ' + $IMG_TRUFFLE +
             ' filesystem /src --no-verification --json'
    $codTf = Invocar-Docker -Argumentos $argTf -Saida $saidaTf
    if ($codTf -eq 0) {
        $nTruffleFs = Contar-LinhasJson $saidaTf
        Write-Host ("[ok] TruffleHog (arquivos): {0} achado(s)" -f $nTruffleFs) -ForegroundColor Green
        $executadas.Add(("TruffleHog arquivos | exit 0 | achados: {0} | {1}" -f $nTruffleFs, (Split-Path $saidaTf -Leaf))) | Out-Null
    } else {
        Write-Host ("[!!] TruffleHog (arquivos) FALHOU (exit {0})" -f $codTf) -ForegroundColor Red
        $executadas.Add(("TruffleHog arquivos | exit {0} | FALHOU" -f $codTf)) | Out-Null
        $semCobertura.Add(("TruffleHog arquivos (falhou, exit {0})" -f $codTf)) | Out-Null
    }

    # 2) historico git
    $temGit = Test-Path -LiteralPath (Join-Path $Alvo '.git')
    if ($PularGit) {
        $semCobertura.Add('TruffleHog no historico git (pulado por -PularGit)') | Out-Null
        Write-Host '[--] TruffleHog (historico git): pulado.'
    } elseif (-not $temGit) {
        $semCobertura.Add('Historico git (o projeto nao e um repositorio git)') | Out-Null
        Write-Host '[--] TruffleHog (historico git): sem .git, nada a varrer.'
    } else {
        $saidaTg = Join-Path $Relatorios ("{0}-trufflehog-git.jsonl" -f $carimbo)
        Write-Host '[..] TruffleHog no historico git...' -ForegroundColor Yellow
        $argTg = 'run --rm -v "' + $AlvoMount + ':/src:ro" ' + $IMG_TRUFFLE +
                 ' git file:///src --no-verification --json'
        $codTg = Invocar-Docker -Argumentos $argTg -Saida $saidaTg
        if ($codTg -eq 0) {
            $nTruffleGit = Contar-LinhasJson $saidaTg
            Write-Host ("[ok] TruffleHog (historico git): {0} achado(s)" -f $nTruffleGit) -ForegroundColor Green
            $executadas.Add(("TruffleHog git | exit 0 | achados: {0} | {1}" -f $nTruffleGit, (Split-Path $saidaTg -Leaf))) | Out-Null
        } else {
            Write-Host ("[!!] TruffleHog (git) FALHOU (exit {0})" -f $codTg) -ForegroundColor Red
            $executadas.Add(("TruffleHog git | exit {0} | FALHOU" -f $codTg)) | Out-Null
            $semCobertura.Add(("TruffleHog historico git (falhou, exit {0})" -f $codTg)) | Out-Null
        }
    }
}

# -------------------------------------------------------------------- Nuclei
$nNuclei = -1
if ($NucleiUrl) {
    if ($NucleiUrl -notmatch '^https?://') {
        $semCobertura.Add('Nuclei (URL invalida: precisa comecar com http:// ou https://)') | Out-Null
        Write-Host '[!!] Nuclei: URL invalida, nao rodei.' -ForegroundColor Red
    } else {
        $saidaNu = Join-Path $Relatorios ("{0}-nuclei.jsonl" -f $carimbo)
        Write-Host ("[..] Nuclei em {0} (somente alvo autorizado)..." -f $NucleiUrl) -ForegroundColor Yellow
        $argNu = 'run --rm ' + $IMG_NUCLEI + ' -u ' + $NucleiUrl + ' -severity high,critical -jsonl -silent'
        $codNu = Invocar-Docker -Argumentos $argNu -Saida $saidaNu
        if ($codNu -eq 0) {
            $nNuclei = Contar-LinhasJson $saidaNu
            Write-Host ("[ok] Nuclei: {0} achado(s)" -f $nNuclei) -ForegroundColor Green
            $executadas.Add(("Nuclei | exit 0 | achados: {0} | {1}" -f $nNuclei, (Split-Path $saidaNu -Leaf))) | Out-Null
        } else {
            Write-Host ("[!!] Nuclei FALHOU (exit {0}) - se for falta de templates, rode -update-templates" -f $codNu) -ForegroundColor Red
            $executadas.Add(("Nuclei | exit {0} | FALHOU" -f $codNu)) | Out-Null
            $semCobertura.Add(("Nuclei (falhou, exit {0})" -f $codNu)) | Out-Null
        }
    }
} else {
    $semCobertura.Add('Nuclei (nenhum -NucleiUrl informado; so roda em alvo autorizado)') | Out-Null
    Write-Host '[--] Nuclei: sem -NucleiUrl, nao rodei (so roda em alvo autorizado).'
}

# ================================================================= relatorio
$tSg = if ($nSemgrep   -ge 0) { "$nSemgrep achado(s)" }   else { 'nao executado / sem resultado' }
$tTf = if ($nTruffleFs -ge 0) { "$nTruffleFs achado(s)" } else { 'nao executado / sem resultado' }
$tTg = if ($nTruffleGit -ge 0) { "$nTruffleGit achado(s)" } else { 'nao executado / sem resultado' }
$tNu = if ($nNuclei    -ge 0) { "$nNuclei achado(s)" }    else { 'nao executado (precisa de -NucleiUrl autorizado)' }

$relatorio = Join-Path $Relatorios ("{0}-RELATORIO.md" -f $carimbo)
$r = New-Object System.Collections.Generic.List[string]
$r.Add('# Relatorio de seguranca') | Out-Null
$r.Add('') | Out-Null
$r.Add('- Projeto (alvo): ' + $Alvo) | Out-Null
$r.Add('- Data: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')) | Out-Null
$r.Add('- Ferramentas: Semgrep, TruffleHog (arquivos + historico git), Nuclei (opcional)') | Out-Null
$r.Add('- Gerado por: ferramentas/seguranca/scan.ps1 (projeto Rosa - Comandos de Papel)') | Out-Null
$r.Add('') | Out-Null
$r.Add('## Ferramentas: o que executou e o que falhou') | Out-Null
$r.Add('') | Out-Null
if ($executadas.Count -eq 0) { $r.Add('- Nada foi executado.') | Out-Null }
foreach ($e in $executadas) { $r.Add('- ' + $e) | Out-Null }
$r.Add('') | Out-Null
$r.Add('## Sem cobertura (importante)') | Out-Null
$r.Add('') | Out-Null
if ($semCobertura.Count -eq 0) { $r.Add('- Nada ficou de fora dentro do fluxo previsto.') | Out-Null }
foreach ($s in $semCobertura) { $r.Add('- ' + $s) | Out-Null }
$r.Add('') | Out-Null
$r.Add('## Achados (contagem bruta, SEM triagem)') | Out-Null
$r.Add('') | Out-Null
$r.Add('- Semgrep: ' + $tSg) | Out-Null
$r.Add('- TruffleHog arquivos: ' + $tTf) | Out-Null
$r.Add('- TruffleHog historico git: ' + $tTg) | Out-Null
$r.Add('- Nuclei: ' + $tNu) | Out-Null
$r.Add('') | Out-Null
$r.Add('## Triagem — OBRIGATORIA antes de chamar algo de vulnerabilidade') | Out-Null
$r.Add('') | Out-Null
$r.Add('Um achado de scanner NAO e, por si so, uma vulnerabilidade: abra o JSON, leia o') | Out-Null
$r.Add('trecho e confira o contexto. Para CVE, confirme produto, versao afetada,') | Out-Null
$r.Add('pre-condicoes e o advisory original. Nao extrapole a partir do titulo.') | Out-Null
$r.Add('') | Out-Null
$r.Add('## Valores de segredo') | Out-Null
$r.Add('') | Out-Null
$r.Add('Os valores NAO foram copiados para este resumo de proposito. Se houver achado de') | Out-Null
$r.Add('segredo, trate como credencial comprometida: rotacione a chave e remova do git.') | Out-Null
$r.Add('O bruto (que PODE conter o valor) esta nos arquivos *-trufflehog-*.jsonl desta pasta.') | Out-Null
$r.Add('Esta pasta security-reports/ NAO deve ser versionada.') | Out-Null
$r.Add('') | Out-Null
[System.IO.File]::WriteAllText($relatorio, ($r -join "`r`n"), $utf8)

Write-Host ''
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host ' RESUMO' -ForegroundColor Cyan
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host (' Semgrep ................: ' + $tSg)
Write-Host (' TruffleHog arquivos ....: ' + $tTf)
Write-Host (' TruffleHog git .........: ' + $tTg)
Write-Host (' Nuclei .................: ' + $tNu)
Write-Host ''
Write-Host ' Sem cobertura:' -ForegroundColor Yellow
if ($semCobertura.Count -eq 0) {
    Write-Host '   - nada'
} else {
    foreach ($s in $semCobertura) { Write-Host ('   - ' + $s) }
}
Write-Host ''
Write-Host (' Relatorio: ' + $relatorio) -ForegroundColor Green
Write-Host ''
Write-Host ' LEMBRETE: contagem != vulnerabilidade. Triar antes de classificar.' -ForegroundColor Yellow
Write-Host ''
