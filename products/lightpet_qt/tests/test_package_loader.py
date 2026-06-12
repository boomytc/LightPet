from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path
import unittest

from lightpet_qt.contract import DEFAULT_CONTRACT_PATH, load_animation_contract
from lightpet_qt.package_loader import PetRuntimeError, load_pet_package, pet_choice


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

    def test_direct_manifest_rejects_noncanonical_spritesheet_path(self) -> None:
        contract = load_animation_contract(DEFAULT_CONTRACT_PATH)
        example_dir = Path("examples/pets/lulu")
        payload = json.loads((example_dir / "pet.json").read_text(encoding="utf-8"))
        payload["spritesheetPath"] = "alt.webp"

        with tempfile.TemporaryDirectory() as temp_dir:
            package_dir = Path(temp_dir)
            (package_dir / "pet.json").write_text(json.dumps(payload), encoding="utf-8")
            shutil.copyfile(example_dir / "spritesheet.webp", package_dir / "alt.webp")

            with self.assertRaisesRegex(PetRuntimeError, "spritesheetPath to spritesheet.webp"):
                load_pet_package(package_dir / "pet.json", contract)

            self.assertIsNone(pet_choice(package_dir / "pet.json"))


if __name__ == "__main__":
    unittest.main()
