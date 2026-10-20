import 'dart:io';

import 'package:bottles_up_vendor/core/connectivity/connection_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

// The real probe, against a real local server: any answer at all means the network works; no answer means it does not.
void main() {
  Future<HttpServer> serve(int status) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = status;
      request.response.close();
    });
    return server;
  }

  for (final status in [200, 401, 404, 500]) {
    test('a server that answers $status is reachable (the network works, whatever the page says)', () async {
      final server = await serve(status);
      addTearDown(() => server.close(force: true));
      expect(await httpProbe('http://127.0.0.1:${server.port}')(), isTrue);
    });
  }

  test('nothing listening is not reachable', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    expect(await httpProbe('http://127.0.0.1:$port')(), isFalse);
  });

  test('an address that is not a web address is not reachable, and does not crash', () async {
    expect(await httpProbe('not a url at all')(), isFalse);
  });
}
