# Machine Learning Prediction of Small-for-Gestational-Age Births: A Model Robustness Assessment

This repository contains the datasets, R source code, and automation bash scripts used in this research. The study establishes a robust machine learning framework to evaluate feature stability and model generalisability for small-for-gestational-age (SGA) screening using routine second-trimester ultrasound biometry. 

## 📁 Repository Structure & Files 
This repository is organised into three main components: 

- **Data**
  - Contains the primary Malaysian cohort dataset used for development and internal modeling. 
  - Contains the independent external Singaporean validation cohort dataset.

- **Source Code**
  - `phase1_data_preparation.R`: Handles data preprocessing and preparation. 
  - `phases_2_3_5_6_analysis.R`: Executes the core statistical modeling, clearly split by data scope: 
    - **Phases 2 & 3:** Implements a 30-run repeated random subsampling framework on the Malaysian data to evaluate baseline logistic regression feature stability and optimise thresholds. 
    - **Phases 5 & 6 (Full Cohort Validation):** Trains a final model on the *entire* primary Malaysian cohort (rebalanced via SMOTE) and evaluates its performance against the *entire* independent Singaporean validation dataset, followed by systematic feature ablation studies. 

- **Scripts/ (Linux Bash Automation)**
  - `guide.sh`: Automates the execution of the GUIDE decision tree algorithm across the 30 resampled subsets. 
  - `results.sh`: Extracts and aggregates terminal outputs, performance metrics, and root/intermediate node selections into a clean summary file (`results.txt`). 

---

## 💻 Environment & Execution Guide

### R Environment & Dependencies (Phases 1, 2, 3, 5, 6)
The statistical modeling, resampling, and validation pipelines were built using **R (version 4.5.0)**. The core packages required to replicate the pipeline are:

- `pROC` (v1.19.0.1): ROC curve computation and mathematical optimization of Youden's Index.
- `caret` (v7.0.1): Data partitioning baseline and evaluation metrics management.
- `smotefamily` (v1.4.0): Synthetic Minority Over-sampling Technique to rebalance the primary cohort for external validation.

To install the necessary packages, run the following command in your R console:
```r
install.packages(c("pROC", "caret", "smotefamily"))
```

### Phase 4 Automation (GUIDE Tree Run)
Phase 4 handles the cross-methodological verification using the *GUIDE algorithm (Version 43.0)*.

⚠️ *Note:* Due to the compilation requirements of the GUIDE executable, *Phase 4 must be run within a Linux-based Ubuntu environment (such as via Windows Subsystem for Linux - WSL)* using the provided automation scripts.

Navigate to your scripts directory in your WSL terminal and execute the pipeline sequentially:


```bash
# Make the automated bash scripts executable
chmod +x guide.sh results.sh

# Run the 30-run decision tree model generation
./guide.sh

# Extract root/intermediate nodes and compile results into results.txt
./results.sh
```
