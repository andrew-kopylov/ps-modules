Import-Module C:\scripts\modules\7z-module.ps1 -Force

$srvinfo = 'C:\Program Files\1cv8\srvinfo'
$destdir = 'C:\archive\1cv8logs-lgd'
$notexistdir = 'C:\archive\srvinfo-ib-notexist'

$ArrayRegDir = Get-ChildItem -Path $srvinfo -Directory -Filter 'reg_*'

foreach ($RegDir in $ArrayRegDir) {
 
    $ClusterInfo = Get-Content -Path ($RegDir.FullName + '\1CV8Clst.lst') 

    $ArrayIBDir = Get-ChildItem -Path $RegDir.FullName -Filter '????????-????-????-????-????????????'
    foreach ($IBDir in $ArrayIBDir) {
        
        $Pattern = $IBDir.Name + ',"(?<base>\w+)"'

        $BaseName = ''
        foreach ($StrClusterInfo in $ClusterInfo) {
            if ($StrClusterInfo -match $Pattern) {
                $BaseName = $Matches.base
                break
            }
        }        

        $IBExist = ($BaseName -ne '')

        if ($IBExist) {

            $ArrayLogFiles = Get-ChildItem -Path $IBDir.FullName -Filter '1cv8.lgd' -File -Recurse 
            foreach ($LogFile in $ArrayLogFiles) {
            
                $DestArchiveDir = $destdir + '\' + $RegDir + '\' + $BaseName + '_' + $IBDir
                
                if (-not (Test-Path -Path $DestArchiveDir)) {
                    New-Item -Path $DestArchiveDir -ItemType Directory -Force
                }

                if (-not (Test-Path -Path $DestArchiveDir)) {
                    continue
                }           

                $DestArchive = $DestArchiveDir + '\1cv8-lgd.7z'
                $Result = Compress-7zArchive -Path $LogFile.FullName -DestinationPath $DestArchive
                if ($Result.ExitCode -eq 0 -and (Test-Path -Path $DestArchive)) {
                    Remove-Item -Path $LogFile.FullName -Force
                    $NewLogFile = $LogFile.DirectoryName + '\' + $LogFile.BaseName + '.lgf'
                    '' | Out-File -FilePath $NewLogFile
                }
                else {
                    'Bad archive: ' + $Result.Cmd
                }

            }


        }
        else {

            $DestArchive = $notexistdir + '\' + $IBDir.Name + '.7z'
            $Result = Compress-7zArchive -Path $IBDir.FullName -DestinationPath $DestArchive
            if ($Result.ExitCode -eq 0 -and (Test-Path -Path $DestArchive)) {
                Remove-Item -Path $IBDir.FullName -Force -Recurse
            }
            else {
                'Bad archive: ' + $Result.Cmd
            }

        }

         
    }
}