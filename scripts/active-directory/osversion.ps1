Function Get-OperatingSystemVersion
{
 (Get-CimInstance -Class Win32_OperatingSystem).Version
} #end Get-OperatingSystemVersion
