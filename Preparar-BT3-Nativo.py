"""Prepara o port nativo usando os dados locais, sem modificar a instalação antiga."""
import hashlib
import pathlib
import shutil
import struct

ROOT = pathlib.Path(__file__).resolve().parent
SOURCE = pathlib.Path(r"C:\Program Files (x86)\Dragon Ball Budokai Tenkaichi 3\data")
OUT = ROOT / "Nativo/Tenkaichi3Decomp/gamedata"

def validate():
    elf = (SOURCE / "SLUS_216.78").read_bytes()
    if elf[:4] != b"\x7fELF":
        raise ValueError("Executável do jogo inválido")
    flat = bytearray(0x2FF180 - 0x100000)
    off = struct.unpack_from("<I", elf, 0x20)[0]
    size, count = struct.unpack_from("<HH", elf, 0x2E)
    for i in range(count):
        _, kind, flags, addr, pos, length = struct.unpack_from("<6I", elf, off + i * size)
        if flags & 2 and kind != 8 and length and 0x100000 <= addr and addr + length <= 0x2FF180:
            flat[addr - 0x100000:addr - 0x100000 + length] = elf[pos:pos + length]
    if hashlib.sha1(flat).hexdigest() != "caee6c2269bba89fc51eea9e7beac3adbec9dc52":
        raise ValueError("SLUS diferente da versão USA suportada pelo port")
    if hashlib.sha1((SOURCE / "BIN/DBZP.BIN").read_bytes()).hexdigest() != "4f910969e05d9b25c83af7642b60da9949a4348b":
        raise ValueError("DBZP diferente da versão USA suportada pelo port")

def split(archive):
    dest = OUT / archive.stem.lower()
    dest.mkdir(parents=True, exist_ok=True)
    with archive.open("rb") as f:
        magic, count = struct.unpack("<4sI", f.read(8))
        if magic != b"AFS\0" or count * 8 + 8 > archive.stat().st_size:
            raise ValueError(f"AFS inválido: {archive.name}")
        table = struct.unpack(f"<{count * 2}I", f.read(count * 8))
        for i in range(count):
            offset, length = table[2*i:2*i+2]
            if offset + length > archive.stat().st_size:
                raise ValueError(f"Entrada inválida: {archive.name}/{i}")
            target = dest / f"{i:05d}.bin"
            if target.exists() and target.stat().st_size == length:
                continue
            f.seek(offset)
            temp = target.with_suffix(".tmp")
            with temp.open("wb") as out:
                left = length
                while left:
                    chunk = f.read(min(left, 1024 * 1024))
                    if not chunk:
                        raise ValueError("Arquivo truncado")
                    out.write(chunk)
                    left -= len(chunk)
            temp.replace(target)
    print(f"{archive.name}: {count} entradas", flush=True)

def main():
    validate()
    OUT.mkdir(parents=True, exist_ok=True)
    for folder in ("BIN", "DATA"):
        for source in (SOURCE / folder).rglob("*"):
            if not source.is_file():
                continue
            if source.suffix.upper() == ".AFS":
                split(source)
                continue
            target = OUT / "disc" / source.relative_to(SOURCE)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    shutil.copy2(SOURCE / "SLUS_216.78", OUT / "disc/SLUS_216.78")
    (OUT / ".installed").write_text("Dados locais validados: USA SLUS-21678\n")
    print("Port nativo preparado; saves antigos preservados.")

if __name__ == "__main__":
    main()
