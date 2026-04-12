import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/webrtc_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import 'dart:convert';

class CallScreen extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;
  final bool isIncoming;
  final RTCSessionDescription? initialOffer;
  final WebSocketService wsService;

  const CallScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.isIncoming = false,
    this.initialOffer,
    required this.wsService,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  String _status = "Initialisation...";
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }

  Future<void> _initCall() async {
    // Vérifier d'abord si la permission est définitivement refusée
    final micStatus = await Permission.microphone.status;
    
    if (micStatus.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Permission microphone refusée"),
            content: const Text(
              "La permission microphone est nécessaire pour les appels. "
              "Veuillez l'activer dans les paramètres de l'application.",
            ),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text("Ouvrir les paramètres"),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Demander la permission si pas encore accordée
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permission micro requise pour l'appel")),
          );
          Navigator.pop(context);
        }
        return;
      }
    }

    await _webrtcService.init();
    
    _webrtcService.onIceCandidate = (candidate) {
      widget.wsService.sendSignaling(widget.targetUserId, {
        "type": "candidate",
        "candidate": candidate.toMap(),
      });
    };

    _webrtcService.onConnectionStateChange = (state) {
      if (mounted) {
        setState(() {
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _isConnected = true;
            _status = "En communication";
          } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                     state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                     state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
            Navigator.pop(context);
          }
        });
      }
    };

    _wsSubscription = widget.wsService.stream?.listen((event) async {
      final data = jsonDecode(event.toString());
      if (data['type'] == 'SIGNALING' && data['from_id'] == widget.targetUserId) {
        final signal = data['data'];
        if (signal['type'] == 'answer') {
          await _webrtcService.setRemoteDescription(
            RTCSessionDescription(signal['sdp'], signal['type']),
          );
        } else if (signal['type'] == 'candidate') {
          await _webrtcService.addIceCandidate(
            RTCIceCandidate(
              signal['candidate']['candidate'],
              signal['candidate']['sdpMid'],
              signal['candidate']['sdpMLineIndex'],
            ),
          );
        } else if (signal['type'] == 'hangup') {
          if (mounted) Navigator.pop(context);
        }
      }
    });

    await _webrtcService.openUserMedia();

    if (widget.isIncoming && widget.initialOffer != null) {
      setState(() => _status = "Appel entrant...");
      // For simplified demo, we auto-answer or wait for UI interaction
      // Here we wait for UI interaction "Accepter"
    } else {
      setState(() => _status = "Appel en cours...");
      final offer = await _webrtcService.createOffer();
      widget.wsService.sendSignaling(widget.targetUserId, {
        "type": "offer",
        "sdp": offer.sdp,
      });
    }
  }

  Future<void> _acceptCall() async {
    if (widget.initialOffer != null) {
      final answer = await _webrtcService.createAnswer(widget.initialOffer!);
      widget.wsService.sendSignaling(widget.targetUserId, {
        "type": "answer",
        "sdp": answer.sdp,
      });
      setState(() {
        _status = "Connexion...";
      });
    }
  }

  void _hangUp() {
    widget.wsService.sendSignaling(widget.targetUserId, {"type": "hangup"});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.textDark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
              child: const Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              widget.targetUserName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallAction(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? AppTheme.errorRed.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _webrtcService.toggleMute(_isMuted);
                      });
                    },
                  ),
                  _buildCallAction(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeakerOn ? AppTheme.primaryBlue.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                    onPressed: () {
                      setState(() {
                        _isSpeakerOn = !_isSpeakerOn;
                        _webrtcService.toggleSpeaker(_isSpeakerOn);
                      });
                    },
                  ),
                  if (widget.isIncoming && !_isConnected)
                    _buildCallAction(
                      icon: Icons.call,
                      color: AppTheme.successGreen,
                      onPressed: _acceptCall,
                    ),
                  _buildCallAction(
                    icon: Icons.call_end,
                    color: AppTheme.errorRed,
                    onPressed: _hangUp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallAction({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}
