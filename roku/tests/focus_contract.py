"""Offline XML regression: python3 roku/tests/focus_contract.py.

Checks declarative focus contracts only; native behavior remains device evidence.
Never instantiates MainScene or performs network/device operations.
"""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


class FocusContract(unittest.TestCase):
    def test_fixed_position_collections(self):
        root = ET.parse(Path(__file__).resolve().parents[1] / "components/MainScene.xml").getroot()
        expected = {
            "sidebar": ("MarkupList", "[21,108]", "7", "NavIcon"),
            "sourceList": ("MarkupList", "[100,234]", "2", "SourceCard"),
            "posterGrid": ("HoldGrid", "[100,248]", "2", "HomeCard"),
        }
        for node_id, (tag, translation, rows, component) in expected.items():
            with self.subTest(node=node_id):
                nodes = root.findall(f".//*[@id='{node_id}']")
                self.assertEqual(len(nodes), 1)
                node = nodes[0]
                self.assertEqual(node.tag, tag)
                self.assertEqual(node.get("vertFocusAnimationStyle"), "floatingFocus")
                self.assertEqual(node.get("translation"), translation)
                self.assertEqual(node.get("numRows"), rows)
                self.assertEqual(node.get("itemComponentName"), component)
        self.assertEqual(root.find(".//*[@id='posterGrid']").get("numColumns"), "4")
        base = ET.parse(Path(__file__).resolve().parents[1] / "components/HoldGrid.xml").getroot()
        self.assertEqual(base.get("extends"), "MarkupGrid")

    def test_search_submit_and_late_grid_focus_contract(self):
        source = (Path(__file__).resolve().parents[1] / "components/SearchScene.brs").read_text()
        batch = source[source.index("sub searchBatch"):source.index("sub searchRender")]
        self.assertIn('if m.mode <> "searchall" then return', batch)
        self.assertIn("if section.done then return", batch)
        self.assertIn("Bounded(incoming,24)", batch)
        self.assertIn("not seen.doesExist(id)", batch)
        self.assertIn("m.searchInFlight < 3", source)
        self.assertIn('m.searchPanel.callFunc("focusResults",state.index)', source)
        self.assertNotIn(".setFocus(true)", batch)

    def test_live_entry_and_catalog_browse_routes(self):
        source = (Path(__file__).resolve().parents[1] / "components/MainScene.brs").read_text()
        live = source[source.index('else if action = "live"'):source.index('else if action = "livefilter"')]
        self.assertIn("openEpg()", live)
        browse = source[source.index("sub browse(kind"):source.index("function acknowledgementMayFocus")]
        self.assertIn('query = Txt(m.search).trim()', browse)
        self.assertIn('if query <> "" then path += "&search="', browse)
        restore = source[source.index("sub restoreView"):]
        self.assertIn("limit = 480", restore)
        self.assertIn("Bounded(saved.items,limit)", restore)
        self.assertNotIn("Bounded(saved.items,100)", restore)
        self.assertIn("Bounded(entry.streams,1000)", source)


if __name__ == "__main__":
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(FocusContract))
    if not result.wasSuccessful():
        raise SystemExit(1)
    print("ROKU_FOCUS_CONTRACT_OK")
