#requires -Version 5.1
<#
.SYNOPSIS
  Recon de bug bounty — motor do comando \recon (pipeline subfinder -> dnsx -> httpx -> katana/gau -> nuclei).

.DESCRIPTION
  Roda o pipeline de reconhecimento via Docker. NAO instala nada no sistema.

  REGRAS DE SEGURANCA E LEGALIDADE DESTE SCRIPT:
  - EXIGE -Autorizo: voce confirma que o alvo e seu OU esta dentro do escopo
    autorizado de um programa, e que a policy permite essa atividade.
  - EXIGE um alvo explicito (-Alvo <dominio> ou -Alvo <arquivo-de-escopo>).
  - Checa "docker info" antes de tudo e para se o Docker estiver desligado.
  - Rate limit conservador por padrao. Volume alto derruba alvo = ban.
  - -Simular monta e mostra os comandos SEM executar nada.
  - Nunca aponta para dominio que voce nao declarou como autorizado.

.PARAMETER Alvo
  Dominio (ex.: exemplo.com) ou caminho de um arquivo com a lista de escopo.

.PARAMETER Etapas
  Quais etapas rodar. Padrao: subs,dns,vivos,urls
  Valores: subs | dns | vivos | urls | scan | portas | cert

.PARAMETER Saida
  Pasta raiz dos resultados. Padrao: .\recon-out

.PARAMETER RateLimit
  Requisicoes por segundo para httpx/katana/nuclei. Padrao: 10 (conservador).

.PARAMETER Autorizo
  Obrigatorio. Confirma autorizacao/escopo.

.PARAMETER Simular
  Mostra os comandos e nao executa nada.

.EXAMPLE
  .\recon.ps1 -Alvo exemplo.com -Autorizo -Etapas subs,dns,vivos

