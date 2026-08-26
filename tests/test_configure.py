import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "configure.py"
SPEC = importlib.util.spec_from_file_location("configure", MODULE_PATH)
configure = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(configure)


class ConfigureTests(unittest.TestCase):
    def test_known_wpa2_vector(self):
        self.assertEqual(
            configure.derive_psk("IEEE", "password"),
            "f42c6fc52df0ebef9ebb4b90b38a5f90"
            "2e83fe1b135a70e23aed762e9710a12e",
        )

    def test_ssid_length_is_bytes(self):
        with self.assertRaises(ValueError):
            configure.validate_ssid("é" * 17)

    def test_rejects_short_password(self):
        with self.assertRaises(ValueError):
            configure.validate_psk("short")

    def test_accepts_normal_values(self):
        self.assertEqual(configure.validate_ssid("Repeater"), "Repeater")
        self.assertEqual(configure.validate_psk("eight888"), "eight888")


if __name__ == "__main__":
    unittest.main()
