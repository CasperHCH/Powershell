<#
.Synopsis
    Install PowerShell on Windows, Linux or macOS.
.DESCRIPTION
    By default, the latest PowerShell release package will be installed.
    If '-Daily' is specified, then the latest PowerShell daily package will be installed.
.Parameter Destination
    The destination path to install PowerShell to.
.Parameter Daily
    Install PowerShell from the daily build.
    Note that the 'PackageManagement' module is required to install a daily package.
.Parameter DoNotOverwrite
    Do not overwrite the destination folder if it already exists.
.Parameter AddToPath
    On Windows, add the absolute destination path to the 'User' scope environment variable 'Path';
    On Linux, make the symlink '/usr/bin/pwsh' points to ;
    On MacOS, make the symlink '/usr/local/bin/pwsh' points to .
.EXAMPLE
    Install the daily build
    .\install-powershell.ps1 -Daily
.EXAMPLE
    Invoke this script directly from GitHub
    Invoke-Expression 
#>
[CmdletBinding(DefaultParameterSetName = )]
param(
    [Parameter(ParameterSetName = )]
    [string] $Destination,

    [Parameter(ParameterSetName = )]
    [switch] $Daily,

    [Parameter(ParameterSetName = )]
    [switch] $DoNotOverwrite,

    [Parameter(ParameterSetName = )]
    [switch] $AddToPath,

    [Parameter(ParameterSetName = )]
    [switch] $UseMSI,

    [Parameter(ParameterSetName = )]
    [switch] $Quiet,

    [Parameter(ParameterSetName = )]
    [switch] $AddExplorerContextMenu,

    [Parameter(ParameterSetName = )]
    [switch] $EnablePSRemoting,

    [Parameter()]
    [switch] $Preview
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 

$IsLinuxEnv = (Get-Variable -Name  -ErrorAction Ignore) -and $IsLinux
$IsMacOSEnv = (Get-Variable -Name  -ErrorAction Ignore) -and $IsMacOS
$IsWinEnv = !$IsLinuxEnv -and !$IsMacOSEnv

if (-not $Destination) {
    if ($IsWinEnv) {
        $Destination = 
    } else {
        $Destination = 
    }

    if ($Daily) {
        $Destination = 
    }
}

$Destination = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)

if (-not $UseMSI) {
    Write-Host 
} else {
    if (-not $IsWinEnv) {
        throw 
    } else {
        $MSIArguments = @()
        if($AddExplorerContextMenu) {
            $MSIArguments += 
        }
        if($EnablePSRemoting) {
            $MSIArguments += 
        }
    }
}

# Expand an archive using Expand-archive when available
# and the DotNet API when it is not
function Expand-ArchiveInternal {
    [CmdletBinding()]
    param(
        $Path,
        $DestinationPath
    )

    if((Get-Command -Name Expand-Archive -ErrorAction Ignore))
    {
        Expand-Archive -Path $Path -DestinationPath $DestinationPath
    }
    else
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $resolvedDestinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DestinationPath)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedPath,$resolvedDestinationPath)
    }
}

function Remove-Destination([string] $Destination) {
    if (Test-Path -Path $Destination) {
        if ($DoNotOverwrite) {
            throw 
        }
        Write-Host  
        if (Test-Path -Path ) {
            Remove-Item  -Recurse -Force
        }
        if ($IsWinEnv -and ($Destination -eq $PSHOME)) {
            # handle the case where the updated folder is currently in use
            Get-ChildItem -Recurse -File -Path $PSHOME | ForEach-Object {
                if ($_.extension -eq ) {
                    Remove-Item $_
                } else {
                    Move-Item $_.fullname 
                }
            }
        } else {
            # Unix systems don't keep open file handles so you can just move files/folders even if in use
            Move-Item  
        }
    }
}

<#
.SYNOPSIS
    Validation for Add-PathTToSettingsToSettings.
.DESCRIPTION
    Validates that the parameter being validated:
    - is not null
    - is a folder and exists
    - and that it does not exist in settings where settings is:
        = the process PATH for Linux/OSX
        - the registry PATHs for Windows
