Describe 'Test-SPGraphGetFallback' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Graph\Test-SPGraphGetFallback.ps1')
    }

    BeforeEach {
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                StatusCode = 200
            }
        }
    }

    It 'Marks GraphReachable true when GET fallback succeeds' {
        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeTrue
        $result.Notes | Should -Contain 'Microsoft Graph endpoint reachable (GET fallback succeeded).'

        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }

    It 'Initializes Notes when Notes is missing or null' {
        $result = [ordered]@{
            GraphReachable = $false
            Notes          = $null
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeTrue
        $result.Notes | Should -Not -BeNullOrEmpty
        $result.Notes | Should -Contain 'Microsoft Graph endpoint reachable (GET fallback succeeded).'
    }

    It 'Marks GraphReachable true when GET fallback returns 401' {
        Mock Invoke-WebRequest {
            $response = [pscustomobject]@{
                StatusCode = 401
            }

            $exception = [System.Exception]::new('Unauthorized.')
            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeTrue
        $result.Notes | Should -Contain 'Microsoft Graph endpoint reachable (GET fallback returned 401).'
    }

    It 'Marks GraphReachable true when GET fallback returns 403' {
        Mock Invoke-WebRequest {
            $response = [pscustomobject]@{
                StatusCode = 403
            }

            $exception = [System.Exception]::new('Forbidden.')
            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeTrue
        $result.Notes | Should -Contain 'Microsoft Graph endpoint reachable (GET fallback returned 403).'
    }

    It 'Adds proxy guidance note when GET fallback returns 407' {
        Mock Invoke-WebRequest {
            $response = [pscustomobject]@{
                StatusCode = 407
            }

            $exception = [System.Exception]::new('Proxy authentication required.')
            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeFalse
        $result.Notes | Should -Contain "Proxy requires authentication (HTTP 407). Configure system proxy/credentials (e.g. run 'netsh winhttp import proxy source=ie' or use PowerShell -Proxy/-ProxyUseDefaultCredentials)."
    }

    It 'Adds throttling note when GET fallback returns 429' {
        Mock Invoke-WebRequest {
            $response = [pscustomobject]@{
                StatusCode = 429
            }

            $exception = [System.Exception]::new('Too many requests.')
            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeFalse
        $result.Notes | Should -Contain 'Microsoft Graph endpoint is throttling requests (HTTP 429). Wait and retry later.'
    }

    It 'Adds unexpected status note when GET fallback returns another HTTP code' {
        Mock Invoke-WebRequest {
            $response = [pscustomobject]@{
                StatusCode = 503
            }

            $exception = [System.Exception]::new('Service unavailable.')
            $exception | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $exception
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result) `
            -PrevCode 405

        $result.GraphReachable | Should -BeFalse
        $result.Notes | Should -Contain 'Cannot reach Microsoft Graph endpoint. HEAD HTTP 405 → GET fallback HTTP 503. Check network, DNS, or proxy.'
    }

    It 'Adds DNS failure note when transport error indicates name resolution failure' {
        Mock Invoke-WebRequest {
            throw [System.Exception]::new('NameResolutionFailure: No such host is known.')
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeFalse
        $result.Notes | Should -Contain 'Cannot reach Microsoft Graph endpoint. DNS resolution failed.'
    }

    It 'Adds timeout note when transport error indicates a timeout' {
        Mock Invoke-WebRequest {
            throw [System.Exception]::new('The operation has timed out.')
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeFalse
        $result.Notes | Should -Contain 'Cannot reach Microsoft Graph endpoint. Connection timed out (firewall or proxy may be blocking).'
    }

    It 'Adds generic transport note when transport error is neither DNS nor timeout' {
        Mock Invoke-WebRequest {
            throw [System.Exception]::new('Socket exploded dramatically')
        }

        $result = [ordered]@{
            GraphReachable = $false
            Notes          = @()
        }

        Test-SPGraphGetFallback `
            -Uri 'https://graph.microsoft.com/v1.0/' `
            -Result ([ref]$result)

        $result.GraphReachable | Should -BeFalse
        $result.Notes | Should -Contain 'Cannot reach Microsoft Graph endpoint. Details (GET fallback): Socket exploded dramatically.'
    }
}
