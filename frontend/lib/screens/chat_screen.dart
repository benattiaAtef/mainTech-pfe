import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final WebSocketService _wsService = WebSocketService();
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  int? _currentUserId;
  String _statutPresence = 'en_travail';
  String? _userRole;
  List<Map<String, dynamic>> _groupMembers = [];
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    _userRole = prefs.getString('user_role');
    
    try {
      final user = await _apiService.getMe();
      setState(() {
        _statutPresence = user.statutPresence;
      });

      // Charger les membres du groupe (incluant le chef)
      final members = await _apiService.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() {
          _groupMembers = members;
        });
      }

      final history = await _chatService.getChatHistory(widget.groupId);
      setState(() {
        _messages = history;
        _isLoading = false;
      });
      _scrollToBottom();
      _initWebSocket();
    } catch (e) {
      debugPrint("Error loading chat: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initWebSocket() async {
    if (_currentUserId != null) {
      await _wsService.connect(_currentUserId!);
      _wsSubscription = _wsService.stream.listen((event) {
        try {
          final data = jsonDecode(event.toString());
          if (data['type'] == 'CHAT_MESSAGE') {
            final msgData = data['data'];
            if (msgData['id_groupe'] == widget.groupId) {
              final newMessage = ChatMessage.fromJson(msgData);
              if (mounted) {
                setState(() {
                  if (!_messages.any((m) => m.id == newMessage.id)) {
                    _messages.add(newMessage);
                  }
                });
                _scrollToBottom();
              }
            }
          } else if (data['type'] == 'SIGNALING') {
            // Gérer l'appel entrant seulement si c'est une 'offer'
            final signal = data['data'];
            if (signal['type'] == 'offer') {
              final fromId = data['from_id'];
              // Idéalement, on cherche le nom de l'expéditeur
              _handleIncomingCall(fromId, signal);
            }
          }
        } catch (e) {
          debugPrint("WS Error: $e");
        }
      });
    }
  }

  void _handleIncomingCall(int fromId, dynamic signal) {
    if (!mounted) return;
    
    // Ignorer les appels entrants si l'utilisateur est hors travail
    if (_statutPresence != 'en_travail') {
      debugPrint("Appel entrant ignoré : utilisateur hors travail");
      return;
    }
    
    // Chercher le nom de l'expéditeur dans les membres
    String callerName = "Membre du groupe";
    final member = _groupMembers.firstWhere(
      (m) => m['id_utilisateur'] == fromId,
      orElse: () => {},
    );
    if (member.isNotEmpty) {
      callerName = "${member['prenom']} ${member['nom']}";
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: fromId,
          targetUserName: callerName,
          isIncoming: true,
          initialOffer: RTCSessionDescription(signal['sdp'], signal['type']),
          wsService: _wsService,
        ),
      ),
    );
  }

  void _startCall(int targetId, String targetName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: targetId,
          targetUserName: targetName,
          wsService: _wsService,
        ),
      ),
    );
  }

  void _initiateCall() {
    // Filtrer seulement les membres en travail (excluant l'utilisateur courant)
    final otherMembers = _groupMembers.where(
      (m) => m['id_utilisateur'] != _currentUserId && m['statut_presence'] == 'en_travail'
    ).toList();
    
    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun autre membre disponible pour un appel")),
      );
      return;
    }

    if (otherMembers.length == 1) {
      final member = otherMembers.first;
      _startCall(member['id_utilisateur'], "${member['prenom']} ${member['nom']} (${member['role']})");
    } else {
      _showCallSelectionDialog(otherMembers);
    }
  }

  void _showCallSelectionDialog(List<Map<String, dynamic>> members) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Appeler un membre"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: member['is_chef'] ? Colors.orange : AppTheme.primaryBlue,
                  child: Icon(member['is_chef'] ? Icons.star : Icons.person, color: Colors.white, size: 20),
                ),
                title: Text("${member['prenom']} ${member['nom']}"),
                subtitle: Text(member['role']),
                trailing: const Icon(Icons.call, color: Colors.green),
                onTap: () {
                  Navigator.pop(context);
                  _startCall(member['id_utilisateur'], "${member['prenom']} ${member['nom']} (${member['role']})");
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      final sentMsg = await _chatService.sendMessage(widget.groupId, text);
      setState(() {
        if (!_messages.any((m) => m.id == sentMsg.id)) {
          _messages.add(sentMsg);
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'envoi: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Chat d'équipe", style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.call,
              color: _statutPresence == 'en_travail' ? Colors.white : Colors.white38,
            ),
            onPressed: _statutPresence == 'en_travail'
                ? _initiateCall
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Appel indisponible : vous êtes hors travail")),
                    );
                  },
            tooltip: _statutPresence == 'en_travail' ? "Appeler" : "Indisponible (hors travail)",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Aucun message", style: TextStyle(color: Colors.grey[500])),
          const Text("Commencez la discussion !", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg.idExpediteur == _currentUserId;
        
        // Date separator logic can be added here
        
        return Column(
          children: [
            _buildMessageBubble(msg, isMe),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final time = DateFormat('HH:mm').format(msg.dateEnvoi);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(msg.displayName, 
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.contenu,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final bool canChat = _statutPresence == 'en_travail';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canChat)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Chat désactivé (Vous êtes hors travail)",
                      style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: canChat ? const Color(0xFFF1F5F9) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    enabled: canChat,
                    decoration: InputDecoration(
                      hintText: canChat ? "Votre message..." : "Indisponible",
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: canChat ? (_) => _sendMessage() : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: canChat ? _sendMessage : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canChat ? AppTheme.primaryBlue : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
