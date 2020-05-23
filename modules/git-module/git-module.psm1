Import-Module common-module

# Version 1.0

# GIT CONNECTION (DIRECTORY)

function Get-GitConn {
    param (
        $Dir,
        $Repository,
        $RefSpec
    )
    $Conn = @{
        Dir = $Dir;
        Repository = $Repository;
        RefSpec = $RefSpec;
    }
    $Conn
}

# INVOKE GIT COMMANDS

function Invoke-GitStatus {
    param (
        $Conn,
        [switch]$Short,
        [switch]$Branch,
        [switch]$ShowStash,
        [switch]$Porcelain,
        [switch]$Long,
        [switch]$Verbose,
        [switch]$UntrackedFiles
    )

    $ArgList = [ordered]@{
        short = $Short;
        branch = $Branch;
        show_stash = $ShowStash;
        porcelain = $Porcelain;
        long = $Long;
        verbose = $Verbose;
        untracked_files = $UntrackedFiles;
    }
    $ArgStr = Get-CmnArgsGNU -ArgList $ArgList

    Invoke-AuxGitCommand -Conn $Conn -Command Status -ArgStr $ArgStr
}

function Invoke-GitAdd {
    param (
        $Conn,
        [switch]$Verbose,
        [switch]$DryRun,
        [switch]$Force,
        [switch]$All,
        $PathSpec
    )
   $ArgList = [ordered]@{
        verbose = $Verbose;
        dry_run = $DryRun;
        force = $Force;
        all = $All;
    }
    $ArgStr = Get-CmnArgsGNU -ArgList $ArgList
    $ArgStr = Add-CmnArgValue -ArgStr $ArgStr -ArgValue $PathSpec

    Invoke-AuxGitCommand -Conn $Conn -Command Add -ArgStr $ArgStr
}

function Invoke-GitCommit {
    param (
        $Conn,
        [switch]$All,
        [switch]$Amend,
        [string]$Message,
        $File,
        $Author,
        $Mail
    )

    $FileIsTemp = $false

    if (-not [string]::IsNullOrEmpty($Message)) {    
        $File = $null
        if (([string]$Message).Split("`n").Count -gt 1) {
            $FileIsTemp = $true
            $Message = $Message.Replace("`r", '')
            $Message = $Message.Replace("`0", '')
            $File = [System.IO.Path]::GetTempFileName()
            $Message | Out-File -FilePath $File -Encoding utf8 -NoNewline
            $Message = $null
        }
    }

    $CommitAuthor = $null
    if (-not [string]::IsNullOrEmpty($Author)) {
        $CommitAuthor = $Author + ' <' + $Mail + '>'
    }

    $ArgList = [ordered]@{
        all = $All;
        amend = $Amend;
        message = $Message;
        file = $File;
        author = $CommitAuthor
    }
    $ArgStr = Get-CmnArgsGNU -ArgList $ArgList

    Invoke-AuxGitCommand -Conn $Conn -Command Commit -ArgStr $ArgStr    
}

function Invoke-GitPush {
    param (
        $Conn,
        [switch]$All,
        $Repository,
        [switch]$Force,
        [switch]$Delete,
        [switch]$Prune,
        [switch]$SetUpstream,
        [switch]$DryRun,
        [switch]$Verbose,
        $RefSpec
    )
    
    if (-not $Repository) {
        $Repository = $Conn.Repository
    }

    if (-not $RefSpec) {
        $RefSpec = $Conn.RefSpec
    }

    $ArgList = [ordered]@{
        all = $All;
        dry_run = $DryRun;
        force = $Force;
        delete = $Delete;
        prune = $Prune;
        verbose = $Verbose;
        set_upstream = $SetUpstream;
    }
    $ArgStr = Get-CmnArgsGNU -ArgList $ArgList

    if (-not [string]::IsNullOrEmpty($Repository)) {
        $ArgStr = Add-CmnArgValue -ArgStr $ArgStr -ArgValue $Repository
        $ArgStr = Add-CmnArgValue -ArgStr $ArgStr -ArgValue $RefSpec
    }

    Invoke-AuxGitCommand -Conn $Conn -Command Push -ArgStr $ArgStr
}

function Invoke-GitPull {
    param (
        $Conn,
        [switch]$All,
        $Repository,
        [switch]$Force,
        [switch]$Quiet,
        [switch]$Commit,
        [switch]$NoFastForward,
        $RefSpec
    )

    if (-not $Repository) {
        $Repository = $Conn.Repository
    }

    if (-not $RefSpec) {
        $RefSpec = $Conn.RefSpec
    }

    $ArgList = [ordered]@{
        all = $All;
        force = $Force;
        quiet = $Quiet;
        commit = $Commit;
        no_ff = $NoFastForward;
    }
    $ArgStr = Get-CmnArgsGNU -ArgList $ArgList

    if (-not [string]::IsNullOrEmpty($Repository)) {
        $ArgStr = Add-CmnArgValue -ArgStr $ArgStr -ArgValue $Repository
        $ArgStr = Add-CmnArgValue -ArgStr $ArgStr -ArgValue $RefSpec
    }

    Invoke-AuxGitCommand -Conn $Conn -Command Pull -ArgStr $ArgStr
}

# AUXILIUARY FUNCTIONS

function Invoke-AuxGitCommand {
    param (
        $Conn,
        [ValidateSet('Status', 'Add', 'Commit', 'Push', 'Pull')]
        $Command,
        $ArgStr
    )

    $FilePath = 'git'
    $Arguments = ([string]$Command).ToLower() + ' ' + $ArgStr

    $Result = Invoke-CmnCmd -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $Conn.Dir
    $Result.Arguments = $Arguments
    $Result.FilePath = $FilePath

    $Result
}

Export-ModuleMember -Function '*-Git*'

