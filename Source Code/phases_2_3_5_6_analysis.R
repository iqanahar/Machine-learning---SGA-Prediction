library(pROC)
library(caret)
library(smotefamily)

run_sga_analysis <- function(vars, num_runs = 30, seed = 17205404) {
  
  result_summary <- data.frame(
    Run = integer(),
    Threshold = numeric(), 
    Sensitivity = numeric(),
    Specificity = numeric(), 
    Balanced_Accuracy = numeric(),
    Significant_Features = character(), 
    stringsAsFactors = FALSE
  )
  
  coef_matrix <- matrix(NA, nrow = num_runs, ncol = length(vars) + 1)
  colnames(coef_matrix) <- c("(Intercept)", vars)
  
  for (i in 1:num_runs) {
    file_name <- paste0("data", i, ".csv")
    df3 <- read.csv(file_name)
    df3$Actual <- factor(df3$Actual, levels = c("AGA", "SGA"))
    
    df_iter <- df3[, c(vars, "Actual", "train")]
    original_train <- subset(df_iter, train == 1)
    original_train$train <- NULL
    
    set.seed(seed)
    train.id <- createDataPartition(original_train$Actual, p = 0.7, list = FALSE) 
    
    temp.train <- original_train[train.id,]
    temp.val   <- original_train[-train.id,]
    
    # Find Optimal Threshold (Using 70% Train, 30% Val)
    scaler.temp <- preProcess(temp.train[, vars], method = c("center", "scale"))
    temp.train.scaled <- predict(scaler.temp, temp.train)
    temp.val.scaled   <- predict(scaler.temp, temp.val)
    
    model.temp <- glm(Actual ~ ., data = temp.train.scaled, family = "binomial")
    val.probs  <- predict(model.temp, newdata = temp.val.scaled, type = "response")
    roc.obj    <- roc(temp.val.scaled$Actual, val.probs, quiet = TRUE)
    opt_threshold <- coords(roc.obj, "best", best.method = "youden")$threshold[1]
    

    scaler.final <- preProcess(original_train[, vars], method = c("center", "scale"))
    final.train.scaled <- predict(scaler.final, original_train)
    model.final <- glm(Actual ~ ., data = final.train.scaled, family = "binomial")
    
    
    all_coefs <- coef(model.final)
    coef_matrix[i, names(all_coefs)] <- all_coefs
    
    
    p_vals <- summary(model.final)$coefficients[-1, 4]
    sig_vars <- names(p_vals)[p_vals < 0.05]
    sig_string <- if(length(sig_vars) > 0) paste(sig_vars, collapse = ", ") else "None"
    
    # INTERNAL TEST
    test_data <- subset(df_iter, train == 0)
    test_data$train <- NULL
    test_data_scaled <- predict(scaler.final, test_data)
    
    test_probs <- predict(model.final, newdata = test_data_scaled, type = "response")
    test_preds <- factor(ifelse(test_probs >= opt_threshold, "SGA", "AGA"), levels = c("AGA", "SGA"))
    
    cm <- table(Predicted = test_preds, Actual = test_data_scaled$Actual)
    sens <- if("SGA" %in% rownames(cm)) cm["SGA", "SGA"] / sum(test_data_scaled$Actual == "SGA") else 0
    spec <- if("AGA" %in% rownames(cm)) cm["AGA", "AGA"] / sum(test_data_scaled$Actual == "AGA") else 0
    
    result_summary[i, ] <- list(i, opt_threshold, sens, spec, (sens + spec)/2, sig_string)
  }
  
  
  # STABILITY ANALYSIS
  stability_df <- data.frame(
    Feature = colnames(coef_matrix)[-1],
    Mean_Coef = colMeans(coef_matrix, na.rm = TRUE)[-1],
    Std_Dev_Coef = apply(coef_matrix[,-1], 2, sd, na.rm = TRUE),
    Min_Coef = apply(coef_matrix[,-1], 2, min, na.rm = TRUE),
    Max_Coef = apply(coef_matrix[,-1], 2, max, na.rm = TRUE),
    Freq_Significant = sapply(colnames(coef_matrix)[-1], function(f) {
      sum(grepl(f, result_summary$Significant_Features))
    })
  )
  
  mean_thres <- mean(result_summary$Threshold)
  se_thres <- sd(result_summary$Threshold)/sqrt(num_runs)
  mean_sen <- mean(result_summary$Sensitivity); se_sen <- sd(result_summary$Sensitivity)/sqrt(num_runs)
  mean_spe <- mean(result_summary$Specificity); se_spe <- sd(result_summary$Specificity)/sqrt(num_runs)
  mean_bacc <- mean(result_summary$Balanced_Accuracy); se_bacc <- sd(result_summary$Balanced_Accuracy)/sqrt(num_runs)
  
  # Phase 5: Training on Malaysia & Testing on Singapore ---
  malaysia <- read.csv("Malaysia clean dataset for Machine Learning Model.csv")
  singapore <- read.csv("Singapore clean dataset.csv")
  
  singapore$age <- singapore$Mother.s.Age.at.Delivery
  singapore$Nuchal.fold.thickness <- singapore$Nuchal.Fold.Thickness..mm.
  singapore$GA_scan <- singapore$Gestational.Age.Scanned..week.*7 + singapore$Gestational.Age.Scanned..day.
  
  m_data <- malaysia[, c(vars, "Actual")]; m_data$Actual <- factor(m_data$Actual, levels = c("AGA", "SGA"))
  s_data <- singapore[, c(vars, "Actual")]; s_data$Actual <- factor(s_data$Actual, levels = c("AGA", "SGA"))
  
  set.seed(seed)
  scaler_master <- preProcess(m_data[, vars], method = c("center", "scale"))
  m_scaled <- predict(scaler_master, m_data)
  s_scaled <- predict(scaler_master, s_data)
  
  smote_out <- SMOTE(m_scaled[, vars], m_scaled$Actual, K = 5, dup_size = 2)
  m_smote <- smote_out$data; colnames(m_smote)[ncol(m_smote)] <- "Actual"
  m_smote$Actual <- factor(m_smote$Actual, levels = c("AGA", "SGA"))
  
  final_model <- glm(Actual ~ ., data = m_smote, family = "binomial")
  probs_sing <- predict(final_model, s_scaled, type = "response")
  preds_sing <- factor(ifelse(probs_sing >= mean_thres, "SGA", "AGA"), levels = c("AGA", "SGA"))
  
  boot_metrics <- replicate(2000, {
    idx <- sample(1:nrow(s_scaled), replace = TRUE)
    b_probs <- probs_sing[idx]; b_actual <- s_scaled$Actual[idx]
    b_preds <- factor(ifelse(b_probs >= mean_thres, "SGA", "AGA"), levels = c("AGA", "SGA"))
    tp <- sum(b_preds == "SGA" & b_actual == "SGA"); fn <- sum(b_preds == "AGA" & b_actual == "SGA")
    tn <- sum(b_preds == "AGA" & b_actual == "AGA"); fp <- sum(b_preds == "SGA" & b_actual == "AGA")
    b_sens <- tp / (tp + fn + 1e-10); b_spec <- tn / (tn + fp + 1e-10)
    return(c(b_sens, b_spec, (b_sens + b_spec)/2))
  })
  
  cm_final <- table(Predicted = preds_sing, Actual = s_data$Actual)
  final_sens <- if("SGA" %in% rownames(cm_final)) cm_final["SGA", "SGA"] / sum(s_data$Actual == "SGA") else 0
  final_spec <- if("AGA" %in% rownames(cm_final)) cm_final["AGA", "AGA"] / sum(s_data$Actual == "AGA") else 0
  final_bacc <- (final_sens + final_spec) / 2
  
  
  return(list(
    Summary_Table = result_summary,    
    Stability_Analysis = stability_df,
    Internal_Metrics = list(Mean_Threshold = c(mean_thres, se_thres), 
                            Sensitivity = c(mean_sen, se_sen), 
                            Specificity = c(mean_spe, se_spe), 
                            Bacc = c(mean_bacc, se_bacc)), 
    External_Metrics = list(Sensitivity = c(val = final_sens, ci = quantile(boot_metrics[1,], c(0.025, 0.975))),
                            Specificity = c(val = final_spec, ci = quantile(boot_metrics[2,], c(0.025, 0.975))),
                            Balanced_Acc = c(val = final_bacc, ci = quantile(boot_metrics[3,], c(0.025, 0.975)))
                            )
  ))
}



