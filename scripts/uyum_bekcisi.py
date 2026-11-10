#!/usr/bin/env python3
"""Uyum bekçisi: kopyalanan dosyalar masaüstü reposuyla (tungarix/habit-tracker) tutuyor mu?

Kullanım: uyum_bekcisi.py ETIKET_DIZINI MASTER_DIZINI
- Etiketteki bir dosya tool/kaynak_ozet.json'daki özetle tutmazsa HATA (çıkış 1).
- Master'daki bir dosya farklıysa yalnız UYARI: masaüstü ilerledi, tool/esitle.ps1 çalıştır.
Özet, satır sonları LF'ye çevrilerek SHA-256 ile hesaplanır (tool/esitle.ps1 ile aynı).
"""
import hashlib
import json
import pathlib
import sys


def ozet(yol: pathlib.Path):
    if not yol.is_file():
        return None
    return hashlib.sha256(yol.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def main() -> int:
    etiket, master = (pathlib.Path(a) for a in sys.argv[1:3])
    dosyalar = json.loads(pathlib.Path("tool/kaynak_ozet.json").read_text("utf-8"))["dosyalar"]
    hatalar = [d for d, h in dosyalar.items() if ozet(etiket / d) != h]
    for d in hatalar:
        print(f"::error::{d}: kaynak etiketindeki dosya kayıtlı özetle tutmuyor.")
    farkli = [d for d, h in dosyalar.items() if ozet(master / d) != h]
    for d in farkli:
        print(f"::warning::{d}: masaüstü master'ı ilerledi, tool/esitle.ps1 çalıştır.")
    return 1 if hatalar else 0


if __name__ == "__main__":
    sys.exit(main())
