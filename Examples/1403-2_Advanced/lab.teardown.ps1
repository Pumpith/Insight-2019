Get-NcNetInterface iscsi* | %{ Set-NcNetInterface -Name $_.InterfaceName -Vserver $_.Vserver -AdministrativeStatus down  | Remove-NcNetInterface -Confirm:$false }