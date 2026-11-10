"""Fake GitHub for the in-app update trial (development only; do NOT run against a real device on a real network).

Usage:  python guncelleme_sahte_github.py [kotu] [apk_klasoru] [surum]
  apk_klasoru  directory holding `yeni.apk`: the NEW release APK, signed with the SAME release key as
               the installed app, with a higher versionCode (default: ./apk)
  surum        version in the tag/asset names (default 0.1.1; must be higher than the installed one)
  kotu         bad scenario: SHA256SUMS.txt carries a wrong hash, so the app must refuse to install

The emulator reaches this host as 10.0.2.2:8123. The app only talks to GitHub hosts (https), so the trial
build must be started with the test hook that points the updater at this server (see the emulator
stage notes in docs/gece-raporu/02c-android.md). Repo and asset names mirror the real release pipeline:
tungarix/habit-tracker-mobil, Habit-Tracker-X.Y.Z.apk, SHA256SUMS.txt.
"""
import hashlib
import http.server
import json
import pathlib
import sys

ARGS = [a for a in sys.argv[1:] if a != "kotu"]
KOTU = "kotu" in sys.argv[1:]  # bad scenario: wrong hash
KLASOR = pathlib.Path(ARGS[0]) if ARGS else pathlib.Path(__file__).parent / "apk"
SURUM = ARGS[1] if len(ARGS) > 1 else "0.1.1"
APK_ADI = f"Habit-Tracker-{SURUM}.apk"
APK = (KLASOR / "yeni.apk").read_bytes()
OZET = hashlib.sha256(APK).hexdigest()
ISTEKLER = []


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, f, *a):
        print("ISTEK", self.path, flush=True)

    def _yaz(self, kod, veri, tur="application/octet-stream"):
        self.send_response(kod)
        self.send_header("Content-Type", tur)
        self.send_header("Content-Length", str(len(veri)))
        self.end_headers()
        self.wfile.write(veri)

    def do_GET(self):
        taban = "http://10.0.2.2:8123"
        if self.path.endswith("/releases/latest"):
            veri = {
                "tag_name": f"v{SURUM}", "draft": False, "prerelease": False,
                "html_url": f"{taban}/sayfa",
                "assets": [
                    {"name": APK_ADI, "size": len(APK), "browser_download_url": f"{taban}/dl/{APK_ADI}"},
                    {"name": "SHA256SUMS.txt", "size": 90, "browser_download_url": f"{taban}/dl/SHA256SUMS.txt"},
                ],
            }
            self._yaz(200, json.dumps(veri).encode(), "application/json")
        elif self.path == f"/dl/{APK_ADI}":
            self._yaz(200, APK)
        elif self.path == "/dl/SHA256SUMS.txt":
            ozet = ("0" * 64) if KOTU else OZET
            self._yaz(200, f"{ozet}  {APK_ADI}\n".encode(), "text/plain")
        else:
            self._yaz(404, b"")


print("sahte github hazir", "(KOTU ozet)" if KOTU else "", flush=True)
http.server.ThreadingHTTPServer(("0.0.0.0", 8123), H).serve_forever()
