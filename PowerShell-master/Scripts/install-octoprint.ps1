try {
	

	& sudo snap install octoprint-pfs --edge
	if ($lastExitCode -ne ) { throw  }

	
	exit 0 # success
} catch {
        
        exit 1
}
