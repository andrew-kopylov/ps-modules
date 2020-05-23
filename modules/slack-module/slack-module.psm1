
# Version 1.2

function Send-SlackWebHook {
    param (
        $HookUrl,
        $Text,
        $Header,
        $Emoji
    )

    if ([string]::IsNullOrEmpty($HookUrl)) {return}

    if ($Header) {
        $Text = "*$Header*`n$Text"
    }

    if ($Emoji) {
        $Text = (Get-SlackEmoji -Name $Emoji) + ' ' + $Text
    }

    $Body = @{
        text = $Text
    }

    $BodyJson = ConvertTo-Json -InputObject $Body

    [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
    Invoke-RestMethod -Method Post -Uri $HookUrl -ContentType 'application/json; charset=utf-8' -Body $BodyJson -TimeoutSec 5 | Out-Null
}

function Get-SlackFormat {
    param (
        $Text,
        [switch]$Bold,
        [switch]$Italic,
        [switch]$Strike,
        [switch]$CodeBlock
    )

    if (-not $Text) {
        return ''
    }

    if ($Bold) {
        $Text = '*' + $Text + '*'
    }

    if ($Italic) {
        $Text = '_' + $Text + '_'
    }

    if ($Strike) {
        $Text = '~' + $Text + '~'
    }

    if ($CodeBlock) {
        if ($Text.Contains("`n")) {
            $Text = '``' + $Text + '``'
        }
        else {
            $Text = '`' + $Text + '`'
        }
    }

    $Text
}

function Get-SlackEmoji ($Name) {
    if ($Name) {':' + $Name + ':'}
    else {''}
}
