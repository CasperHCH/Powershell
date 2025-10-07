# Copilot Instructions

## Overview
This repository contains a collection of PowerShell scripts for various automation tasks, including user management, system monitoring, and API integrations. The scripts are organized into different folders based on their purpose and development status.

## Folder Structure
- `autoload/`: Contains reusable PowerShell functions and modules.
- `Powershell-Master/`: A collection of finalized and tested scripts.
- `Scripts/`, `Tools/`, `WindowsPowershell/`: Additional scripts and tools for specific use cases.

## Key Scripts
- **Jira User Management**: Scripts for bulk deleting and anonymizing Jira users, replacing usernames and emails, and integrating with Azure AD or on-prem Active Directory.
- **System Monitoring**: Scripts for checking system uptime, listing running services, and fetching weather data.
- **Automation Tasks**: Scripts for installing Jenkins agents, creating event logs, and managing user accounts.

## Development Guidelines
1. **Error Handling**: Ensure all scripts include robust error handling to manage unexpected scenarios.
2. **Logging**: Use consistent logging practices to track script execution and debug issues.
3. **Modularization**: Break down scripts into reusable functions and modules for better maintainability.
4. **Environment Compatibility**: Adapt scripts to work seamlessly in both cloud and on-prem environments.
5. **WhatIf Mode**: Include a "WhatIf" mode to simulate actions without making changes.

## Developer Workflows
- **Testing**: Use `Pester` for unit testing PowerShell scripts. Example test files can be found in the `Powershell-Master/scripts/` directory.
- **Debugging**: Leverage the `Write-Debug` cmdlet for inline debugging. Ensure debug messages are meaningful and actionable.
- **Script Signing**: Use the `SignScripts.ps1` script in the `Scripts/` folder to sign PowerShell scripts before deployment.

## API Integrations
- Replace `Invoke-RestMethod` with `curl` for API calls where possible.
- Ensure API calls include proper authentication and error handling.
- Refer to `autoload/Connect-Office365Services.ps1` for examples of API integration patterns.

## Project-Specific Conventions
- **Function Naming**: Use the `Verb-Noun` naming convention for all functions (e.g., `Get-UserAutomapping`).
- **Parameter Validation**: Include `[ValidateNotNullOrEmpty()]` attributes for mandatory parameters.
- **Logging**: Use the `Write-Log` function from `autoload/Functions-PSStoredCredentials.ps1` for consistent logging.

## Integration Points
- **Azure AD**: Scripts like `Get-AdSync.ps1` and `Start-AdSync.ps1` integrate with Azure AD for synchronization tasks.
- **Jira**: Refer to `Powershell-Master/scripts/` for Jira user management scripts.

## Contribution Guidelines
- Follow the development guidelines outlined above.
- Test scripts thoroughly using `Pester`.
- Document any new scripts or updates in the `README.md` files.

## Notes for AI Agents
- Focus on improving error handling, logging, and modularization in scripts.
- Ensure compatibility with both cloud and on-prem environments where possible.
- Prioritize the use of `curl` for API calls.
- Add or update documentation as needed.
- Refer to `autoload/` for reusable functions and modules.
- Ensure all scripts include appropriate comments and documentation.
- Maintain consistent formatting and style across all scripts.
- Include error handling and logging in all scripts.
- Use `Pester` for testing and ensure scripts are well-tested before committing.
- Consider performance implications and optimize scripts for efficiency.
- Ensure scripts are secure, especially when handling sensitive data or credentials.
- Follow best practices for PowerShell scripting.
- Use version control effectively, with clear commit messages and branches for new features or fixes.
- Document any new scripts or updates in the `README.md` files.
- Regularly review and update scripts to ensure they remain relevant and effective.
- Ensure all scripts are properly documented and include usage examples.

## Contact
For any questions or contributions, please contact the repository maintainer.