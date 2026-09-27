"""Native HD design inputs and layout invariants, separate from device evidence."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
main = ET.parse(root / "components/MainScene.xml")
node = lambda ident: main.find(f".//*[@id='{ident}']")
assert node("sidebar").tag == "DesignRail"
children = list(main.getroot().find("children"))
assert children.index(node("appChrome")) > children.index(node("epgGrid")), "guide covers expanded rail"
assert node("episodeList").tag == "HorizontalStrip"
assert node("discoverFilters").tag == "HorizontalStrip"
assert node("discoverTypes") is not None
home_layout = (root / "components/PresentationHomeScene.brs").read_text()
assert "m.homeRows.numRows = 3" in home_layout
assert "m.homeRows.itemSize = [1088,214]" in home_layout
assert node("homeRows").get("showRowCounter") == "[false]"
assert node("homeRows").get("rowItemSize") == "[[213,170]]"
assert node("homeShelves").get("clippingRect") == "[0,0,1096,218]"
assert node("detailBackdrop").get("width") == "747"
assert node("sourceList").get("translation") == "[776,172]"
assert node("sourceList").get("itemSize") == "[440,82]"
assert node("profileGrid").get("itemSize") == "[146,188]"
for path in (root / "components").glob("*.xml"):
    tree = ET.parse(path)
    for font in tree.iter("Font"):
        assert font.get("uri", "").startswith("pkg:/fonts/"), (path, font.attrib)
    for uri in re.findall(r'pkg:/[^"\s]+', path.read_text()):
        assert (root / uri.removeprefix("pkg:/")).is_file(), (path, uri)
    assert not re.search(r'scale="\[1\.0[1-9]', path.read_text()), path
for component in ["ActionRow", "NavIcon", "PlayerOverlay"]:
    assert "pkg:/images/lucide/" in (root / "components" / (component + ".brs")).read_text()
assert (root / "fonts/onest-LICENSE.txt").is_file()
assert (root / "images/lucide/LICENSE").is_file()
print("ROKU_DESIGN_CONTRACT_OK")