.EXAMPLE
  .\recon.ps1 -Alvo exemplo.com -Autorizo -Simular
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Alvo,
    [string[]]$Etapas = @('subs','dns','vivos','urls'),
    [string]$Saida,
    [ValidateRange(1,100)][int]$RateLimit = 10,
    [switch]$Autorizo,
    [switch]$Simular
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Ao chamar via "powershell -File ... -Etapas dns,vivos", o valor chega como UMA
# string ("dns,vivos"). Normalizando para array de verdade.
$Etapas = @($Etapas | ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' })

$IMG_SUBFINDER = 'projectdiscovery/subfinder:latest'
$IMG_DNSX      = 'projectdiscovery/dnsx:latest'
$IMG_HTTPX     = 'projectdiscovery/httpx:latest'
$IMG_KATANA    = 'projectdiscovery/katana:latest'
$IMG_GAU       = 'sxcurity/gau:latest'
$IMG_NUCLEI    = 'projectdiscovery/nuclei:latest'
$IMG_NAABU     = 'projectdiscovery/naabu:latest'
$IMG_TLSX      = 'projectdiscovery/tlsx:latest'

$VALIDAS = @('subs','dns','vivos','urls','scan','portas','cert')

# ------------------------------------------------------ 1) autorizacao
if (-not $Autorizo) {
    Write-Host ''
    Write-Host '[PARADO] Falta -Autorizo.' -ForegroundColor Red
    Write-Host '         Recon so roda em alvo SEU ou DENTRO DO ESCOPO autorizado de um' -ForegroundColor Red
    Write-Host '         programa, e so se a policy daquele programa permitir.' -ForegroundColor Red
    Write-Host '         Testar fora de escopo da BAN e risco juridico.' -ForegroundColor Red
    Write-Host ''
    Write-Host '         Se o alvo esta autorizado, repita com -Autorizo.' -ForegroundColor Yellow
    exit 3
}

# ------------------------------------------------------ 2) etapas validas
$etapasOk = @($Etapas | Where-Object { $VALIDAS -contains $_ })
$invalidas = @($Etapas | Where-Object { $VALIDAS -notcontains $_ })
if ($invalidas.Count -gt 0) {
    Write-Host ('[PARADO] Etapa(s) invalida(s): ' + ($invalidas -join ', ')) -ForegroundColor Red
    Write-Host ('         Validas: ' + ($VALIDAS -join ', ')) -ForegroundColor Yellow
    exit 4
}
if ($etapasOk.Count -eq 0) {
    Write-Host '[PARADO] Nenhuma etapa valida informada.' -ForegroundColor Red
    exit 4
}

# Fechamento de dependencias + ordem canonica.
# A cadeia e: subs -> dns -> vivos -> urls/scan. Nao adianta rodar "vivos" sem "dns".
$deps = @{
    'subs'   = @()
    'dns'    = @('subs')
    'vivos'  = @('dns')
    'urls'   = @('vivos')
    'scan'   = @('vivos')
    'cert'   = @('subs')
    'portas' = @()
}
$conjunto = @{}
foreach ($e in $etapasOk) { $conjunto[$e] = $true }
$mudou = $true
while ($mudou) {
    $mudou = $false
    foreach ($k in @($conjunto.Keys)) {
        foreach ($d in $deps[$k]) {
            if (-not $conjunto.ContainsKey($d)) { $conjunto[$d] = $true; $mudou = $true }
        }
    }
}
$antes    = $etapasOk.Count
$etapasOk = @($VALIDAS | Where-Object { $conjunto.ContainsKey($_) })
$depsAuto = ($etapasOk.Count -gt $antes)

# ------------------------------------------------------ 3) alvo / escopo
$ehArquivo = Test-Path -LiteralPath $Alvo -PathType Leaf
if ($ehArquivo) {
    $dominioRotulo = Split-Path $Alvo -Leaf
    $arquivoEscopo = (Resolve-Path -LiteralPath $Alvo).Path
} else {
    $dominioRotulo = $Alvo.Trim()
    $arquivoEscopo = $null
    if ($dominioRotulo -notmatch '^[A-Za-z0-9][A-Za-z0-9\.\-]*\.[A-Za-z]{2,}$') {
        Write-Host ('[PARADO] Alvo nao parece um dominio nem um arquivo: ' + $Alvo) -ForegroundColor Red
        Write-Host '         Informe ex.: -Alvo exemplo.com  (ou um arquivo com a lista)' -ForegroundColor Yellow
        exit 5
    }
}
$rotuloPasta = ($dominioRotulo -replace '[^A-Za-z0-9\.\-]','_')

# ------------------------------------------------------ 4) docker
$tmpD = Join-Path $env:TEMP ('recon-docker-' + [guid]::NewGuid().ToString('N') + '.txt')
cmd /c ('docker info > "' + $tmpD + '" 2>&1') | Out-Null
$dockerOk = ($LASTEXITCODE -eq 0)
if (Test-Path -LiteralPath $tmpD) { Remove-Item -LiteralPath $tmpD -Force }

# ------------------------------------------------------ 5) saida
if (-not $Saida) { $Saida = Join-Path (Get-Location).Path 'recon-out' }
$carimbo = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$pasta = Join-Path (Join-Path $Saida $rotuloPasta) $carimbo

function Executar-Docker {
    param(
        [Parameter(Mandatory)][string]$Argumentos,
        [Parameter(Mandatory)][string]$Saida,
        [string]$Entrada
    )
    $erro = $Saida + '.erro.txt'
    $redirIn = ''
    if ($Entrada) { $redirIn = ' < "' + $Entrada + '"' }
    $linha = 'docker ' + $Argumentos + $redirIn + ' > "' + $Saida + '" 2> "' + $erro + '"'
    cmd /c $linha | Out-Null
    return [int]$LASTEXITCODE
}

function ContarLinhas([string]$Caminho) {
    if (-not (Test-Path -LiteralPath $Caminho)) { return 0 }
    return @(Get-Content -LiteralPath $Caminho -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

# ---------- monta a lista de comandos (usada tanto para simular quanto para rodar)
$plano        = New-Object System.Collections.Generic.List[string]
$executadas   = New-Object System.Collections.Generic.List[string]
$semCobertura = New-Object System.Collections.Generic.List[string]

$dominio = if ($arquivoEscopo) { $null } else { $dominioRotulo }
$rotulo  = if ($arquivoEscopo) { $arquivoEscopo } else { $dominio }

$fSubs   = Join-Path $pasta '01-subs.txt'
$fDns    = Join-Path $pasta '02-dns.txt'
$fVivos  = Join-Path $pasta '03-vivos.txt'
$fUrls   = Join-Path $pasta '04-urls.txt'
$fNuclei = Join-Path $pasta '05-nuclei.jsonl'
$fCert   = Join-Path $pasta '06-certificados.txt'

$montaPasta = '-v "' + $pasta + ':/out:ro"'

$passos = New-Object System.Collections.Generic.List[object]

foreach ($e in $etapasOk) {
    switch ($e) {
        'subs' {
            if ($arquivoEscopo) {
                $passos.Add([pscustomobject]@{ Etapa='subs'; Descricao='lista de escopo fornecida (subfinder pulado)'; Args=$null; Saida=$fSubs; Entrada=$arquivoEscopo; Copia=$true })
            } else {
                $passos.Add([pscustomobject]@{ Etapa='subs'; Descricao='subfinder (subdominios)'; Args=('run --rm ' + $IMG_SUBFINDER + ' -d ' + $dominio + ' -silent'); Saida=$fSubs; Entrada=$null; Copia=$false })
            }
        }
        'dns' {
            $passos.Add([pscustomobject]@{ Etapa='dns'; Descricao='dnsx (resolver/filtrar)'; Args=('run -i --rm ' + $IMG_DNSX + ' -silent -a'); Saida=$fDns; Entrada=$fSubs; Copia=$false })
        }
        'vivos' {
            $passos.Add([pscustomobject]@{ Etapa='vivos'; Descricao='httpx (hosts HTTP vivos)'; Args=('run -i --rm ' + $IMG_HTTPX + ' -silent -status-code -title -tech-detect -rl ' + $RateLimit); Saida=$fVivos; Entrada=$fDns; Copia=$false })
        }
        'urls' {
            $passos.Add([pscustomobject]@{ Etapa='urls-katana'; Descricao='katana (crawler)'; Args=('run --rm ' + $montaPasta + ' ' + $IMG_KATANA + ' -list /out/03-vivos.txt -silent -rl ' + $RateLimit); Saida=$fUrls; Entrada=$null; Copia=$false })
            $passos.Add([pscustomobject]@{ Etapa='urls-gau'; Descricao='gau (URLs historicas Wayback/CommonCrawl)'; Args=('run -i --rm ' + $IMG_GAU + ' --threads 5'); Saida=($fUrls + '.gau.txt'); Entrada=$fSubs; Copia=$false })
        }
        'scan' {
            $passos.Add([pscustomobject]@{ Etapa='scan'; Descricao='nuclei (templates high/critical)'; Args=('run --rm ' + $montaPasta + ' ' + $IMG_NUCLEI + ' -l /out/03-vivos.txt -severity high,critical -rl ' + $RateLimit + ' -jsonl -silent'); Saida=$fNuclei; Entrada=$null; Copia=$false })
        }
        'portas' {
            $passos.Add([pscustomobject]@{ Etapa='portas'; Descricao='naabu (portas) - exige rede do host'; Args=('run --rm --network host ' + $IMG_NAABU + ' -host ' + $dominio + ' -silent -top-ports 100'); Saida=(Join-Path $pasta '07-portas.txt'); Entrada=$null; Copia=$false })
        }
        'cert' {
            $passos.Add([pscustomobject]@{ Etapa='cert'; Descricao='tlsx (certificados -> subdominios novos)'; Args=('run -i --rm ' + $IMG_TLSX + ' -silent -san'); Saida=$fCert; Entrada=$fSubs; Copia=$false })
        }
    }
}

foreach ($p in $passos) { $plano.Add(('docker ' + $p.Args)) | Out-Null }

# ---------------------------------------------- cabecalho
Write-Host ''
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host ' RECON - bug bounty (motor do \recon)' -ForegroundColor Cyan
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host (' Alvo      : ' + $rotulo)
Write-Host (' Etapas    : ' + ($etapasOk -join ', '))
if ($depsAuto) {
    Write-Host ' Dependencias: etapas de pre-requisito foram incluidas automaticamente.' -ForegroundColor DarkGray
}
Write-Host (' RateLimit : ' + $RateLimit + ' req/s (conservador)')
Write-Host (' Saida     : ' + $pasta)
Write-Host ' Autorizo  : confirmado por voce' -ForegroundColor Green
Write-Host ''

if ($Simular) {
    Write-Host '[SIMULACAO] Nada foi executado e nenhum pacote saiu para a rede.' -ForegroundColor Cyan
    Write-Host ''
    foreach ($p in $passos) {
        Write-Host (' [' + $p.Etapa + '] ' + $p.Descricao) -ForegroundColor Yellow
        if ($p.Args) {
            Write-Host ('     docker ' + $p.Args)
        } else {
            Write-Host '     (etapa local: copia do arquivo de escopo, sem Docker)' -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    Write-Host 'Portoes OK: autorizacao, etapas validas, alvo valido, Docker.' -ForegroundColor Green
    exit 0
}

if (-not $dockerOk) {
    Write-Host '[PARADO] O Docker nao respondeu (docker info falhou).' -ForegroundColor Red
    Write-Host '         Abra o Docker Desktop e rode de novo. NADA foi executado.' -ForegroundColor Red
    exit 6
}
if (-not (Test-Path -LiteralPath $pasta)) { New-Item -ItemType Directory -Force -Path $pasta | Out-Null }

# ---------------------------------------------- executar
foreach ($p in $passos) {
    if ($p.Copia) {
        # limpa comentarios (#) e linhas vazias do arquivo de escopo
        $linhasOk = @(Get-Content -LiteralPath $p.Entrada -Encoding UTF8 |
                      ForEach-Object { $_.Trim() } |
                      Where-Object { $_ -ne '' -and -not $_.StartsWith('#') })
        [System.IO.File]::WriteAllLines($p.Saida, $linhasOk, $utf8)
        $n = ContarLinhas $p.Saida
        Write-Host ('[ok] ' + $p.Descricao + ': ' + $n + ' linha(s)') -ForegroundColor Green
        $executadas.Add(($p.Etapa + ' | ok | ' + $n + ' | ' + (Split-Path $p.Saida -Leaf))) | Out-Null
        continue
    }
    if ($p.Entrada -and -not (Test-Path -LiteralPath $p.Entrada)) {
        Write-Host ('[--] ' + $p.Etapa + ': entrada ausente (' + (Split-Path $p.Entrada -Leaf) + '), pulado.') -ForegroundColor Yellow
        $semCobertura.Add(($p.Etapa + ' (entrada ausente)')) | Out-Null
        continue
    }
    Write-Host ('[..] ' + $p.Descricao + ' ...') -ForegroundColor Yellow
    $cod = Executar-Docker -Argumentos $p.Args -Saida $p.Saida -Entrada $p.Entrada
    $n = ContarLinhas $p.Saida
    if ($cod -eq 0) {
        Write-Host ('[ok] ' + $p.Etapa + ': ' + $n + ' linha(s)') -ForegroundColor Green
        $executadas.Add(($p.Etapa + ' | exit 0 | ' + $n + ' | ' + (Split-Path $p.Saida -Leaf))) | Out-Null
    } else {
        Write-Host ('[!!] ' + $p.Etapa + ' FALHOU (exit ' + $cod + ') - veja ' + (Split-Path $p.Saida -Leaf) + '.erro.txt') -ForegroundColor Red
        $executadas.Add(($p.Etapa + ' | exit ' + $cod + ' | FALHOU')) | Out-Null
        $semCobertura.Add(($p.Etapa + ' (falhou, exit ' + $cod + ')')) | Out-Null
    }
}

# ---------------------------------------------- relatorio
$r = New-Object System.Collections.Generic.List[string]
$r.Add('# Recon - ' + $rotulo) | Out-Null
$r.Add('') | Out-Null
$r.Add('- Data: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')) | Out-Null
$r.Add('- Etapas pedidas: ' + ($etapasOk -join ', ')) | Out-Null
$r.Add('- Rate limit: ' + $RateLimit + ' req/s (conservador)') | Out-Null
$r.Add('- Autorizacao: confirmada pelo usuario (-Autorizo)') | Out-Null
$r.Add('- Pasta: ' + $pasta) | Out-Null
$r.Add('') | Out-Null
$r.Add('## Etapas executadas') | Out-Null
$r.Add('') | Out-Null
if ($executadas.Count -eq 0) { $r.Add('- Nada foi executado.') | Out-Null }
foreach ($x in $executadas) { $r.Add('- ' + $x) | Out-Null }
$r.Add('') | Out-Null
$r.Add('## Sem cobertura') | Out-Null
$r.Add('') | Out-Null
if ($semCobertura.Count -eq 0) { $r.Add('- Nada ficou de fora dentro das etapas pedidas.') | Out-Null }
foreach ($x in $semCobertura) { $r.Add('- ' + $x) | Out-Null }
$r.Add('') | Out-Null
$r.Add('## Superficie encontrada') | Out-Null
$r.Add('') | Out-Null
$r.Add('- Subdominios: ' + (ContarLinhas $fSubs)) | Out-Null
$r.Add('- Resolvidos (dnsx): ' + (ContarLinhas $fDns)) | Out-Null
$r.Add('- Vivos (httpx): ' + (ContarLinhas $fVivos)) | Out-Null
$r.Add('- URLs (katana): ' + (ContarLinhas $fUrls)) | Out-Null
$r.Add('- URLs (gau): ' + (ContarLinhas ($fUrls + '.gau.txt'))) | Out-Null
$r.Add('- Nuclei (jsonl): ' + (ContarLinhas $fNuclei)) | Out-Null
$r.Add('') | Out-Null
$r.Add('## Arquivos gerados') | Out-Null
$r.Add('') | Out-Null
foreach ($arq in @($fSubs, $fDns, $fVivos, $fUrls, ($fUrls + '.gau.txt'), $fNuclei, $fCert)) {
    if (Test-Path -LiteralPath $arq) { $r.Add('- ' + (Split-Path $arq -Leaf)) | Out-Null }
}
$r.Add('') | Out-Null
$r.Add('## Proximo passo (o que paga)') | Out-Null
$r.Add('') | Out-Null
$r.Add('1. Abrir 03-vivos.txt e procurar o que foge do padrao (dev-, staging-, api-, admin-).') | Out-Null
$r.Add('2. Cruzar 04-urls com parametros (?id=, ?url=, ?file=) -> candidatos a IDOR/SSRF.') | Out-Null
$r.Add('3. Nuclei achou algo? Confirmar manualmente e checar se e duplicado na plataforma.') | Out-Null
$r.Add('4. Escrever o PoC minimo ANTES de reportar.') | Out-Null
$r.Add('') | Out-Null
$r.Add('> Recon NAO e vulnerabilidade. E superficie de ataque.') | Out-Null
$r.Add('') | Out-Null

$caminhoRel = Join-Path $pasta 'RELATORIO.md'
[System.IO.File]::WriteAllText($caminhoRel, ($r -join "`r`n"), $utf8)

Write-Host ''
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host ' RESUMO' -ForegroundColor Cyan
Write-Host '==================================================' -ForegroundColor Cyan
Write-Host (' Subdominios ......: ' + (ContarLinhas $fSubs))
Write-Host (' Resolvidos .......: ' + (ContarLinhas $fDns))
Write-Host (' Vivos ............: ' + (ContarLinhas $fVivos))
Write-Host (' URLs katana ......: ' + (ContarLinhas $fUrls))
Write-Host (' URLs gau .........: ' + (ContarLinhas ($fUrls + '.gau.txt')))
Write-Host (' Nuclei (jsonl) ...: ' + (ContarLinhas $fNuclei))
Write-Host ''
Write-Host ' Sem cobertura:' -ForegroundColor Yellow
if ($semCobertura.Count -eq 0) {
    Write-Host '   - nada'
} else {
    foreach ($x in $semCobertura) { Write-Host ('   - ' + $x) }
}
Write-Host ''
Write-Host (' Relatorio: ' + $caminhoRel) -ForegroundColor Green
Write-Host ''
Write-Host ' LEMBRETE: recon != vulnerabilidade. E so a superficie de ataque.' -ForegroundColor Yellow
Write-Host ''

$falhou = @($executadas | Where-Object { $_ -match 'FALHOU' }).Count
if ($falhou -gt 0) { exit 1 }
exit 0


