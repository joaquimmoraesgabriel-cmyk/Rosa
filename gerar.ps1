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

function Gerar-Cursor {
    $fm = (@(
        '---',
        'description: Rosa - Comandos de Papel (comandos \pm \ux \tech \scrum \front \back \devops \data \secops \qa \geral \map \ajuda)',
        'alwaysApply: true',
        '---',
        ''
    ) -join "`r`n")
    Gerar-ArquivoUnico 'cursor' 'cursor/.cursor/rules/rosa-comandos.mdc' '<projeto>/.cursor/rules/' $fm -PrefixoPrimeiro
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

foreach ($k in $lista) {
    Write-Host ("[{0}]" -f $k) -ForegroundColor Yellow
    & $mapa[$k]
}

Write-Host ''
Write-Host ("Concluido: {0} arquivo(s) gerado(s)." -f $gerados.Count) -ForegroundColor Green
Write-Host ("Tamanho do conjunto completo: {0} caracteres." -f $completo.Length)
Write-Host 'Proximo passo: ver adaptadores/README.md para instalar em cada IA.'
