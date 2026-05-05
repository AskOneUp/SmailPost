Describe 'Test-SPPrerequisite' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot
        . (Join-Path $script:ModuleRoot 'Private\Graph\Test-SPGraphGetFallback.ps1')
        . (Join-Path $script:ModuleRoot 'Public\Environment\Test-SPPrerequisite.ps1')
    }

    Context 'When HEAD succeeds with a reachable status code' {
        It 'Returns reachable when HEAD returns 200' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                }
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Microsoft Graph endpoint reachable (HEAD 200).'
        }

        It 'Returns reachable when HEAD returns 401' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 401
                }
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Microsoft Graph endpoint reachable (HEAD 401).'
        }

        It 'Returns reachable when HEAD returns 403' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 403
                }
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Microsoft Graph endpoint reachable (HEAD 403).'
        }
    }

    Context 'When HEAD returns a status that needs direct handling' {
        It 'Returns proxy guidance when HEAD returns 407' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 407
                }
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Proxy requires authentication (HTTP 407). Configure system proxy/credentials.'
        }

        It 'Returns throttling note when HEAD returns 429' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 429
                }
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Microsoft Graph endpoint is throttling requests (HTTP 429). Wait and retry later.'
        }

        It 'Returns unexpected status note for other HTTP codes' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 500
                }
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'HEAD probe returned unexpected HTTP 500. Consider network, DNS, or proxy issues.'
        }
    }

    Context 'When HEAD falls back to GET' {
        It 'Uses GET fallback when HEAD returns 405' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 405
                }
            }

            Mock Test-SPGraphGetFallback {
                param(
                    [string]$Uri,
                    [ref]$Result,
                    [int]$PrevCode
                )

                $null = $Uri
                $null = $PrevCode

                $Result.Value.GraphReachable = $true
                $Result.Value.Notes = @('GET fallback succeeded after HEAD 405.')
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'GET fallback succeeded after HEAD 405.'
        }

        It 'Uses GET fallback when HEAD throws with HTTP 405 response' {
            Mock Invoke-WebRequest {
                $exception = [System.Exception]::new('Method not allowed.')
                $response = [pscustomobject]@{
                    StatusCode = 405
                }

                $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
                throw $exception
            }

            Mock Test-SPGraphGetFallback {
                param(
                    [string]$Uri,
                    [ref]$Result,
                    [int]$PrevCode
                )

                $null = $Uri
                $null = $PrevCode

                $Result.Value.GraphReachable = $true
                $Result.Value.Notes = @('GET fallback succeeded after thrown HEAD 405.')
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'GET fallback succeeded after thrown HEAD 405.'
        }
    }

    Context 'When HEAD throws with an HTTP response' {
        It 'Returns reachable when thrown response status is 401' {
            Mock Invoke-WebRequest {
                $exception = [System.Exception]::new('Unauthorized.')
                $response = [pscustomobject]@{
                    StatusCode = 401
                }

                $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
                throw $exception
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Microsoft Graph endpoint reachable (HEAD 401).'
        }

        It 'Returns extended proxy guidance when thrown response status is 407' {
            Mock Invoke-WebRequest {
                $exception = [System.Exception]::new('Proxy authentication required.')
                $response = [pscustomobject]@{
                    StatusCode = 407
                }

                $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
                throw $exception
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be "Proxy requires authentication (HTTP 407). Configure system proxy/credentials (e.g., 'netsh winhttp import proxy source=ie' or use PowerShell -Proxy/-ProxyUseDefaultCredentials)."
        }

        It 'Returns throttling note when thrown response status is 429' {
            Mock Invoke-WebRequest {
                $exception = [System.Exception]::new('Too many requests.')
                $response = [pscustomobject]@{
                    StatusCode = 429
                }

                $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
                throw $exception
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'Microsoft Graph endpoint is throttling requests (HTTP 429). Wait and retry later.'
        }
    }

    Context 'When HEAD throws a transport error without an HTTP response' {
        It 'Returns DNS note and merges failed GET fallback notes' {
            Mock Invoke-WebRequest {
                throw [System.Exception]::new('NameResolutionFailure')
            }

            Mock Test-SPGraphGetFallback {
                param(
                    [string]$Uri,
                    [ref]$Result,
                    [int]$PrevCode
                )

                $null = $Uri
                $null = $PrevCode

                $Result.Value.GraphReachable = $false
                $Result.Value.Notes = @('GET fallback also failed.')
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 2
            $result.Notes[0] | Should -Be 'Cannot reach Microsoft Graph endpoint. DNS resolution failed.'
            $result.Notes[1] | Should -Be 'GET fallback also failed.'
        }

        It 'Returns timeout note and preserves successful GET fallback reachability' {
            Mock Invoke-WebRequest {
                throw [System.Exception]::new('The operation timed out.')
            }

            Mock Test-SPGraphGetFallback {
                param(
                    [string]$Uri,
                    [ref]$Result,
                    [int]$PrevCode
                )

                $null = $Uri
                $null = $PrevCode

                $Result.Value.GraphReachable = $true
                $Result.Value.Notes = @('GET fallback succeeded after timeout.')
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeTrue

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 2
            $result.Notes[0] | Should -Be 'Cannot reach Microsoft Graph endpoint. Connection timed out (firewall or proxy may be blocking).'
            $result.Notes[1] | Should -Be 'GET fallback succeeded after timeout.'
        }

        It 'Returns generic transport note when the error is not recognized' {
            Mock Invoke-WebRequest {
                throw [System.Exception]::new('Socket exploded in a boring corporate way')
            }

            Mock Test-SPGraphGetFallback {
                param(
                    [string]$Uri,
                    [ref]$Result,
                    [int]$PrevCode
                )

                $null = $Uri
                $null = $PrevCode

                $Result.Value.GraphReachable = $false
                $Result.Value.Notes = @()
            }

            $result = Test-SPPrerequisite

            $result.GraphReachable | Should -BeFalse

            $null -eq $result.Notes | Should -BeFalse
            $null -eq $result.Notes.Count | Should -BeFalse
            $result.Notes.Count | Should -Be 1
            $result.Notes[0] | Should -Be 'HEAD probe failed: Socket exploded in a boring corporate way.'
        }
    }

    Context 'Parameter forwarding' {
        It 'Passes Uri, Head method, and timeout to Invoke-WebRequest' {
            Mock Invoke-WebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                }
            } -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/' -and
                $Method -eq 'Head' -and
                $OperationTimeoutSeconds -eq 7
            }

            $result = Test-SPPrerequisite -OperationTimeoutSeconds 7

            $result.GraphReachable | Should -BeTrue
        }
    }
}
