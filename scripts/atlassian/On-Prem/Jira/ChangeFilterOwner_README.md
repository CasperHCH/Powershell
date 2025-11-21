# ChangeFilterOwner.ps1 - Quick Reference

## 🔧 **Fixed Issues**

### **v1.1 - November 20, 2025**
- ✅ Fixed PowerShell 5.1 compatibility (removed `??` operator)
- ✅ Fixed parameter binding error with `-Sensitive` switch
- ✅ Added `-SkipUserValidation` parameter for restricted permissions
- ✅ Fixed foreach loop syntax (changed to `for` loop)

## 🚀 **Usage**

### **Basic Usage (With User Validation)**
```powershell
.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Users\a1-chcasp\Downloads\export-error-logs" `
    -JiraUrl "https://jira.norlys.dk" `
    -JiraUser "chcasp" `
    -NewOwner "nicste"
```

### **Skip User Validation (Recommended if you get 403 errors)**
```powershell
.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Users\a1-chcasp\Downloads\export-error-logs" `
    -JiraUrl "https://jira.norlys.dk" `
    -JiraUser "chcasp" `
    -NewOwner "nicste" `
    -SkipUserValidation
```

### **Preview Mode (Validate Only)**
```powershell
.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Users\a1-chcasp\Downloads\export-error-logs" `
    -JiraUrl "https://jira.norlys.dk" `
    -JiraUser "chcasp" `
    -NewOwner "nicste" `
    -SkipUserValidation `
    -ValidateOnly
```

### **With Pre-Stored Password**
```powershell
$securePassword = Read-Host "Enter password" -AsSecureString

.\ChangeFilterOwner.ps1 `
    -LogFolder "C:\Users\a1-chcasp\Downloads\export-error-logs" `
    -JiraUrl "https://jira.norlys.dk" `
    -JiraUser "chcasp" `
    -JiraPassword $securePassword `
    -NewOwner "nicste" `
    -SkipUserValidation
```

## 📋 **Parameters**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-LogFolder` | Yes | Path to folder containing .log files with filter IDs |
| `-JiraUrl` | Yes | Base URL of Jira instance (e.g., https://jira.norlys.dk) |
| `-JiraUser` | Yes | Username for authentication |
| `-JiraPassword` | No | SecureString password (will prompt if omitted) |
| `-NewOwner` | Yes | Username of the new filter owner |
| `-ValidateOnly` | No | Preview changes without executing |
| `-SkipUserValidation` | No | Skip user validation (use if 403 errors occur) |

## ⚠️ **Common Issues & Solutions**

### **403 Forbidden on User Validation**
**Error**: `User validation failed for 'nicste': [403] The remote server returned an error: (403) Forbidden`

**Solution**: Add `-SkipUserValidation` parameter
```powershell
-SkipUserValidation
```

### **403 Forbidden on Filter Update**
**Possible Causes**:
1. You don't own the filter
2. The filter is private
3. You lack "Administer Jira" permissions
4. The new owner doesn't have required permissions

**Solutions**:
- Request admin permissions from Jira administrators
- Contact the current filter owner to transfer ownership manually
- Verify the new owner account has appropriate permissions

### **401 Unauthorized**
**Cause**: Authentication failed

**Solution**: Verify your username and password are correct

## 📊 **Output**

The script provides:
- ✅ Real-time progress with color-coded status
- ✅ Detailed error messages with troubleshooting tips
- ✅ Summary report with success/failure counts
- ✅ Audit log file: `FilterOwnerChange_[SessionID].log`

## 🔍 **Log File Format**

Log files are automatically created in the same directory as the script:
```
FilterOwnerChange_0e8d7762.log
```

Contains:
- Timestamp for every action
- Session ID for tracking
- User and computer information
- Full audit trail of all operations

## 💡 **Tips**

1. **Always test first**: Use `-ValidateOnly` to preview changes
2. **Check permissions**: Ensure your account has filter admin rights
3. **Verify usernames**: Double-check the new owner username spelling
4. **Review logs**: Check audit logs after execution for detailed results
5. **Use SkipUserValidation**: If you get 403 errors during user validation

## 📞 **Need Help?**

If you continue to experience issues:
1. Check the audit log file for detailed error messages
2. Verify your Jira permissions with your administrator
3. Confirm the filter IDs exist in your Jira instance
4. Test with a single filter ID first before batch processing
