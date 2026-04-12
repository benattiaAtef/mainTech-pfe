import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'machine_detail_screen.dart';
import 'team_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  late Future<List<Machine>> _machinesFuture;

  @override
  void initState() {
    super.initState();
    _machinesFuture = _apiService.getMachines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaintManager', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.primaryBlue),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text('MaintManager', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryBlue),
              title: const Text('Vue d\'ensemble'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.show_chart_rounded),
              title: const Text('Monitoring'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Rapports'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Équipe'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamScreen()));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Paramètres'),
              onTap: () {},
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: AppTheme.textGrey, child: Icon(Icons.person, color: Colors.white)),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chef d\'équipe', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('En ligne', style: TextStyle(fontSize: 12, color: AppTheme.successGreen)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Responsable Maintenance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('20 Unités actives', style: TextStyle(color: AppTheme.textGrey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Admin', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _buildStatusIndicator('Opérationnel', AppTheme.successGreen),
                _buildStatusIndicator('En cours', AppTheme.textDark),
                _buildStatusIndicator('Arrêt critique', AppTheme.errorRed),
                _buildStatusIndicator('Problème', AppTheme.warningOrange),
              ],
            ),
            const SizedBox(height: 32),
            FutureBuilder<List<Machine>>(
              future: _machinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aucune machine trouvée'));
                }

                final machines = snapshot.data!;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    return _buildMachineCard(context, machine);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineCard(BuildContext context, Machine machine) {
    final bool isOperational = machine.statut == 'Opérationnel';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MachineDetailScreen(machine: machine)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isOperational ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_suggest_outlined,
                color: isOperational ? AppTheme.successGreen : AppTheme.errorRed,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'M${machine.id}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              machine.nom,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isOperational ? AppTheme.successGreen : AppTheme.errorRed).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                machine.statut,
                style: TextStyle(
                  color: isOperational ? AppTheme.successGreen : AppTheme.errorRed,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
      ],
    );
  }
}
