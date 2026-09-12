# Extraction validation

Baseline: vynxc/viptv@7d6b4131a44d87b58edcf12709af5851da387176. All runtime source, SceneGraph XML, data, images, manifest and configuration bytes are unchanged. MIGRATION.json records one test-only fix: direct_runtime.py now includes the existing ContinuationPolicy.brs dependency needed by the current findStreams handler.

Local checks passed: migration checksums; account, branding, playback, focus, scenegraph and node-identity static contracts; all 19 *_runtime.py harnesses (18 initially passed and the corrected direct harness then passed); BrighterScript 0.73.1 validation/staging; generated runtime ZIP layout with 749 entries including generated source/bslib.brs. CI also exercises the explicit BRS policy fixtures.

ZIP packaging uses compiled staging, not raw source; artifact creation refuses to overwrite an existing archive. GitHub CI uploads the checksummed archive, and validated version-tag builds publish it as a release asset. This split did not install a device package, submit a Roku Store build or perform physical TV validation.
