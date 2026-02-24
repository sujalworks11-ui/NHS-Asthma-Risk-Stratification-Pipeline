🫁 NHS Asthma Risk Stratification Pipeline

📌 Project Overview

This project presents a complete, end-to-end data mining and machine learning pipeline designed to predict patient asthma outcomes (asthma_worsened). Following the CRISP-DM framework, the project transitions from raw clinical data ingestion and robust SQL-based feature engineering to advanced predictive modeling using MATLAB. The primary goal is to stratify patient risk by analyzing demographics, physiological metrics, comorbidities, and environmental pollution factors.

📊 Dataset

Raw Data (dataset.csv): Contains longitudinal clinical records, including SNOMED codes for medical conditions, blood pressure readings, cholesterol levels, smoking status, and geographical distance to motorways (mwaydist_km1).
Target Variable: asthma_worsened (Binary classification: 0 = No, 1 = Yes).

🛠️ Technologies & Tools

SQL (Oracle PL/SQL): Database management, data cleaning, and feature engineering.
MATLAB: Missing data imputation, exploratory data analysis (EDA), and machine learning model training/evaluation.

🚀 Workflow & Methodology

1. Feature Engineering & Data Cleaning (SQL)
   
The Feature engineering.sql script applies rigorous data quality rules and builds a modeling view via Common Table Expressions (CTEs).
Data Standardization: Converts complex medical codes into binary flags for diabetes (c_diabetes), smoking (c_smoker), cardiovascular medications (c_cvdrx), and family history (c_fh_asthma).
Physiological Derivations: Calculates derived metrics like pulse pressure (pulse_pressure) and flags clinical hypertension (c_htn).
Environmental Risk Categorization: Transforms raw distance-to-motorway data into categorical pollution risk bands (c_dist_band).
Outlier Handling: Identifies and filters out implausible blood pressure and cholesterol readings.

2. Preprocessing & Exploratory Data Analysis (MATLAB)
   
The NHS Asthma Risk Stratification Pipeline.m script prepares the cleaned SQL data for modeling.
Imputation: Handles missing data by assuming 0 for unknown smoking statuses and utilizing median imputation for missing cholesterol ratios (CHOL_HDL_RATIO).
Categorical Encoding: Converts standard features like GENDER, POLLUTION_RISK_BAND, and the target ASTHMA_WORSENED into categorical arrays.
EDA: Generates statistical summaries and visualizes distributions, such as plotting age against asthma worsening using boxplots.

3. Machine Learning Modeling (MATLAB)
   
The pipeline trains and evaluates three distinct supervised learning algorithms to classify the risk of asthma worsening:
Decision Tree
Random Forest
K-Nearest Neighbors (KNN)

4. Model Evaluation
   
The models are rigorously compared using a suite of performance metrics to determine the most effective classification strategy.
Metrics Calculated: Sensitivity (Recall), Specificity, Precision, and F1 Score.
Visualizations: Generates comparative ROC (Receiver Operating Characteristic) curves and calculates the AUC (Area Under the Curve) for all three models against a random guess baseline.

⚙️ How to Run the Pipeline

Import dataset.csv into your SQL environment.
Execute Feature engineering.sql to build the required tables, perform idempotent column additions, and generate the final vw_patient_features_cte view.
Export the resulting view to a CSV file (e.g., cleaneddata.csv).
Open MATLAB and ensure the exported CSV is in your active directory.
Run NHS Asthma Risk Stratification Pipeline.m to execute the preprocessing, train the machine learning models, and output the evaluation metrics and ROC curves.
