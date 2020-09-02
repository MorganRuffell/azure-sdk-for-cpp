<#
.SYNOPSIS
Bumps up package versions after release

.PARAMETER RepoRoot
The root of the repo (defaults to ${PSScriptRoot}/..)

.PARAMETER ServiceDirectory
The service directory under <repo-root>/sdk/ used to find version.hpp

.PARAMETER PackageName
The package name under <repo-root>/sdk/<service-directory> used to find
version.hpp

.PARAMETER NewVersionString
New version string to use. Must follow SemVer conventions.

.DESCRIPTION
This script bumps up package versions following conventions defined at https://github.com/Azure/azure-sdk/blob/master/docs/policies/releases.md#incrementing-after-release-cpp


#>

[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    [string] $RepoRoot = "${PSScriptRoot}/..",
    [Parameter(Mandatory=$True)]
    [string] $ServiceDirectory,
    [Parameter(Mandatory=$True)]
    [string] $PackageName,
    [string] $NewVersionString
)

. ${PSScriptRoot}\common\scripts\SemVer.ps1
. ${PSScriptRoot}\scripts\SdkVersion-Common.ps1

# Updated Version in version file and changelog using computed or set NewVersionString
function Update-Version(
    [AzureEngSemanticVersion]$SemVer,
    $VersionHppLocation,
    $Unreleased=$True,
    $ReplaceVersion=$False)
{
    Write-Verbose "New Version: $SemVer"
    # Disabling because prerelease validation does not presently support 'beta'
    # if ($SemVer.HasValidPrereleaseLabel() -ne $true){
    #     Write-Error "Invalid prerelease label"
    #     exit 1
    # }

    Write-Host "Saving version.hpp file..."
    $versionHppContent = Get-Content $VersionHppLocation -Raw
    $newContent = $versionHppContent -replace $VersionRegex, "`${1}$($SemVer.Major)`${2}$($SemVer.Minor)`${3}$($SemVer.Patch)`${4}`"$($SemVer.PrereleaseLabel).$($SemVer.PrereleaseNumber)`""

    $newContent | Set-Content $VersionHppLocation

    # Set Version in ChangeLog file
    $ChangelogPath = Join-Path $RepoRoot "sdk" $ServiceDirectory $PackageName "CHANGELOG.md"
    & "${PSScriptRoot}/common/Update-Change-Log.ps1" `
        -Version $SemVer.ToString() `
        -ChangeLogPath $ChangelogPath `
        -Unreleased $Unreleased `
        -ReplaceVersion $ReplaceVersion
}

$versionHppLocation = Get-VersionHppLocaiton `
    -ServiceDirectory $ServiceDirectory `
    -PackageName $PackageName

Write-Host "VERSION: $versionHppLocation"

# Obtain Current Package Version
if ([System.String]::IsNullOrEmpty($NewVersionString))
{
    $PackageVersion = & $PSScriptRoot/scripts/Get-PkgVersion.ps1 `
        -ServiceDirectory $ServiceDirectory `
        -PackageName $PackageName

    $SemVer = [AzureEngSemanticVersion]::new($PackageVersion)
    Write-Verbose "Current Version: ${PackageVersion}"

    $SemVer.IncrementAndSetToPrerelease()

    # Hardcoding this until SemVer supports setting beta
    $SemVer.PrereleaseLabel = 'beta'

    Update-Version -SemVer $SemVer -VersionHppLocation $versionHppLocation
}
else
{
    # Use specified VersionString
    $SemVer = [AzureEngSemanticVersion]::new($NewVersionString)
    Update-Version `
        -SemVer $SemVer `
        -VersionHppPath $versionHppLocation `
        -Unreleased $False `
        -ReplaceVersion $True
}
