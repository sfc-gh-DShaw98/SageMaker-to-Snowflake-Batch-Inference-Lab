# Vertex AI → Snowflake Model Registry Lab  
*End-to-end batch-inference workflow on Google Cloud*

| Notebook | What it shows | Link |
|----------|---------------|------|
| **Part 1 – Vertex AI → Snowflake** | Train XGBoost in Vertex AI Workbench, register in Snowflake Model Registry, batch-score new data | [`Vertex AI Model to Snowflake Model Registry.ipynb`](/notebooks/Vertex%20AI%20Model%20to%20Snowflake%20Model%20Registry.ipynb) |
| **Part 2 – Explainability** | Use **Snowflake ML Explainability** to compute feature importance and SHAP values on the registered model | [`MLOPs Snowflake ML Observability In Action for Vertex AI Model.ipynb`](/notebooks/MLOPs%20Snowflake%20ML%20Observability%20In%20Action%20for%20Vertex%20AI%20Model.ipynb) |
| **Part 3 - Retraining** | Use other **Snowflake** features like Feature Store, ML Observability, Model Alias to migrate your Vertex AI model to end-to-end Snowflake ML | [`MLOPs End-to-End Snowflake ML Retraining Solution for Vertex AI model.ipynb`](/notebooks/MLOPs%20End-to-End%20Snowflake%20ML%20Retraining%20Solution%20for%20Vertex%20AI%20model.ipynb)|

> *Tip:* Open each notebook directly in **Vertex AI Workbench** (File ▸ Open from GitHub) or clone the repo locally and upload the files.

## 0. Prerequisites

