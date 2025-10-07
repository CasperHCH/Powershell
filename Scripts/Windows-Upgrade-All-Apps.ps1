# Please read and acknowledge before using the software.

Write-Host "--------------------------------------------"
Write-Host "SOFTWARE DISCLAIMER: NO IMPLIED WARRANTY"
Write-Host "--------------------------------------------"

Write-Host "By using this software, you acknowledge and agree to the following terms:"
Write-Host ""

Write-Host "1. No Warranty: This software is provided 'as-is' and without any express or implied warranties, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose."
Write-Host ""

Write-Host "2. Use at Your Own Risk: The use of this software is at your own risk. The author(s) and contributors shall not be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including negligence or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage."
Write-Host ""

Write-Host "3. No Support: The author(s) of this software may not provide support, maintenance, updates, or enhancements for this software."
Write-Host ""

Write-Host "4. Compliance: It is your responsibility to ensure that your use of this software complies with all applicable laws and regulations."
Write-Host ""

Write-Host "If you do not agree with these terms, please do not use the software."

Write-Host "--------------------------------------------"




# Get path for Winget executible
$Winget = ((Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -File | Where-Object { ($_.fullname -match 'C:\\Program Files\\WindowsApps\\Microsoft.DesktopAppInstaller_' -and $_.name -match 'winget.exe') } | Sort-Object fullname -Descending | ForEach-Object{$_.FullName}) -Split [Environment]::NewLine)[0]

# WinGet version
Write-Output $winget
& "$Winget" --info

# Update source
& "$Winget" source update

# Run the upgrade command
& "$Winget" upgrade --all --silent --accept-source-agreements