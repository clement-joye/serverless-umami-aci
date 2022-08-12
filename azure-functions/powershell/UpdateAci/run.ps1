using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "PowerShell HTTP trigger function processed a request."
Write-Host $Request.Url

$SubscriptionId = $env:SUBSCRIPTION_ID
$ResourceGroup = $env:RESOURCE_GROUP_NAME
$UmamiContainerGroup = $env:UMAMI_CONTAINER_GROUP_NAME
$UmamiDb = $env:UMAMI_DB_NAME
$UmamiUrl = $env:UMAMI_ACI_URL

$Action = $Request.Query.Action
$Instance = $Request.Query.Instance
$Code = $Request.Query.Code
$Html = Get-Content ".\UpdateAci\index.html" | Out-String

$BaseUrl = $Request.Url.Substring(0, $Request.Url.IndexOf("?")) 

$StatusRequest = $BaseUrl + "?action=status&code=$Code"

$UmamiStartRequest = $BaseUrl + "?action=start&code=$Code"
$UmamiStopRequest = $BaseUrl + "?action=stop&code=$Code"

if ($Action -eq "start" -Or $Action -eq "stop") {

    if ($Action -eq "start") {

        try {
            if ($Instance -eq "umami" -Or [string]::IsNullOrEmpty($Instance)) {
                
                Write-Host "Starting Az postgresql flexible server $UmamiContainerGroup."
                Start-AzPostgreSqlFlexibleServer -Name $UmamiDb -ResourceGroupName $ResourceGroup -SubscriptionId $SubscriptionId -NoWait
                Write-Host "Starting Az postgresql flexible server $UmamiContainerGroup done."

                Write-Host "Starting Az container group $UmamiContainerGroup."
                Start-AzContainerGroup -Name $UmamiContainerGroup -ResourceGroupName $ResourceGroup -SubscriptionId $SubscriptionId -NoWait
                Write-Host "Starting Az container group $UmamiContainerGroup done."
            }
        }
        catch { }
    }

    elseif ($Action -eq "stop") {

        try {
            if ($Instance -eq "umami" -Or [string]::IsNullOrEmpty($Instance)) {
                Write-Host "Stopping Az container group $UmamiContainerGroup."
                Stop-AzContainerGroup -Name $UmamiContainerGroup -ResourceGroupName $ResourceGroup -SubscriptionId $SubscriptionId
                Write-Host "Stopping Az container group $UmamiContainerGroup done."
                
                Write-Host "Stopping Az postgresql flexible server $UmamiContainerGroup."
                Stop-AzPostgreSqlFlexibleServer -Name $UmamiDb -ResourceGroupName $ResourceGroup -SubscriptionId $SubscriptionId -NoWait
                Write-Host "Stopping Az postgresql flexible server $UmamiContainerGroup done."
            }
        }
        catch { }
    }
    
    $Html = $Html.Replace("{{url}}", $StatusRequest)
    $Html = $Html.Replace("{{umamiUrl}}", $UmamiUrl)
    
    $Html = $Html.Replace("{{umamiStartUrl}}", $UmamiStartRequest)
    $Html = $Html.Replace("{{umamiStopUrl}}", $UmamiStopRequest)
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        headers = @{'content-type'='text/html'}
        Body = $Html
    })
}
elseif ($Action -eq "status") {

    $UmamiStatus = (Get-AzContainerGroup -ResourceGroupName $ResourceGroup -Name $UmamiContainerGroup).InstanceViewState
    Write-Host "Umami status: $UmamiStatus"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        headers = @{'content-type'='application/json'}
        Body = @{
            "umami" = $UmamiStatus
        } | ConvertTo-Json
    })
}
