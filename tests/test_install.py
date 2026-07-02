import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts/install.py"


def load_module():
    spec = importlib.util.spec_from_file_location("install", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.module.log = lambda msg: None

    # -- parse_cli_flags --

    def test_parse_cli_flags_help(self):
        s = self.module.InstallState()
        with self.assertRaises(SystemExit) as ctx:
            self.module.parse_cli_flags(s, ["--help"])
        self.assertEqual(ctx.exception.code, 0)

    def test_parse_cli_flags_unknown(self):
        s = self.module.InstallState()
        with self.assertRaises(SystemExit) as ctx:
            self.module.parse_cli_flags(s, ["--bogus"])
        self.assertEqual(ctx.exception.code, 2)

    def test_parse_cli_flags_repo(self):
        s = self.module.InstallState()
        self.module.parse_cli_flags(s, ["--repo", "/tmp/foo"])
        self.assertEqual(s.target_dir, "/tmp/foo")
        self.assertTrue(s.cli_target_dir)

    def test_parse_cli_flags_modules(self):
        s = self.module.InstallState()
        self.module.parse_cli_flags(s, ["--modules", "governance,pr-quality"])
        self.assertEqual(s.modules, ["governance", "pr-quality"])
        self.assertTrue(s.cli_modules)

    def test_parse_cli_flags_qoder_model(self):
        s = self.module.InstallState()
        self.module.parse_cli_flags(s, ["--qoder-model", "A", "--qoder-model", "B"])
        self.assertEqual(s.qoder_models, ["A", "B"])
        self.assertEqual(s.qoder_models_from_cli, ["A", "B"])

    # -- parse_config_file --

    def test_parse_config_file_valid(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cfg = Path(tmp.name) / "install.conf"
        cfg.write_text("# comment\nTARGET_DIR = /tmp/repo\nPROJECT_TYPE = node\n")
        result = self.module.parse_config_file(cfg)
        self.assertEqual(result, {"TARGET_DIR": "/tmp/repo", "PROJECT_TYPE": "node"})

    def test_parse_config_file_secret_rejection(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cfg = Path(tmp.name) / "install.conf"
        cfg.write_text("AI_REVIEW_ENGINE = ghp_abc123token\n")
        with self.assertRaises(SystemExit) as ctx:
            self.module.parse_config_file(cfg)
        self.assertEqual(ctx.exception.code, 2)

    def test_parse_config_file_unknown_key(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cfg = Path(tmp.name) / "install.conf"
        cfg.write_text("BOGUS_KEY = value\n")
        with self.assertRaises(SystemExit) as ctx:
            self.module.parse_config_file(cfg)
        self.assertEqual(ctx.exception.code, 2)

    # -- validate_inputs --

    def test_validate_inputs_bad_project_type(self):
        s = self.module.InstallState()
        s.target_dir = "/nonexistent-but-nonempty"
        s.project_type = "cobol"
        s.modules = ["governance"]
        with self.assertRaises(SystemExit) as ctx:
            self.module.validate_inputs(s)
        self.assertEqual(ctx.exception.code, 2)

    def test_validate_inputs_bad_module(self):
        s = self.module.InstallState()
        s.target_dir = "/nonexistent-but-nonempty"
        s.project_type = "node"
        s.modules = []
        with self.assertRaises(SystemExit) as ctx:
            self.module.validate_inputs(s)
        self.assertEqual(ctx.exception.code, 2)

    # -- validate_ai_inputs --

    def test_validate_ai_inputs_qoder_no_models(self):
        s = self.module.InstallState()
        s.ai_engine = "qoder"
        s.qoder_models = []
        with self.assertRaises(SystemExit) as ctx:
            self.module.validate_ai_inputs(s)
        self.assertEqual(ctx.exception.code, 2)

    def test_validate_ai_inputs_qoder_too_many(self):
        s = self.module.InstallState()
        s.ai_engine = "qoder"
        s.qoder_models = ["A", "B", "C"]
        with self.assertRaises(SystemExit) as ctx:
            self.module.validate_ai_inputs(s)
        self.assertEqual(ctx.exception.code, 2)

    def test_validate_ai_inputs_qoder_duplicate(self):
        s = self.module.InstallState()
        s.ai_engine = "qoder"
        s.qoder_models = ["A", "A"]
        with self.assertRaises(SystemExit) as ctx:
            self.module.validate_ai_inputs(s)
        self.assertEqual(ctx.exception.code, 2)

    def test_validate_ai_inputs_qoder_auto(self):
        s = self.module.InstallState()
        s.ai_engine = "qoder"
        s.qoder_models = ["Auto"]
        with self.assertRaises(SystemExit) as ctx:
            self.module.validate_ai_inputs(s)
        self.assertEqual(ctx.exception.code, 2)

    # -- file_sha256 --

    def test_file_sha256(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        f = Path(tmp.name) / "data.bin"
        content = b"dogsquard test payload"
        f.write_bytes(content)
        expected = hashlib.sha256(content).hexdigest()
        self.assertEqual(self.module.file_sha256(f), expected)

    def test_file_sha256_missing(self):
        self.assertIsNone(self.module.file_sha256(Path("/nonexistent/file.bin")))

    # -- run_capture --

    def test_run_capture_success(self):
        code, out, err = self.module.run_capture(["echo", "hello"])
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "hello")

    def test_run_capture_not_found(self):
        code, out, err = self.module.run_capture(["nonexistent_cmd_xyz_42"])
        self.assertEqual(code, 1)
        self.assertIn("not found", err)


if __name__ == "__main__":
    unittest.main()
