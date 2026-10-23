#!/usr/bin/env python3
"""Puente pequeño entre Neovim y las herramientas oficiales de ST (Linux)."""

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def executable(path):
    return bool(path and Path(path).is_file() and os.access(path, os.X_OK))


def pick(override, candidates):
    if os.environ.get(override):
        path = Path(os.environ[override]).expanduser().absolute()
        require(executable(path), f"{override} no es un ejecutable: {path}")
        return str(path)
    return next((str(Path(p).absolute()) for p in candidates if executable(p)), "")


def tools():
    homes = [Path("/opt/st"), Path.home() / "st"]
    installs = sorted(
        (p for home in homes for p in home.glob("stm32cubeide*")),
        key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.name)),
        reverse=True,
    )
    headless = pick(
        "STM32_CUBEIDE",
        [shutil.which("headless-build.sh")]
        + [p / suffix for p in installs for suffix in ("headless-build.sh", "STM32CubeIDE/headless-build.sh")],
    )
    plugins = Path(headless).resolve().parent / "plugins" if headless else None
    bundled = (
        sorted(plugins.glob("com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.*/tools/bin"))
        if plugins
        else []
    )
    compiler = pick(
        "STM32_ARM_GCC",
        [p / "arm-none-eabi-gcc" for p in reversed(bundled)] + [shutil.which("arm-none-eabi-gcc")],
    )
    compiler_dir = Path(compiler).parent if compiler else Path("/nonexistent")
    programmer = pick(
        "STM32_PROGRAMMER_CLI",
        [
            shutil.which("STM32_Programmer_CLI"),
            Path.home() / "STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI",
            Path("/opt/st/stm32cubeprogrammer/bin/STM32_Programmer_CLI"),
        ]
        + (
            sorted(
                plugins.glob(
                    "com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.*/tools/bin/STM32_Programmer_CLI"
                ),
                reverse=True,
            )
            if plugins
            else []
        ),
    )
    return {
        "cubeide": headless,
        "programmer": programmer,
        "gcc": compiler,
        "g++": str(compiler_dir / "arm-none-eabi-g++")
        if executable(compiler_dir / "arm-none-eabi-g++")
        else "",
        "objcopy": str(compiler_dir / "arm-none-eabi-objcopy")
        if executable(compiler_dir / "arm-none-eabi-objcopy")
        else "",
    }


def inside(root, path):
    path = path.resolve()
    require(path != root and root in path.parents, f"Ruta fuera del proyecto: {path}")
    return path


def metadata(root):
    project = ET.parse(root / ".project").getroot().findtext("name", "").strip()
    require(
        project and not re.search(r"[/\r\n]", project),
        "Nombre de proyecto CubeIDE inválido",
    )
    tree = ET.parse(root / ".cproject").getroot()
    configs = []
    for node in tree.iter("configuration"):
        if node.get("artifactExtension") != "elf":
            continue
        name = node.get("name", "")
        require(name and not re.search(r"[/\r\n]", name), "Configuración CubeIDE inválida")
        require(
            any("gnu.managedbuild" in n.get("superClass", "") for n in node.iter("toolChain")),
            "Esta integración requiere un proyecto CubeIDE con GNU Arm GCC",
        )
        builder = node.find(".//builder")
        build = builder.get("buildPath", "") if builder is not None else ""
        build = build or name
        build = (
            build.replace("${workspace_loc:/" + project + "}", str(root))
            .replace("${ProjDirPath}", str(root))
            .replace("${ConfigName}", name)
        )
        artifact = (
            node.get("artifactName", "${ProjName}")
            .replace("${ProjName}", project)
            .replace("${ConfigName}", name)
        )
        require(
            "${" not in build + artifact and not re.search(r"[/\\\r\n]", artifact),
            "Ruta CubeIDE con variables no soportadas",
        )
        directory = inside(root, root / build)
        elf = inside(root, directory / (artifact + ".elf"))
        mcu = next(
            (
                n.get("value", "")
                for n in node.iter("option")
                if n.get("superClass", "").endswith(".target_mcu")
            ),
            "",
        )
        configs.append(
            {
                "name": name,
                "build_dir": str(directory),
                "elf": str(elf),
                "hex": str(elf.with_suffix(".hex")),
                "mcu": mcu,
            }
        )
    require(configs, "No hay configuraciones ejecutables GNU Arm GCC en .cproject")
    require(
        len({c["name"] for c in configs}) == len(configs),
        "Configuraciones CubeIDE duplicadas",
    )
    return {"project": project, "configurations": configs}


def selected(root, configuration):
    data = metadata(root)
    config = next((c for c in data["configurations"] if c["name"] == configuration), None)
    require(config, "Configuración inexistente; elígela con Espacio rt")
    return data, config


