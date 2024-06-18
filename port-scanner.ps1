param (
    [string]$target,
    [int]$startPort = 1,
    [int]$endPort = 85
)

if (-not $target) {
    Write-Host "Invalid amount of arguments."
    Write-Host "Syntax: .\scanner.ps1 -target <ip> [-startPort <startPort>] [-endPort <endPort>]"
    exit
}

Write-Host ("***********************************************************************")
Write-Host "Scanning target $target"
Write-Host "Port range: $startPort - $endPort"
Write-Host "TIME STARTED: $(Get-Date)"
Write-Host ("***********************************************************************")

try {
    $jobs = @()
    for ($port = $startPort; $port -le $endPort; $port++) {
        $jobs += Start-Job -ScriptBlock {
            param ($target, $port)
            
            function Scan-Port {
                param (
                    [string]$target,
                    [int]$port
                )

                $tcpClient = New-Object System.Net.Sockets.TcpClient
                try {
                    $tcpClient.Connect($target, $port)
                    if ($tcpClient.Connected) {
                        Write-Host "Port $port is open"
                    }
                } catch {
                    # Do nothing, port is closed
                } finally {
                    $tcpClient.Close()
                }
            }

            Scan-Port -target $target -port $port
        } -ArgumentList $target, $port
    }

    $jobs | ForEach-Object { Receive-Job -Job $_ -Wait }

} catch [System.Exception] {
    Write-Host "An unexpected error occurred: $($_.Exception.Message)"
    exit
}

Write-Host "**********************************************************************"
Write-Host "TIME ENDED: $(Get-Date)"