#>
function Test-PathNotInSettings($Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Argument is null'
    }

    # Remove ending DirectorySeparatorChar for comparison purposes
    $Path = [System.Environment]::ExpandEnvironmentVariables($Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar));

    if (-not [System.IO.Directory]::Exists($Path)) {
        throw 
    }

    # [System.Environment]::GetEnvironmentVariable automatically expands all variables
    [System.Array] $InstalledPaths = @()
    if ([System.Environment]::OSVersion.Platform -eq ) {
        $InstalledPaths += @(([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)) -split ([System.IO.Path]::PathSeparator))
        $InstalledPaths += @(([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)) -split ([System.IO.Path]::PathSeparator))
    } else {
        $InstalledPaths += @(([System.Environment]::GetEnvironmentVariable('PATH'), [System.EnvironmentVariableTarget]::Process) -split ([System.IO.Path]::PathSeparator))
    }

    # Remove ending DirectorySeparatorChar in all items of array for comparison purposes
    $InstalledPaths = $InstalledPaths | ForEach-Object { $_.TrimEnd([System.IO.Path]::DirectorySeparatorChar) }

    # if $InstalledPaths is in setting return false
    if ($InstalledPaths -icontains $Path) {
        throw 'Already in PATH environment variable'
    }

    return $true
}

<#
.Synopsis
    Adds a Path to settings (Supports Windows Only)
.DESCRIPTION
    Adds the target path to the target registry.
.Parameter Path
    The path to add to the registry. It is validated with Test-PathNotInSettings which ensures that:
    -The path exists
    -Is a directory
    -Is not in the registry (HKCU or HKLM)
.Parameter Target
    The target hive to install the Path to.
    Must be either User or Machine
    Defaults to User
#>

function Add-PathTToSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-PathNotInSettings $_})]
        [string] $Path,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet([System.EnvironmentVariableTarget]::User, [System.EnvironmentVariableTarget]::Machine)]
        [System.EnvironmentVariableTarget] $Target = ([System.EnvironmentVariableTarget]::User)
    )

    if (-not $IsWinEnv) {
        return
    }

    if ($Target -eq [System.EnvironmentVariableTarget]::User) {
        [string] $Environment = 'Environment'
        [Microsoft.Win32.RegistryKey] $Key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Environment, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
    } else {
        [string] $Environment = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
        [Microsoft.Win32.RegistryKey] $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Environment, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
    }

    # $key is null here if it the user was unable to get ReadWriteSubTree access.
    if ($null -eq $Key) {
        throw (New-Object -TypeName 'System.Security.SecurityException' -ArgumentList )
    }

    # Get current unexpanded value
    [string] $CurrentUnexpandedValue = $Key.GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

    # Keep current PathValueKind if possible/appropriate
    try {
        [Microsoft.Win32.RegistryValueKind] $PathValueKind = $Key.GetValueKind('PATH')
    } catch {
        [Microsoft.Win32.RegistryValueKind] $PathValueKind = [Microsoft.Win32.RegistryValueKind]::ExpandString
    }

    # Evaluate new path
    $NewPathValue = [string]::Concat($CurrentUnexpandedValue.TrimEnd([System.IO.Path]::PathSeparator), [System.IO.Path]::PathSeparator, $Path)

    # Upgrade PathValueKind to [Microsoft.Win32.RegistryValueKind]::ExpandString if appropriate
    if ($NewPathValue.Contains('%')) { $PathValueKind = [Microsoft.Win32.RegistryValueKind]::ExpandString }

    $Key.SetValue(, $NewPathValue, $PathValueKind)
}

