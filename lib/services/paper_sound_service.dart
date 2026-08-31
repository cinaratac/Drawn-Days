import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PaperSoundService {
  PaperSoundService({AudioPlayer? player, Random? random})
    : _player = player ?? AudioPlayer(),
      _random = random ?? Random();

  static const _assets = [
    'lib/assets/papersound1.mp3',
    'lib/assets/papersound2.mp3',
    'lib/assets/papersound3.mp3',
  ];

  final AudioPlayer _player;
  final Random _random;

  Future<void> playRandom() async {
    final asset = _assets[_random.nextInt(_assets.length)];
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (error, stackTrace) {
      debugPrint('Paper sound failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> dispose() => _player.dispose();
}
