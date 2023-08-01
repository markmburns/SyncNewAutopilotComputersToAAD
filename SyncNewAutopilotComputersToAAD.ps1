# SyncNewAutoPilotComputersToAAD.ps1
#
# Version 1.3
#
# Alex Durrant, Steve Prentice, Mark Burns
#
# Triggers an ADDConnect Delta Sync if new objects are found to be have been created
# in the OU's in question, this is helpful with Hybrid AD joined devices via Autopilot
# and helps to avoid the 3rd authentication prompt.
#
# Only devices with a userCertificate attribute are synced, so this script only attempts
# to sync devices that have been created within the last 24 hours and have the attribute set,
# which is checked every 5 minutes via any changes in the object's Modified time.
#
# Install this as a scheduled task that runs every 5 minutes on your AADConnect server.
# Change the OU's to match your environment.

Import-Module ActiveDirectory

$time = [DateTime]::Now.AddMinutes(-5)
$computers = Get-ADComputer -Filter 'Modified -ge $time' -SearchBase "OU=Autopilot Hybrids,DC=mmbb,DC=local" -Properties Created, Modified, userCertificate

If ($computers -ne $null) {
    ForEach ($computer in $computers) {
        $diff = $computer.Modified.Subtract($computer.Created)
        If (($diff.TotalHours -le 24) -And ($computer.userCertificate)) {
            # The below adds to AD groups automatically if you want
            #Add-ADGroupMember -Identity "Some Intune Co-management Pilot Device Group" -Members $computer
            #Logging
            $dest = "$($env:ProgramData)\SyncNewAutopilotComputersToAAD"
            if (-not (Test-Path $dest))
            {
                mkdir $dest
            }
            Start-Transcript "$dest\SyncNewAutopilotComputersToAAD.log" -Append

            Write-Host "Valid computer found (<24hrs old, modified in the last 5 minutes, and has userCertificate): $computer"
            $syncComputers = "True"
        }
    }
    # Wait for 30 seconds to allow for some replication
    Start-Sleep -Seconds 30
}

If ($syncComputers -ne $null){
    Write-Host "Syncing computers"
    Try {
        $startAD = Start-ADSyncSyncCycle -PolicyType Delta
        Write-Host "Result:"$startAD.Result
    }
    Catch {
        Write-Host "Error starting sync"
        $ErrorMessage = $_.Exception.Message
        Write-Host "Error message: $ErrorMessage"
    }
    Stop-Transcript

}else{Write-Host "No new computers to sync"}
