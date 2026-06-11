from __future__ import annotations

import unittest

from lightpet_pyside6.contract import DEFAULT_CONTRACT_PATH, load_animation_contract
from lightpet_pyside6.package_loader import load_pet_package


class PackageLoaderTests(unittest.TestCase):
    def test_bundled_example_loads_and_extracts_frames(self) -> None:
        contract = load_animation_contract(DEFAULT_CONTRACT_PATH)
        package = load_pet_package("examples/pets/lulu/pet.json", contract)

        self.assertEqual(package.manifest.id, "lulu")
        self.assertEqual(package.spritesheet_path.name, "spritesheet.webp")
        for row in contract.rows:
            self.assertEqual(len(package.frames.frames_by_state[row.state]), row.frame_count)

    def test_first_idle_frame_has_visible_pixels(self) -> None:
        contract = load_animation_contract(DEFAULT_CONTRACT_PATH)
        package = load_pet_package("examples/pets/lulu/pet.json", contract)
        idle = contract.row_by_state["idle"]
        frame = package.frames.frame(idle, 0)

        self.assertTrue(any(alpha > contract.atlas.visible_alpha_threshold for alpha in frame.alpha))


if __name__ == "__main__":
    unittest.main()

