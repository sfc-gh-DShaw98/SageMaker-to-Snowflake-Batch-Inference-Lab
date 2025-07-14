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
4. Review + Create → **Create** (deployment takes ~2-3 minutes)
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

CREATE OR REPLACE USER mlops_user TYPE = SERVICE
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
```

### Step 2: Azure ML-Specific Permissions (Required for all users)
```sql
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

### Step 4: Network Policy Setup (Completed During Azure ML Notebook Execution)
⚠️ **Important:** This step will be completed DURING notebook execution, not before. The notebook will guide you through getting your IP address and updating the network policy.

**What will happen in the notebook:**
1. The notebook will show you how to get your Azure ML compute instance IP
2. You'll then return to Snowsight to update the network policy with that IP
3. The notebook will test the connection to confirm it works

**SQL commands you'll use (save these for reference):**
```sql
-- You'll run these commands in Snowsight when prompted by the notebook
CREATE OR REPLACE NETWORK POLICY ALLOW_AZUREML
  ALLOWED_IP_LIST = ('<your_azure_ml_ip_from_notebook>')
  COMMENT = 'Restrict access to Azure ML IPs for MLOps HOL';

-- Assign to service user
ALTER USER mlops_user SET NETWORK_POLICY = ALLOW_AZUREML;

-- Verify configuration
DESC USER mlops_user;
```
📝 **Note:** Don't run these SQL commands now - wait for the notebook to guide you through the process.

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
CREATE OR REPLACE FILE FORMAT aicollege.public.mlops TYPE = CSV
    SKIP_HEADER = 1
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

---

## Part 3: Execute the ML Pipeline

### 📓 **Main Notebook: [Azure ML Model to Snowflake Model Registry](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/notebooks/Azure_ML%20Model%20to%20Snowflake%20Model%20Registry.ipynb)**

This comprehensive notebook demonstrates the complete MLOps workflow from Azure ML training to Snowflake Model Registry deployment.

#### 🔧 **What This Notebook Accomplishes:**

**Model Development & Training:**
- Data preprocessing with pandas (one-hot encoding, feature alignment)
- XGBoost classifier training with proper train/validation/holdout splits
- Model evaluation with comprehensive metrics (accuracy, precision, recall, F1)
- Azure ML experiment tracking and logging

**Azure-Snowflake Integration:**
- Secure connection setup using TOML configuration and JWT authentication
- Network policy configuration and IP allowlisting
- Error handling and connection validation

**Model Registry & Governance:**
- Model registration in Snowflake Model Registry with metadata
- Governance tagging for model lifecycle management
- Version control and model lineage tracking

**Batch Inference Pipeline:**
- Feature preprocessing pipeline for inference data alignment
- Batch scoring on Snowflake data with multiple approaches
- Results storage with ground truth for model monitoring

---

### Step 1: Upload and Configure the Notebook

1. **Download the notebook** from the repository
2. **In Azure ML Studio**, navigate to **Notebooks**
3. **Upload the notebook file** using the upload button
4. **Create your configuration files:****
   - Create `connections.toml`:**
      ```toml
      [connections.Snowpark_MLOps_HOL]
      account = "your_account_identifier"
      user = "mlops_user"
      role = "aicollege"
      warehouse = "aicollege"
      database = "aicollege"
      schema = "public"
      authenticator = "snowflake_jwt"
      ```
6. **Upload your rsa_private_key.pem file** (generated in Step 3)

### Step 2: Execute the Notebook
1. **Open the notebook** in Azure ML Studio
2. **Select kernel:** Choose **Python 3.10- AzureML**
3. **Execute cells sequentially,** following these key phases:
   - **Environment Setup (Cells 1-3)**
      - Install required packages
      - Import libraries
      - Connect to Azure ML workspace
   - **Data Preparation (Cells 4-7)**
      - Load mortgage lending dataset
      - Perform feature engineering and preprocessing
      - Create train/validation/test splits
   - **Model Training (Cells 8-9)**
      - Train XGBoost classifier
      - Log metrics to Azure ML
      - Evaluate model performance
   - **Snowflake Integration (Cells 10-11)**
      - Establish secure connection to Snowflake
      - Test connection and permissions
   - **Model Registration (Cells 12-14)**
      - Register model in Snowflake Model Registry
      - Apply governance tags
      - Validate registration
   - **Batch Inference (Cells 15-17)**
      - Preprocess inference data
      - Run batch scoring
      - Store results for monitoring

