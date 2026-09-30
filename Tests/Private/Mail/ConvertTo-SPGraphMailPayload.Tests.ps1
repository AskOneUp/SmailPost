Describe 'ConvertTo-SPGraphMailPayload' {
    BeforeAll {
        . "$PSScriptRoot\..\..\Shared\TestBootstrap.ps1"

        $script:ModuleRoot = Get-SPTestProjectRoot -StartPath $PSScriptRoot

        . (Join-Path $script:ModuleRoot 'Private\Mail\ConvertTo-SPGraphMailPayload.ps1')
    }

    Context 'When required inputs are valid' {

        It 'Builds the expected Graph payload without attachments' {
            # Proves the function builds the correct payload structure.

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient ' user@example.com ' `
                -Subject 'Test subject' `
                -HtmlBody '<p>Hello world</p>'

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType ([hashtable])

            $result.ContainsKey('message') | Should -BeTrue
            $result.ContainsKey('saveToSentItems') | Should -BeTrue

            $result.saveToSentItems | Should -BeTrue

            $result.message.subject | Should -Be 'Test subject'
            $result.message.body.contentType | Should -Be 'HTML'
            $result.message.body.content | Should -Be '<p>Hello world</p>'

            $result.message.toRecipients | Should -HaveCount 1
            $result.message.toRecipients[0].emailAddress.address | Should -Be 'user@example.com'

            $result.message.ContainsKey('bccRecipients') | Should -BeFalse
            $result.message.ContainsKey('attachments') | Should -BeFalse
        }

        It 'Builds the expected Graph payload with attachments' {
            # Proves attachments are included when provided.

            $attachments = @(
                @{
                    '@odata.type' = '#microsoft.graph.fileAttachment'
                    name          = 'report.txt'
                    contentBytes  = 'dGVzdA=='
                    contentType   = 'text/plain'
                }
            )

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient 'user@example.com' `
                -Subject 'Attachment test' `
                -HtmlBody '<p>Attached</p>' `
                -Attachments $attachments

            $result.message.ContainsKey('attachments') | Should -BeTrue
            $result.message.attachments | Should -HaveCount 1
            $result.message.attachments[0].name | Should -Be 'report.txt'
        }

        It 'Builds the expected Graph payload with a BCC recipient' {
            # Proves a supplied BCC address is included in the Graph message.

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient 'user@example.com' `
                -Subject 'BCC test' `
                -HtmlBody '<p>Body</p>' `
                -BccAddress ' audit@example.com '

            $result.message.ContainsKey('bccRecipients') | Should -BeTrue
            $result.message.bccRecipients | Should -HaveCount 1
            $result.message.bccRecipients[0].emailAddress.address | Should -Be 'audit@example.com'
        }

        It 'Does not add BCC recipients when no BCC address is supplied' {
            # Proves BCC remains optional and preserves existing behaviour.

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient 'user@example.com' `
                -Subject 'No BCC' `
                -HtmlBody '<p>Body</p>'

            $result.message.ContainsKey('bccRecipients') | Should -BeFalse
        }

        It 'Does not add BCC recipients when the BCC address is whitespace' {
            # Proves a whitespace-only optional BCC address is ignored.

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient 'user@example.com' `
                -Subject 'Whitespace BCC' `
                -HtmlBody '<p>Body</p>' `
                -BccAddress '   '

            $result.message.ContainsKey('bccRecipients') | Should -BeFalse
        }

        It 'Uses the provided SaveToSentItems value when false' {
            # Proves explicit SaveToSentItems value is preserved.

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient 'user@example.com' `
                -Subject 'No save' `
                -HtmlBody '<p>Body</p>' `
                -SaveToSentItems $false

            $result.saveToSentItems | Should -BeFalse
        }

        It 'Does not add attachments when empty array supplied' {
            # Proves empty attachments do not create the attachments node.

            $result = ConvertTo-SPGraphMailPayload `
                -Recipient 'user@example.com' `
                -Subject 'Empty attachments' `
                -HtmlBody '<p>Body</p>' `
                -Attachments @()

            $result.message.ContainsKey('attachments') | Should -BeFalse
        }
    }

    Context 'When required inputs are invalid' {

        It 'Throws binding error when Recipient is empty' {
            # PowerShell parameter binding rejects empty string.

            {
                ConvertTo-SPGraphMailPayload `
                    -Recipient '' `
                    -Subject 'Test subject' `
                    -HtmlBody '<p>Hello world</p>'
            } | Should -Throw "Cannot bind argument to parameter 'Recipient' because it is an empty string."
        }

        It 'Throws when Recipient is whitespace' {
            # Function validation should reject whitespace.

            {
                ConvertTo-SPGraphMailPayload `
                    -Recipient '   ' `
                    -Subject 'Test subject' `
                    -HtmlBody '<p>Hello world</p>'
            } | Should -Throw 'Recipient cannot be null, empty, or whitespace.'
        }

        It 'Throws binding error when Subject is empty' {
            # Parameter binding rejection.

            {
                ConvertTo-SPGraphMailPayload `
                    -Recipient 'user@example.com' `
                    -Subject '' `
                    -HtmlBody '<p>Hello world</p>'
            } | Should -Throw "Cannot bind argument to parameter 'Subject' because it is an empty string."
        }

        It 'Throws when Subject is whitespace' {
            # Function validation should reject whitespace.

            {
                ConvertTo-SPGraphMailPayload `
                    -Recipient 'user@example.com' `
                    -Subject '   ' `
                    -HtmlBody '<p>Hello world</p>'
            } | Should -Throw 'Subject cannot be null, empty, or whitespace.'
        }

        It 'Throws binding error when HtmlBody is empty' {
            # Parameter binding rejection.

            {
                ConvertTo-SPGraphMailPayload `
                    -Recipient 'user@example.com' `
                    -Subject 'Test subject' `
                    -HtmlBody ''
            } | Should -Throw "Cannot bind argument to parameter 'HtmlBody' because it is an empty string."
        }

        It 'Throws when HtmlBody is whitespace' {
            # Function validation should reject whitespace.

            {
                ConvertTo-SPGraphMailPayload `
                    -Recipient 'user@example.com' `
                    -Subject 'Test subject' `
                    -HtmlBody '   '
            } | Should -Throw 'HtmlBody cannot be null, empty, or whitespace.'
        }
    }
}
