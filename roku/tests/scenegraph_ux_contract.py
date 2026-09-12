"""Static contract for VIPTV 1.8 Roku information architecture."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
scene = (ROOT / "components/MainScene.brs").read_text()
xml = (ROOT / "components/MainScene.xml").read_text()
util = (ROOT / "source/Util.brs").read_text()

for node in ("homeHeroPanel", "discoverFilters", "profileGrid", "pairQr", "sourceList"):
    assert f'id="{node}"' in xml
home_rows = re.search(r'<HoldRowList id="homeRows"[^>]+>', xml).group(0)
assert 'translation="[8,8]"' in home_rows
assert 'itemSize="[1180,242]"' in home_rows and 'rowItemSize="[[256,200]]"' in home_rows
assert 'itemSpacing="[0,12]"' in home_rows and 'numRows="2"' in home_rows
# The home shelf viewport clips rows below the screen; row pitch leaves title space.
assert 'clippingRect="[0,0,1188,254]"' in xml
assert 242 >= 200 + 32
for label in ("Profile", "Home", "Discover", "Live TV", "My List", "Search", "Settings"):
    assert f'name:"{label}"' in scene
for shelf in ("Continue Watching", "Trending Movies", "Popular Series", "Live Now", "My List"):
    assert shelf in scene
for setting in ("Switch profile", "Maximum quality", "About VIPTV", "Addons", "Sign out"):
    assert setting in scene

for misleading in ("subtitlesetting", "audiosetting", "subtitle_default", "audio_default", "PLAYBACK DEFAULTS"):
    assert misleading not in scene
assert "&genre=" in scene and "supports_search" in (ROOT / "components/SearchScene.brs").read_text() and "next_skip" in scene
assert "AppendDistinctSources" in scene
assert "m.streams = FairSources" not in scene
assert "tryResumeSource()" in scene and "m.manualSources = true" in scene
assert "source_addon_id,128" in util
assert "StablePreferenceText(item.source,256)" not in util
assert "API token" not in scene and "VIPTV_API_KEY" not in scene
assert "pkg:/images/ui-profile-focus.png" in (ROOT / "components/ProfileCard.xml").read_text()
print("ROKU_SCENEGRAPH_UX_CONTRACT_OK")
