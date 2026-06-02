import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../components/intervention_detail_dialog.dart';

class InterventionManagementView extends StatefulWidget {
  const InterventionManagementView({super.key});

  @override
  State<InterventionManagementView> createState() => _InterventionManagementViewState();
}

class _InterventionManagementViewState extends State<InterventionManagementView> {
  final ApiService _apiService = ApiService();
  List<Intervention> _interventions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'Toutes';

  @override
  void initState() {
    super.initState();
    _fetchInterventions();
  }

  Future<void> _fetchInterventions() async {
    setState(() => _isLoading = true);
    try {
      final interventions = await _apiService.getInterventions();
      setState(() => _interventions = interventions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteIntervention(int id) async {
    try {
      await _apiService.deleteIntervention(id);
      _fetchInterventions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention supprimée')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _interventions.where((i) {
      // Filter by Search Query
      final tech = i.technicien != null ? '${i.technicien!.prenom} ${i.technicien!.nom}' : '';
      final machine = i.panne?.machine?.nom ?? '';
      final id = '#${i.id}';
      final matchesSearch = tech.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          machine.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery);

      if (!matchesSearch) return false;

      // Filter by Status Chip
      if (_selectedStatus == 'Toutes') return true;
      if (_selectedStatus == 'En Cours') {
        return i.statut.toLowerCase() == 'en_cours' || i.statut.toLowerCase() == 'acceptee';
      }
      if (_selectedStatus == 'Terminées') {
        return i.statut.toLowerCase() == 'terminee';
      }
      if (_selectedStatus == 'Urgentes') {
        return i.panne?.priorite == 1;
      }
      return true;
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
                Text(
                  'Suivi des Interventions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Text(
                  'Historique et suivi en temps réel des actions techniques',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              ],
            ),
            const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 32),
        
        // Quick Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Toutes', _selectedStatus == 'Toutes'),
              const SizedBox(width: 8),
              _buildFilterChip('En Cours', _selectedStatus == 'En Cours'),
              const SizedBox(width: 8),
              _buildFilterChip('Terminées', _selectedStatus == 'Terminées'),
              const SizedBox(width: 8),
              _buildFilterChip('Urgentes', _selectedStatus == 'Urgentes'),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
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
                  hintText: 'Filtrer par technicien, machine ou ID...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('ID / DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('TECHNICIEN', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('MACHINE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('DÉTAILS', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filtered.map((interv) {
                      final statusColor = _getStatusColor(interv.statut);
                      return DataRow(
                        onSelectChanged: (_) {
                          showDialog(
                            context: context,
                            builder: (context) => InterventionDetailDialog(
                              intervention: interv,
                              onRefresh: _fetchInterventions,
                            ),
                          );
                        },
                        cells: [
                          DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('#${interv.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(DateFormat('dd/MM HH:mm').format(interv.dateDebut), style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
                            ],
                          )),
                          DataCell(Row(
                            children: [
                              const Icon(Icons.person_pin, size: 16, color: AppTheme.primaryBlue),
                              const SizedBox(width: 8),
                              Text(interv.technicien != null ? '${interv.technicien!.prenom} ${interv.technicien!.nom}' : 'ID: ${interv.idTechnicien}'),
                            ],
                          )),
                          DataCell(Text(interv.panne?.machine?.nom ?? 'Machine non spécifiée')),
                          DataCell(_buildStatusBadge(interv.statut, statusColor)),
                          DataCell(Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => InterventionDetailDialog(
                                      intervention: interv,
                                      onRefresh: _fetchInterventions,
                                    ),
                                  );
                                }, 
                                child: const Text('Voir Rapport', style: TextStyle(fontSize: 12))
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                                onPressed: () => _deleteIntervention(interv.id),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedStatus = label;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryBlue.withOpacity(0.1),
      checkmarkColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryBlue : AppTheme.textDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en_attente': return AppTheme.warningOrange;
      case 'en_cours': return AppTheme.primaryBlue;
      case 'terminee': return AppTheme.successGreen;
      case 'annulee': return AppTheme.errorRed;
      default: return AppTheme.textGrey;
    }
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
