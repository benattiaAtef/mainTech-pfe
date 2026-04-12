import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/chat_message.dart';

class ChatService {
  final String baseUrl = ApiService.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<ChatMessage>> getChatHistory(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$groupId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((m) => ChatMessage.fromJson(m)).toList();
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  Future<ChatMessage> sendMessage(int groupId, String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/$groupId'),
      headers: await _getHeaders(),
      body: jsonEncode({'contenu': content}),
    );

    if (response.statusCode == 200) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to send message');
    }
  }
}
