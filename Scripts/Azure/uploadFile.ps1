$filepath = 'C:\Temp\'
$file = 'editedFile.rtf'

$fullPath = $filepath + $file

$lastModifiedDate = (Get-Item ).LastWriteTime


$dateA= $lastModifiedDate 
$dateB= (Get-Item ).LastWriteTime

if ($dateA -ge $dateB) {
  Write-Host()
} else {
  Write-Host()
}



$StorageUrl = 
$SASToken = ''

$blobUploadParams = @{
    URI =  -f $StorageURL, $File, $SASToken
    Method = 
    Headers = @{
        'x-ms-blob-type' = 
        'x-ms-blob-content-disposition' = {0}` -f $FileName
        'x-ms-meta-m1' = 'v1'
        'x-ms-meta-m2' = 'v2'
    }
    Body = $Content
    Infile = $FileToUpload
}
