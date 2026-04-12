import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'qr_scanner_screen.dart';


class MachineManagementScreen extends StatefulWidget {
  const MachineManagementScreen({super.key});

  @override
  State<MachineManagementScreen> createState() => _MachineManagementScreenState();
}

class _MachineManagementScreenState extends State<MachineManagementScreen> {
  final _apiService = ApiService();
  List<Machine> _machines = [];
  List<Map<String, dynamic>> _machineGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getMachines(),
        _apiService.getGroupesMachines(),
      ]);
      setState(() {
        _machines = results[0] as List<Machine>;
        _machineGroups = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMachine(int id) async {
    try {
      await _apiService.deleteMachine(id);
      _fetchMachines();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Machine supprimée')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Machines'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _machines.length,
              itemBuilder: (context, index) {
                final machine = _machines[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.precision_manufacturing, color: Colors.orange),
                    ),
                    title: Text(machine.nom),
                    subtitle: Text(
                      'SN: ${machine.numSerie ?? 'N/A'} • ${machine.localisation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          machine.statut ?? 'Inconnu',
                          style: TextStyle(
                            color: (machine.statut == 'Opérationnel') ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteMachine(machine.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMachineDialog(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddMachineDialog() {
    final nomController = TextEditingController();
    final qrController = TextEditingController();
    final locController = TextEditingController();
    final snController = TextEditingController();
    int? selectedGroupId = _machineGroups.isNotEmpty ? _machineGroups.first['id_groupe_machine'] : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle Machine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom de la machine')),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedGroupId,
                  decoration: const InputDecoration(labelText: 'Groupe de machine'),
                  items: _machineGroups.map((group) {
                    return DropdownMenuItem<int>(
                      value: group['id_groupe_machine'],
                      child: Text(group['nom_groupe'] ?? 'Sans nom'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedGroupId = value;
                    });
                  },
                ),
                TextField(
                  controller: qrController,
                  decoration: InputDecoration(
                    labelText: 'QR Code',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue),
                      onPressed: () async {
                        final result = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                        );
                        if (result != null) {
                          setDialogState(() {
                            qrController.text = result;
                          });
                        }
                      },
                    ),
                  ),
                ),

                TextField(controller: locController, decoration: const InputDecoration(labelText: 'Localisation')),
                TextField(controller: snController, decoration: const InputDecoration(labelText: 'Numéro de série')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: selectedGroupId == null ? null : () async {
                try {
                  await _apiService.createMachine({
                    'nom': nomController.text,
                    'id_groupe_machine': selectedGroupId,
                    'qr_code': qrController.text,
                    'localisation': locController.text,
                    'num_serie': snController.text,
                    'fonction': 'Production',
                    'date_installation': DateTime.now().toIso8601String(),
                  });
                  if (mounted) Navigator.pop(context);
                  _fetchMachines();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
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
