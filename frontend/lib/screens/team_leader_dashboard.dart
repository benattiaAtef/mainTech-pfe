import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import 'machine_detail_screen.dart';
import 'team_screen.dart';
import 'intervention_management_screen.dart';
import 'intervention_details_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'chat_screen.dart';
import 'call_screen.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'login_screen.dart';

class TeamLeaderDashboard extends StatefulWidget {
  const TeamLeaderDashboard({super.key});

  @override
  State<TeamLeaderDashboard> createState() => _TeamLeaderDashboardState();
}

class _TeamLeaderDashboardState extends State<TeamLeaderDashboard> {
  final _apiService = ApiService();
  List<Machine> _allMachines = [];
  List<Machine> _filteredMachines = [];
  late Future<List<Map<String, dynamic>>> _autorisationsFuture;
  late Future<List<Intervention>> _interventionsFuture;
  Map<String, dynamic>? _chefGroupData;
  User? _currentUser;
  bool _isLoadingMachines = true;
  bool _isSearchingMachines = false;
  final _searchController = TextEditingController();
  final _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

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
          if (data['type'] == 'DEMANDE_AUTORISATION') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nouvelle demande d\'autorisation reçue !'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
              _loadData(); // Auto-refresh the list
            }
          } else if (data['type'] == 'SIGNALING') {
            final signal = data['data'];
            if (signal['type'] == 'offer') {
              final fromId = data['from_id'];
              _handleIncomingCall(fromId, signal);
            }
          }
        } catch (e) {
          print('Error parsing WebSocket event: $e');
        }
      });
    }
  }

  void _handleIncomingCall(int fromId, dynamic signal) {
    if (!mounted) return;

    // Bloquer les appels entrants si le chef est hors travail
    final statutPresence = _currentUser?.statutPresence ?? '';
    if (statutPresence != 'en_travail') {
      debugPrint("Appel entrant ignoré : chef hors travail");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          targetUserId: fromId,
          targetUserName: "Membre de l'équipe", 
          isIncoming: true,
          initialOffer: RTCSessionDescription(signal['sdp'], signal['type']),
          wsService: _wsService,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Souhaitez-vous fermer votre session de supervision ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('DÉCONNEXION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Future<void> _updatePresence(String newStatut) async {
    try {
      await _apiService.updatePresence(newStatut);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatut == 'en_travail' ? 'Statut : EN POSTE' : 'Statut : HORS POSTE'),
            backgroundColor: newStatut == 'en_travail' ? Colors.teal : Colors.orange,
          ),
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

  Future<void> _loadData() async {
    setState(() {
      _isLoadingMachines = true;
      _autorisationsFuture = _apiService.getPendingAutorisations();
      _interventionsFuture = _apiService.getInterventions();
    });

    try {
      final user = await _apiService.getMe();
      final machines = await _apiService.getMachines();
      setState(() {
        _currentUser = user;
        _allMachines = machines;
        _applyMachineSearch();
        _isLoadingMachines = false;
      });
      
      final chefData = await _apiService.getMeChef();
      setState(() {
        _chefGroupData = chefData;
      });
    } catch (e) {
      print("Error loading data: $e");
      if (mounted) setState(() => _isLoadingMachines = false);
    }
  }

  void _applyMachineSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMachines = _allMachines.where((m) {
        return m.nom.toLowerCase().contains(query) ||
               m.localisation.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ─── Dialog Ajouter Machine ───────────────────────────────────────────────
  Future<void> _showAddMachineDialog() async {
    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController();
    final qrCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final serieCtrl = TextEditingController();
    final fonctionCtrl = TextEditingController();
    bool isLoading = false;

    // Charger les groupes machines
    List<Map<String, dynamic>> groupes = [];
    int? selectedGroupeId;
    try {
      groupes = await _apiService.getGroupesMachines();
      if (groupes.isNotEmpty) selectedGroupeId = groupes.first['id_groupe_machine'];
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_circle_outline, color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Ajouter une Machine',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Nom
                    _buildField(ctrl: nomCtrl, label: 'Nom de la machine', icon: Icons.settings_suggest_outlined,
                      validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null),
                    const SizedBox(height: 12),

                    // QR Code
                    _buildField(ctrl: qrCtrl, label: 'QR Code (identifiant unique)', icon: Icons.qr_code_outlined,
                      validator: (v) {
                        if (v == null || v.length < 5) return 'Min. 5 caractères';
                        return null;
                      }),
                    const SizedBox(height: 12),

                    // Localisation
                    _buildField(ctrl: locCtrl, label: 'Localisation', icon: Icons.place_outlined),
                    const SizedBox(height: 12),

                    // Numéro de série
                    _buildField(ctrl: serieCtrl, label: 'Numéro de série (optionnel)', icon: Icons.numbers_outlined),
                    const SizedBox(height: 12),

                    // Fonction
                    _buildField(ctrl: fonctionCtrl, label: 'Fonction (optionnel)', icon: Icons.build_outlined),
                    const SizedBox(height: 12),

                    // Groupe Machine (dropdown)
                    if (groupes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aucun groupe machine trouvé. Contactez l\'administrateur.',
                                style: TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: selectedGroupeId,
                        decoration: InputDecoration(
                          labelText: 'Groupe Machine',
                          prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.primaryBlue),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: groupes.map((g) {
                          return DropdownMenuItem<int>(
                            value: g['id_groupe_machine'],
                            child: Text(g['nom_groupe'] ?? 'Groupe ${g['id_groupe_machine']}'),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selectedGroupeId = v),
                        validator: (v) => v == null ? 'Sélectionnez un groupe' : null,
                      ),
                    const SizedBox(height: 20),

                    // Bouton soumettre
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading || (groupes.isNotEmpty && selectedGroupeId == null)
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isLoading = true);
                                try {
                                  await _apiService.createMachine({
                                    'nom': nomCtrl.text.trim(),
                                    'qr_code': qrCtrl.text.trim(),
                                    'id_groupe_machine': selectedGroupeId,
                                    'localisation': locCtrl.text.trim().isEmpty ? 'Non spécifiée' : locCtrl.text.trim(),
                                    if (serieCtrl.text.trim().isNotEmpty) 'num_serie': serieCtrl.text.trim(),
                                    if (fonctionCtrl.text.trim().isNotEmpty) 'fonction': fonctionCtrl.text.trim(),
                                  });
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Machine ajoutée avec succès'),
                                      backgroundColor: AppTheme.successGreen,
                                    ),
                                  );
                                  _loadData();
                                } catch (e) {
                                  setModalState(() => isLoading = false);
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur: $e'),
                                      backgroundColor: AppTheme.errorRed,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Ajouter la machine',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  // ─── Confirmation Supprimer Machine ──────────────────────────────────────
  Future<void> _handleDeleteMachine(Machine machine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la machine'),
        content: Text('Voulez-vous vraiment supprimer la machine « ${machine.nom} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteMachine(machine.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Machine « ${machine.nom} » supprimée'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _handleApprobation(int interventionId, bool approuver) async {
    try {
      await _apiService.approuverAutorisation(interventionId, approuver);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approuver ? 'Intervention exceptionnelle approuvée' : 'Intervention exceptionnelle rejetée'),
          backgroundColor: approuver ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearchingMachines
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un équipement...',
                    hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => _applyMachineSearch(),
                ),
              )
            : const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        centerTitle: false,
        actions: [
          _isSearchingMachines
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _isSearchingMachines = false);
                  _searchController.clear();
                  _applyMachineSearch();
                },
              )
            : IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => setState(() => _isSearchingMachines = true),
              ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.primaryBlue),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text('MaintManager', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryBlue),
              title: const Text('Vue d\'ensemble'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Équipe'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_rounded),
              title: const Text('Interventions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InterventionManagementScreen()));
              },
            ),
            if (_chefGroupData != null)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryBlue),
                title: const Text('Chat de l\'équipe'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        groupId: _chefGroupData!['id_groupe_supervise'],
                        groupName: _chefGroupData!['nom_groupe'] ?? "Équipe",
                      ),
                    ),
                  );
                },
              ),
            const Spacer(),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: AppTheme.textGrey, child: Icon(Icons.person, color: Colors.white)),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chef d\'équipe', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('En ligne', style: TextStyle(fontSize: 12, color: AppTheme.successGreen)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMachineDialog,
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Machine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        tooltip: 'Ajouter une machine',
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Espace Supervision', 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900, 
                    color: Color(0xFF1E293B),
                    letterSpacing: -1.0,
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  _chefGroupData != null ? "Groupe : ${_chefGroupData!['nom_groupe']}" : "Gestion d'équipe & parc machines", 
                  style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSupervisionStatusCard(),
            const SizedBox(height: 32),
            _buildAutorisationsSection(),
            _buildInterventionsSection(),
            const SizedBox(height: 24),
            const Text('Parc Machines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 16),
            _isLoadingMachines
                ? const Center(child: CircularProgressIndicator())
                : _filteredMachines.isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(Icons.settings_suggest_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(_allMachines.isEmpty ? 'Aucune machine dans votre parc' : 'Aucune machine trouvée', style: TextStyle(color: AppTheme.textGrey)),
                            if (_allMachines.isEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _showAddMachineDialog,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Ajouter la première machine'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _filteredMachines.length,
                        itemBuilder: (context, index) {
                          final machine = _filteredMachines[index];
                          return _buildMachineCard(context, machine);
                        },
                      ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMachineCard(BuildContext context, Machine machine) {
    final bool isOperational = machine.statut == 'Opérationnel';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MachineDetailScreen(machine: machine)),
        ).then((_) => _loadData());
      },
      onLongPress: () => _handleDeleteMachine(machine),
      child: Container(
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
        child: Stack(
          children: [
            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOperational ? Colors.teal.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOperational ? Icons.check_circle_outline : Icons.error_outline_rounded,
                        color: isOperational ? Colors.teal : Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      machine.nom,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOperational ? Colors.teal.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        machine.statut.toUpperCase(),
                        style: TextStyle(
                          color: isOperational ? Colors.teal : Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions (top-right corner)
            Positioned(
              top: 8,
              right: 8,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey[400]),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'delete') _handleDeleteMachine(machine);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: AppTheme.errorRed)),
                      ],
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

  Widget _buildAutorisationsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _autorisationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); 
        }

        final autorisations = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security_update_warning_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Autorisations Spéciales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${autorisations.length}', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...autorisations.map((auth) {
              final tech = auth['technicien'];
              final machine = auth['machine'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.2),
                          radius: 18,
                          child: const Icon(Icons.engineering, color: Colors.orange, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tech != null ? "${tech['prenom']} ${tech['nom']}" : "Technicien inconnu",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                'Machine : ${machine != null ? machine['nom'] : "N/A"}',
                                style: TextStyle(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(color: Colors.orange, thickness: 0.1),
                    ),
                    const Text(
                      'Demande d\'affectation exceptionnelle nécessitant votre approbation immédiate.',
                      style: TextStyle(color: Color(0xFF7C2D12), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleApprobation(auth['id_intervention'], false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange[900],
                              side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('REFUSER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleApprobation(auth['id_intervention'], true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('APPROUVER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _handleValider(int panneId) async {
    try {
      await _apiService.validerPanne(panneId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Machine validée et remise en service'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }
  Widget _buildInterventionsSection() {
    return FutureBuilder<List<Intervention>>(
      future: _interventionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Silent loading for this section
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final interventions = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_edu_rounded, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Interventions en attente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final pendingInterventions = interventions.where((i) {
                  final s = i.statut.toLowerCase();
                  return s == 'en_attente' || s == 'acceptee';
                }).toList();
                
                if (pendingInterventions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('Aucune intervention en attente', style: TextStyle(color: AppTheme.textGrey)),
                    ),
                  );
                }

                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingInterventions.length,
                    itemBuilder: (context, index) {
                      final inter = pendingInterventions[index];
                      final isEnCours = inter.statut == 'EN_COURS' || inter.statut == 'ACCEPTEE';
                      
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InterventionDetailsScreen(intervention: inter),
                            ),
                          ).then((_) => _loadData());
                        },
                        child: Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 16, bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: isEnCours ? AppTheme.primaryBlue.withOpacity(0.3) : Colors.transparent),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(inter.statut).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      inter.statut.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(inter.statut),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(inter.dateDebut),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                inter.panne?.machine?.nom ?? 'Machine Inconnue',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 14, color: AppTheme.textGrey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      inter.technicien != null 
                                        ? '${inter.technicien?.prenom} ${inter.technicien?.nom}'
                                        : 'En attente d\'affectation',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Divider(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (inter.panne?.statut == 'a_valider')
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _handleValider(inter.idPanne),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.successGreen,
                                          padding: const EdgeInsets.symmetric(vertical: 0),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Valider Machine', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      inter.typeAffectation == 'urgente' ? '🚨 URGENT' : '🔧 Standard',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.w500,
                                        color: inter.typeAffectation == 'urgente' ? AppTheme.errorRed : AppTheme.textGrey,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textGrey),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSupervisionStatusCard() {
    final bool isInWork = _currentUser?.statutPresence == 'en_travail';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          // Presence Status
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isInWork ? Colors.teal.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isInWork ? Icons.person_pin_circle : Icons.person_pin_circle_outlined,
                    color: isInWork ? Colors.teal : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInWork ? 'EN POSTE' : 'HORS POSTE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isInWork ? Colors.teal : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text('Ma Présence', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
                const Spacer(),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isInWork,
                    activeColor: Colors.teal,
                    inactiveThumbColor: Colors.orange,
                    inactiveTrackColor: Colors.orange.withOpacity(0.2),
                    onChanged: (v) => _updatePresence(v ? 'en_travail' : 'hors_travail'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          Container(height: 40, width: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(width: 16),

          // Logout Button
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en_attente': return Colors.orange;
      case 'acceptee': return Colors.blue;
      case 'en_cours': return AppTheme.primaryBlue;
      case 'terminee': return AppTheme.successGreen;
      default: return AppTheme.textGrey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
