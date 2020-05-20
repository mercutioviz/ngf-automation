<#
.Synopsis
	Creates a new service object in the firewall or returns a suitable powershell object for use with New-BarracudaCGFFirewallRule to create an explicit object
.Description
    This function will create a new service object in either the Host Firewall or Forwarding Firewall or return a powershell object. It expects input of either the -entries or -references to create an object.
    -entries is hashtable that you can use Convert-BarracudaCGFServiceObject-ps1 to create from CSV.

.Example
	New-BarracudaCGFServiceObject -deviceName $dev_name -token $token -name "MyObject" -entries $array -Debug -Verbose 
    $object = New-BarracudaCGFServiceObject -name "MyObject" -entries $array 
.Notes
v0.1
#>

Function New-BarracudaCGFServiceObject {
[cmdletbinding()]
param(
#if no device details are provided a powershell object is created.
[Parameter(Mandatory=$true,
ValueFromPipelineByPropertyName=$true)]
[string]$deviceName,

[Parameter(Mandatory=$true,
ValueFromPipelineByPropertyName=$false)]
[string] $token,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string] $devicePort=8443,

#the below parameters define the ruleset to create the object in
[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$virtualServer,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$serviceName,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$range,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$cluster,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$box,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$false)]
[switch]$notHTTPs,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$false)]
[switch]$hostfirewall,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$false)]
[switch]$ccglobal,

# Below are the values that define the object

[Parameter(Mandatory=$true,
ValueFromPipelineByPropertyName=$true)]
[string]$name,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[array]$entries=@(),

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$false)]
[array] $references,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$comment,

[Parameter(Mandatory=$false,
ValueFromPipelineByPropertyName=$true)]
[string]$color

)

    <#

        if($range -or $cluster -or $ccglobal){
        #REST Path for CC
        $url = "http$($s)://$($deviceName):$($devicePort)/rest/cc/v1/config"
        
        if($range -and $cluster -and $serverName -and $serviceName){
        #Forwarding ruleset via CC for v7
            $url = $url + "/ranges/$($PSBoundParameters.("range"))/clusters/$($PSBoundParameters.("cluster"))/servers/$($PSBoundParameters.("serverName"))/services/$($PSBoundParameters.("serviceName"))"
        }elseif($range -and $cluster -and $box -and $serviceName){
        #Forwarding ruleset via CC for v8 
            $url = $url + "/ranges/$($PSBoundParameters.("range"))/clusters/$($PSBoundParameters.("cluster"))/boxes/$($PSBoundParameters.("box"))/service-container/$($PSBoundParameters.("serviceName"))"
        }elseif($range -and $cluster -and $box){
        #Host ruleset via CC for a box
            $url = $url + "/ranges/$($PSBoundParameters.("range"))/clusters/$($PSBoundParameters.("cluster"))/boxes/$($PSBoundParameters.("box"))"
        #}elseif($range -and $cluster -and $serviceName){
        #
        #    $url = $url + "/ranges/$($PSBoundParameters.("range"))/clusters/$($PSBoundParameters.("cluster"))/services/$($PSBoundParameters.("serviceName"))"
        }elseif($range -and $cluster){
        #Service objects for a cluster in CC
              $url = $url + "/ranges/$($PSBoundParameters.("range"))/clusters/$($PSBoundParameters.("cluster"))"
        }elseif($range){
        #Service objects for a Range in CC
            $url = $url + "/ranges/$($PSBoundParameters.("range"))"
        }
        elseif($ccglobal){
        #assume global
            $url = $url + "/global"
        }

        #Finishes the URL path.
        if($sharedfirewall){
             $url = $url + "/shared-firewall/$($PSBoundParameters.("sharedfirewall"))/objects/services"
        }else{
            $url = $url + "/firewall/objects/services"
        }

     
    }else{
    #Direct Firewall paths
        $url = "http$($s)://$($deviceName):$($devicePort)/rest/config/v1"
        if($serviceName -and $serverName){
        #v7 forwarding service objects
            $url = $url + "/servers/$($PSBoundParameters.("serverName"))/services/$($PSBoundParameters.("serviceName"))/firewall/objects/services"

        }elseif($serviceName){
        #v8 forwarding objects
            $url = $url + "/service-container/$($PSBoundParameters.("serviceName"))/firewall/objects/services"
        
        }elseif($fwdingfw){
            $url = $url + "/forwarding-firewall/objects/services"
        }else{
        #in the absence of any service or server info get the host ruleset
             $url = $url + "/box/firewall/objects/services"
        }
    }
    #>
    If ($PSBoundParameters['Debug']) {
        $DebugPreference = 'Continue'
    }

    Write-Debug "Provide PSBoundParameters" 

   #sets any default variables to parameters in $PSBoundParameters
    foreach($key in $MyInvocation.MyCommand.Parameters.Keys)
    {
        $value = Get-Variable $key -ValueOnly -EA SilentlyContinue
        if($value -and !$PSBoundParameters.ContainsKey($key)) {$PSBoundParameters[$key] = $value}
        Write-Debug "$($key) : $($value)"
    }

    
    $postParams = @{}
    $postParams.Add("name",$name)
    $postParams.Add("comments",$comments)


        #references need to be hashtables inside array
        ForEach($obj in $references){
            $entries = $entries += @{"references"=$obj}
        }
    
    $postParams.Add("entries",$entries)
    
    $data = ConvertTo-Json $postParams -Depth 99
    
    #Sets the token header
    $header = @{"X-API-Token" = "$token"}

    #Inserts the tail of the API path to the parameters 
    $PSBoundParameters["context"] = "objects/services"

    #builds the REST API path.
    $url = Set-RESTPath @PSBoundParameters

    #Write-Debug $postParams
    Write-Debug $url
    Write-Debug $data

    if(!$deviceName -and !$token){
        return $postParams

    }else{
        
            try{
                $results = Invoke-WebRequest -Uri $url -ContentType 'application/json' -Method POST -Headers $header -Body $data -UseBasicParsing
            }catch [System.Net.WebException] {
                    $results = [system.String]::Join(" ", ($_ | Get-ExceptionResponse))
                    Write-Error $results
                   
                }

    }

return $results
}