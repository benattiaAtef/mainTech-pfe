import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../components/intervention_detail_dialog.dart';

class TeamInterventionsView extends StatefulWidget {
  const TeamInterventionsView({super.key});

  @override
  State<TeamInterventionsView> createState() => _TeamInterventionsViewState();
}

class _TeamInterventionsViewState extends State<TeamInterventionsView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Intervention> _teamInterventions = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInterventions();
  }

  Future<void> _loadInterventions() async {
    setState(() => _isLoading = true);
    try {
      final chefProfile = await _apiService.getMeChef();
      final groupId = chefProfile?['id_groupe_supervise'];
      
      if (groupId != null) {
        // Fetch all team members to get their IDs
        final members = await _apiService.getGroupMembers(groupId);
        final memberIds = members.map((m) => m['id_technicien']).toSet();
        
        // Fetch all interventions and filter
        final all = await _apiService.getInterventions();
        setState(() {
          _teamInterventions = all.where((i) => memberIds.contains(i.idTechnicien)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading team interventions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teamInterventions.where((i) {
      final tech = '${i.technicien?.prenom ?? ''} ${i.technicien?.nom ?? ''}'.toLowerCase();
      final machine = (i.panne?.machine?.nom ?? '').toLowerCase();
      return tech.contains(_searchQuery.toLowerCase()) || machine.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Suivi des Travaux', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                Text('Toutes les opérations actives et passées de mon équipe', style: TextStyle(color: AppTheme.textGrey)),
              ],
            ),
            const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 32),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Filtrer par technicien ou machine...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator())
              else if (filtered.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48.0), child: Text('Aucune intervention enregistrée pour votre équipe.')))
              else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columnSpacing: 40,
                    columns: const [
                      DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('TECHNICIEN', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('MACHINE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filtered.map((interv) {
                      final statusColor = _getStatusColor(interv.statut);
                      return DataRow(cells: [
                        DataCell(Text(DateFormat('dd/MM HH:mm').format(interv.dateDebut))),
                        DataCell(Text('${interv.technicien?.prenom ?? ''} ${interv.technicien?.nom ?? ''}')),
                        DataCell(Text(interv.panne?.machine?.nom ?? 'N/A')),
                        DataCell(_buildStatusBadge(interv.statut, statusColor)),
                        DataCell(TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => InterventionDetailDialog(
                                intervention: interv,
                                onRefresh: _loadInterventions,
                              ),
                            );
                          }, 
                          child: const Text('Détails', style: TextStyle(fontSize: 12))
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en_cours': return AppTheme.primaryBlue;
      case 'terminee': return AppTheme.successGreen;
      case 'en_attente': return AppTheme.warningOrange;
      default: return AppTheme.textGrey;
    }
  }

}
