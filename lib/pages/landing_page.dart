import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart';
import 'package:spotify_display/constants/strings.dart';
import 'package:spotify_display/pages/music_player.dart';
import 'package:spotify_display/utils/preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

import '../provider/main_provider.dart';

class LandingPage extends StatefulWidget {
  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isConnected = false;
  dynamic spotify;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isConnected = prefs.getBool('isConnected') ?? false;
    setState(() {
      _isConnected = isConnected;
    });
    if (_isConnected) {
      if (spotify == null) {
        String accessToken = prefs.getString('accessToken') ?? '';
        spotify = SpotifyApi.withAccessToken(accessToken);

        await prefs.setBool('isConnected', true);
        await prefs.setString(
            'accessToken', spotify?.client.credentials.accessToken);
        await prefs.setString(
            'refreshToken', spotify?.client.credentials.refreshToken ?? '');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MusicPlayer(
            spotify: spotify,
          ),
        ),
      );
    }
  }

  Future<void> _connectSpotify() async {
    var credentials = SpotifyApiCredentials(
        CustomStrings.clientId, CustomStrings.clientSecret);
    var grant = SpotifyApi.authorizationCodeGrant(credentials);

    // The URI to redirect to after the user grants or denies permission. This must match the redirectUri you set in your Spotify application dashboard.
    var redirectUri = 'http://localhost:8080/';

    // The scopes that your application needs. The Spotify API documentation lists all available scopes.
    var scopes = [
      'user-read-playback-state',
      'user-modify-playback-state',
      'user-library-read'
    ];

    var authUri = grant.getAuthorizationUrl(
      Uri.parse(redirectUri),
      scopes: scopes, // scopes are optional
    );

    // `redirectUri` is an imaginary route which will be used to extract an authorization code in your server route
    // The user is redirected to this URI after granting/denying permission.
    // This is where the authorization code is captured and used to obtain the access token.
    await redirectUserTo(authUri);

    // After the user grants/denies permission, Spotify redirects to `redirectUri` with an authorization code.
    // Use this code to obtain an access token.
    var responseUri = await listenForCode(redirectUri);

    dynamic client =
        await grant.handleAuthorizationResponse(responseUri.queryParameters);
    spotify = SpotifyApi.fromClient(client);

    // Your connectToSpotify function here
    // After successful connection, set the flag in SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isConnected', true);
    await prefs.setString('accessToken', client.credentials.accessToken);
    await prefs.setString('refreshToken', client.credentials.refreshToken);
    _checkConnection();
  }

  Future<void> redirectUserTo(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  Future<Uri> listenForCode(String redirectUri) async {
    Completer<Uri> completer = Completer();
    var server = await io.serve((shelf.Request request) {
      var params = request.requestedUri.queryParameters;
      if (params.containsKey('code')) {
        completer.complete(request.requestedUri);
      } else {
        completer.completeError('Authorization code was not obtained');
      }
      return shelf.Response.ok("");
    }, 'localhost', 8080);

    // Wait for the first request to come in with the code.
    Uri uri = await completer.future;

    // Close the server
    await server.close(force: true);

    return uri;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: !_isConnected
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32.0),
                  ),
                ),
                onPressed: _connectSpotify,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speaker, size: 32.0),
                    Text('Connect Spotify'),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