---

### Step 3: Validate Your Results
After completing the notebook execution, verify your setup worked correctly:

1. **Check model registration in Snowflake:**
```sql
USE ROLE aicollege;
SHOW MODELS IN SCHEMA aicollege.public;
```
2. **Verify inference results:**
```sql
SELECT * FROM aicollege.public.ALL_PREDICTIONS_WITH_GROUND_TRUTH LIMIT 10;
```
3. Confirm model tags:
```sql
SELECT * FROM TABLE(aicollege.information_schema.tag_references('aicollege.public.azureml_xgb_model', 'model'));
```

---
### Step 4: Expected Outcomes
Upon successful completion, you should have:

✅ A trained XGBoost model registered in Snowflake Model Registry
✅ Batch inference pipeline processing mortgage application data
✅ Model governance tags applied for lifecycle management
✅ Comprehensive metrics logged in both Azure ML and Snowflake
✅ Understanding of scaling options for production deployment

---
## Troubleshooting

### Common Issues and Solutions

**Azure ML Issues:**
- **Compute instance won't start**: Try a different VM size or refresh the page
- **Kernel disconnections**: Restart the kernel from the notebook toolbar
- **Package installation failures**: Ensure you're using the correct Python 3.10 kernel

**Snowflake Connection Issues:**
- **Authentication failures**: Verify RSA key pair matches and is correctly formatted
- **Network policy errors**: Confirm your Azure ML IP is added to the ALLOW_AZUREML policy
- **Permission denied**: Ensure all grants in Step 2 were executed as ACCOUNTADMIN

**Model Registry Issues:**
- **Tag creation errors**: Run the tag ownership grants from Step 6
- **Model registration failures**: Check that CREATE MODEL privilege is granted
- **Inference errors**: Verify feature schema alignment between training and inference data

### Getting Help
If you encounter issues not covered here:
1. Check the notebook's error messages for specific guidance
2. Verify all prerequisite steps were completed
3. Ensure your Snowflake and Azure ML environments have proper permissions

---
## Next Steps

### 🎯 Phase 2: Model Monitoring with Snowflake ML Observability
Now that you’ve batch-scored your Azure ML model and stored results in `PREDICTIONS_WITH_GROUND_TRUTH`, Phase 2 focuses on keeping it healthy in production:

- Instrument a **Model Monitor** for your registered Azure ML XGBoost model  
- Generate and persist **baseline metrics** from your initial batch results  
- Set up **automated alerts** (e.g. F1-score falls below 0.7)  
- Visualize performance trends, drift, and data quality issues natively in Snowflake  
- Define **retraining triggers** based on drift detection and alert thresholds

This phase builds directly on your `PREDICTIONS_WITH_GROUND_TRUTH` table to ensure your model stays accurate in production.

➡️ Continue to [Phase 2: Model Monitoring with Snowflake ML Observability](./phase2_ml_observability.md)

**Notebook (Azure ML):**  
[MLOps Snowflake ML Observability for Azure ML Model](notebooks/MLOPs%20Snowflake%20ML%20Observability%20In%20Action%20for%20Azure%20ML%20Model.ipynb)

---

### 🚀 **Additional Scaling & Production Options**

After completing Phase 2, explore these advanced deployment patterns:

- **[ML Jobs](https://docs.snowflake.com/en/developer-guide/snowpark-ml/snowpark-ml-mlops)** - Automate your batch inference pipeline with scheduled jobs
- **[Snowpark Container Services](https://docs.snowflake.com/en/developer-guide/snowpark-container-services/overview)** - Deploy real-time inference endpoints for high-scale applications  
