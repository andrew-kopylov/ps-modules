
# ftp-module: 1.0

function Get-FtpConn($Srv, $Usr, $Pwd, $RootPath, $IsSecure, $BufferSize = 64KB) {
    @{
        Srv = $Srv;
        Credentials = New-Object System.Net.NetworkCredential($Usr, $Pwd);
        RootPath = $RootPath;
        IsSecure = $IsSecure;
        BufferSize = $BufferSize
    }
}

function Rename-FtpFile($Conn, $Path, $NewName) {
    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::Rename)
    $Request.RenameTo = $NewName
	$Response = $Request.GetResponse()
	$Status = $Response.StatusDescription
	$Response.Close()
    return $Status
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

    $OK = $false
    if ($Response -ne $null) {
        $Response.Close()
        $Response.Dispose()
        $OK = $true
    }

    $OK
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
    $ResponseStream.Close()
    $Response.Close()
    $Response.Dispose()
    $LocalFile.Close()

    Get-Item -Path $LocalPath
}

function Remove-FtpItem($Conn, $Path, [switch]$CheckExistence) {
    
    if ($CheckExistence) {
        $Item = Get-FtpItem -Conn $Conn -Path $Path
        if ($Item -eq $null) {
            return $false
        }
    }

    $Request = Get-FtpRequest -Conn $Conn -Path $Path

    if ($Item.Dir) {
        $Request.Method = [System.Net.WebRequestMethods+Ftp]::RemoveDirectory
    }
    else {
        $Request.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    }

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()

    $OK = $false
    if ($Response -ne $null) {
        $Response.Close()
        $Response.Dispose()
        $OK = $true
    }

    $OK
}

function New-FtpDirectory($Conn, $Path, [switch]$Force, [switch]$CheckExistance) {

    if ([string]::IsNullOrEmpty($Path) -or ($Path -eq '/')) {
        return $null
    }

    if ($CheckExistance) {
        $FindedItem = Get-FtpItem -Conn $Conn -Path $Path
        if ($FindedItem -ne $null) {
            return $FindedItem
        }
    }

    if ($Force) {
        $FtpSplit = Split-FtpUrl -Url $Path
        if ($FtpSplit.Parent -gt '/') {
            if (-not (Test-FtpItem -Conn $Conn -Path $FtpSplit.Parent -Recurse:$true)) {
                $SubPath = New-FtpDirectory -Conn $Conn -Path $FtpSplit.Parent -Force:$true
            }
        }
    }

    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
    $Response = [System.Net.FtpWebResponse]$request.GetResponse()

    $OK = $false
    if ($Response -ne $null) {
        $Response.Close()
        $Response.Dispose()
        $OK = $true
    }
    
    $OK
}

function Test-FtpItem($Conn, $Path, [switch]$Recurse) {
    if ($Recurse) {
        $UrlSplit = Split-FtpUrl -Url $Path
        if ($UrlSplit.Parent -gt '/') {
            $Result = Test-FtpItem -Conn $Conn -Path $UrlSplit.Parent -Recurse:$true
            if (-not $Result) {
                return $false
            }
        }
    }
    $Result = [bool]((Get-FtpItem -Conn $Conn -Path $Path) -ne $null)
    $Result
}

function Get-FtpItem($Conn, $Path) {

    $SplitUrl = Split-FtpUrl -Url $Path
    $SubPath = $SplitUrl.Parent
    $Child = $SplitUrl.Child

    $Item = Get-FtpChildItem -Conn $Conn -Path $SubPath | Where-Object -FilterScript {$_.Name -Like $Child}
  
    if ($Item -ne $null -and $Item.Name -like $Child) {
        return $Item
    }
    else {
        return $null 
    }

}

function Get-FtpChildItem($Conn, $Path, [switch]$Recurse) {

    $Request = Get-FtpRequest -Conn $Conn -Path $Path -Method ([System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails)

    $Response = [System.Net.FtpWebResponse]$request.GetResponse()
    $Stream = New-Object System.IO.StreamReader($Response.GetResponseStream(), [System.Text.Encoding]::Default)

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
            $FileInfo = [System.IO.FileInfo]$Matches.name;
            $Item = New-Object PSCustomObject -Property @{
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
                BaseName = $FileInfo.BaseName;
                Extension = $FileInfo.Extension;
                Parent = $Path;
                Path = (Add-FtpUrlPath -Url $Path -SubUrl $Matches.name);
                FullName = (Join-FtpUrlPaths -Paths $Conn.RootPath, $Path, $Matches.name)
            }
            $FtpItems += $Item
        }
        $Line = $Stream.ReadLine()
    }

    $Stream.Close()
    $Response.Close()
    $Response.Dispose()

    if ($Recurse) {
        $SubDirs = $FtpItems.Where({$_.Dir})
        foreach ($DirItem in $SubDirs) {
            $SubPath = Add-PgPath -Path $Path -AddPath $DirItem.Name
            $SubItemList = Get-FtpChildItem -Conn $Conn -Path $SubPath -Recurse:$true
            foreach ($SubItem in $SubItemList) {
                $FtpItems += $SubItem
            }
        }
    }

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

    $Url = Join-FtpUrlPaths -Paths $Proto, $Conn.Srv, $Conn.RootPath, $Path

    $FtpRequest = [System.Net.FtpWebRequest]::Create($Url)
    $FtpRequest.Credentials = $Conn.Credentials
    if ($Method -ne $null) {
        $FtpRequest.Method = $Method
    }

    $FtpRequest

}

function Split-FtpUrl([string]$Url) {

    $Return = @{Parent = ''; Child = ''}

    if ($Url.EndsWith('/')) {
        $Url = $Url.Substring(0, $Url.Length -1)
    }

    $LastSep = $Url.LastIndexOf('/')
    if ($LastSep -eq -1) {
        $Return.Parent = '/'
        $Return.Child = $Url
    }
    else {
        $Return.Parent = $Url.Substring(0, $LastSep)
        $Return.Child = $Url.Substring($LastSep + 1)
    }

    if ([string]::IsNullOrEmpty($Return.Parent)) {
        $Return.Parent = '/'
    }

    $Return
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
        $Result = $SubUrl
    }
    elseif ([string]::IsNullOrEmpty($SubUrl)) {
        $Result = $Url
    }
    elseif ($Url.EndsWith($Sep) -xor $SubUrl.StartsWith($Sep)) {
        $Result = $Url + $SubUrl
    } 
    elseif (-not $SubUrl.StartsWith($Sep)) {
        $Result = $Url + $Sep + $SubUrl
    }
    else {
        $Result = $Url + $SubUrl.Substring(1)
    }
    $Result
}
