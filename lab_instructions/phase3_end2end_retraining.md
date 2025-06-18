# Phase 3: End-to-End Model Retraining in Snowflake ML

This guide walks you through retraining your model entirely within Snowflake, using native ML capabilities for feature engineering, model training, explainability, and production deployment.

## 3.1 Setup: Load Training Data into Snowflake
1. Log in to your Snowflake account
2. Upload the following to your aicollege.public.setup stage:
    - [NewTrainingData.csv](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/data/NewTrainingData.csv) – updated dataset for retraining
    - [SnowflakeML.jpg](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/images/SnowflakeML.jpg) – image for visual documentation
3. Run this setup SQL in a Snowsight worksheet:
```sql
USE ROLE AICOLLEGE;

-- Create retraining model data table
CREATE OR REPLACE TABLE AICOLLEGE.PUBLIC.NEWTRAININGDATA (
    WEEK_START_DATE TIMESTAMP_NTZ,
    WEEK NUMBER(38, 0),
    LOAN_ID NUMBER(38, 0),
    TS VARCHAR,
    LOAN_TYPE_NAME VARCHAR,
    LOAN_PURPOSE_NAME VARCHAR,
    APPLICANT_INCOME_000S NUMBER(38, 0),
    LOAN_AMOUNT_000S NUMBER(38, 0),
    COUNTY_NAME VARCHAR,
    MORTGAGERESPONSE NUMBER(38, 0)
);

-- Load the enriched dataset from your Snowflake stage
COPY INTO AICOLLEGE.PUBLIC.NEWTRAININGDATA
FROM @AICOLLEGE.PUBLIC.SETUP
FILES = ('NewTrainingData.csv')  -- Case-sensitive match required
FILE_FORMAT = aicollege.public.mlops
ON_ERROR = CONTINUE;
```

## 3.2 Snowflake Notebook Setup with Container Runtime
1. Use **AICOLLEGE** Role
2. Navigate to **Projects** and then **Notebooks**
3. Select the **v** beside the **+ Notebook** button
4. Select **Import .ipynb** file option
5. Import the [MLOPs End-to-End Snowflake ML Retraining Exercise](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/notebooks/MLOPs%20End-to-End%20Snowflake%20ML%20Retraining%20Exercise.ipynb) notebook
6. Select **AICOLLEGE** and **PUBLIC** for Notebook location
7. Select **Run on container** for Runtime
8. Select **Snowflake ML Runtime CPU 1.0** for runtime
9. Select **SYSTEM_COMPUTE_POOL_CPU** for compute pool
10. Select **AICOLLEGE** for Query warehouse
11. Select **Create**
12. In the left sidebar of your Snowflake Notebook (where the notebook title is shown), click the **+** icon.
13. Upload the [environment.yml](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/config/environment.yml) file
14. After uploading, click **Start** to apply the environment.
15. Snowflake will build the runtime with your specified packages *(this may take a few minutes on first use)*.

## 3.3 Customize the Notebook
Throughout the notebook, you'll find several placeholders marked `XXX` that need to be replaced:

|**Cell Context**|**Replace XXX With**|
|----------------|-----------------|
|**Use Snowflake ML Modeling Preprocessing `One Hot Encoder function** ohe = XXX|`OneHotEncoder`|
|**Initialize Feature Store** fs = XXX|`FeatureStore`|
|**Create Feature Entity** loan_entity = XXX(name="XXX", join_keys=["LOAN_ID"])|`Entity` and "`LOAN_ENTITY`"|
|**Register Feature View** fv = XXX(name="XXX",entities=[loan_entity],|`FeatureView` and "`LOAN_FEATURES_OHE`"|
|**Target column for retraining** label = "XXX"|"`MORTGAGERESPONSE`"|
|**Register Version 2**model=logreg_model,model_name="XXX",version_name="XXX",|"`COLLEGE_AI_HOL_XGB_MORTGAGE_MODEL`", "`v2`"|
|**Run Model Explainability** function_name="XXX"|"`EXPLAIN`"|
|**Set model alias** SET XXX|"`PRODUCTION`"|
|**Read features for batch-scoring pipeline inference** df_features = session.table("XXX")|"`AICOLLEGE.PUBLIC.LOAN_FEATURES_OHE$1`"|

## 3.4 Key Notebook Steps
The notebook will guide you through:

### 3.4.1 Feature Engineering with Snowpark ML
```python
# Example: Using OneHotEncoder for categorical features
ohe = OneHotEncoder()
ohe.fit(df[categorical_cols])
encoded_features = ohe.transform(df[categorical_cols])
```

### 3.4.2 Feature Store Registration
```python
# Example: Registering features in Snowflake Feature Store
fs = FeatureStore(session, database="AICOLLEGE", name="PUBLIC")
loan_entity = Entity(name="LOAN_ENTITY", join_keys=["LOAN_ID"])
fv = FeatureView(name="LOAN_FEATURES_OHE",
                 entities=[loan_entity],
                 feature_df=df_features,
                 timestamp_col="WEEK_START_DATE")
fs.register_feature_view(fv, version="1", overwrite=True)
```
### 3.4.3 Model Training in Snowflake
```python
# Example: Training XGBoost model natively in Snowflake
from snowflake.ml.modeling.xgboost

import XGBClassifier
xgb_model = XGBClassifier(
    n_estimators=100,
    max_depth=6,
    learning_rate=0.3,
    objective="binary:logistic")

xgb_model.fit(X_train, y_train)
```

### 3.4.4 Model Registration
```python
# Example: Registering model in Snowflake Model Registry
registry.log_model(
    model=xgb_model,
    model_name="COLLEGE_AI_HOL_XGB_MORTGAGE_MODEL",
    version_name="v2",
    enable_explainability=True,
    sample_input_data=X_train.sample(5, random_state=42).astype("float32"))
```

### 3.4.5 Model Explainability
```python
# Example: Using Snowflake's built-in explainability
shap_df = model_v2.run(sample_df, function_name="EXPLAIN")
```

### 3.4.6 Model Promotion via Aliases
```sql
-- Example: Promoting v2 to production

ALTER MODEL COLLEGE_AI_HOL_XGB_MORTGAGE_MODEL 
VERSION V2 SET ALIAS = PRODUCTION;
```

### 3.4.7 Version-Agnostic Batch Scoring
```python
# Example: Scoring using the PRODUCTION alias
df_features = session.table("AICOLLEGE.PUBLIC.LOAN_FEATURES_OHE$1")
scores = model_prod.run(df_features, function_name="PREDICT_PROBA")
```

## 3.5 Complete DORA Evaluations
The notebook includes two DORA evaluation steps that must be completed:

|**DORA Step**|**Purpose**|
|----------------|-----------------|
|SEAI53|Verifies that Model Version V2 has been successfully registered|
|SEAI54|Ensures that Version V2 has been assigned the PRODUCTION alias|

A ✅ checkmark will appear when each evaluation completes successfully.

## Next Steps
Congratulations! You've completed all three phases of the lab:

1. Trained a model in SageMaker and registered it in Snowflake
2. Set up ML Observability to monitor model performance
3. Retrained the model natively in Snowflake and promoted it to production

You now have a complete MLOps workflow that spans model development, monitoring, and retraining—all within Snowflake.
