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

### Step 1: Configure Snowflake Resources
Run the following SQL commands in Snowsight as **ACCOUNTADMIN**:

```sql
-- Create dedicated role and user
CREATE OR REPLACE ROLE aicollege;
CREATE OR REPLACE USER mlops_userTYPE = SERVICE
  DEFAULT_ROLE = aicollege;

-- Grant permissions
GRANT ROLE aicollege TO USER mlops_user;
GRANT ROLE aicollege TO USER<your_username>;

-- Create database and warehouse
CREATE OR REPLACE DATABASE aicollege;
CREATE OR REPLACE WAREHOUSE aicollege
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 300;

-- Grant required permissions
GRANT USAGE, OPERATE ON WAREHOUSE aicollege TO ROLE aicollege;
GRANT ALL ON DATABASE aicollege TO ROLE aicollege;
GRANT ALL ON SCHEMA aicollege.public TO ROLE aicollege;
GRANT CREATE MODEL ON SCHEMA aicollege.public TO ROLE aicollege;
