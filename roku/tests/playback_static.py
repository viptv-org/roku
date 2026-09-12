#!/usr/bin/env python3
"""Static invariants complement BrightScript flow tests; no network/device access."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
scene = (root / "components/MainScene.brs").read_text()
overlay = (root / "components/PlayerOverlay.brs").read_text()
api = (root / "components/ApiTask.brs").read_text()
util = (root / "source/Util.brs").read_text()
xml = (root / "components/MainScene.xml").read_text()
for removed in (
    "sub autoSource()", "sub nextSource(", "offerUnknownSource", "confirmUnknownAudio",
    "allow_unknown_audio", "audioPolicy", "English-only", "Keep English only",
):
    assert removed not in scene + api + util, f"removed policy/automatic path remains: {removed}"
assert 'findStreams(m.selected,action <> "resume",StableResumePreference(m.selected))' in scene
assert 'findStreams(episode,true)' in scene
resume = scene[scene.index('sub tryResumeSource()'):scene.index('sub playSource(')]
assert 'm.resumeSourcePreference = invalid' in resume
assert 'm.manualSources = true' in resume
assert 'startPlayback(' not in resume
assert 'function StableSourcePreference' in util and 'function SourceMatchesPreference' in util
assert 'return actual.source_addon_id = expected.source_addon_id and Txt(actual.source_fingerprint) = Txt(expected.source_fingerprint)' in util
assert 'label = "Choose source"' in scene and '{name:"Sources",action:"sources"}' not in scene
assert '<Video id="replacementVideo"' not in xml and '<Timer id="seekTimer"' in xml
assert 'm.video.control = "pause"' in scene
assert 'm.video.visible = true' in scene
assert 'replacementVideo' not in scene
assert 'm.seekOldContent = m.video.content' in scene
assert 'resumeTimer' not in scene + xml
assert 'seekReplacementFailed("Seek failed. Playback resumed at the prior position.")' in scene
assert 'm.video.control = "resume"' in scene
assert 'function SeekStepForRepeat' in overlay and 'if repeats >= 15 then multiplier = 60' in overlay
assert 'm.justCommittedSeek = true' in overlay
print('ROKU_PLAYBACK_STATIC_OK')
