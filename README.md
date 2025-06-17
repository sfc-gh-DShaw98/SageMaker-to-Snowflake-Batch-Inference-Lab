# SageMaker-to-Snowflake-Batch-Inference-Lab
In this lab, you’ll migrate an XGBoost model from SageMaker into Snowflake: log it in the Model Registry, perform batch inference via SQL, monitor performance and drift with ML Observability, and optionally retrain and promote a model version using Snowflake’s warehouse compute.

## What You’ll Do
- **Phase 1: SageMaker Training & Registration**
  - Train and evaluate an XGBoost model in SageMaker
  - Log the model into Snowflake Model Registry
  - Batch‑score historical data (Weeks 1–5)
- **Phase 2: Snowflake ML Observability**
  - Create a baseline and model monitor
  - Track metrics (F1‑score, AUC, drift) over time
  - Configure alerts for performance degradation
- **Phase 3: End‑to‑End Snowflake Retraining**
  - Feature engineer with Snowflake OneHotEncoder
  - Train and register a Snowflake‑native XGBoost model
  - Use EXPLAIN (SHAP) for insights
  - Promote via PRODUCTION alias and version‑agnostic scoring

#### Key Benefits:
- **Centralized Governance:** Version external models alongside your data
- **Frictionless Inference:** Batch‑score without managing containers or endpoints
- **Scalable Compute:** Leverage Snowflake warehouses for elasticity and performance
- **SQL‑First Analytics:** Empower analysts to explore predictions and performance
- **Automated Monitoring:** Detect drift and quality issues without leaving Snowflake

## Prerequisites
- Snowflake account & role with privileges to create databases, schemas, warehouses, stages, integrations
- AWS SageMaker Studio environment (SE‑Sandbox or equivalent)
- Python 3.8+ and packages: snowflake-ml-python, xgboost, scikit-learn
- Local files: connections.toml (store Snowflake credentials) and rsa_private_key.pem
