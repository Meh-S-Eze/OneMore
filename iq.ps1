<#
.SYNOPSIS
Installation qualification
#>

param (
    [switch] $Registry = $true
)

Begin
{
    $script:guid = '{88AB88AB-CDFB-4C68-9C3A-F10B75A5BC61}'

    function HasKey
    {
        param($kpath)
        if (-not (Test-Path $kpath))
        {
            write-Host "key not found: $kpath" -Fore Red
            return $false
        }
        return $true
    }

    function HasProperty
    {
        param($kpath, $name)
        $ok = (Get-ItemProperty $kpath).PSObject.Properties.Name -contains $name
        if (-not $ok)
        {
            write-Host "property not found: $kpath\$name" -Fore Red
            return $false
        }
        return $true
    }

    function HasValue
    {
        param($kpath, $name, $value, [switch] $match)
        if (-not (HasProperty $kpath $name))
        {
            return $false
        }
        $script:lastValue = (Get-ItemPropertyValue -Path $kpath -Name $name)
        if ($value.Contains('*'))
        {
            if (-not ($lastValue -like $value))
            {
                Write-Host "invalid value: $kpath\$name, '$lastValue' <> '$value'" -Fore Red
                return $false
            }
        }
        elseif ($lastValue -ne $value)
        {
            if ($match) {
                Write-Host "mismatch $kpath\$name, '$lastValue' <> '$value'" -Fore Yellow
            }
            else {
                Write-Host "invalid value: $kpath\$name, '$lastValue' <> '$value'" -Fore Red
            }
            return $false
        }
        return $true
    }
    
    function GetVersions
    {
        $0 = "Registry::HKEY_CLASSES_ROOT\Excel.Application\CurVer"
        if (-not (HasKey $0)) {
            write-Host "cannot determine version of Office"
        } else {
            $parts = (Get-ItemPropertyValue -Path $0 -Name '(default)').Split('.')
            $script:offVersion = $parts[$parts.Length - 1] + ".0"
            Write-Host "OK Office version is $offVersion"
        }

        $0 = "Registry::HKEY_CLASSES_ROOT\OneNote.Application\CurVer"
        if (-not (HasKey $0)) {
            write-Host "cannot determine version of OneNote"
        } else {
            $parts = (Get-ItemPropertyValue -Path $0 -Name '(default)').Split('.')
            $script:oneVersion = $parts[$parts.Length - 1] + ".0"
            Write-Host "OK OneNote version is $oneVersion"
        }
    }

    function CheckAppID
    {
        $0 = "Registry::HKEY_CLASSES_ROOT\AppID\$guid"
        $ok = (HasKey $0)
        if ($ok) { $ok = (HasValue $0 'DllSurrogate' '') }
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }
    }

    function CheckRoot
    {
        $0 = "Registry::HKEY_CLASSES_ROOT\onemore"
        $ok = (HasKey $0)
        if ($ok) {
            $ok = (HasValue $0 '(default)' 'URL:OneMore Protocol Handler') -and $ok
            $ok = (HasValue $0 'URL Protocol' '') -and $ok
        }
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }
    }

    function CheckShell
    {
        # this also covers the virtual node LOCAL_MACHINE\SOFTWARE\Classes\onemore\shell\open\command
        $0 = "Registry::HKEY_CLASSES_ROOT\onemore\shell\open\command"
        $ok = (HasKey $0)
        if ($ok) { $ok = (HasValue $0 '(default)' '*\OneMoreProtocolHandler.exe %1 %2 %3 %4 %5') }
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }
    }

    function CheckAddIn
    {
        $0 = "Registry::HKEY_CLASSES_ROOT\River.OneMoreAddIn"
        $ok = (HasKey $0)
        if ($ok) {
            $ok = (HasValue $0 '(default)' 'River.OneMoreAddIn.AddIn') -and $ok
            $1 = "$0\CLSID"
            $ok = (HasValue $1 '(default)' $guid) -and $ok
            $1 = "$0\CurVer"
            $ok = (HasValue $1 '(default)' 'River.OneMoreAddIn.1') -and $ok
        }
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }

        $0 = "Registry::HKEY_CLASSES_ROOT\River.OneMoreAddIn.1"
        $ok = (HasValue $0 '(default)' 'Addin class')
        $1 = "$0\CLSID"
        $ok = (HasValue $1 '(default)' $guid) -and $ok
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }
    }

    function CheckCLSID
    {
        $0 = "Registry::HKEY_CLASSES_ROOT\CLSID\$guid"
        $ok = (HasKey $0)
        if ($ok) {
            $ok = (HasValue $0 '(default)' 'River.OneMoreAddIn.AddIn')
            $ok = (HasValue $0 'AppID' $guid) -and $ok
        }
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }

        $1 = "$0\Implemented Categories\{62C8FE65-4EBB-45E7-B440-6E39B2CDBF29}"
        $ver = $null
        $ok = (HasKey $0)
        if ($ok) {
            $1 = "$0\InprocServer32"
            $ok = (HasKey $1)
            if ($ok) {
                $ok = (HasValue $1 '(default)' 'mscoree.dll')
                $ok = (HasValue $1 'ThreadingModel' 'Both') -and $ok
                
                $ok = (HasValue $1 'CodeBase' '*\River.OneMoreAddIn.dll') -and $ok
                if ($ok) { $script:codeBase = $lastValue }

                $oo = (HasValue $1 'Class' 'River.OneMoreAddIn.AddIn')
                if ($oo) { $script:class = $lastValue }
                $ok = $oo -and $ok

                $oo = (HasValue $1 'RuntimeVersion' 'v*')
                if ($oo) { $script:runtimeVersion = $lastValue }
                $ok = $oo -and $ok

                $oo = (HasValue $1 'Assembly' 'River.OneMoreAddIn, Version=*')
                if ($oo) { $script:assembly = $lastValue }
                $ok = $oo -and $ok

                if ($oo)
                {
                    if ($assembly -match ',\sVersion=([0-9\.]+),\s')
                    {
                        $ver = $matches[1]
                    }
                }
            }
        }
        if ($ok) { Write-Host "OK $1" } else { Write-Host "BAD $1" }

        if ($ver)
        {
            $1 = "$0\InprocServer32\$ver"
            $ok = (HasValue $1 'Assembly' $assembly -match)
            $ok = (HasValue $1 'CodeBase' $codeBase -match) -and $ok
            $ok = (HasValue $1 'RuntimeVersion' $runtimeVersion -match) -and $ok
            $ok = (HasValue $1 'Class' $class -match) -and $ok
            if ($ok) { Write-Host "OK $1" } else { Write-Host "BAD $1" }
        }
        else
        {
            Write-Host "skipping $0\InprocServer32\<version>" -Fore Yellow
        }

        $1 = "$0\ProgID"
        $ok = (HasKey $1)
        if ($ok) { $ok = (HasValue $1 '(default)' 'River.OneMoreAddIn') }
        if ($ok) { Write-Host "OK $1" } else { Write-Host "BAD $1" }

        $1 = "$0\Programmable"
        $ok = (HasKey $1)
        if ($ok) { $ok = (HasValue $1 '(default)' '') }
        if ($ok) { Write-Host "OK $1" } else { Write-Host "BAD $1" }

        $1 = "$0\TypeLib"
        $ok = (HasKey $1)
        if ($ok) { $ok = (HasValue $1 '(default)' $guid) }
        if ($ok) { Write-Host "OK $1" } else { Write-Host "BAD $1" }

        $1 = "$0\VersionIndependentProgID"
        $ok = (HasKey $1)
        if ($ok) { $ok = (HasValue $1 '(default)' 'River.OneMoreAddIn') }
        if ($ok) { Write-Host "OK $1" } else { Write-Host "BAD $1" }
    }

    function CheckUser
    {
        $0 = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\AppID\$guid"
        $ok = (HasKey $0)
        if ($ok) { $ok = (HasValue $0 'DllSurrogate' '') }
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }

        $0 = "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Office\OneNote\AddIns\River.OneMoreAddIn"
        $ok = (HasValue $0 'LoadBehavior' '3')
        $ok = (HasValue $0 'Description' 'Extension for OneNote') -and $ok
        $ok = (HasValue $0 'FriendlyName' 'OneMoreAddIn') -and $ok
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }

        $0 = "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\River.OneMoreAddIn.dll"
        $ok = (HasValue $0 'Path' $codeBase -match)
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }

        $0 = "Registry::HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Office\$offVersion\Common\Security\Trusted Protocols\All Applications\onemore:"
        $ok = (HasKey $0)
        if ($ok) { Write-Host "OK $0" } else { Write-Host "BAD $0" -Fore Yellow }
    }
}
Process
{
    GetVersions
    CheckAppID
    CheckRoot
    CheckShell
    CheckAddIn
    CheckCLSID
    CheckUser
}
