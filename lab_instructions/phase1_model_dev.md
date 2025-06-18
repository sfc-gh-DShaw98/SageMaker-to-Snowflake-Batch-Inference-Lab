# Phase 1: Model Development & SageMaker Integration - Initial Model Registration

This guide walks you through training an XGBoost model in SageMaker and registering it in Snowflake Model Registry for batch inference.

## 1.3 Model Development in SageMaker

### 1.3.1 Open the Notebook
1. In your JupyterLab environment, open the [College-of-AI-MLOPsExerciseNotebook.ipynb](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/notebooks/College-of-AI-MLOPsExerciseNotebook.ipynb) notebook
2. Ensure you're using the Python 3 (ipykernel) kernel

### 1.3.2 Customize the Notebook
1. Throughout the notebook, you'll find several placeholders marked XXX that need to be replaced:

|**Cell Context**|**Replace `XXX` With**|
|----------------|-----------------|
|categorical_cols = ["LOAN_TYPE_NAME", "XXX", "XXX"]|"`LOAN_PURPOSE_NAME`" and "`COUNTY_NAME`"|
|X = df_encoded.drop(columns=["XXX"]) and y = df_encoded.loc[X.index, "XXX"]|"`MORTGAGERESPONSE`"|
|test_size=XXX|`0.2` for holdout and 0.25 for `0.25` for validation|
|SET ALLOWED_IP_LIST = ('XXX.XXX.XXX.XXX')|Your SageMaker IP from `!curl ifconfig.me`|
|config = toml.load("XXX")|"`connections.toml`"|
|params = config["connections"]["XXX"]|Use "`Snowpark_MLOps_HOL`"|
|sample_input_data = XXX.astype(...)|`X_train.astype("float32").sample(5, random_state=42)`|
|model=XXX|`model`|
|model_name='XXX'|'`COLLEGE_AI_HOL_XGB_MORTGAGE_MODEL`'|
|version_name='XXX'|'`v1`'|
|conda_dependencies=['XXX']|"`xgboost`"|
|session.table("XXX").filter("XXX")|"`InferenceMortgageData`" and "`WEEK = 1`"|
|registry.get_model("XXX"), model.version("XXX")|"`COLLEGE_AI_HOL_XGB_MORTGAGE_MODEL`", "`v1`"|
|pred_series = pd.Series(np.squeeze(predictions), name="XXX")|"`PREDICTED_RESPONSE`"|
|score_series = pd.Series(np.array(proba_predictions)[:, 1], name="XXX")|"`PREDICTED_SCORE`"|
|save_as_table("XXX")|"`PREDICTIONS_WITH_GROUND_TRUTH`"|
|raw_all_df["XXX"] = pd.Series(np.squeeze(predictions))|"`PREDICTED_RESPONSE`"|
|raw_all_df["XXX"] = pd.Series(np.array(proba_predictions))|"`PREDICTED_SCORE`"|

### 1.3.3 Key Notebook Steps
The notebook will guide you through:

1. Loading historical mortgage data from Snowflake
2. Preprocessing the data (drop nulls, one-hot encode, select numeric features)
3. Training a binary classification model using XGBoost
4. Evaluating the model with precision, recall, and confusion matrix
5. Saving the model locally
6. Registering the model into Snowflake Model Registry using log_model()
7. Running batch inference on mortgage data (Weeks 1-5)
8. Saving predictions and scores with ground truth back in Snowflake

### 1.3.4 Complete DORA Evaluations
The notebook includes two DORA evaluation steps that must be completed:

|**DORA**|**Step	Purpose**|
|------------------|------------------------|
|SEAI50|Confirms your SageMaker model was successfully registered in Snowflake|
|SEAI51|Confirms you completed batch inference in Snowflake|

A ✅ checkmark will appear if each evaluation is completed successfully.

### 1.3.5 SageMaker Warnings
As you run the notebook, you may see messages that look like errors:

- pip's dependency resolver conflicts
- TensorFlow CPU optimization notices
These are normal SageMaker environment warnings and will not prevent you from completing the lab.

## 1.3.6 Clean Up Your SageMaker Resources
Once you've completed the notebook:

1. In the SageMaker Studio left sidebar, click Applications > JupyterLab
2. Locate your active JupyterLab Space in the list
3. Click the three-dot menu (⋮) next to the space name
4. Choose Stop and wait for the status to change to "Stopped"
5. Once stopped, click the three-dot menu (⋮) again and select Delete
6. Confirm the deletion when prompted

## Next Steps
After completing this phase, proceed to [**Phase 2: Model Monitoring with Snowflake ML Observability**]() to set up monitoring for your registered model.
