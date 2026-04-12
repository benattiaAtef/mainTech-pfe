import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int? _currentUserId;

  final StreamController<dynamic> _controller = StreamController.broadcast();

  Stream<dynamic> get stream => _controller.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(int userId) async {
    if (_isConnected && _currentUserId == userId) return;

    if (_isConnected) {
      disconnect();
    }

    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final wsBaseUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final url = '$wsBaseUrl/pannes/ws/$userId?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      print('[WS Desktop] Connecté: $url');

      _channel!.stream.listen(
        (data) {
          _controller.add(data);
        },
        onError: (error) {
          print('[WS Desktop] Erreur: $error');
          _isConnected = false;
        },
        onDone: () {
          print('[WS Desktop] Connexion fermée');
          _isConnected = false;
        },
      );
    } catch (e) {
      print('[WS Desktop] Erreur de connexion: $e');
      _isConnected = false;
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _currentUserId = null;
  }

  void send(String message) {
    if (!_isConnected) return;
    _channel?.sink.add(message);
  }

  void sendSignaling(int targetId, Map<String, dynamic> data) {
    if (!_isConnected) return;
    final payload = {
      "type": "SIGNALING",
      "target_id": targetId,
      "data": data,
    };
    _channel?.sink.add(jsonEncode(payload));
    print('[WS Desktop] Signal envoyé à $targetId: ${data['type']}');
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
