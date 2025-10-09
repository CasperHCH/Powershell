[appdomain]::CurrentDomain.GetAssemblies() | ForEach {
    Try {
        $_.GetExportedTypes() | Where-Object {
            $_.Fullname -match 'Exception'
        }
    } Catch {}
} | Select BaseType,Name,FullName