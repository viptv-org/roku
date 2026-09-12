"""Static account-only Roku contract; no network or registry access."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
scene = (ROOT / "components/AccountScene.brs").read_text()
main = (ROOT / "components/MainScene.brs").read_text()
api = (ROOT / "components/ApiTask.brs").read_text()
policy = (ROOT / "source/AccountPolicy.brs").read_text()
card = (ROOT / "components/ProfileCard.brs").read_text()
util = (ROOT / "source/Util.brs").read_text()
xml = (ROOT / "components/MainScene.xml").read_text()

assert "LegacyAdmin" not in scene + api + policy
assert 'request("POST","/api/device/token",{device_code:m.pairing.device_code}' in scene
assert "verification_uri_complete" in scene and "qr_uri" in policy
assert "device_token" not in scene + policy
assert "last_profile_id" in scene + api
assert "m.config.profile" not in scene + main
assert "m.config.token" not in scene + main
assert "connection.token" not in main and "origin.token" not in main and "entry.token" not in main
assert "access_token:Txt(connection.access_token)" in main
assert "entry.last_profile_id = Txt(connection.last_profile_id)" in main
assert "entry.account_epoch = m.accountEpoch" in main
assert "request.access_token" in api and 'Authorization", "Bearer " + accessToken' in api
assert '(?:base|token)' not in api
assert "registry.Delete(\"token\")" in api
assert 'q + "base" + q' in api
assert 'pkg:/data/connection.json' in api and 'pkg:/private/connection.json' not in api
assert "AccountAvatarStyles" in policy and "api.dicebear.com/10.x" in policy
assert "AccountAvatarUrl(item.avatar_url)" in card
assert "setup_complete" in scene + policy
assert "body.profile_id" not in util
assert "authenticated session owns the selected profile" in util
assert '<Poster id="pairQr" translation="[910,208]" width="250" height="250" loadWidth="250" loadHeight="250"' in xml
assert 'panel = m.top.findNode("pairPanel")' in scene and 'panel.visible = false' in scene
assert 'm.pairQr.visible = false' in scene
assert 'address = Txt(data.verification_uri)' in scene
assert 'body.setup_complete = true' in scene
assert 'request("PATCH","/api/profiles/"' in scene
assert 'request("POST","/api/profiles"' in scene
print("ROKU_ACCOUNT_ONLY_CONTRACT_OK")
