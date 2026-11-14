#!/usr/bin/env python3
"""GUTS Dotfiles: Pacman, catalogo e integracion con gestores simulados."""

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
with Path(os.environ["TEST_MANAGER_LOG"]).open("a") as log:
    log.write(json.dumps({"command": Path(sys.argv[0]).name, "arguments": arguments, "privileged": os.environ.get("TEST_PRIVILEGED") == "1"}) + "\\n")
if Path(sys.argv[0]).name != "pacman":
    sys.exit(96)
control = json.loads(Path(os.environ["TEST_PACMAN_CONTROL"]).read_text())
database = Path(os.environ["TEST_PACKAGE_DB"])
installed = json.loads(database.read_text())
if arguments[:2] == ["-T", "--"]:
    if "query_code" in control:
        sys.stdout.write(control.get("query_output", ""))
        sys.exit(control["query_code"])
    missing = [p for p in arguments[2:] if p not in installed and p not in control.get("provides", [])]
    if control.get("reverse"):
        missing.reverse()
    if missing:
        print("\\n".join(missing))
        sys.exit(127)
    sys.exit(0)
if arguments[:3] != ["-S", "--needed", "--"] or not arguments[3:]:
    sys.exit(97)
code = control.get("install_code", 0)
for package in arguments[3:] if code == 0 else control.get("partial", []):
    if package not in installed:
        installed.append(package)
