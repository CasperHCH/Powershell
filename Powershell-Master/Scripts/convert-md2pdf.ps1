gci -r -i *.md |foreach{$pdf=$_.directoryname++$_.basename+;pandoc -f markdown -s --citeproc $_.name -o $pdf}
