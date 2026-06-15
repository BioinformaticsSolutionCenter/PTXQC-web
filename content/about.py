from pathlib import Path

import streamlit as st

from src.common.common import page_setup

page_setup()

st.title("ℹ️ About")

if Path("assets/BSC.png").exists():
    st.image("assets/BSC.png", width=400)

st.markdown(
    """
This web application generates proteomics quality-control reports with the
**[PTXQC](https://github.com/cbielow/PTXQC)** R package. It was originally developed
as a bachelor thesis at the
**[Bioinformatics Solution Center, Freie Universität Berlin](https://www.bsc.fu-berlin.de/)**
(Kristin Köhler), supervised by Dr. Chris Bielow and Dr. Sandro Andreotti, with
contributions from Kilian Malek (2023), and has been ported onto the
[OpenMS streamlit-template](https://github.com/OpenMS/streamlit-template).

#### Impressum

Freie Universität Berlin — Bioinformatics Solution Center

In case of questions or feedback, please write to **mail@bsc.fu-berlin.de**.
"""
)
