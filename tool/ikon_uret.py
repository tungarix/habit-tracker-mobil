"""Habit Tracker baslatici ikonunu yeni logodan uretir.

Calistirma (proje kokunden):  python tool/ikon_uret.py
Kaynak: tool/ikon-kaynak/habit-tracker-logo.png (siyah zeminli logo; ustte halka+onay kutusu,
altta yazi). Yalniz halka+kutu isareti kullanilir (yazi atilir). Isaret, siyah zeminde "isik"
gibi davranir: alfa = zeminin ustundeki en parlak kanal, renk = alfaya bolunmus piksel.
Boylece glow korunur ve koyu zemin uzerine konunca kaynakla ayni gorunur.
Uretilen dosyalar (android/app/src/main/res altinda):
  - drawable-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png   (108..432 px, isaret merkez %66)
  - drawable-{m,h,xh,xxh,xxxh}dpi/ic_launcher_monochrome.png   (beyaz alfa, temali ikon)
  - mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png                (eski cihazlar, yuvarlatilmis kare)
  - mipmap-anydpi-v26/ic_launcher.xml, values/ic_launcher_background.xml
Gerekli: Pillow.
"""
import os
from PIL import Image, ImageDraw

AD = os.path.dirname(os.path.abspath(__file__))
KAYNAK = os.path.join(AD, "ikon-kaynak", "habit-tracker-logo.png")
KOK = os.path.join(AD, "..", "android", "app", "src", "main", "res")

ARKA = (2, 3, 6)            # #020306 duz arka plan (kaynagin zemini)
ZEMIN = (2, 4, 7)           # alfa turetirken cikarilan zemin
MERKEZ = (620, 467)         # halkanin merkezi (kaynak pikseli)
YARI = 300                  # kirpma yaricapi; yazinin ustu (~310) disarida kalir
TAM_R, SIFIR_R = 296, 304   # bu yaricapin otesinde isaret yumusakca sifirlanir
HALKA_DIS = 547.0           # kaynakta halkanin dis capi (px)
FG_ORAN = 0.60              # on plan: halka capi / tuval; glow dahil ~%66 guvenli alan
LEG_ORAN = 0.70             # eski ikon: halka capi / tuval
KOSE = 56.0 / 256.0         # eski ikon kose yaricapi / boyut
YOGUNLUK = (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4))


def isaret():
    """Kaynaktan halka+kutu isaretini RGBA (600x600) olarak cikarir."""
    kaynak = Image.open(KAYNAK).convert("RGB")
    cx, cy = MERKEZ
    kes = kaynak.crop((cx - YARI, cy - YARI, cx + YARI, cy + YARI))
    n = 2 * YARI
    px = kes.load()
    out = Image.new("RGBA", (n, n))
    op = out.load()
    for y in range(n):
        for x in range(n):
            r, g, b = px[x, y]
            r, g, b = max(0, r - ZEMIN[0]), max(0, g - ZEMIN[1]), max(0, b - ZEMIN[2])
            a = max(r, g, b)
            d = ((x - YARI + .5) ** 2 + (y - YARI + .5) ** 2) ** .5
            a *= min(1.0, max(0.0, (SIFIR_R - d) / (SIFIR_R - TAM_R)))
            if a < 3:  # zemin gurultusu
                continue
            m = max(r, g, b)
            op[x, y] = (min(255, round(r * 255 / m)), min(255, round(g * 255 / m)),
                        min(255, round(b * 255 / m)), round(a))
    return out


def yerlestir(isr, tuval, oran, taban=None):
    """Isareti (halka capi tuval*oran olacak sekilde) tuvalin ortasina koyar."""
    k = tuval * oran / HALKA_DIS
    bt = max(1, round(isr.width * k))
    kucuk = isr.resize((bt, bt), Image.LANCZOS)
    taban = taban or Image.new("RGBA", (tuval, tuval), (0, 0, 0, 0))
    taban.alpha_composite(kucuk, ((tuval - bt) // 2, (tuval - bt) // 2))
    return taban


def legacy(isr, boyut):
    n = boyut * 4  # super-ornekleme
    zemin = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    msk = Image.new("L", (n, n), 0)
    ImageDraw.Draw(msk).rounded_rectangle([0, 0, n - 1, n - 1], radius=KOSE * n, fill=255)
    zemin.paste(Image.new("RGBA", (n, n), ARKA + (255,)), (0, 0), msk)
    yerlestir(isr, n, LEG_ORAN, zemin)
    zemin.putalpha(msk)
    return zemin.resize((boyut, boyut), Image.LANCZOS)


def mono(fg):
    """Temali ikon: beyaz, alfa yalniz isaretten; zayif glow kesilir, iz halka soluk kalir."""
    a = fg.getchannel("A").point(lambda v: min(255, max(0, round((v - 30) * 255 / 225))))
    out = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def yaz(yol, icerik):
    yol = os.path.normpath(os.path.join(KOK, yol))
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with open(yol, "w", encoding="utf-8", newline="\n") as f:
        f.write(icerik)


def kaydet(img, yol):
    yol = os.path.normpath(os.path.join(KOK, yol))
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    img.save(yol, optimize=True)


def main():
    isr = isaret()
    for ad, k in YOGUNLUK:
        fg = yerlestir(isr, round(108 * k), FG_ORAN)
        kaydet(fg, "drawable-%s/ic_launcher_foreground.png" % ad)
        kaydet(mono(fg), "drawable-%s/ic_launcher_monochrome.png" % ad)
        kaydet(legacy(isr, round(48 * k)), "mipmap-%s/ic_launcher.png" % ad)
    yaz("values/ic_launcher_background.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#%02x%02x%02x</color>\n</resources>\n' % ARKA)
    yaz("mipmap-anydpi-v26/ic_launcher.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n')


if __name__ == "__main__":
    main()
