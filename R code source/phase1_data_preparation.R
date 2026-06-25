setwd("C:/Users/HP/OneDrive/Desktop/RESEARCH PROJECT")
df <- read.csv("Malaysia clean dataset for Machine Learning Model.csv")

df$Actual <- as.factor(df$Actual)

table(df$Actual)

df2 <- df[, -c(1,4,6,7,9,11:17,20)]

df_aga <- subset(df2, Actual == "AGA")
df_sga <- subset(df2, Actual == "SGA")


set.seed(17205404)

for (i in 1:30) {
  
  # Stratified Random Split: Create Testing Data (900 AGA, 100 SGA)
  test_aga_idx <- sample(nrow(df_aga), 900)
  test_sga_idx <- sample(nrow(df_sga), 100)
  
  test_data <- rbind(df_aga[test_aga_idx, ], 
                     df_sga[test_sga_idx, ])
  
  # Isolate the remaining data for the Training data
  df_aga_remaining <- df_aga[-test_aga_idx, ] 
  df_sga_remaining <- df_sga[-test_sga_idx, ] 
  
  # Undersampling of majority class: Achieve 1:2.33 ratio (1376 AGA, 590 SGA)
  train_aga_idx <- sample(nrow(df_aga_remaining), 1376)
  
  train_data <- rbind(df_aga_remaining[train_aga_idx, ], 
                      df_sga_remaining)
  
  test_data <- test_data[sample(nrow(test_data)), ]
  train_data <- train_data[sample(nrow(train_data)), ]
  
  
  train_data$train <- 1
  test_data$train <- 0
  
  # Combine them into a single dataframe
  df3 <- rbind(train_data, test_data)
  
  # Shuffle the final dataframe
  df3 <- df3[sample(nrow(df3)), ]
  
  file_name <- paste0("data", i, ".csv")
  
  write.csv(df3, file = file_name, quote = FALSE, row.names = FALSE)
  

  cat("Successfully saved", file_name, "\n")
}