import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _techGroups = [];
  List<Map<String, dynamic>> _machineGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getAllUsers(),
        _apiService.getGroupesTechniciens(),
        _apiService.getGroupesMachines(),
      ]);
      setState(() {
        _users = results[0] as List<Map<String, dynamic>>;
        _techGroups = results[1] as List<Map<String, dynamic>>;
        _machineGroups = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet utilisateur ? Cette action est irréversible.'),
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
        await _apiService.deleteUser(id);
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur supprimé avec succès')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final name = '${user['prenom']} ${user['nom']}'.toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Utilisateurs du Système',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Text(
                  '${_users.length} utilisateurs enregistrés au total',
                  style: const TextStyle(color: AppTheme.textGrey),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddUserDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouvel Utilisateur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom ou email...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columnSpacing: 40,
                    columns: const [
                      DataColumn(label: Text('UTILISATEUR', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('EMAIL', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('RÔLE', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredUsers.map((user) {
                      return DataRow(cells: [
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                              child: Text(
                                user['prenom'][0].toUpperCase(),
                                style: const TextStyle(fontSize: 10, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('${user['prenom']} ${user['nom']}'),
                          ],
                        )),
                        DataCell(Text(user['email'] ?? '')),
                        DataCell(_buildRoleBadge(user['role'] ?? '')),
                        DataCell(
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppTheme.successGreen, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              const Text('Actif', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textGrey),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorRed),
                              onPressed: () => _deleteUser(user['id_utilisateur']),
                            ),
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

  void _showAddUserDialog() {
    final nomCtrl = TextEditingController();
    final prenomCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'TECHNICIEN';
    int? selectedPrimaryGroup;
    List<int> selectedComps = [];

    // Initialize the primary group if available
    if (_techGroups.isNotEmpty) {
      selectedPrimaryGroup = _techGroups.first['id_groupe_tech'];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Créer un nouvel utilisateur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom')),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Mot de passe', hintText: 'Min 8 caractères'), obscureText: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                    items: const [
                      DropdownMenuItem(value: 'ADMINISTRATEUR', child: Text('Administrateur')),
                      DropdownMenuItem(value: 'SUPERVISEUR', child: Text('Superviseur')),
                      DropdownMenuItem(value: 'CHEF_EQUIPE', child: Text('Chef d\'Équipe')),
                      DropdownMenuItem(value: 'MAGASINIER', child: Text('Magasinier')),
                      DropdownMenuItem(value: 'TECHNICIEN', child: Text('Technicien')),
                    ],
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                if (selectedRole == 'TECHNICIEN') ...[
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Groupe Principal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedPrimaryGroup,
                    decoration: InputDecoration(
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _techGroups.map((g) => DropdownMenuItem<int>(
                      value: g['id_groupe_tech'],
                      child: Text(g['nom_groupe']),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedPrimaryGroup = val),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Compétences (Groupes Machines)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _machineGroups.map((mg) {
                      final id = mg['id_groupe_machine'] as int;
                      final isSelected = selectedComps.contains(id);
                      return FilterChip(
                        label: Text(mg['nom_groupe'], style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.textDark)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBlue,
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedComps.add(id);
                            } else {
                              selectedComps.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final commonData = {
                    'nom': nomCtrl.text,
                    'prenom': prenomCtrl.text,
                    'email': emailCtrl.text,
                    'mot_de_passe': passCtrl.text,
                  };

                  if (selectedRole == 'MAGASINIER') {
                    await _apiService.createMagasinier(commonData);
                  } else if (selectedRole == 'TECHNICIEN') {
                    final techData = {
                      ...commonData,
                      'id_groupe_principal': selectedPrimaryGroup ?? 1,
                      'competences_ids': selectedComps,
                      'statut_presence': 'en_travail',
                      'statut': 'disponible',
                    };
                    await _apiService.createTechnician(techData);
                  } else if (selectedRole == 'CHEF_EQUIPE') {
                    final chefData = {
                      ...commonData,
                      'id_groupe_supervise': 1, // Default or specific group
                    };
                    await _apiService.createChef(chefData);
                  } else if (selectedRole == 'SUPERVISEUR') {
                    final supData = {
                      ...commonData,
                      'zone_responsabilite': 'Zone A',
                    };
                    await _apiService.createSupervisor(supData);
                  } else {
                    final userData = {
                      ...commonData,
                      'role': selectedRole,
                      'statut_presence': 'en_travail',
                    };
                    await _apiService.createUser(userData);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    _fetchUsers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Utilisateur créé avec succès'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'administrateur':
        color = Colors.purple;
        break;
      case 'superviseur':
        color = Colors.blue;
        break;
      case 'chef_equipe':
        color = Colors.orange;
        break;
      case 'magasinier':
        color = Colors.indigo;
        break;
      case 'technicien':
        color = Colors.teal;
        break;
      default:
        color = AppTheme.textGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildHeaderButton(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
