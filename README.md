# BNR Data Pipeline v2026 (Production Grade)

This project implements a complete ETL (Extract, Transform, Load) pipeline for the BNR (National Bank of Romania) exchange rate, fully automated in Google Cloud Platform using **Cloud Run Jobs** and **Terraform**.

[Image of a cloud ETL pipeline architecture diagram with Cloud Build and BigQuery]

## 🛠️ System Features
* **Job-Based Architecture:** Utilization of Cloud Run Jobs for robust processing of large data volumes and native retry management.
* **Modular Infrastructure:** Separation of build tools (Artifact Registry) from logical application infrastructure (BigQuery, Job, Scheduler).
* **Cloud-Native CI/CD:** Container build is done directly in Google Cloud via Cloud Build, eliminating local Docker dependency.
* **Auto-Configuration API:** Automatic activation of required Google Cloud APIs via Terraform (Artifact Registry, Cloud Build, Cloud Run, BigQuery, Monitoring).
* **Idempotency:** SQL `MERGE` logic prevents duplicates in BigQuery, regardless of the job run frequency.

---

## 📂 Project Structure

```text
BNR_ETL_PROJECT/
├── 01_build_tooling/       # Part 1: Artifact Registry & Build Permissions
│   ├── main.tf             # Enables Build APIs & creates Registry
│   ├── terraform.tfvars    # Variables: project_id, region
│   └── outputs.tf
├── 02_app_infrastructure/  # Part 2: BigQuery, Job, Scheduler, Alerts
│   ├── main.tf             # Enables App APIs & final resources
│   ├── terraform.tfvars    # Variables: project_id, region, admin_email
│   └── outputs.tf
├── src/                    # Python Source Code
│   ├── main.py             # ETL Logic (Python 3.14) with SQL MERGE
│   └── requirements.txt    # pandas, google-cloud-bigquery, requests
├── Dockerfile              # Container recipe (based on python:3.14-slim)
├── cloudbuild.yaml         # CI/CD Pipeline for Google Cloud Build
├── migrate_history.sh      # Bash script for historical migration (2005-2026)
├── .gitignore              # Excludes sensitive Terraform files and temp
└── .dockerignore           # Optimizes transfer to Cloud Build
```

## 🚀 Installation Guide (Natural Order)

### Step 1: Environment Preparation
Ensure you have gcloud CLI and terraform installed and you are authenticated in your desired project:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Bootstrap Build Tooling

* Create the Docker registry, enable required build permissions, and create the Terraform state bucket.
* Navigate to 01_build_tooling/.
* Edit terraform.tfvars with your project ID.
* Run: `terraform init && terraform apply`

### Step 3: Moving Terraform state to GCS

After creating the bucket in Step 2, configure Terraform to use the GCS backend through partial configuration.
Create a file named `backend.conf` in both infrastructure folders (`01_build_tooling` and `02_app_infrastructure`):

For `01_build_tooling/backend.conf`:
```hcl
bucket = "YOUR_PROJECT_ID-tfstate"
prefix = "terraform/state-01-build"
```

For `02_app_infrastructure/backend.conf`:
```hcl
bucket = "YOUR_PROJECT_ID-tfstate"
prefix = "terraform/state-02-app"
```

Then run the initialization command below in each folder and confirm the migration with `yes`:

```bash
terraform init -backend-config=backend.conf -migrate-state
```

### Step 4: Container Construction

Launch the build in the cloud. Cloud Build will fetch the code, build the image, and save it in the Artifact Registry:

```bash
cd ..
gcloud builds submit --config cloudbuild.yaml
```

### Step 5: Application Infrastructure Deployment

* Create the database, the import job, and automatic alerts.
* Navigate to 02_app_infrastructure/.
* Edit terraform.tfvars (make sure admin_email is correct for alerts).
* Run: `terraform init && terraform apply`

### Step 6: Historic Data Import

Populate the BigQuery table with data from the 2005 - 2026 period using the orchestration script.

For Linux/macOS users:
```bash
cd ..
chmod +x import_historical_data.sh
./import_historical_data.sh
```

For Windows users (PowerShell):
```powershell
cd ..
.\import_historical_data.ps1
```

#### 🔍 Verification Query (BigQuery SQL)

After migration, you can check the data with this query:

```SQL
SELECT 
  date, 
  currency, 
  value, 
  multiplier 
FROM `YOUR_PROJECT_ID.bnr_data.bnr_rates` 
WHERE date >= '2026-01-01'
ORDER BY date DESC, currency ASC;
```

Maintenance: To update the code, run only Step 4. To modify the table structure or alert settings, run Step 5.

## 📊 Monitoring and Maintenance

Daily Trigger: Cloud Scheduler automatically starts the job at 13:30 (Romania Time) every working day.

Alert System: In case of critical failure (after 3 automatic retry attempts), a notification will be sent to the configured email address.

Idempotency: If execution fails halfway through, a rerun will not duplicate data already existing for that day due to the UPSERT/MERGE logic.