if ($IsLinux) {
    $Name = $PSVersionTable.OS
    if ($Name -like ) {
        if ([System.Environment]::Is64BitOperatingSystem) {
            $architecture = 
	} else {
            $architecture = 
	}
    } elseif ($Name -like ) {
        if ([System.Environment]::Is64BitOperatingSystem) {
            $architecture = 
	} else {
            $architecture = 
	}
    }
} elseif (-not $IsWinEnv) {
    $architecture = 
} elseif ($(Get-ComputerInfo -Property OsArchitecture).OsArchitecture -eq ) {
    $architecture = 
} else {
    switch ($env:PROCESSOR_ARCHITECTURE) {
         { $architecture =  }
         { $architecture =  }
        default { throw  }
    }
}
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue
try {
    # Setting Tls to 12 to prevent the Invoke-WebRequest : The request was
    # aborted: Could not create SSL/TLS secure channel. error.
    $originalValue = [Net.ServicePointManager]::SecurityProtocol
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if ($Daily) {
        $metadata = Invoke-RestMethod 'https://aka.ms/pwsh-buildinfo-daily'
        $release = $metadata.ReleaseTag -replace '^v'
        $blobName = $metadata.BlobName

        # Get version from currently installed PowerShell Daily if available.
        $pwshPath = if ($IsWinEnv) {Join-Path $Destination } else {Join-Path $Destination }
        $currentlyInstalledVersion = if(Test-Path $pwshPath) {
            ((& $pwshPath -version) -split )[1]
        }

        if($currentlyInstalledVersion -eq $release) {
            Write-Verbose  -Verbose
            return
        }

        if ($IsWinEnv) {
            if ($UseMSI) {
                $packageName = 
            } else {
                $packageName = 
            }
        } elseif ($IsLinuxEnv) {
            $packageName = 
        } elseif ($IsMacOSEnv) {
            $packageName = 
        }

        if ($architecture -ne ) {
            throw 
        }


        $downloadURL = 
        Write-Verbose  -Verbose

        $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
        if (!$PSVersionTable.ContainsKey('PSEdition') -or $PSVersionTable.PSEdition -eq ) {
            # On Windows PowerShell, progress can make the download significantly slower
            $oldProgressPreference = $ProgressPreference
            $ProgressPreference = 
        }

        try {
            Invoke-WebRequest -Uri $downloadURL -OutFile $packagePath
        } finally {
            if (!$PSVersionTable.ContainsKey('PSEdition') -or $PSVersionTable.PSEdition -eq ) {
                $ProgressPreference = $oldProgressPreference
            }
        }

        $contentPath = Join-Path -Path $tempDir -ChildPath 

        $null = New-Item -ItemType Directory -Path $contentPath -ErrorAction SilentlyContinue
        if ($IsWinEnv) {
            if ($UseMSI -and $Quiet) {
                Write-Verbose 
                $ArgumentList=@(, $packagePath, )
                if($MSIArguments) {
                    $ArgumentList+=$MSIArguments
                }
                $process = Start-Process msiexec -ArgumentList $ArgumentList -Wait -PassThru
                if ($process.exitcode -ne 0) {
                    throw 
                }
            } elseif ($UseMSI) {
                if($MSIArguments) {
                    Start-Process $packagePath -ArgumentList $MSIArguments -Wait
                } else {
                    Start-Process $packagePath -Wait
                }
            } else {
                Expand-ArchiveInternal -Path $packagePath -DestinationPath $contentPath
            }
        } else {
            tar zxf $packagePath -C $contentPath
        }
    } else {
        $metadata = Invoke-RestMethod https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/metadata.json
        if ($Preview) {
            $release = $metadata.PreviewReleaseTag -replace '^v'
        } else {
            $release = $metadata.ReleaseTag -replace '^v'
        }

        if ($IsWinEnv) {
            if ($UseMSI) {
                if ($architecture -eq ) {
                    $packageName = 
                } else {
                    $packageName = 
                }
            } else {
                $packageName = 
            }
        } elseif ($IsLinuxEnv) {
            $packageName = 
        } elseif ($IsMacOSEnv) {
            $packageName = 
        }

        $downloadURL = 
        Write-Host 

        $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
        if (!$PSVersionTable.ContainsKey('PSEdition') -or $PSVersionTable.PSEdition -eq ) {
            # On Windows PowerShell, progress can make the download significantly slower
            $oldProgressPreference = $ProgressPreference
            $ProgressPreference = 
        }

        try {
            Invoke-WebRequest -Uri $downloadURL -OutFile $packagePath
        } finally {
            if (!$PSVersionTable.ContainsKey('PSEdition') -or $PSVersionTable.PSEdition -eq ) {
                $ProgressPreference = $oldProgressPreference
            }
        }

        $contentPath = Join-Path -Path $tempDir -ChildPath 

        $null = New-Item -ItemType Directory -Path $contentPath -ErrorAction SilentlyContinue
        if ($IsWinEnv) {
            if ($UseMSI -and $architecture -eq ) {
                Add-AppxPackage -Path $packagePath
            } elseif ($UseMSI -and $Quiet) {
                Write-Verbose 
                $ArgumentList=@(, $packagePath, )
                if($MSIArguments) {
                    $ArgumentList+=$MSIArguments
                }
                $process = Start-Process msiexec -ArgumentList $ArgumentList -Wait -PassThru
                if ($process.exitcode -ne 0) {
                    throw 
                }
            } elseif ($UseMSI) {
                if($MSIArguments) {
                    Start-Process $packagePath -ArgumentList $MSIArguments -Wait
                } else {
                    Start-Process $packagePath -Wait
                }
            } else {
                Expand-ArchiveInternal -Path $packagePath -DestinationPath $contentPath
            }
        } else {
            tar zxf $packagePath -C $contentPath
        }
    }

    if (-not $UseMSI) {
        Remove-Destination $Destination
        if (Test-Path $Destination) {
            Write-Verbose  -Verbose
            # only copy files as folders will already exist at $Destination
            Get-ChildItem -Recurse -Path  -File | ForEach-Object {
                $DestinationFilePath = Join-Path $Destination $_.fullname.replace($contentPath, )
                Copy-Item $_.fullname -Destination $DestinationFilePath
            }
        } else {
            $null = New-Item -Path (Split-Path -Path $Destination -Parent) -ItemType Directory -ErrorAction SilentlyContinue
            Move-Item -Path $contentPath -Destination $Destination
        }
    }

    ## Change the mode of 'pwsh' to 'rwxr-xr-x' to allow execution
    if (-not $IsWinEnv) { chmod 755 $Destination/pwsh }

    if ($AddToPath -and -not $UseMSI) {
        if ($IsWinEnv) {
            if ((-not ($Destination.StartsWith($ENV:USERPROFILE))) -and
                (-not ($Destination.StartsWith($ENV:APPDATA))) -and
                (-not ($Destination.StartsWith($env:LOCALAPPDATA)))) {
                $TargetRegistry = [System.EnvironmentVariableTarget]::Machine
                try {
                    Add-PathTToSettings -Path $Destination -Target $TargetRegistry
                } catch {
                    Write-Warning -Message 
                    $TargetRegistry = [System.EnvironmentVariableTarget]::User
                }
            } else {
                $TargetRegistry = [System.EnvironmentVariableTarget]::User
            }

            # If failed to install to machine wide path or path was not appropriate for machine wide path
            if ($TargetRegistry -eq [System.EnvironmentVariableTarget]::User) {
                try {
                    Add-PathTToSettings -Path $Destination -Target $TargetRegistry
                } catch {
                    Write-Warning -Message 
                }
            }
        } else {
            $targetPath = Join-Path -Path $Destination -ChildPath 
            if ($IsLinuxEnv) { $symlink =  } elseif ($IsMacOSEnv) { $symlink =  }
            $needNewSymlink = $true

            if (Test-Path -Path $symlink) {
                $linkItem = Get-Item -Path $symlink
                if ($linkItem.LinkType -ne ) {
                    Write-Warning 
                    $needNewSymlink = $false
                } elseif ($linkItem.Target -contains $targetPath) {
                    ## The link already points to the target
                    Write-Verbose  -Verbose
                    $needNewSymlink = $false
                }
            }

            if ($needNewSymlink) {
                $uid = id -u
                if ($uid -ne ) { $SUDO =  } else { $SUDO =  }

                Write-Verbose  -Verbose
                & $SUDO ln -fs $targetPath $symlink

                if ($LASTEXITCODE -ne 0) {
                    Write-Error 
                }
            }
        }

        ## Add to the current process 'Path' if the process is not 'pwsh'
        $runningProcessName = (Get-Process -Id $PID).ProcessName
        if ($runningProcessName -ne 'pwsh') {
            $env:Path = $Destination + [System.IO.Path]::PathSeparator + $env:Path
        }
    }

    if (-not $UseMSI) {
        Write-Host 
        if ($Destination -eq $PSHOME) {
            Write-Host  -ForegroundColor Magenta
        }
    }
} finally {
    # Restore original value
    [Net.ServicePointManager]::SecurityProtocol = $originalValue

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
	exit 0 # success
}
