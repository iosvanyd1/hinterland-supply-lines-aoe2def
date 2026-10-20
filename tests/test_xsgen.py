import pytest

from hinterland import xsgen


def test_render_defaults_match_committed_placeholder():
    assert xsgen.GENERATED_IDS.read_text(encoding="utf-8") == xsgen.render({})


def test_render_uses_new_ids():
    out = xsgen.render({"cSupplyCartId": 2100})
    assert "extern const int cSupplyCartId = 2100;" in out
    assert "extern const int cPalaceId = -1;" in out


def test_render_rejects_unknown_constant():
    with pytest.raises(ValueError):
        xsgen.render({"cTypo": 1})


def test_every_palace_tech_has_an_xs_constant():
    from hinterland.datmod.patches import palace_techs

    for spec in palace_techs.TECHS:
        assert spec.key in xsgen.DEFAULTS
