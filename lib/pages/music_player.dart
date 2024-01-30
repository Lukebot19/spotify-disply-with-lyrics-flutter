import 'dart:async';
import 'dart:convert';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify/spotify.dart';
import 'package:spotify_display/constants/colors.dart';
import 'package:spotify_display/constants/strings.dart';
import 'package:spotify_display/models/music.dart';
import 'package:spotify_display/pages/landing_page.dart';
import 'package:spotify_display/pages/lyrics_page.dart';
import 'package:spotify_display/pages/settings_page.dart';
import 'package:spotify_display/utils/preferences.dart';
import 'package:spotify_display/widgets/art_work_image.dart';
import 'package:http/http.dart' as http;

class MusicPlayer extends StatefulWidget {
  SpotifyApi? spotify;
  MusicPlayer({super.key, required this.spotify});

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  Music music = Music();
  bool _currentTrack = false;

  StreamController<Duration>? _streamController;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _streamController?.close();
    super.dispose();
  }

  @override
  void initState() {
    connectToSpotify();
    pollSpotify();
    super.initState();
  }

  void pollSpotify() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      PlaybackState? _currentTrack;
      try {
        _currentTrack = await widget.spotify?.player.playbackState();
      } catch (e) {
        if (e is AuthorizationException) {
          try {
            SharedPreferences prefs = await SharedPreferences.getInstance();

            final refreshToken = prefs.getString('refreshToken');

            // Try to refresh the access token
            final response = await http.post(
              Uri.parse('https://accounts.spotify.com/api/token'),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization':
                    'Basic ${base64Encode(utf8.encode('${CustomStrings.clientId}:${CustomStrings.clientSecret}'))}',
              },
              body: {
                'grant_type': 'refresh_token',
                'refresh_token': refreshToken,
              },
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              prefs.setString('accessToken', data['access_token']);
              prefs.setString('refreshToken', data['refresh_token']);
              widget.spotify = SpotifyApi.withAccessToken(data['access_token']);
            } else {
              throw Exception('Failed to refresh access token');
            }
          } catch (_) {
            clearSharedPreferences();
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) {
              return LandingPage();
            }));
          }
        }
        _currentTrack = null;
      }
      if (_currentTrack != null) {
        setMusicState(_currentTrack);
      }
    });
  }

  void _startTimer() {
    if (music.currentPosition == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _streamController?.add(Duration(milliseconds: music.currentPosition!));
    });
  }

  Future<void> connectToSpotify() async {
    await getCurrentTrack();

    if (_currentTrack == false) {
      // Poll the api every second until the playerstate has changed
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        await getCurrentTrack();
        if (_currentTrack == true) {
          timer.cancel();
        }
      });
    }
    _streamController = StreamController<Duration>();
    _startTimer();
  }

  Future<void> getCurrentTrack() async {
    PlaybackState? currentTrack;
    try {
      currentTrack = await widget.spotify?.player.playbackState();
    } catch (e) {
      if (e is AuthorizationException) {
        clearSharedPreferences();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) {
          return LandingPage();
        }));
      }
      currentTrack = null;
    }
    if (currentTrack != null) {
      _currentTrack = true;
      setMusicState(currentTrack);
    } else {
      _currentTrack = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  setMusicState(PlaybackState currentTrack) async {
    music.trackId = currentTrack.item?.id ?? "";
    music.songName = currentTrack.item?.name;
    music.artistName = currentTrack.item?.artists?.first.name ?? "";
    music.songImage = currentTrack.item!.album?.images?.first.url;
    music.artistImage = currentTrack.item?.artists?.first.images?.first.url;
    music.duration = currentTrack.item?.duration;
    music.isPlaying = currentTrack.isPlaying;
    music.isShuffling = currentTrack.isShuffling;
    music.repeatState = currentTrack.repeatState;
    music.currentPosition = currentTrack.progress_ms;
    music.isLiked = await widget.spotify!.tracks.me.containsOne(music.trackId!);

    Track? track = currentTrack.item;
    if (track == null) {
      return;
    }
    String? tempSongName = track.name;
    if (tempSongName != null) {
      music.songName = tempSongName;
      music.artistName = track.artists?.first.name ?? "";
      String? image = track.album?.images?.first.url;
      if (image != null) {
        music.songImage = image;
        final tempSongColor = await getImagePalette(NetworkImage(image));
        if (tempSongColor != null) {
          music.songColor = tempSongColor;
        }
      }
      music.artistImage = track.artists?.first.images?.first.url;
      setState(() {});
    }
    

    setState(() {});
  }

  Future<Color?> getImagePalette(ImageProvider imageProvider) async {
    final PaletteGenerator paletteGenerator =
        await PaletteGenerator.fromImageProvider(imageProvider);
    return paletteGenerator.dominantColor?.color;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: music.songColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: _currentTrack == true
              ? Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Center(
                                child: ArtWorkImage(image: music.songImage),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SingleChildScrollView(
                                      clipBehavior: Clip.antiAlias,
                                      scrollDirection: Axis.horizontal,
                                      child: Text(
                                        music.songName ?? '',
                                        style: textTheme.titleMedium
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      music.artistName ?? '-',
                                      style: textTheme.bodySmall
                                          ?.copyWith(color: Colors.white60),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                            ],
                          ),
                        ),
                        Icon(
                          music.isLiked == true
                              ? Icons.favorite
                              : Icons.favorite_outline,
                          color: music.isLiked == true
                              ? CustomColors.primaryColor
                              : Colors.white,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          StreamBuilder(
                            stream: _streamController?.stream,
                            builder: (context, data) {
                              return ProgressBar(
                                progress: data.data ??
                                    Duration(
                                        milliseconds: music.currentPosition!),
                                total: music.duration ??
                                    const Duration(minutes: 0),
                                bufferedBarColor: Colors.white38,
                                baseBarColor: Colors.white10,
                                thumbColor: Colors.white,
                                timeLabelTextStyle: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                progressBarColor: Colors.white,
                                onSeek: (duration) {
                                  widget.spotify?.player
                                      .seek(duration.inMilliseconds);
                                },
                              );
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => LyricsPage(
                                                  music: music,
                                                )));
                                  },
                                  icon: const Icon(Icons.lyrics_outlined,
                                      color: Colors.white)),
                              IconButton(
                                  onPressed: () async {
                                    await widget.spotify!.player.previous();
                                    PlaybackState newState = await widget
                                        .spotify!.player
                                        .playbackState();
                                    setMusicState(newState);
                                    _timer?.cancel();
                                    _startTimer();
                                  },
                                  icon: const Icon(Icons.skip_previous,
                                      color: Colors.white, size: 36)),
                              IconButton(
                                  onPressed: () async {
                                    PlaybackState? newState;
                                    if (music.isPlaying == true) {
                                      newState =
                                          await widget.spotify!.player.pause();
                                      _timer?.cancel();
                                    } else {
                                      newState = await widget.spotify!.player
                                          .startOrResume();
                                      _timer?.cancel();
                                      _startTimer();
                                    }
                                    setMusicState(newState!);

                                    setState(() {});
                                  },
                                  icon: Icon(
                                    music.isPlaying == true
                                        ? Icons.pause
                                        : Icons.play_circle,
                                    color: Colors.white,
                                    size: 45,
                                  )),
                              IconButton(
                                  onPressed: () async {
                                    await widget.spotify!.player.next();
                                    PlaybackState newState = await widget
                                        .spotify!.player
                                        .playbackState();
                                    setMusicState(newState);
                                    _timer?.cancel();
                                    _startTimer();
                                  },
                                  icon: const Icon(Icons.skip_next,
                                      color: Colors.white, size: 36)),
                              IconButton(
                                  onPressed: () async {
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (context) {
                                      return SettingsPage();
                                    }));
                                  },
                                  icon: const Icon(Icons.settings,
                                      color: Colors.white)),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ),
      ),
    );
  }
}
