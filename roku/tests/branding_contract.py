"""Offline contract for Roku branding and remote-only profile avatars."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
manifest = dict(
    line.split("=", 1)
    for line in (ROOT / "manifest").read_text().splitlines()
    if line and not line.startswith("#")
)
assert manifest["mm_icon_focus_hd"] == "pkg:/images/channel-poster-hd.jpg"
assert manifest["mm_icon_side_hd"] == "pkg:/images/channel-poster-hd.jpg"
assert manifest["splash_screen_hd"] == "pkg:/images/splash-hd.jpg"
for key in ("mm_icon_focus_hd", "mm_icon_side_hd", "splash_screen_hd"):
    path = ROOT / manifest[key].removeprefix("pkg:/")
    assert path.is_file() and path.stat().st_size > 1024

profile_xml = (ROOT / "components/ProfileCard.xml").read_text()
profile_brs = (ROOT / "components/ProfileCard.brs").read_text()
assert 'id="avatar"' in profile_xml and 'id="avatarFallback"' in profile_xml
assert "item.avatar_url" in profile_brs
assert not re.search(r'pkg:/images/[^"\n]*avatar', profile_xml + profile_brs, re.I)
assert 'loadStatus' in profile_brs and 'm.initial.visible = not loaded' in profile_brs
hero_xml = (ROOT / "components/HeroPanel.xml").read_text()
hero_brs = (ROOT / "components/HeroPanel.brs").read_text()
assert 'id="backdrop"' in hero_xml and 'id="summary"' in hero_xml
for metadata in ("background", "poster", "releaseInfo", "runtime", "genres", "description"):
    assert metadata in hero_brs
filter_xml = (ROOT / "components/FilterChip.xml").read_text()
assert 'field id="focusPercent"' in filter_xml and 'id="label"' in filter_xml
print("ROKU_BRANDING_CONTRACT_OK")
