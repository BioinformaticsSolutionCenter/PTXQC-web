from pathlib import Path

import streamlit as st

from src.common.common import page_setup
from src.common.admin import is_admin_configured, verify_admin_password
from src import ptxqc_config as cfg

page_setup()

st.title("📦 Usage Logfile")

# Hidden admin page (reached via the ?logfile URL query). Gated by the template's
# admin password (set in secrets.toml) — no hardcoded password.
if not is_admin_configured():
    st.info("The admin password is not configured for this deployment, so the usage log is unavailable.")
    st.stop()

if not st.session_state.get("logfile_authed", False):
    pw = st.text_input("Enter password", type="password", key="logfile-pw")
    if st.button("Enter"):
        if verify_admin_password(pw):
            st.session_state["logfile_authed"] = True
            st.rerun()
        else:
            st.error("Incorrect password.")
    st.stop()

root = Path(st.session_state["workspace"]).parent
df = cfg.read_usage_log(root)

c1, c2 = st.columns(2)
order = c1.selectbox("Order", ["Newest", "Oldest"])
only_errors = c2.checkbox("Only show errors")

if only_errors:
    df = df[df["error"].astype(str).str.strip() != ""]
if order == "Newest":
    df = df.iloc[::-1]

st.dataframe(df, use_container_width=True, hide_index=True)
