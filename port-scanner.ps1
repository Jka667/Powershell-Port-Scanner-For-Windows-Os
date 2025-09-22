param (
    [string]$target,
    [int]$startPort,
    [int]$endPort,
    [int]$TimeoutMs = 800  # connection timeout per port (milliseconds)
)

# Default ports to test when no range is provided
$DefaultPorts = @(21,22,25,53,80,110,143,443,445,3389)

# Ask for target if none provided
if (-not $target) {
    $target = Read-Host "Enter the target IP address or hostname to scan"
}

# Build the ports list (either user-defined range or default list)
[int[]]$Ports = @()
if (-not $startPort -or -not $endPort) {
    Write-Host "No port range provided."
    $useDefault = Read-Host "Use default common ports? (Y/N)"
    if ($useDefault -match '^(Y|y|O|o)$') {
        $Ports = $DefaultPorts
    } else {
        $startPort = [int](Read-Host "Enter the start port")
        $endPort   = [int](Read-Host "Enter the end port")
        $Ports = $startPort..$endPort
    }
} else {
    $Ports = $startPort..$endPort
}

# Header
Write-Host ("***********************************************************************")
Write-Host "Scanning target: $target"
Write-Host "Ports: $($Ports -join ', ')"
Write-Host "TIME STARTED: $(Get-Date)"
Write-Host ("***********************************************************************")

# Function used inside jobs – returns an object instead of writing to host
$scanScript = {
    param ($target, $port, $TimeoutMs)

    # Return objects to aggregate in the parent runspace
    $result = [pscustomobject]@{
        Port   = $port
        Open   = $false
        Error  = $null
    }

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        # Async connect with timeout to avoid long hangs
        $iar = $client.BeginConnect($target, $port, $null, $null)
        $connectedInTime = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($connectedInTime -and $client.Connected) {
            $result.Open = $true
        } else {
            $result.Open = $false
        }
    } catch {
        $result.Error = $_.Exception.Message
        $result.Open = $false
    } finally {
        $client.Close()
    }

    # Emit result object to the pipeline
    $result
}

# Launch jobs for each port
$jobs = foreach ($p in $Ports) {
    Start-Job -ScriptBlock $scanScript -ArgumentList $target, $p, $TimeoutMs
}

# Collect results
$results = @()
foreach ($job in $jobs) {
    $results += Receive-Job -Job $job -Wait -ErrorAction SilentlyContinue
    Remove-Job $job -Force | Out-Null
}

# Per-port output (clear and explicit)
foreach ($r in $results | Sort-Object Port) {
    if ($r.Open) {
        Write-Host ("Port {0} is OPEN" -f $r.Port) -ForegroundColor Green
    } else {
        Write-Host ("Port {0} is CLOSED" -f $r.Port) -ForegroundColor DarkGray
    }
}

# Summary
$openPorts   = $results | Where-Object { $_.Open } | Select-Object -ExpandProperty Port
$closedCount = ($results.Count - $openPorts.Count)

Write-Host ("-----------------------------------------------------------------------")
Write-Host ("SUMMARY for {0}" -f $target) -ForegroundColor Cyan
Write-Host ("Open ports: {0}" -f $openPorts.Count) -ForegroundColor Green
if ($openPorts.Count -gt 0) {
    Write-Host (" - {0}" -f ($openPorts -join ', ')) -ForegroundColor Green
}
Write-Host ("Closed ports: {0}" -f $closedCount) -ForegroundColor DarkGray
Write-Host ("TIME ENDED: {0}" -f (Get-Date))
Write-Host ("***********************************************************************")
