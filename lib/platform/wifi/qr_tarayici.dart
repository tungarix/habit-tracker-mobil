// QR tarayıcı soyutlaması: testler gerçek kamera istemez. Gerçek uygulama `mobile_scanner` (CameraX + ML Kit).
// Kamera izni tarayıcı açılırken `mobile_scanner`'ın kendi akışıyla istenir (permission_handler kullanılmaz).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui_metin.dart';

/// [bulundu]: ilk okunan metin (tarayıcı sonra kendini kapatır). [izinYok]: kamera izni reddedildi.
/// [hata]: kamera açılamadı (izin dışı).
typedef QrTarayiciKurucu = Widget Function(
  BuildContext context, {
  required void Function(String metin) bulundu,
  required VoidCallback izinYok,
  required VoidCallback hata,
});

final qrTarayiciProvider = Provider<QrTarayiciKurucu>((ref) => gercekTarayici);

Widget gercekTarayici(
  BuildContext context, {
  required void Function(String metin) bulundu,
  required VoidCallback izinYok,
  required VoidCallback hata,
}) => _GercekTarayici(bulundu: bulundu, izinYok: izinYok, hata: hata);

class _GercekTarayici extends StatefulWidget {
  const _GercekTarayici({
    required this.bulundu,
    required this.izinYok,
    required this.hata,
  });
  final void Function(String) bulundu;
  final VoidCallback izinYok, hata;

  @override
  State<_GercekTarayici> createState() => _GercekTarayiciState();
}

class _GercekTarayiciState extends State<_GercekTarayici> {
  final _denetleyici = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _bitti = false;

  @override
  void dispose() {
    _denetleyici.dispose(); // kamerayı serbest bırakır
    super.dispose();
  }

  void _bulundu(BarcodeCapture c) {
    if (_bitti) return;
    for (final b in c.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        _bitti = true;
        _denetleyici.stop(); // kamera ağ isteğinden önce kapanır
        widget.bulundu(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: Metin.wifiTarayiciEtiket,
      child: MobileScanner(
        controller: _denetleyici,
        onDetect: _bulundu,
        errorBuilder: (ctx, e) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _bitti) return;
            _bitti = true;
            e.errorCode == MobileScannerErrorCode.permissionDenied
                ? widget.izinYok()
                : widget.hata();
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
