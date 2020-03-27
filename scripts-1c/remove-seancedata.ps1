Import-Module 1c-module -Force

# Старт скрпита с административными правами.
$WinUsr = [System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Winusr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell' -ArgumentList ('-f "' + $PSCommandPath + '"') -Verb RunAs
    break
}

# Остановка служб 1С
Stop-1CService

Start-Sleep -Seconds 1

# Удаление оставшихся процессов сервера 1С.
Get-Process | Where-Object -FilterScript {$_.Name -like 'rphost*'} | % {$_.Kill()}
Get-Process | Where-Object -FilterScript {$_.Name -like 'rmngr*'} | % {$_.Kill()}
Get-Process | Where-Object -FilterScript {$_.Name -like 'ragent*'} | % {$_.Kill()}

Start-Sleep -Seconds 1

# Удаление сеансовых данных.
Remove-Item -Path "C:\Program Files\1cv8\srvinfo\reg_*\snccntx*\*" -Force

# Запуск службы 1С
Start-1CService
