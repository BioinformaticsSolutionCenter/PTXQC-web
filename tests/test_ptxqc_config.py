"""Unit tests for the pure-Python PTXQC config helpers (src/ptxqc_config.py).

These exercise the logic that does NOT require R/PTXQC: the contaminants parser,
the run-config assembly (incl. the PTXQC-web intensity/protein-threshold coupling),
and the usage-log round-trip.
"""
import os
import sys
from pathlib import Path

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(PROJECT_ROOT)

from src import ptxqc_config as cfg


def test_parse_contaminants_default():
    assert cfg.parse_contaminants("MYCOPLASMA: 1") == [{"name": "MYCOPLASMA", "threshold": 1}]


def test_parse_contaminants_multiple():
    result = cfg.parse_contaminants("MYCOPLASMA: 1; ECOLI: 2")
    assert result == [
        {"name": "MYCOPLASMA", "threshold": 1},
        {"name": "ECOLI", "threshold": 2},
    ]


def test_parse_contaminants_disabled_and_empty():
    assert cfg.parse_contaminants("no") == []
    assert cfg.parse_contaminants("") == []
    assert cfg.parse_contaminants(None) == []


def test_parse_contaminants_skips_malformed():
    # entries without a colon or threshold are skipped, valid ones kept
    assert cfg.parse_contaminants("BAD; GOOD: 5; ALSObad:") == [
        {"name": "GOOD", "threshold": 5}
    ]


def test_build_run_config_uses_defaults():
    out = cfg.build_run_config({}, [], [], None)
    assert set(out["param"].keys()) == set(cfg.PARAM_KEYS)
    assert out["param"]["id_rate_bad"] == 20
    assert out["param"]["id_rate_great"] == 35
    assert out["metrics"] == []
    assert out["uploaded_yaml"] is None


def test_build_run_config_couples_intensity_to_protein_count():
    # PTXQC-web sets param_EV_intThresh from the protein-count widget (server.R:107)
    out = cfg.build_run_config({"param_EV_protThresh": 5000}, ["MS2_Frac"], [], None)
    assert out["param"]["param_EV_protThresh"] == 5000
    assert out["param"]["param_EV_intThresh"] == 5000
    assert out["metrics"] == ["MS2_Frac"]


def test_usage_log_roundtrip(tmp_path):
    root = tmp_path
    cfg.append_usage_log(root, "1.2.3", "MaxQuant directory", 12.34, "")
    cfg.append_usage_log(root, "1.2.3", "mzTab file", 0.5, "boom")

    assert cfg.usage_log_path(root).exists()
    df = cfg.read_usage_log(root)
    assert list(df.columns) == cfg.USAGE_LOG_COLUMNS
    assert len(df) == 2
    assert df.iloc[0]["data type"] == "MaxQuant directory"
    assert df.iloc[0]["size MB"] == "12.3"
    assert df.iloc[1]["error"] == "boom"


def test_usage_log_missing_is_empty(tmp_path):
    df = cfg.read_usage_log(tmp_path)
    assert list(df.columns) == cfg.USAGE_LOG_COLUMNS
    assert len(df) == 0
