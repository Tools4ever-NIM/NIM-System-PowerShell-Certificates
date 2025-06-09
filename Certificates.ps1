# version: 1.0
#
# Certificates.ps1 - Certificates
#

$Log_MaskableKeys = @(
    "proxy_password"
)

#
# System functions
#
function Idm-SystemInfo {
    param (
        # Operations
        [switch] $Connection,
        [switch] $TestConnection,
        [switch] $Configuration,
        # Parameters
        [string] $ConnectionParams
    )

    Log info "-Connection=$Connection -TestConnection=$TestConnection -Configuration=$Configuration -ConnectionParams='$ConnectionParams'"

    if ($Connection) {
        @(
            @{
                name = 'hostnames'
                type = 'textbox'
                label = 'URLs'
                description = 'Comma delimited list of urls to check'
                value = 'https://tools4ever.com,https://google.com'
            }
            @{
                name = 'nr_of_sessions'
                type = 'textbox'
                label = 'Max. number of simultaneous sessions'
                description = ''
                value = 1
            }
            @{
                name = 'sessions_idle_timeout'
                type = 'textbox'
                label = 'Session cleanup idle time (minutes)'
                description = ''
                value = 1
            }
        )
    }

    if ($TestConnection) {
        
    }

    if ($Configuration) {
        @()
    }

    Log info "Done"
}

function Idm-OnUnload {
}

#
# Object CRUD functions
#

function Idm-CertificatesRead {
    param (
        # Mode
        [switch] $GetMeta,    
        # Parameters
        [string] $SystemParams,
        [string] $FunctionParams

    )
        $system_params   = ConvertFrom-Json2 $SystemParams
        $function_params = ConvertFrom-Json2 $FunctionParams
        
        if ($GetMeta) {
            @(
                @{ name = 'URL';           										options = @('default','key')} 
                @{ name = 'ResponseTimeMS';           									options = @('default')}    
                @{ name = 'Subject';           									options = @('default')}    
                @{ name = 'Issuer';           									options = @('default')}
                @{ name = 'NotBefore';           								options = @('default')}
                @{ name = 'NotAfter';           							    options = @('default')}
                @{ name = 'Thumbprint';           						        options = @('default')}
                @{ name = 'SerialNumber';           						    options = @('default')}
                @{ name = 'FriendlyName';           						    options = @('default')}
                @{ name = 'SignatureAlgo';           							options = @('default')}
                @{ name = 'PublicKeyAlgo';           						    options = @('default')}
            )
            
        } else {
            Log info "Parsing hostnames"
            foreach($url in $system_params.hostnames.split(',')) {
                Log info "Retrieving [$($url)]"
                try {
                        # Extract hostname and port
                        $uri = [Uri]$Url
                        $hostname = $uri.Host
                        $port = if ($uri.Port -eq -1) { 443 } else { $uri.Port }

                        # Start timer
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                        $tcpClient = New-Object System.Net.Sockets.TcpClient
                        $tcpClient.Connect($hostname, $port)
                        

                        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, ({ $true }))
                        $sslStream.AuthenticateAsClient($hostname)

                        # Stop timer
                        $stopwatch.Stop()
                        $elapsedMs = $stopwatch.ElapsedMilliseconds

                        $cert = $sslStream.RemoteCertificate
                        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $cert

                        # Output certificate details
                        [PSCustomObject]@{
                            URL            = $url
                            ResponseTimeMS  = $elapsedMs
                            Subject        = $cert2.Subject
                            Issuer         = $cert2.Issuer
                            NotBefore      = $cert2.NotBefore
                            NotAfter       = $cert2.NotAfter
                            Thumbprint     = $cert2.Thumbprint
                            SerialNumber   = $cert2.SerialNumber
                            FriendlyName   = $cert2.PublicKey.Oid.FriendlyName
                            SignatureAlgo  = $cert2.SignatureAlgorithm.FriendlyName
                            PublicKeyAlgo  = $cert2.PublicKey.Oid.FriendlyName
                        }

                        $sslStream.Close()
                        $tcpClient.Close()                
                }
                catch [System.Net.WebException] {
                    $message = "Error : $($_)"
                    Log error $message
                    Write-Error $_
                }
                catch {
                    $message = "Error : $($_)"
                    Log error $message
                    Write-Error $_
                }
            }
        }
}


function Get-ClassMetaData {
    param (
        [string] $SystemParams,
        [string] $Class
    )

    @(
        @{
            name = 'properties'
            type = 'grid'
            label = 'Properties'
            table = @{
                rows = @( $Global:Properties.$Class | ForEach-Object {
                    @{
                        name = $_.name
                        usage_hint = @( @(
                            foreach ($opt in $_.options) {
                                if ($opt -notin @('default', 'idm', 'key')) { continue }

                                if ($opt -eq 'idm') {
                                    $opt.Toupper()
                                }
                                else {
                                    $opt.Substring(0,1).Toupper() + $opt.Substring(1)
                                }
                            }
                        ) | Sort-Object) -join ' | '
                    }
                })
                settings_grid = @{
                    selection = 'multiple'
                    key_column = 'name'
                    checkbox = $true
                    filter = $true
                    columns = @(
                        @{
                            name = 'name'
                            display_name = 'Name'
                        }
                        @{
                            name = 'usage_hint'
                            display_name = 'Usage hint'
                        }
                    )
                }
            }
            value = ($Global:Properties.$Class | Where-Object { $_.options.Contains('default') }).name
        }
    )
}
