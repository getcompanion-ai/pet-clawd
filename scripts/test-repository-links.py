"""Offline checks; no app build, signing, publishing, or credential access."""
import base64
from pathlib import Path
import plistlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REPO = "https://github.com/advaitpaliwal/pet-clawd"
FEED = "https://raw.githubusercontent.com/advaitpaliwal/pet-clawd/main/appcast.xml"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


class RepositoryLinksTests(unittest.TestCase):
    def test_source_and_generated_plists_agree(self):
        source = plistlib.loads((ROOT / "Clawd/Info.plist").read_bytes())
        script = (ROOT / "scripts/build-app.sh").read_text()
        for name in ("SUFeedURL", "SUPublicEDKey"):
            generated = re.search(
                rf"<key>{name}</key>\s*<string>([^<]+)</string>", script
            ).group(1)
            self.assertEqual(source[name], generated)
        self.assertEqual(source["SUFeedURL"], FEED)
        self.assertEqual(source["SUPublicEDKey"], "p/STOfduNWVMNYn1sjYX3pbM5PnywVU/8WrGUJjpoAI=")
        self.assertEqual(len(base64.b64decode(source["SUPublicEDKey"], validate=True)), 32)
        self.assertIn('BUNDLE_ID="com.getcompanion.clawd"', script)

    def test_feed_destinations_keep_signed_archive_metadata(self):
        content = (ROOT / "appcast.xml").read_text()
        # A future signed XML feed must not be edited as plain URL metadata.
        self.assertNotIn("sparkle-signatures:", content)
        self.assertNotIn("sparkle-sign-warning:", content)
        feed = ET.fromstring(content)
        self.assertEqual(feed.findtext("./channel/link"), REPO)
        enclosures = feed.findall("./channel/item/enclosure")
        self.assertTrue(enclosures)
        for enclosure in enclosures:
            self.assertTrue(enclosure.attrib["url"].startswith(f"{REPO}/releases/download/"))
            self.assertEqual(
                len(base64.b64decode(enclosure.attrib[f"{SPARKLE}edSignature"], validate=True)), 64
            )
            self.assertGreater(int(enclosure.attrib["length"]), 0)
        self.assertNotIn("getcompanion-ai/pet-clawd", content)
        historical = next(
            item for item in feed.findall("./channel/item")
            if item.findtext(f"{SPARKLE}shortVersionString") == "1.3.3"
        )
        self.assertEqual(historical.findtext(f"{SPARKLE}version"), "13")
        enclosure = historical.find("enclosure")
        self.assertEqual(enclosure.attrib["length"], "1212027")
        self.assertEqual(
            enclosure.attrib[f"{SPARKLE}edSignature"],
            "Zf3l4ib0yyjO7wG6OaFD0xug0fwaCfn9KkpRPd/jLZrEK20kX5wzE3GJy02zM/xh0/inAcatIcZ99mOD6lBECQ==",
        )

    def test_readme_uses_personal_source_and_downloads(self):
        readme = (ROOT / "README.md").read_text()
        self.assertIn(f"{REPO}/releases", readme)
        self.assertIn(f"git clone {REPO}.git", readme)
        self.assertNotIn("getcompanion-ai/pet-clawd", readme)


if __name__ == "__main__":
    unittest.main()