| Tool / Service | Why you need it | Quick link |
|----------------|-----------------|-----------|
| **Google Cloud project** (owner or editor) | Run Vertex AI Workbench & Cloud Storage | [console](https://console.cloud.google.com/) |
| **Snowflake account** (role with CREATE MODEL) | Register & score the model | [signup](https://signup.snowflake.com/) |
| **Vertex AI Workbench** (Python 3 kernel) | Managed Jupyter VM for training | Vertex AI > Workbench |
| **`connections.toml` + `rsa_private_key.pem`** | Store Snowflake creds & JWT key | See step 5 |

---

## 1. Enable required GCP services

```bash
gcloud config set project <YOUR_PROJECT_ID>
gcloud services enable storage.googleapis.com
gcloud services enable aiplatform.googleapis.com
```

## 2. Create a Cloud Storage bucket & upload data
```bash
REGION=us-central1
BUCKET=mlops-xgb-bucket-$(date +%s)
gsutil mb -l $REGION gs://$BUCKET
gsutil cp ./MORTGAGE_LENDING_DEMO_DATA.csv gs://$BUCKET/
```

## 3. Spin up a Vertex AI Workbench instance
| Setting           | Value                               |
| ----------------- | ----------------------------------- |
| **Name**          | `vertex-xgb-notebook`               |
| **Region / Zone** | `us-central1-a` (or same as bucket) |
| **Machine**       | `e2-standard-4`                     |
| **GPUs**          | *None*                              |
| **Environment**   | Python 3 (latest)                   |

- Once the status is **Active**, click **OPEN JUPYTERLAB**.

## 4. Install Python dependencies (notebook cell)
```python
!pip install --quiet \
    google-cloud-aiplatform \
    snowflake-ml-python snowflake-connector-python \
    xgboost pandas scikit-learn gcsfs toml cryptography
```
- Restart the kernel.

## 5. Securely store Snowflake credentials
[**connections.toml**](https://github.com/sfc-gh-DShaw98/SageMaker-to-Snowflake-Batch-Inference-Lab/blob/main/config/connections.toml)
```toml
[connections.Snowpark_MLOps_HOL]
account      = "<acct>"
user         = "<user>"
role         = "<role>"
warehouse    = "<warehouse>"
database     = "<database>"
schema       = "<schema>"
authenticator = "snowflake_jwt"
```

- **Upload both files:**
  - connections.toml
  - rsa_private_key.pem (your Snowflake JWT private key)

- Drag-and-drop into the JupyterLab file browser.

## 6. Configuration cell
```python
# CSV in Cloud Storage
GCS_URI = "gs://<BUCKET>/MORTGAGE_LENDING_DEMO_DATA.csv"

# Load Snowflake creds
import toml, pathlib
cfg = toml.load("connections.toml")["connections"]["Snowpark_MLOps_HOL"]

from cryptography.hazmat.primitives import serialization
key = serialization.load_pem_private_key(
    open("rsa_private_key.pem","rb").read(), password=None
)

SF_CFG = {**cfg, "private_key": key}

from snowflake.snowpark import Session
session = Session.builder.configs(SF_CFG).create()
```

## 7. Load & prep data
```python
import pandas as pd

df = pd.read_csv(GCS_URI)
categorical_cols = ["LOAN_TYPE_NAME","LOAN_PURPOSE_NAME","COUNTY_NAME"]

df_clean = df.dropna()
df_encoded = pd.get_dummies(df_clean, columns=categorical_cols, drop_first=True)

y = df_encoded["MORTGAGERESPONSE"]
X = df_encoded.drop(columns=["MORTGAGERESPONSE"])
```

## 8. Train & evaluate XGBoost
```python
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import xgboost as xgb

X_tr, X_val, y_tr, y_val = train_test_split(
    X, y, test_size=0.25, random_state=42, stratify=y
)

model = xgb.XGBClassifier(eval_metric="logloss")
model.fit(X_tr, y_tr)

val_acc = accuracy_score(y_val, model.predict(X_val))
print("Validation accuracy:", val_acc)
```

## 9. Register model in Snowflake Model Registry
```python
from snowflake.ml.registry import Registry

sample_input = X_tr.head(5).copy()
registry = Registry(session=session)

mv = registry.log_model(
    model              = model,
    model_name         = "VERTEX_XGB_MORTGAGE",
    version_name       = "v1",
    sample_input_data  = sample_input,
    metrics            = {"accuracy": float(val_acc)},
)
```

## 10. Add governance tags (optional)
```python
# Create tags (once)
for tag in ["MODEL_STAGE_TAG","PURPOSE_TAG"]:
    session.sql(f"CREATE OR REPLACE TAG {tag}").collect()

# Attach to model
mv.set_tag("MODEL_STAGE_TAG", "PROD")
mv.set_tag("PURPOSE_TAG",    "Mortgage Response Scoring")
mv.show_tags()
```

## 11. Batch-score Week 1 data
```python
# Pull raw data
inference_df = (
    session.table("INFERENCEMORTGAGEDATA")
           .filter("WEEK = 1")
           .to_pandas()
)

# One-hot encode & align
inf_enc = pd.get_dummies(inference_df, columns=categorical_cols, drop_first=True)
for col in X.columns:
    if col not in inf_enc: inf_enc[col] = 0
inf_enc = inf_enc[X.columns]

# Run predictions
preds  = mv.run(inf_enc, function_name="predict")
proba  = mv.run(inf_enc, function_name="predict_proba")

# Merge & write back
results = inference_df.copy()
results["PREDICTION"]      = preds
results["PREDICTED_SCORE"] = proba[:,1]

session.write_pandas(
    results,
    table_name="PREDICTIONS_WITH_GROUND_TRUTH",
    auto_create_table=True,
    overwrite=True
)
```

## 12. Next steps
- Deploy the model as a Snowflake UDF for real-time scoring.
- Schedule the notebook or a Snowpark Stored Procedure for daily/weekly batch runs.
- Track model drift by comparing PREDICTED_SCORE vs. true MORTGAGERESPONSE.

---

### Cleanup
```bash
# Stop the Workbench VM to avoid charges
#   Vertex AI ▸ Workbench ▸ Stop instance
gsutil rm -r gs://<BUCKET>
```

🎉 *You’ve completed the Vertex AI → Snowflake Model Registry lab!*
The pipeline loads data from Cloud Storage, trains in Vertex AI Workbench, registers in Snowflake, adds governance tags, and batch-scores new data—mirroring the Azure ML workflow but entirely on Google Cloud.
