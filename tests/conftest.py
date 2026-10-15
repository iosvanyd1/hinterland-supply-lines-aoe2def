import pytest

from hinterland import assemble, package


@pytest.fixture(autouse=True)
def isolated_output_dirs(tmp_path, monkeypatch):
    """Keep tests out of the real build/ and dist/.

    A --no-dat assemble into build/ wipes a real build's .dat, and deploy then
    ships a mod without its data file.
    """
    monkeypatch.setattr(assemble, "BUILD_DIR", tmp_path / "build")
    monkeypatch.setattr(package, "DIST_DIR", tmp_path / "dist")
