#requires -Version 5.1
<#
.SYNOPSIS
  Gera os arquivos de regras do "Rosa - Comandos de Papel" para cada IA.

.DESCRIPTION
  Le catalogo/*.md (a fonte da verdade, AGNOSTICA de ferramenta) e escreve a
  saida no formato de cada ferramenta dentro de dist/.

.PARAMETER Ferramenta
  Qual adaptador gerar. Padrao: todas.

.PARAMETER Destino
  Pasta de saida. Padrao: <raiz do projeto>\dist

.EXAMPLE
  .\gerar.ps1
  .\gerar.ps1 -Ferramenta cursor
  .\gerar.ps1 -Destino C:\temp\rosa-dist
#>
[CmdletBinding()]
param(
    [ValidateSet('todas','cline-projeto','cline-global','cursor','claude-code','copilot','gemini','windsurf','agents','unico')]
    [string]$Ferramenta = 'todas',

    [string]$Destino
)

$ErrorActionPreference = 'Stop'

$Raiz     = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Catalogo = Join-Path $Raiz 'catalogo'
if (-not $Destino) { $Destino = Join-Path $Raiz 'dist' }

if (-not (Test-Path -LiteralPath $Catalogo)) {
    throw "Pasta do catalogo nao encontrada: $Catalogo"
}

$fonte = @(Get-ChildItem -LiteralPath $Catalogo -Filter '*.md' -File | Sort-Object Name)
if ($fonte.Count -eq 0) { throw "Nenhum arquivo .md em $Catalogo" }

$utf8SemBom = New-Object System.Text.UTF8Encoding($false)
$textoDe = @{}
foreach ($f in $fonte) {
    $textoDe[$f.Name] = ([System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)).Trim()
}
$completo = (($fonte | ForEach-Object { $textoDe[$_.Name] }) -join "`r`n`r`n---`r`n`r`n")
$gerados = New-Object System.Collections.Generic.List[string]

function Escrever([string]$Caminho, [string]$Conteudo) {
    $dir = Split-Path -Parent $Caminho
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Caminho, $Conteudo, $utf8SemBom)
    $rel = $Caminho.Replace($Raiz, '.')
    Write-Host ("  [ok] {0}" -f $rel)
    $script:gerados.Add($rel)
}

function Cabecalho([string]$Adapter, [string]$Instalar) {
    (@(
        '<!-- GERADO AUTOMATICAMENTE por gerar.ps1 - NAO EDITE ESTE ARQUIVO. -->',
        '<!-- Projeto: Rosa - Comandos de Papel | Fonte: catalogo/*.md -->',
        ("<!-- Adapter: {0} | Instalar em: {1} -->" -f $Adapter, $Instalar),
        ("<!-- Gerado em: {0} -->" -f (Get-Date -Format 'yyyy-MM-dd HH:mm')),
        ''
    ) -join "`r`n")
}

function Gerar-MultiArquivo([string]$Adapter, [string]$SubPasta, [string]$Instalar) {
    foreach ($f in $fonte) {
        $conteudo = (Cabecalho $Adapter $Instalar) + $textoDe[$f.Name] + "`r`n"
        Escrever (Join-Path $Destino "$SubPasta/$($f.Name)") $conteudo
    }
}

function Gerar-ArquivoUnico([string]$Adapter, [string]$CaminhoRel, [string]$Instalar, [string]$Prefixo = '', [switch]$PrefixoPrimeiro) {
    $cab = Cabecalho $Adapter $Instalar
    $conteudo = if ($PrefixoPrimeiro) { $Prefixo + $cab + $completo + "`r`n" } else { $cab + $Prefixo + $completo + "`r`n" }
    Escrever (Join-Path $Destino $CaminhoRel) $conteudo
}

function Gerar-ClineProjeto { Gerar-MultiArquivo 'cline-projeto' 'cline-projeto/.clinerules' '<projeto>/.clinerules/' }
function Gerar-ClineGlobal  { Gerar-MultiArquivo 'cline-global'  'cline-global/Rules'        'Documents\Cline\Rules\' }

# Descricoes usadas no front-matter (description) das regras do Cursor.
$descricoes = @{
    '00-nucleo.md'       = 'Rosa - nucleo - sintaxe dos comandos, regras de modo, progresso e aprovacao'
    '10-planejamento.md' = 'Rosa - comandos de PLANEJAMENTO (\pm \ux \tech \scrum) - nao editam arquivos'
    '20-execucao.md'     = 'Rosa - comandos de EXECUCAO (\front \back \devops \data \secops \qa)'
    '30-geral-e-map.md'  = 'Rosa - \geral (roteador com aprovacao) e \map (historico do projeto)'
    '40-limites.md'      = 'Rosa - limites da IA - o que ela nao consegue e o que o usuario deve fazer'
    '50-ajuda.md'        = 'Rosa - \ajuda - manual completo de todos os comandos'
}

function LimparPasta([string]$Rel) {
    $alvo = Join-Path $Destino $Rel
    if (Test-Path -LiteralPath $alvo) { Remove-Item -LiteralPath $alvo -Recurse -Force }
}

# Cursor: CADA regra e um arquivo .mdc em .cursor/rules/ e o front-matter TEM
# que estar na linha 1 (o Cursor ignora arquivos .md dentro de .cursor/rules).
function Gerar-Cursor {
    foreach ($f in $fonte) {
        $desc = if ($descricoes.ContainsKey($f.Name)) { $descricoes[$f.Name] } else { "Rosa - $($f.Name)" }
        $fm = (@(
            '---',
            ("description: '" + $desc + "'"),
            'alwaysApply: true',
            '---',
            ''
        ) -join "`r`n")
        $conteudo = $fm + (Cabecalho 'cursor' '<projeto>/.cursor/rules/rosa/') + $textoDe[$f.Name] + "`r`n"
        Escrever (Join-Path $Destino ("cursor/.cursor/rules/rosa/" + $f.BaseName + '.mdc')) $conteudo
    }

    # O Cursor nao tem pasta global: o global chama-se "User Rules" (colar no app).
    $cabUser = (@(
        'ROSA - COMANDOS DE PAPEL --- User Rules do Cursor',
        '',
        'Cole TODO este texto em: Cursor > Settings / Customize > Rules > User Rules.',
        'Assim os comandos valem em TODOS os seus projetos no Cursor.',
        '',
        'Fonte: https://github.com/joaquimmoraesgabriel-cmyk/Rosa',
        ("Gerado em: " + (Get-Date -Format 'yyyy-MM-dd HH:mm')),
        ('=' * 60),
        ''
    ) -join "`r`n")
    Escrever (Join-Path $Destino 'cursor/USER-RULES.txt') ($cabUser + $completo + "`r`n")
}

function Gerar-ClaudeCode { Gerar-ArquivoUnico 'claude-code' 'claude-code/CLAUDE.md' '<projeto>/CLAUDE.md' }
function Gerar-Copilot    { Gerar-ArquivoUnico 'copilot'    'copilot/.github/copilot-instructions.md' '<projeto>/.github/' }
function Gerar-Gemini     { Gerar-ArquivoUnico 'gemini'     'gemini/GEMINI.md' '<projeto>/GEMINI.md' }
function Gerar-Windsurf   { Gerar-ArquivoUnico 'windsurf'   'windsurf/.windsurfrules' '<projeto>/.windsurfrules' }
function Gerar-Agents     { Gerar-ArquivoUnico 'agents'     'agents/AGENTS.md' '<projeto>/AGENTS.md ou ~/.agents/AGENTS.md' }
function Gerar-Unico      { Gerar-ArquivoUnico 'unico'      'UNICO-completo.md' 'colar em qualquer IA' }

$ordem = @('cline-projeto','cline-global','cursor','claude-code','copilot','gemini','windsurf','agents','unico')
$mapa = @{
    'cline-projeto' = 'Gerar-ClineProjeto'
    'cline-global'  = 'Gerar-ClineGlobal'
    'cursor'        = 'Gerar-Cursor'
    'claude-code'   = 'Gerar-ClaudeCode'
    'copilot'       = 'Gerar-Copilot'
    'gemini'        = 'Gerar-Gemini'
    'windsurf'      = 'Gerar-Windsurf'
    'agents'        = 'Gerar-Agents'
    'unico'         = 'Gerar-Unico'
}

$lista = if ($Ferramenta -eq 'todas') { $ordem } else { @($Ferramenta) }

Write-Host ''
Write-Host 'Rosa - Comandos de Papel : gerador de adaptadores' -ForegroundColor Cyan
Write-Host ("Catalogo : {0} arquivo(s) em {1}" -f $fonte.Count, $Catalogo)
Write-Host ("Destino  : {0}" -f $Destino)
Write-Host ''

$pastas = @{
    'cline-projeto' = 'cline-projeto'
    'cline-global'  = 'cline-global'
    'cursor'        = 'cursor'
    'claude-code'   = 'claude-code'
    'copilot'       = 'copilot'
    'gemini'        = 'gemini'
    'windsurf'      = 'windsurf'
    'agents'        = 'agents'
}

foreach ($k in $lista) {
    Write-Host ("[{0}]" -f $k) -ForegroundColor Yellow
    if ($pastas.ContainsKey($k)) { LimparPasta $pastas[$k] }
    if ($k -eq 'unico') {
        $unico = Join-Path $Destino 'UNICO-completo.md'
        if (Test-Path -LiteralPath $unico) { Remove-Item -LiteralPath $unico -Force }
    }
    & $mapa[$k]
}

# ---------------- Auto-validacao da saida ----------------
# Evita "gerou torto sem avisar": confere o front-matter das regras do Cursor.
Write-Host ''
Write-Host 'Validando a saida...' -ForegroundColor Cyan
$falhas = 0

$mdcs = @(Get-ChildItem -LiteralPath $Destino -Recurse -Filter '*.mdc' -File -ErrorAction SilentlyContinue)
foreach ($m in $mdcs) {
    $linhas = @(Get-Content -LiteralPath $m.FullName -TotalCount 5 -Encoding UTF8)
    $bloco = $linhas -join "`n"
    if ($linhas.Count -lt 3 -or $linhas[0] -ne '---' -or $bloco -notmatch 'alwaysApply') {
        Write-Host ("  [FALHA] front-matter invalido (linha 1 deve ser ---): " + $m.Name) -ForegroundColor Red
        $falhas++
    }
}
Write-Host ("  {0} arquivo(s) .mdc conferido(s)." -f $mdcs.Count)

# O Cursor IGNORA .md dentro de .cursor/rules/ -- nao gerar esse erro.
$mdErrados = @(Get-ChildItem -LiteralPath $Destino -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -eq '.md' -and $_.FullName -match '\.cursor[\\/]rules[\\/]' })
if ($mdErrados.Count -gt 0) {
    foreach ($m in $mdErrados) { Write-Host ("  [FALHA] .md dentro de .cursor/rules (o Cursor ignora): " + $m.Name) -ForegroundColor Red }
    $falhas++
}
Write-Host ("  {0} arquivo(s) .md indevido(s) em .cursor/rules." -f $mdErrados.Count)

if ($falhas -eq 0) {
    Write-Host '  Validacao OK.' -ForegroundColor Green
} else {
    Write-Host ("  {0} problema(s) encontrado(s)." -f $falhas) -ForegroundColor Red
    throw 'Validacao da saida falhou.'
}

Write-Host ''
Write-Host ("Concluido: {0} arquivo(s) gerado(s)." -f $gerados.Count) -ForegroundColor Green
Write-Host ("Tamanho do conjunto completo: {0} caracteres." -f $completo.Length)
Write-Host 'Proximo passo: ver adaptadores/README.md para instalar em cada IA.'
