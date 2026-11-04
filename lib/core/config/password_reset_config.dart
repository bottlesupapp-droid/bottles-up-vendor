/// What this app tells Supabase when it asks for a password-reset email. It is not where the person ends up: the email's button goes to the
/// website's /reset-password page (which can open this app again, see recovery_link.dart), and this address is how the email knows the request
/// came from BottlesUp Business and not from the customer app (supabase/email-templates/recovery.html in the website repo matches it exactly).
/// It must be listed in Supabase > Authentication > URL Configuration > Redirect URLs, or the email falls back to its neutral wording.
const String passwordResetRedirect = 'https://www.bottlesupapp.com/reset-password?app=business';

/// The address the website's page uses to open this app (registered in AndroidManifest.xml and ios/Runner/Info.plist).
const String businessAppScheme = 'bottlesupbusiness';
