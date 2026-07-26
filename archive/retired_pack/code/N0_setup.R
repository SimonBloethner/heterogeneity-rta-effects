# N0: Setup
library(data.table)
library(fixest)

set.seed(20260719)

cat("============================================================\n")
cat("N0: SETUP — PPML Model Estimation\n")
cat("============================================================\n\n")

total <- readRDS("/groups/m-larch/bt307958/tails/data/ITPDE_total.rds")
setDT(total)

cat("Loaded", nrow(total), "observations\n")

total[, pair := paste(exporter, importer, sep = "_")]
total <- total[exporter != importer & trade > 0]
n_original <- nrow(total)
cat("After filtering:", n_original, "observations\n\n")

total[, pair_fe := pair]
total[, exp_year := paste(exporter, year, sep = "_")]
total[, imp_year := paste(importer, year, sep = "_")]
total[, row_idx := .I]

cat("Estimating PPML model...\n")

model_full <- fepois(
    trade ~ rta | pair_fe + exp_year + imp_year,
    data = total,
    cluster = ~pair_fe
)

cat("RTA coefficient:", round(coef(model_full)["rta"], 4), "\n")
cat("N obs in model:", nobs(model_full), "\n")

n_model <- nobs(model_full)
fit_vals <- fitted(model_full)

removed_idx <- model_full$obs_selection$obsRemoved

if (length(removed_idx) > 0) {
    removed_idx <- abs(removed_idx)
    cat("Removing", length(removed_idx), "observations\n")
    total_used <- total[-removed_idx]
} else {
    total_used <- total
}

cat("total_used rows:", nrow(total_used), "\n")

stopifnot(nrow(total_used) == length(fit_vals))

total_used[, y_hat := fit_vals]

cat("Computing counterfactual...\n")
total_cf <- copy(total_used)
total_cf[, rta := 0]
total_used[, y_hat_0 := predict(model_full, newdata = total_cf, type = "response")]

total_used <- total_used[!is.na(y_hat) & !is.na(y_hat_0)]
cat("Final observations:", nrow(total_used), "\n\n")

# Pair info
rta_pairs <- total_used[rta == 1, .(adoption_year = min(year)), by = pair]
setkey(rta_pairs, pair)

never_treated <- setdiff(unique(total_used$pair), rta_pairs$pair)

cat("RTA pairs:", nrow(rta_pairs), "\n")
cat("Never-treated:", length(never_treated), "\n\n")

pair_trade <- total_used[, .(total_trade = sum(trade)), by = pair]
setkey(pair_trade, pair)

breaks <- quantile(pair_trade$total_trade, probs = seq(0, 1, 0.1), na.rm = TRUE)
breaks <- unique(breaks)
n_bins <- length(breaks) - 1
cat("Creating", n_bins, "size bins\n")

pair_trade[, size_decile := as.numeric(cut(total_trade, breaks = breaks,
    labels = 1:n_bins, include.lowest = TRUE))]

total_used <- merge(total_used, pair_trade[, .(pair, total_trade, size_decile)], by = "pair")
total_used <- merge(total_used, rta_pairs, by = "pair", all.x = TRUE)

total_used[, pre := year < adoption_year]
total_used[, post := year >= adoption_year]
total_used[is.na(adoption_year), c("pre", "post") := FALSE]

# Save to /scratch first then copy
cat("\nSaving to /scratch...\n")
outdir <- "/scratch/bt307958"

saveRDS(total_used, file.path(outdir, "N0_data.rds"), compress = FALSE)
Sys.sleep(1)  # Wait for write to complete

saveRDS(pair_trade, file.path(outdir, "N0_pair_trade.rds"), compress = FALSE)
saveRDS(rta_pairs, file.path(outdir, "N0_rta_pairs.rds"), compress = FALSE)

model_summary <- list(
    rta_coef = coef(model_full)["rta"],
    rta_se = se(model_full)["rta"],
    n_obs = nrow(total_used),
    n_rta_pairs = nrow(rta_pairs),
    n_never = length(never_treated)
)
saveRDS(model_summary, file.path(outdir, "N0_model_summary.rds"), compress = FALSE)

cat("\nVerifying saved files...\n")
Sys.sleep(2)

test <- readRDS(file.path(outdir, "N0_data.rds"))
cat("Main data verified:", nrow(test), "rows\n")

# Copy to gates directory
cat("Copying to gates directory...\n")
system(paste("cp", file.path(outdir, "N0_*.rds"), "/groups/m-larch/bt307958/gates/"))

cat("\nN0 complete.\n")
