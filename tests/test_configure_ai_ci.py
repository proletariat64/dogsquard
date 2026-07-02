import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts/configure_ai_ci.py"


def load_module():
    spec = importlib.util.spec_from_file_location("configure_ai_ci", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ConfigureAiCiTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.module.log = lambda msg: None

    def _patch_common(self, settings_data=None):
        """Patch module-level helpers so main() runs without real I/O."""
        if settings_data is None:
            settings_data = json.loads(json.dumps(self.module.DEFAULT_SETTINGS))
        p_load = patch.object(
            self.module, "load_current_settings", return_value=settings_data,
        )
        p_write = patch.object(self.module, "write_settings_atomic")
        p_validate = patch.object(
            self.module, "validate_qoder_models_available",
        )
        p_chdir = patch("os.chdir")
        return p_load, p_write, p_validate, p_chdir

    # ------------------------------------------------------------------
    # parse_args
    # ------------------------------------------------------------------

    def test_parse_args_help(self):
        state = self.module.parse_args(["--help"])
        self.assertEqual(state["_exit"], 0)

    def test_parse_args_unknown(self):
        state = self.module.parse_args(["--bogus"])
        self.assertEqual(state["_exit"], 2)

    def test_parse_args_enabled(self):
        state = self.module.parse_args(["--enabled", "true"])
        self.assertEqual(state["enabled"], "true")
        self.assertNotIn("_exit", state)

    def test_parse_args_engine(self):
        state = self.module.parse_args(["--engine", "qoder"])
        self.assertEqual(state["engine"], "qoder")
        self.assertTrue(state["engine_flag_set"])
        self.assertNotIn("_exit", state)

    def test_parse_args_qoder_model(self):
        state = self.module.parse_args(
            ["--qoder-model", "A", "--qoder-model", "B"]
        )
        self.assertEqual(state["qoder_models"], ["A", "B"])
        self.assertEqual(state["qoder_model_flag_count"], 2)
        self.assertNotIn("_exit", state)

    def test_parse_args_apply_github_vars_requires_apply(self):
        with patch("os.chdir"):
            code = self.module.main(["--apply-github-vars"])
        self.assertEqual(code, 2)

    # ------------------------------------------------------------------
    # Settings I/O
    # ------------------------------------------------------------------

    def test_load_settings_default(self):
        missing_path = Path(self.tmp.name) / "nonexistent" / "settings.json"
        settings = self.module.load_current_settings(missing_path)

        self.assertTrue(settings["enabled"])
        self.assertEqual(settings["engine"], "qoder")
        self.assertEqual(settings["claude"]["provider"], "deepseek")
        self.assertEqual(settings["qoder"]["models"], ["Qwen3.7-Max"])

    def test_load_settings_existing(self):
        settings_path = Path(self.tmp.name) / "settings.json"
        data = {"enabled": False, "engine": "claude-deepseek"}
        settings_path.write_text(json.dumps(data), encoding="utf-8")

        loaded = self.module.load_current_settings(settings_path)

        self.assertFalse(loaded["enabled"])
        self.assertEqual(loaded["engine"], "claude-deepseek")

    def test_write_settings_atomic(self):
        settings_path = Path(self.tmp.name) / "sub" / "settings.json"
        payload = json.dumps({"enabled": True, "engine": "qoder"})

        self.module.write_settings_atomic(settings_path, payload)

        self.assertTrue(settings_path.is_file())
        written = json.loads(settings_path.read_text(encoding="utf-8"))
        self.assertTrue(written["enabled"])
        self.assertEqual(written["engine"], "qoder")

    # ------------------------------------------------------------------
    # Validation (exercised through main)
    # ------------------------------------------------------------------

    def test_validate_models_auto_rejected(self):
        p_load, p_write, p_validate, p_chdir = self._patch_common()
        with p_load, p_write, p_validate, p_chdir:
            code = self.module.main([
                "--enabled", "true",
                "--engine", "qoder",
                "--qoder-model", "Auto",
                "--apply",
            ])
        self.assertEqual(code, 2)

    def test_validate_models_duplicate_rejected(self):
        p_load, p_write, p_validate, p_chdir = self._patch_common()
        with p_load, p_write, p_validate, p_chdir:
            code = self.module.main([
                "--enabled", "true",
                "--engine", "qoder",
                "--qoder-model", "A",
                "--qoder-model", "A",
                "--apply",
            ])
        self.assertEqual(code, 2)

    def test_validate_models_too_many(self):
        p_load, p_write, p_validate, p_chdir = self._patch_common()
        with p_load, p_write, p_validate, p_chdir:
            code = self.module.main([
                "--enabled", "true",
                "--engine", "qoder",
                "--qoder-model", "A",
                "--qoder-model", "B",
                "--qoder-model", "C",
                "--apply",
            ])
        self.assertEqual(code, 2)

    def test_validate_models_empty_with_qoder(self):
        settings = {
            "enabled": True,
            "engine": "qoder",
            "claude": {"provider": "deepseek"},
            "qoder": {"models": [], "implicit_auto_fallback": True},
        }
        p_load, p_write, p_validate, p_chdir = self._patch_common(settings)
        with p_load, p_write, p_validate, p_chdir:
            code = self.module.main([
                "--enabled", "true",
                "--engine", "qoder",
                "--apply",
            ])
        self.assertEqual(code, 2)

    # ------------------------------------------------------------------
    # JSON generation
    # ------------------------------------------------------------------

    def test_build_settings_json(self):
        result = self.module.generate_settings_json(
            "true", "qoder", "deepseek", ["ModelA", "ModelB"],
        )
        data = json.loads(result)

        self.assertTrue(data["enabled"])
        self.assertEqual(data["engine"], "qoder")
        self.assertEqual(data["claude"]["provider"], "deepseek")
        self.assertEqual(data["qoder"]["models"], ["ModelA", "ModelB"])
        self.assertTrue(data["qoder"]["implicit_auto_fallback"])

        # disabled variant
        result_off = self.module.generate_settings_json(
            "false", "claude-deepseek", "deepseek", [],
        )
        data_off = json.loads(result_off)
        self.assertFalse(data_off["enabled"])
        self.assertEqual(data_off["engine"], "claude-deepseek")
        self.assertEqual(data_off["qoder"]["models"], [])


if __name__ == "__main__":
    unittest.main()
