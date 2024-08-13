[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

# vars for logs
$fileoutputdate = (Get-Date -Format yyyy-MM-dd)
$logFile = ".\logs\RoleMappingSync_" + $fileoutputdate + ".txt"

function WriteLog {
    param($logMessage)
    $timestamp = (Get-Date -Format s)
    $logLine = "$timestamp : $logMessage"
    Write-Host $logMessage
    Add-Content $logFile -Value $logLine
}

$ADServer = "someADServer.your.domain"

$url = "https://your_elastic_url:port"
$apikey = "yourApiKey"
$endpoint = "_security/role_mapping"

$ADtoESMap = @{
    "AD Group Name" = "es_role_mapping"
}

WriteLog "Starting script."
Foreach ($ADGroup in $ADtoESMap.Keys) {
    $ESRoleMapping = $ADtoESMap[$ADGroup]
    $userList = New-Object -TypeName System.Collections.ArrayList 
    Get-ADGroupMember -Server $ADServer -Identity $ADGroup | ForEach-Object {
        $userList.Add($_.SamAccountName)
    }
    WriteLog "Got users."
    $jsonHash = (@{ "all" = @{ "field" = @{ "username" = $userList }}, @{"field" = @{ "realm.name" = "<auth_realm>" }} })
    WriteLog "Getting $ESRoleMapping."
    $body = ((( Invoke-WebRequest -Method Get -Uri $url/endpoint/$ESRoleMapping -Headers @{Authorization = "ApiKey $apiKey"}).Content | ConvertFrom-Json).$ESRoleMapping | ConvertTo-Json -Depth 10 -Compress)
    $body = $body -replace '{"all":\[(.+)\]}', $jsonHash
    WriteLog "Putting update to $ESRoleMapping."
    $res = Invoke-WebRequest -Method Get -Uri $url/endpoint/$ESRoleMapping -Headers @{Authorization = "ApiKey $apiKey"} -Body $body -ContentType "application/json"
    If ($res.StatusCode -eq 200) {
        WriteLog "Put successful."
    } else {
        WriteLog "Put unsuccessful. Stopping."
        Exit(1)
    }
} 