def state_dir():
    path = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "dotfiles/stm32"
    require(path.is_absolute(), "XDG_STATE_HOME debe ser absoluto")
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    return path


@contextlib.contextmanager
def lock(path):
    with path.open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("Hay otra operación STM32 en curso") from None
        yield


def interrupted(signum, _frame):
    raise InterruptedError(f"Operación cancelada ({signum})")


def run(command, cwd=None, env=None, capture=False):
    # Sin shell; al cancelar también se detienen Eclipse, Make y sus hijos.
    with subprocess.Popen(
        command,
        cwd=cwd,
        env=env,
        start_new_session=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
        text=True,
    ) as child:
        try:
            output, _ = child.communicate()
        except BaseException:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
            raise
        require(
            child.returncode == 0,
            (output or "") + f"\nFalló {Path(command[0]).name}: {child.returncode}",
        )
    return output or ""


def build(root, configuration, index=False):
    data, config = selected(root, configuration)
    sdk = tools()
    require(
        sdk["cubeide"],
        "Falta headless-build.sh; instala STM32CubeIDE o define STM32_CUBEIDE",
    )
    require(
        sdk["gcc"] and sdk["objcopy"],
        "No se encontró GNU Arm GCC de CubeIDE; define STM32_ARM_GCC",
    )
    workspace = state_dir() / hashlib.sha256(str(root).encode()).hexdigest()
    workspace.mkdir(exist_ok=True, mode=0o700)
    env = dict(
        os.environ,
        PATH=str(Path(sdk["gcc"]).parent) + os.pathsep + os.environ.get("PATH", ""),
    )
    selector = re.escape(data["project"]) + "/" + re.escape(configuration)
    command = [
        sdk["cubeide"],
        "-data",
        str(workspace / "workspace"),
        "-import",
        str(root),
        "-cleanBuild" if index else "-build",
        selector,
    ]
    with lock(workspace / "build.lock"):
        temporary = None
        try:
            if index:
                require(
                    shutil.which("bear"),
                    "Falta Bear; ejecuta dotfiles install --with-stm32",
                )
                fd, temporary = tempfile.mkstemp(prefix=".compile_commands.", suffix=".json", dir=root)
                os.close(fd)
                command = ["bear", "--output", temporary, "--"] + command
            print(f"CubeIDE: {data['project']}/{configuration}", flush=True)
            run(command, cwd=root, env=env)
            elf = Path(config["elf"])
            require(elf.is_file(), "CubeIDE no generó el ELF esperado: " + str(elf))
            header = elf.read_bytes()[:20]
            require(
                header[:6] == b"\x7fELF\x01\x01"
                and len(header) == 20
                and int.from_bytes(header[18:20], "little") == 40,
                "El ELF generado no es ARM de 32 bits",
            )
            fd, hex_temp = tempfile.mkstemp(prefix=".firmware.", suffix=".hex", dir=elf.parent)
            os.close(fd)
            try:
                run([sdk["objcopy"], "-O", "ihex", str(elf), hex_temp], cwd=root)
                os.replace(hex_temp, config["hex"])
            finally:
                Path(hex_temp).unlink(missing_ok=True)
            if index:
                entries = json.loads(Path(temporary).read_text())
                require(
                    isinstance(entries, list)
                    and entries
                    and all(
                        isinstance(e, dict)
                        and e.get("file")
                        and e.get("directory")
                        and (e.get("arguments") or e.get("command"))
                        for e in entries
                    ),
                    "Bear no registró compilaciones; se conserva el índice anterior",
                )
                # Flag de informes del GCC de ST que clangd no reconoce.
                # CPU, FPU, ABI, macros, includes y demás opciones se conservan.
                for entry in entries:
                    args = entry.get("arguments") or shlex.split(entry.pop("command"))
                    entry.pop("command", None)
                    entry["arguments"] = [arg for arg in args if arg != "-fcyclomatic-complexity"]
                Path(temporary).write_text(json.dumps(entries, indent=2) + "\n")
                os.replace(temporary, root / "compile_commands.json")
            print("HEX: " + config["hex"], flush=True)
        finally:
            if temporary:
                Path(temporary).unlink(missing_ok=True)


