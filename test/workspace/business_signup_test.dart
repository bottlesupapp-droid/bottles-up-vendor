import 'package:bottles_up_vendor/features/workspace/logic/business_signup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // What the database issues: two UUIDs with the dashes removed.
  const token = '0f8fad5bd9cb469fa16570867728950e3a1c4b7e9d2f4a6c8b0e1d3f5a7c9e2b';

  group('businessSignupUri', () {
    test('is the website\'s business signup page', () {
      expect(businessSignupUri('https://www.bottlesupapp.com').toString(), 'https://www.bottlesupapp.com/signup/business');
    });

    test('does not double a trailing slash', () {
      expect(businessSignupUri('https://example.test/').toString(), 'https://example.test/signup/business');
      expect(businessSignupUri('https://example.test///').toString(), 'https://example.test/signup/business');
    });
  });

  group('invitationTokenFrom', () {
    test('the whole link from the invitation email', () {
      expect(invitationTokenFrom('https://www.bottlesupapp.com/accept-invite?token=$token'), token);
    });

    test('a link with other parameters, a different site, or surrounding spaces and a line break', () {
      expect(invitationTokenFrom('  http://localhost:8080/accept-invite?next=%2Fhome&token=$token&utm=x\n'), token);
    });

    test('the token on its own', () {
      expect(invitationTokenFrom(token), token);
      expect(invitationTokenFrom('\n$token \n'), token);
    });

    test('anything else is not a token', () {
      expect(invitationTokenFrom(''), isNull);
      expect(invitationTokenFrom('   '), isNull);
      expect(invitationTokenFrom('hello'), isNull);
      expect(invitationTokenFrom('https://www.bottlesupapp.com/accept-invite'), isNull); // no token in it
      expect(invitationTokenFrom('https://www.bottlesupapp.com/accept-invite?code=$token'), isNull); // not called token
      expect(invitationTokenFrom('https://www.bottlesupapp.com/accept-invite?token=short'), isNull);
      expect(invitationTokenFrom('please use $token thanks'), isNull); // text around a bare token
    });

    test('the length limits', () {
      expect(invitationTokenFrom('a' * 31), isNull);
      expect(invitationTokenFrom('a' * 32), 'a' * 32);
      expect(invitationTokenFrom('a' * 128), 'a' * 128);
      expect(invitationTokenFrom('a' * 129), isNull);
    });

    test('a link whose token is too long or too short is not accepted', () {
      expect(invitationTokenFrom('https://x.test/accept-invite?token=${'a' * 129}'), isNull);
      expect(invitationTokenFrom('https://x.test/accept-invite?token=${'a' * 31}'), isNull);
    });
  });
}
