import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/chat/screens/chat_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/walkin/providers/walkin_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/fake_chat_backend.dart';
import '../walkin/fake_walkin_backend.dart';
import 'fake_table_backend.dart';

const managerWs = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

void main() {
  testWidgets('Message team on Tonight opens the manager\'s messages, with the club\'s chat in it', (tester) async {
    final tables = FakeTableBackend()..role = 'manager';
    tables.now = DateTime(2026, 10, 9, 21);
    final chat = FakeChatBackend();
    chat.conversations.add(FakeConversation('c1', 'venue', 'Club A', venueId: 'v1'));
    chat.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice');
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tableServiceServiceProvider.overrideWithValue(tables.service),
        walkinServiceProvider.overrideWithValue(FakeWalkinBackend().service),
        chatServiceProvider.overrideWithValue(chat.service),
        chatPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: TonightScreen(workspace: managerWs, clock: () => DateTime(2026, 10, 9, 21)))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('message-team')), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    await tester.tap(find.byKey(const Key('message-team')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.textContaining('Table 4 needs ice'), findsOneWidget);
    expect(chat.calledWith('chat_conversations'), isNotEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byKey(const Key('message-team')), findsOneWidget);
  });
}
