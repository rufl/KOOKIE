#!/usr/bin/env python3
"""Remove CodeView debug sections from a Windows COFF object."""

from __future__ import annotations

import pathlib
import struct
import sys


COFF_HEADER_SIZE = 20
COFF_SECTION_SIZE = 40
COFF_SYMBOL_SIZE = 18
COFF_RELOCATION_SIZE = 10
COFF_LINE_NUMBER_SIZE = 6


def fail(message: str) -> None:
    raise SystemExit(f"strip-coff-debug: {message}")



def checked_chunk(data: bytes, pointer: int, size: int, description: str) -> bytes:
    if size == 0:
        return b""
    if pointer == 0 or pointer + size > len(data):
        fail(f"{description} is outside the COFF object")
    return data[pointer:pointer + size]


def strip_debug_sections(data: bytes) -> bytes:
    if len(data) < COFF_HEADER_SIZE:
        fail("COFF header is truncated")

    section_count = struct.unpack_from("<H", data, 2)[0]
    optional_size = struct.unpack_from("<H", data, 16)[0]
    section_table = COFF_HEADER_SIZE + optional_size
    section_table_end = section_table + section_count * COFF_SECTION_SIZE
    if section_table_end > len(data):
        fail("COFF section table is truncated")

    sections: list[dict[str, object]] = []
    for index in range(section_count):
        header_offset = section_table + index * COFF_SECTION_SIZE
        header = bytearray(data[header_offset:header_offset + COFF_SECTION_SIZE])
        name = bytes(header[:8]).split(b"\0", 1)[0]
        raw_size, raw_pointer = struct.unpack_from("<II", header, 16)
        reloc_pointer, line_pointer = struct.unpack_from("<II", header, 24)
        reloc_count, line_count = struct.unpack_from("<HH", header, 32)
        sections.append(
            {
                "header": header,
                "name": name,
                "raw": checked_chunk(
                    data, raw_pointer, raw_size, f"section {index} raw data"
                ),
                "reloc": checked_chunk(
                    data,
                    reloc_pointer,
                    reloc_count * COFF_RELOCATION_SIZE,
                    f"section {index} relocations",
                ),
                "line": checked_chunk(
                    data,
                    line_pointer,
                    line_count * COFF_LINE_NUMBER_SIZE,
                    f"section {index} line numbers",
                ),
            }
        )

    removed = {
        index
        for index, section in enumerate(sections)
        if bytes(section["name"]).startswith(b".debug")
    }
    if not removed:
        return data

    symbol_pointer, symbol_count = struct.unpack_from("<II", data, 8)
    new_symbols = bytearray()
    symbol_index_map: dict[int, int] = {}
    string_table = b""
    if symbol_count:
        symbol_end = symbol_pointer + symbol_count * COFF_SYMBOL_SIZE
        if symbol_pointer == 0 or symbol_end > len(data):
            fail("COFF symbol table is truncated")
        string_pointer = symbol_end
        string_size = (
            struct.unpack_from("<I", data, string_pointer)[0]
            if string_pointer + 4 <= len(data)
            else 0
        )
        if string_size < 4 or string_pointer + string_size > len(data):
            fail("COFF string table is invalid")
        string_table = data[string_pointer:string_pointer + string_size]

        old_index = 0
        while old_index < symbol_count:
            record_offset = symbol_pointer + old_index * COFF_SYMBOL_SIZE
            record = bytearray(data[record_offset:record_offset + COFF_SYMBOL_SIZE])
            aux_count = record[17]
            group_count = 1 + aux_count
            if old_index + group_count > symbol_count:
                fail("COFF symbol auxiliary records are truncated")
            section_number = struct.unpack_from("<h", record, 12)[0]
            if section_number > 0:
                section_index = section_number - 1
                if section_index in removed:
                    old_index += group_count
                    continue
                removed_before = sum(index < section_index for index in removed)
                record[12:14] = struct.pack(
                    "<h", section_number - removed_before
                )
            new_index = len(new_symbols) // COFF_SYMBOL_SIZE
            for member in range(group_count):
                symbol_index_map[old_index + member] = new_index + member
            new_symbols.extend(record)
            aux_start = record_offset + COFF_SYMBOL_SIZE
            new_symbols.extend(data[aux_start:aux_start + aux_count * COFF_SYMBOL_SIZE])
            old_index += group_count
    elif symbol_pointer:
        fail("COFF has a symbol-table pointer but no symbols")

    kept_sections = [
        (index, section)
        for index, section in enumerate(sections)
        if index not in removed
    ]
    output = bytearray(data[:COFF_HEADER_SIZE])
    struct.pack_into("<H", output, 2, len(kept_sections))
    output.extend(b"\0" * (len(kept_sections) * COFF_SECTION_SIZE))

    def append_chunk(chunk: bytes) -> int:
        while len(output) % 4:
            output.append(0)
        pointer = len(output)
        output.extend(chunk)
        return pointer

    for new_index, (_, section) in enumerate(kept_sections):
        header = bytearray(section["header"])
        raw = bytes(section["raw"])
        reloc = bytearray(section["reloc"])
        line = bytes(section["line"])
        struct.pack_into("<I", header, 20, append_chunk(raw) if raw else 0)
        if reloc:
            for offset in range(0, len(reloc), COFF_RELOCATION_SIZE):
                old_symbol = struct.unpack_from("<I", reloc, offset + 4)[0]
                if old_symbol not in symbol_index_map:
                    fail(f"relocation references removed symbol {old_symbol}")
                struct.pack_into(
                    "<I", reloc, offset + 4, symbol_index_map[old_symbol]
                )
            struct.pack_into("<I", header, 24, append_chunk(reloc))
        else:
            struct.pack_into("<I", header, 24, 0)
        struct.pack_into("<I", header, 28, append_chunk(line) if line else 0)
        header_offset = COFF_HEADER_SIZE + new_index * COFF_SECTION_SIZE
        output[header_offset:header_offset + COFF_SECTION_SIZE] = header

    if new_symbols:
        while len(output) % 4:
            output.append(0)
        new_symbol_pointer = len(output)
        output.extend(new_symbols)
        output.extend(string_table)
        struct.pack_into(
            "<II", output, 8, new_symbol_pointer, len(new_symbols) // COFF_SYMBOL_SIZE
        )
    else:
        struct.pack_into("<II", output, 8, 0, 0)
    return bytes(output)


def main() -> None:
    if len(sys.argv) == 4 and sys.argv[1] == "--strip-debug":
        source_name, destination_name = sys.argv[2:]
    elif len(sys.argv) == 3:
        source_name, destination_name = sys.argv[1:]
    else:
        raise SystemExit(
            "Usage: strip_coff_debug.py [--strip-debug] INPUT OUTPUT"
        )
    source = pathlib.Path(source_name)
    destination = pathlib.Path(destination_name)
    destination.write_bytes(strip_debug_sections(source.read_bytes()))


if __name__ == "__main__":
    main()
