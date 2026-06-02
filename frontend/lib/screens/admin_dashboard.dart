import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'user_management_screen.dart';
import 'machine_management_screen.dart';
import 'config_management_screen.dart';
import 'panne_management_screen.dart';
import 'intervention_management_screen.dart';
import 'magasin_management_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Console d\'Administration',
          style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textDark),
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contrôle Global',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous avez les droits d\'accès et de gestion sur tous les rôles.',
              style: TextStyle(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 32),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildAdminCard(
                  context,
                  'Utilisateurs',
                  Icons.people_alt_rounded,
                  AppTheme.primaryBlue,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                ),
                _buildAdminCard(
                  context,
                  'Machines',
                  Icons.precision_manufacturing_rounded,
                  Colors.orange,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MachineManagementScreen())),
                ),
                _buildAdminCard(
                  context,
                  'Pannes',
                  Icons.report_problem_rounded,
                  Colors.redAccent,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanneManagementScreen())),
                ),
                _buildAdminCard(
                  context,
                  'Interventions',
                  Icons.assignment_turned_in_rounded,
                  Colors.green,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterventionManagementScreen())),
                ),
                _buildAdminCard(
                  context,
                  'Groupes',
                  Icons.group_work_rounded,
                  Colors.purple,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigManagementScreen())),
                ),
                _buildAdminCard(
                  context,
                  'Magasin',
                  Icons.inventory_2_rounded,
                  Colors.brown,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MagasinManagementScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
