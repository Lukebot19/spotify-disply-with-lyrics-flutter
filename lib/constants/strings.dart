import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;


class CustomStrings {
  static String clientId = dotenv.dotenv.env['SPOTIFY_CLIENT_ID']!;
  static String clientSecret = dotenv.dotenv.env['SPOTIFY_CLIENT_SECRET']!;
}
