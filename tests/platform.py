#!/usr/bin/env python3
"""Deteccion y preflight aislados, sin paquetes, red ni cambios del host."""

import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
GIT = shutil.which("git")


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-platform-test-")
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.release = self.base / "os-release"
        self.fallback = self.base / "vendor-release"
        self.release.write_text('ID=ubuntu\nNAME="Ubuntu"\nVERSION_ID="24.04"\n')
        self.env = dict(os.environ)
        for key in tuple(self.env):
            if key.startswith("DOTFILES_"):
                self.env.pop(key)
        self.env.update(HOME=str(self.base / "home with spaces"), XDG_CONFIG_HOME=str(self.base / "config"), XDG_STATE_HOME=str(self.base / "state"), XDG_DATA_HOME=str(self.base / "data"), XDG_CACHE_HOME=str(self.base / "cache"), XDG_CURRENT_DESKTOP="XFCE", DOTFILES_ALLOW_ROOT="1", PATH=f"{self.bin}:{os.environ['PATH']}")
        home = Path(self.env["HOME"])
        home.mkdir()
        (home / ".zshrc").write_text("configuracion personal\n")
        self.executable("uname", "printf 'x86_64\\n'\n")
        for name in ("apt-get", "dpkg-query", "pacman", "sudo", "chsh"):
            self.executable(name, "exit 97\n")

    def executable(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body)
        path.chmod(0o755)

    def invoke(self, arguments, **environment):
        return subprocess.run(arguments, cwd=ROOT, env=self.env | environment, text=True, capture_output=True)

    def detect(self, architecture="x86_64", code=None):
        if code is None:
            code = '''if dotfiles_platform_detect "$2" "$3" "$4"; then
    printf '%s\\n' "$DOTFILES_PLATFORM_ID" "$DOTFILES_PLATFORM_NAME" "$DOTFILES_PLATFORM_VERSION" "$DOTFILES_PLATFORM_ARCH" "$DOTFILES_PLATFORM_PACKAGE_FAMILY" "$DOTFILES_PLATFORM_ID_LIKE" "$DOTFILES_PLATFORM_OS_RELEASE"
else
    printf '%s\\n' "$DOTFILES_PLATFORM_ERROR" >&2
    exit 1
fi'''
        return self.invoke([BASH, "-c", 'source "$1/lib/common.sh"; source "$1/lib/platform.sh"; ' + code, "bash", str(ROOT), str(self.release), str(self.fallback), architecture])

    def repository(self):
        repo = self.base / "repository"
        repo.mkdir()
        for name in ("bin", "lib", "setup", "config"):
            shutil.copytree(ROOT / name, repo / name)
        # Solo la copia temporal inyecta rutas; la CLI de produccion no acepta
        # variables de entorno ni flags para sustituir os-release.
        platform = repo / "lib/platform.sh"
        platform.write_text(platform.read_text().replace("/etc/os-release", str(self.release)).replace("/usr/lib/os-release", str(self.fallback)))
        for arguments in (("init", "--quiet", "--template=", "-b", "dev"), ("add", "."), ("commit", "--quiet", "-m", "fixture")):
            result = self.invoke([GIT, "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-C", str(repo), *arguments])
            self.assertEqual(result.returncode, 0, result.stderr)
        return repo

    def snapshot(self):
        result = {}
        for path in self.base.rglob("*"):
            info = path.lstat()
            content = os.readlink(path) if path.is_symlink() else path.read_bytes() if stat.S_ISREG(info.st_mode) else None
            result[str(path.relative_to(self.base))] = (info.st_mode, info.st_mtime_ns, content)
        return result

    def guard_commands(self):
        self.env["TEST_COMMAND_LOG"] = str(self.base / "commands.log")
        for name in ("apt-get", "dpkg-query", "pacman", "git", "sudo", "chsh", "ln", "mv", "cp", "flock", "mkdir", "mktemp", "curl"):
            self.executable(name, 'printf "%s\\n" "${0##*/} $*" >> "$TEST_COMMAND_LOG"\nexit 97\n')

    def assert_rejected_without_changes(self, repo, operation, message, *options, **environment):
        before = self.snapshot()
        result = self.invoke([BASH, str(repo / "bin/dotfiles"), operation, *options], **environment)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)
        return result

    def limited_path(self, excluded):
        directory = Path(tempfile.mkdtemp(prefix="limited-bin-", dir=self.base))
        commands = ("bash", "dirname", "basename", "realpath", "uname", "apt-get", "dpkg-query", "git", "flock", "mktemp", "mkdir", "cp", "mv", "ln", "readlink", "rmdir", "rm", "find", "grep", "sed", "sort", "head", "tar", "sudo", "chsh")
        for command in commands:
            if command not in excluded:
                target = shutil.which(command, path=self.env["PATH"])
                self.assertIsNotNone(target, command)
                (directory / command).symlink_to(target)
        return str(directory)

    def test_distribution_fields_and_package_families(self):
        examples = (
            ("ID=arch\nNAME=\"Arch Linux\"\n", "arch", "Arch Linux", "", "pacman"),
            ("ID='ubuntu'\nNAME=Ubuntu\nVERSION_ID='24.04'\n", "ubuntu", "Ubuntu", "24.04", "apt"),
            ('ID=debian\nNAME="Debian GNU/Linux"\nVERSION_ID="13"\n', "debian", "Debian GNU/Linux", "13", "apt"),
            ('ID=linuxmint\nNAME="Linux Mint"\nID_LIKE="ubuntu debian"\n', "linuxmint", "Linux Mint", "", "unknown"),
        )
        for contents, identifier, name, version, family in examples:
            with self.subTest(identifier=identifier):
                self.release.write_text(contents)
                result = self.detect()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines()[:5], [identifier, name, version, "x86_64", family])

    def test_architecture_is_identified_without_certifying_it(self):
        for architecture in ("x86_64", "aarch64", "arm64", "riscv64", "ppc64le"):
            with self.subTest(architecture=architecture):
                result = self.detect(architecture)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines()[3], architecture)

    def test_vendor_fallback_and_primary_precedence(self):
        self.fallback.write_text("ID=arch\n")
        self.assertEqual(self.detect().stdout.splitlines()[0], "ubuntu")
        self.release.unlink()
        result = self.detect()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[0], "arch")
        self.assertEqual(result.stdout.splitlines()[6], str(self.fallback))

    def test_invalid_existing_primary_does_not_fall_back(self):
        self.fallback.write_text("ID=debian\n")
        for contents in ("", "NAME=Ubuntu\n", 'ID="ubuntu\n'):
            with self.subTest(contents=contents):
                self.release.write_text(contents)
                self.assertNotEqual(self.detect().returncode, 0)
        self.release.unlink()
        self.release.symlink_to(self.base / "missing-primary")
        self.assertNotEqual(self.detect().returncode, 0)

    def test_missing_and_non_regular_files(self):
        self.release.unlink()
        self.assertIn("No se puede leer", self.detect().stderr)
        self.release.mkdir()
        self.assertNotEqual(self.detect().returncode, 0)

    def test_malformed_data_is_rejected(self):
        examples = ("ID=Ubuntu\n", "ID=ubuntu extra\n", 'ID="ubuntu" "debian"\n', "ID=ubuntu\nVERSION_ID='24.04 invalid'\n", "export ID=ubuntu\n", "ID=ubuntu\r\n", 'ID=ubuntu\nNAME="unterminated\n', 'ID=ubuntu\nNAME="bad\tname"\n', "ID=ubuntu\nVERSION_CODENAME=../../escape\n", "ID=ubu\x00ntu\n")
        for contents in examples:
            with self.subTest(contents=contents):
                self.release.write_text(contents)
                self.assertNotEqual(self.detect().returncode, 0)

    def test_shell_content_is_never_executed(self):
        marker = self.base / "executed"
        examples = (f'ID=ubuntu\nNAME="$(touch {marker})"\n', f"ID=ubuntu\nNAME=`touch {marker}`\n", f"ID=ubuntu;touch {marker}\n")
        for contents in examples:
            with self.subTest(contents=contents):
                self.release.write_text(contents)
                self.assertNotEqual(self.detect().returncode, 0)
                self.assertFalse(marker.exists())
        self.release.write_text(f"ID=ubuntu\nVENDOR_EXTRA=$(touch {marker})\n")
        self.assertEqual(self.detect().returncode, 0)
        self.assertFalse(marker.exists())

    def test_quotes_escapes_comments_and_duplicate_keys(self):
        self.release.write_text('# Datos representativos\n\nID=ubuntu\nID=debian\n' + r'NAME="Debian \"test\" \\ \$literal \`literal"' + '\nVERSION_ID="13"')
        result = self.detect()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[0:3], ["debian", 'Debian "test" \\ $literal `literal', "13"])

    def test_detection_is_idempotent_and_clears_stale_results(self):
        code = '''dotfiles_platform_detect "$2" "$3" "$4"
first="$DOTFILES_PLATFORM_ID|$DOTFILES_PLATFORM_VERSION|$DOTFILES_PLATFORM_ARCH|$DOTFILES_PLATFORM_PACKAGE_FAMILY"
dotfiles_platform_detect "$2" "$3" "$4"
[[ "$first" == "$DOTFILES_PLATFORM_ID|$DOTFILES_PLATFORM_VERSION|$DOTFILES_PLATFORM_ARCH|$DOTFILES_PLATFORM_PACKAGE_FAMILY" ]]
if dotfiles_platform_detect "$2.missing" "$3.missing" "$4"; then exit 1; fi
[[ -z "$DOTFILES_PLATFORM_ID" && "$DOTFILES_PLATFORM_PACKAGE_FAMILY" == unknown ]]'''
        before = self.snapshot()
        result = self.detect(code=code)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_arch_install_update_stop_before_any_effect(self):
        self.release.write_text("ID=arch\n")
        repo = self.repository()
        self.guard_commands()
        for operation in ("install", "update"):
            for existing_state in (False, True):
                with self.subTest(operation=operation, existing_state=existing_state):
                    state = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/install.state"
                    if existing_state:
                        state.parent.mkdir(parents=True, exist_ok=True)
                        state.write_text("estado anterior que no debe leerse ni migrarse\n")
                        state.chmod(0o640)
                    else:
                        state.unlink(missing_ok=True)
                    options = ("--with-docker", "--migrate-state", "--change-shell") if operation == "install" else ("--with-avr",)
                    self.assert_rejected_without_changes(repo, operation, "backend Pacman", *options)

    def test_unknown_derivative_rejects_all_mutations(self):
        self.release.write_text('ID=linuxmint\nID_LIKE="ubuntu debian"\n')
        repo = self.repository()
        self.guard_commands()
        for operation in ("install", "update", "link"):
            with self.subTest(operation=operation):
                self.assert_rejected_without_changes(repo, operation, "ID=linuxmint")

    def test_missing_or_malformed_release_blocks_mutations(self):
        repo = self.repository()
        self.guard_commands()
        for contents in (None, "ID=ubuntu\ninvalid command\n", ""):
            if contents is None:
                self.release.unlink()
            else:
                self.release.write_text(contents)
            for operation in ("install", "update", "link"):
                with self.subTest(contents=contents, operation=operation):
                    self.assert_rejected_without_changes(repo, operation, "[error]")

    def test_unsupported_architecture_blocks_install_update_only(self):
        repo = self.repository()
        self.executable("uname", "printf 'riscv64\\n'\n")
        self.guard_commands()
        for operation in ("install", "update"):
            with self.subTest(operation=operation):
                self.assert_rejected_without_changes(repo, operation, "Arquitectura no contemplada")

    def test_environment_cannot_override_platform(self):
        self.release.write_text("ID=arch\n")
        repo = self.repository()
        self.guard_commands()
        fake = self.base / "fake-ubuntu"
        fake.write_text("ID=ubuntu\n")
        self.assert_rejected_without_changes(repo, "install", "backend Pacman", DOTFILES_OS_RELEASE=str(fake), DOTFILES_PLATFORM_ID="ubuntu", DOTFILES_PLATFORM_PACKAGE_FAMILY="apt", DOTFILES_PLATFORM_ARCH="x86_64")

    def test_missing_backend_command_fails_without_writes(self):
        repo = self.repository()
        for command in ("apt-get", "dpkg-query"):
            with self.subTest(command=command):
                path = self.limited_path({command})
                self.assert_rejected_without_changes(repo, "install", f"falta el requisito minimo {command}", PATH=path)

    def test_preflight_does_not_require_tools_installed_by_base(self):
        repo = self.repository()
        path = self.limited_path(set())
        before = self.snapshot()
        result = self.invoke([BASH, "-c", 'source "$1/lib/common.sh"; source "$1/lib/platform.sh"; dotfiles_platform_preflight install', "bash", str(repo)], PATH=path)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_missing_bootstrap_requirement_fails_before_lock(self):
        repo = self.repository()
        path = self.limited_path({"flock"})
        self.assert_rejected_without_changes(repo, "update", "falta el requisito minimo flock", PATH=path)

    def test_change_shell_is_validated_before_state(self):
        repo = self.repository()
        path = self.limited_path({"chsh"})
        self.assert_rejected_without_changes(repo, "install", "falta chsh", "--change-shell", PATH=path)

    def test_arch_link_needs_neither_backend_nor_supported_binary_architecture(self):
        self.release.write_text("ID=arch\n")
        repo = self.repository()
        self.executable("uname", "printf 'riscv64\\n'\n")
        path = self.limited_path({"apt-get", "dpkg-query", "pacman", "git", "flock", "sudo"})
        result = self.invoke([BASH, str(repo / "bin/dotfiles"), "link"], PATH=path)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        home = Path(self.env["HOME"])
        self.assertTrue((home / ".zshrc").is_symlink())
        backups = list(home.glob(".zshrc.backup.*/original"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "configuracion personal\n")
        before = self.snapshot()
        result = self.invoke([BASH, str(repo / "bin/dotfiles"), "link"], PATH=path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(Path(self.env["XDG_STATE_HOME"]).exists())

    def test_unknown_platform_keeps_help_static_check_and_diagnostics(self):
        self.release.write_text("ID=unknown\n")
        repo = self.repository()
        # Incluso --version puede crear datos auxiliares de Neovim. Este caso
        # valida la CLI/doctor con un sustituto, no el runtime del editor.
        self.executable("nvim", "printf 'NVIM v0.12.5\\n'\n")
        (repo / "bin/check.sh").write_text("#!/usr/bin/env bash\nprintf 'static check reached\\n'\n")
        for arguments in (("help",), ("--help",), ("install", "--help"), ("update", "--help")):
            result = self.invoke([BASH, str(repo / "bin/dotfiles"), *arguments])
            self.assertEqual(result.returncode, 0, result.stderr)
        result = self.invoke([BASH, str(repo / "bin/dotfiles"), "check"])
        self.assertEqual(result.stdout, "static check reached\n")
        before = self.snapshot()
        result = self.invoke([BASH, str(repo / "bin/dotfiles"), "doctor"])
        self.assertIn("ID=unknown", result.stdout)
        self.assertIn("solo se ejecuta el diagnostico", result.stdout)
        self.assertIn("pendientes", result.stdout)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
