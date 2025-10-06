# Step 1: Load Required Libraries

library(survival)
install.packages("survminer")
library(survminer)
library(dplyr)
library(ggplot2)

# Step 2: Load Dataset

data <- read.csv("cirrhosis.csv")  
# View first few rows
head(data)

# Step 3: Data Preprocessing

# Check for missing values
cat("Missing values per column:\n")
print(colSums(is.na(data)))

cat("\nTotal missing values:", sum(is.na(data)), "\n")
cat("Proportion of missing data:", mean(is.na(data)) * 100, "%\n")

# Check rows with missing values
missing_rows <- nrow(data[!complete.cases(data), ])
cat("Number of rows with at least one missing value:", missing_rows, "\n")

install.packages("naniar")
library(naniar) # For missing data visualization
install.packages("mice")
library(mice)  # For imputation

# Visualize missingness
gg_miss_var(data, show_pct = TRUE) + 
  theme_minimal() + 
  labs(title = "Percentage of Missing Values by Variable")

# Save missingness summary
write.csv(data.frame(Variable = names(colSums(is.na(data))), Missing = colSums(is.na(data))), 
          "missing_values_summary.csv", row.names = FALSE)

# Rename columns if necessary
colnames(data) <- c("ID","N_Days","Status","Drug","Age","Gender","Ascites",
                    "Hepatomegaly","Spiders","Edema","Bilirubin","Cholesterol",
                    "Albumin","Copper","Alk_Phos","SGOT","Triglycerides",
                    "Platelets","Prothrombin","Stage")

# Convert categorical variables to factors
data$Status <- as.factor(data$Status)
data$Drug <- as.factor(data$Drug)
data$Gender <- as.factor(data$Gender)
data$Stage <- as.factor(data$Stage)
data$Ascites <- as.factor(data$Ascites)
data$Hepatomegaly <- as.factor(data$Hepatomegaly)
data$Spiders <- as.factor(data$Spiders)
data$Edema <- as.factor(data$Edema)

# Recode Status variable (1 = death, 0 = censored/survived)
data$Status <- ifelse(data$Status == "D", 1, 0)
table(data$Status, useNA = "always")

# Imputation using mice
imputed_data <- mice(data, m=5, method="pmm", maxit=50, seed=123)
data_imputed <- complete(imputed_data)
data <- data_imputed  # Use imputed data

# Create survival object
surv_obj <- Surv(time = data$N_Days, event = data$Status)

# Step 4: Kaplan-Meier Estimation
# Survival curves by Drug

km_drug <- survfit(surv_obj ~ Drug, data = data)

# Plot Kaplan-Meier curve
ggsurvplot(km_drug, data = data,
           pval = TRUE, conf.int = TRUE,
           risk.table = TRUE,
           ggtheme = theme_minimal(),
           title = "Kaplan-Meier Survival Curve by Drug Type",
           xlab = "Days", ylab = "Survival Probability")

# Survival curves by Disease Stage
km_stage <- survfit(surv_obj ~ Stage, data = data)
ggsurvplot(km_stage, data = data,
           pval = TRUE, conf.int = FALSE,
           risk.table = TRUE,
           ggtheme = theme_light(),
           title = "Kaplan-Meier Curve by Disease Stage")

# Step 5: Cox Proportional Hazards Model

cox_model <- coxph(surv_obj ~ Age + Drug + Bilirubin + Albumin + Prothrombin + Stage, data = data)
summary(cox_model)

# Step 6: Check Model Assumptions

test_ph <- cox.zph(cox_model)
test_ph
ggcoxzph(test_ph)  # plot Schoenfeld residuals

# Step 7: Visualize Variable Effects

ggforest(cox_model, data = data, main = "Hazard Ratios from Cox Model", cpositions = c(0.02, 0.22, 0.4))

# Step 8: Extract Median Survival Times

summary(km_drug)$table[, "median"]
summary(km_stage)$table[, "median"]

# Step 9: Save Results

write.csv(data, "cleaned_cirrhosis.csv", row.names = FALSE)
