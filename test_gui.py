from streamlit.testing.v1 import AppTest
import pytest
import json


@pytest.fixture
def launch(request):
    test = AppTest.from_file(request.param)

    ## Initialize session state ##
    with open("settings.json", "r") as f:
        test.session_state.settings = json.load(f)
    test.session_state.settings["test"] = True
    test.secrets["workspace"] = "test"
    return test


# Test launching of all PTXQC pages. R/PTXQC is not installed in CI, so the
# config helper degrades gracefully — the pages must still render without error.
@pytest.mark.parametrize(
    "launch",
    (
        "content/ptxqc_upload.py",
        "content/ptxqc_configure.py",
        "content/ptxqc_run.py",
        "content/ptxqc_results.py",
        "content/help.py",
        "content/about.py",
    ),
    indirect=True,
)
def test_launch(launch):
    """Test if all pages can be launched without errors."""
    launch.run(timeout=30)
    assert not launch.exception
