import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class RideAlertService {

  static final AudioPlayer
      _audioPlayer = AudioPlayer();

  static bool _isPlaying = false;

  static Future<void>
      startAlert() async {

    if (_isPlaying) return;

    _isPlaying = true;

    try {

      await _audioPlayer.setReleaseMode(
        ReleaseMode.loop,
      );

      await _audioPlayer.play(
        AssetSource(
          'sounds/ride_alert.mp3',
        ),
      );

      if (
        await Vibration.hasVibrator() ??
            false
      ) {

        Vibration.vibrate(
          pattern: [
            500,
            1000,
            500,
            1000
          ],
          repeat: 0,
        );

      }

    } catch (e) {

      print(
        'Ride alert error: $e',
      );

    }

  }

  static Future<void>
      stopAlert() async {

    _isPlaying = false;

    try {

      await _audioPlayer.stop();

      Vibration.cancel();

    } catch (e) {

      print(
        'Stop alert error: $e',
      );

    }

  }

}
