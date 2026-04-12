import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int? _currentUserId;

  // StreamController broadcast pour permettre plusieurs listeners (chat + appels)
  final StreamController<dynamic> _controller = StreamController.broadcast();

  Stream<dynamic> get stream => _controller.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(int userId) async {
    if (_isConnected && _currentUserId == userId) return;

    // Déconnecter l'ancienne connexion si elle existe
    if (_isConnected) {
      disconnect();
    }

    _currentUserId = userId;

    // Récupérer le vrai token JWT depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final wsBaseUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final url = '$wsBaseUrl/pannes/ws/$userId?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      print('[WS] Connecté: $url');

      // Écouter et redistribuer tous les messages dans le StreamController
      _channel!.stream.listen(
        (data) {
          _controller.add(data);
        },
        onError: (error) {
          print('[WS] Erreur: $error');
          _isConnected = false;
        },
        onDone: () {
          print('[WS] Connexion fermée');
          _isConnected = false;
        },
      );
    } catch (e) {
      print('[WS] Erreur de connexion: $e');
      _isConnected = false;
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _currentUserId = null;
  }

  void send(String message) {
    if (!_isConnected) {
      print('[WS] Impossible d\'envoyer: non connecté');
      return;
    }
    _channel?.sink.add(message);
  }

  void sendSignaling(int targetId, Map<String, dynamic> data) {
    if (!_isConnected) {
      print('[WS] Signal ignoré: non connecté');
      return;
    }
    final payload = {
      "type": "SIGNALING",
      "target_id": targetId,
      "data": data,
    };
    _channel?.sink.add(jsonEncode(payload));
    print('[WS] Signal envoyé à $targetId: ${data['type']}');
  }

  void sendCallInvite(int targetId, String callerName) {
    if (!_isConnected) return;
    final payload = {
      "type": "CALL_INVITE",
      "target_id": targetId,
      "data": {
        "caller_name": callerName,
        "caller_id": _currentUserId,
      },
    };
    _channel?.sink.add(jsonEncode(payload));
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
