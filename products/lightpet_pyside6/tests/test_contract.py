from __future__ import annotations

from pathlib import Path
import unittest

from lightpet_pyside6.contract import DEFAULT_CONTRACT_PATH, load_animation_contract


class AnimationContractTests(unittest.TestCase):
    def test_contract_loads_expected_geometry_and_states(self) -> None:
        contract = load_animation_contract(DEFAULT_CONTRACT_PATH)

        self.assertEqual(contract.atlas.width, 1536)
        self.assertEqual(contract.atlas.height, 1872)
        self.assertEqual(contract.atlas.cell_width, 192)
        self.assertEqual(contract.atlas.cell_height, 208)
        self.assertEqual(contract.state_names[0], "idle")
        self.assertEqual(contract.state_names[-1], "review")

    def test_contract_is_product_local(self) -> None:
        contract_path = Path(DEFAULT_CONTRACT_PATH)

        self.assertEqual(contract_path.parts[-3:], ("lightpet_pyside6", "docs", "pet-animation-contract.json"))


if __name__ == "__main__":
    unittest.main()

