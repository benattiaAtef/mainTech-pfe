import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../views/magasinier_dashboard_view.dart';
import '../views/magasinier_inventory_view.dart';
import '../views/magasinier_requests_view.dart';

class MagasinierShell extends StatefulWidget {
  const MagasinierShell({super.key});

  @override
  State<MagasinierShell> createState() => _MagasinierShellState();
}

class _MagasinierShellState extends State<MagasinierShell> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final ApiService _apiService = ApiService();

  final List<MagasinierMenuItem> _menuItems = [
    MagasinierMenuItem(title: 'Tableau de Bord', icon: FontAwesomeIcons.chartLine),
    MagasinierMenuItem(title: 'Gestion du Stock', icon: FontAwesomeIcons.boxesStacked),
    MagasinierMenuItem(title: 'Demandes de Pièces', icon: FontAwesomeIcons.envelopeOpenText),
    MagasinierMenuItem(title: 'Paramètres', icon: FontAwesomeIcons.gear),
  ];

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return MagasinierDashboardView(
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return const MagasinierInventoryView();
      case 2:
        return const MagasinierRequestsView();
      case 3:
        return _buildSettingsPlaceholder();
      default:
        return const Center(child: Text('Vue non implémentée'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Row(
        children: [
          _buildSidebar(),
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
        color: const Color(0xFF1E293B),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildSidebarLogo(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) => _buildSidebarItem(index),
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
          const Icon(FontAwesomeIcons.warehouse, color: AppTheme.primaryBlue, size: 24),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 12),
            const Text(
              'MAGASINIER',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
          border: isSelected ? const Border(left: BorderSide(color: AppTheme.primaryBlue, width: 4)) : null,
          color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(item.icon, color: isSelected ? Colors.white : Colors.white.withOpacity(0.5), size: 18),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 16),
              Text(item.title, style: TextStyle(color: isSelected ? Colors.white : Colors.white.withOpacity(0.5), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
        icon: Icon(_isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
        onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_menuItems[_selectedIndex].title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              _buildHeaderIcon(Icons.search_rounded),
              const SizedBox(width: 16),
              _buildHeaderIcon(Icons.notifications_none_rounded),
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
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Magasinier Central', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Gestion des Stocks', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
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

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppTheme.textGrey, size: 20),
    );
  }

  Widget _buildSettingsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Center(child: Text('Paramètres du compte bientôt disponibles')),
    );
  }
}

class MagasinierMenuItem {
  final String title;
  final IconData icon;
  MagasinierMenuItem({required this.title, required this.icon});
}
