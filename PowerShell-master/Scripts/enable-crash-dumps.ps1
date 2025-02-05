<#
.SYNOPSIS
	Enables the writing of crash dumps
.DESCRIPTION
	This PowerShell script enables the writing of crash dumps.
.EXAMPLE
	PS> ./enable-crash-dumps.ps1
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz | License: CC0
#>

##################################################################
#                                                                #
# Written by: Ryan Waters                                        #
#                                                                #
# Program: Get-Dump.ps1                                          #
# Date: 2-06-2020                                                #
# Purpose: To set registry keys to gather a WER Usermode Dump    #
#          and be able to change from a custom, mini, or FULL    #
#          Dumps for ease of use for customers and others.       #
#                                                                #
# EULA: Code is free to use for all, and free to distribute      #
#       I just ask that you leave the credit information and     #
#       this EULA and Comment Section in tact and do not delete. #
#                                                                #
# Bitwise Values:  (For reference)                               #
#                                                                #
# 0x00000000 -  MiniDumpNormal                                   #
# 0x00000001 -  MiniDumpWithDataSegs                             #
# 0x00000002 -  MiniDumpWithFullMemory                           #
# 0x00000004 -  MiniDumpWithHandleData                           #
# 0x00000008 -  MiniDumpFilterMemory                             #
# 0x00000010 -  MiniDumpScanMemory                               #
# 0x00000020 -  MiniDumpWithUnloadedModules                      #
# 0x00000040 -  MiniDumpWithIndirectlyReferenced                 #
# 0x00000080 -  MemoryMiniDumpFilterModulePaths                  #
# 0x00000100 -  MiniDumpWithProcessThreadData                    #
# 0x00000200 -  MiniDumpWithPrivateReadWriteMemory               #
# 0x00000400 -  MiniDumpWithoutOptionalData                      #
# 0x00000800 -  MiniDumpWithFullMemoryInfo                       #
# 0x00001000 -  MiniDumpWithThreadInfo                           #
# 0x00002000 -  MiniDumpWithCodeSegs                             #
# 0x00004000 -  MiniDumpWithoutAuxiliaryState                    #
# 0x00008000 -  MiniDumpWithFullAuxiliaryState                   #
# 0x00010000 -  MiniDumpWithPrivateWriteCopyMemory               #
# 0x00020000 -  MiniDumpIgnoreInaccessibleMemory                 #
# 0x00040000 -  MiniDumpWithTokenInformation                     #
#                                                                #
##################################################################

#Setting Values:
$MDN = '0'
$MDWDS = '1'
$MDWFM = '2'
$MDWHD = '4'
$MDFM = '8'
$MDSM = '10'
$MDWUM = '20'
$MDWIR = '40'
$MMDFMP = '80'
$MDWPTD = '100'
$MDWPRWM = '200'
$MDWOD = '400'
$MDWFMI = '800'
$MDWTI = '1000'
$MDWCS = '2000'
$MDWAS = '4000'
$MDWFAS = '8000'
$MDWPWCM = '10000'
$MDIIM = '20000'
$MDWTOI = '40000'

$a = $MDN
$b = $MDWDS
$c = $MDWFM
$d = $MDWHD
$e = $MDFM
$f = $MDSM
$g = $MDWUM
$h = $MDWIR
$i = $MMDFMP
$j = $MDWPTD
$k = $MDWPRWM
$l = $MDWOD
$m = $MDWFMI
$n = $MDWTI
$o = $MDWCS
$p = $MDWAS
$q = $MDWFAS
$r = $MDWPWCM
$s = $MDIIM
$t = $MDWTOI

$0x = 

$array = @()

Clear-Host
Write-Host 
Start-Sleep -seconds 3


New-ItemProperty -Path  -Name  -Value  -PropertyType ExpandString -Force
New-ItemProperty -Path  -Name  -Value  -PropertyType DWORD -Force

clear-host
Write-Host 
Write-Host 
write-host 
$NCD = Read-Host 

If ($NCD -eq '3')
{
    
    New-ItemProperty -Path  -Name  -Value  -PropertyType DWORD -Force
    Do
    {
        clear-host
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        Write-Host 
        write-host 
        $Option = Read-Host 
        if($Option -eq '1')
        {
            $array += [int]$a
        }
        ElseIf($Option -eq '2')
        {
            $array += [int]$b
        }
        ElseIf($Option -eq '3')
        {
            $array += [int]$c
        }
        ElseIf($Option -eq '4')
        {
            $array += [int]$d
        }
        ElseIf($Option -eq '5')
        {
            $array += [int]$e
        }
        ElseIf($Option -eq '6')
        {
            $array += [int]$f
        }
        ElseIf($Option -eq '7')
        {
            $array += [int]$g
        }
        ElseIf($Option -eq '8')
        {
            $array += [int]$h
        }
        ElseIf($Option -eq '9')
        {
            $array += [int]$i
        }
        ElseIf($Option -eq '10')
        {
            $array += [int]$j
        }
        ElseIf($Option -eq '11')
        {
        $array += [int]$k
        }
        ElseIf($Option -eq '12')
        {
            $array += [int]$l
        }
        ElseIf($Option -eq '13')
        {
            $array += [int]$m
        }
        ElseIf($Option -eq '14')
        {
            $array += [int]$n
        }
        ElseIf($Option -eq '15')
        {
            $array += [int]$o
        }
        ElseIf($Option -eq '16')
        {
            $array += [int]$p
        }
        ElseIf($Option -eq '17')
        {
            $array += [int]$q
        } 
        ElseIf($Option -eq '18')
        {
            $array += [int]$r
        } 
        ElseIf($Option -eq '19')
        {
            $array += [int]$s
        } 
        ElseIf($Option -eq '20')
        {
            $array += [int]$t
        }
        ElseIf($Option -eq 'q')
        {
            write-host 
            Start-Sleep -seconds 2
        }
        Else
        {
            write-host 
            Start-Sleep -seconds 2
        }  
                                               
    }
    While($Option -ne )
    $sum = $array -join '+'
    $SumArray = Invoke-Expression $sum
    $FinalSum = $0x + $SumArray

    New-ItemProperty -Path  -Name  -Value  -PropertyType DWORD -Force

    Write-Host 
}
ElseIf ($NCD -eq '0')
{
    Remove-ItemProperty -Path  -Name  -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path  -Name  -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path  -Name  -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path  -Name  -Force -ErrorAction SilentlyContinue
    write-host 
    $reboot = read-host 
    if($reboot -eq  -or $reboot -eq  -or $reboot -eq  -or $reboot -eq )
    {
        shutdown -r
    }
    Else
    {
        write-host 
    }
}
ElseIf ($NCD -eq '1')
{
    New-ItemProperty -Path  -Name  -Value  -PropertyType DWORD -Force
    Write-Host 
    if($reboot -eq  -or $reboot -eq  -or $reboot -eq  -or $reboot -eq )
    {
        shutdown -r
    }
    Else
    {
        write-host 
    }
}
ElseIf ($NCD -eq '2')
{
    New-ItemProperty -Path  -Name  -Value  -PropertyType DWORD -Force
    Write-Host 
    if($reboot -eq  -or $reboot -eq  -or $reboot -eq  -or $reboot -eq )
    {
        shutdown -r
    }
    Else
    {
        write-host 
    }
}
Else
{
    Write-Host 
    Start-Sleep -seconds 5
}
exit 0 # success
