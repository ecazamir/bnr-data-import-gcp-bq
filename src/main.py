import os
import logging
import requests
import xml.etree.ElementTree as ET
import pandas as pd
from google.cloud import bigquery
from datetime import datetime, timezone

# Setup Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration from environment variables (set via Terraform/Job)
TABLE_ID = os.getenv("TABLE_ID")
IMPORT_MODE = os.getenv("IMPORT_MODE", "daily") # 'daily' or 'history'
IMPORT_YEAR = os.getenv("IMPORT_YEAR")
NAMESPACE = {'ns': 'http://www.bnr.ro/xsd'}

def get_bnr_url():
    if IMPORT_MODE == 'history' and IMPORT_YEAR:
        return f"https://www.bnr.ro/files/xml/years/nbrfxrates{IMPORT_YEAR}.xml"
    return "https://www.bnr.ro/nbrfxrates.xml"

def parse_xml_to_df(xml_content):
    root = ET.fromstring(xml_content)
    records = []
    
    # Search for <Cube> elements (there can be multiple in historical files)
    for cube in root.findall('.//ns:Cube', NAMESPACE):
        date_str = cube.get('date')
        for rate in cube.findall('ns:Rate', NAMESPACE):
            records.append({
                "date": date_str,
                "currency": rate.get('currency'),
                "value": float(rate.text),
                "multiplier": int(rate.get('multiplier', 1)),
                "ingested_at": datetime.now(timezone.utc)
            })
            
    if not records:
        return None
        
    df = pd.DataFrame(records)
    df['date'] = pd.to_datetime(df['date']).dt.date
    return df

def run_etl():
    if not TABLE_ID:
        raise ValueError("Environment variable TABLE_ID is not set.")

    client = bigquery.Client()
    url = get_bnr_url()
    
    logger.info(f"Downloading data from: {url}")
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    
    df = parse_xml_to_df(response.content)
    if df is None:
        logger.warning("No data found to process.")
        return

    # Create a temporary table for the MERGE operation
    temp_table_id = f"{TABLE_ID}_temp_{int(datetime.now().timestamp())}"
    
    logger.info(f"Loading data into temporary table {temp_table_id}")
    job_config = bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE")
    client.load_table_from_dataframe(df, temp_table_id, job_config=job_config).result()

    # Execute MERGE to ensure idempotency (Update if exists, Insert if new)
    merge_query = f"""
    MERGE `{TABLE_ID}` T
    USING `{temp_table_id}` S
    ON T.date = S.date AND T.currency = S.currency
    WHEN NOT MATCHED THEN
      INSERT (date, currency, value, multiplier, ingested_at)
      VALUES (date, currency, value, multiplier, ingested_at)
    WHEN MATCHED THEN
      UPDATE SET value = S.value, ingested_at = S.ingested_at
    """
    
    logger.info("Executing MERGE in BigQuery...")
    client.query(merge_query).result()
    
    # Cleanup: Delete the temporary table
    client.delete_table(temp_table_id, not_found_ok=True)
    logger.info(f"Import successfully completed: {len(df)} rows processed.")

if __name__ == "__main__":
    try:
        run_etl()
    except Exception as e:
        logger.error(f"Critical error during execution: {e}")
        exit(1) # Non-zero exit code to trigger Retry/Alert in GCP