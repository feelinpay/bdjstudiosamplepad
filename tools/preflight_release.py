#!/usr/bin/env python3
"""Comprueba que lo que hay en `distribution/` se puede repartir.

Los fallos que llegan a un usuario final rara vez son de codigo: son de
empaquetado. Un APK firmado con la clave de debug, una version del instalador
que no coincide con la del binario que lleva dentro, o una libreria nativa mal
alineada que solo revienta en ciertos moviles. Ninguna de esas tres cosas se ve
abriendo la app en el equipo de desarrollo.

Este script las verifica todas de una vez, sin SDK de Android ni NDK:

  1. Coherencia de version -- `frontend/pubspec.yaml`, `distribution/installer.iss`
     y los nombres de los artefactos deben hablar de la misma version.
  2. Alineacion de 16 KB -- delega en `check_16kb_alignment.py`.
  3. Clave de firma -- un APK firmado con la clave de debug de Android NO debe
     distribuirse: es una clave publica y compartida por todo el SDK.
  4. Presencia de artefactos y checksums.

Uso:
    python3 tools/preflight_release.py
    python3 tools/preflight_release.py --write-checksums

Codigos de salida: 0 = listo para repartir, 1 = hay algo que corregir.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import re
import struct
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DISTRIBUTION_DIR = REPO_ROOT / "distribution"
PUBSPEC = REPO_ROOT / "frontend" / "pubspec.yaml"
INSTALLER_SCRIPT = DISTRIBUTION_DIR / "installer.iss"
CHECKSUMS_NAME = "checksums.sha256"

# Sujeto del certificado de depuracion que genera el SDK de Android. Es la misma
# clave en todas las instalaciones del mundo, asi que un APK firmado con ella
# puede ser reemplazado por cualquiera: nunca debe salir de la maquina.
ANDROID_DEBUG_SUBJECT = b"Android Debug"

# Marca que cierra el "APK Signing Block" (esquemas de firma v2 y v3).
APK_SIG_BLOCK_MAGIC = b"APK Sig Block 42"

_GREEN, _RED, _YELLOW, _RESET = "\033[32m", "\033[31m", "\033[33m", "\033[0m"


class Report:
    """Acumula el resultado de las comprobaciones."""

    def __init__(self) -> None:
        self.failures: list[str] = []
        self.warnings: list[str] = []

    def ok(self, message: str) -> None:
        print(f"  {_GREEN}OK{_RESET}    {message}")

    def fail(self, message: str) -> None:
        print(f"  {_RED}FALLO{_RESET} {message}")
        self.failures.append(message)

    def warn(self, message: str) -> None:
        print(f"  {_YELLOW}AVISO{_RESET} {message}")
        self.warnings.append(message)


def _load_alignment_checker():
    """Importa `check_16kb_alignment.py` del mismo directorio."""
    module_path = Path(__file__).resolve().parent / "check_16kb_alignment.py"
    spec = importlib.util.spec_from_file_location("check_16kb_alignment", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"No se pudo cargar {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_pubspec_version(path: Path) -> str | None:
    """Devuelve el nombre de version de pubspec (`1.0.3` de `1.0.3+4`)."""
    if not path.is_file():
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^version:\s*([0-9]+(?:\.[0-9]+)*)", line.strip())
        if match:
            return match.group(1)
    return None


def read_installer_version(path: Path) -> str | None:
    """Devuelve `MyAppVersion` del script de Inno Setup."""
    if not path.is_file():
        return None
    match = re.search(
        r'#define\s+MyAppVersion\s+"([^"]+)"', path.read_text(encoding="utf-8")
    )
    return match.group(1) if match else None


def _apk_signing_block(apk_path: Path) -> bytes | None:
    """Extrae el APK Signing Block (firmas v2/v3), si existe."""
    data = apk_path.read_bytes()

    # El End Of Central Directory esta al final, con un comentario de <= 64 KB.
    eocd_index = data.rfind(b"PK\x05\x06", max(0, len(data) - 65536 - 22))
    if eocd_index < 0:
        return None
    central_dir_offset = struct.unpack_from("<I", data, eocd_index + 16)[0]
    if central_dir_offset < 24 or central_dir_offset > len(data):
        return None

    magic_start = central_dir_offset - len(APK_SIG_BLOCK_MAGIC)
    if data[magic_start:central_dir_offset] != APK_SIG_BLOCK_MAGIC:
        return None  # APK sin firma v2/v3

    block_size = struct.unpack_from("<Q", data, magic_start - 8)[0]
    block_start = central_dir_offset - block_size - 8
    if block_start < 0:
        return None
    return data[block_start:central_dir_offset]


def signed_with_debug_key(apk_path: Path) -> bool | None:
    """`True` si el APK esta firmado con la clave de debug de Android.

    Devuelve `None` si no se encontro ninguna firma que inspeccionar, para no
    confundir "no lo se" con "esta bien".
    """
    found_signature = False

    signing_block = _apk_signing_block(apk_path)
    if signing_block is not None:
        found_signature = True
        if ANDROID_DEBUG_SUBJECT in signing_block:
            return True

    # Firma v1 (JAR): el certificado va en META-INF.
    try:
        with zipfile.ZipFile(apk_path) as archive:
            for name in archive.namelist():
                upper = name.upper()
                if upper.startswith("META-INF/") and upper.endswith(
                    (".RSA", ".DSA", ".EC")
                ):
                    found_signature = True
                    if ANDROID_DEBUG_SUBJECT in archive.read(name):
                        return True
    except (OSError, zipfile.BadZipFile):
        return None

    return False if found_signature else None


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_versions(report: Report) -> str | None:
    print("\nCoherencia de version")
    pubspec_version = read_pubspec_version(PUBSPEC)
    installer_version = read_installer_version(INSTALLER_SCRIPT)

    if pubspec_version is None:
        report.fail(f"no se pudo leer `version:` de {PUBSPEC.name}")
        return None
    report.ok(f"pubspec.yaml declara {pubspec_version}")

    if installer_version is None:
        report.warn(f"no se encontro MyAppVersion en {INSTALLER_SCRIPT.name}")
    elif installer_version != pubspec_version:
        report.fail(
            f"installer.iss declara {installer_version} y pubspec {pubspec_version}: "
            f"el instalador de Windows saldria con el numero equivocado"
        )
    else:
        report.ok(f"installer.iss declara {installer_version}")

    return pubspec_version


def check_apks(report: Report, version: str | None) -> list[Path]:
    print("\nAPK de Android")
    apks = sorted(DISTRIBUTION_DIR.glob("*.apk"))
    if not apks:
        report.fail(
            f"no hay ningun .apk en {DISTRIBUTION_DIR.name}/ "
            f"(ejecuta `flutter build apk --release` desde frontend/)"
        )
        return []

    alignment = _load_alignment_checker()

    for apk in apks:
        if version and version not in apk.name:
            report.fail(f"{apk.name} no corresponde a la version {version}")
        else:
            report.ok(f"{apk.name} presente")

        try:
            problems = alignment.check_apk(str(apk))
        except alignment.AlignmentError as error:
            report.fail(f"{apk.name}: no se pudo analizar ({error})")
            continue

        if problems:
            for problem in problems:
                report.fail(f"{apk.name}: {problem}")
        else:
            report.ok(f"{apk.name}: librerias nativas compatibles con 16 KB")

        debug_signed = signed_with_debug_key(apk)
        if debug_signed is True:
            report.fail(
                f"{apk.name}: firmado con la CLAVE DE DEBUG de Android. Esa clave "
                f"es publica; cualquiera podria publicar una actualizacion falsa. "
                f"Configura android/key.properties y vuelve a compilar."
            )
        elif debug_signed is None:
            report.fail(f"{apk.name}: no se encontro ninguna firma en el paquete")
        else:
            report.ok(f"{apk.name}: firmado con una clave propia")

    return apks


def check_windows_installer(report: Report, version: str | None) -> list[Path]:
    print("\nInstalador de Windows")
    installers = sorted(DISTRIBUTION_DIR.glob("*Setup*.exe"))
    if not installers:
        report.warn(
            f"no hay instalador de Windows en {DISTRIBUTION_DIR.name}/ "
            f"(compila con `ISCC installer.iss`)"
        )
        return []
    for installer in installers:
        if version and version not in installer.name:
            report.fail(f"{installer.name} no corresponde a la version {version}")
        else:
            report.ok(f"{installer.name} presente")
    return installers


def check_checksums(report: Report, artifacts: list[Path], write: bool) -> None:
    print("\nChecksums")
    if not artifacts:
        report.warn("no hay artefactos que resumir")
        return

    checksums_path = DISTRIBUTION_DIR / CHECKSUMS_NAME
    computed = {artifact.name: sha256(artifact) for artifact in artifacts}

    if write:
        checksums_path.write_text(
            "".join(f"{digest}  {name}\n" for name, digest in sorted(computed.items())),
            encoding="utf-8",
        )
        report.ok(f"{CHECKSUMS_NAME} escrito con {len(computed)} entradas")
        return

    if not checksums_path.is_file():
        report.warn(
            f"falta {CHECKSUMS_NAME}; generalo con --write-checksums para que "
            f"quien descargue pueda verificar el archivo"
        )
        return

    recorded: dict[str, str] = {}
    for line in checksums_path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) == 2:
            recorded[parts[1]] = parts[0]

    for name, digest in computed.items():
        if name not in recorded:
            report.fail(f"{name} no aparece en {CHECKSUMS_NAME}")
        elif recorded[name] != digest:
            report.fail(f"{name}: el checksum no coincide, el archivo cambio")
        else:
            report.ok(f"{name}: checksum correcto")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Verifica que distribution/ esta listo para repartir.",
    )
    parser.add_argument(
        "--write-checksums",
        action="store_true",
        help="regenera el archivo de checksums en vez de verificarlo",
    )
    args = parser.parse_args(argv)

    if not DISTRIBUTION_DIR.is_dir():
        print(f"::error::No existe {DISTRIBUTION_DIR}")
        return 1

    print(f"Preflight de distribucion sobre {DISTRIBUTION_DIR}")
    report = Report()

    version = check_versions(report)
    apks = check_apks(report, version)
    installers = check_windows_installer(report, version)
    check_checksums(report, apks + installers, args.write_checksums)

    print("\n" + "=" * 72)
    if report.failures:
        print(f"{_RED}NO SE PUEDE DISTRIBUIR{_RESET}: {len(report.failures)} problema(s)")
        for failure in report.failures:
            print(f"  - {failure}")
        return 1

    if report.warnings:
        print(f"{_YELLOW}Listo, con {len(report.warnings)} aviso(s){_RESET}")
    else:
        print(f"{_GREEN}Todo correcto: se puede distribuir.{_RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
