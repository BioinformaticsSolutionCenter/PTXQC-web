#!/usr/bin/env Rscript
# Adversarial config-parity check (run inside the R-enabled image):
#
#   cd /app && Rscript tests/ptxqc_yaml_parity.R
#
# Asserts that the PTXQC config YAML produced by the PORT (src/ptxqc_runner.R
# build-config, fed the JSON payload that src/ptxqc_config.build_run_config emits)
# is equivalent to the YAML the ORIGINAL PTXQC-web app produces (a faithful
# transcription of app/server.R build.yaml) for the same user inputs.
#
# The two YAMLs are compared as PARSED structures (all.equal) so cosmetic
# differences (comment headers, int-vs-double formatting) do not cause false
# mismatches — a real divergence in the parameter mapping does.

suppressPackageStartupMessages({
  library(PTXQC)
  library(yaml)
  library(jsonlite)
})

# Non-default, discriminating test inputs.
v <- list(
  id_rate_bad = 15, id_rate_great = 40,
  pg_ratioLabIncThresh = 5, param_PG_intThresh = 26,
  param_EV_protThresh = 4000, param_EV_pepThresh = 16000,
  param_EV_MatchingTolerance = 0.8, param_evd_mbr = "yes",
  param_EV_PrecursorTolPPM = 18, param_EV_PrecursorOutOfCalSD = 3,
  param_EV_PrecursorTolPPMmainSearch = 4.0, param_MSMSScans_ionInjThresh = 12
)
metrics <- c("EVD_PeptideCount", "EVD_ProteinCount", "PAR")
contaminants_str <- "MYCOPLASMA: 1"  # single entry: trim/no-trim agree

# --- Way A: faithful transcription of PTXQC-web app/server.R build.yaml ---
yaml_original <- function() {
  cl <- unlist(strsplit(contaminants_str, ";"))
  contaminants <- list()
  for (i in seq_along(cl)) {
    cont <- unlist(strsplit(cl[i], ":"))
    contaminants[[paste0("cont_", cont[1])]] <-
      c(name = cont[1], threshold = as.integer(cont[2]))
  }
  param <- list()
  param$id_rate_bad <- v$id_rate_bad
  param$id_rate_great <- v$id_rate_great
  param$pg_ratioLabIncThresh <- v$pg_ratioLabIncThresh
  param$param_PG_intThresh <- v$param_PG_intThresh
  param$param_EV_protThresh <- v$param_EV_protThresh
  param$param_EV_intThresh <- v$param_EV_protThresh   # server.R:107 — from protein count
  param$param_EV_pepThresh <- v$param_EV_pepThresh
  param$yaml_contaminants <- contaminants
  param$param_EV_MatchingTolerance <- v$param_EV_MatchingTolerance
  param$param_evd_mbr <- v$param_evd_mbr
  param$param_EV_PrecursorTolPPM <- v$param_EV_PrecursorTolPPM
  param$param_EV_PrecursorOutOfCalSD <- v$param_EV_PrecursorOutOfCalSD
  param$param_EV_PrecursorTolPPMmainSearch <- v$param_EV_PrecursorTolPPMmainSearch
  param$param_MSMSScans_ionInjThresh <- v$param_MSMSScans_ionInjThresh
  yc <- YAMLClass$new(list())
  PTXQC:::createYaml(yc = yc, DEBUG_PTXQC = FALSE,
                     metrics = paste0("qcMetric_", metrics), param = param)
  f <- tempfile(fileext = ".yaml")
  invisible(capture.output(yc$writeYAML(f), type = "output"))
  yaml.load_file(f)
}

# --- Way B: the port. Build the JSON payload exactly as
# src/ptxqc_config.build_run_config does (incl. the intThresh<-protThresh
# coupling and parsed contaminants), then call the real wrapper build-config. ---
yaml_port <- function() {
  cfg <- list(
    metrics = metrics,
    param = c(v[setdiff(names(v), character(0))],
              list(param_EV_intThresh = v$param_EV_protThresh)),
    contaminants = list(list(name = "MYCOPLASMA", threshold = 1)),
    uploaded_yaml = NULL
  )
  cfg_file <- tempfile(fileext = ".json")
  out_file <- tempfile(fileext = ".yaml")
  writeLines(toJSON(cfg, auto_unbox = TRUE, null = "null"), cfg_file)
  status <- system2("Rscript",
                    c("src/ptxqc_runner.R", "build-config",
                      "--config", cfg_file, "--out", out_file))
  if (status != 0 || !file.exists(out_file)) {
    stop("build-config failed")
  }
  yaml.load_file(out_file)
}

a <- yaml_original()
b <- yaml_port()
cmp <- all.equal(a, b)
if (isTRUE(cmp)) {
  cat("CONFIG PARITY OK — port YAML matches PTXQC-web build.yaml.\n")
} else {
  cat("CONFIG PARITY MISMATCH:\n")
  print(cmp)
  quit(status = 1)
}
