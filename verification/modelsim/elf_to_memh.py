#!/usr/bin/env python3
"""Convert an ELF32 little-endian image into a flat 32-bit RAM image."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


ELF_HEADER = struct.Struct("<16sHHIIIIIHHHHHH")
SECTION_HEADER = struct.Struct("<IIIIIIIIII")


def parse_elf(path: Path, ram_words: int) -> list[int]:
    blob = path.read_bytes()
    if len(blob) < ELF_HEADER.size:
        raise ValueError("ELF file is shorter than an ELF32 header")

    (
        ident,
        _e_type,
        _e_machine,
        _e_version,
        _entry,
        _phoff,
        shoff,
        _flags,
        _ehsize,
        _phentsize,
        _phnum,
        shentsize,
        shnum,
        shstrndx,
    ) = ELF_HEADER.unpack_from(blob)
    if ident[:4] != b"\x7fELF" or ident[4] != 1 or ident[5] != 1:
        raise ValueError("expected a 32-bit little-endian ELF")
    if shentsize != SECTION_HEADER.size:
        raise ValueError(f"unsupported section-header size {shentsize}")
    if shoff + shnum * shentsize > len(blob):
        raise ValueError("section headers extend past the end of the file")

    sections = [
        SECTION_HEADER.unpack_from(blob, shoff + index * shentsize)
        for index in range(shnum)
    ]
    shstr = sections[shstrndx]
    shstr_data = blob[shstr[4] : shstr[4] + shstr[5]]

    def section_name(offset: int) -> str:
        end = shstr_data.find(b"\0", offset)
        if end < 0:
            end = len(shstr_data)
        return shstr_data[offset:end].decode("ascii", errors="replace")

    words = [0] * ram_words
    ram_bytes = ram_words * 4
    for section in sections:
        name, section_type, flags, address, offset, size, *_ = section
        if not (flags & 0x2) or size == 0:
            continue
        if address + size > ram_bytes:
            raise ValueError(
                f"section {section_name(name)!r} at 0x{address:08x}.."
                f"0x{address + size - 1:08x} does not fit in {ram_bytes} bytes"
            )

        section_data = b"\0" * size if section_type == 8 else blob[offset : offset + size]
        if len(section_data) != size:
            raise ValueError(f"section {section_name(name)!r} extends past the end of the file")

        for byte_offset, value in enumerate(section_data):
            absolute = address + byte_offset
            word_index = absolute // 4
            byte_index = absolute % 4
            words[word_index] |= value << (8 * byte_index)

    return words


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--ram-words", type=int, default=16384)
    args = parser.parse_args()

    words = parse_elf(args.elf, args.ram_words)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as output:
        for word in words:
            output.write(f"{word:08x}\n")
    print(f"Wrote {len(words)} words to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
