<#
.SYNOPSIS
    IP Checker v4.5 - Migración a PowerShell
    Autor Original: Rooster
#>

# --- Forzar codificación UTF-8 en la Consola ---
# Esto corrige las letras raras (Ã­, Ã³) tanto en entrada como en salida
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- Configuración de Ruta del .env ---
$EnvPath = Join-Path $PSScriptRoot ".env"

if (Test-Path $EnvPath) {
    # Corregido: Filtramos líneas vacías y comentarios ANTES del bucle y limpiamos retornos de carro invisibles
    Get-Content $EnvPath | ForEach-Object {
        $linea = $_.Trim().Replace("`r", "") # Elimina cualquier salto de línea invisible de Windows
        if ($linea -notmatch '^#' -and $linea -like '*=*') {
            $k, $v = $linea -split '=', 2
            # Guardamos tanto en el proceso actual como en el bloque global de variables de entorno
            $keyName = $k.Trim()
            $keyValue = $v.Trim().Trim('"').Trim("'") # Quita comillas si las tuviera el .env
            [System.Environment]::SetEnvironmentVariable($keyName, $keyValue, "Process")
        }
    }
}

# Obtener la API Key de forma segura del proceso actual
$global:API_KEY = [System.Environment]::GetEnvironmentVariable("ABUSEIPDB_API_KEY", "Process")

# --- Funciones de Interfaz ---
function Show-Banner {
    Write-Host @"
┌─────────────────────────────────────────────────────────────────────────┐
│d888888b d8888b.  .o88b. db   db d88888b  .o88b.  db   dD d88888b d8888b.│
│   88    88   8D d8P  Y8 88   88 88'      d8P  Y8 88 ,8P' 88'     88   8D│
│   88    88oodD' 8P      88ooo88 88ooooo 8P       88,8P   88ooooo 88oobY'│
│   88    88~~~   8b      88~~~88 88~~~~~ 8b       88 8b   88~~~~~ 88 8b  │
│  .88.   88      Y8b  d8 88   88 88.      Y8b  d8 88  88. 88.     88  88.│
│Y888888P 88       Y88P'  YP   YP Y88888P   Y88P'  YP   YD Y88888P 88   YD│
└─────────────────────────────────────────────────────────────────────────┘
                        IP CHECKER v1.5 PowerShell Edition
"@ -ForegroundColor Yellow
    Write-Host "   Autor: Rooster | GitHub: https://github.com/Rzztr" -ForegroundColor Cyan
}

function Show-Exchange {
    Start-Sleep -Milliseconds 500
    Write-Host "`n0================================================================================================0`n" -ForegroundColor Cyan
}

# --- Funciones de Lógica ---
function Test-HostActive {
    param([string]$Target)
    Write-Host "[*] Revisando si $Target está activo..." -ForegroundColor Blue
    if (Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-Host "[+] Host activo" -ForegroundColor Green
    } else {
        Write-Host "[-] Host inactivo o bloquea ICMP" -ForegroundColor Red
    }
}

function Process-Source {
    param([string[]]$Entrada)
    if ($Entrada.Count -eq 1 -and (Test-Path $Entrada[0]) -and ($Entrada[0] -match '\.(txt|log)$')) {
        return Get-Content $Entrada[0] -Encoding UTF8
    }
    return $Entrada
}

