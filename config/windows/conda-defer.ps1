# cli-setup -- activate conda base in the background (PowerShell 7, interactive sessions)
#
# The prompt appears immediately; `conda shell.powershell activate base` runs in a child process,
# and its result is applied the next time the command line is idle. Running `conda` yourself, or
# changing PATH / the environment meanwhile, cancels it. Check progress with: $CondaBaseStartup.Status
# Requires the Conda module (Invoke-Conda) to be loaded already. Keep this file ASCII-only.
param([ValidateRange(1, 300)][int]$TimeoutSeconds = 30)
& {
  param($startupTimeout)
  if ($global:CondaBaseStartup -and $global:CondaBaseStartup.Status -eq 'Pending') { return }

  $state = [pscustomobject]@{
    Status         = 'Pending'
    Started        = [Diagnostics.Stopwatch]::StartNew()
    Environment    = @{}
    Process        = [Diagnostics.Process]::new()
    Output         = $null
    Errors         = $null
    IdleSubscriber = $null
    ExitSubscriber = $null
    Cleanup        = $null
    TimeoutSeconds = $startupTimeout
  }
  foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
    $state.Environment[$entry.Key] = $entry.Value
  }
  $global:CondaBaseStartup = $state
  $state.Process.StartInfo.FileName = $env:CONDA_EXE
  $state.Process.StartInfo.Arguments = 'shell.powershell activate base'
  $state.Process.StartInfo.UseShellExecute = $false
  $state.Process.StartInfo.CreateNoWindow = $true
  $state.Process.StartInfo.RedirectStandardOutput = $true
  $state.Process.StartInfo.RedirectStandardError = $true
  $state.Process.StartInfo.WorkingDirectory = $env:_CONDA_ROOT

  $state.Cleanup = {
    $state = $global:CondaBaseStartup
    foreach ($subscriber in @($state.IdleSubscriber, $state.ExitSubscriber)) {
      if ($subscriber) { Unregister-Event -SubscriptionId $subscriber.SubscriptionId -Force }
    }
    if ((Get-Alias conda -ErrorAction SilentlyContinue).Definition -eq 'Invoke-CondaDuringStartup') {
      Set-Alias -Name conda -Value Invoke-Conda -Scope Global
    }
    Remove-Item Function:\Invoke-CondaDuringStartup -ErrorAction SilentlyContinue
    if ($state.Process) {
      try { if (-not $state.Process.HasExited) { $state.Process.Kill($true) } } catch {}
      $state.Process.Dispose()
    }
    $state.Started.Stop()
    $state.Process = $state.Output = $state.Errors = $null
    $state.IdleSubscriber = $state.ExitSubscriber = $state.Environment = $null
    $state.Cleanup = $null
  }

  try {
    $null = $state.Process.Start()
    $state.Output = $state.Process.StandardOutput.ReadToEndAsync()
    $state.Errors = $state.Process.StandardError.ReadToEndAsync()

    # An explicit conda command takes precedence over the automatic activation.
    Set-Item Function:\global:Invoke-CondaDuringStartup -Value {
      $state = $global:CondaBaseStartup
      $state.Status = 'Cancelled'
      & $state.Cleanup
      Conda\Invoke-Conda @args
    }
    Set-Alias -Name conda -Value Invoke-CondaDuringStartup -Scope Global

    $state.ExitSubscriber = $ExecutionContext.Events.SubscribeEvent(
      $null, $null, 'PowerShell.Exiting', $null, {
        $state = $global:CondaBaseStartup
        $state.Status = 'Cancelled'
        & $state.Cleanup
      }, $true, $false)

    $state.IdleSubscriber = $ExecutionContext.Events.SubscribeEvent(
      $null, $null, 'PowerShell.OnIdle', $null, {
        $state = $global:CondaBaseStartup
        if ($state.Status -ne 'Pending') { return }
        if ($state.Started.Elapsed.TotalSeconds -gt $state.TimeoutSeconds) {
          $state.Status = 'TimedOut'
          & $state.Cleanup
          Write-Warning 'Conda base startup timed out. Run: conda activate base'
          return
        }
        if (-not $state.Process.HasExited -or
            -not $state.Output.IsCompleted -or -not $state.Errors.IsCompleted) { return }

        try {
          if ($state.Process.ExitCode -ne 0) {
            throw "Conda exited with code $($state.Process.ExitCode): $($state.Errors.Result.Trim())"
          }
          $activation = $state.Output.Result
          $tokens = $parseErrors = $null
          $ast = [Management.Automation.Language.Parser]::ParseInput($activation, [ref]$tokens, [ref]$parseErrors)
          if ($parseErrors.Count -or [string]::IsNullOrWhiteSpace($activation)) {
            throw 'Conda returned an invalid activation script.'
          }
          # Don't overwrite changes made while the worker was running.
          $names = @('PATH', 'VIRTUAL_ENV', 'CONDA_PREFIX', 'CONDA_SHLVL')
          $names += $ast.FindAll({
              param($node)
              $node -is [Management.Automation.Language.VariableExpressionAst] -and
              $node.VariablePath.UserPath -like 'env:*'
            }, $true) | ForEach-Object { $_.VariablePath.UserPath.Substring(4) }
          foreach ($name in $names | Select-Object -Unique) {
            if ([Environment]::GetEnvironmentVariable($name) -cne $state.Environment[$name]) {
              $state.Status = 'Cancelled'
              return
            }
          }
          Invoke-Expression $activation
          $state.Status = 'Ready'
        } catch {
          $state.Status = 'Failed'
          Write-Warning "Conda base could not start: $_ Run: conda activate base"
        } finally {
          & $state.Cleanup
        }
        if ($state.Status -eq 'Ready') {
          # PSReadLine keeps the current input while redrawing the prompt.
          try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } catch {}
        }
      }, $true, $false)
  } catch {
    $state.Status = 'Failed'
    & $state.Cleanup
    Write-Warning "Conda background startup could not begin: $_ Run: conda activate base"
  }
} $TimeoutSeconds
