/// What the BottlesUp Business app collects, stated as facts that can be checked in the code (client answer 15 of 20 Oct: "the client arranges the legal wording; the developer explains
/// what is collected; no placeholder as final"). This is NOT the legal privacy policy: that text is BottlesUp's own and lives on the website. Nothing here promises a retention period, a
/// region or a legal basis, because none of those is decided in the app. If the app starts to collect something new, this list and `docs/DATA_COLLECTED_BUSINESS_APP.md` in the monorepo change with it.
class DataSection {
  const DataSection(this.title, this.lines);

  final String title;
  final List<String> lines;
}

const List<DataSection> dataCollected = [
  DataSection('Your account', [
    'The email address or phone number and the name you sign in with.',
    'Which businesses and clubs you work for, and your role in each (owner, manager, organizer, server, door, security, verifier).',
    'On your phone only: which workspace you used last, so it is listed first next time.',
  ]),
  DataSection('What you enter about the night', [
    'Bookings and their guests: names, and an email address or phone number only where you type one (a walk-in, or a guest list).',
    'Orders, deliveries, payments you record (amount, how it was paid, the till\'s receipt number), refunds, discounts and free bottles, tables held or moved, notes, chat messages, incident reports, inventory counts and cash handovers.',
    'Who did each thing and when. This history is kept so that a manager can see it and nothing is silently changed.',
  ]),
  DataSection('Camera and photos', [
    'The camera reads QR codes to check guests in. The picture is not kept.',
    'Photos you choose or take for a receipt are stored privately; only the people at that club who need them can open one.',
    'Photos you add for a venue, a table, a bottle or an event are public: guests see them on the booking pages.',
  ]),
  DataSection('What the app does not collect', [
    'Your location, your contacts, or an advertising identifier.',
    'No advertising and no analytics profile of you. This version sends no push notifications.',
    'Card numbers. Guests pay online on the website through the payment provider; this app never sees a card number.',
  ]),
  DataSection('Crash reports', [
    'When the build you installed has crash reporting switched on, a crash sends the error and the app version. The person, the web requests, the trail of screens and screenshots are removed before it leaves the phone. When it is switched off nothing is sent.',
  ]),
  DataSection('Other contact with outside services', [
    'The first time the app runs it may download its text font from Google Fonts, so Google can see the phone\'s internet address.',
    'About every 15 seconds the app checks that BottlesUp\'s server answers, to tell you when you are offline. It sends no personal details.',
  ]),
  DataSection('Where the rest is decided', [
    'What each role may see and do is decided by the database, not the app.',
    'How long records are kept, where they are held and your legal rights are set out in BottlesUp\'s privacy policy, which is on the website.',
  ]),
];

/// Words that belong to placeholder or invented policy text and must never come back into what a person reads here.
const List<String> forbiddenPlaceholderWords = [
  'Main Street', '800-BOTTLES', 'January 2025', 'Google Analytics', 'AWS', 'New York', 'dpo@', 'privacy@bottlesup.com', 'Marketing cookies', '7 years',
];