function Invoke-AbuseIPScript {
    param(
        [string[]]$Fuente,
        [bool]$GuardarArchivo
    )
    
    $Ips = Process-Source $Fuente
    $SalidaTxt = Join-Path $PSScriptRoot "reputacion_ips_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $ReporteLineas = @()

    if ($GuardarArchivo) {
        Write-Host "[*] Guardando reporte de reputación en: $SalidaTxt" -ForegroundColor Yellow
    }

    $Header = "INICIANDO ANALISIS DE REPUTACION...`n"
    $Header += [string]::Format("{0,-18} | {1,-7} | {2,-6} | {3,-30}", "IP", "SCORE", "PAIS", "ORGANIZACION")
    $Header += "`n--------------------------------------------------------------------------------------------------"
    
    if (-not $GuardarArchivo) { Write-Host $Header } else { $ReporteLineas += $Header }

    foreach ($linea in $Ips) {
        $ip = $linea.Trim()
        if ([string]::IsNullOrWhiteSpace($ip) -or $ip -match '^#' -or $ip -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            continue
        }

        # Consulta AbuseIPDB (JSON Nativo)
        if ($global:API_KEY) {
            $headers = @{ "Key" = $global:API_KEY; "Accept" = "application/json" }
            $uri = "https://api.abuseipdb.com/api/v2/check?ipAddress=$ip&maxAgeInDays=90"
            try {
                $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
                $score = $response.data.abuseConfidenceScore
                if ($null -eq $score) { $score = 0 }
            } catch {
                $score = "Err"
            }
        } else {
            $score = "?"
        }

        # Consulta WHOIS alternativa via API
        try {
            $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/$ip" -Method Get
            $country = if ($geo.countryCode) { $geo.countryCode } else { "??" }
            $org = if ($geo.org) { $geo.org } else { "Desconocido" }
            if ($org.Length -gt 30) { $org = $org.Substring(0,30) }
        } catch {
            $country = "??"
            $org = "Desconocido"
        }

        $FormatString = "{0,-18} | {1,-3}%    | {2,-6} | {3,-30}"
        $DataLine = [string]::Format($FormatString, $ip, $score, $country, $org)

        if ($GuardarArchivo) {
            $ReporteLineas += $DataLine
        } else {
            $color = "Green"
            if ($score -ne "?" -and $score -ne "Err" -and $score -gt 50) { $color = "Red" }
            elseif ($score -ne "?" -and $score -ne "Err" -and $score -gt 10) { $color = "Yellow" }
            
            Write-Host "$($ip.PadRight(18)) | " -NoNewline
            Write-Host "$($score.ToString().PadRight(3))%    " -ForegroundColor $color -NoNewline
            Write-Host "| $($country.PadRight(6)) | $org"
        }
    }

    if ($GuardarArchivo) {
        $ReporteLineas | Out-File -FilePath $SalidaTxt -Encoding utf8
        Write-Host "[+] ¡Reporte guardado con éxito!" -ForegroundColor Green
    }
}

function Test-IsTor {
    param([string]$IpSuspicius)
    if ([string]::IsNullOrEmpty($IpSuspicius)) {
        Write-Host "Error: No se proporcionó una IP para verificar." -ForegroundColor Red
        return
    }
    
    try {
        $torList = Invoke-RestMethod -Uri "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=8.8.8.8"
        if ($torList -match "(?m)^$([regex]::Escape($IpSuspicius))$") {
            Write-Host "[!] La IP $IpSuspicius es un nodo de salida de Tor." -ForegroundColor Red
        } else {
            Write-Host "[+] La IP $IpSuspicius no es un nodo de salida de Tor." -ForegroundColor Green
        }
    } catch {
        Write-Host "[-] Error al conectar con el proyecto Tor." -ForegroundColor Red
    }
}

function Get-CheckTor {
    param([string]$Ip)
    if ([string]::IsNullOrEmpty($Ip)) {
        Write-Host "Error: No se proporcionó una IP para verificar." -ForegroundColor Red
        return
    }
    Write-Host "IP's tor que alcanzan al host: $Ip" -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$Ip" | Select-Object -ExpandProperty Content
    } catch {
        Write-Host "[-] Error al obtener lista de Tor." -ForegroundColor Red
    }
}

function Get-WhoisData {
    param([string]$Ip)
    Write-Host "--- DATOS RESUMIDOS --- (Vía Geolocalización API)" -ForegroundColor Yellow
    try {
        $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/$Ip" -Method Get
        Write-Host "  IP:          $Ip"
        Write-Host "  Organización:$($geo.org)"
        Write-Host "  Proveedor:   $($geo.as)"
        Write-Host "  Ciudad:      $($geo.city)"
        Write-Host "  País:        $($geo.country)"
    } catch {
        Write-Host "  No se pudieron recuperar datos para esta IP." -ForegroundColor Red
    }
}

