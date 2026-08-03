import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A hand-rolled [HttpClientAdapter] double: answers requests from an
/// in-memory responder function instead of touching a socket. Used instead
/// of a mocking package so repository/interceptor tests never reach the
/// network, a real backend, or an emulator.
///
/// [responder] may return a [ResponseBody] synchronously, or a
/// `Future<ResponseBody>` (e.g. a [Completer] a test controls by hand) to
/// simulate a request that stays in flight until the test explicitly
/// resolves it — used for "an older, slower request must not overwrite a
/// newer one" tests.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FutureOr<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> capturedRequests = [];

  FakeHttpClientAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);
    return await responder(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Builds a JSON [ResponseBody] the way a real server would (with a
/// `content-type: application/json` header). [body] is `dynamic` because
/// real endpoints return either a JSON object (`{...}`, e.g. the auth
/// envelopes) or a bare JSON array (e.g. `GET /prestamos/creditos`).
ResponseBody jsonResponseBody(dynamic body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
