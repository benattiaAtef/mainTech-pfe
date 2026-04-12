import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../views/dashboard_overview_view.dart';
import '../views/user_management_view.dart';
import '../views/machine_management_view.dart';
import '../views/intervention_management_view.dart';
import '../views/panne_management_view.dart';
import '../views/magasin_management_view.dart';
import '../views/performance_bi_view.dart';
import '../views/system_configuration_view.dart';

class AdminShell extends StatefulWidget {
  final String role;
  const AdminShell({super.key, this.role = 'administrateur'});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  int _refreshCount = 0; // Increment to force view reload

  // All available menu items with their associated views and allowed roles
  static const _allItems = [
    {'title': 'Tableau de Bord',      'roles': ['administrateur', 'admin', 'magasinier']},
    {'title': 'Utilisateurs',         'roles': ['administrateur', 'admin']},
    {'title': 'Parc Machines',        'roles': ['administrateur', 'admin']},
    {'title': 'Magasin',              'roles': ['administrateur', 'admin', 'magasinier']},
    {'title': 'Interventions',        'roles': ['administrateur', 'admin']},
    {'title': 'Pannes Actives',       'roles': ['administrateur', 'admin']},
    {'title': 'Performance & BI',     'roles': ['administrateur', 'admin']},
    {'title': 'Configuration Système','roles': ['administrateur', 'admin']},
  ];

  static const _allIcons = [
    FontAwesomeIcons.chartLine,
    FontAwesomeIcons.usersCog,
    FontAwesomeIcons.industry,
    FontAwesomeIcons.boxesStacked,
    FontAwesomeIcons.tools,
    FontAwesomeIcons.exclamationTriangle,
    FontAwesomeIcons.chartBar,
    FontAwesomeIcons.cogs,
  ];

  // Global index → view builder
  Widget _viewForGlobalIndex(int globalIndex) {
    switch (globalIndex) {
      case 0: return DashboardOverviewView(onNavigate: _navigateToGlobalIndex);
      case 1: return const UserManagementView();
      case 2: return const MachineManagementView();
      case 3: return const MagasinManagementView();
      case 4: return const InterventionManagementView();
      case 5: return const PanneManagementView();
      case 6: return const PerformanceBIView();
      case 7: return const SystemConfigurationView();
      default: return const Center(child: Text('Vue non implémentée'));
    }
  }

  // Filtered menu items for the current role
  List<Map<String, dynamic>> get _filteredItems {
    return _allItems.where((item) {
      final roles = item['roles'] as List;
      return roles.contains(widget.role);
    }).toList();
  }

  // Get the global index corresponding to selected filtered index
  int _globalIndex(int filteredIndex) {
    final filtered = _filteredItems;
    final title = filtered[filteredIndex]['title'];
    return _allItems.indexWhere((item) => item['title'] == title);
  }

  void _navigateToGlobalIndex(int globalIndex) {
    final items = _filteredItems;
    final title = _allItems[globalIndex]['title'];
    final filteredIdx = items.indexWhere((item) => item['title'] == title);
    if (filteredIdx != -1) {
      setState(() => _selectedIndex = filteredIdx);
    }
  }

  List<AdminMenuItem> get _menuItems {
    return _filteredItems.map((item) {
      final globalIdx = _allItems.indexWhere((a) => a['title'] == item['title']);
      return AdminMenuItem(
        title: item['title'] as String,
        icon: _allIcons[globalIdx],
      );
    }).toList();
  }

  Widget _buildCurrentView() {
    return Container(
      key: ValueKey('view_${_globalIndex(_selectedIndex)}_$_refreshCount'),
      child: _viewForGlobalIndex(_globalIndex(_selectedIndex)),
    );
  }

  String get _roleLabel {
    switch (widget.role) {
      case 'magasinier': return 'Magasinier';
      case 'administrateur': case 'admin': return 'Admin Principal';
      default: return widget.role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Retractable Sidebar
          _buildSidebar(),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCurrentView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarExpanded ? 260 : 80,
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarLogo(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                return _buildSidebarItem(index);
              },
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.rocket, color: Colors.white, size: 24),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 12),
            const Text(
              'MAINTECH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index) {
    final item = _menuItems[index];
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(left: BorderSide(color: AppTheme.primaryBlue, width: 4))
              : null,
          color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              size: 18,
            ),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 16),
              Text(
                item.title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: IconButton(
        icon: Icon(
          _isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.white.withOpacity(0.5),
        ),
        onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _menuItems[_selectedIndex].title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              _buildHeaderActionButton(
                icon: Icons.refresh_rounded, 
                tooltip: 'Rafraîchir la vue',
                onPressed: () => setState(() => _refreshCount++),
              ),
              const SizedBox(width: 12),
              _buildHeaderActionButton(
                icon: Icons.logout_rounded, 
                tooltip: 'Se déconnecter',
                color: AppTheme.errorRed,
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 24),
              const VerticalDivider(indent: 20, endIndent: 20),
              const SizedBox(width: 24),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_roleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Text('Connecté', style: TextStyle(color: AppTheme.successGreen, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon, 
    required VoidCallback onPressed, 
    String? tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? AppTheme.textGrey, size: 20),
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }
}

class AdminMenuItem {
  final String title;
  final IconData icon;

  AdminMenuItem({required this.title, required this.icon});
}
