import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PanneManagementView extends StatefulWidget {
  const PanneManagementView({super.key});

  @override
  State<PanneManagementView> createState() => _PanneManagementViewState();
}

class _PanneManagementViewState extends State<PanneManagementView> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _pannes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPannes();
  }

  Future<void> _fetchPannes() async {
    setState(() => _isLoading = true);
    try {
      final pannes = await _apiService.getPannes();
      setState(() => _pannes = pannes);
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

  @override
  Widget build(BuildContext context) {
    final filtered = _pannes.where((p) {
      final id = '#${p['id_panne']}';
      final machineId = 'Machine #${p['id_machine']}';
      return id.contains(_searchQuery) || machineId.toLowerCase().contains(_searchQuery.toLowerCase());
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
                  'Signalements de Pannes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Text(
                  'Alertes actives et pannes signalées par le personnel',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _fetchPannes,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
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
                  hintText: 'Rechercher par ID de panne ou machine...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator())
              else if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Text('Aucune panne signalée pour le moment.', style: TextStyle(color: AppTheme.textGrey)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('ID PANNE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('MACHINE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('PRIORITÉ', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filtered.map((panne) {
                      final priority = panne['priorite'] ?? 1;
                      return DataRow(cells: [
                        DataCell(Text('#${panne['id_panne']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('Machine #${panne['id_machine']}')),
                        DataCell(_buildPriorityBadge(priority)),
                        DataCell(Text(panne['statut'] ?? 'Inconnu', style: const TextStyle(fontSize: 13))),
                        DataCell(Row(
                          children: [
                            TextButton(onPressed: () {}, child: const Text('Assigner', style: TextStyle(fontSize: 12))),
                            IconButton(icon: const Icon(Icons.info_outline, size: 18), onPressed: () {}),
                          ],
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

  Widget _buildPriorityBadge(int priority) {
    String label;
    Color color;
    switch (priority) {
      case 5:
        label = 'Critique';
        color = AppTheme.errorRed;
        break;
      case 4:
        label = 'Haute';
        color = Colors.orange;
        break;
      case 3:
        label = 'Moyenne';
        color = Colors.blue;
        break;
      default:
        label = 'Basse';
        color = AppTheme.successGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
