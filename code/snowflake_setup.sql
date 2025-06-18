-- 1.1 Snowflake Environment Setup
-- Use elevated privileges
USE ROLE ACCOUNTADMIN;

-- Create a dedicated role, service user, database, and warehouse
CREATE OR REPLACE ROLE aicollege;

CREATE OR REPLACE USER mlops_user
  TYPE = SERVICE 
  DEFAULT_ROLE = aicollege 
  COMMENT = 'Service user for MLOps HOL';

-- Grant role to service user and your standard user
GRANT ROLE aicollege TO USER mlops_user;
GRANT ROLE aicollege TO USER <your_standard_user>;

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

-- 1.1.1 Recommended Code: Set Default Role to AICOLLEGE
ALTER USER mlops_user SET DEFAULT_ROLE = AICOLLEGE;

-- 1.1.2 Add you Your Private Key for mlops_user
-- Run the following SQL (replace placeholder):
ALTER USER mlops_user SET RSA_PUBLIC_KEY='
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAA...
-----END PUBLIC KEY-----';

-- Confirm the key was set:
DESC USER mlops_user;

-- 1.1.3 Upload Files & Load Data
-- Use AICOLLEGE Role
-- Navigate to Data >> Databases >> AICOLLEGE >> PUBLIC >> Stages >> SETUP
-- Add these two files
-- Mortgage_Data.csv and
-- MLObservabilityWorkflow.jpg files
-- Run this code to create/load the required data

-- Ensure you're using the correct context
USE ROLE aicollege;
USE DATABASE aicollege;
USE SCHEMA public;
USE WAREHOUSE aicollege;

-- Create a target table for inference data
CREATE OR REPLACE TABLE InferenceMortgageData (
    WEEK_START_DATE TIMESTAMP_NTZ,
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
CREATE OR REPLACE FILE FORMAT aicollege.public.mlops
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_DELIMITER = ','
    TRIM_SPACE = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    REPLACE_INVALID_CHARACTERS = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Load the CSV file into the table
COPY INTO InferenceMortgageData
FROM @aicollege.public.setup/Mortgage_Data.csv
FILE_FORMAT = aicollege.public.mlops
ON_ERROR = ABORT_STATEMENT;
1.1.4 Integrations & Permissions Setup
Use AICOLLEGE Role
Copy and run this code to set necessary permissions
USE ROLE ACCOUNTADMIN;

-- Create an Email integration to receive notifications from Snowflake alerts 
CREATE OR REPLACE NOTIFICATION INTEGRATION ML_ALERTS
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<snowflake email>');

GRANT USAGE ON INTEGRATION ML_ALERTS TO ROLE aicollege;
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE AICOLLEGE;
GRANT CREATE DYNAMIC TABLE ON SCHEMA AICOLLEGE.PUBLIC TO ROLE AICOLLEGE;

-- Grant usage on existing DORA integration and utility database
GRANT USAGE ON INTEGRATION dora_api_integration TO ROLE aicollege;
GRANT USAGE ON DATABASE util_db TO ROLE aicollege;
GRANT USAGE ON SCHEMA util_db.public TO ROLE aicollege;

-- Grant usage on DORA external functions
GRANT USAGE ON FUNCTION util_db.public.se_grader(VARCHAR,BOOLEAN,INTEGER,INTEGER,VARCHAR) TO ROLE aicollege;
GRANT USAGE ON FUNCTION util_db.public.se_greeting(VARCHAR,VARCHAR,VARCHAR,VARCHAR) TO ROLE aicollege;

-- -- SageMaker Network Policy Configuration (to be run once you get your SageMaker IP address after running a cell in SageMaker)
-- Create the network policy
-- CREATE NETWORK POLICY ALLOW_SAGEMAKER
--   ALLOWED_IP_LIST = ('<YOUR_SAGEMAKER_IP>')
--   COMMENT = 'Restrict access to SageMaker IPs for MLOps HOL';
--   -- Assign the policy to the service user only (NOT to the full account)
-- ALTER USER mlops_user SET NETWORK_POLICY = ALLOW_SAGEMAKER;
-- -- Confirm it's set correctly
-- DESC USER mlops_user;
