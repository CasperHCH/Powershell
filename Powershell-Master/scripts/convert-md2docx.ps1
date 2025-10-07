

Get-ChildItem -r -i *.md | ForEach-Object{$docx=$_.directoryname+"\" +$_.basename+".docx";pandoc -f markdown -s --citeproc $_.name -o $docx}ci -r -i *.md |foreach{$docx=$_.directoryname+"\"+$_.basename+".docx";pandoc -f markdown -s --citeproc $_.name -o $docx}
