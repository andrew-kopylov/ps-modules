
function Upload-FtpFile($Url, $Usr, $Pwd, $LocalPath) {

    $Request = Get-FtpRequest -Url $Url -Usr $Usr -Pwd $Pwd -Method ([System.Net.WebRequestMethods+Ftp]::UploadFile)
    $Request.UseBinary = $true
    $Request.UsePassive = $true

    $FileContent = Get-Content -Encoding Byte -Path $LocalPath
    $Request.ContentLength = $FileContent.Length
    
    $Stream = $Request.GetRequestStream()
    $Stream.Write($FileContent, 0, $FileContent.Length)

    $Stream.Close()
    $Stream.Dispose()

    Get-FtpItem -Url $Url -Usr $Usr -Pwd $Pwd
}

function Download-FtpFile($Url, $Usr, $Pwd, $LocalPath) {

    $Request = Get-FtpRequest -Url $Url -Usr $Usr -Pwd $Pwd -Method ([System.Net.WebRequestMethods+Ftp]::DownloadFile)
    $Request.UseBinary = $true
    $Request.KeepAlive = $false

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $ResponseStream = $Response.GetResponseStream()

    # Create the target file on the local system and the download buffer
    $LocalFile = New-Object IO.FileStream ($LocalPath, [IO.FileMode]::Create)

    [byte[]]$ReadBuffer = New-Object byte[] 1024

    $ReadLength = $ResponseStream.Read($ReadBuffer, 0, 1024)
    while ($ReadLength -ne 0) {
        $LocalFile.Write($ReadBuffer, 0, $ReadLength)
        $ReadLength = $ResponseStream.Read($ReadBuffer, 0, 1024)
    }
    $Response.Dispose()
    $Response.Close()

    $LocalFile.Close()

    Get-Item -Path $LocalPath
}

function Remove-FtpItem($Url, $Usr, $Pwd) {
    
    $Item = Get-FtpItem -Url $Url -Usr $Usr -Pwd $Pwd
    if ($Item -eq $null) {
        return $false
    }

    $Request = Get-FtpRequest -Url $Url -Usr $Usr -Pwd $Pwd

    if ($Item.Dir) {
        $Request.Method = [System.Net.WebRequestMethods+Ftp]::RemoveDirectory
    }
    else {
        $Request.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    }

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $Response.Dispose()
    $Response.Close()

    $true
}

function New-FtpDirectory($Url, $Usr, $Pwd) {
    $Request = Get-FtpRequest -Url $Url -Usr $Usr -Pwd $Pwd
    $Request.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $Response.Dispose()
    $Response.Close()
    Get-FtpItem -Url $Url -Usr $Usr -Pwd $Pwd
}

function Test-FtpItem($Url, $Usr, $Pwd) {
    $Result = [bool]((Get-FtpItem -Url $Url -Usr $Usr -Pwd $Pwd) -ne $null)
    $Result
}

function Get-FtpItem($Url, $Usr, $Pwd) {

    $SplitUrl = Split-FtpUrl -Url $Url
    if ([String]::IsNullOrEmpty($SplitUrl.Child)) {return $null}

    $Item = Get-FtpChildItems -Url $SplitUrl.Parent -Usr $Usr -Pwd $Pwd | Where-Object -FilterScript {$_.Name -Like $SplitUrl.Child}
    
    if ($Item -ne $null -and $Item.Name -like $SplitUrl.Child) {
        return $Item
    }
    else {
        return $null 
    }

}

function Get-FtpChildItems($Url, $Usr, $Pwd) {

    $Request = Get-FtpRequest -Url $Url -Usr $Usr -Pwd $Pwd -Method ([System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails)

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $Stream = New-Object System.IO.StreamReader($Response.GetResponseStream())

    # drw-rw-rw- 1 ftp ftp            0 Jun 10 10:16 directoryname
    # -rw-rw-rw- 1 ftp ftp     32866304 Sep 28 23:00 filename

    $Pattern = @()
    $Pattern += '(?<dir>[-d])(?<right>[-rwx]{9})'
    $Pattern += '(?<link>\d+)'
    $Pattern += '(?<usr>\S+)'
    $Pattern += '(?<grp>\S+)'
    $Pattern += '(?<size>\d+)'
    $Pattern += '(?<month>\w+)'
    $Pattern += '(?<day>\d+)'
    $Pattern += '(?<time>\d{1,2}:\d{2})'
    $Pattern += '(?<name>.+)'
    $Pattern = '^' + [String]::Join('\s+', $Pattern) + '$'

    $FtpItems = @()

    $Line = $Stream.ReadLine()
    while ($Line -ne $null) {
        if ($Line -match $Pattern) {
            $Item = New-Object psobject -Property @{
                Dir = ($Matches.dir -eq 'd');
                Right = $Matches.right;
                Link = [int]$Matches.link;
                User = $Matches.usr;
                Group = $Matches.grp;
                Size = [long]$Matches.size;
                Month = $Matches.month;
                Day = [int]$Matches.day;
                Time = $Matches.time;
                Name = $Matches.name;
                Parent = $Url;
                Url = (Add-FtpUrlPath -Url $Url -SubUrl $Matches.name)
            }
            $FtpItems += $Item
        }
        $Line = $Stream.ReadLine()
    }

    $Response.Close()
    $Response.Dispose()

    $FtpItems
}

function Get-FtpRequest($Url, $Usr, $Pwd, $Method) {
    $FtpRequest = [System.Net.FtpWebRequest]::Create($Url)
    $FtpRequest.Credentials = New-Object System.Net.NetworkCredential($Usr, $Pwd)
    if ($Method -ne $null) {
        $FtpRequest.Method = $Method
    }
    $FtpRequest
}

function Split-FtpUrl($Url) {
    $Result = @{Parent = ''; Child = ''}
    $Pattern = '^(?<parent>\S+)\/(?<child>\S+?)\/{0,1}$'
    if ($Url -match $Pattern) {
        $Result.Parent = $Matches.parent
        $Result.Child = $Matches.child
    }
    else {
        $Result.Parent = $Url
        $Result.Child = ''
    }
    $Result
}

function Join-FtpUrlPaths($Paths) {
    $Result = ''
    foreach ($Path in $Paths) {
        if ([String]::IsNullOrEmpty($Path)) {continue}
        $Result = Add-FtpUrlPath -Url $Result -SubUrl $Path
    }
    $Result
}

function Add-FtpUrlPath($Url, $SubUrl) {
    $Sep = '/'
    if ($Url.EndsWith($Sep) -xor $SubUrl.StartsWith($Sep)) {
        $Url = $Url + $SubUrl
    } 
    elseif (-not $SubUrl.StartsWith($Sep)) {
        $Url = $Url + $Sep + $SubUrl
    }
    else {
        $Url = $Url + $SubUrl.Substring(1)
    }
    $Url
}
