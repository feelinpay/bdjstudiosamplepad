#!/usr/bin/env python3
"""Verifica que un APK sea apto para dispositivos Android con paginas de 16 KB.

Un dispositivo que arranca con paginas de memoria de 16 KB (Android 15+, p. ej.
Galaxy S25) no puede mapear una libreria nativa cuyos segmentos ELF PT_LOAD esten
alineados a 4 KB: `dlopen()` falla y la app muere, normalmente antes de pintar
nada. Como solo falla en ESOS dispositivos, el sintoma tipico es "no abre en
algunos moviles".

Se comprueban las dos condiciones necesarias e independientes:

  1. Alineacion ELF  -- cada `.so` de 64 bits debe declarar p_align >= 16384 en
     todos sus segmentos PT_LOAD. Depende de con que flags se enlazo la libreria
     (`-Wl,-z,max-page-size=16384`), no del empaquetado.
  2. Alineacion en el ZIP -- cada `.so` almacenado sin comprimir debe empezar en
     un offset multiplo de 16384 dentro del APK, para poder mapearse directo
     desde el paquete. Lo garantiza AGP >= 8.5.1 / `zipalign -P 16`.

Uso:
    python3 tools/check_16kb_alignment.py APK [APK ...]

Codigos de salida: 0 = todo correcto, 1 = alguna libreria incumple,
2 = error de uso o APK ilegible.

Sin dependencias externas a proposito: corre igual en el runner de CI y en la
maquina de desarrollo, sin NDK ni SDK instalados.
"""

from __future__ import annotations

import argparse
import struct
import sys
import zipfile

PAGE_SIZE_16KB = 16 * 1024

# Cabecera ELF (little-endian, 64 bits)
_ELF_MAGIC = b"\x7fELF"
_ELFCLASS64 = 2
_PT_LOAD = 1
_E_PHOFF = 0x20
_E_PHENTSIZE = 0x36
_E_PHNUM = 0x38
_P_TYPE_OFFSET = 0x00
_P_ALIGN_OFFSET = 0x30

# Solo las ABI de 64 bits tienen dispositivos con paginas de 16 KB.
_ABIS_64_BIT = ("arm64-v8a", "x86_64")


class AlignmentError(Exception):
    """El APK no se puede analizar (corrupto, truncado o no es un ZIP)."""


def _max_pt_load_alignment(blob: bytes) -> int | None:
    """Devuelve la mayor alineacion PT_LOAD de un ELF 64 bits, o None si no aplica."""
    if len(blob) < 64 or blob[:4] != _ELF_MAGIC or blob[4] != _ELFCLASS64:
        return None

    ph_off = struct.unpack_from("<Q", blob, _E_PHOFF)[0]
    ph_entsize = struct.unpack_from("<H", blob, _E_PHENTSIZE)[0]
    ph_num = struct.unpack_from("<H", blob, _E_PHNUM)[0]

    alignments = []
    for index in range(ph_num):
        entry = ph_off + index * ph_entsize
        if entry + _P_ALIGN_OFFSET + 8 > len(blob):
            raise AlignmentError("tabla de cabeceras de programa fuera de rango")
        if struct.unpack_from("<I", blob, entry + _P_TYPE_OFFSET)[0] != _PT_LOAD:
            continue
        alignments.append(struct.unpack_from("<Q", blob, entry + _P_ALIGN_OFFSET)[0])

    return max(alignments) if alignments else None


def _zip_entry_data_offset(apk_path: str, info: zipfile.ZipInfo) -> int:
    """Offset real de los bytes de la entrada (saltando su cabecera local)."""
    with open(apk_path, "rb") as handle:
        handle.seek(info.header_offset + 26)
        name_len, extra_len = struct.unpack("<HH", handle.read(4))
    return info.header_offset + 30 + name_len + extra_len


def check_apk(apk_path: str) -> list[str]:
    """Devuelve la lista de problemas encontrados (vacia si el APK es correcto)."""
    problems: list[str] = []

    try:
        archive = zipfile.ZipFile(apk_path)
    except (OSError, zipfile.BadZipFile) as exc:
        raise AlignmentError(f"no se pudo abrir como ZIP: {exc}") from exc

    with archive:
        native_libs = [
            info
            for info in archive.infolist()
            if info.filename.startswith("lib/")
            and info.filename.endswith(".so")
            and any(f"/{abi}/" in info.filename for abi in _ABIS_64_BIT)
        ]

        if not native_libs:
            print(f"  (sin librerias nativas de 64 bits en {apk_path})")
            return problems

        for info in sorted(native_libs, key=lambda i: i.filename):
            alignment = _max_pt_load_alignment(archive.read(info))
            if alignment is None:
                print(f"  OMITIDA   {info.filename} (no es un ELF de 64 bits)")
                continue

            elf_ok = alignment >= PAGE_SIZE_16KB
            # Solo las entradas STORED se mapean directamente desde el APK.
            stored = info.compress_type == zipfile.ZIP_STORED
            data_offset = _zip_entry_data_offset(apk_path, info)
            zip_ok = (not stored) or data_offset % PAGE_SIZE_16KB == 0

            status = "OK      " if elf_ok and zip_ok else "FALLO   "
            print(
                f"  {status}  {info.filename}  "
                f"(ELF p_align={hex(alignment)}, "
                f"zip={'alineado' if zip_ok else 'NO alineado'})"
            )

            if not elf_ok:
                problems.append(
                    f"{info.filename}: segmentos ELF alineados a {hex(alignment)}; "
                    f"se requiere >= {hex(PAGE_SIZE_16KB)}. Recompila la libreria con "
                    f"-Wl,-z,max-page-size=16384 o actualiza la dependencia que la trae."
                )
            if not zip_ok:
                problems.append(
                    f"{info.filename}: almacenada sin comprimir en el offset "
                    f"{data_offset}, que no es multiplo de {PAGE_SIZE_16KB}. "
                    f"Reempaqueta con `zipalign -P 16 -f 4`."
                )

    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Verifica la compatibilidad de un APK con paginas de 16 KB.",
    )
    parser.add_argument("apks", nargs="+", metavar="APK", help="APK(s) a verificar")
    args = parser.parse_args(argv)

    all_problems: list[str] = []
    for apk_path in args.apks:
        print(f"Analizando {apk_path}")
        try:
            all_problems.extend(check_apk(apk_path))
        except AlignmentError as exc:
            print(f"::error::No se pudo analizar {apk_path}: {exc}")
            return 2
        print()

    if all_problems:
        print("=" * 72)
        print("INCOMPATIBLE CON DISPOSITIVOS DE 16 KB")
        print("=" * 72)
        for problem in all_problems:
            print(f"::error::{problem}")
        return 1

    print("Todas las librerias nativas de 64 bits son compatibles con 16 KB.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
