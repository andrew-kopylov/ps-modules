Import-Module ..\modules\1c-module.ps1 -Force

$Conn = Get-1CConn -V8 '8.3.14.1565' -File 'D:\work\bases\update_by_cr\base2-fromdev'  -CRPath 'D:\work\bases\update_by_cr\cr-dev' -CRUsr 'fromdev'

$Log = Get-1CLog -Dir ($PSScriptRoot + '\logs')


Invoke-1CCRSetLable -Conn $Conn -v 5 -Lable 'ver 5' -LableComment 'Комментарий к версии хранилища 5 (ogogo) today'

#Invoke-1CCRSetLable -Conn $Conn -v 6 -Lable 'ver 6' -LableComment $Comment


#Invoke-1CCRCreate -Conn $Conn -Log $Log

#Invoke-1CCRAddUser -Conn $Conn -User 'NewUser' -Rights LockObjects -Log $Log
#Invoke-1CCRAddUser -Conn $Conn -User 'admin' -Rights Administration -Log $Log 