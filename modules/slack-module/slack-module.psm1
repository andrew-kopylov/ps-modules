
function Send-SlackWebHook {
    param (
        $HookUrl,
        $Text
    )

    if ([string]::IsNullOrEmpty($HookUrl)) {break}

    $Body = @{
        text = $Text
    }

    $BodyJson = ConvertTo-Json -InputObject $Body

    [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
    Invoke-RestMethod -Method Post -Uri $HookUrl -ContentType 'application/json; charset=utf-8' -Body $BodyJson -TimeoutSec 5
}
