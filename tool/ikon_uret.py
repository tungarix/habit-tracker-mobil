"""Habit Tracker baslatici ikonunu uretir (masaustu app_icon.ico tasarimi).

Calistirma (proje kokunden):  python tool/ikon_uret.py
Uretilen dosyalar (android/app/src/main/res altinda):
  - mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png  (eski cihazlar, yuvarlatilmis kare)
  - mipmap-anydpi-v26/ic_launcher.xml            (adaptive + monochrome)
  - drawable/ic_launcher_foreground.xml, ic_launcher_monochrome.xml (vektor)
  - values/ic_launcher_background.xml            (koyu duz arka plan rengi)
Gerekli: Pillow. Tasarim 256'lik izgarada; renkler ve olculer kaynak ikondan
(256 px) orneklenmistir, cizim ise PIL ile 8x super-ornekleme (PNG) ve vektor (XML).
"""
import math
import os
from PIL import Image, ImageChops, ImageDraw

# --- Tasarim (256'lik izgara) ---
ARKA = (10, 11, 12)        # #0a0b0c zemin
IZ = (30, 34, 36)          # #1e2224 halkanin bos (iz) kismi
YESIL = (52, 168, 24)      # #34a818 seri halkasi
TIK = (245, 245, 245)      # #f5f5f5 tik
M = 128.0                  # merkez
R = 71.75                  # halka orta yaricapi
W = 17.5                   # halka kalinligi
KOSE = 56.0                # zemin kose yaricapi
DOLU_BAS, DOLU_BIT = 90.0, 160.0  # bos kisim (matematik derecesi, saat yonunun tersi); yesil geri kalan
TIK_NOKTA = [(95.0, 130.25), (119.75, 154.75), (165.75, 102.5)]
TIK_W = 17.25

KOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "app", "src", "main", "res")
SS = 8


def _hex(c):
    return "#%02x%02x%02x" % c


def _maske_halka(n, k, r_dis, r_ic):
    """k: izgara->piksel katsayisi. Halka (annulus) maskesi."""
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    c = M * k
    d.ellipse([c - r_dis * k, c - r_dis * k, c + r_dis * k, c + r_dis * k], fill=255)
    d.ellipse([c - r_ic * k, c - r_ic * k, c + r_ic * k, c + r_ic * k], fill=0)
    return m


def _maske_yesil(n, k):
    ring = _maske_halka(n, k, R + W / 2, R - W / 2)
    pie = Image.new("L", (n, n), 0)
    c = M * k
    box = [c - 2 * R * k, c - 2 * R * k, c + 2 * R * k, c + 2 * R * k]
    # PIL acisi saat yonunde, 3'ten baslar: yesil = 12'den saat yonunde bos kismin basina
    ImageDraw.Draw(pie).pieslice(box, -DOLU_BAS, -DOLU_BIT + 360, fill=255)
    return ImageChops.multiply(ring, pie)


def _maske_tik(n, k):
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    p = [(x * k, y * k) for x, y in TIK_NOKTA]
    d.line(p, fill=255, width=round(TIK_W * k))
    for x, y in p:  # yuvarlak uc ve birlesim
        r = TIK_W * k / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def _boya(maske, renk, taban):
    taban.paste(Image.new("RGB", taban.size, renk), (0, 0), maske)


def ciz_legacy(boyut):
    """Yuvarlatilmis kare koyu zeminli tam ikon (RGBA)."""
    n = boyut * SS
    k = n / 256.0
    zemin = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    msk = Image.new("L", (n, n), 0)
    ImageDraw.Draw(msk).rounded_rectangle([0, 0, n - 1, n - 1], radius=KOSE * k, fill=255)
    zemin.paste(Image.new("RGBA", (n, n), ARKA + (255,)), (0, 0), msk)
    rgb = zemin.convert("RGB")
    _boya(_maske_halka(n, k, R + W / 2, R - W / 2), IZ, rgb)
    _boya(_maske_yesil(n, k), YESIL, rgb)
    _boya(_maske_tik(n, k), TIK, rgb)
    out = rgb.convert("RGBA")
    out.putalpha(msk)
    return out.resize((boyut, boyut), Image.LANCZOS)


