function Invoke-FastThread()
{
    [cmdletbinding()]
    Param
    (
        [Parameter(mandatory=$true)]
        [object[]]$objects,

        [Parameter(mandatory=$true)]
        [scriptblock]$scriptblock,

        [int]$maxThreads = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors * 2,
        [int]$maxThreadTimeSeconds = 300,
        [string]$threadPriority = "AboveNormal"

    )
    
    $variables = get-variable  | ? { @(
        "maxTHreadTimeSeconds"
        "threadPriority"
        "maxThreads"
        "`$_"
        "args"
        "args"
        "defaultVariableNames"
        "input"
        "MyInvocation"
        "PROFILE"
        "PSBoundParameters"
        "variables"
        "objects"
        "PSCmdlet"
        "scriptblock"
        "$"
        "?"
        "^"
        "ConfirmPreference"
        "ConsoleFileName"
        "DebugPreference"
        "Error"
        "ErrorActionPreference"
        "ErrorView"
        "ExecutionContext"
        "false"
        "FormatEnumerationLimit"
        "HOME"
        "Host"
        "InformationPreference"
        "MaximumAliasCount"
        "MaximumDriveCount"
        "MaximumErrorCount"
        "MaximumFunctionCount"
        "MaximumHistoryCount"
        "MaximumVariableCount"
        "NestedPromptLevel"
        "null"
        "OutputEncoding"
        "PID"
        "ProgressPreference"
        "PSCommandPath"
        "PSCulture"
        "PSDefaultParameterValues"
        "PSEdition"
        "PSEmailServer"
        "PSHOME"
        "PSScriptRoot"
        "PSSenderInfo"
        "PSSessionApplicationName"
        "PSSessionConfigurationName"
        "PSSessionOption"
        "PSUICulture"
        "PSVersionTable"
        "PWD"
        "ShellId"
        "StackTrace"
        "true"
        "VerbosePreference"
        "WarningPreference"
        "WhatIfPreference"
    ) -notcontains $_.name }

    $parameterString = "param(`$_)"

    if ($debug.IsPresent)
    {
        #Enable write-error stream
        $parameterScriptBlock = [Scriptblock]::Create("& {`r`n$parameterString`r`n$($($scriptblock.tostring()))`r`n}*>&1")
    }
    else {
        $parameterScriptBlock = [Scriptblock]::Create("`r`n$parameterString`r`n$($($scriptblock.tostring()))`r`n")
    }

    (Get-Process -Id $pid).priorityclass = $threadPriority

    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    gci function: | ? { -not $_.helpfile -and -not $_.source } | % {
        $InitialSessionState.Commands.Add(( New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $_.name, $_.Definition))
    }

    foreach ($variable in $variables) {
        $sessionStateVar = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $variable.name,$variable.value,$Null
        $initialSessionState.Variables.Add($sessionStateVar)
    }


    $pool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $initialSessionState, $host)
    $pool.ApartmentState = "MTA"
    $pool.Open()
    $Global:pool = $pool
    $runspaces = @()

    foreach ($object in $objects) {
        $runspace = [PowerShell]::Create()
        $null = $runspace.AddScript($parameterScriptBlock)
        $null = $runspace.AddArgument($object)

        $runspace.RunspacePool = $pool
        $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke(); StartTime = get-date }
    }

    $results = @()
    while ($runspaces | ? { $_.status }) {
        $completed = $runspaces | Where-Object { $_.Status.IsCompleted }
        $stillRunning = $runspaces | Where-Object { -not $_.Status.IsCompleted }
        $done = $runspaces | ? { -not $_.status }

        foreach ($runspace in $completed) {
            $results += $runspace.Pipe.EndInvoke($runspace.Status)
            $runspace.Status = $null
        }

        foreach ($runspace in $stillRunning) {
            if ($runspace.StartTime.AddSeconds($maxThreadTimeSeconds) -lt (get-date)) {
                Write-Warning "Killing thread for running too long"
                $runspace.Pipe.Dispose()
                $runspace.Status = $null

                start-sleep -Seconds 1
            }
        }

        write-host "[$($done.count)/$($runspaces.count)] jobs completed" -ForegroundColor green
        
        start-sleep -Seconds 1
    }

    $pool.Close()
    [system.gc]::Collect()

    write-host "[all jobs completed]" -ForegroundColor green

    return $results
}