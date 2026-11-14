#!/usr/bin/env python3
"""GUTS Dotfiles: contratos de paquetes con APT y dpkg-query simulados."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
MOCK = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

arguments = sys.argv[1:]
database = Path(os.environ["TEST_PACKAGE_DB"])
control = json.loads(Path(os.environ["TEST_APT_CONTROL"]).read_text())
packages = json.loads(database.read_text())
if Path(sys.argv[0]).name == "dpkg-query":
    with Path(os.environ["TEST_DPKG_LOG"]).open("a") as log:
        log.write(json.dumps(arguments) + "\\n")
    entry = packages.get(arguments[-1], {"code": 1})
    sys.stdout.write(entry.get("status", ""))
    sys.exit(control.get("query_code", entry.get("code", 0)))
with Path(os.environ["TEST_APT_LOG"]).open("a") as log:
    log.write(json.dumps(arguments) + "\\n")
if arguments == ["update"]:
    sys.exit(control.get("update", 0))
if arguments[:3] != ["install", "-y", "--no-install-recommends"]:
    sys.exit(97)
code = control.get("install", 0)
if code == 0:
    for package in arguments[3:]:
        packages[package] = {"code": 0, "status": "install ok installed"}
    database.write_text(json.dumps(packages))
sys.exit(code)
'''


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-packages-test-")
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.repo = self.base / "repository"
        self.repo.mkdir()
        for name in ("lib", "setup"):
            shutil.copytree(ROOT / name, self.repo / name)
        self.release = self.base / "os-release"
        self.release.write_text("ID=ubuntu\nVERSION_ID=24.04\n")
        platform = self.repo / "lib/platform.sh"
        platform.write_text(platform.read_text().replace("/etc/os-release", str(self.release)).replace("/usr/lib/os-release", str(self.base / "no-release")))
        self.bin = self.base / "bin"
        self.bin.mkdir()
        for command in ("apt-get", "dpkg-query"):
            path = self.bin / command
            path.write_text(MOCK)
            path.chmod(0o755)
        self.database = self.base / "packages.json"
        self.database.write_text("{}")
        self.control = self.base / "control.json"
        self.control.write_text("{}")
        self.apt_log = self.base / "apt.jsonl"
        self.query_log = self.base / "queries.jsonl"
        self.stamp = self.base / "apt-refreshed"
        self.processed = self.base / "apt-packages"
        self.env = dict(os.environ)
        for key in tuple(self.env):
            if key.startswith("DOTFILES_"):
                self.env.pop(key)
        self.env.update(HOME=str(self.base / "home"), XDG_CONFIG_HOME=str(self.base / "config"), XDG_DATA_HOME=str(self.base / "data"), XDG_STATE_HOME=str(self.base / "state"), XDG_CACHE_HOME=str(self.base / "cache"), PATH=f"{self.bin}:{os.environ['PATH']}", DOTFILES_UPDATE="0", DOTFILES_APT_STAMP=str(self.stamp), DOTFILES_APT_PACKAGES=str(self.processed), TEST_PACKAGE_DB=str(self.database), TEST_APT_CONTROL=str(self.control), TEST_APT_LOG=str(self.apt_log), TEST_DPKG_LOG=str(self.query_log), TEST_PRIVILEGE_LOG=str(self.base / "privileges.log"))
        Path(self.env["HOME"]).mkdir()
        (Path(self.env["HOME"]) / ".zshrc").write_text("conservar configuracion personal\n")
        # Solo la copia temporal sustituye privilegios; los modulos hijos
        # cargan esta misma copia y nunca ejecutan sudo ni el APT del host.
        with (self.repo / "lib/common.sh").open("a") as common:
            common.write('\nas_root() { printf "%s\\n" "$*" >> "$TEST_PRIVILEGE_LOG"; "$@"; }\n')

    def shell(self, code, *arguments, **environment):
        return subprocess.run([BASH, "-c", 'source "$1/lib/common.sh"\n' + code, "bash", str(self.repo), *arguments], cwd=self.repo, env=self.env | environment, text=True, capture_output=True)

    def call(self, interface, *arguments, **environment):
        return self.shell('"$2" "${@:3}"', interface, *arguments, **environment)

    def conditional_call(self, interface, *arguments, **environment):
        code = '''if "$2" "${@:3}"; then result_code=0; else result_code=$?; fi
printf 'STATUS=%s\\n' "$result_code"
exit "$result_code"'''
        return self.shell(code, interface, *arguments, **environment)

    def success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def lines(self, path):
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def apt(self):
        return self.lines(self.apt_log)

    def controls(self, **values):
        self.control.write_text(json.dumps(values))

    def installed(self, *packages, status="install ok installed"):
        data = json.loads(self.database.read_text())
        data.update({package: {"code": 0, "status": status} for package in packages})
        self.database.write_text(json.dumps(data))

    def snapshot(self):
        return {str(path.relative_to(self.base)): (path.stat().st_mode, path.stat().st_mtime_ns, path.read_bytes() if path.is_file() else None) for path in self.base.rglob("*")}

    def test_loading_libraries_has_no_package_effects(self):
        self.release.write_text("malformed os-release\n")
        before = self.snapshot()
        self.success(self.shell("declare -F apt_install apt_install_module dotfiles_packages_install dotfiles_packages_install_module"))
        self.assertEqual(self.snapshot(), before)

    def test_installed_package_is_not_reinstalled(self):
        self.installed("alpha")
        self.success(self.call("apt_install", "alpha", "alpha"))
        self.assertEqual(self.apt(), [])
        self.assertEqual(self.lines(self.query_log), [["-W", "-f=${Status}", "alpha"]])
        self.assertFalse(self.stamp.exists())
        self.assertFalse(self.processed.exists())

    def test_missing_package_preserves_install_arguments_and_privileges(self):
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(self.apt(), [["update"], ["install", "-y", "--no-install-recommends", "alpha"]])
        self.assertEqual((self.base / "privileges.log").read_text().splitlines(), ["apt-get update", "apt-get install -y --no-install-recommends alpha"])
        self.assertEqual(self.processed.read_text(), "alpha\n")
        self.assertTrue(self.stamp.exists())

    def test_empty_requests_do_not_refresh_or_install(self):
        before = self.snapshot()
        for interface in ("apt_install", "dotfiles_packages_install"):
            self.success(self.call(interface))
        for interface in ("apt_install_module", "dotfiles_packages_install_module"):
            self.success(self.call(interface, "nvim-tools"))
        self.assertEqual(self.snapshot(), before)

    def test_empty_package_argument_is_rejected(self):
        result = self.conditional_call("dotfiles_packages_install", "")
        self.assertEqual(result.returncode, 1)
        self.assertIn("vacio", result.stderr)
        self.assertEqual(self.apt(), [])

    def test_duplicate_arguments_are_requested_once_in_order(self):
        self.success(self.call("dotfiles_packages_install", "alpha", "alpha", "beta", "alpha"))
        self.assertEqual(self.apt()[-1], ["install", "-y", "--no-install-recommends", "alpha", "beta"])
        self.assertEqual([query[-1] for query in self.lines(self.query_log)], ["alpha", "beta"])
        self.assertEqual(self.processed.read_text(), "alpha\nbeta\n")

    def test_processed_packages_skip_queries_even_during_update(self):
        self.processed.write_text("alpha\n")
        self.controls(query_code=2)
        self.success(self.call("apt_install", "alpha", DOTFILES_UPDATE="1"))
        self.assertEqual(self.apt(), [])
        self.assertEqual(self.lines(self.query_log), [])
        self.assertFalse(self.stamp.exists())

    def test_shared_modules_and_interfaces_deduplicate_across_processes(self):
        for interface, module in (("dotfiles_packages_install_module", "base"), ("apt_install_module", "git"), ("dotfiles_packages_install_module", "python")):
            self.success(self.call(interface, module, DOTFILES_UPDATE="1"))
        calls = self.apt()
        self.assertEqual(calls.count(["update"]), 1)
        packages = [package for call in calls if call[0] == "install" for package in call[3:]]
        self.assertEqual(len(packages), len(set(packages)))
        self.assertTrue({"git", "gh", "python3", "python3-venv", "nodejs", "npm"}.issubset(packages))
        self.assertEqual(self.lines(self.query_log), [])

    def test_update_reconciles_installed_packages_without_querying(self):
        self.installed("alpha")
        self.controls(query_code=2)
        self.success(self.call("dotfiles_packages_install", "alpha", DOTFILES_UPDATE="1"))
        self.success(self.call("apt_install", "alpha", DOTFILES_UPDATE="1"))
        self.assertEqual(self.apt(), [["update"], ["install", "-y", "--no-install-recommends", "alpha"]])
        self.assertEqual(self.lines(self.query_log), [])

    def test_unconfigured_package_is_repaired(self):
        self.installed("alpha", status="install ok unpacked")
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(self.apt()[-1][-1], "alpha")

    def test_query_fatal_error_is_not_treated_as_missing(self):
        self.controls(query_code=2)
        result = self.conditional_call("apt_install", "alpha")
        self.assertEqual(result.returncode, 2)
        self.assertIn("dpkg-query", result.stderr)
        self.assertEqual(self.apt(), [])
        self.assertFalse(self.stamp.exists())
        self.assertFalse(self.processed.exists())
        self.controls()
        self.success(self.call("dotfiles_packages_install", "alpha"))

    def test_query_command_failure_is_propagated(self):
        self.controls(query_code=127)
        result = self.conditional_call("dotfiles_packages_install", "alpha")
        self.assertEqual(result.returncode, 127)
        self.assertEqual(self.apt(), [])

    def test_nonconditional_errors_keep_exit_status_in_bash_c(self):
        for controls, expected in (({"query_code": 2}, 2), ({"update": 100}, 100)):
            with self.subTest(controls=controls):
                self.controls(**controls)
                result = self.call("dotfiles_packages_install", "alpha")
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertNotIn("unbound variable", result.stderr)
                self.assertFalse(self.processed.exists())

    def test_failed_refresh_does_not_install_or_record_and_can_retry(self):
        self.controls(update=100)
        result = self.conditional_call("apt_install", "alpha")
        self.assertEqual(result.returncode, 100)
        self.assertIn("STATUS=100", result.stdout)
        self.assertEqual(self.apt(), [["update"]])
        self.assertFalse(self.stamp.exists())
        self.assertFalse(self.processed.exists())
        self.controls()
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(self.apt(), [["update"], ["update"], ["install", "-y", "--no-install-recommends", "alpha"]])
        self.assertEqual(self.processed.read_text(), "alpha\n")

    def test_failed_install_reuses_successful_refresh_on_retry(self):
        self.controls(install=100)
        result = self.conditional_call("dotfiles_packages_install", "alpha")
        self.assertEqual(result.returncode, 100)
        self.assertIn("STATUS=100", result.stdout)
        self.assertTrue(self.stamp.exists())
        self.assertFalse(self.processed.exists())
        self.controls()
        self.success(self.call("apt_install", "alpha"))
        self.assertEqual(self.apt().count(["update"]), 1)
        self.assertEqual(len([call for call in self.apt() if call[0] == "install"]), 2)
        self.assertEqual(self.processed.read_text(), "alpha\n")

    def test_marker_write_failure_is_propagated_before_install(self):
        self.stamp.mkdir()
        result = self.conditional_call("dotfiles_packages_install", "alpha")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.apt(), [["update"]])
        self.assertFalse(self.processed.exists())

    def test_package_record_failure_is_not_reported_as_success(self):
        self.processed.mkdir()
        result = self.conditional_call("dotfiles_packages_install", "alpha")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.apt()[-1][-1], "alpha")

    def test_standalone_install_without_markers_keeps_installed_packages(self):
        environment = {"DOTFILES_APT_STAMP": "", "DOTFILES_APT_PACKAGES": ""}
        self.success(self.call("apt_install", "alpha", **environment))
        self.success(self.call("dotfiles_packages_install", "alpha", **environment))
        self.assertEqual(self.apt().count(["update"]), 1)
        self.assertEqual(len(self.apt()), 2)
        self.assertFalse(self.stamp.exists())
        self.assertFalse(self.processed.exists())

    def test_module_interfaces_keep_both_apt_distributions(self):
        for distro, interface in (("ubuntu", "apt_install_module"), ("debian", "dotfiles_packages_install_module")):
            with self.subTest(distro=distro):
                self.release.write_text(f"ID={distro}\n")
                self.success(self.call(interface, "git", DOTFILES_UPDATE="1"))
        self.assertEqual(self.apt(), [["update"], ["install", "-y", "--no-install-recommends", "git", "gh"]])

    def test_package_requests_do_not_activate_optional_modules(self):
        code = 'dotfiles_packages_install_module avr\n[[ "${DOTFILES_WITH_AVR:-0}" == 0 ]]'
        self.success(self.shell(code))
        self.assertIn("gcc-avr", self.apt()[-1])

    def test_unknown_module_is_rejected_without_package_operations(self):
        for interface in ("apt_install_module", "dotfiles_packages_install_module"):
            before = self.snapshot()
            result = self.call(interface, "unknown-module")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unknown-module", result.stderr)
            self.assertEqual(self.snapshot(), before)

    def test_unknown_backends_reject_every_public_interface(self):
        for distro in ("unknown", "linuxmint"):
            self.release.write_text(f'ID={distro}\nID_LIKE="ubuntu debian"\n')
            for interface, argument in (("apt_install", "alpha"), ("dotfiles_packages_install", "alpha"), ("apt_install_module", "base"), ("dotfiles_packages_install_module", "base"), ("dotfiles_packages_install_module", "nvim-tools")):
                with self.subTest(distro=distro, interface=interface, argument=argument):
                    before = self.snapshot()
                    result = self.call(interface, argument, DOTFILES_PLATFORM_PACKAGE_FAMILY="apt")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(distro, result.stderr)
                    self.assertEqual(self.snapshot(), before)

    def test_arch_rejects_historical_apt_names_before_any_manager(self):
        self.release.write_text("ID=arch\n")
        before = self.snapshot()
        result = self.call("apt_install", "build-essential", DOTFILES_PLATFORM_PACKAGE_FAMILY="apt")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no se envian nombres APT a Pacman", result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_riscv_system_mode_preserves_package_contract(self):
        result = self.shell('bash "$1/setup/modules/riscv.sh"')
        self.success(result)
        self.assertEqual(self.apt()[-1], ["install", "-y", "--no-install-recommends", "gcc-riscv64-unknown-elf", "binutils-riscv64-unknown-elf", "gdb-multiarch", "qemu-system-misc"])

    def test_riscv_source_dependencies_use_compatibility_interface(self):
        with (self.repo / "lib/common.sh").open("a") as common:
            common.write('\nsync_repo() { printf "%s\\n" "$*" > "$TEST_SYNC_LOG"; exit 73; }\n')
        result = self.shell('bash "$1/setup/modules/riscv.sh" --source', TEST_SYNC_LOG=str(self.base / "sync.log"), RISCV_BUILD_PREFIX=str(self.base / "riscv"))
        # El centinela detiene la prueba antes de clonar o compilar.
        self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
        packages = self.apt()[-1][3:]
        self.assertTrue({"autoconf", "automake", "python3-pip", "python3-tomli", "build-essential", "libmpc-dev", "libslirp-dev", "libboost-regex-dev", "libboost-system-dev"}.issubset(packages))
        self.assertEqual(len(packages), len(set(packages)))
        self.assertEqual(self.apt().count(["update"]), 1)
        self.assertIn("riscv-collab/riscv-gnu-toolchain.git", (self.base / "sync.log").read_text())
        self.assertFalse((self.base / "riscv/.toolchain-complete").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
