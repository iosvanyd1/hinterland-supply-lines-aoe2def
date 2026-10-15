from pathlib import Path

from hinterland import config

# libraryfolders.vdf escapes backslashes, as Steam writes it.
VDF = r'''"libraryfolders"
{
	"0"
	{
		"path"		"C:\\Program Files (x86)\\Steam"
	}
	"1"
	{
		"path"		"E:\\SteamLibrary"
	}
}
'''


def test_steam_library_installs_reads_every_library(tmp_path):
    index = tmp_path / "libraryfolders.vdf"
    index.write_text(VDF, encoding="utf-8")
    assert config._steam_library_installs(index) == [
        Path(r"C:\Program Files (x86)\Steam\steamapps\common\AoE2DE"),
        Path(r"E:\SteamLibrary\steamapps\common\AoE2DE"),
    ]


def test_missing_library_index_gives_no_installs(tmp_path):
    assert config._steam_library_installs(tmp_path / "nope.vdf") == []
