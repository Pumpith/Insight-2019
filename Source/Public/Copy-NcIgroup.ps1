<#
    .SYNOPSIS
    This script will clone an igroup from 7g or cDOT and will facilitate the creation of an associated portset.
 
    .DESCRIPTION
    Use Get-NcIgroup or Get-NaIgroup to find the igroup that you would like to clone. This function will copy the contents of the object into a new igroup and will allow you to create a new portset for this igroup as well.

    .EXAMPLE
    Copy an igroup (vmware_rdm) from a 7-Mode controller (node01) onto a Clustered Data ONTAP cluster (cluster01). Create a new portset named newVM and add four ports to the portset (fc01,fc02,fc03,fc04). Finally show the progress with -verbose switch.
    PS > Get-NaIgroup vmware_rdm | Copy-NGEN-NcIgroup -NewName newVM -NewPortSetName newVM -NewPortSetPorts fc01,fc02,fc03,fc04 -Vserver vmwareSvm -Verbose

        Name            : newVM
        Type            : vmware
        Protocol        : fcp
        Portset         : newVM
        ALUA            : True
        ThrottleBorrow  : False
        ThrottleReserve : 0
        Partner         : True
        VSA             : False
        Initiators      : {10:00:00:90:fa:1c:45:2f, 10:00:00:90:fa:1c:79:2d, 10:00:00:90:fa:1c:79:55,
                        10:00:00:90:fa:1c:79:63...}
        Vserver         : vmwareSvm 
#>
function Copy-NcIgroup
{
    [CmdletBinding()]
    [OutputType( [DataONTAP.C.Types.Igroup.InitiatorGroupInfo], ParameterSetName = "NaOldPortset" )]
    [OutputType( [DataONTAP.C.Types.Igroup.InitiatorGroupInfo], ParameterSetName = "NaNewPortset" )]
    [OutputType( [DataONTAP.C.Types.Igroup.InitiatorGroupInfo], ParameterSetName = "NcOldPortset" )]
    [OutputType( [DataONTAP.C.Types.Igroup.InitiatorGroupInfo], ParameterSetName = "NcNewPortset" )]
    Param(
        #The object that comes from Get-NaIgroup
        [Parameter( ParameterSetName = 'NaOldPortset', Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True )]
        [Parameter( ParameterSetName = 'NaNewPortset', Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True )]
        [DataONTAP.Types.Lun.InitiatorGroupInfo]$NaIgroup
        ,
        #The object that comest from Get-NcIgroup
        [Parameter( ParameterSetName = 'NcOldPortset', Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True )]
        [Parameter( ParameterSetName = 'NcNewPortset', Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True )]
        [DataONTAP.C.Types.Igroup.InitiatorGroupInfo]$NcIgroup
        ,
        #The Name the igroup will be called on the cDOT system.
        [Parameter( ParameterSetName = 'NaOldPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NaNewPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NcOldPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NcNewPortset', Mandatory )]
        [String]$NewName
        ,
        #Map the Igroup to an existing PortSet
        [Parameter( ParameterSetName = 'NcOldPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NaOldPortset', Mandatory )]
        [String]$PortSet
        ,
        #The name of a new portset
        [Parameter( ParameterSetName = 'NcNewPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NaNewPortset', Mandatory )]
        [String]$NewPortSetName
        ,
        #The ports that you want to add to the new portset. e.g. fc01,fc02,fc03,fc04
        [Parameter( ParameterSetName = 'NcNewPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NaNewPortset', Mandatory )]
        [String[]]$NewPortSetPorts
        ,
        #The Name of the vserver where this igroup will be created on.
        [Parameter( ParameterSetName = 'NcOldPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NcNewPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NaOldPortset', Mandatory )]
        [Parameter( ParameterSetName = 'NaNewPortset', Mandatory )]
        [String]$Vserver
    )
    begin
    {
        if ( -not $global:CurrentNcController )
        {
            throw "You must be connected to a NetApp cluster in order for this script to work."
        }
        if ( $NaIgroup )
        {
            Write-Verbose "Using 7-Mode Igroup Properties"

            $Igroup = $NaIgroup
        }
        if ( $NcIgroup )
        {
            Write-Verbose "Using cDOT Igroup Properties"

            $Igroup = $NcIgroup
        }
        if ( $NewPortSetName )
        {
            try
            {
                Write-Verbose "Creating PortSet"

                Invoke-NcComaand -Script { New-NcPortset -Name $NewPortSetName -Protocol ( $Igroup.Protocol ) -VserverContext $Vserver -ErrorAction stop } | Out-Null

                $PortSet = $NewPortSetName

                Write-Verbose " - Adding ports"

                foreach ( $port in $NewPortSetPorts )
                {
                    Write-Verbose " - > $port"

                    Invoke-NcComaand -Script { Add-NcPortsetPort -Name $NewPortSetName -Port $Port -VserverContext $Vserver } | Out-Null
                }
            }
            catch
            {
                throw "There was an error during the creation of the Portset"
            }
        }
    }
    process
    {
        try
        {
            Write-Verbose "Creating Igroup"

            $newIgroupParam = @{
                Name           = $NewName
                Protocol       = ( $Igroup.Protocol ) 
                Type           = ( $Igroup.Type )
                VserverContext = $Vserver 
                ErrorAction    = 'Stop'
            }
            if ( $portset )
            {
                $newIgroupParam.Add( 'Portset', $PortSet )
            }
            Invoke-NcComaand -Script { New-NcIgroup @newIgroupParam } | Out-Null

            Write-Verbose " - Adding Initiators"

            foreach ( $initiator in $Igroup.Initiators.InitiatorName )
            {
                Write-Verbose " - > $initiator"
                
                Invoke-NcComaand -Script { Add-NcIgroupInitiator -Name $NewName -Initiator $initiator -VserverContext $Vserver } | Out-Null
            }
            Invoke-NcComaand -Script { Get-NcIgroup -Name $NewName }
        }
        catch
        {
            throw "There was an error during the creation of the igroup"
        }
    }
}