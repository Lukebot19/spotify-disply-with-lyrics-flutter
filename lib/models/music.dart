import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';

class Music {
  String? trackId;
  Duration? duration;
  String? artistName;
  String? songName;
  String? songImage;
  String? artistImage;
  Color? songColor;
  bool? isPlaying = false;
  bool? isShuffling = false;
  RepeatState? repeatState;
  int? currentPosition;
  bool? isLiked;

  Music(
      {this.trackId,
      this.duration,
      this.artistName,
      this.songName,
      this.songImage,
      this.artistImage,
      this.songColor,
      this.isPlaying,
      this.isShuffling,
      this.repeatState,
      this.currentPosition,
      this.isLiked});
}
