import streamlit as st

from src.common.common import page_setup
from src import ptxqc_config as cfg

page_setup()

meta = cfg.get_ptxqc_metadata()
version = meta.get("version", "?")

st.title("❓ Help")

st.markdown(
    f"""
This web application generates **proteomics quality-control reports** from
[MaxQuant](https://www.maxquant.org/) (`.txt`) output or OpenMS (`.mzTab`) files,
using the R package **[PTXQC](https://github.com/cbielow/PTXQC)** (version **{version}**).

### Input data

When processing **MaxQuant** output you can provide the following `.txt` files:

> *evidence.txt, msms.txt, msmsScans.txt, parameters.txt, proteinGroups.txt, summary.txt* and *mqpar.xml*

The more files you provide, the more metrics you get. Most metrics are derived from
**evidence.txt**, so it is highly recommended to provide at least that file. When you
choose a whole folder (*MaxQuant directory*), only the files relevant to PTXQC are used.

### Advanced settings

Report settings can be adjusted manually on the **Configure** page, or supplied as a
PTXQC configuration **YAML** file (toggle *"Upload a PTXQC YAML config"* on that page).
"""
)

if meta.get("available") and meta.get("default_yaml"):
    st.download_button(
        "⬇️ Download default PTXQC YAML config",
        data=meta["default_yaml"],
        file_name="PTXQC_default.yaml",
        mime="text/yaml",
    )

st.markdown(
    """
### More information

- PTXQC package, manual and vignettes on
  [CRAN](https://cran.r-project.org/web/packages/PTXQC/) and
  [GitHub](https://github.com/cbielow/PTXQC).
- The original Shiny web application:
  [Webserver-for-Quality-Control-Reports](https://github.com/koehlek99/Webserver-for-Quality-Control-Reports).
"""
)