database.write_text(json.dumps(installed))
sys.exit(code)
'''


class PacmanTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="dotfiles-pacman-test-")
        self.addCleanup(self.directory.cleanup)
        self.base = Path(self.directory.name)
        self.repo = self.base / "repository"
        self.repo.mkdir()
        for name in ("bin", "lib", "setup", "config"):
            shutil.copytree(ROOT / name, self.repo / name)
        self.release = self.base / "os-release"
        self.release.write_text("ID=arch\n")
        platform = self.repo / "lib/platform.sh"
        platform.write_text(platform.read_text().replace("/etc/os-release", str(self.release)).replace("/usr/lib/os-release", str(self.base / "no-release")))
        self.bin = self.base / "bin"
        self.bin.mkdir()
        for command in ("pacman", "apt-get", "dpkg-query", "sudo", "systemctl", "curl", "git", "rm", "flock"):
            self.executable(command, MOCK)
        self.database = self.base / "packages.json"
        self.database.write_text("[]")
        self.control = self.base / "control.json"
        self.control.write_text("{}")
        self.manager_log = self.base / "managers.jsonl"
        self.privilege_log = self.base / "privileges.log"
        self.catalog = self.repo / "setup/packages/arch.conf"
        self.env = {key: value for key, value in os.environ.items() if not key.startswith(("DOTFILES_", "TEST_"))}
        self.env.update(HOME=str(self.base / "home"), XDG_CONFIG_HOME=str(self.base / "config"), XDG_DATA_HOME=str(self.base / "data"), XDG_STATE_HOME=str(self.base / "state"), XDG_CACHE_HOME=str(self.base / "cache"), PATH=f"{self.bin}:{os.environ['PATH']}", DOTFILES_UPDATE="0", DOTFILES_DOCTOR_ALLOW_PENDING="1", XDG_CURRENT_DESKTOP="", TEST_MANAGER_LOG=str(self.manager_log), TEST_PACMAN_CONTROL=str(self.control), TEST_PACKAGE_DB=str(self.database), TEST_PRIVILEGE_LOG=str(self.privilege_log))
        Path(self.env["HOME"]).mkdir()
        (Path(self.env["HOME"]) / ".zshrc").write_text("conservar configuracion personal\n")
        # La copia ejecuta los modulos reales con todos los gestores sustituidos.
        # Las consultas no heredan privilegios; solo as_root marca la instalacion.
        with (self.repo / "lib/common.sh").open("a") as common:
            common.write('\nas_root() { printf "%s\\n" "$*" >> "$TEST_PRIVILEGE_LOG"; TEST_PRIVILEGED=1 "$@"; }\n')

    def executable(self, name, text):
        path = self.bin / name
        path.write_text(text)
        path.chmod(0o755)

    def shell(self, code, *arguments, **environment):
        return subprocess.run([BASH, "-c", 'source "$1/lib/common.sh"\n' + code, "bash", str(self.repo), *arguments], cwd=self.repo, env=self.env | environment, text=True, capture_output=True)

    def call(self, interface, *arguments, **environment):
        return self.shell('"$2" "${@:3}"', interface, *arguments, **environment)

    def conditional(self, *arguments, **environment):
        return self.shell('if dotfiles_packages_install "${@:2}"; then code=0; else code=$?; fi\nexit "$code"', *arguments, **environment)

    def success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def controls(self, **values):
        self.control.write_text(json.dumps(values))

    def installed(self, *packages):
        self.database.write_text(json.dumps(list(packages)))

    def calls(self):
        return [json.loads(line) for line in self.manager_log.read_text().splitlines()] if self.manager_log.exists() else []

    def arguments(self):
        calls = self.calls()
        self.assertTrue(all(call["command"] == "pacman" for call in calls), calls)
        return [call["arguments"] for call in calls]

    def installs(self):
        return [call for call in self.arguments() if call[0] == "-S"]

    def snapshot(self):
        return {str(path.relative_to(self.base)): (path.lstat().st_mode, path.lstat().st_mtime_ns, os.readlink(path) if path.is_symlink() else path.read_bytes() if path.is_file() else None) for path in self.base.rglob("*")}

    def resolve(self, name):
        return self.shell('dotfiles_packages_resolve_module "$2"\nprintf "%s\\n%s\\n%s\\n%s\\n" "$DOTFILES_RESOLVED_STATE" "${DOTFILES_RESOLVED_PACKAGES[*]}" "$DOTFILES_RESOLVED_COMMANDS" "$DOTFILES_RESOLVED_REASON"', name)

    def replace_row(self, name, replacement):
        lines = self.catalog.read_text().splitlines()
        self.catalog.write_text("\n".join(replacement if line.startswith(name + "|") else line for line in lines) + "\n")

    def test_loading_is_passive_even_without_release_or_pacman(self):
        self.release.unlink()
        (self.bin / "pacman").unlink()
        before = self.snapshot()
        self.success(self.shell("declare -F dotfiles_packages_pacman_install dotfiles_packages_install apt_install_module"))
        self.assertEqual(self.snapshot(), before)

    def test_empty_requests_and_none_module_never_query_or_install(self):
        before = self.snapshot()
        self.success(self.call("dotfiles_packages_install"))
        self.success(self.call("dotfiles_packages_install_module", "nvim-tools"))
        self.success(self.call("apt_install_module", "nvim"))
        self.assertEqual(self.snapshot(), before)

    def test_installed_package_is_only_queried_without_privileges(self):
        self.installed("alpha")
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(self.arguments(), [["-T", "--", "alpha"]])
        self.assertFalse(self.calls()[0]["privileged"])
        self.assertFalse(self.privilege_log.exists())

    def test_installed_provider_satisfies_native_requirement(self):
        self.controls(provides=["alpha"])
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(self.installs(), [])

    def test_missing_packages_keep_order_and_only_install_uses_as_root(self):
        self.installed("present")
        self.controls(reverse=True)
        self.success(self.call("dotfiles_packages_install", "beta", "present", "alpha"))
        self.assertEqual(self.arguments(), [["-T", "--", "beta", "present", "alpha"], ["-S", "--needed", "--", "beta", "alpha"]])
        self.assertEqual([call["privileged"] for call in self.calls()], [False, True])
        self.assertEqual(self.privilege_log.read_text(), "pacman -S --needed -- beta alpha\n")

    def test_duplicate_requests_install_each_package_once(self):
        self.success(self.call("dotfiles_packages_install", "beta", "beta", "alpha", "beta"))
        self.assertEqual(self.arguments(), [["-T", "--", "beta", "alpha"], ["-S", "--needed", "--", "beta", "alpha"]])

    def test_shared_modules_do_not_repeat_installs_across_processes(self):
        for interface, module in (("dotfiles_packages_install_module", "base"), ("apt_install_module", "git"), ("dotfiles_packages_install_module", "zsh"), ("apt_install_module", "python"), ("dotfiles_packages_install_module", "cpp"), ("dotfiles_packages_install_module", "avr")):
            self.success(self.call(interface, module))
        packages = [package for call in self.installs() for package in call[3:]]
        self.assertEqual(len(packages), len(set(packages)))
        self.assertTrue({"fd", "xz", "python", "github-cli", "ninja", "pkgconf", "clang", "avr-gcc"}.issubset(packages))
        self.assertTrue({"fd-find", "xz-utils", "python3", "gh", "ninja-build", "build-essential", "gcc-avr"}.isdisjoint(packages))

    def test_update_also_queries_and_keeps_installed_packages(self):
        for update in ("0", "1"):
            with self.subTest(update=update):
                self.installed("present")
                start = len(self.calls())
                self.success(self.call("dotfiles_packages_install", "present", "new", DOTFILES_UPDATE=update))
                calls = self.arguments()[start:]
                self.assertEqual(calls, [["-T", "--", "present", "new"], ["-S", "--needed", "--", "new"]])
                self.success(self.call("dotfiles_packages_install", "present", "new", DOTFILES_UPDATE=update))
                self.assertEqual(len(self.calls()) - start, 3)

    def test_query_error_is_propagated_and_retry_queries_again(self):
        for code in (1, 2, 42):
            with self.subTest(code=code):
                self.controls(query_code=code, query_output="alpha\n")
                result = self.conditional("alpha")
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertIn("pacman -T fallo", result.stderr)
                self.assertEqual(self.installs(), [])
        self.controls()
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(len(self.installs()), 1)

    def test_empty_missing_result_with_127_is_an_error(self):
        self.controls(query_code=127)
        result = self.conditional("alpha")
        self.assertEqual(result.returncode, 127)
        self.assertEqual(self.installs(), [])

    def test_malformed_query_output_cannot_add_install_targets(self):
        for code, output in ((0, "alpha\n"), (127, "unknown\n"), (127, "--refresh\n"), (127, "alpha beta\n"), (127, "alpha\n\nbeta\n")):
            with self.subTest(code=code, output=output):
                self.controls(query_code=code, query_output=output)
                result = self.conditional("alpha", "beta")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.installs(), [])

    def test_install_error_preserves_status_and_can_retry(self):
        self.controls(install_code=73)
        result = self.conditional("alpha")
        self.assertEqual(result.returncode, 73, result.stderr)
        self.assertEqual(json.loads(self.database.read_text()), [])
        self.controls()
        self.success(self.call("dotfiles_packages_install", "alpha"))
        self.assertEqual(self.arguments(), [["-T", "--", "alpha"], ["-S", "--needed", "--", "alpha"], ["-T", "--", "alpha"], ["-S", "--needed", "--", "alpha"]])

    def test_partial_failure_retry_only_requests_remaining_packages(self):
        self.controls(install_code=74, partial=["alpha"])
        self.assertEqual(self.conditional("alpha", "beta").returncode, 74)
        self.controls()
        self.success(self.call("dotfiles_packages_install", "alpha", "beta"))
        self.assertEqual(self.installs()[-1], ["-S", "--needed", "--", "beta"])

    def test_nonconditional_error_retains_code_without_unbound_variables(self):
        for control, expected in (({"query_code": 3}, 3), ({"install_code": 75}, 75)):
            self.controls(**control)
            result = self.call("dotfiles_packages_install", "alpha")
            self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
            self.assertNotIn("unbound variable", result.stderr)

    def test_invalid_native_names_fail_before_any_manager(self):
        before = self.snapshot()
        for name in ("", "-Sy", "--noconfirm", "alpha beta", "alpha>=1", "$(touch unexpected)", "../alpha"):
            with self.subTest(name=name):
                self.assertNotEqual(self.conditional(name).returncode, 0)
                self.assertEqual(self.snapshot(), before)

    def test_pacman_failure_does_not_delete_its_database_or_lock(self):
        lock = self.base / "pacman/db.lck"
        lock.parent.mkdir()
        lock.write_text("bloqueo ajeno\n")
        database = lock.with_name("local")
        database.mkdir()
        record = database / "desc"
        record.write_text("base local del usuario\n")
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in (lock, record)}
        self.controls(install_code=1)
        self.assertEqual(self.conditional("alpha").returncode, 1)
        self.assertEqual({p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before}, before)
        self.assertEqual(self.installs(), [["-S", "--needed", "--", "alpha"]])

    def test_complete_catalog_covers_modules_without_package_effects(self):
        code = '''source "$1/lib/modules.sh"
