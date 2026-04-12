import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class TeamChatView extends StatefulWidget {
  const TeamChatView({super.key});

  @override
  State<TeamChatView> createState() => _TeamChatViewState();
}

class _TeamChatViewState extends State<TeamChatView> {
  final ChatService _chatService = ChatService();
  final WebSocketService _wsService = WebSocketService();
  final ApiService _apiService = ApiService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final WebRTCService _webrtcService = WebRTCService();

  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  int? _currentUserId;
  int? _groupId;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _webrtcService.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');

    try {
      final chefProfile = await _apiService.getMeChef();
      _groupId = chefProfile?['id_groupe_supervise'];

      if (_groupId != null) {
        final results = await Future.wait([
          _chatService.getChatHistory(_groupId!),
          _apiService.getGroupMembers(_groupId!),
        ]);

        setState(() {
          _messages = results[0] as List<ChatMessage>;
          _members = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });

        _scrollToBottom();
        _setupWebSocket();
      }
    } catch (e) {
      debugPrint('Error init chat: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupWebSocket() {
    if (_currentUserId != null) {
      _wsService.connect(_currentUserId!);
      _wsSubscription = _wsService.stream.listen((event) {
        try {
          final data = jsonDecode(event.toString());
          if (data['type'] == 'CHAT_MESSAGE') {
            final msgData = data['data'];
            if (msgData['id_groupe'] == _groupId) {
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
            _handleIncomingCallSignal(data);
          }
        } catch (e) {
          debugPrint('WS Chat Error: $e');
        }
      });
    }
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

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _groupId == null) return;

    _msgController.clear();
    try {
      final sent = await _chatService.sendMessage(_groupId!, text);
      setState(() {
        if (!_messages.any((m) => m.id == sent.id)) {
          _messages.add(sent);
        }
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending: $e');
    }
  }

  void _handleIncomingCallSignal(Map<String, dynamic> signalData) {
    // Structure: { "type": "SIGNALING", "from_id": id, "data": { "type": "offer"/"hangup"/"answer" } }
    final fromId = signalData['from_id'];
    final payload = signalData['data'];
    final type = payload['type'];
    
    if (type == 'offer') {
      // Rechercher le nom de l'appelant dans les membres
      final member = _members.firstWhere((m) => m['id_utilisateur'] == fromId, orElse: () => {});
      _showCallOverlay({
        'id_utilisateur': fromId,
        'prenom': member['prenom'] ?? 'Membre',
        'nom': member['nom'] ?? 'Équipe',
      }, isIncoming: true, offer: RTCSessionDescription(payload['sdp'], payload['type']));
    } else if (type == 'hangup') {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _webrtcService.dispose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Appel terminé'), backgroundColor: AppTheme.textGrey),
        );
      }
    } else if (type == 'answer') {
      _webrtcService.setRemoteDescription(
        RTCSessionDescription(payload['sdp'], payload['type']),
      );
    } else if (type == 'candidate') {
      _webrtcService.addIceCandidate(
        RTCIceCandidate(
          payload['candidate']['candidate'],
          payload['candidate']['sdpMid'],
          payload['candidate']['sdpMLineIndex'],
        ),
      );
    }
  }

  Future<void> _showCallOverlay(Map<String, dynamic> member, {bool isVideo = false, bool isIncoming = false, RTCSessionDescription? offer}) async {
    // Vérifier les permissions
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Permission micro requise pour l\'appel'), backgroundColor: AppTheme.errorRed),
        );
      }
      return;
    }

    await _webrtcService.init();
    _webrtcService.onIceCandidate = (candidate) {
      _wsService.sendSignaling(member['id_utilisateur'], {
        "type": "candidate",
        "candidate": candidate.toMap(),
      });
    };

    if (!isIncoming) {
      await _webrtcService.openUserMedia();
      final offer = await _webrtcService.createOffer();
      _wsService.sendSignaling(member['id_utilisateur'], {
        "type": "offer",
        "sdp": offer.sdp,
        "isVideo": isVideo,
      });
    }

    if (!mounted) return;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        bool isMuted = false;
        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isVideo ? AppTheme.primaryBlue : AppTheme.successGreen, width: 4),
                        color: Colors.white,
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.person_rounded, 
                        size: 80, 
                        color: isVideo ? AppTheme.primaryBlue : AppTheme.successGreen
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '${member['prenom']} ${member['nom']}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIncoming 
                        ? (isVideo ? 'Appel vidéo entrant...' : 'Appel vocal entrant...')
                        : (isVideo ? 'Appel vidéo en cours...' : 'Appel vocal en cours...'),
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 100),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isIncoming) ...[
                          _buildCallAction(
                            Icons.call_rounded, 
                            'Accepter', 
                            color: AppTheme.successGreen, 
                            onTap: () async {
                              await _webrtcService.openUserMedia();
                              final answer = await _webrtcService.createAnswer(offer!);
                              _wsService.sendSignaling(member['id_utilisateur'], {
                                "type": "answer",
                                "sdp": answer.sdp,
                              });
                              Navigator.pop(context);
                              // Re-show overlay in active call mode
                              _showCallOverlay(member, isVideo: isVideo, isIncoming: false);
                            }
                          ),
                          const SizedBox(width: 40),
                          _buildCallAction(
                            Icons.call_end_rounded, 
                            'Refuser', 
                            color: AppTheme.errorRed, 
                            onTap: () {
                              _wsService.sendSignaling(member['id_utilisateur'], {"type": "hangup"});
                              _webrtcService.dispose();
                              Navigator.pop(context);
                            }
                          ),
                        ] else ...[
                          _buildCallAction(
                            isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, 
                            isMuted ? 'Activé' : 'Muet',
                            color: isMuted ? AppTheme.errorRed : null,
                            onTap: () {
                              setOverlayState(() {
                                isMuted = !isMuted;
                                _webrtcService.toggleMute(isMuted);
                              });
                            }
                          ),
                          const SizedBox(width: 40),
                          _buildCallAction(
                            Icons.call_end_rounded, 
                            'Raccrocher', 
                            color: AppTheme.errorRed, 
                            onTap: () {
                              _wsService.sendSignaling(member['id_utilisateur'], {"type": "hangup"});
                              _webrtcService.dispose();
                              Navigator.pop(context);
                            }
                          ),
                          const SizedBox(width: 40),
                          _buildCallAction(Icons.volume_up_rounded, 'Haut-parleur'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1, child: child));
      },
    );
  }

  Widget _buildCallAction(IconData icon, String label, {Color? color, VoidCallback? onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? Colors.white.withOpacity(0.15),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      height: MediaQuery.of(context).size.height - 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Row(
        children: [
          // Chat Section
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildChatHeader(),
                Expanded(child: _buildMessageList()),
                _buildInputArea(),
              ],
            ),
          ),
          // Members Section
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            flex: 1,
            child: _buildMembersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          const Text('Discussion d\'Équipe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showCallOverlay({'prenom': 'Toute', 'nom': 'l\'équipe', 'role': 'Conférence Groupée'}),
            icon: const Icon(Icons.groups_rounded, size: 20),
            label: const Text('Appel Groupe'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Text('${_messages.length} messages échangés', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg.idExpediteur == _currentUserId;
        return _buildMessageBubble(msg, isMe);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(msg.displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textGrey)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.contenu, style: TextStyle(color: isMe ? Colors.white : AppTheme.textDark, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(msg.dateEnvoi),
                    style: TextStyle(color: isMe ? Colors.white70 : AppTheme.textGrey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Écrivez votre message ici...',
                fillColor: const Color(0xFFF8FAFC),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 16),
          IconButton.filled(
            onPressed: _send,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primaryBlue, padding: const EdgeInsets.all(16)),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Membres (En ligne)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final m = _members[index];
              final isOnline = m['statut_presence'] == 'en_travail';
              return ListTile(
                leading: Badge(
                  backgroundColor: isOnline ? AppTheme.successGreen : Colors.grey,
                  smallSize: 10,
                  child: const CircleAvatar(radius: 16, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 16, color: AppTheme.textGrey)),
                ),
                title: Text('${m['prenom']} ${m['nom']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(m['role'] ?? 'Technicien', style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.phone_rounded, size: 18, color: AppTheme.textGrey),
                  onPressed: () => _showCallOverlay(m),
                  hoverColor: AppTheme.successGreen.withOpacity(0.1),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
