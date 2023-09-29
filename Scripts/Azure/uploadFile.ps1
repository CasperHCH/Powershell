$filepath = 'C:\Temp\'
$file = 'editedFile.rtf'

$fullPath = $filepath + $file

$lastModifiedDate = (Get-Item "C:\foo.tmp").LastWriteTime


$dateA= $lastModifiedDate 
$dateB= (Get-Item "C:\other.tmp").LastWriteTime

if ($dateA -ge $dateB) {
  Write-Host("C:\foo.tmp was modified at the same time or after C:\other.tmp")
} else {
  Write-Host("C:\foo.tmp was modified before C:\other.tmp")
}



$StorageUrl = "https://gorthmorth.blob.core.windows.net/STORAGE_CONTAINER/"
$SASToken = ''

$blobUploadParams = @{
    URI = "{0}/{1}?{2}" -f $StorageURL, $File, $SASToken
    Method = "PUT"
    Headers = @{
        'x-ms-blob-type' = "BlockBlob"
        'x-ms-blob-content-disposition' = "attachment; filename=`"{0}`"" -f $FileName
        'x-ms-meta-m1' = 'v1'
        'x-ms-meta-m2' = 'v2'
    }
    Body = $Content
    Infile = $FileToUpload
}