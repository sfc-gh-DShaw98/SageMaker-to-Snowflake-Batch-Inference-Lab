# Azure Machine Learning to Snowflake Model Registry Lab

## Overview
This lab demonstrates how to train a machine learning model in Azure ML and register it to Snowflake's Model Registry for scalable batch inference. You'll build an end-to-end MLOps pipeline that bridges Azure's ML capabilities with Snowflake's data platform.

## Learning Objectives
By the end of this lab, you will:
- ✅ Set up an Azure ML workspace and compute resources
- ✅ Train an XGBoost classifier on mortgage lending data
- ✅ Connect Azure ML to Snowflake using secure authentication
- ✅ Register your trained model in Snowflake's Model Registry
- ✅ Perform batch inference on Snowflake data
- ✅ Apply governance tags for model lifecycle management
- ✅ Understand scaling options with ML Jobs and SPCS

## Prerequisites
- Azure subscription with contributor access
- Snowflake account with ACCOUNTADMIN privileges
- Basic familiarity with Python, pandas, and machine learning concepts

---

## Part 1: Azure Machine Learning Workspace Setup

### Step 1: Create Azure ML Workspace
1. In the Azure portal header, click **☰ > Create a resource**
2. Search for **"Machine Learning"** → select **Azure Machine Learning** → **Create**
3. Fill the basics:
   - **Subscription / Resource group** – pick or create a new resource group
   - **Workspace name** – e.g., `college-ai-mlops`
   - **Region** – select your preferred region
   - Leave networking/encryption defaults for this lab
4. **Review + Create** → **Create** (deployment takes ~2-3 minutes)
5. When deployment completes, click **Go to resource**
6. Click **Launch studio** to open Azure ML Studio

### Step 2: Create Compute Instance
1. In Azure ML Studio, navigate to **Compute** → **Compute instances**
2. Click **+ New** to create a compute instance
3. Configure:
   - **Compute name**: `ml-compute-instance`
   - **Virtual machine type**: `CPU`
   - **Virtual machine size**: `Standard_DS3_v2` (4 cores, 14 GB RAM)
4. Click **Create** (provisioning takes 3-5 minutes)

### Step 3: Upload Training Data
1. Navigate to **Data** → **Datastores** → **workspaceblobstore**
2. Click **Browse** → **Upload files**
3. Upload your `MORTGAGE_LENDING_DEMO_DATA.csv` file
4. Create a dataset:
   - Go to **Data** → **Data assets** → **+ Create**
   - Name: `collegeaimlops`
   - Source: From datastore files
   - Select your uploaded CSV file

---

## Part 2: Snowflake Environment Setup

> **📝 Note:** If you've already completed the **Phase 1 Setup** from the SageMaker lab, most of these steps are already done. You only need to run the **Azure ML-specific sections** marked below.

### Step 1: Core Environment Setup (Skip if Phase 1 Setup completed)

Run the following SQL commands in Snowsight as **ACCOUNTADMIN**:

```sql
-- Use elevated privileges
USE ROLE ACCOUNTADMIN;

-- Create a dedicated role, service user, database, and warehouse
CREATE OR REPLACE ROLE aicollege;

CREATE OR REPLACE USER mlops_userTYPE = SERVICE
  DEFAULT_ROLE = aicollege
  COMMENT = 'Service user for MLOps HOL';

-- Grant role to service user and your standard user
GRANT ROLE aicollege TO USER mlops_user;
GRANT ROLE aicollege TO USER <your_snowflake_username>;

-- Create database and warehouse
CREATE DATABASE IF NOT EXISTS aicollege;
CREATE WAREHOUSE IF NOT EXISTS aicollege
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 300;

-- Grant required permissions
GRANT USAGE, OPERATE ON WAREHOUSE aicollege TO ROLE aicollege;
GRANT ALL ON DATABASE aicollege TO ROLE aicollege;
GRANT ALL ON SCHEMA aicollege.public TO ROLE aicollege;
GRANT CREATE STAGE ON SCHEMA aicollege.public TO ROLE aicollege;
GRANT SELECT ON FUTURE TABLES IN SCHEMA aicollege.public TO ROLE aicollege;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA aicollege.public TO ROLE aicollege;

-- Create a staging area for uploads
CREATE STAGE IF NOT EXISTS aicollege.public.setup;
GRANT READ ON STAGE aicollege.public.setup TO ROLE aicollege;

### Step 2: Azure ML-Specific Permissions (Required for all users)
-- Additional permissions needed for Azure ML integration
USE ROLE ACCOUNTADMIN;

-- Model Registry permissions
GRANT CREATE MODEL ON SCHEMA aicollege.public TO ROLE aicollege;
GRANT CREATE TAG ON SCHEMA aicollege.public TO ROLE aicollege;

-- Email integration for alerts (update email address)
CREATE OR REPLACE NOTIFICATION INTEGRATION ML_ALERTS
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<your_email@company.com>');

GRANT USAGE ON INTEGRATION ML_ALERTS TO ROLE aicollege;
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE aicollege;
GRANT CREATE DYNAMIC TABLE ON SCHEMA aicollege.public TO ROLE aicollege;
```

