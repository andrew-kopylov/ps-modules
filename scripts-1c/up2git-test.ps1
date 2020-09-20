

$Conn1C = Get-1CConn -File C:\Users\kopyl\Documents\1c-bases\test-upload-to-git-up2git `
    -CRPath C:\Users\kopyl\Documents\1c-rep\test-upload-to-git -CRUsr git

$ConnGit = Get-GitConn -Dir C:\Users\kopyl\Documents\git\1ccr-up2git-test

$DataDir = 'C:\Users\kopyl\Documents\1c-rep\test-upload-to-git-data'


Invoke-1CDevUploadRepositoryToGit -Conn1C $Conn1C -ConnGit $ConnGit -DataDir $DataDir -IssuePrefix RDV, TST -EMailDomain rdv-it.ru -LimitRunTimeHour 0.01 -PushRemote

