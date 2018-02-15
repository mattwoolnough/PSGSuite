﻿# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
        $ProjectRoot = $ENV:BHProjectPath
        if(-not $ProjectRoot) {
            if ($pwd.Path -like "*ci*") {
                Set-Location ..
            }
            $ProjectRoot = $pwd.Path
        }

    $Timestamp = Get-Date -Uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'

    $Verbose = @{}
    if($ENV:BHCommitMessage -match "!verbose")
    {
        $Verbose = @{Verbose = $True}
    }
}

Task Default -Depends Init,Test,Build,Deploy

Task Init {
    $lines
    Install-Module Coveralls -Force
    Import-Module Coveralls -Force
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}

Task Test -Depends Init  {
    $lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile"

    # In Appveyor?  Upload our tests! #Abstract this into a function?
    If($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            "$ProjectRoot\$TestFile" )
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    if($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Test {
    $lines
    
    if ($ENV:BHBuildSystem -eq 'AppVeyor' -and $env:BHCommitMessage -match '!deploy' -and $env:BHBranchName -eq "master") {
        # Load the module, read the exported functions, update the psd1 FunctionsToExport
        Set-ModuleFunctions @Verbose

        $curVer = (Get-Module $env:BHProjectName).Version
        $nextGalVer = Get-NextPSGalleryVersion -Name $env:BHProjectName

        $versionToDeploy = if ($curVer -ge $nextGalVer) {
            Write-Host -ForegroundColor Green "Module version has been bumped to $curVer, using version from manifest"
            $curVer
        }
        elseif ($env:BHCommitMessage -match '!hotfix') {
            $nextGalVer
        }
        elseif ($env:BHCommitMessage -match '!minor') {
            [System.Version]("{0}.{1}.{2}" -f $nextGalVer.Major,([int]$nextGalVer.Minor + 1),0)
        }
        elseif ($env:BHCommitMessage -match '!minor') {
            [System.Version]("{0}.{1}.{2}" -f ([int]$nextGalVer.Major + 1),0,0)
        }
        else {
            $null
        }
        # Bump the module version
        if ($versionToDeploy) {        
            Write-Host -ForegroundColor Green "Module version to deploy: $versionToDeploy"
            Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value $versionToDeploy
        }
        $lines
    }
    else {
        Write-Host -ForegroundColor Magenta "Build system is not AppVeyor, commit message does not contain '!deploy' and/or branch is not 'master' -- skipping module update!"
    }
}

Task Deploy -Depends Build {
    $lines

    $Params = @{
        Path = $ProjectRoot
        Force = $true
        Recurse = $false # We keep psdeploy artifacts, avoid deploying those : )
    }
    Invoke-PSDeploy @Verbose @Params
}