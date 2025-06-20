# Phase 2: Model Monitoring with Snowflake ML Observability

This guide walks you through setting up [Snowflake ML Observability](https://docs.snowflake.com/en/developer-guide/snowflake-ml/model-registry/model-observability) to monitor your model's performance and detect drift over time.

## 2.1 Snowflake Notebook Setup
1. Log in to your Snowflake account
2. Use **AICOLLEGE** Role
3. Click on **Projects** and then **Notebooks**
4. Select the **v** beside the **+ Notebook** button
5. Select **Import .ipynb** file option
6. Import the [MLOPs Snowflake ML Observability In Action Exercise](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/notebooks/MLOPs%20Snowflake%20ML%20Observability%20In%20Action%20Exercise.ipynb) notebook
7. Select **AICOLLEGE** and **PUBLIC** for Notebook location
8. Select **Run on warehouse** for Runtime
9. Select **Create**
10. Go to your **Snowflake Notebooks Packages**
11. Select **Packages**, type matplotlib, **Select matplotlib**

## 2.2 Customize the Notebook
Throughout the notebook, you'll find several placeholders marked `XXX` that need to be replaced:

|**Cell Context**|**Replace XXX With**|
|----------------|-----------------|
|CREATE OR REPLACE TABLE XXX AS ... and FROM XXX|`AICOLLEGE.PUBLIC.BASELINE_PREDICTIONS` and `AICOLLEGE.PUBLIC.PREDICTIONS_WITH_GROUND_TRUTH`|
|XXX_MODEL_NAME, FUNCTION = 'XXX', PREDICTION_CLASS_COLUMNS = ('XXX'), and PREDICTION_SCORE_COLUMNS = ('XXX')|`COLLEGE_AI_HOL_XGB_MORTGAGE_MODEL`, `predict`, `PREDICTED_RESPONSE`, and `PREDICTED_SCORE`|
|CREATE ALERT XXX, and METRIC_VALUE < XXX|`F1_SCORE_DROP_ALERT` and `0.7`|
|SOURCE = XXX|`ALL_PREDICTIONS_WITH_GROUND_TRUTH`|
|FROM TABLE(XXX(...))|`MODEL_MONITOR_PERFORMANCE_METRIC(...)`|

## 2.3 Key Notebook Steps
The notebook will guide you through:

1. Creating a baseline using early inference data (Weeks 1-5)
2. Registering a model monitor to track predictions, features, and targets over time
3. Monitoring drift and performance metrics using SQL and Snowsight
4. Creating a triggerable alert when F1-score falls below a threshold (0.7)
5. Visualizing trends using Altair charts in Python

### 2.3.1 Setting Up the Baseline
The baseline is a reference point representing your model's healthy behavior. You'll create this from your initial predictions (Weeks 1-5).

### 2.3.2 Configuring the Model Monitor
You'll set up a model monitor that tracks:
  - Input features (e.g., `APPLICANT_INCOME_000S`, `LOAN_AMOUNT_000S`)
  - Predictions (`PREDICTED_RESPONSE`)
  - Prediction scores (`PREDICTED_SCORE`)
  - Ground truth (`MORTGAGERESPONSE`)

### 2.3.3 Tracking Performance Metrics
The monitor automatically calculates:
  - Classification metrics (accuracy, precision, recall, F1-score)
  - Statistical drift measures for inputs and predictions
  - Trends over your specified time windows

### 2.3.4 Creating Alerts
You'll create an alert that triggers when the F1-score drops below 0.7, which can:
  - Send an email notification
  - Signal when model retraining might be needed

### 2.3.5 Visualizing Model Performance
The notebook includes visualization code to help you:
- Track performance metrics over time
- Identify when drift occurs
- Understand how your model's behavior changes across different weeks

## 2.4 Complete DORA Evaluation
The notebook includes a DORA evaluation step that must be completed:

|**DORA Step**|**Purpose**|
|----------------|-----------------|
|SEAI52|Verifies that your ML Observability setup is correct|

A ✅ checkmark will appear when the evaluation completes successfully.

## Next Steps
After completing this phase, proceed to [**Phase 3: End-to-End Model Retraining in Snowflake ML**](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/lab_instructions/phase3_end2end_retraining.md) to learn how to retrain your model when performance degrades.
