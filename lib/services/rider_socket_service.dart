import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../utils/constants.dart';
import '../main.dart';

class RiderSocketService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static Function(Map<String, dynamic>)? onMessage;
  static Function()? onReconnect;
  static Function()? onDisconnect;

  static bool _isConnected = false;
  static bool get isConnected => _isConnected;

  static bool isChatOpen = false;

  static bool _isExplicitDisconnect = false;
  static Timer? _reconnectTimer;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 6; // 6 attempts * 5 seconds = 30 seconds
  static bool _isReconnecting = false;

  static Future<void> connect(int riderId, String token, {bool isReconnectAttempt = false}) async {
    try {
      if (!isReconnectAttempt) {
        _isExplicitDisconnect = false;
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _isReconnecting = false;
      }

      if (_subscription != null) {
        await _subscription!.cancel();
        _subscription = null;
      }
      if (_channel != null) {
        _channel!.sink.close(status.normalClosure);
        _channel = null;
      }
      _isConnected = false;

      final wsUrl =
          '${AppConstants.wsBaseUrl}/ws/rider/$riderId?token=$token';

      print('Rider socket connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'chat_message') {
              if (data['open_chat'] == true && !isChatOpen) {
                isChatOpen = true;
                navigatorKey.currentState?.pushNamed(
                  '/rider_chat',
                  arguments: {
                    'trip_id': data['trip_id'],
                    'driver_name': data['sender_name'],
                  },
                ).then((_) {
                  isChatOpen = false;
                });
              }
            }
            if (onMessage != null) onMessage!(data);
          } catch (e) {
            print('Rider socket parse error: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('Rider WebSocket disconnected. Close code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
          if (!_isExplicitDisconnect) {
            _startReconnection(riderId, token);
          }
        },
        onError: (e) {
          _isConnected = false;
          print('Rider WebSocket error: $e. Close code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
          if (!_isExplicitDisconnect) {
            _startReconnection(riderId, token);
          }
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
      _isConnected = false;
      print('Rider socket connection error: $e');
      if (!_isExplicitDisconnect) {
        _startReconnection(riderId, token);
      }
    }
  }

  static void _startReconnection(int riderId, String token) {
    if (_isExplicitDisconnect) return;
    if (_isReconnecting) return;
    _isReconnecting = true;
    _reconnectAttempts = 0;

    if (onDisconnect != null) {
      onDisconnect!();
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _reconnectAttempts++;
      print('Rider socket reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts');

      if (_reconnectAttempts > _maxReconnectAttempts) {
        print('Rider socket reconnection failed after 30 seconds');
        timer.cancel();
        _isReconnecting = false;
        return;
      }

      await connect(riderId, token, isReconnectAttempt: true);

      if (_isConnected) {
        print('Rider socket reconnected successfully');
        timer.cancel();
        _isReconnecting = false;
        if (onReconnect != null) {
          onReconnect!();
        }
      }
    });
  }

  static void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  static void disconnect() {
    _isExplicitDisconnect = true;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }
    _channel?.sink.close(status.normalClosure);
    _channel = null;
  }
}
