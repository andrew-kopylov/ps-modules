
# Version 1.1

function Send-SlackWebHook {
    param (
        $HookUrl,
        $Text,
        $Header
    )

    if ([string]::IsNullOrEmpty($HookUrl)) {return}

    if (-not [string]::IsNullOrEmpty($Header)) {
        $Text = "*$Header*\n$Text"
    }

    $Body = @{
        text = $Text
    }

    $BodyJson = ConvertTo-Json -InputObject $Body

    [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
    Invoke-RestMethod -Method Post -Uri $HookUrl -ContentType 'application/json; charset=utf-8' -Body $BodyJson -TimeoutSec 5
}