def devices(programmer):
    output = run([programmer, "--list"], capture=True)
    output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
    # No confundir un número de serie ST-Link/UART con uno USB DFU.
    section = re.search(
        r"=+\s*DFU Interface\s*=+(.*?)(?==+\s*\w.*?Interface|\Z)", output, re.DOTALL | re.IGNORECASE
    )
    if not section:
        raise ValueError(
            "CubeProgrammer no informó interfaces DFU. Revisa permisos USB y modo DFU.\n" + output
        )
    result = []
    for block in re.split(r"Device Index\s*:", section[1], flags=re.IGNORECASE)[1:]:
        port = re.match(r"\s*(USB\d+)\b", block, re.IGNORECASE)
        serial = re.search(
            r"Serial number[^\S\r\n]*:[^\S\r\n]*([0-9a-f]+)[^\S\r\n]*(?:\r?\n|$)",
            block,
            re.IGNORECASE,
        )
        if port and serial:
            result.append({"port": port[1].upper(), "serial": serial[1]})
    require(
        len({d["serial"] for d in result}) == len(result),
        "Números de serie DFU ambiguos",
    )
    return result


def validate_hex(path):
    address, data_bytes, ended = 0, 0, False
    for line in path.read_text(encoding="ascii").splitlines():
        require(not ended and line.startswith(":"), "Intel HEX inválido")
        record = bytes.fromhex(line[1:])
        require(
            len(record) >= 5 and len(record) == record[0] + 5 and sum(record) % 256 == 0,
            "Checksum Intel HEX inválido",
        )
        size, kind = record[0], record[3]
        offset = int.from_bytes(record[1:3], "big")
        payload = record[4:-1]
        if kind == 0:
            start = address + offset
            require(
                0x08000000 <= start and start + size <= 0x08100000,
                "HEX fuera de la Flash interna del STM32F407VG",
            )
            data_bytes += size
        elif kind in (2, 4):
            require(size == 2 and offset == 0, "Dirección Intel HEX inválida")
            address = int.from_bytes(payload, "big") << (4 if kind == 2 else 16)
        elif kind == 1:
            require(size == 0 and offset == 0, "Fin Intel HEX inválido")
            ended = True
        else:
            require(
                kind in (3, 5) and size == 4 and offset == 0,
                "Registro Intel HEX no soportado",
            )
    require(ended and data_bytes, "Intel HEX vacío o incompleto")


def flash(root, configuration, serial):
    _, config = selected(root, configuration)
    require(
        config["mcu"].startswith("STM32F407VG"),
        "La carga DFU de esta versión está validada para STM32F407VG",
    )
    require(re.fullmatch(r"[0-9a-fA-F]+", serial), "Número de serie DFU inválido")
    programmer = tools()["programmer"]
    require(
        programmer,
        "Falta STM32_Programmer_CLI; instala CubeProgrammer o define STM32_PROGRAMMER_CLI",
    )
    firmware = Path(config["hex"])
    validate_hex(firmware)
    with lock(state_dir() / "dfu.lock"):
        require(
            any(d["serial"] == serial for d in devices(programmer)),
            "La placa seleccionada se desconectó; vuelve a seleccionarla",
        )
        connection = [programmer, "-c", "port=usb", "sn=" + serial]
        probe = run(connection, capture=True)
        probe = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", probe)
        print(probe, end="", flush=True)
        require(
            re.search(r"Device ID\s*:\s*0x0*413\b", probe, re.IGNORECASE),
            "El dispositivo conectado no se identifica como STM32F405/407",
        )
        # La dirección proviene del HEX. No se cambian option bytes ni se pide borrado total.
        run(connection + ["-d", str(firmware), "-v"], cwd=root)
        print(
            "Firmware grabado y verificado. Sal del modo DFU y reinicia la placa.",
            flush=True,
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=("tools", "doctor", "metadata", "build", "index", "devices", "flash"),
    )
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--configuration", default="Debug")
    parser.add_argument("--serial")
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    root = args.root.resolve()
    if args.action == "tools":
        print(json.dumps(tools()))
    elif args.action == "doctor":
        sdk = tools()
        for name in ("cubeide", "gcc", "objcopy", "programmer"):
            print(f"[STM32] {name}: {sdk[name] or 'FALTA; consulta README'}")
        require(
            all(sdk[name] for name in ("cubeide", "gcc", "objcopy", "programmer")),
            "Completa las rutas de las herramientas de ST",
        )
    elif args.action == "metadata":
        print(json.dumps(metadata(root)))
    elif args.action in ("build", "index"):
        build(root, args.configuration, index=args.action == "index")
    elif args.action == "devices":
        programmer = tools()["programmer"]
        require(programmer, "No se encontró STM32_Programmer_CLI")
        print(json.dumps(devices(programmer)))
    else:
        require(args.serial, "Selecciona una placa DFU antes de grabar")
        flash(root, args.configuration, args.serial)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, ET.ParseError) as error:
        print("[STM32] " + str(error), file=sys.stderr)
        sys.exit(1)
