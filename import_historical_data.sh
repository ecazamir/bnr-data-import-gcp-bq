#!/bin/bash

# --- CONFIGURATION ---
JOB_NAME="bnr-data-import"
PROJECT_ID="bnr-xr-data-zzzz"
REGION="europe-west3"
START_YEAR=2005
END_YEAR=2026

echo "-------------------------------------------------------"
echo " Starting BNR Historical Data Import (Cloud Run Jobs) "
echo " Period: $START_YEAR - $END_YEAR "
echo "-------------------------------------------------------"

# Check if gcloud is configured
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed."
    exit 1
fi

for year in $(seq $START_YEAR $END_YEAR)
do
    echo "[$(date +'%H:%M:%S')] Launching import execution for year: $year..."

    # Execute Job overriding environment variables
    # --wait: Script will wait for current year execution to finish before moving to the next
    gcloud run jobs execute $JOB_NAME \
        --project=$PROJECT_ID \
        --region=$REGION \
        --update-env-vars="IMPORT_MODE=history,IMPORT_YEAR=$year" \
        --wait

    # Check the status of the last command
    if [ $? -eq 0 ]; then
        echo "✅ Success: Data for year $year was migrated."
    else
        echo "❌ Error: Execution for year $year failed. Check console logs."
        # Optional: exit 1 if you want the script to stop on the first error
    fi

    echo "-------------------------------------------------------"
done

echo "Migration complete for the entire $START_YEAR - $END_YEAR interval!"
