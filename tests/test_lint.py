import pytest

from hinterland import lint


def test_xs_passes_xs_check():
    try:
        lint.find_xs_check()
    except FileNotFoundError:
        pytest.skip("xs-check not installed")
    assert lint.lint() == 0
