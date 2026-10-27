#!/usr/bin/env python3
"""Tests for commit-comment-audit. Run: python3 commit-comment-audit-test.py"""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.realpath(__file__))
HOOK = os.path.join(HERE, "commit-comment-audit")
loader = importlib.machinery.SourceFileLoader("cca", HOOK)
spec = importlib.util.spec_from_loader("cca", loader)
cca = importlib.util.module_from_spec(spec)
loader.exec_module(cca)


class CommitRepo(unittest.TestCase):
    def test_finds_a_commit_in_any_form(self):
        cases = {
            "git commit -m x": "/w",
            "cd /r && git add a && git commit -q -F - <<'EOF'\nmsg; git push\nEOF": "/r",
            "git -C /r commit -m x": "/r",
            "git -c user.name=x --no-pager commit": "/w",
            "GIT_X=1 git commit": "/w",
            "(cd sub && git commit -m 'a \"b')": "/w/sub",
            "git commit -m 'unbalanced": "/w",
        }
        for cmd, repo in cases.items():
            self.assertEqual(cca.commit_repo(cmd, "/w"), repo, cmd)

    def test_ignores_commands_that_only_mention_commit(self):
        for cmd in [
            "git push --force-with-lease",
            "git log --format=%s | grep commit",
            "gh pr create --body 'git commit then push'",
            "echo \"$(git rev-parse HEAD)\" commit",
            "cat <<'EOF'\ngit commit -m x\nEOF",
            "sed -i '' 's/a/b/' x && git status",
        ]:
            self.assertIsNone(cca.commit_repo(cmd, "/w"), cmd)


def diff_for(path, added):
    lines = "\n".join("+" + a for a in added)
    return f"diff --git a/{path} b/{path}\n--- a/{path}\n+++ b/{path}\n@@ -0,0 +1,{len(added)} @@\n{lines}\n"


class NumberedDiff(unittest.TestCase):
    def test_keeps_files_that_add_a_comment(self):
        for line in ["# Settlement runs at 9pm AEST.", "x = 1 # why", "// note", "-- sql why", "/* c */", "<!-- c -->"]:
            self.assertIn(line, cca.numbered_diff(diff_for("app/a.rb", ["x = 1", line])), line)

    def test_numbers_added_lines_by_new_file_line(self):
        self.assertIn("    2 +# why", cca.numbered_diff(diff_for("a.rb", ["x = 1", "# why"])))

    def test_drops_diffs_with_no_prose_comment(self):
        for path, added in [
            ("a.rb", ["x = \"#{y}\"", "  --model x \\"]),
            ("a.rb", ["# frozen_string_literal: true", "# rubocop:disable Foo"]),
            ("README.md", ["# Heading"]),
            ("docs/x.rb", ["# c"]),
            ("Gemfile.lock", ["# c"]),
            ("db/schema.rb", ["# c"]),
            ("a.sh", ["#!/bin/bash"]),
        ]:
            self.assertEqual(cca.numbered_diff(diff_for(path, added)), "", f"{path} {added}")


class EndToEnd(unittest.TestCase):
    """Runs the hook against a temp repo, with a stub `claude` that records its call."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.repo = os.path.join(self.tmp, "repo")
        os.makedirs(self.repo)
        git = lambda *a: subprocess.run(["git", "-C", self.repo, *a], check=True, capture_output=True)
        git("init", "-q")
        with open(os.path.join(self.repo, "a.rb"), "w") as f:
            f.write("x = 1\n")
        git("add", "a.rb")
        self.git = git
        bin_dir = os.path.join(self.tmp, "bin")
        os.makedirs(bin_dir)
        self.called = os.path.join(self.tmp, "called")
        with open(os.path.join(bin_dir, "claude"), "w") as f:
            f.write(f"#!/bin/sh\ncat > {self.called}\necho \"$STUB_VERDICT\"\n")
        os.chmod(os.path.join(bin_dir, "claude"), 0o755)
        self.env = {**os.environ, "PATH": bin_dir + os.pathsep + os.environ["PATH"]}

    def run_hook(self, cmd, verdict):
        payload = json.dumps({"tool_input": {"command": cmd}, "cwd": self.repo})
        return subprocess.run([sys.executable, HOOK], input=payload, capture_output=True, text=True,
                              env={**self.env, "STUB_VERDICT": json.dumps(verdict)})

    def stage(self, text):
        with open(os.path.join(self.repo, "a.rb"), "w") as f:
            f.write(text)
        self.git("add", "a.rb")

    def test_blocks_with_the_models_reason(self):
        self.stage("# Previously used the old resolver.\nx = 1\n")
        r = self.run_hook("git commit -m x", {"structured_output": {"ok": False, "reason": "a.rb:1 narrates"}})
        self.assertEqual(r.returncode, 2)
        self.assertIn("a.rb:1 narrates", r.stderr)
        with open(self.called) as f:
            self.assertIn("    1 +# Previously used the old resolver.", f.read())

    def test_passes_when_the_model_approves(self):
        self.stage("# Settlement runs at 9pm AEST.\nx = 1\n")
        r = self.run_hook("git commit -m x", {"structured_output": {"ok": True, "reason": ""}})
        self.assertEqual(r.returncode, 0)

    def test_skips_the_model_when_no_comment_is_added(self):
        self.stage("x = 2\n")
        self.assertEqual(self.run_hook("git commit -m x", {"structured_output": {"ok": False, "reason": "no"}}).returncode, 0)
        self.assertFalse(os.path.exists(self.called))

    def test_skips_non_commits_and_user_comments(self):
        self.stage("# Previously used the old resolver.\nx = 1\n")
        bad = {"structured_output": {"ok": False, "reason": "no"}}
        self.assertEqual(self.run_hook("git push", bad).returncode, 0)
        self.assertEqual(self.run_hook("GUARD_SKIP_COMMENTS=user git commit -m x", bad).returncode, 0)
        self.assertFalse(os.path.exists(self.called))

    def test_fails_open_on_garbage_from_the_model(self):
        self.stage("# Previously used the old resolver.\nx = 1\n")
        self.assertEqual(self.run_hook("git commit -m x", "not json").returncode, 0)


if __name__ == "__main__":
    unittest.main()
