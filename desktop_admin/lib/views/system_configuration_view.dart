import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class SystemConfigurationView extends StatefulWidget {
  const SystemConfigurationView({super.key});

  @override
  State<SystemConfigurationView> createState() => _SystemConfigurationViewState();
}

class _SystemConfigurationViewState extends State<SystemConfigurationView> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configuration Système',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const Text(
          'Gérez les paramètres globaux de l\'application',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
        ),
        const SizedBox(height: 40),
        
        // Configuration Cards
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildConfigCard(
              context,
              title: 'Groupe de Machines',
              description: 'Créer un nouveau groupe de machines.',
              icon: FontAwesomeIcons.shapes,
              iconColor: Colors.purple,
              onAddTap: () => _showCreateMachineGroupDialog(context),
            ),
            _buildConfigCard(
              context,
              title: 'Groupe de Techniciens',
              description: 'Définir une nouvelle équipe technique.',
              icon: FontAwesomeIcons.userCog,
              iconColor: Colors.blue,
              onAddTap: () => _showCreateTechnicianGroupDialog(context),
            ),
            _buildConfigCard(
              context,
              title: 'Types de Pannes',
              description: 'Ajouter une catégorie de panne au catalogue.',
              icon: FontAwesomeIcons.exclamationTriangle,
              iconColor: Colors.teal,
              onAddTap: () => _showCreateTypePanneDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onAddTap,
  }) {
    final width = (MediaQuery.of(context).size.width - 320 - 48 * 2) / 3; 
    return Container(
      width: width < 300 ? 300 : width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onAddTap,
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.textGrey),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ],
      ),
    );
  }

  void _showCreateMachineGroupDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    bool isLoading = false;
    List<Map<String, dynamic>> techGroups = [];
    int? selectedTechGroupId;

    // Fetch tech groups
    try {
      techGroups = await _apiService.getGroupesTechniciens();
    } catch (e) {
      debugPrint("Error fetching tech groups: $e");
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nouveau Groupe de Machines'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedTechGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Équipe technique responsable',
                      border: OutlineInputBorder(),
                    ),
                    items: techGroups.map((g) {
                      return DropdownMenuItem<int>(
                        value: g['id_groupe_tech'],
                        child: Text(g['nom_groupe'] ?? 'Équipe ${g['id_groupe_tech']}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedTechGroupId = val),
                    hint: const Text('Sélectionner une équipe'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await _apiService.createMachineGroup(
                        nameController.text,
                        idGroupeTech: selectedTechGroupId,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Groupe de machines créé avec succès'), backgroundColor: AppTheme.successGreen),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
                        );
                      }
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Créer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showCreateTechnicianGroupDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nouvelle Équipe Technique'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'équipe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await _apiService.createTechnicianGroup(nameController.text);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Équipe technique créée avec succès'), backgroundColor: AppTheme.successGreen),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
                        );
                      }
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Créer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showCreateTypePanneDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    String selectedGravite = 'MINEURE';
    final List<String> gravites = ['MINEURE', 'MAJEURE', 'CRITIQUE'];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nouveau Type de Panne'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la panne',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGravite,
                    decoration: const InputDecoration(
                      labelText: 'Gravité',
                      border: OutlineInputBorder(),
                    ),
                    items: gravites.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedGravite = newValue!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await _apiService.createTypePanne(nameController.text, selectedGravite);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Type de panne créé avec succès'), backgroundColor: AppTheme.successGreen),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
                        );
                      }
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  child: isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Créer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

