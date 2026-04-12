import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeamManagementView extends StatefulWidget {
  const TeamManagementView({super.key});

  @override
  State<TeamManagementView> createState() => _TeamManagementViewState();
}

class _TeamManagementViewState extends State<TeamManagementView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _teamMembers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    try {
      final chefProfile = await _apiService.getMeChef();
      final groupId = chefProfile?['id_groupe_supervise'];
      if (groupId != null) {
        _teamMembers = await _apiService.getGroupMembers(groupId);
      }
    } catch (e) {
      debugPrint('Error loading team: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teamMembers.where((m) {
      if (m['is_chef'] == true) return false; // Exclude Team Leader
      final firstName = m['prenom'] ?? m['utilisateur']?['prenom'] ?? '';
      final lastName = m['nom'] ?? m['utilisateur']?['nom'] ?? '';
      final name = '$firstName $lastName'.toLowerCase();
      final matricule = (m['matricule'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || matricule.contains(_searchQuery.toLowerCase());
    }).toList();

    // Summary calculations
    int totalInterventions = 0;
    int totalTime = 0;
    int occupiedCount = 0;
    final onlyTechs = _teamMembers.where((m) => m['is_chef'] == false).toList();
    
    for (var m in onlyTechs) {
      totalInterventions += (m['interventions_count_today'] as num? ?? 0).toInt();
      totalTime += (m['total_time_today_minutes'] as num? ?? 0).toInt();
      final statut = (m['statut'] ?? '').toString().toLowerCase();
      if (statut == 'en_intervention' || statut == 'occupe') occupiedCount++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Text('Gestion des effectifs et planning du groupe', style: TextStyle(color: AppTheme.textGrey)),
          const SizedBox(height: 32),
          _buildTeamSummary(totalInterventions, totalTime, occupiedCount, onlyTechs.length),
          const SizedBox(height: 16),
          _buildChatButton(),
          const SizedBox(height: 32),
          const Text('Liste des Techniciens', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            _buildEmptyState()
          else
            _buildTechniciansGrid(filtered),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Équipe Technique', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        ElevatedButton.icon(
          onPressed: _loadTeam,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Actualiser'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSummary(int interventions, int time, int occupied, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                'Résumé de l\'Équipe',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Aujourd\'hui', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat(Icons.handyman_outlined, interventions.toString(), 'Interventions'),
              _buildSummaryStat(Icons.timer_outlined, '${time}m', 'Temps Total'),
              _buildSummaryStat(Icons.people_outline, '$occupied/$total', 'Occupés'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 26),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
      ],
    );
  }

  Widget _buildChatButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
        label: const Text('Ouvrir le chat d\'équipe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom ou matricule...',
          hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTechniciansGrid(List<Map<String, dynamic>> technicians) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 320,
      ),
      itemCount: technicians.length,
      itemBuilder: (context, index) => _buildTechnicianCard(technicians[index]),
    );
  }

  Widget _buildTechnicianCard(Map<String, dynamic> tech) {
    final firstName = tech['prenom'] ?? tech['utilisateur']?['prenom'] ?? '';
    final lastName = tech['nom'] ?? tech['utilisateur']?['nom'] ?? '';
    final status = tech['statut'] ?? tech['statut_presence'] ?? 'indisponible';
    
    final isAvailable = status == 'disponible' || status == 'en_travail';
    final isInIntervention = status == 'en_intervention';
    final totalTime = (tech['total_time_today_minutes'] as num? ?? 0).toDouble();
    double occupationProgress = totalTime / 480.0; // 8h shift
    if (occupationProgress > 1.0) occupationProgress = 1.0;
    
    Color statusColor = AppTheme.successGreen;
    if (isInIntervention || status == 'occupe') statusColor = AppTheme.errorRed; 
    if (status == 'hors_travail' || status == 'indisponible') statusColor = Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showTechnicianDetails(tech),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.secondaryBlue.withOpacity(0.2),
                    child: const Icon(Icons.person, size: 40, color: AppTheme.primaryBlue),
                  ),
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '$firstName $lastName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_history, size: 12, color: isAvailable || isInIntervention ? Colors.teal : Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    isAvailable || isInIntervention ? 'AU TRAVAIL' : 'HORS TRAVAIL',
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold, 
                      color: isAvailable || isInIntervention ? Colors.teal : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: occupationProgress,
                  child: Container(decoration: BoxDecoration(color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(2))),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat(Icons.handyman, tech['interventions_count_today']?.toString() ?? '0'),
                  _buildMiniStat(Icons.timer, '${tech['total_time_today_minutes'] ?? 0}m'),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconButton(Icons.email_outlined),
                  _buildIconButton(Icons.phone_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTechnicianDetails(Map<String, dynamic> tech) {
    final firstName = tech['prenom'] ?? tech['utilisateur']?['prenom'] ?? '';
    final lastName = tech['nom'] ?? tech['utilisateur']?['nom'] ?? '';
    final status = tech['statut'] ?? tech['statut_presence'] ?? 'indisponible';
    final isFree = status == 'disponible' || status == 'en_travail';
    final intTime = (tech['total_time_today_minutes'] as num? ?? 0).toInt();
    final intCount = (tech['interventions_count_today'] as num? ?? 0).toInt();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
          width: 500,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 45,
                  backgroundColor: AppTheme.secondaryBlue.withOpacity(0.2),
                  child: const Icon(Icons.person, size: 55, color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 20),
                Text(
                  '$firstName $lastName',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const Text(
                  'Technicien de Maintenance',
                  style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 32),
                _buildDetailInfoRow(Icons.email_outlined, 'Email', tech['email'] ?? tech['utilisateur']?['email'] ?? 'Non renseigné'),
                _buildDetailInfoRow(Icons.badge_outlined, 'Matricule', tech['matricule'] ?? 'Non assigné'),
                _buildDetailInfoRow(Icons.work_outline, 'Groupe', tech['id_groupe'] != null ? 'Groupe ${tech['id_groupe']}' : 'Non assigné'),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (isFree ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isFree ? 'Libre' : 'Occupé',
                              style: TextStyle(
                                color: isFree ? AppTheme.successGreen : AppTheme.errorRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Text('Statut Actuel', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${intTime} min',
                              style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text('$intCount int. auj.', style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final newStatus = isFree ? 'occupe' : 'disponible';
                      try {
                        await _apiService.updateTechnicianStatut(tech['id'], newStatus);
                        if (context.mounted) Navigator.pop(context);
                        _loadTeam();
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                      }
                    },
                    icon: Icon(isFree ? Icons.block_flipped : Icons.check_circle_outline, color: Colors.white),
                    label: Text(isFree ? 'Mettre Indisponible' : 'Mettre Disponible', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFree ? AppTheme.errorRed : AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to history
                    },
                    icon: const Icon(Icons.history, color: Colors.white),
                    label: const Text('Historique des interventions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleDeleteTechnician(tech),
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white),
                        label: const Text('Retirer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }

  Widget _buildDetailInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteTechnician(Map<String, dynamic> tech) async {
    final user = tech['utilisateur'];
    final name = '${user?['prenom'] ?? ''} ${user?['nom'] ?? ''}';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le retrait'),
        content: Text('Voulez-vous vraiment retirer $name de votre équipe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteTechnician(tech['id']);
        if (mounted) {
          Navigator.pop(context); // Close details dialog
          _loadTeam();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technicien retiré avec succès')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textGrey),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      ],
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: AppTheme.primaryBlue),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.people_outline, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('Aucun technicien trouvé.', style: TextStyle(color: AppTheme.textGrey)),
        ],
      ),
    );
  }
}


