import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ConfigManagementScreen extends StatefulWidget {
  const ConfigManagementScreen({super.key});

  @override
  State<ConfigManagementScreen> createState() => _ConfigManagementScreenState();
}

class _ConfigManagementScreenState extends State<ConfigManagementScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Système'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildConfigItem(
              'Groupe de Machines',
              'Créer un nouveau groupe de machines.',
              Icons.category_rounded,
              Colors.purple,
              () => _showCreateDialog('Groupe de Machines', (name) => _apiService.createMachineGroup(name)),
            ),
            const SizedBox(height: 16),
            _buildConfigItem(
              'Groupe de Techniciens',
              'Définir une nouvelle équipe technique.',
              Icons.engineering_rounded,
              Colors.blue,
              () => _showCreateDialog('Groupe de Techniciens', (name) => _apiService.createTechnicianGroup(name)),
            ),
            const SizedBox(height: 16),
            _buildConfigItem(
              'Types de Pannes',
              'Ajouter une catégorie de panne au catalogue.',
              Icons.warning_amber_rounded,
              Colors.teal,
              () => _showCreateTypePanneDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Colors.white,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.add_circle_outline, color: AppTheme.textGrey),
    );
  }

  void _showCreateDialog(String title, Future<void> Function(String) onCreate) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau $title'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await onCreate(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créé avec succès')));
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showCreateTypePanneDialog() {
    final nameController = TextEditingController();
    String gravite = 'MOYENNE';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau Type de Panne'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom de la panne')),
              DropdownButton<String>(
                value: gravite,
                isExpanded: true,
                items: ['FAIBLE', 'MOYENNE', 'HAUTE', 'CRITIQUE'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (val) => setDialogState(() => gravite = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await _apiService.createTypePanne(nameController.text, gravite);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type de panne créé')));
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