# --- Adaptive icon (vektor): 108dp tuval, halka dis capi HALKA_DP ---
HALKA_DP = 60.0  # tuvalin %55,6'si, guvenli alan (merkez %66) icinde
S = HALKA_DP / (2 * (R + W / 2))  # izgara -> dp
TUVAL = 108.0


def _p(x, y):
    return (TUVAL / 2 + (x - M) * S, TUVAL / 2 + (y - M) * S)


def _f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def _yol_yay():
    r = R * S
    c = TUVAL / 2
    # yesil: tepeden (90) saat yonunde 160.75'e; baslangic (c, c-r), bitis aci DOLU_BIT
    bx = c + r * math.cos(math.radians(DOLU_BIT))
    by = c - r * math.sin(math.radians(DOLU_BIT))
    return "M%s,%s A%s,%s 0 1,1 %s,%s" % (_f(c), _f(c - r), _f(r), _f(r), _f(bx), _f(by))


def _yol_iz():
    r = R * S
    c = TUVAL / 2
    return "M%s,%s A%s,%s 0 1,1 %s,%s A%s,%s 0 1,1 %s,%s" % (
        _f(c - r), _f(c), _f(r), _f(r), _f(c + r), _f(c), _f(r), _f(r), _f(c - r), _f(c))


def _yol_tik():
    (x1, y1), (x2, y2), (x3, y3) = [_p(*q) for q in TIK_NOKTA]
    return "M%s,%s L%s,%s L%s,%s" % (_f(x1), _f(y1), _f(x2), _f(y2), _f(x3), _f(y3))


def _vektor(yollar):
    govde = ""
    for yol, renk, kal, uc in yollar:
        govde += (
            '    <path\n        android:pathData="%s"\n        android:strokeColor="%s"\n'
            '        android:strokeWidth="%s"\n        android:strokeLineCap="%s"\n'
            '        android:strokeLineJoin="round" />\n' % (yol, renk, _f(kal), uc))
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n    android:height="108dp"\n'
        '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
        + govde + '</vector>\n')


def _yaz(yol, icerik):
    yol = os.path.normpath(os.path.join(KOK, yol))
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with open(yol, "w", encoding="utf-8", newline="\n") as f:
        f.write(icerik)


def main():
    for klasor, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        yol = os.path.normpath(os.path.join(KOK, "mipmap-" + klasor, "ic_launcher.png"))
        os.makedirs(os.path.dirname(yol), exist_ok=True)
        ciz_legacy(px).save(yol, optimize=True)

    kal, tw = W * S, TIK_W * S
    _yaz("drawable/ic_launcher_foreground.xml", _vektor([
        (_yol_iz(), _hex(IZ), kal, "butt"),
        (_yol_yay(), _hex(YESIL), kal, "butt"),
        (_yol_tik(), _hex(TIK), tw, "round"),
    ]))
    # Temali ikon: yalniz alfa kullanilir; iz soluk, yay ve tik tam opak
    _yaz("drawable/ic_launcher_monochrome.xml", _vektor([
        (_yol_iz(), "#4D000000", kal, "butt"),
        (_yol_yay(), "#FF000000", kal, "butt"),
        (_yol_tik(), "#FF000000", tw, "round"),
    ]))
    _yaz("values/ic_launcher_background.xml",
         '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
         '    <color name="ic_launcher_background">%s</color>\n</resources>\n' % _hex(ARKA))
    _yaz("mipmap-anydpi-v26/ic_launcher.xml",
         '<?xml version="1.0" encoding="utf-8"?>\n'
         '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
         '    <background android:drawable="@color/ic_launcher_background" />\n'
         '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
         '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
         '</adaptive-icon>\n')


if __name__ == "__main__":
    main()