function Invoke-AuditoriaWhoisCompleta {
    param(
        [string[]]$Fuente,
        [bool]$GuardarArchivo
    )
    $Ips = Process-Source $Fuente
    $SalidaTxt = Join-Path $PSScriptRoot "resultado_whois_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    Write-Host "=== Iniciando auditoría resumida de red ===" -ForegroundColor Yellow
    if ($GuardarArchivo) {
        Write-Host "Resultados se guardarán en: $SalidaTxt"
        $null = New-Item -Path $SalidaTxt -ItemType File -Force
    } else {
        Write-Host "Mostrando resultados en pantalla..."
    }
    Write-Host "------------------------------------------------"

    $contador = 0
    foreach ($linea in $Ips) {
        $ip = $linea.Trim()
        if ([string]::IsNullOrWhiteSpace($ip) -or $ip -match '^#' -or $ip -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { continue }
        $contador++

        if ($GuardarArchivo) {
            Write-Host "[$contador] Consultando datos de red para: $ip..."
            $txtBlock = @"
==================================================
 IP: $ip
 Fecha de consulta: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
==================================================
$(Invoke-RestMethod -Uri "http://ip-api.com/json/$ip" | ConvertTo-Json)


"@
            $txtBlock | Add-Content -Path $SalidaTxt
        } else {
            Write-Host "[$contador] Datos de red para: $ip" -ForegroundColor Blue
            Write-Host "=================================================="
            Invoke-RestMethod -Uri "http://ip-api.com/json/$ip" | Format-List | Out-String | Write-Host
            Write-Host "=================================================="
            Write-Host "`n"
        }
    }
    Write-Host "------------------------------------------------"
    Write-Host "¡Proceso terminado con éxito!" -ForegroundColor Green
    Write-Host "Total de IPs procesadas: $contador"
}

function Show-Help {
    Write-Host "Modo de uso:" -ForegroundColor Yellow -NoNewline
    Write-Host " .\ipChecker.ps1 [opción] [IPs / archivo] [-o]"
    Write-Host "-------------------------------------------------------------"
    Write-Host "`nOpciones disponibles:"
    Write-Host "  -g, --generar   [IP]            Analiza una sola IP (Ping + Reputación + Resumen)" -ForegroundColor Green
    Write-Host "  -i, --lista     [IPs/Archivo]   Ver reputación en consola. Agrega -o al final para TXT" -ForegroundColor Green
    Write-Host "  -w, --whois     [IPs/Archivo]   Ver resumen de red en consola. Agrega -o al final para TXT" -ForegroundColor Green
    Write-Host "  -isTor, --tor   [IP]            Verifica si la IP es un nodo de salida de Tor" -ForegroundColor Green
    Write-Host "  -cT, --checkTor [IP]            Lista de IPs de salida de Tor que alcanzan a la IP dada" -ForegroundColor Green
    Write-Host "  -h, --help                      Muestra este menú" -ForegroundColor Green

    Write-Host "`nEjemplos prácticos:"
    Write-Host "  Visualizar: .\ipChecker.ps1 -g 8.8.8.8"
    Write-Host "  Múltiples:  .\ipChecker.ps1 -i 8.8.8.8 1.1.1.1"
    Show-Exchange
}

# --- Lógica de Argumentos ---
if ($args.Count -eq 0) {
    Show-Banner
    Show-Help
    exit
}

Show-Banner

$Opcion = $args[0]
$ArgumentosRestantes = $args[1..($args.Count - 1)]

$Guardar = $false
if ($ArgumentosRestantes -contains "-o") {
    $Guardar = $true
    $ArgumentosRestantes = $ArgumentosRestantes | Where-Object { $_ -ne "-o" }
}

switch ($Opcion) {
    { $_ -in "-g", "--generar" } {
        if (-not $ArgumentosRestantes) { Write-Host "Error: Debes proporcionar una IP individual" -ForegroundColor Red; exit }
        $TargetIP = $ArgumentosRestantes[0]
        Show-Exchange
        Test-HostActive $TargetIP
        Invoke-AbuseIPScript @($TargetIP) $false
        Show-Exchange
        Get-WhoisData $TargetIP
        Show-Exchange
    }
    { $_ -in "-i", "--lista" } {
        if (-not $ArgumentosRestantes) { Write-Host "Error: Debes proporcionar IPs o un archivo" -ForegroundColor Red; exit }
        Show-Exchange
        Invoke-AbuseIPScript $ArgumentosRestantes $Guardar
        Show-Exchange
    }
    { $_ -in "-w", "--whois" } {
        if (-not $ArgumentosRestantes) { Write-Host "Error: Debes proporcionar IPs o un archivo" -ForegroundColor Red; exit }
        Show-Exchange
        Invoke-AuditoriaWhoisCompleta $ArgumentosRestantes $Guardar
        Show-Exchange
    }
    { $_ -in "-isTor", "--tor" } {
        if (-not $ArgumentosRestantes) { Write-Host "Error: Debes proporcionar una IP para verificar" -ForegroundColor Red; exit }
        Show-Exchange
        Test-IsTor $ArgumentosRestantes[0]
        Show-Exchange
    }
    { $_ -in "-cT", "--checkTor" } {
        if (-not $ArgumentosRestantes) { Write-Host "Error: Debes proporcionar una IP para verificar" -ForegroundColor Red; exit }
        Show-Exchange
        Get-CheckTor $ArgumentosRestantes[0]
        Show-Exchange
    }
    Default {
        Show-Help
    }
}
