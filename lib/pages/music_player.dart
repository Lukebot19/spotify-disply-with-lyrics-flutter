import 'dart:async';
import 'dart:convert';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:auto_scroll_text/auto_scroll_text.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:spotify/spotify.dart' as Spotify;
import 'package:spotify_display/constants/colors.dart';
import 'package:spotify_display/constants/strings.dart';
import 'package:spotify_display/pages/landing_page.dart';
import 'package:spotify_display/pages/lyrics_page.dart';
import 'package:spotify_display/pages/settings_page.dart';
import 'package:spotify_display/states/main_state.dart';
import 'package:spotify_display/storage.dart';
import 'package:spotify_display/storage/storage.dart';
import 'package:spotify_display/widgets/art_work_image.dart';
import 'package:http/http.dart' as http;

import '../models/music.dart';
import '../widgets/base_widget.dart';

class MusicPlayer extends StatefulWidget {
  Spotify.SpotifyApi? spotify;
  MusicPlayer({super.key, required this.spotify});

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  StreamController<Duration>? _streamController;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  Color textColor = Colors.white;

  @override
  void dispose() {
    _timer?.cancel();
    _streamController?.close();
    super.dispose();
  }

  void pollSpotify(MainState state) {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      Spotify.PlaybackState? _currentTrack;
      try {
        _currentTrack = await widget.spotify?.player.playbackState();
      } catch (e) {
        if (e is Spotify.AuthorizationException) {
          try {
            final refreshToken = StorageService().getRefreshToken();

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
              await StorageService().saveTokens(
                accessToken: data['access_token'],
                refreshToken: data['refresh_token'],
              );
              widget.spotify =
                  Spotify.SpotifyApi.withAccessToken(data['access_token']);
            } else {
              throw Exception('Failed to refresh access token');
            }
          } catch (_) {
            Storage().clear();
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) {
              return LandingPage();
            }));
          }
        }
        _currentTrack = null;
      }
      if (_currentTrack != null) {
        setMusicState(_currentTrack, state);
      }
    });
  }

  void _startTimer(MainState state) {
    if (state.music.currentPosition == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _streamController
          ?.add(Duration(milliseconds: state.music.currentPosition!));
    });
  }

  Future<void> connectToSpotify(MainState state) async {
    await getCurrentTrack(state);

    if (state.currentTrack == false) {
      // Poll the api every second until the playerstate has changed
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        await getCurrentTrack(state);
        if (state.currentTrack == true) {
          timer.cancel();
        }
      });
    }
    _streamController = StreamController<Duration>();
    _startTimer(state);
  }

  Future<void> getCurrentTrack(MainState state) async {
    Spotify.PlaybackState? currentTrack;
    try {
      currentTrack = await widget.spotify?.player.playbackState();
    } catch (e) {
      if (e is Spotify.AuthorizationException) {
        Storage().clear();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) {
          return LandingPage();
        }));
      }
      currentTrack = null;
    }
    if (currentTrack != null) {
      setMusicState(currentTrack, state);
      state.setCurrentTrack(true);
    } else {
      state.setCurrentTrack(false);
    }
    if (mounted) {
      setState(() {});
    }
  }

  setMusicState(Spotify.PlaybackState currentTrack, MainState state) async {
    if (state.music != null) {
      // Check if the song in the state is the same as the current song
      if (state.music.trackId == currentTrack.item?.id) {
        // Update the current position, isPlaying and isShuffling
        state.music.currentPosition = currentTrack.progress_ms;
        state.music.isPlaying = currentTrack.isPlaying;
        state.music.isShuffling = currentTrack.isShuffling;
        state.music.isLiked = await widget.spotify!.tracks.me.containsOne(
          currentTrack.item?.id.toString() ?? "",
        );
        setState(() {});
        return;
      }
    }

    Music music = Music(
      trackId: currentTrack.item?.id ?? "",
      songName: currentTrack.item?.name ?? "",
      artistName: currentTrack.item?.artists?.first.name ?? "",
      songImage: currentTrack.item!.album?.images?.first.url,
      artistImage: currentTrack.item?.artists?.first.images?.first.url,
      duration: currentTrack.item?.duration,
      isPlaying: currentTrack.isPlaying,
      isShuffling: currentTrack.isShuffling,
      repeatState: currentTrack.repeatState,
      currentPosition: currentTrack.progress_ms,
      isLiked: await widget.spotify!.tracks.me.containsOne(
        currentTrack.item?.id.toString() ?? "",
      ),
    );

    state.setMusic(music);

    Spotify.Track? track = currentTrack.item;
    if (track == null) {
      return;
    }
    String? tempSongName = track.name;
    if (tempSongName != null) {
      state.music.songName = tempSongName;
      state.music.artistName = track.artists?.first.name ?? "";
      String? image = track.album?.images?.first.url;
      if (image != null) {
        state.music.songImage = image;
        final tempSongColor = await getImagePalette(NetworkImage(image));
        if (tempSongColor != null) {
          state.setColours(
            tempSongColor.red,
            tempSongColor.green,
            tempSongColor.blue,
          );

          if (state.ledCharacteristic != null) {
            state.sendCommand();
          }

          state.music.songColor = tempSongColor;
          // Compute luminance of the color
          double luminance = tempSongColor.computeLuminance();

          // If the color is light, set text and icons to black. Otherwise, set them to white.
          textColor = luminance > 0.5 ? Colors.black : Colors.white;

          // Now you can use `textColor` for your text and icons.
        }
      }
      state.music.artistImage = track.artists?.first.images?.first.url;
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
      body: BaseWidget<MainState>(
        state: Provider.of<MainState>(context),
        onStateReady: (state) async {
          await connectToSpotify(state);
          pollSpotify(state);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        },
        builder: (context, state, child) {
          return Scaffold(
            backgroundColor:
                state.music.songColor ?? const Color.fromARGB(255, 29, 185, 84),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: state.currentTrack == true
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
                                      child: ArtWorkImage(
                                          image: state.music.songImage),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AutoScrollText(
                                            velocity: const Velocity(
                                                pixelsPerSecond: Offset(40, 0)),
                                            pauseBetween:
                                                const Duration(seconds: 2),
                                            mode: AutoScrollTextMode.bouncing,
                                            state.music.songName ?? '',
                                            style: textTheme.titleMedium
                                                ?.copyWith(color: textColor),
                                          ),
                                          Text(
                                            state.music.artistName ?? '-',
                                            style: textTheme.bodySmall
                                                ?.copyWith(color: textColor),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                ),
                              ),
                              Icon(
                                state.music.isLiked == true
                                    ? Icons.favorite
                                    : Icons.favorite_outline,
                                color: state.music.isLiked == true
                                    ? CustomColors.primaryColor
                                    : textColor,
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
                                            milliseconds:
                                                state.music.currentPosition ??
                                                    0,
                                          ),
                                      total: state.music.duration ??
                                          const Duration(minutes: 0),
                                      bufferedBarColor: Colors.white38,
                                      baseBarColor: Colors.white10,
                                      thumbColor: textColor,
                                      timeLabelTextStyle: TextStyle(
                                          color: textColor, fontSize: 12),
                                      progressBarColor: textColor,
                                      onSeek: (duration) {
                                        widget.spotify?.player
                                            .seek(duration.inMilliseconds);
                                      },
                                    );
                                  },
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const LyricsPage(),
                                            ),
                                          );
                                        },
                                        icon: Icon(Icons.lyrics_outlined,
                                            color: textColor)),
                                    IconButton(
                                        onPressed: () async {
                                          await widget.spotify!.player
                                              .previous();
                                          Spotify.PlaybackState newState =
                                              await widget.spotify!.player
                                                  .playbackState();
                                          setMusicState(newState, state);
                                          _timer?.cancel();
                                          _startTimer(state);
                                        },
                                        icon: Icon(Icons.skip_previous,
                                            color: textColor, size: 36)),
                                    IconButton(
                                        onPressed: () async {
                                          Spotify.PlaybackState? newState;
                                          if (state.music.isPlaying == true) {
                                            newState = await widget
                                                .spotify!.player
                                                .pause();
                                            _timer?.cancel();
                                          } else {
                                            // Manually call the Spotify API endpoint to start or resume playback
                                            Map<String, dynamic> tokens =
                                                await StorageService()
                                                    .getTokens();
                                            String accessToken =
                                                tokens['accessToken'];
                                            var response = await http.put(
                                              Uri.parse(
                                                  'https://api.spotify.com/v1/me/player/play'),
                                              headers: {
                                                'Authorization':
                                                    'Bearer $accessToken',
                                              },
                                            );

                                            if (response.statusCode == 204) {
                                              // The playback started successfully
                                              _timer?.cancel();
                                              _startTimer(state);
                                              newState = await widget
                                                  .spotify!.player
                                                  .playbackState();
                                              setMusicState(newState, state);
                                            } else {
                                              // Handle the error
                                              print(
                                                  'Failed to start playback: ${response.statusCode}');
                                            }
                                            return;
                                          }
                                          setMusicState(newState!, state);

                                          setState(() {});
                                        },
                                        icon: Icon(
                                          state.music.isPlaying == true
                                              ? Icons.pause
                                              : Icons.play_circle,
                                          color: textColor,
                                          size: 45,
                                        )),
                                    IconButton(
                                        onPressed: () async {
                                          await widget.spotify!.player.next();
                                          Spotify.PlaybackState newState =
                                              await widget.spotify!.player
                                                  .playbackState();
                                          setMusicState(newState, state);
                                          _timer?.cancel();
                                          _startTimer(state);
                                        },
                                        icon: Icon(Icons.skip_next,
                                            color: textColor, size: 36)),
                                    IconButton(
                                        onPressed: () async {
                                          Navigator.push(context,
                                              MaterialPageRoute(
                                                  builder: (context) {
                                            return SettingsPage();
                                          }));
                                        },
                                        icon: Icon(Icons.settings,
                                            color: textColor)),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("No music playing..."),
                          const SizedBox(height: 10),
                          TextButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.black,
                              ),
                            ),
                            onPressed: () async {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return SettingsPage();
                              }));
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings, color: textColor),
                                const SizedBox(width: 10),
                                Text(
                                  "Launch Settings",
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: textColor,
                              ),
                              Text(
                                "Powered By Spotify",
                                style: TextStyle(color: textColor),
                              ),
                            ],
                          )
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
