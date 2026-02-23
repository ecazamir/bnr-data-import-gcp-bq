<#
.SYNOPSIS
    Migrates historical BNR data using Cloud Run Jobs.
    
.DESCRIPTION
    This script executes the BNR Data Import Cloud Run Job iteratively for each year
    in the specified range, passing the year and mode as environment variables.
#>

# --- CONFIGURATION ---
$JOB_NAME = "bnr-data-import"
$PROJECT_ID = "bnr-xr-data-zzzz"
$REGION = "europe-west3"
$START_YEAR = 2005
$END_YEAR = 2026

Write-Host "-------------------------------------------------------"
Write-Host " Starting BNR Historical Data Import (Cloud Run Jobs) "
Write-Host " Period: $START_YEAR - $END_YEAR "
Write-Host "-------------------------------------------------------"

# Check if gcloud is configured
if (!(Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "Error: gcloud CLI is not installed."
    exit 1
}

for ($year = $START_YEAR; $year -le $END_YEAR; $year++) {
    $currentTime = Get-Date -Format "HH:mm:ss"
    Write-Host "[$currentTime] Launching import execution for year: $year..."

    # Execute Job overriding environment variables
    # --wait: Script will wait for current year execution to finish before moving to the next
    
    # We use cmd /c because sometimes gcloud arguments are incorrectly parsed in PowerShell
    cmd.exe /c "gcloud run jobs execute $JOB_NAME --project=$PROJECT_ID --region=$REGION --update-env-vars=`"IMPORT_MODE=history,IMPORT_YEAR=$year`" --wait"
    
    # Check the status of the last command
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Success: Data for year $year was migrated." -ForegroundColor Green
    } else {
        Write-Host "❌ Error: Execution for year $year failed. Check console logs." -ForegroundColor Red
        # Optional: exit 1 if you want the script to stop on the first error
    }

    Write-Host "-------------------------------------------------------"
}

Write-Host "Migration complete for the entire $START_YEAR - $END_YEAR interval!" -ForegroundColor Green
