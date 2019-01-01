$ErrorActionPreference = "Stop"
$LocateMSBuild = $true
if (Get-Command msbuild -ErrorAction SilentlyContinue)
{
    $MSBuildVersion = [Version](msbuild /nologo /version)
    $LocateMSBuild = $MSBuildVersion.Major -lt 15
    if (!$LocateMSBuild)
    {
        $MSBuild = "msbuild"
    }
}

if ($LocateMSBuild)
{
    $MSBuildHome = @("Enterprise", "Professional", "BuildTools", "Community") |ForEach-Object {
        "C:\Program Files (x86)\Microsoft Visual Studio\2017\$_\MSBuild\15.0"
    } |Where-Object { Test-Path "$_\bin\msbuild.exe" } | Select-Object -First 1

    if (!$MSBuildHome)
    {
        throw "Failed to locate msbuild 15"
    }

    $MSBuild = "$MSBuildHome\bin\msbuild.exe"
}

$Properties = @{
    SourceRevisionId = $(git rev-parse --short HEAD)
    RepositoryUrl = $(git remote get-url origin)
}

$MSBuildProperties = $Properties.GetEnumerator() | Where-Object { 
    $_.Value
} | ForEach-Object { 
    "/p:{0}={1}" -f $_.Key,$_.Value 
}

Write-Host "Building ..."
&$MSBuild /restore /v:q /nologo /nr:false $MSBuildProperties
if ($LastExitCode)
{
    exit $LastExitCode
}

Write-Host "Packing ..."
Remove-Item src\bin\Debug\*nupkg -ErrorAction SilentlyContinue
&$MSBuild /v:q /nologo /nr:false $MSBuildProperties /t:pack
if ($LastExitCode)
{
    exit $LastExitCode
}

$Dll = "src\bin\Debug\netstandard2\PackVersionTest.dll"
$VersionInfo = (Get-Item $Dll).VersionInfo
"Dll Product Version = $($VersionInfo.ProductVersion)"

$Nuspec = "src\obj\Debug\PackVersionTest.1.2.3.4.nuspec"
$Pattern = '.*<version>(.+)</version>'
$NuspecVersion = (Select-String -path $Nuspec -Pattern $Pattern) -replace $Pattern,'$1'
"Nuspec Version = $NuspecVersion"
