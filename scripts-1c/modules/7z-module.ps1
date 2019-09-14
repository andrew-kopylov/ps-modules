function Compress-7zArchive {
    param (
        $Path, 
        $DestinationPath,
        [ValidateSet('Fastest', 'NoComression', 'Optimal', 'Ultra')]
        $CompressionLevel,
        [switch]$Recurse,
        $CompressionTreads = 0
    )

    $Arguments = @()

    foreach ($FileName in $Path) {
        $Arguments += $FileName
    }

    $SwitchesAfter = [ordered]@{}

    if ($Recurse) {
        $SwitchesAfter['r'] = $true
    }

    # Compression level
    if ($CompressionLevel -eq 'NoCompression') {
        $SwitchesAfter['mx0'] = $true  
    }
    elseif ($CompressionLevel -eq 'Fastest') {
        $SwitchesAfter['mx1'] = $true  
    }
    elseif ($CompressionLevel -eq 'Ultra') {
        $SwitchesAfter['mx9'] = $true  
    }

    # MultiTreading
    if ($CompressionTreads -gt 0) {
        $SwitchesAfter[('mmt' + $CompressionTreads)] = $true  
    }

    $Arguments += $SwitchesAfter

    Invoke-7z -Command Add -ArchiveBaseName $DestinationPath -Arguments $Arguments
}

function Invoke-7z {
    param (
        [ValidateSet('Add', 'Bench', 'Delete', 'Extract', 'Hash', 'List', 'Rename', 'Test', 'Update', 'ExtractFP')]
        [string]$Command,
        $Switches,
        [string]$ArchiveBaseName,
        $Arguments
    )

    $ArchiveDirectory = [System.IO.Path]::GetDirectoryName($ArchiveBaseName)
    $ArchiveFileName = [System.IO.Path]::GetFileName($ArchiveBaseName)

    $Commands = [ordered]@{
        Add = 'a';
        Bench = 'b';
        Delete = 'd';
        Extract = 'e';
        Hash = 'h';
        List = 'l';
        Rename = 'rn';
        Test = 't';
        Update = 'u';
        ExtractFP = 'x'; # eXtract with full paths
    }

    $ArgsStr = $Commands[$Command]
    $ArgsStr = $ArgsStr + (Get-7zSwitchesString -Switches $Switches)
    $ArgsStr = $ArgsStr + ' ' + $ArchiveFileName

    foreach ($Argument in $Arguments) {
        $ArgsStr = $ArgsStr + (Get-7zSwitchesString -Switches $Argument)
    }

    $File7z = $env:ProgramFiles + '\7-Zip\7z.exe'

    $Result = Start-Process -FilePath $File7z -ArgumentList $ArgsStr -NoNewWindow -Wait -WorkingDirectory $ArchiveDirectory

    $Result

}

function Get-7zSwitchesString($Switches) {
    $SwchStr = ''
    # Is HashTable or OrderedDictionary
    if ($Switches -is [hashtable] -or ($Switches -is [System.Object] -and $Switches.GetType().name -eq 'OrderedDictionary')) {
        foreach ($SwchKey in $Switches.Keys) {
            $SwchVal = $Switches[$SwchKey]
            if ($SwchVal -eq $null -or ($SwchVal -is [boolean] -and $SwchVal)) {
                $SwchStr = $SwchStr + ' -' + $SwchKey
            }
            else {
                $SwchStr = $SwchStr + ' -' + $SwchKey + $SwchVal
            }  
        }
    }
    else {
        $SwchStr = ' ' + [string]$Switches
    }
    $SwchStr
}
