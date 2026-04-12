import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _apiService.getAllUsers();
      setState(() => _users = users);
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

  Future<void> _deleteUser(int id) async {
    try {
      await _apiService.deleteUser(id);
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur supprimé')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Superviseurs'),
            Tab(text: 'Chefs'),
            Tab(text: 'Magasiniers'),
            Tab(text: 'Technicien'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_users),
                _buildUserList(_users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'superviseur').toList()),
                _buildUserList(_users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'chef_equipe').toList()),
                _buildUserList(_users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'magasinier').toList()),
                _buildUserList(_users.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'technicien').toList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateUserDialog(),
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur trouvé.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: const Icon(Icons.person, color: AppTheme.primaryBlue),
            ),
            title: Text('${user['prenom']} ${user['nom']}'),
            subtitle: Text('${user['email']} • ${user['role']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteUser(user['id_utilisateur']),
            ),
          ),
        );
      },
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateUserDialog(
        apiService: _apiService,
        onUserCreated: _fetchUsers,
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onUserCreated;

  const _CreateUserDialog({
    required this.apiService,
    required this.onUserCreated,
  });

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  
  String selectedRole = 'technicien';
  int? selectedGroupTech;
  List<int> selectedCompetences = [];
  
  List<Map<String, dynamic>> machineGroups = [];
  List<Map<String, dynamic>> techGroups = [];
  bool isLoadingGroups = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final results = await Future.wait([
        widget.apiService.getGroupesTechniciens(),
        widget.apiService.getGroupesMachines(),
      ]);
      if (mounted) {
        setState(() {
          techGroups = results[0];
          machineGroups = results[1];
          isLoadingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingGroups = false);
      print('Error loading groups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvel Utilisateur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prénom')),
            TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passController, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
            const SizedBox(height: 16),
            const Text('Rôle', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              items: ['technicien', 'chef_equipe', 'superviseur', 'magasinier'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (val) => setState(() => selectedRole = val!),
            ),
            
            if (selectedRole == 'technicien') ...[
              const SizedBox(height: 16),
              const Text('Groupe Principal', style: TextStyle(fontWeight: FontWeight.bold)),
              isLoadingGroups 
                ? const LinearProgressIndicator()
                : DropdownButton<int>(
                    value: selectedGroupTech,
                    isExpanded: true,
                    hint: const Text('Sélectionner un groupe'),
                    items: techGroups.map((g) {
                      return DropdownMenuItem<int>(
                        value: g['id_groupe_tech'],
                        child: Text(g['nom_groupe'].toString().trim()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedGroupTech = val),
                  ),
              const SizedBox(height: 16),
              const Text('Compétences (Renfort)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (isLoadingGroups)
                const Center(child: CircularProgressIndicator())
              else if (machineGroups.isEmpty)
                const Text('Aucun groupe machine disponible')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: machineGroups.map((g) {
                    final isSelected = selectedCompetences.contains(g['id_groupe_machine']);
                    return FilterChip(
                      label: Text(g['nom_groupe'].toString().trim()),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedCompetences.add(g['id_groupe_machine']);
                          } else {
                            selectedCompetences.remove(g['id_groupe_machine']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
            
            if (selectedRole == 'chef_equipe') ...[
              const SizedBox(height: 16),
              const Text('Groupe à superviser', style: TextStyle(fontWeight: FontWeight.bold)),
              isLoadingGroups
                ? const LinearProgressIndicator()
                : DropdownButton<int>(
                    value: selectedGroupTech,
                    isExpanded: true,
                    hint: const Text('Sélectionner un groupe'),
                    items: techGroups.map((g) {
                      return DropdownMenuItem<int>(
                        value: g['id_groupe_tech'],
                        child: Text(g['nom_groupe'].toString().trim()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedGroupTech = val),
                  ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            // ── Validation ──
            final email = emailController.text.trim();
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            
            if (nomController.text.trim().isEmpty ||
                prenomController.text.trim().isEmpty ||
                email.isEmpty ||
                passController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
              );
              return;
            }
            
            if (!emailRegex.hasMatch(email)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Veuillez entrer une adresse email valide.')),
              );
              return;
            }

            if (passController.text.length < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères.')),
              );
              return;
            }

            final data = {
              'nom': nomController.text.trim(),
              'prenom': prenomController.text.trim(),
              'email': email,
              'mot_de_passe': passController.text,
            };

            try {
              if (selectedRole == 'superviseur') {
                await widget.apiService.createSupervisor({...data, 'zone_responsabilite': 'Générale'});
              } else if (selectedRole == 'chef_equipe') {
                await widget.apiService.createChef({...data, 'id_groupe_supervise': selectedGroupTech ?? 1});
              } else if (selectedRole == 'magasinier') {
                await widget.apiService.createMagasinier(data);
              } else {
                // Technicien
                await widget.apiService.createTechnician({
                  ...data,
                  'id_groupe_principal': selectedGroupTech,
                  'competences_ids': selectedCompetences,
                  'statut': 'DISPONIBLE', // Correct case for backend
                  'position_lat': 0.0,
                  'position_lng': 0.0
                });
              }
              if (mounted) {
                widget.onUserCreated();
                Navigator.pop(context);
              }
            } catch (e) {
              if (mounted) {
                String cleanMessage = e.toString().replaceAll('Exception: ', '');
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanMessage)));
              }
            }
          },
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
