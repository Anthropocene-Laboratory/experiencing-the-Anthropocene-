# =============================================================================
# 5e_diagnose_area_share_churn.R
#
# QUESTION. The flicker test of 2026-08-13 found that 62.6 % of the transitions
# HILDA+ counts are <= 2-year excursions returning to their starting class. It
# measured PER-PIXEL TRANSITIONS. This pipeline publishes AREA SHARES. They are
# not the same quantity, and the same flicker affects them differently:
#
#   Mechanism A -- CONTAMINATION. If the excursions are directionally biased,
#     each year's composition is biased too, and year-to-year deltas inherit it.
#     A "+0.3 pp per decade" would then be reconstruction noise.
#   Mechanism B -- CANCELLATION. If the excursions are symmetric, they cancel at
#     the aggregate level. Each year's composition is nearly right, only the
#     per-pixel change COUNT is inflated, and rates per decade are defensible.
#
# The 13 August test cannot separate them. This one can.
#
# ---------------------------------------------------------------------------
# READING RULE, WRITTEN BEFORE THE MEASUREMENT
# ---------------------------------------------------------------------------
# Window: 2000-2019 annual, HILDA ONLY (no Lesiv). Lesiv must be off, otherwise
# 2015 changes source and the jump would be read as churn -- the very confusion
# `comparable = FALSE` exists to prevent.
#
# S -- SIGN-REVERSAL RATE. Share of consecutive annual deltas that change sign,
#   per component, then pooled over the four components (4 x 19 = 76 deltas).
#   Real land-use change is a slow social process: a directional series gives
#   S near 0. Independent annual noise gives S = 0.5, the ceiling.
#     PASS         if S <= 0.15  (trend-dominated; rates per decade defensible)
#     FAIL         if S >= 0.35  (70 % of the way to pure noise; annual deltas
#                                 are churn and no "pp per decade" from
#                                 consecutive years may be published)
#     INCONCLUSIVE otherwise: report the number and claim nothing.
#
# R -- GROSS OVER NET. sum(|annual delta|) / |net change over the window|, per
#   component. A perfectly monotone series gives exactly 1; R = 3 means two
#   thirds of the movement cancels.
#   Computed ONLY for components whose |net| >= 1 pp: below that the
#   denominator is near zero and R explodes for arithmetic reasons, not
#   substantive ones. That exclusion is part of the rule, not a later excuse.
#     PASS         if every eligible component has R <= 1.5
#     FAIL         if any eligible component has R >= 3.0
#     INCONCLUSIVE otherwise.
#
# COMBINED VERDICT: FAIL if either statistic fails. PASS only if both pass.
#   Anything else is INCONCLUSIVE and licenses nothing.
#
# WHY 2000-2019 AND NOT 1960-2019. The 13 August test's criterion C1 passed:
# the flicker is uniform across data regimes, as strong in 1960-1981 (no
# satellite input at all) as after 2000. A post-2000 window is therefore
# representative, and costs a quarter of the full series.
#
# WHAT THIS MEASUREMENT IS NOT: it tests whether the PUBLISHED area shares
# alternate. It does not measure how much of HILDA's reconstruction is right.
# A passing S licenses rates per decade; it does not license the level.
# =============================================================================

suppressPackageStartupMessages(library(stats))

S_PASS <- 0.15
S_FAIL <- 0.35
R_PASS <- 1.5
R_FAIL <- 3.0
NET_MIN_PP <- 1.0

