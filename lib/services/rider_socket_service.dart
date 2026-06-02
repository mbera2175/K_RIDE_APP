import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../utils/constants.dart';

class RiderSocketService {
  static WebSocketChannel? _channel;
  static Function(Map<String, dynamic>)? onMessage;
  static bool _isConnected = false;
  static bool get isConnected => _isConnected;

  static Future<void> connect(int riderId, String token) async {
    try {
      disconnect();

      final wsUrl =
          '${AppConstants.wsBaseUrl}/ws/rider/$riderId?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (onMessage != null) onMessage!(data);
          } catch (e) {
            print('Rider socket parse error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('Rider WebSocket disconnected');
        },
        onError: (e) {
          _isConnected = false;
          print('Rider WebSocket error: $e');
        },
      );

      // Send ping every 30 seconds
      Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_isConnected) {
          send({'type': 'ping'});
        } else {
          timer.cancel();
        }
      });

      print('Rider WebSocket connected');
    } catch (e) {
      print('Rider socket connection error: $e');
    }
  }

  static void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  static void disconnect() {
    _isConnected = false;
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }
}
