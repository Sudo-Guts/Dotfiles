#!/usr/bin/env python3
"""Pruebas de edición degradada con Neovim real y sin plugins descargados."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")


class NeovimFallbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not NVIM:
            raise unittest.SkipTest("Neovim no está disponible")
        version = subprocess.run([NVIM, "--version"], text=True, capture_output=True, check=True).stdout
        match = re.search(r"NVIM v(\d+)\.(\d+)", version)
        if not match or tuple(map(int, match.groups())) < (0, 12):
            raise unittest.SkipTest("Estas pruebas requieren Neovim >= 0.12")

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="dotfiles-nvim-test-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        config = self.base / "config"
        config.mkdir()
        (config / "nvim").symlink_to(ROOT / "config/nvim")
        binaries = self.base / "bin"
        binaries.mkdir()
        git = binaries / "git"
        git.write_text('#!/bin/sh\nprintf "called\\n" >> "$DOTFILES_GIT_LOG"\nexit 42\n')
        git.chmod(0o755)
        self.env = dict(os.environ)
        for name in ("DOTFILES_NVIM_INSTALL", "DOTFILES_NVIM_LOCKFILE", "DOTFILES_NVIM_MODULES"):
            self.env.pop(name, None)
        self.env.update(HOME=str(self.base / "home"), XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(self.base / "data"), XDG_STATE_HOME=str(self.base / "state"), XDG_CACHE_HOME=str(self.base / "cache"), TERM="xterm-256color", PATH=f"{binaries}:{os.environ['PATH']}", DOTFILES_TEST_ROOT=str(ROOT), DOTFILES_TEST_FILE=str(self.base / "example.c"), DOTFILES_GIT_LOG=str(self.base / "git.log"))

    def lua(self, code, **environment):
        command = 'lua local ok, err = pcall(function()\n' + code + '\nend); if not ok then print(err); vim.cmd("cquit 1") end'
        result = subprocess.run([NVIM, "--headless", "-c", command, "+qa!"], env=self.env | environment, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_startup_does_not_download_and_keeps_editing(self):
        self.lua('''
            assert(package.loaded.lazy == nil)
            assert(package.loaded["config.hdl.verilog"] == nil)
            assert(vim.fn.maparg("<leader>w", "n") ~= "")
            assert(vim.fn.exists(":DotfilesHealth") == 2)
            vim.api.nvim_buf_set_name(0, vim.env.DOTFILES_TEST_FILE)
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "int main(void) { return 0; }" })
            vim.cmd.write()
            assert(vim.fn.readfile(vim.env.DOTFILES_TEST_FILE)[1] == "int main(void) { return 0; }")
        ''')
        self.assertFalse((self.base / "git.log").exists())
        self.assertFalse((self.base / "data/nvim/lazy/lazy.nvim").exists())

    def test_failed_bootstrap_is_visible_and_cleans_staging(self):
        self.lua('''
            assert(require("config.nvim.health").issues["config:lazy"].required)
            assert(vim.fn.maparg("<leader>w", "n") ~= "")
            assert(package.loaded.lazy == nil)
        ''', DOTFILES_NVIM_INSTALL="1")
        self.assertTrue((self.base / "git.log").exists())
        self.assertFalse(list((self.base / "data").rglob("*.tmp.*")))

    def test_readonly_prevents_bootstrap_even_if_install_is_requested(self):
        self.lua('assert(package.loaded.lazy == nil)', DOTFILES_NVIM_INSTALL="1", DOTFILES_NVIM_READONLY="1")
        self.assertFalse((self.base / "git.log").exists())

    def test_missing_and_broken_parsers_preserve_the_buffer(self):
        self.lua('''
            package.loaded["nvim-treesitter"] = { setup = function() end }
            dofile(vim.env.DOTFILES_TEST_ROOT .. "/config/nvim/lua/plugins/treesitter.lua").config()
            vim.api.nvim_buf_set_name(0, vim.env.DOTFILES_TEST_FILE)
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "mensaje de commit" })
            vim.bo.filetype = "gitcommit"
            assert(require("config.nvim.health").issues["parser:gitcommit"])
            vim.treesitter.language.add = function() error("ABI simulado") end
            vim.bo.filetype = "c"
            assert(require("config.nvim.health").issues["parser:c"])
            assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "mensaje de commit")
        ''')

    def test_failed_case_alignment_preserves_clang_format_output(self):
        self.lua('''
            vim.treesitter.get_string_parser = function()
                return { parse = function() error("parser dañado") end }
            end
            local lines = { "    break;" }
            local result = require("config.nvim.c_format").case_breaks(lines, "c")
            assert(vim.deep_equal(lines, result))
            assert(require("config.nvim.health").issues["c-format"])
        ''')

    def test_incomplete_plugin_marker_is_not_accepted_as_installed(self):
        self.lua('''
            local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\\n"))
            local path = vim.fn.stdpath("data") .. "/plugin"
            vim.fn.mkdir(vim.fs.dirname(path), "p")
            vim.fn.writefile({}, path .. ".cloning")
            package.loaded.lazy = {}
            package.loaded["lazy.core.config"] = { plugins = {
                ["lazy.nvim"] = { dir = path, commit = lock["lazy.nvim"].commit, pin = true, _ = { installed = true } },
            } }
            local ok, err = pcall(dofile(vim.env.DOTFILES_TEST_ROOT .. "/setup/nvim-doctor.lua").plugins)
            assert(not ok and tostring(err):find("Instalación incompleta", 1, true))
        ''')
        self.assertFalse((self.base / "git.log").exists())

    def test_missing_language_servers_keep_editing_available(self):
        self.lua('''
            local lsp = require("config.nvim.lsp")
            lsp.servers = { pyright = "dotfiles-missing-pyright", ruff = "dotfiles-missing-ruff" }
            lsp.setup_capabilities()
            vim.bo.filetype = "python"
            lsp.enable_servers()
            assert(require("config.nvim.health").issues["lsp:pyright"])
            assert(require("config.nvim.health").issues["lsp:ruff"])
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "value = 1" })
            assert(vim.api.nvim_get_current_line() == "value = 1")
        ''')
        self.assertFalse((self.base / "git.log").exists())

    def test_health_command_remains_available_without_plugins(self):
        result = self.lua('vim.cmd("DotfilesHealth"); print(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\\n"))')
        self.assertIn("Plugins fijados", result.stdout + result.stderr)
        self.assertIn("ERROR", result.stdout + result.stderr)

    def test_clang_format_respects_braces_and_long_calls(self):
        binary = shutil.which("clang-format")
        if not binary:
            self.skipTest("clang-format no está disponible")
        parameters = ", ".join(f"int parametro_largo_{index}" for index in range(12))
        arguments = ", ".join(f"parametro_largo_{index}" for index in range(12))
        source = f"int calcular({parameters}) {{\nreturn ejecutar({arguments});\n}}\n"
        result = subprocess.run([binary, f"--style=file:{ROOT / 'config/nvim/.clang-format'}"], input=source, text=True, capture_output=True, check=True)
        self.assertIn(f"int calcular({parameters}) {{", result.stdout)
        self.assertIn(f"    return ejecutar({arguments});", result.stdout)
        self.assertNotIn("\n{", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
