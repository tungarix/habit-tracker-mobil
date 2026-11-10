// Spike: pure-Dart self-signed cert + pinned-fingerprint HTTPS on loopback.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

String b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');

Uint8List pemToDer(String pem) => base64.decode(pem
    .split(RegExp(r'\r?\n'))
    .where((l) => l.isNotEmpty && !l.startsWith('-----'))
    .join());

Future<String> get(int port, String token, String pin) async {
  final c = HttpClient(context: SecurityContext(withTrustedRoots: false))
    ..connectionTimeout = const Duration(seconds: 5)
    // Accept only the exact pinned certificate; hostname is not checked here.
    ..badCertificateCallback =
        (cert, host, p) => b64url(sha256.convert(cert.der).bytes) == pin;
  try {
    final req = await c.getUrl(Uri.parse('https://127.0.0.1:$port/v1/hello'));
    req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return '${res.statusCode} $body';
  } on HandshakeException catch (e) {
    return 'REJECTED (handshake): ${e.message}';
  } finally {
    c.close(force: true);
  }
}

Future<void> main() async {
  final sw = Stopwatch()..start();
  final pair = CryptoUtils.generateEcKeyPair(); // prime256v1
  final priv = pair.privateKey as ECPrivateKey;
  final pub = pair.publicKey as ECPublicKey;
  final csr = X509Utils.generateEccCsrPem(
      {'CN': 'habit-sync'}, priv, pub, san: ['127.0.0.1']);
  final certPem = X509Utils.generateSelfSignedCertificate(priv, csr, 1,
      sans: ['127.0.0.1'], serialNumber: '1');
  final keyPem = CryptoUtils.encodeEcPrivateKeyToPem(priv);
  print('keygen+cert: ${sw.elapsedMilliseconds} ms');

  final der = pemToDer(certPem);
  final pin = b64url(sha256.convert(der).bytes);
  print('pin (${pin.length} chars): $pin');

  final ctx = SecurityContext()
    ..useCertificateChainBytes(utf8.encode(certPem))
    ..usePrivateKeyBytes(utf8.encode(keyPem));
  final server = await HttpServer.bindSecure(
      InternetAddress('127.0.0.1'), 0, ctx);
  final rnd = Random.secure();
  final token =
      List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  var used = false;
  server.listen((r) async {
    final ok = !used && r.headers.value('authorization') == 'Bearer $token';
    if (ok) used = true; // single use
    r.response.statusCode = ok ? 200 : 401;
    r.response.write(ok ? '{"format":"habit-sync"}' : '{"error":"yetkisiz"}');
    await r.response.close();
  });
  final port = server.port;
  print('listening 127.0.0.1:$port');

  final wrongPin = b64url(sha256.convert([1, 2, 3]).bytes);
  print('1 wrong token      : ${await get(port, 'a' * 32, pin)}');
  print('2 wrong fingerprint: ${await get(port, token, wrongPin)}');
  print('3 correct          : ${await get(port, token, pin)}');
  print('4 token reuse      : ${await get(port, token, pin)}');
  await server.close(force: true);
}
