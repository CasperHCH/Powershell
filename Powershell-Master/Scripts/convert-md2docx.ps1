gci -r -i *.md |foreach{$docx=$_.directoryname++$_.basename+;pandoc -f markdown -s --citeproc $_.name -o $docx}
