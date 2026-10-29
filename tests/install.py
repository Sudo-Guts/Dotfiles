#!/usr/bin/env python3
"""Regresiones del instalador con Git local y sustitutos sin red ni privilegios."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GIT = shutil.which("git")


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-install-test-")
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ)
        for key in ("DOTFILES_APT_STAMP", "DOTFILES_APT_PACKAGES", "DOTFILES_NVIM_MODULES", "DOTFILES_UPDATE_REPO", "DOTFILES_UPDATE_APPLY_COMMIT"):
            self.env.pop(key, None)
        self.env.update(HOME=str(self.base / "home with spaces"), XDG_CONFIG_HOME=str(self.base / "config"), XDG_STATE_HOME=str(self.base / "state"), XDG_DATA_HOME=str(self.base / "data"), XDG_CACHE_HOME=str(self.base / "cache"), XDG_CURRENT_DESKTOP="XFCE", DOTFILES_ALLOW_ROOT="1", DOTFILES_UPDATE="0", PATH=f"{self.bin}:{os.environ['PATH']}")
        self.module_log = self.base / "modules.log"
        self.env["TEST_MODULE_LOG"] = str(self.module_log)

    def invoke(self, command, check=True, **environment):
        result = subprocess.run(command, cwd=ROOT, env=self.env | environment, text=True, capture_output=True)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def shell(self, code, **environment):
        return self.invoke(["bash", "-c", code, "bash", str(ROOT)], **environment)

    def executable(self, name, content):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + content)
        path.chmod(0o755)

    def git(self, repo, *arguments):
        return self.invoke([GIT, "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-C", str(repo), *arguments])

    def repository(self, stubs=True):
        repo = self.base / "repository"
        repo.mkdir()
        for name in ("bin", "lib", "setup", "config"):
            shutil.copytree(ROOT / name, repo / name)
        if stubs:
            for module in (repo / "setup/modules").glob("*.sh"):
                module.write_text('#!/usr/bin/env bash\nset -eu\nname="${0##*/}"\nprintf "%s\\n" "${name%.sh}" >> "$TEST_MODULE_LOG"\n[[ "${TEST_FAIL_MODULE:-}" != "${name%.sh}" ]]\n')
            (repo / "bin/doctor.sh").write_text("#!/usr/bin/env bash\nexit 0\n")
        self.git(repo, "init", "--quiet", "--template=", "-b", "main")
        self.git(repo, "add", ".")
        self.git(repo, "commit", "--quiet", "-m", "fixture")
        return repo

    def install(self, repo, *options, **environment):
        self.module_log.unlink(missing_ok=True)
        result = self.invoke(["bash", str(repo / "bin/dotfiles"), "install", *options], **environment)
        return result, self.module_log.read_text().splitlines()

    def state(self):
        path = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/install.state"
        return dict(line.split("=", 1) for line in path.read_text().splitlines())

    def test_core_and_persistent_options(self):
        repo = self.repository()
        _, modules = self.install(repo)
        self.assertTrue({"cpp", "python", "hdl"}.issubset(modules))
        self.assertFalse({"avr", "riscv", "docker", "apache", "ssh", "gnome"}.intersection(modules))
        self.assertEqual(modules[-1], "nvim-tools")
        self.assertEqual(len(modules), len(set(modules)))
        _, modules = self.install(repo, "--with-avr", "--with-ssh", "--with-gnome")
        self.assertTrue({"avr", "ssh"}.issubset(modules))
        self.assertNotIn("gnome", modules)
        _, repeated = self.install(repo)
        self.assertEqual(modules, repeated)
        self.assertEqual(self.state()["avr"], "1")
        self.assertEqual(self.state()["ssh"], "1")
        self.assertEqual(self.state()["pending_commit"], "")
        _, gnome = self.install(repo, XDG_CURRENT_DESKTOP="ubuntu:GNOME")
        self.assertIn("gnome", gnome)
        self.assertLess(gnome.index("kitty"), gnome.index("gnome"))

    def test_legacy_states_keep_selections(self):
        repo = self.repository()
        path = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/install.state"
        path.parent.mkdir(parents=True)
        for schema in range(1, 5):
            with self.subTest(schema=schema):
                text = f"schema={schema}\napplied_commit=\npending_commit=\nriscv=1\ndocker=0\ngnome=1\n"
                if schema >= 2:
                    text += "apache=1\nssh=0\n"
                if schema >= 3:
                    text += "avr=1\n"
                if schema >= 4:
                    text += "stm32=1\n"
                path.write_text(text)
                _, modules = self.install(repo)
                state = self.state()
                self.assertEqual(state["schema"], "4")
                self.assertEqual(state["riscv"], "1")
                self.assertEqual(state["gnome"], "1")
                self.assertEqual(state["stm32"], str(int(schema == 4)))
                self.assertEqual(state["avr"], str(int(schema >= 3)))
                self.assertEqual(state["apache"], str(int(schema >= 2)))
                self.assertIn("riscv", modules)
                self.assertNotIn("gnome", modules)
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_interrupted_install_can_resume(self):
        repo = self.repository()
        result, _ = self.install(repo, "--with-docker", TEST_FAIL_MODULE="hdl", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state()["docker"], "1")
        self.assertTrue(self.state()["pending_commit"])
        self.assertEqual(self.state()["applied_commit"], "")
        _, modules = self.install(repo)
        self.assertIn("docker", modules)
        self.assertEqual(self.state()["pending_commit"], "")
        self.assertEqual(self.state()["applied_commit"], self.git(repo, "rev-parse", "HEAD").stdout.strip())

    def test_update_uses_new_commit_and_keeps_options(self):
        repo = self.repository()
        self.install(repo, "--with-apache", "--with-riscv")
        self.git(repo, "switch", "--quiet", "-c", "upstream")
        (repo / "README.fixture").write_text("nueva revisión\n")
        self.git(repo, "add", ".")
        self.git(repo, "commit", "--quiet", "-m", "new revision")
        expected = self.git(repo, "rev-parse", "HEAD").stdout.strip()
        self.git(repo, "switch", "--quiet", "main")
        self.git(repo, "config", "branch.main.remote", ".")
        self.git(repo, "config", "branch.main.merge", "refs/heads/upstream")
        self.module_log.unlink()
        self.invoke(["bash", str(repo / "bin/dotfiles"), "update"])
        self.assertEqual(self.state()["applied_commit"], expected)
        self.assertEqual(self.state()["pending_commit"], "")
        self.assertTrue({"apache", "riscv", "hdl", "python"}.issubset(self.module_log.read_text().splitlines()))

    def test_manifest_rejects_dependency_out_of_order(self):
        repo = self.repository()
        manifest = repo / "setup/modules.conf"
        manifest.write_text("git|core|base|git gh|git gh\nbase|core||git|git\n")
        result = self.invoke(["bash", str(repo / "bin/dotfiles"), "install"], check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fuera de orden", result.stderr)
        self.assertFalse(self.module_log.exists())
        self.invoke(["bash", str(repo / "bin/dotfiles"), "help"])
        self.invoke(["bash", str(repo / "bin/dotfiles"), "link"])

    def test_doctor_only_requires_selected_components(self):
        repo = self.repository(stubs=False)
        rows = [line.split("|") for line in (repo / "setup/modules.conf").read_text().splitlines() if line and not line.startswith("#")]
        commands = {command.split(":", 1)[0] for row in rows for command in row[3].split()}
        for name in commands:
            self.executable(name, '''source "$TEST_VERSIONS"
case "${0##*/}" in
    nvim) if [[ "${1:-}" == --version ]]; then printf 'NVIM %s\\n' "$NVIM_VERSION"; fi ;;
    kitty) printf 'kitty %s\\n' "$KITTY_VERSION" ;;
    serie) printf 'serie %s\\n' "$SERIE_VERSION" ;;
    tree-sitter) printf 'tree-sitter %s\\n' "$TREE_SITTER_VERSION" ;;
esac
''')
        for row in rows:
            if row[0] == "avr":
                row[3] = "dotfiles-test-avr-absent"
        (repo / "setup/modules.conf").write_text("\n".join("|".join(row) for row in rows) + "\n")
        state = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/install.state"
        state.parent.mkdir(parents=True)
        state.write_text("schema=4\napplied_commit=\npending_commit=\nriscv=0\ndocker=0\ngnome=0\napache=0\nssh=0\navr=0\nstm32=0\n")
        font = Path(self.env["XDG_DATA_HOME"]) / "fonts/IosevkaNerdFont"
        font.mkdir(parents=True)
        version = self.shell('source "$1/setup/versions.sh"; printf "%s" "$NERD_FONT_VERSION"').stdout
        (font / ".version").write_text(version)
        (font / "test.ttf").touch()
        lazy = Path(self.env["XDG_DATA_HOME"]) / "nvim/lazy/lazy.nvim/lua/lazy"
        lazy.mkdir(parents=True)
        (lazy / "init.lua").touch()
        self.invoke(["bash", str(repo / "bin/dotfiles"), "link"])
        environment = dict(DOTFILES_DOCTOR_ALLOW_PENDING="1", TEST_VERSIONS=str(repo / "setup/versions.sh"))
        result = self.invoke(["bash", str(repo / "bin/doctor.sh")], **environment)
        self.assertNotIn("dotfiles-test-avr-absent", result.stdout)
        self.assertNotIn("OK docker:", result.stdout)
        self.assertIn("OK ghdl:", result.stdout)
        self.assertIn("OK python3:", result.stdout)
        state.write_text(state.read_text().replace("avr=0", "avr=1"))
        result = self.invoke(["bash", str(repo / "bin/doctor.sh")], check=False, **environment)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FALTA dotfiles-test-avr-absent", result.stdout)

    def test_apt_install_skips_available_packages(self):
        self.executable("dpkg-query", "printf 'install ok installed\\n'\n")
        self.executable("apt-get", "exit 0\n")
        log = self.base / "apt.log"
        self.shell('source "$1/lib/common.sh"; as_root() { printf "%s\\n" "$*" >> "$TEST_APT_LOG"; }; apt_install_module git', TEST_APT_LOG=str(log))
        self.assertFalse(log.exists())

    def test_apt_update_deduplicates_packages_and_refresh(self):
        self.executable("apt-get", "exit 0\n")
        log = self.base / "apt.log"
        self.shell('source "$1/lib/common.sh"; as_root() { printf "%s\\n" "$*" >> "$TEST_APT_LOG"; }; apt_install_module base; apt_install_module git; apt_install_module python', TEST_APT_LOG=str(log), DOTFILES_UPDATE="1", DOTFILES_APT_STAMP=str(self.base / "apt-refreshed"), DOTFILES_APT_PACKAGES=str(self.base / "apt-packages"))
        lines = log.read_text().splitlines()
        self.assertEqual(lines.count("apt-get update"), 1)
        packages = [package for line in lines if line.startswith("apt-get install ") for package in line.split()[4:]]
        self.assertEqual(len(packages), len(set(packages)))
        self.assertTrue({"git", "gh", "python3", "nodejs", "npm"}.issubset(packages))

    def test_nvim_preparation_only_repairs_missing_components(self):
        self.executable("tree-sitter", "exit 0\n")
        self.executable("nvim", '''if [[ "${DOTFILES_NVIM_READONLY:-}" == 1 ]]; then
    printf 'check\\n' >> "$TEST_NVIM_LOG"
    if [[ "$TEST_NVIM_STATE" != plugins-missing ]]; then printf 'ready\\n' > "$DOTFILES_NVIM_PLUGINS_READY"; fi
    [[ "$TEST_NVIM_STATE" == healthy ]]
elif [[ "$*" == *'Lazy! restore'* ]]; then
    printf 'restore\\n' >> "$TEST_NVIM_LOG"
else
    printf 'prepare\\n' >> "$TEST_NVIM_LOG"
fi
''')
        log = self.base / "nvim.log"
        for state, expected in (("healthy", ["check"]), ("tools-missing", ["check", "prepare"]), ("plugins-missing", ["check", "restore", "prepare"])):
            with self.subTest(state=state):
                log.unlink(missing_ok=True)
                self.invoke(["bash", str(ROOT / "setup/modules/nvim-tools.sh")], TEST_NVIM_LOG=str(log), TEST_NVIM_STATE=state)
                self.assertEqual(log.read_text().splitlines(), expected)

    def test_docker_reuses_key_and_repository(self):
        repo = self.repository(stubs=False)
        apt_root = self.base / "apt"
        (apt_root / "sources.list.d").mkdir(parents=True)
        release = self.base / "os-release"
        release.write_text("ID=debian\nVERSION_CODENAME=bookworm\n")
        module = repo / "setup/modules/docker.sh"
        module.write_text(module.read_text().replace("/etc/apt", str(apt_root)).replace("/etc/os-release", str(release)).replace("/run/systemd/system", str(self.base / "no-systemd")))
        with (repo / "lib/common.sh").open("a") as file:
            file.write('\n# Solo en la copia de prueba; todos los destinos están aislados.\nas_root() { "$@"; }\n')
        self.executable("dpkg-query", "printf 'install ok installed\\n'\n")
        self.executable("apt-get", 'printf "%s\\n" "$*" >> "$TEST_APT_LOG"\n')
        self.executable("curl", 'printf "key\\n" > "${@: -1}"\nprintf "download\\n" >> "$TEST_CURL_LOG"\n')
        self.executable("docker", "printf 'Docker test\\n'\n")
        apt_log, curl_log = self.base / "apt.log", self.base / "curl.log"
        environment = dict(TEST_APT_LOG=str(apt_log), TEST_CURL_LOG=str(curl_log), DOTFILES_APT_STAMP=str(self.base / "apt-refreshed"))
        self.invoke(["bash", str(module)], **environment)
        source = apt_root / "sources.list.d/docker.sources"
        initial = source.stat().st_mtime_ns
        self.invoke(["bash", str(module)], **environment)
        self.invoke(["bash", str(module)], DOTFILES_UPDATE="1", **environment)
        self.assertEqual(curl_log.read_text().splitlines(), ["download"])
        self.assertEqual(source.stat().st_mtime_ns, initial)
        self.assertEqual(apt_log.read_text().splitlines().count("update"), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
