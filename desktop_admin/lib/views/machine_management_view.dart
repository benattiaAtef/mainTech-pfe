import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class MachineManagementView extends StatefulWidget {
  const MachineManagementView({super.key});

  @override
  State<MachineManagementView> createState() => _MachineManagementViewState();
}

class _MachineManagementViewState extends State<MachineManagementView> {
  final ApiService _apiService = ApiService();
  List<Machine> _machines = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    try {
      final machines = await _apiService.getMachines();
      setState(() => _machines = machines);
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

  Future<void> _deleteMachine(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la machine'),
        content: const Text('Êtes-vous sûr de vouloir retirer cette machine du parc ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteMachine(id);
        _fetchMachines();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed));
        }
      }
    }
  }

  Future<void> _showAddMachineDialog() async {
    final List<Map<String, dynamic>> groups = await _apiService.getGroupesMachines();
    int? selectedGroupId;
    final nameController = TextEditingController();
    final serialController = TextEditingController();
    final locationController = TextEditingController();
    final qrController = TextEditingController();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Ajouter une Machine'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom de la machine')),
                  TextField(controller: serialController, decoration: const InputDecoration(labelText: 'Numéro de série')),
                  TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Localisation')),
                  TextField(controller: qrController, decoration: const InputDecoration(labelText: 'Code QR (identifiant unique)')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Groupe de machine'),
                    items: groups.map((g) => DropdownMenuItem<int>(
                      value: g['id_groupe_machine'],
                      child: Text(g['nom_groupe']),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedGroupId = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedGroupId == null || nameController.text.isEmpty) return;
                  try {
                    await _apiService.createMachine({
                      'nom': nameController.text,
                      'num_serie': serialController.text,
                      'localisation': locationController.text,
                      'qr_code': qrController.text.isEmpty ? nameController.text : qrController.text,
                      'id_groupe_machine': selectedGroupId,
                    });
                    Navigator.pop(context);
                    _fetchMachines();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMachines = _machines.where((m) {
      return m.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.numSerie ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
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
                  'Gestion du Parc Machines',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Text(
                  'Suivi technique et état opérationnel des équipements',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddMachineDialog,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Ajouter une Machine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Stats Cards for Machines
        Row(
          children: [
            _buildStatCard('Total', _machines.length.toString(), FontAwesomeIcons.industry, Colors.blue),
            const SizedBox(width: 24),
            _buildStatCard('Opérationnel', _machines.where((m) => m.statut == 'Opérationnel').length.toString(), FontAwesomeIcons.checkCircle, Colors.green),
            const SizedBox(width: 24),
            _buildStatCard('En Panne', _machines.where((m) => m.statut != 'Opérationnel').length.toString(), FontAwesomeIcons.exclamationTriangle, Colors.red),
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
                  hintText: 'Rechercher par nom ou numéro de série...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator())
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columnSpacing: 32,
                    columns: const [
                      DataColumn(label: Text('MACHINE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('SÉRIE / QR', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('LOCALISATION', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredMachines.map((machine) {
                      final isOk = machine.statut == 'Opérationnel';
                      return DataRow(cells: [
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.precision_manufacturing, color: Colors.orange, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Text(machine.nom, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          ],
                        )),
                        DataCell(Text(machine.numSerie ?? machine.qrCode)),
                        DataCell(Text(machine.localisation)),
                        DataCell(_buildStatusBadge(machine.statut ?? 'Inconnu', isOk)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.qr_code_2, size: 18), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed), onPressed: () => _deleteMachine(machine.id)),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isOk) {
    final color = isOk ? AppTheme.successGreen : AppTheme.errorRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
