"""Keep the operational product instructions consistent with Main's real inputs."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ChecklistTests(unittest.TestCase):
    def setUp(self):
        self.checklist = (ROOT / 'docs/ROBLOX_CREATOR_DASHBOARD_CHECKLIST.md').read_text(encoding='utf-8')

    def test_configured_product_attributes_match_main(self):
        main = (ROOT / 'src/server/Main.server.luau').read_text(encoding='utf-8')
        product_loop = re.search(r'for _,catalogId in \{([^}]+)\} do', main)
        self.assertIsNotNone(product_loop)
        products = re.findall(r'"([a-z0-9_]+)"', product_loop[1])
        required = {product + '_PlatformId' for product in products}
        documented = set(re.findall(r'^\| `([a-z0-9_]+_PlatformId)` \|', self.checklist, re.M))
        self.assertEqual(documented, required)

    def test_epic_product_rows_match_enabled_products(self):
        pricing = (ROOT / 'src/shared/EpicPricing.luau').read_text(encoding='utf-8')
        products = set(re.findall(r'"(epic_upgrade_\d+)"', pricing))
        rows = set(re.findall(r'^\| `(epic_upgrade_\d+)` \|', self.checklist, re.M))
        self.assertEqual(rows, products)
        self.assertNotRegex(self.checklist, r'(?m)^\| `epic_tier_\d` \|')

    def test_large_pack_has_no_false_fifty_percent_claim(self):
        row = next(line for line in self.checklist.splitlines() if line.startswith('| `ge_pack_large`'))
        self.assertNotIn('+50%', row)


if __name__ == '__main__':
    unittest.main()
