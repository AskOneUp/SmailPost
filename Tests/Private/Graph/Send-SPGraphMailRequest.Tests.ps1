Describe 'Send-SPGraphMailRequest' {

    BeforeAll {

        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        if (-not (Get-Command Get-SPGraphAccessToken -ErrorAction SilentlyContinue)) {
            function Get-SPGraphAccessToken {
            }
        }

        . (Join-Path $script:ModuleRoot 'Private\Graph\Send-SPGraphMailRequest.ps1')
    }

    BeforeEach {

        Mock Get-SPGraphAccessToken {
            [pscustomobject]@{
                Success     = $true
                AccessToken = 'token-123'
                Audience    = 'https://graph.microsoft.com'
                AppId       = 'app-123'
                Roles       = @('Mail.Send')
                Notes       = @()
            }
        }

        Mock Invoke-WebRequest {
            [pscustomobject]@{
                StatusCode = 202
            }
        }

        Mock Start-Sleep {
        }
    }

    It 'Throws when SenderAddress is null, empty, or whitespace' {
        {
            Send-SPGraphMailRequest -SenderAddress '   ' -Payload @{ message = @{ subject = 'Hello' } }
        } | Should -Throw 'SenderAddress cannot be null, empty, or whitespace.'
    }

    It 'Throws when Payload is null' {
        {
            Send-SPGraphMailRequest -SenderAddress 'askoneup@askoneup.com' -Payload $null
        } | Should -Throw "Cannot bind argument to parameter 'Payload' because it is null."
    }

    It 'Throws when Payload is empty' {
        {
            Send-SPGraphMailRequest -SenderAddress 'askoneup@askoneup.com' -Payload @{}
        } | Should -Throw 'Payload cannot be null or empty.'
    }

    It 'Returns success when Microsoft Graph accepts the sendMail request' {
        $payload = @{
            message         = @{
                subject = 'Hello'
            }
            saveToSentItems = $true
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload $payload

        $result.Success | Should -BeTrue
        $result.StatusCode | Should -Be 202
        $result.ErrorMessage | Should -Be ''
        $result.RequestUri | Should -Be 'https://graph.microsoft.com/v1.0/users/askoneup%40askoneup.com/sendMail'
        $result.Notes | Should -Contain 'RequestUri: https://graph.microsoft.com/v1.0/users/askoneup%40askoneup.com/sendMail'
        $result.Notes | Should -Contain 'SenderAddress input: askoneup@askoneup.com'
        $result.Notes | Should -Contain 'Token audience: https://graph.microsoft.com'
        $result.Notes | Should -Contain 'Token app id: app-123'
        $result.Notes | Should -Contain 'Token roles: Mail.Send'
        $result.Notes | Should -Contain "Microsoft Graph accepted the sendMail request for sender 'askoneup@askoneup.com'."

        Should -Invoke -CommandName Get-SPGraphAccessToken -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Trims and URL-encodes the sender address in the request URI' {
        $payload = @{
            message = @{
                subject = 'Hello'
            }
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress ' ask oneup+test@askoneup.com ' `
            -Payload $payload

        $result.Success | Should -BeTrue
        $result.RequestUri | Should -Be 'https://graph.microsoft.com/v1.0/users/ask%20oneup%2Btest%40askoneup.com/sendMail'
        $result.Notes | Should -Contain 'SenderAddress input: ask oneup+test@askoneup.com'
    }

    It 'Returns failure when token result is null' {
        Mock Get-SPGraphAccessToken {
            $null
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.StatusCode | Should -Be 0
        $result.ErrorMessage | Should -Be 'Failed to acquire a Microsoft Graph access token result.'
        $result.Notes | Should -Contain "Microsoft Graph sendMail request failed for sender 'askoneup@askoneup.com'."
        $result.Notes | Should -Contain 'Failed to acquire a Microsoft Graph access token result.'

        Should -Invoke -CommandName Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Returns failure when token acquisition fails without notes' {
        Mock Get-SPGraphAccessToken {
            [pscustomobject]@{
                Success     = $false
                AccessToken = $null
                Audience    = $null
                AppId       = $null
                Roles       = @()
                Notes       = @()
            }
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Failed to acquire a Microsoft Graph access token.'
        $result.Notes | Should -Contain 'Failed to acquire a Microsoft Graph access token.'

        Should -Invoke -CommandName Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Returns failure when token acquisition fails with notes' {
        Mock Get-SPGraphAccessToken {
            [pscustomobject]@{
                Success     = $false
                AccessToken = $null
                Audience    = $null
                AppId       = $null
                Roles       = @()
                Notes       = @(
                    'Stored secret found.',
                    'AAD rejected the client secret.'
                )
            }
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Failed to acquire a Microsoft Graph access token. Stored secret found. AAD rejected the client secret.'
        $result.Notes | Should -Contain 'Failed to acquire a Microsoft Graph access token. Stored secret found. AAD rejected the client secret.'

        Should -Invoke -CommandName Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Returns failure when token result does not contain an access token' {
        Mock Get-SPGraphAccessToken {
            [pscustomobject]@{
                Success     = $true
                AccessToken = ''
                Audience    = 'https://graph.microsoft.com'
                AppId       = 'app-123'
                Roles       = @('Mail.Send')
                Notes       = @()
            }
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Token result did not contain an access token.'
        $result.Notes | Should -Contain 'Token result did not contain an access token.'

        Should -Invoke -CommandName Invoke-WebRequest -Times 0 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Returns failure with status code when Invoke-WebRequest throws with response status' {
        Mock Invoke-WebRequest {
            $exception = [System.Exception]::new('Graph request failed.')
            $response = [pscustomobject]@{
                StatusCode = 403
            }

            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.StatusCode | Should -Be 403
        $result.ErrorMessage | Should -Be 'Graph request failed.'
        $result.Notes | Should -Contain "Microsoft Graph sendMail request failed for sender 'askoneup@askoneup.com'."
        $result.Notes | Should -Contain 'Graph request failed.'

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Returns failure and includes response body when available' {
        Mock Invoke-WebRequest {
            $memoryStream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new(
                $memoryStream,
                [System.Text.Encoding]::UTF8,
                1024,
                $true
            )

            $writer.Write('{"error":"access denied"}')
            $writer.Flush()
            $memoryStream.Position = 0

            $response = [pscustomobject]@{
                StatusCode = 401
                Stream     = $memoryStream
            }

            $response | Add-Member -MemberType ScriptMethod -Name GetResponseStream -Value {
                return $this.Stream
            } -Force

            $exception = [System.Exception]::new('Unauthorized.')
            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.StatusCode | Should -Be 401
        $result.ErrorMessage | Should -Be 'Unauthorized. Response body: {"error":"access denied"}'
        $result.Notes | Should -Contain 'Unauthorized. Response body: {"error":"access denied"}'

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
    }

    It 'Retries a throttled Graph request and succeeds when the retry is accepted' {
        $script:requestAttempt = 0

        Mock Invoke-WebRequest {
            $script:requestAttempt++

            if ($script:requestAttempt -eq 1) {
                $response = [pscustomobject]@{
                    StatusCode = 429
                    Headers    = @{
                        'Retry-After' = '2'
                    }
                }

                $exception = [System.Exception]::new(
                    'Response status code does not indicate success: 429 (Too Many Requests).'
                )

                $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

                throw $exception
            }

            [pscustomobject]@{
                StatusCode = 202
            }
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeTrue
        $result.StatusCode | Should -Be 202
        $result.ErrorMessage | Should -Be ''

        Should -Invoke -CommandName Get-SPGraphAccessToken -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -Times 2 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 1 -Exactly -ParameterFilter {
            $Seconds -eq 2
        }
    }

    It 'Returns failure after the maximum number of throttled Graph attempts' {
        Mock Invoke-WebRequest {
            $response = [pscustomobject]@{
                StatusCode = 429
                Headers    = @{
                    'Retry-After' = '1'
                }
            }

            $exception = [System.Exception]::new(
                'Response status code does not indicate success: 429 (Too Many Requests).'
            )

            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeFalse
        $result.StatusCode | Should -Be 429

        Should -Invoke -CommandName Get-SPGraphAccessToken -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -Times 5 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 4 -Exactly -ParameterFilter {
            $Seconds -eq 1
        }
    }

    It 'Returns token roles note as empty when no roles are present' {
        Mock Get-SPGraphAccessToken {
            [pscustomobject]@{
                Success     = $true
                AccessToken = 'token-123'
                Audience    = 'https://graph.microsoft.com'
                AppId       = 'app-123'
                Roles       = @()
                Notes       = @()
            }
        }

        $result = Send-SPGraphMailRequest `
            -SenderAddress 'askoneup@askoneup.com' `
            -Payload @{ message = @{ subject = 'Hello' } }

        $result.Success | Should -BeTrue
        $result.Notes | Should -Contain 'Token roles: '
    }
}
