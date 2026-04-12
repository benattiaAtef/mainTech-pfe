import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';
import '../components/intervention_detail_dialog.dart';

class ChefDashboardView extends StatefulWidget {
  final Function(int)? onNavigate;
  const ChefDashboardView({super.key, this.onNavigate});

  @override
  State<ChefDashboardView> createState() => _ChefDashboardViewState();
}

class _ChefDashboardViewState extends State<ChefDashboardView> {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  bool _isLoading = true;
  bool _isSearchingMachines = false;
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? _chefProfile;
  User? _currentUser;

  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _pendingAuthorizations = [];
  List<Intervention> _allInterventions = [];
  int _activeInterventionsCount = 0;

  List<Machine> _allMachines = [];
  List<Machine> _filteredMachines = [];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _initWebSocket();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading) {
        _loadDashboardData(isBackground: true);
      }
    });
  }

  Future<void> _initWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId != null) {
      _wsService.connect(userId);
      _wsSubscription = _wsService.stream.listen((event) {
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
              _loadDashboardData(); // Auto-refresh the list
            }
          }
        } catch (e) {
          debugPrint('Error parsing WebSocket event: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _searchController.dispose();
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
      await _loadDashboardData();
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

  Future<void> _loadDashboardData({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoading = true);
    try {
      final user = await _apiService.getMe();
      final machines = await _apiService.getMachines();
      _currentUser = user;
      _allMachines = machines;

      _chefProfile = await _apiService.getMeChef();
      _applyMachineSearch(); 

      final groupId = _chefProfile?['id_groupe_supervise'];

      if (groupId != null) {
        final results = await Future.wait([
          _apiService.getGroupMembers(groupId),
          _apiService.getInterventions(),
          _apiService.getPendingAutorisations(),
        ]);

        _teamMembers = (results[0] as List<Map<String, dynamic>>)
            .where((m) => m['is_chef'] == false)
            .toList();
        _allInterventions = results[1] as List<Intervention>;
        _pendingAuthorizations = results[2] as List<Map<String, dynamic>>;
        
        final memberIds = _teamMembers.map((m) => m['id_technicien']).toSet();
        _activeInterventionsCount = _allInterventions.where((i) => 
          memberIds.contains(i.idTechnicien) && i.statut.toLowerCase() == 'en_cours'
        ).length;
      }
    } catch (e) {
      debugPrint('Error loading chef dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyMachineSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMachines = _allMachines.where((m) {
        final groupId = _chefProfile?['id_groupe_supervise'];
        if (groupId != null && m.idGroupe != groupId) return false;

        return m.nom.toLowerCase().contains(query) ||
               m.localisation.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _processAuthorization(int interventionId, bool approve) async {
    try {
      await _apiService.approuverAutorisation(interventionId, approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Intervention exceptionnelle approuvée' : 'Intervention exceptionnelle rejetée'),
            backgroundColor: approve ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Future<void> _handleValider(int panneId) async {
    try {
      await _apiService.validerPanne(panneId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Machine validée et remise en service'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final technicians = _teamMembers.where((m) => m['is_chef'] == false || m['role']?.toString().contains('Technicien') == true).toList();
    final availableCount = technicians.where((m) {
      final status = (m['statut'] ?? m['statut_presence'] ?? 'indisponible').toString().toLowerCase();
      return status == 'disponible' || status == 'en_travail';
    }).length;
    final nomGr = _chefProfile?['nom_groupe'] ?? _chefProfile?['groupe_nom'] ?? 'Équipe';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSupervisionStatusCard(),
          const SizedBox(height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bonjour, Chef ${_chefProfile?['utilisateur']?['prenom'] ?? ''}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              ElevatedButton.icon(
                onPressed: () => _loadDashboardData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualiser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          Text(
            'Supervision du groupe : $nomGr',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Cards
          Row(
            children: [
              Expanded(
                child: _buildSimpleStatCard(
                  'Techniciens',
                  technicians.length.toString(),
                  FontAwesomeIcons.users,
                  AppTheme.primaryBlue,
                  onTap: () => widget.onNavigate?.call(1),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSimpleStatCard(
                  'Disponibles',
                  availableCount.toString(),
                  FontAwesomeIcons.checkCircle,
                  AppTheme.successGreen,
                  onTap: () => widget.onNavigate?.call(1),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSimpleStatCard(
                  'En Intervention',
                  _activeInterventionsCount.toString(),
                  FontAwesomeIcons.tools,
                  AppTheme.warningOrange,
                  onTap: () => widget.onNavigate?.call(3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Autorisations Spéciales
          _buildAutorisationsSection(),

          // Interventions en Attente / A Valider
          _buildInterventionsSection(),

          const SizedBox(height: 20),

          // Parc Machines
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parc Machines du Groupe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_isSearchingMachines)
                    Container(
                      width: 250,
                      height: 40,
                      margin: const EdgeInsets.only(right: 16),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un équipement...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() => _isSearchingMachines = false);
                              _searchController.clear();
                              _applyMachineSearch();
                            },
                          ),
                        ),
                        onChanged: (_) => _applyMachineSearch(),
                      ),
                    )
                  else
                    IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => setState(() => _isSearchingMachines = true),
                    ),
                  ElevatedButton.icon(
                    onPressed: _showAddMachineDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouvelle Machine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMachinesGrid(),
          
          const SizedBox(height: 40),
        ],
      ),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isInWork ? Colors.teal : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text('Ma Présence', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(width: 16),
                Switch(
                  value: isInWork,
                  activeColor: Colors.teal,
                  inactiveThumbColor: Colors.orange,
                  inactiveTrackColor: Colors.orange.withOpacity(0.2),
                  onChanged: (v) => _updatePresence(v ? 'en_travail' : 'hors_travail'),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          Container(height: 40, width: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(width: 16),

          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
            label: const Text('Déconnexion'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 20),
              Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(Map<String, dynamic> member) {
    final status = member['statut'] ?? 'inconnu';
    final name = '${member['utilisateur']?['prenom'] ?? ''} ${member['utilisateur']?['nom'] ?? ''}';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const CircleAvatar(radius: 20, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 20, color: AppTheme.textGrey)),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
          _buildStatusTag(status),
        ],
      ),
    );
  }

  Widget _buildAutorisationsSection() {
    if (_pendingAuthorizations.isEmpty) {
      return const SizedBox.shrink(); 
    }

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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_pendingAuthorizations.length}', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._pendingAuthorizations.map((auth) {
          final tech = auth['technicien'];
          final machine = auth['panne']?['machine'] ?? auth['machine'];
          final machineName = machine != null ? machine['nom'] : "N/A";
          final techName = tech != null ? "${tech['prenom']} ${tech['nom']}" : "Technicien inconnu";

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  radius: 20,
                  child: const Icon(Icons.engineering, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        techName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Machine : $machineName | Motif : Autorisation Chef requise',
                        style: TextStyle(color: Colors.orange[800], fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => _processAuthorization(auth['id_intervention'], false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[900],
                    side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                  child: const Text('REFUSER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _processAuthorization(auth['id_intervention'], true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  ),
                  child: const Text('APPROUVER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 32),
      ],
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

  Widget _buildInterventionsSection() {
    final pendingInterventions = _allInterventions.where((i) {
      final s = i.statut.toLowerCase();
      return s == 'en_attente' || s == 'acceptee';
    }).toList();
    
    if (pendingInterventions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_edu_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text(
              'Interventions en attente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pendingInterventions.length,
            itemBuilder: (context, index) {
              final inter = pendingInterventions[index];
              final isEnCours = inter.statut == 'EN_COURS' || inter.statut == 'ACCEPTEE';
              
              return InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => InterventionDetailDialog(
                      intervention: inter,
                      onRefresh: _loadDashboardData,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 300,
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(inter.dateDebut),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        inter.panne?.machine?.nom ?? 'Machine Inconnue',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: AppTheme.textGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              inter.technicien != null 
                                ? '${inter.technicien?.prenom} ${inter.technicien?.nom}'
                                : 'En attente d\'affectation',
                              style: const TextStyle(fontSize: 14, color: AppTheme.textGrey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Divider(height: 16),
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
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Valider Machine', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else ...[
                            Text(
                              inter.typeAffectation == 'urgente' ? '🚨 URGENT' : '🔧 Standard',
                              style: TextStyle(
                                fontSize: 13, 
                                fontWeight: FontWeight.w500,
                                color: inter.typeAffectation == 'urgente' ? AppTheme.errorRed : AppTheme.textGrey,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textGrey),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMachinesGrid() {
    if (_filteredMachines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text('Aucune machine trouvée pour ce groupe')),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 2.5,
      ),
      itemCount: _filteredMachines.length,
      itemBuilder: (context, index) => _buildMachineCard(_filteredMachines[index]),
    );
  }

  Widget _buildMachineCard(Machine m) {
    final isOperational = m.statut == 'Opérationnel';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isOperational ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOperational ? Icons.check_circle_outline : Icons.error_outline,
              color: isOperational ? AppTheme.successGreen : AppTheme.errorRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(m.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(m.localisation, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey[400]),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) async {
              if (val == 'delete') {
                await _apiService.deleteMachine(m.id);
                _loadDashboardData();
              }
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
        ],
      ),
    );
  }

  void _showAddMachineDialog() {
    final nameCtrl = TextEditingController();
    final qrCtrl = TextEditingController();
    final locCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle Machine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de la machine')),
            TextField(controller: qrCtrl, decoration: const InputDecoration(labelText: 'Identifiant QR Code')),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Localisation/Poste')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final groupId = _chefProfile?['id_groupe_supervise'];
              await _apiService.createMachine({
                'nom': nameCtrl.text,
                'qr_code': qrCtrl.text,
                'localisation': locCtrl.text.isEmpty ? 'Non renseignée' : locCtrl.text,
                'id_groupe_machine': groupId,
              });
              if (mounted) {
                Navigator.pop(context);
                _loadDashboardData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('AJOUTER'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    Color color;
    switch (status) {
      case 'disponible': color = AppTheme.successGreen; break;
      case 'en_intervention': color = AppTheme.warningOrange; break;
      case 'occupe': color = AppTheme.errorRed; break;
      default: color = AppTheme.textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
