# FEEDAGIANT — VALIDACAO SEM PUBLICACAO (PowerShell 7/Windows)
# Rode no diretório do repositorio, nao dentro do Roblox Studio.
# Exige Rojo, Selene, StyLua instalados. Erro de qualquer ferramenta = NO-GO.
# Nao altera DataStore, place oficial, Creator Store ou Robux.
[CmdletBinding()]
param(
  [string]$KenneyZip = "$env:USERPROFILE\Downloads\kenney_food-kit.zip",
  [string]$FantasyZip = "$env:USERPROFILE\Downloads\Fantasy Props MegaKit[Standard].zip",
  [switch]$IgnoreMissingArchives
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$checks = New-Object System.Collections.Generic.List[string]

function Must-Command([string]$name) {
  $found = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $found) { throw "Ferramenta obrigatória ausente: $name. Execute com Rokit ativo." }
  return $found
}

function Run-Checked([string]$label, [scriptblock]$action) {
  Write-Host "-- $label"
  & $action
  if ($LASTEXITCODE -ne 0) { throw "Falhou: $label (exit code: $LASTEXITCODE)" }
  $checks.Add("$label: PASS") | Out-Null
}

try {
  Must-Command git | Out-Null
  Must-Command rojo | Out-Null
  Must-Command selene | Out-Null
  Must-Command stylua | Out-Null
  Write-Host "[FeedAGiant] Projeto: $root"
  git status --short
  Write-Host "Este script nao modifica arquivos do projeto."

  Run-Checked "StyLua (sintaxe e formatacao)" { stylua --check src tests }
  Run-Checked "Selene (lints Roblox)" { selene src }

  $outputPlace = Join-Path ([System.IO.Path]::GetTempPath()) ("FeedAGiant_check_" + [Guid]::NewGuid().ToString("N") + ".rbxl")
  try {
    Run-Checked "Rojo build isolado" { rojo build default.project.json -o $outputPlace }
    if (-not (Test-Path -LiteralPath $outputPlace)) { throw "Rojo não criou arquivo temporário." }
    Write-Host "Rojo place temporário: $outputPlace"
  }
  finally {
    if (Test-Path -LiteralPath $outputPlace) {
      Remove-Item -LiteralPath $outputPlace -Force
    }
  }

  if ((Test-Path -LiteralPath $KenneyZip) -and (Test-Path -LiteralPath $FantasyZip)) {
    Must-Command python | Out-Null
    Run-Checked "22 assets nos ZIPs locais" {
      python tools/check_art_archives.py --kenney $KenneyZip --fantasy $FantasyZip
    }
  } elseif (-not $IgnoreMissingArchives) {
    throw "ZIPs não encontrados. Indique -KenneyZip e -FantasyZip, ou -IgnoreMissingArchives para executar somente código."
  } else {
    Write-Warning "Arquivos ZIP não testados — SKIP explícito."
  }

  Write-Host ""
  foreach ($line in $checks) { Write-Host $line }
  Write-Host "GATES MANUAIS NÃO EXECUTADOS: Studio Play, 2 clientes, DataStore, recibos, celular real, captura de foto, place oficial."
  Write-Host "STATUS: APENAS VERIFICAÇÕES DE CÓDIGO E ARQUIVOS; ainda não é autorização para publicar."
}
catch {
  Write-Error $_
  exit 1
}
finally {
  Pop-Location
}
