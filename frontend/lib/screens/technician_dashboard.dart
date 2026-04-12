import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'intervention_en_cours_screen.dart';
import 'rapport_intervention_screen.dart';
import 'qr_scanner_screen.dart';
import 'magasin_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'chat_screen.dart';
import 'call_screen.dart';
import 'chatbot_screen.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  final _apiService = ApiService();
  String _userName = "";
  final _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;
  Intervention? _pendingIntervention;
  Intervention? _ongoingIntervention;
  List<Intervention> _historyInterventions = [];
  Technician? _technicien;
  bool _isLoading = true;
  final _webrtcService = WebRTCService();

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId != null) {
      _wsService.connect(userId);
      _wsSubscription = _wsService.stream?.listen((event) {
        try {
          final data = jsonDecode(event.toString());
          if (data['type'] == 'NOUVELLE_AFFECTATION') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nouvelle intervention assignée : ${data['data']['machine_nom']}'),
                  backgroundColor: AppTheme.primaryBlue,
                  duration: const Duration(seconds: 5),
                ),
              );
              _loadData();
            }
          } else if (data['type'] == 'SIGNALING') {
            final signal = data['data'];
            final fromId = data['from_id'];
            if (signal['type'] == 'offer') {
              _handleIncomingCall(fromId, signal);
            } else if (signal['type'] == 'hangup') {
              if (mounted) {
                if (Navigator.canPop(context)) Navigator.pop(context);
                _webrtcService.dispose();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appel terminé'), backgroundColor: AppTheme.textGrey),
                );
              }
            } else if (signal['type'] == 'answer') {
              _webrtcService.setRemoteDescription(
                RTCSessionDescription(signal['sdp'], signal['type']),
              );
            } else if (signal['type'] == 'candidate') {
              _webrtcService.addIceCandidate(
                RTCIceCandidate(
                  signal['candidate']['candidate'],
                  signal['candidate']['sdpMid'],
                  signal['candidate']['sdpMLineIndex'],
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('WS error: $e');
        }
      });
    }
  }

  Future<void> _handleIncomingCall(int fromId, dynamic signal, {bool isConnected = false, RTCSessionDescription? offer}) async {
    if (!mounted) return;

    // Vérifier les permissions
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission micro requise pour l\'appel'), backgroundColor: AppTheme.errorRed),
        );
      }
      return;
    }

    await _webrtcService.init();
    _webrtcService.onIceCandidate = (candidate) {
      _wsService.sendSignaling(fromId, {
        "type": "candidate",
        "candidate": candidate.toMap(),
      });
    };

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
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
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isConnected ? AppTheme.primaryBlue : Colors.green, width: 4),
                        color: Colors.white,
                      ),
                      child: Icon(
                        isConnected ? Icons.person_rounded : Icons.person_rounded, 
                        size: 64, 
                        color: isConnected ? AppTheme.primaryBlue : Colors.green
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isConnected ? 'En communication...' : 'Appel Entrant',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Chef d'équipe",
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 80),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isConnected) ...[
                          // Décrocher
                          GestureDetector(
                            onTap: () async {
                              await _webrtcService.openUserMedia();
                              final offerDesc = RTCSessionDescription(signal['sdp'], signal['type']);
                              final answer = await _webrtcService.createAnswer(offerDesc);
                              _wsService.sendSignaling(fromId, {
                                "type": "answer",
                                "sdp": answer.sdp,
                              });
                              Navigator.of(ctx).pop();
                              // Transition vers l'état connecté
                              _handleIncomingCall(fromId, signal, isConnected: true);
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                  ),
                                  child: const Icon(Icons.call, color: Colors.white, size: 30),
                                ),
                                const SizedBox(height: 10),
                                const Text('Accepter', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 60),
                          // Refuser
                          GestureDetector(
                            onTap: () {
                              _wsService.sendSignaling(fromId, {"type": "hangup"});
                              _webrtcService.dispose();
                              Navigator.of(ctx).pop();
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red[600],
                                  ),
                                  child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                                ),
                                const SizedBox(height: 10),
                                const Text('Refuser', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Raccrocher (état connecté)
                          GestureDetector(
                            onTap: () {
                              _wsService.sendSignaling(fromId, {"type": "hangup"});
                              _webrtcService.dispose();
                              Navigator.of(ctx).pop();
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red[600],
                                  ),
                                  child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                                ),
                                const SizedBox(height: 10),
                                const Text('Raccrocher', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 60),
                          // Muet
                          GestureDetector(
                            onTap: () {
                              setOverlayState(() {
                                isMuted = !isMuted;
                                _webrtcService.toggleMute(isMuted);
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMuted ? Colors.red[400] : Colors.white.withOpacity(0.1),
                                  ),
                                  child: Icon(isMuted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 30),
                                ),
                                const SizedBox(height: 10),
                                Text(isMuted ? 'Activé' : 'Muet', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
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
      transitionBuilder: (ctx, anim1, anim2, child) =>
          FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1, child: child)),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _webrtcService.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SE DÉCONNECTER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _wsService.disconnect();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('user_firstname') ?? "Technicien";
      
      final tech = await _apiService.getMeTechnician();
      
      setState(() {
        _technicien = tech;
        _userName = firstName;
      });

      if (_technicien != null) {
        final interventions = await _apiService.getTechnicianInterventions(_technicien!.id);
        
        // Sort by ID descending to see the newest first
        interventions.sort((a, b) => b.id.compareTo(a.id));

        setState(() {
          _pendingIntervention = interventions.cast<Intervention?>().firstWhere(
            (i) => i!.statut.toLowerCase() == 'en_attente', 
            orElse: () => null
          );
          _ongoingIntervention = interventions.cast<Intervention?>().firstWhere(
            (i) => i!.statut.toLowerCase() == 'acceptee' || i!.statut.toLowerCase() == 'en_cours', 
            orElse: () => null
          );
          _historyInterventions = interventions.where((i) {
            final s = i.statut.toLowerCase();
            return s == 'terminee' || s == 'resolue' || s == 'annulee';
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _accepterIntervention() async {
    if (_pendingIntervention == null) return;
    final id = _pendingIntervention!.id;
    setState(() => _pendingIntervention = null); // Immediate UI feedback
    try {
      await _apiService.accepterIntervention(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention acceptée')),
        );
      }
    } catch (e) {
      await _loadData(); // Resync on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _annulerIntervention(int interventionId) async {
    final interventionToMove = _pendingIntervention?.id == interventionId ? _pendingIntervention : _ongoingIntervention;
    
    setState(() {
      if (_pendingIntervention?.id == interventionId) _pendingIntervention = null;
      if (_ongoingIntervention?.id == interventionId) _ongoingIntervention = null;
      
      if (interventionToMove != null && interventionToMove.id == interventionId) {
        // Optimistic update: move to history locally
        _historyInterventions.insert(0, interventionToMove.copyWith(statut: 'annulee'));
      }
      _currentIndex = 1; // Switch to History tab automatically
    });
    
    try {
      await _apiService.annulerIntervention(interventionId);
      await _loadData(); // Final sync
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention annulée')),
        );
      }
    } catch (e) {
      await _loadData(); // Sync on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _terminerInterventionDirect(int interventionId) async {
    final interventionToMove = _ongoingIntervention;
    setState(() {
      _ongoingIntervention = null;
      if (interventionToMove != null && interventionToMove.id == interventionId) {
        // Optimistic update: move to history locally
        _historyInterventions.insert(0, interventionToMove.copyWith(statut: 'terminee'));
      }
      _currentIndex = 1; // Switch to History tab immediately
    });

    try {
      await _apiService.terminerIntervention(interventionId);
      await _loadData(); // Final sync with server
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention terminée')),
        );
      }
    } catch (e) {
      await _loadData(); // Revert/Sync on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _demarrerIntervention(int interventionId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && result is String) {
      try {
        await _apiService.demarrerIntervention(interventionId, result);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Intervention démarrée (Équipement validé)')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur QR: $e')),
          );
        }
      }
    }
  }

  Future<void> _demanderRenfort() async {
    if (_ongoingIntervention == null) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander du renfort'),
        content: const Text('Souhaitez-vous demander l\'aide d\'un autre technicien pour cette panne ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('DEMANDER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _apiService.requestReinforcement(_ongoingIntervention!.id);
        if (mounted) {
          final statut = result['statut'] ?? 'ok';
          if (statut == 'en_attente') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.hourglass_empty, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Aucun technicien disponible. Le renfort sera assigné automatiquement dès qu\'un technicien sera libre.')),
                ]),
                backgroundColor: const Color(0xFFD97706),
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (statut == 'deja_en_attente') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Une demande de renfort est déjà en attente.'),
                backgroundColor: Color(0xFF6366F1),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Demande de renfort envoyée ! Un technicien a été assigné.'),
                backgroundColor: Color(0xFF059669),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget AppButton({required String text, required VoidCallback onPressed, required IconData icon}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          _buildDashboardTab(),
                          _buildHistoryTab(),
                        ],
                      ),
                    ),
                  ),
                  if (_currentIndex == 0 && _pendingIntervention != null && _ongoingIntervention == null)
                    _buildBottomAction(),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TECHBOT Button
          FloatingActionButton(
            heroTag: 'fab_chatbot',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatbotScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFF0066CC),
            child: const Icon(Icons.smart_toy, color: Colors.white),
          ),
          const SizedBox(height: 12),
          // Team Chat Button
          if (_technicien?.idGroupe != null)
            FloatingActionButton(
              heroTag: 'fab_chat',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      groupId: _technicien!.idGroupe!,
                      groupName: "Mon Équipe",
                    ),
                  ),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingIntervention != null)
            _buildPendingInterventionCard()
          else if (_ongoingIntervention != null) 
            _buildOngoingInterventionCard()
          else
            _buildNoInterventionView(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: _buildHistorySection(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tableau de bord',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gestion des interventions',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 24),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 24),
                  onPressed: _logout,
                  tooltip: 'Déconnexion',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildMemberStatusCard(),
        ],
      ),
    );
  }

  Widget _buildMemberStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPresenceStatusItem()),
          Container(
            height: 40,
            width: 1,
            color: const Color(0xFFF1F5F9),
          ),
          Expanded(child: _buildAvailabilityStatusItem()),
        ],
      ),
    );
  }

  Widget _buildPresenceStatusItem() {
    if (_technicien == null) return const SizedBox();
    final bool isInWork = _technicien!.statutPresence == 'en_travail';
    
    return Column(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: isInWork,
            activeColor: Colors.teal,
            inactiveThumbColor: Colors.orange,
            inactiveTrackColor: Colors.orange.withOpacity(0.2),
            onChanged: (value) => _updatePresence(value ? 'en_travail' : 'hors_travail'),
          ),
        ),
        Text(
          isInWork ? 'EN POSTE' : 'HORS POSTE',
          style: TextStyle(
            fontSize: 10,
            color: isInWork ? Colors.teal : Colors.orange,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        )
      ],
    );
  }

  Widget _buildAvailabilityStatusItem() {
    if (_technicien == null) return const SizedBox();
    final bool isAvailable = _technicien!.statut == 'disponible';
    
    return Column(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: isAvailable,
            activeColor: AppTheme.successGreen,
            inactiveTrackColor: AppTheme.errorRed.withOpacity(0.2),
            onChanged: (value) => _updateStatus(value ? 'disponible' : 'indisponible'),
          ),
        ),
        Text(
          isAvailable ? 'DISPONIBLE' : 'OCCUPÉ',
          style: TextStyle(
            fontSize: 10,
            color: isAvailable ? AppTheme.successGreen : AppTheme.errorRed,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        )
      ],
    );
  }

  Future<void> _updatePresence(String newStatut) async {
    try {
      await _apiService.updatePresence(newStatut);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Présence mise à jour : $newStatut')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_technicien == null) return;
    try {
      await _apiService.updateTechnicianStatut(_technicien!.id, newStatus);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour : $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Widget _buildPendingInterventionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nouvelle Intervention',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Il y a quelques minutes', // Logic for "5 min ago" can be added
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildDetailItem(
            Icons.location_on_outlined, 
            'Emplacement de machine', 
            _pendingIntervention?.panne?.machine?.localisation ?? '(à renseigner)'
          ),
          const SizedBox(height: 16),
          _buildDetailItem(
            Icons.build_outlined, 
            'Type de panne', 
            'Maintenance corrective (N/S)' // Fallback
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUrgentTag(),
            ],
          ),
          const SizedBox(height: 24),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildOngoingInterventionCard() {
    if (_ongoingIntervention == null) return const SizedBox.shrink();

    final startTimeStr = _ongoingIntervention!.dateAcceptation != null
        ? "${_ongoingIntervention!.dateAcceptation!.hour.toString().padLeft(2, '0')}:${_ongoingIntervention!.dateAcceptation!.minute.toString().padLeft(2, '0')}"
        : "--:--";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Intervention en cours",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Actif",
                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoItem(Icons.dns_outlined, "Machine", _ongoingIntervention!.panne?.machine?.nom ?? "N/A"),
          _buildInfoItem(Icons.location_on_outlined, "Localisation", _ongoingIntervention!.panne?.machine?.localisation ?? "N/A"),
          
          const SizedBox(height: 8),
          AppButton(
            text: "Demander du renfort",
            onPressed: _demanderRenfort,
            icon: Icons.group_add,
          ),

          const Divider(height: 32),
          
          // --- Identification Machine (QR Code) ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "IDENTIFICATION MACHINE",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.2),
              ),
              const SizedBox(height: 16),
              if (_ongoingIntervention!.dateScanQr == null)
                GestureDetector(
                  onTap: () => _demarrerIntervention(_ongoingIntervention!.id),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 40, color: AppTheme.primaryBlue),
                        const SizedBox(height: 12),
                        const Text("Scanner le code QR", style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text("Validez l'équipement avant de commencer", 
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successGreen, size: 24),
                    const SizedBox(width: 8),
                    Text("Équipement validé", 
                      style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 32),
          
          // --- Suivi du Temps ---
          const Text(
            "SUIVI DU TEMPS",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.access_time, size: 20, color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      Text(startTimeStr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text("Heure de début", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.timer_outlined, size: 20, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: 12),
                      _buildTimerDisplay(),
                      const Text("Durée écoulée", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: "Accéder au magasin",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MagasinScreen(intervention: _ongoingIntervention!),
                      ),
                    );
                  },
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                  text: "Accéder au rapport",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RapportInterventionScreen(intervention: _ongoingIntervention!),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: Icons.assignment_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    if (_ongoingIntervention?.dateScanQr == null) {
      return const Text("00:00:00", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)));
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final elapsed = DateTime.now().difference(_ongoingIntervention!.dateScanQr!);
        final hours = elapsed.inHours.toString().padLeft(2, '0');
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        
        return Text(
          "$hours:$minutes:$seconds",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
        );
      },
    );
  }

  Widget _buildNoInterventionView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppTheme.primaryBlue.withOpacity(0.5)),
          ),
          const SizedBox(height: 32),
          const Text(
            'Statut opérationnel',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w700, 
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Aucune nouvelle intervention pour le moment. Vous pouvez rester disponible pour de futurs appels.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_historyInterventions.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Aucun historique',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textGrey),
            ),
            const Text(
              "Vos interventions terminées s'afficheront ici.",
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _historyInterventions.length,
      itemBuilder: (context, index) {
        final i = _historyInterventions[index];
        final isAnnulee = i.statut.toLowerCase() == 'annulee';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAnnulee ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAnnulee ? Icons.close : Icons.check,
                  color: isAnnulee ? AppTheme.errorRed : AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Machine: ${i.panne?.machine?.nom ?? 'N/A'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      i.panne?.machine?.localisation ?? 'Aucune localisation',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Le ${i.dateDebut.day}/${i.dateDebut.month}/${i.dateDebut.year}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAnnulee ? AppTheme.errorRed.withOpacity(0.1) : AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAnnulee ? 'Annulée' : 'Terminée',
                  style: TextStyle(
                    color: isAnnulee ? AppTheme.errorRed : AppTheme.successGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrgentTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Urgent',
        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _accepterIntervention,
          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          label: const Text(
            'Accepter',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
