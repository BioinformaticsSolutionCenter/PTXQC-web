#!/usr/bin/env Rscript
# Thin PTXQC command-line wrapper for the streamlit-template port.
#
# PTXQC is kept as a version-pinned R subprocess tool: the Streamlit app never
# imports R, it only shells out to this script via CommandExecutor.run_command.
# All PTXQC-specific config assembly lives here (mirroring the original
# PTXQC-web app/server.R build.yaml), so the Python side needs no knowledge of
# PTXQC's YAML schema or its unexported internals.
#
# Subcommands:
#   default-config --out <file>
#       Write the version-correct default PTXQC config YAML to <file> and print a
#       JSON object {version, metrics:[{id,name}, ...]} to stdout. The metric list
#       drives the "Compute metrics" UI and is therefore always correct for the
#       installed PTXQC version (no hardcoding in Python).
#
#   run --config <params.json> --in <txt-dir|mztab-file> --type <maxquant|mztab> --out <dir>
#       Build the PTXQC config from the user parameters (identical to PTXQC-web's
#       build.yaml) or use an uploaded YAML verbatim, run createReport(), and write
#       <out>/ptxqc_result.json describing the produced files. Exits non-zero on
#       failure (run_command then reports the failure to the workflow log).

suppressPackageStartupMessages({
  library(PTXQC)
  library(yaml)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
cmd <- if (length(args) >= 1) args[[1]] else ""

get_opt <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return(default)
  args[[i + 1]]
}

# Ordered QC metric list, mirroring PTXQC-web app/global.R.
metric_table <- function() {
  lst <- PTXQC:::getMetricsObjects(FALSE)
  meta <- PTXQC:::getMetaData(lst_qcMetrics = lst)
  ids <- gsub("qcMetric_", "", names(lst[meta$.id]))
  data.frame(id = ids, name = ids, stringsAsFactors = FALSE)
}

# Assemble the PTXQC `param` list from the user values, mirroring
# PTXQC-web app/server.R build.yaml (lines 83-122).
build_param_list <- function(cfg) {
  p <- cfg$param
  contaminants <- list()
  if (!is.null(cfg$contaminants) && length(cfg$contaminants) > 0) {
    for (c in cfg$contaminants) {
      key <- paste0("cont_", c$name)
      contaminants[[key]] <- c(name = c$name, threshold = as.integer(c$threshold))
    }
  }
  param <- list()
  param$id_rate_bad <- p$id_rate_bad
  param$id_rate_great <- p$id_rate_great
  param$pg_ratioLabIncThresh <- p$pg_ratioLabIncThresh
  param$param_PG_intThresh <- p$param_PG_intThresh
  param$param_EV_protThresh <- p$param_EV_protThresh
  param$param_EV_intThresh <- p$param_EV_intThresh
  param$param_EV_pepThresh <- p$param_EV_pepThresh
  param$yaml_contaminants <- if (length(contaminants) > 0) contaminants else FALSE
  param$param_EV_MatchingTolerance <- p$param_EV_MatchingTolerance
  param$param_evd_mbr <- p$param_evd_mbr
  param$param_EV_PrecursorTolPPM <- p$param_EV_PrecursorTolPPM
  param$param_EV_PrecursorOutOfCalSD <- p$param_EV_PrecursorOutOfCalSD
  param$param_EV_PrecursorTolPPMmainSearch <- p$param_EV_PrecursorTolPPMmainSearch
  param$param_MSMSScans_ionInjThresh <- p$param_MSMSScans_ionInjThresh
  param
}

# Build the PTXQC YAMLClass object from the user config (mirrors server.R build.yaml).
build_yc <- function(cfg) {
  # Empty selection means "all metrics" (PTXQC-web defaults to all selected).
  if (is.null(cfg$metrics) || length(cfg$metrics) == 0) {
    mets <- paste0("qcMetric_", metric_table()$id)
  } else {
    mets <- paste0("qcMetric_", cfg$metrics)
  }
  param <- build_param_list(cfg)
  yc <- YAMLClass$new(list())
  PTXQC:::createYaml(yc = yc, DEBUG_PTXQC = FALSE, metrics = mets, param = param)
  yc
}

# Produce the yaml_obj (a nested list) that createReport() consumes.
make_yaml_obj <- function(cfg) {
  if (!is.null(cfg$uploaded_yaml) && nzchar(cfg$uploaded_yaml)) {
    # User uploaded a full PTXQC config YAML -> use verbatim (server.R:194 short-circuit).
    return(yaml.load_file(cfg$uploaded_yaml))
  }
  tmp <- tempfile(fileext = ".yaml")
  invisible(capture.output(build_yc(cfg)$writeYAML(tmp), type = "output"))
  yaml.load_file(tmp)
}

if (cmd == "default-config") {
  out <- get_opt("--out")
  meta_out <- paste0(out, ".json")
  mt <- metric_table()
  # createYaml/writeYAML print progress to stdout; capture it so the JSON contract
  # stays clean. The metric list is essential for the UI, so never let a YAML-write
  # failure fail this subcommand (the default YAML is only a download/reference).
  invisible(capture.output(
    tryCatch({
      yc <- YAMLClass$new(list())
      PTXQC:::createYaml(yc = yc, DEBUG_PTXQC = FALSE,
                         metrics = paste0("qcMetric_", mt$id), param = list())
      yc$writeYAML(out)
    }, error = function(e) {
      message(paste0("default-config: could not write default YAML: ", conditionMessage(e)))
    }),
    type = "output"
  ))
  # Python reads the metric list / version from this sidecar file (not stdout).
  writeLines(toJSON(list(
    version = as.character(packageVersion("PTXQC")),
    metrics = mt
  ), dataframe = "rows", auto_unbox = TRUE), con = meta_out)

} else if (cmd == "run") {
  config <- get_opt("--config")
  input  <- get_opt("--in")
  type   <- get_opt("--type", "maxquant")
  out    <- get_opt("--out")

  cfg <- fromJSON(config, simplifyVector = TRUE, simplifyDataFrame = FALSE)
  version <- as.character(packageVersion("PTXQC"))
  result_file <- file.path(out, "ptxqc_result.json")

  write_result <- function(lst) {
    writeLines(toJSON(lst, auto_unbox = TRUE, null = "null"), result_file)
  }

  glob_one <- function(dir, pattern) {
    hits <- list.files(dir, pattern = pattern, full.names = TRUE)
    if (length(hits) > 0) normalizePath(hits[[1]]) else NULL
  }

  tryCatch({
    yaml_obj <- make_yaml_obj(cfg)
    if (type == "mztab") {
      createReport(txt_folder = NULL, mztab_file = input,
                   yaml_obj = yaml_obj, enable_log = TRUE)
    } else {
      createReport(txt_folder = input, mztab_file = NULL,
                   yaml_obj = yaml_obj, enable_log = TRUE)
    }
    write_result(list(
      version = version,
      html = glob_one(out, "report.*\\.html$"),
      pdf  = glob_one(out, "report.*\\.pdf$"),
      yaml = glob_one(out, "report.*\\.yaml$"),
      log  = glob_one(out, "report.*\\.log$"),
      error = NULL
    ))
  }, error = function(e) {
    msg <- conditionMessage(e)
    write_result(list(version = version, error = msg))
    message(paste0("PTXQC createReport failed: ", msg))
    quit(status = 1)
  })

} else if (cmd == "build-config") {
  # Write the PTXQC config YAML that a run would use (for preview/download and the
  # parity audit) without running a report.
  config <- get_opt("--config")
  out <- get_opt("--out")
  cfg <- fromJSON(config, simplifyVector = TRUE, simplifyDataFrame = FALSE)
  invisible(capture.output({
    if (!is.null(cfg$uploaded_yaml) && nzchar(cfg$uploaded_yaml)) {
      file.copy(cfg$uploaded_yaml, out, overwrite = TRUE)
    } else {
      build_yc(cfg)$writeYAML(out)
    }
  }, type = "output"))

} else {
  message("Usage: ptxqc_runner.R [default-config|run|build-config] ...")
  quit(status = 2)
}