args <- commandArgs(trailingOnly = TRUE)
get_opt <- function(key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
this_file <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
root <- normalizePath(file.path(dirname(this_file), "../../.."), mustWork = TRUE)

summary_path <- get_opt("summary")
if (is.null(summary_path) || !file.exists(summary_path)) {
  stop("Pass --summary=<path to trajectory_summary_*.csv> from a HILDA-only annual run")
}

s <- read.csv(summary_path, stringsAsFactors = FALSE)
s <- s[order(s$year), , drop = FALSE]

if (any(s$temporal_support != "hilda_only")) {
  stop("This diagnostic requires a HILDA-only run. Found: ",
       paste(unique(s$temporal_support), collapse = ", "),
       "\n  A source change inside the window would be read as churn.")
}
if (nrow(s) < 10) stop("Need at least 10 annual rows; got ", nrow(s))
if (any(diff(s$year) != 1)) stop("Years must be consecutive; found a gap")

components <- c("pct_wild", "pct_domesticated", "pct_built_up", "pct_unresolved")

rows <- list()
all_reversals <- integer(0)
for (nm in components) {
  d <- diff(s[[nm]])
  # A delta of exactly zero is neither a reversal nor a continuation; drop it
  # rather than let sign(0) = 0 count as a change of direction.
  nz <- d[d != 0]
  reversals <- if (length(nz) > 1) as.integer(sign(nz[-1]) != sign(nz[-length(nz)])) else integer(0)
  all_reversals <- c(all_reversals, reversals)
  gross <- sum(abs(d))
  net <- s[[nm]][nrow(s)] - s[[nm]][1]
  eligible <- abs(net) >= NET_MIN_PP
  rows[[nm]] <- data.frame(
    component = nm,
    n_deltas = length(d),
    S_component = if (length(reversals)) mean(reversals) else NA_real_,
    gross_pp = gross,
    net_pp = net,
    R = if (eligible) gross / abs(net) else NA_real_,
    eligible_for_R = eligible,
    stringsAsFactors = FALSE
  )
}
tab <- do.call(rbind, rows)

S_pooled <- mean(all_reversals)
S_verdict <- if (S_pooled <= S_PASS) "PASS" else if (S_pooled >= S_FAIL) "FAIL" else "INCONCLUSIVE"

R_elig <- tab$R[tab$eligible_for_R & is.finite(tab$R)]
R_verdict <- if (!length(R_elig)) {
  "INCONCLUSIVE (no component moved >= 1 pp over the window)"
} else if (all(R_elig <= R_PASS)) "PASS" else if (any(R_elig >= R_FAIL)) "FAIL" else "INCONCLUSIVE"

combined <- if (S_verdict == "FAIL" || startsWith(R_verdict, "FAIL")) {
  "FAIL -- annual deltas are churn; do not publish pp-per-decade from consecutive years"
} else if (S_verdict == "PASS" && R_verdict == "PASS") {
  "PASS -- area shares are directionally coherent; rates per decade are defensible"
} else {
  "INCONCLUSIVE -- report the numbers, claim nothing"
}

cat("\n=== Area-share churn, ", min(s$year), "-", max(s$year),
    " (", nrow(s), " years, HILDA only) ===\n", sep = "")
print(tab, row.names = FALSE, digits = 4)
cat(sprintf("\nS pooled = %.4f over %d non-zero deltas  (PASS <= %.2f, FAIL >= %.2f)  -> %s\n",
            S_pooled, length(all_reversals), S_PASS, S_FAIL, S_verdict))
cat(sprintf("R eligible components: %s  (PASS <= %.1f, FAIL >= %.1f)  -> %s\n",
            if (length(R_elig)) paste(sprintf("%.2f", R_elig), collapse = ", ") else "none",
            R_PASS, R_FAIL, R_verdict))
cat("\nVERDICT: ", combined, "\n\n", sep = "")

out_dir <- file.path(root, "Feature explorations", "Biosphere", "data_processed",
                     "wild_domesticated_built", "tables")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
tab$S_pooled <- S_pooled
tab$S_verdict <- S_verdict
tab$R_verdict <- R_verdict
tab$combined_verdict <- combined
tab$window <- sprintf("%d-%d", min(s$year), max(s$year))
csv_path <- file.path(out_dir, "area_share_churn_diagnostic.csv")
write.csv(tab, csv_path, row.names = FALSE)
cat("Wrote ", csv_path, "\n", sep = "")
