Get-ChildItem -path  | rename-item -newname { [io.path]::ChangeExtension($_.name, ) }
$file = gci  | sort LastWriteTime | select -last 1
$currentDate = get-date
$Summary = 
$Description = @@

acli Miracle_Jira --action run --input MHDTask$($summary)$($description)-a addAttachment --issue @issue@ --file $file"
