// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:bottles_up_vendor/features/events/services/event_team_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// EventTeamService is the Team & Lineup page's four database calls, moved out of the page unchanged so the page can be shown with a fake. The page's own tests use that fake, so
// these tests check the real service: they run it against a stand-in for the network and read what it would have sent to the `event_team_members` table.
class Sent {
  Sent(this.method, this.uri, this.body);

  final String method;
  final Uri uri;
  final Object? body;
}

void main() {
  late List<Sent> sent;
  late EventTeamService service;

  setUp(() {
    sent = [];
    final client = MockClient((http.Request request) async {
      sent.add(Sent(request.method, request.url, request.body.isEmpty ? null : jsonDecode(request.body)));
      final rows = [
        {'id': 'm1', 'event_id': 'e1', 'name': 'DJ Kato', 'email': null, 'phone': null, 'role': 'DJ', 'created_at': '2026-01-01T00:00:00Z', 'updated_at': '2026-01-01T00:00:00Z'},
      ];
      return http.Response(request.method == 'GET' ? jsonEncode(rows) : '[]', 200, request: request, headers: {'content-type': 'application/json'});
    });
    service = EventTeamService(SupabaseClient('http://localhost:54321', 'anon-key', httpClient: client));
  });

  test('list reads the event\'s own team, oldest first, and builds the members', () async {
    final members = await service.list('e1');
    expect(members.map((m) => m.name), ['DJ Kato']);
    final request = sent.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/rest/v1/event_team_members');
    expect(request.uri.queryParameters['event_id'], 'eq.e1');
    expect(request.uri.queryParameters['order'], 'created_at.asc.nullslast');
  });

  test('add writes one row for this event with the name, role, e-mail and phone', () async {
    await service.add(eventId: 'e1', name: 'Ada', role: 'Security', email: 'ada@x.test', phone: '+1 416 555 0100');
    final request = sent.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/rest/v1/event_team_members');
    final body = request.body is List ? (request.body as List).single : request.body;
    expect(body, {'event_id': 'e1', 'name': 'Ada', 'role': 'Security', 'email': 'ada@x.test', 'phone': '+1 416 555 0100'});
  });

  test('update changes that one member only, and stamps when', () async {
    await service.update('m1', name: 'Leigh', role: 'Bartender');
    final request = sent.single;
    expect(request.method, 'PATCH');
    expect(request.uri.queryParameters['id'], 'eq.m1', reason: 'only this member, never the whole team');
    final body = request.body as Map;
    expect(body['name'], 'Leigh');
    expect(body['role'], 'Bartender');
    expect(body.containsKey('updated_at'), isTrue);
    expect(body.containsKey('event_id'), isFalse, reason: 'a member never moves to another event');
  });

  test('remove deletes that one member only', () async {
    await service.remove('m1');
    final request = sent.single;
    expect(request.method, 'DELETE');
    expect(request.uri.queryParameters['id'], 'eq.m1');
  });
}
