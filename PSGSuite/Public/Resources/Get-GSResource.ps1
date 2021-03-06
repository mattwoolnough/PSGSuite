function Get-GSResource {
    <#
    .SYNOPSIS
    Gets Calendar Resources (Calendars, Buildings & Features supported)
    
    .DESCRIPTION
    Gets Calendar Resources (Calendars, Buildings & Features supported)
    
    .PARAMETER Id
    If Id is provided, gets the Resource by Id
    
    .PARAMETER Resource
    The Resource Type to List

    Available values are:
    * "Calendars": resource calendars (legacy and new - i.e. conference rooms)
    * "Buildings": new Building Resources (i.e. "Building A" or "North Campus")
    * "Features": new Feature Resources (i.e. "Video Conferencing" or "Projector")
    
    .PARAMETER Filter
    String query used to filter results. Should be of the form "field operator value" where field can be any of supported fields and operators can be any of supported operations. Operators include '=' for exact match and ':' for prefix match or HAS match where applicable. For prefix match, the value should always be followed by a *. Supported fields include generatedResourceName, name, buildingId, featureInstances.feature.name. For example buildingId=US-NYC-9TH AND featureInstances.feature.name:Phone.

    PowerShell filter syntax here is supported as "best effort". Please use Google's filter operators and syntax to ensure best results
    
    .PARAMETER OrderBy
    Field(s) to sort results by in either ascending or descending order. Supported fields include resourceId, resourceName, capacity, buildingId, and floorName.
    
    .PARAMETER PageSize
    Page size of the result set
    
    .EXAMPLE
    Get-GSResource -Resource Buildings

    Gets the full list of Buildings Resources
    #>
    [CmdletBinding(DefaultParameterSetName = "List")]
    Param
    (
        [parameter(Mandatory = $true,Position = 0,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true,ParameterSetName = "Get")]
        [String[]]
        $Id,
        [parameter(Mandatory = $false,Position = 1)]
        [ValidateSet('Calendars','Buildings','Features')]
        [String]
        $Resource = 'Calendars',
        [parameter(Mandatory = $false,ParameterSetName = "List")]
        [Alias('Query')]
        [String[]]
        $Filter,
        [parameter(Mandatory = $false,ParameterSetName = "List")]
        [String[]]
        $OrderBy,
        [parameter(Mandatory = $false,ParameterSetName = "List")]
        [ValidateRange(1,500)]
        [Alias("MaxResults")]
        [Int]
        $PageSize = "500"
    )
    Begin {
        if ($PSCmdlet.ParameterSetName -eq 'Get') {
            $serviceParams = @{
                Scope       = 'https://www.googleapis.com/auth/admin.directory.resource.calendar'
                ServiceType = 'Google.Apis.Admin.Directory.directory_v1.DirectoryService'
            }
            $service = New-GoogleService @serviceParams
        }
    }
    Process {
        switch ($PSCmdlet.ParameterSetName) {
            Get {
                foreach ($I in $Id) {
                    try {
                        Write-Verbose "Getting Resource $Resource Id '$I'"
                        $request = $service.Resources.$Resource.Get($(if($Script:PSGSuite.CustomerID){$Script:PSGSuite.CustomerID}else{'my_customer'}),$I)
                        $request.Execute() | Add-Member -MemberType NoteProperty -Name 'Id' -Value $I -PassThru | Add-Member -MemberType NoteProperty -Name 'Resource' -Value $Resource -PassThru | Add-Member -MemberType ScriptMethod -Name ToString -Value {$this.Id} -PassThru -Force
                    }
                    catch {
                        if ($ErrorActionPreference -eq 'Stop') {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                        else {
                            Write-Error $_
                        }
                    }
                }
            }
            List {
                Get-GSResourceListPrivate @PSBoundParameters
            }
        }
    }
}