for module in "${DOTFILES_MODULES[@]}"; do
    dotfiles_packages_resolve_module "$module"
    printf '%s:%s\\n' "$module" "$DOTFILES_RESOLVED_STATE"
done'''
        before = self.snapshot()
        result = self.shell(code)
        self.success(result)
        rows = dict(line.split(":") for line in result.stdout.splitlines())
        self.assertEqual(len(rows), 18)
        self.assertEqual({name for name, state in rows.items() if state == "pending"}, {"hdl", "docker", "riscv"})
        self.assertEqual(rows["nvim-tools"], "none")
        self.assertEqual(self.snapshot(), before)

    def test_known_differences_and_diagnostic_commands_resolve(self):
        cases = {
            "base": ({"fd", "xz", "python"}, "rg fd fzf shellcheck"),
            "git": ({"git", "github-cli"}, "git gh"),
            "cpp": ({"gcc", "make", "ninja", "pkgconf", "clang"}, "gcc g++ make cmake ninja pkg-config clangd clang-format gdb bear"),
            "python": ({"python", "nodejs", "npm"}, "python3 node npm"),
            "apache": ({"apache"}, "apachectl"),
            "ssh": ({"openssh"}, "sshd"),
            "avr": ({"avr-gcc", "avr-binutils", "avr-libc", "avrdude", "make"}, "avr-gcc avr-objcopy avr-size avr-objdump avrdude"),
        }
        for name, (packages, commands) in cases.items():
            with self.subTest(module=name):
                result = self.resolve(name)
                self.success(result)
                state, resolved, diagnostic, _ = result.stdout.splitlines()
                self.assertEqual(state, "native")
                self.assertTrue(packages.issubset(resolved.split()))
                self.assertEqual(diagnostic, commands)
        self.assertEqual(self.calls(), [])

    def test_pending_provider_is_never_successful_even_with_known_packages(self):
        for name, reason in (("hdl", "GHDL es obligatorio"), ("docker", "repositorio APT"), ("riscv", "prefijos riscv64-elf")):
            with self.subTest(module=name):
                before = self.snapshot()
                result = self.call("dotfiles_packages_install_module", name)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(reason, result.stderr)
                self.assertEqual(self.snapshot(), before)

    def test_absent_catalog_entry_is_not_an_empty_success(self):
        self.replace_row("base", "# base ausente")
        before = self.snapshot()
        result = self.call("apt_install_module", "base")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sin entrada Arch: base", result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_invalid_catalog_is_rejected_before_package_commands(self):
        original = self.catalog.read_text()
        invalid = (
            ("base|native|curl||\nbase|native|wget||\n", "duplicado"),
            ("outsider|native|curl||\n", "desconocido"),
            ("base|native|||\n", "no definidos"),
            ("base|none|curl||Otro mecanismo\n", "mecanismo"),
            ("base|none|||\n", "mecanismo"),
            ("base|pending|||\n", "sin motivo"),
            ("base|typo|curl||\n", "Estado"),
            ("base|native|curl\n", "mal formada"),
            ("base|native|curl|||\n", "mal formada"),
            ("base|native|--refresh||\n", "Paquete"),
            ("base|native|*||\n", "Paquete"),
            ("base|native|curl|*|\n", "Comando"),
            ("base|native|curl|bad:/relative:path|\n", "Comando"),
            ("base|native|curl|rg;touch|\n", "Comando"),
            ("base|native|curl|\trg|\n", "mal formada"),
        )
        for catalog, message in invalid:
            with self.subTest(catalog=catalog):
                self.catalog.write_text(catalog)
                before = self.snapshot()
                result = self.resolve("base")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertEqual(self.snapshot(), before)
        self.catalog.write_text(original)

    def test_unknown_module_and_missing_catalog_fail_without_writes(self):
        for name in ("unknown", '$(touch unexpected)', ""):
            before = self.snapshot()
            result = self.call("dotfiles_packages_install_module", name)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("desconocido", result.stderr)
            self.assertEqual(self.snapshot(), before)
        self.catalog.unlink()
        before = self.snapshot()
        result = self.call("dotfiles_packages_install_module", "base")
        self.assertIn("Falta el catalogo", result.stderr)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_legacy_raw_apt_interface_rejects_arch_even_for_empty_request(self):
        for packages in ((), ("build-essential",)):
            before = self.snapshot()
            result = self.call("apt_install", *packages)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no se envian nombres APT", result.stderr)
            self.assertEqual(self.snapshot(), before)

    def test_backend_selection_ignores_environment(self):
        self.success(self.call("apt_install_module", "cpp", DOTFILES_PLATFORM_PACKAGE_FAMILY="apt", DOTFILES_PLATFORM_ID="ubuntu"))
        self.assertIn("clang", self.installs()[-1])
        self.assertTrue(all(call["command"] == "pacman" for call in self.calls()))

    def test_unknown_distributions_reject_native_and_logical_requests(self):
        for distro in ("unknown", "linuxmint", "manjaro"):
            self.release.write_text(f"ID={distro}\nID_LIKE=arch\n")
            for interface, name in (("dotfiles_packages_install", "curl"), ("dotfiles_packages_install_module", "base"), ("apt_install", "curl"), ("apt_install_module", "nvim-tools")):
                with self.subTest(distro=distro, interface=interface):
                    before = self.snapshot()
                    result = self.call(interface, name, DOTFILES_PLATFORM_PACKAGE_FAMILY="pacman")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(distro, result.stderr)
                    self.assertEqual(self.snapshot(), before)

    def test_apt_distribution_never_calls_pacman(self):
        self.release.write_text("ID=debian\n")
        result = self.call("dotfiles_packages_install", "curl")
        # El centinela APT devuelve 96; la bateria packages.py valida su contrato.
        self.assertEqual(result.returncode, 96, result.stdout + result.stderr)
        self.assertEqual([call["command"] for call in self.calls()], ["dpkg-query"])

    def test_optional_request_does_not_activate_selection(self):
        self.success(self.shell('apt_install_module avr\n[[ "${DOTFILES_WITH_AVR:-0}" == 0 ]]'))

    def test_unported_real_module_scripts_reject_arch_before_writes(self):
        for script, options, message in (("hdl", "", "GHDL es obligatorio"), ("docker", "", "Ubuntu o Debian"), ("riscv", "", "prefijos riscv64-elf"), ("riscv", "--source", "no se envian nombres APT")):
            with self.subTest(script=script, options=options):
                before = self.snapshot()
                result = self.shell(f'bash "$1/setup/modules/{script}.sh" {options}', RISCV_BUILD_PREFIX=str(self.base / "riscv"))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertEqual(self.snapshot(), before)

    def test_arch_cli_install_update_block_on_ghdl_before_state_or_links(self):
        for operation in ("install", "update"):
            for existing_state in (False, True):
                with self.subTest(operation=operation, existing_state=existing_state):
                    state = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/install.state"
                    if existing_state:
                        state.parent.mkdir(parents=True, exist_ok=True)
                        state.write_text("estado personal anterior\n")
                    else:
                        state.unlink(missing_ok=True)
                    before = self.snapshot()
                    result = self.shell(f'bash "$1/bin/dotfiles" {operation} --with-docker --with-avr', DOTFILES_ALLOW_ROOT="1")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("GHDL es obligatorio", result.stderr)
                    self.assertEqual(self.snapshot(), before)

    def test_apache_and_ssh_install_native_packages_without_starting_services(self):
        for name, package, service in (("apache", "apache", "httpd"), ("ssh", "openssh", "sshd")):
            with self.subTest(module=name):
                result = self.shell(f'bash "$1/setup/modules/{name}.sh"')
                self.success(result)
                self.assertIn(f"servicio {service} explicitamente", result.stdout)
                self.assertNotIn("APT", result.stdout)
                self.assertEqual(self.installs()[-1], ["-S", "--needed", "--", package])
        self.arguments()

    def test_doctor_uses_arch_commands_and_reports_pending_selected_modules(self):
        # Evita que nvim --version del host cree archivos auxiliares.
        self.executable("nvim", "#!/bin/sh\nprintf 'NVIM v0.12.5\\n'\n")
        for name in ("apachectl", "sshd", "riscv64-elf-gcc", "riscv64-elf-objdump", "gdb", "qemu-system-riscv32"):
            self.executable(name, "#!/bin/sh\nexit 0\n")
        state = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/install.state"
        state.parent.mkdir(parents=True)
        state.write_text("schema=4\napplied_commit=\npending_commit=\nriscv=1\ndocker=0\ngnome=0\napache=1\nssh=1\nstm32=0\navr=0\n")
        before = self.snapshot()
        result = self.shell('bash "$1/bin/doctor.sh"')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("OK apachectl:", result.stdout)
        self.assertIn("OK sshd:", result.stdout)
        self.assertIn("OK riscv64-elf-gcc:", result.stdout)
        self.assertNotIn("apache2ctl", result.stdout)
        self.assertNotIn("gdb-multiarch", result.stdout)
        self.assertIn("Modulo Arch pendiente: hdl", result.stdout)
        self.assertIn("Modulo Arch pendiente: riscv", result.stdout)
        self.assertNotIn("Modulo Arch pendiente: docker", result.stdout)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
