
function Get-FtpConn($Srv, $Usr, $Pwd, $RootPath, $IsSecure, $BufferSize = 64KB) {
    @{
        Srv = $Srv;
        Usr = $Usr;
        Pwd = $Pwd;
        RootPath = $RootPath;
        IsSecure = $IsSecure;
        BufferSize = $BufferSize
    }
}

function Rename-FtpFile($Conn, $Path, $NewName) {

}

function Send-FtpFile($Conn, $Path, $LocalPath) {

    if (-not (Test-Path -Path $LocalPath)) {
        throw ('Local file ' + $LocalPath + ' not exists')
    }

    $File = Get-Item -Path $LocalPath
    if ([String]::IsNullOrEmpty($Path)) {
        $Path = $File.Name
    }
    else {
        $Item = Get-FtpItem -Conn $Conn -Path $Path
        if ($Item.dir) {
            $Path = Add-FtpUrlPath -Url $Path -SubUrl $File.Name
        }
    }
    
    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::UploadFile)
    $Request.UseBinary = $true
    $Request.UsePassive = $true

	$File = [IO.File]::OpenRead((Convert-Path $LocalPath) )
	$Response = $Request.GetRequestStream()
    if (-not $Response.CanWrite) {
        throw 'Can''t write to ftp'
    }
    [Byte[]]$Buffer = New-Object Byte[] $Conn.BufferSize
						
	$ReadedData = 0
	$AllReadedData = 0
	$TotalData = (Get-Item $LocalPath).Length
												
	do {
        $ReadedData = $File.Read($Buffer, 0, $Buffer.Length)
        $Response.Write($Buffer, 0, $ReadedData);
    } while($ReadedData -gt 0)
			
	$File.Close()
    $Response.Close()
    $Response.Dispose()

    Get-FtpItem -Conn $Conn -Path $Path
}

function Receive-FtpFile($Conn, $Path, $LocalPath) {

    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::DownloadFile)
    $Request.UseBinary = $true
    $Request.KeepAlive = $false

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $ResponseStream = $Response.GetResponseStream()

    # Create the target file on the local system and the download buffer
    $LocalFile = New-Object IO.FileStream ($LocalPath, [IO.FileMode]::Create)

    [byte[]]$Buffer = New-Object byte[] $Conn.BufferSize

    $ReadLength = $ResponseStream.Read($ReadBuffer, 0, $Buffer.Length)
    while ($ReadLength -ne 0) {
        $LocalFile.Write($ReadBuffer, 0, $ReadLength)
        $ReadLength = $ResponseStream.Read($ReadBuffer, 0, $Buffer.Length)
    }
    $Response.Close()
    $Response.Dispose()

    $LocalFile.Close()

    Get-Item -Path $LocalPath
}

function Remove-FtpItem($Conn, $Path) {
    
    $Item = Get-FtpItem -Conn $Conn -Path $Path
    if ($Item -eq $null) {
        return $false
    }

    $Request = Get-FtpRequest -Conn $Conn -Path $Path

    if ($Item.Dir) {
        $Request.Method = [System.Net.WebRequestMethods+Ftp]::RemoveDirectory
    }
    else {
        $Request.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    }

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $Response.Close()
    $Response.Dispose()

    $true
}

function New-FtpDirectory($Conn, $Path) {
    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $Response.Close()
    $Response.Dispose()
    Get-FtpItem -Conn $Conn -Path $Path
}

function Test-FtpItem($Conn, $Path) {
    $Result = [bool]((Get-FtpItem -Conn $Conn -Path $Path) -ne $null)
    $Result
}

function Get-FtpItem($Conn, $Path) {

    $SplitUrl = Split-FtpUrl -Url $Path
    if ([string]::IsNullOrEmpty($SplitUrl.Child)) {
        $Child = $Path
        $SubPath = '/'
    }
    else {
        $Child = $SplitUrl.Child
        $SubPath = $SplitUrl.Parent
    }

    $Item = Get-FtpChildItems -Conn $Conn -Path $SubPath | Where-Object -FilterScript {$_.Name -Like $Child}
  
    if ($Item -ne $null -and $Item.Name -like $Child) {
        return $Item
    }
    else {
        return $null 
    }

}

function Get-FtpChildItems($Conn, $Path) {

    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails)

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
                Parent = $Path;
                FilePath = (Add-FtpUrlPath -Url $Path -SubUrl $Matches.name)
            }
            $FtpItems += $Item
        }
        $Line = $Stream.ReadLine()
    }

    $Response.Close()
    $Response.Dispose()

    $FtpItems
}

function Get-FtpRequest($Conn, $Path, $Method) {
    
    $Proto = ''
    if ($Conn.IsSecure) {
        $Proto = 'ftps://'
    }
    else {
        $Proto = 'ftp://'
    }

    $Url = Join-FtpUrlPaths -Paths @($Proto, $Conn.Srv, $Conn.RootPath, $Path)

    $FtpRequest = [System.Net.FtpWebRequest]::Create($Url)
    $FtpRequest.Credentials = New-Object System.Net.NetworkCredential($Conn.Usr, $Conn.Pwd)
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
    if ([string]::IsNullOrEmpty($Url)) {
        $Url = $SubUrl
    }
    elseif ($Url.EndsWith($Sep) -xor $SubUrl.StartsWith($Sep)) {
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