vars7 <- c("AC", "FL", "GA_scan","Nuchal.fold.thickness", "age", "HC", "BPD")
output <- run_sga_analysis(vars7)

print(output$Stability_Analysis)
lapply(output$Internal_Metrics, function(x) round(x, 2))
lapply(output$External_Metrics, function(x) round(x, 2))



vars4 <- c("AC", "FL", "GA_scan","Nuchal.fold.thickness")
output <- run_sga_analysis(vars4)

print(output$Stability_Analysis)
lapply(output$Internal_Metrics, function(x) round(x, 2))
lapply(output$External_Metrics, function(x) round(x, 2))



#4 CHOOSE 3 = 4

df3<-read.csv("data1.csv")
combo <- combn(colnames(df3[c(3:5,7)]),3)
var <- list()
output <- list()
for (i in 1:ncol(combo)){
  
  var[[i]] <-combo[,i]
  output[[i]]<-run_sga_analysis(var[[i]])
  print(output[[i]]$Stability_Analysis)
  lapply(output[i]$Internal_Metrics, function(x) round(x, 2))
  lapply(output[i]$External_Metrics, function(x) round(x, 2))

}


vars2 <- c("AC", "GA_scan")
output <- run_sga_analysis(vars2)

print(output$Stability_Analysis)
lapply(output$Internal_Metrics, function(x) round(x, 2))
lapply(output$External_Metrics, function(x) round(x, 2))


