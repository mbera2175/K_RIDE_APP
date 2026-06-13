import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../utils/constants.dart';
import '../main.dart';

class DriverSocketService {
  static WebSocketChannel? _channel;

  static Function(Map<String, dynamic>)? onMessage;

  static bool _isConnected = false;

  static bool get isConnected => _isConnected;

  static bool isChatOpen = false;

  static Future<void> connect(int driverId, String token) async {
    try {
      disconnect();

      final wsUrl =
    '${AppConstants.wsBaseUrl}/ws/driver/$driverId?token=$token';

      print('Driver socket connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      await _channel!.ready;
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);

            if (data['type'] == 'chat_message') {
              if (data['open_chat'] == true && !isChatOpen) {
                isChatOpen = true;
                navigatorKey.currentState?.pushNamed(
                  '/chat',
                  arguments: {
                    'trip_id': data['trip_id'],
                  },
                ).then((_) {
                  isChatOpen = false;
                });
              }
            }

            if (onMessage != null) {
              onMessage!(data);
            }
          } catch (e) {
            print('Socket parse error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('Driver WebSocket disconnected. Close code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
        },
        onError: (e) {
          _isConnected = false;
          print('Driver WebSocket error: $e. Close code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
        },
      );

      print('Driver WebSocket connected');
    } catch (e) {
      print('Socket connection error: $e');
    }
  }

  static void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(
        jsonEncode(data),
      );
    }
  }

  static void disconnect() {
    _isConnected = false;

    _channel?.sink.close(
      status.normalClosure,
    );

    _channel = null;
  }
}
