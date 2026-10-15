from hinterland import REPO_ROOT


def test_setup_cmd_has_crlf_and_targets_master():
    data = (REPO_ROOT / "HinterlandSetup.cmd").read_bytes()
    assert data.count(b"\n") == data.count(b"\r\n"), "batch files need CRLF line endings"
    assert b'set "BRANCH=master"' in data
