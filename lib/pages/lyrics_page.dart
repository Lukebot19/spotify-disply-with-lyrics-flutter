import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:spotify_display/models/lyrics.dart';
import 'package:spotify_display/models/music.dart';
import 'package:spotify_display/states/main_state.dart';
import 'package:spotify_display/utils/resize_window.dart';
import 'package:spotify_display/widgets/base_widget.dart';

class LyricsPage extends StatefulWidget {
  const LyricsPage({
    super.key,
  });

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  late MainState state;
  List<Lyric>? lyrics;
  bool not_found = false;
  final ItemScrollController itemScrollController = ItemScrollController();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();
  StreamSubscription? streamSubscription;

  StreamController<Duration>? _streamController;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  bool firstTime = true;

  @override
  void dispose() {
    _timer?.cancel();
    _streamController?.close();
    streamSubscription?.cancel();
    super.dispose();
  }

  void _startTimer() {
    int? startPosition = state.music.currentPosition;
    if (startPosition != null) {
      _elapsedTime = Duration(milliseconds: startPosition);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _elapsedTime += Duration(milliseconds: 100);
      _streamController?.add(_elapsedTime);
    });
  }

  @override
  void initState() {
    state = Provider.of<MainState>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await resizeWindow(350, 250);
    });

    _streamController = StreamController<Duration>.broadcast();
    _startTimer();

    streamSubscription = _streamController?.stream.listen((duration) {
      DateTime dt = DateTime(1970, 1, 1).copyWith(
          hour: duration.inHours,
          minute: duration.inMinutes.remainder(60),
          second: duration.inSeconds.remainder(60));
      if (lyrics != null) {
        for (int index = 0; index < lyrics!.length; index++) {
          if (lyrics![index].timeStamp.isAfter(dt)) {
            int scrollToIndex = index > 0 ? index - 1 : index;
            // If loading the page for the first time, scroll to the current position
            if (firstTime == true) {
              itemScrollController.jumpTo(index: scrollToIndex);
              firstTime = false;
            }
            itemScrollController.scrollTo(
                index: scrollToIndex,
                duration: const Duration(milliseconds: 600));
            break;
          }
        }
      }
    });
    get(Uri.parse(
            'https://paxsenixofc.my.id/server/getLyricsMusix.php?q=${state.music.songName} ${state.music.artistName}&type=default'))
        .then((response) {
      String data = response.body;
      try {
        lyrics = data
            .split('\n')
            .map((e) => Lyric(
                words: e.split(']')[1].split(' ').sublist(0).join(' '),
                timeStamp: DateFormat("[mm:ss.SS]").parse(e.split(' ')[0])))
            .toList();
      } catch (e) {
        lyrics = null;
        not_found = true;
      }

      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: state.music.songColor,
      body: BaseWidget<MainState>(
        state: Provider.of<MainState>(context),
        onStateReady: (state) async {},
        builder: (context, state, child) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: state.music.songColor,
              elevation: 0,
              leading: IconButton(
                onPressed: () async {
                  await resizeWindow(350, 190);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back_ios),
              ),
              title: Text(
                state.music.songName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
            backgroundColor: state.music.songColor,
            body: lyrics != null
                ? SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0)
                          .copyWith(top: 20),
                      child: StreamBuilder<Duration>(
                        stream: _streamController?.stream,
                        builder: (context, snapshot) {
                          return ScrollablePositionedList.builder(
                            itemCount: lyrics!.length,
                            itemBuilder: (context, index) {
                              Duration duration =
                                  snapshot.data ?? const Duration(seconds: 0);
                              DateTime dt = DateTime(1970, 1, 1).copyWith(
                                  hour: duration.inHours,
                                  minute: duration.inMinutes.remainder(60),
                                  second: duration.inSeconds.remainder(60));
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Text(
                                  lyrics![index].words,
                                  style: TextStyle(
                                    color: lyrics![index].timeStamp.isAfter(dt)
                                        ? Colors.white38
                                        : Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                            itemScrollController: itemScrollController,
                            scrollOffsetController: scrollOffsetController,
                            itemPositionsListener: itemPositionsListener,
                            scrollOffsetListener: scrollOffsetListener,
                          );
                        },
                      ),
                    ),
                  )
                : not_found == false
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Center(
                        child: Text(
                          'Lyrics not found',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
          );
        },
      ),
    );
  }
}