### Step 3: Set Up Key-Pair Authentication (Skip if Phase 1 Setup completed)
1. Generate RSA key pair (if not already done):
```bash
openssl genrsa -out rsa_private_key.pem 2048
openssl rsa -in rsa_private_key.pem -pubout -out rsa_public_key.pem
```
2. Set the public key for your service user:
```sql
ALTER USER mlops_user SET RSA_PUBLIC_KEY='-----BEGIN PUBLIC KEY-----<your_public_key_content>
-----END PUBLIC KEY-----';
```

### Step 4: Configure Network Access for Azure ML
⚠️ Important: This step is Azure ML-specific and must be completed even if you did Phase 1 Setup.
1. Get your Azure ML compute instance IP (you'lldo this in the notebook):
```python
!curl ifconfig.me
```
2. Create/Update network policy with your Azure ML IP:
```sql
-- Create network policy for Azure ML (replace with your actual IP)
CREATE OR REPLACE NETWORK POLICY ALLOW_AZUREML
  ALLOWED_IP_LIST = ('<your_azure_ml_ip>')
  COMMENT = 'Restrict access to Azure ML IPs for MLOps HOL';

-- Assign to service user
ALTER USER mlops_user SET NETWORK_POLICY = ALLOW_AZUREML;

-- Verify configuration
DESC USER mlops_user;
```

### Step 5: Create Inference Data Table (Skip if Phase 1 Setup completed)
```sql
-- Switch to working role
USE ROLE aicollege;
USE DATABASE aicollege;
USE SCHEMA public;
USE WAREHOUSE aicollege;

-- Create target table for inference data
CREATE TABLE IF NOT EXISTS InferenceMortgageData (WEEK_START_DATE TIMESTAMP_NTZ,
    WEEK NUMBER(38, 0),
    LOAN_ID NUMBER(38, 0),
    TS VARCHAR,
    LOAN_TYPE_NAME VARCHAR,
    LOAN_PURPOSE_NAME VARCHAR,
    APPLICANT_INCOME_000S NUMBER(38, 1),
    LOAN_AMOUNT_000S NUMBER(38, 0),
    COUNTY_NAME VARCHAR,
    MORTGAGERESPONSE NUMBER(38, 0)
);

-- Define file format for CSV import
CREATE OR REPLACE FILE FORMAT aicollege.public.mlopsTYPE = CSV
    SKIP_HEADER =1
    FIELD_DELIMITER = ','
    TRIM_SPACE = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    REPLACE_INVALID_CHARACTERS = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Load the CSV file (upload Mortgage_Data.csv to @aicollege.public.setup first)
COPY INTO InferenceMortgageData
FROM @aicollege.public.setup/Mortgage_Data.csv
FILE_FORMAT = aicollege.public.mlops
ON_ERROR = ABORT_STATEMENT;
```

### Step 6: Handle Model Tags (Azure ML-specific)
📝 Note: The notebook will create these tags, but if you encounter permission errors, run this as ACCOUNTADMIN:
```sql
-- Only run if you get tag permission errors in the notebook
USE ROLE ACCOUNTADMIN;

-- Grant tag ownership (only needed if tags already exist from previous runs)
-- GRANT OWNERSHIP ON TAG aicollege.public.MODEL_STAGE_TAG TO ROLE aicollege;
-- GRANT OWNERSHIP ON TAG aicollege.public.MODEL_PURPOSE_TAG TO ROLE aicollege;
-- GRANT OWNERSHIP ON TAG aicollege.public.SOURCE TO ROLE aicollege;
-- GRANT OWNERSHIP ON TAG aicollege.public.PROJECT TO ROLE aicollege;
```

### Step 7: Use this notebook in Azure ML



