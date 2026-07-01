import importlib.util
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from contextlib import redirect_stdout
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / ".github/workflows/scripts/ai_review_pr.py"


def load_module():
    spec = importlib.util.spec_from_file_location("ai_review_pr", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AiReviewConfigTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.settings_path = Path(self.tmp.name) / ".github/ai-review/settings.json"
        self.module.AI_REVIEW_SETTINGS_FILE = self.settings_path
        self.module.log = lambda message: None

    def write_settings(self, data):
        self.settings_path.parent.mkdir(parents=True, exist_ok=True)
        self.settings_path.write_text(json.dumps(data), encoding="utf-8")

    def valid_review_output(self):
        return f"""### PASS - Dogsquard AI Code Review

## Dogsquard AI Code Review

{self.module.COMMENT_MARKER}

### Verdict
PASS

### What changed
- Test output.

### Must fix
- None.

### Should consider
- None.

### Test gaps
- None.

### Acceptance check
- Passed.

### File-skip check
- Skip used: no.

### Dogsquard boundary check
- Passed.

### Engine details
- Engine: qoder
- Model: test
"""

    def test_load_settings_defaults_when_file_missing(self):
        settings = self.module.load_ai_review_settings()

        self.assertTrue(settings["enabled"])
        self.assertEqual(settings["engine"], "claude-deepseek")
        self.assertEqual(settings["claude"]["provider"], "deepseek")
        self.assertEqual(settings["qoder"]["models"], ["Qwen3.7-Max"])

    def test_resolve_engine_precedence(self):
        settings = {"engine": "qoder"}

        with patch.dict(os.environ, {"AI_REVIEW_ENGINE_INPUT": "claude-deepseek", "AI_REVIEW_ENGINE": "qoder"}, clear=True):
            self.assertEqual(self.module.resolve_engine(settings), "claude-deepseek")

        with patch.dict(os.environ, {"AI_REVIEW_ENGINE": "claude-deepseek"}, clear=True):
            self.assertEqual(self.module.resolve_engine(settings), "qoder")

        with patch.dict(os.environ, {"AI_REVIEW_ENGINE": "qoder"}, clear=True):
            self.assertEqual(self.module.resolve_engine({}), "qoder")

        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(self.module.resolve_engine({}), "claude-deepseek")

    def test_resolve_engine_rejects_non_string_config(self):
        with patch.dict(os.environ, {"AI_REVIEW_ENGINE": "qoder"}, clear=True):
            with self.assertRaisesRegex(self.module.ReviewFailure, "field engine must be a string"):
                self.module.resolve_engine({"engine": 42})

    def test_resolve_enabled_rejects_non_boolean(self):
        with self.assertRaisesRegex(self.module.ReviewFailure, "field enabled must be boolean"):
            self.module.resolve_enabled({"enabled": "false"})

    def test_resolve_config_cli_prints_normalized_workflow_json(self):
        self.write_settings({"enabled": True, "engine": "qoder", "qoder": {"models": ["GLM-5.2"], "implicit_auto_fallback": True}})
        stdout = io.StringIO()

        with patch.dict(os.environ, {}, clear=True), redirect_stdout(stdout):
            self.assertEqual(self.module.main(["--resolve-config"]), 0)

        self.assertEqual(
            json.loads(stdout.getvalue()),
            {"enabled": True, "engine": "qoder", "qoder_models": ["GLM-5.2", "Auto"]},
        )

    def test_resolve_config_cli_does_not_validate_provider_settings_when_disabled(self):
        self.write_settings({"enabled": False, "engine": "qoder", "qoder": {"models": [], "implicit_auto_fallback": False}})
        stdout = io.StringIO()

        with patch.dict(os.environ, {}, clear=True), redirect_stdout(stdout):
            self.assertEqual(self.module.main(["--resolve-config"]), 0)

        self.assertEqual(json.loads(stdout.getvalue()), {"enabled": False, "engine": "qoder"})

    def test_qoder_models_validation(self):
        valid_settings = {"qoder": {"models": ["GLM-5.2", "Qwen3.7-Max"], "implicit_auto_fallback": True}}
        self.assertEqual(self.module.configured_qoder_models(valid_settings), ["GLM-5.2", "Qwen3.7-Max"])
        self.assertEqual(self.module.resolve_qoder_model_sequence(valid_settings), ["GLM-5.2", "Qwen3.7-Max", "Auto"])

        invalid_cases = [
            {"models": ["Auto"], "implicit_auto_fallback": True},
            {"models": ["GLM-5.2", "GLM-5.2"], "implicit_auto_fallback": True},
            {"models": ["GLM-5.2", ""], "implicit_auto_fallback": True},
            {"models": ["GLM-5.2", "Qwen3.7-Max", "Kimi-K2.7-Code"], "implicit_auto_fallback": True},
            {"models": ["GLM-5.2"], "implicit_auto_fallback": False},
        ]
        for qoder in invalid_cases:
            with self.subTest(qoder=qoder):
                with self.assertRaises(self.module.ReviewFailure):
                    self.module.configured_qoder_models({"qoder": qoder})

    def test_qoder_timeout_does_not_coerce_boolean_values_to_seconds(self):
        with patch.dict(os.environ, {"AI_REVIEW_TIMEOUT_SECONDS": "42"}, clear=True):
            self.assertEqual(self.module.qoder_settings_timeout({"timeout_seconds": True}), 42)
            self.assertEqual(self.module.qoder_settings_timeout({"timeout_seconds": False}), 42)
            self.assertEqual(self.module.qoder_settings_timeout({"timeout_seconds": "7"}), 7)

    def test_run_qoder_falls_back_after_invalid_output(self):
        settings = {"qoder": {"models": ["BadModel", "GoodModel"], "implicit_auto_fallback": True}}
        responses = [
            (0, "invalid output", ""),
            (0, self.valid_review_output(), ""),
        ]

        with patch.dict(os.environ, {"QODER_PERSONAL_ACCESS_TOKEN": "token"}, clear=True):
            with patch.object(self.module, "load_qoder_settings", return_value={}):
                with patch.object(self.module, "qoder_settings_timeout", return_value=5):
                    with patch.object(self.module, "run_capture", side_effect=responses) as run_capture:
                        comment, model = self.module.run_qoder("prompt", settings)

        self.assertEqual(model, "GoodModel")
        self.assertIn("### Verdict\nPASS", comment)
        self.assertEqual(run_capture.call_count, 2)
        self.assertEqual(run_capture.call_args_list[0].args[0][2], "BadModel")
        self.assertEqual(run_capture.call_args_list[1].args[0][2], "GoodModel")

    def test_run_qoder_falls_back_after_retryable_failure(self):
        settings = {"qoder": {"models": ["RestrictedModel", "GoodModel"], "implicit_auto_fallback": True}}
        responses = [
            (1, "", "model unavailable"),
            (0, self.valid_review_output(), ""),
        ]

        with patch.dict(os.environ, {"QODER_PERSONAL_ACCESS_TOKEN": "token"}, clear=True):
            with patch.object(self.module, "load_qoder_settings", return_value={}):
                with patch.object(self.module, "qoder_settings_timeout", return_value=5):
                    with patch.object(self.module, "run_capture", side_effect=responses) as run_capture:
                        _comment, model = self.module.run_qoder("prompt", settings)

        self.assertEqual(model, "GoodModel")
        self.assertEqual(run_capture.call_count, 2)
        self.assertEqual(run_capture.call_args_list[0].args[0][2], "RestrictedModel")
        self.assertEqual(run_capture.call_args_list[1].args[0][2], "GoodModel")

    def test_run_qoder_non_retryable_failure_stops_early(self):
        settings = {"qoder": {"models": ["BrokenModel", "GoodModel"], "implicit_auto_fallback": True}}

        with patch.dict(os.environ, {"QODER_PERSONAL_ACCESS_TOKEN": "token"}, clear=True):
            with patch.object(self.module, "load_qoder_settings", return_value={}):
                with patch.object(self.module, "qoder_settings_timeout", return_value=5):
                    with patch.object(self.module, "run_capture", return_value=(2, "", "permission denied")) as run_capture:
                        with self.assertRaisesRegex(self.module.ReviewFailure, "permission denied"):
                            self.module.run_qoder("prompt", settings)

        self.assertEqual(run_capture.call_count, 1)
        self.assertEqual(run_capture.call_args.args[0][2], "BrokenModel")

    def test_run_qoder_passes_prompt_via_stdin_not_cli_arg(self):
        settings = {"qoder": {"models": ["TestModel"], "implicit_auto_fallback": True}}
        large_prompt = "x" * 10000

        with patch.dict(os.environ, {"QODER_PERSONAL_ACCESS_TOKEN": "token"}, clear=True):
            with patch.object(self.module, "load_qoder_settings", return_value={}):
                with patch.object(self.module, "qoder_settings_timeout", return_value=5):
                    with patch.object(self.module, "run_capture", return_value=(0, self.valid_review_output(), "")) as run_capture:
                        self.module.run_qoder(large_prompt, settings)

        cmd = run_capture.call_args.args[0]
        self.assertNotIn(large_prompt, cmd)
        self.assertEqual(run_capture.call_args.kwargs.get("input_text"), large_prompt)

    def test_disabled_comment_is_not_file_skip(self):
        comment = self.module.disabled_comment("qoder")

        self.assertIn("### Verdict\nPASS", comment)
        self.assertIn("### AI review state\nDISABLED", comment)
        self.assertIn("- Skip used: no.", comment)
        self.assertNotIn("### Verdict\nSKIP", comment)
        self.assertNotIn("Reason: AI review disabled by configuration.", comment)

    def test_safe_file_skip_comment_keeps_skip_verdict(self):
        comment = self.module.skip_comment("qoder", ["docs/manual.pdf"])

        self.assertIn("### Verdict\nSKIP", comment)
        self.assertIn("- Skip used: yes.", comment)
        self.assertIn("Reason: all changed files are safe binary/document assets.", comment)
        self.assertNotIn("### AI review state\nDISABLED", comment)

    def test_disabled_main_writes_review_without_provider_or_pr_collection(self):
        self.write_settings({"enabled": False, "engine": "qoder"})

        with patch.dict(os.environ, {}, clear=True):
            with patch.object(self.module, "collect_pr_context") as collect_pr_context:
                with patch.object(self.module, "run_qoder") as run_qoder:
                    with patch.object(self.module, "write_review") as write_review:
                        self.assertEqual(self.module.main([]), 0)

        collect_pr_context.assert_not_called()
        run_qoder.assert_not_called()
        write_review.assert_called_once()
        self.assertIn("### AI review state\nDISABLED", write_review.call_args.args[0])


if __name__ == "__main__":
    unittest.main()
