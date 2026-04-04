class AppConstants {
  /// List of email addresses that have administrative privileges in the app.
  static const List<String> adminEmails = [
    'edlich6@gmail.com',
    'thechenmor@gmail.com',
    'ori.demb@gmail.com'
  ];

  /// The redirect URL used for Supabase authentication.
  static const String supabaseAuthSiteUrl =
      'io.supabase.bark://login-callback/';
}
