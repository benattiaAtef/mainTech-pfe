import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../views/chef_dashboard_view.dart';
import '../views/team_management_view.dart';
import '../views/team_interventions_view.dart';
import '../views/team_chat_view.dart';

class ChefShell extends StatefulWidget {
  const ChefShell({super.key});

  @override
  State<ChefShell> createState() => _ChefShellState();
}

class _ChefShellState extends State<ChefShell> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  bool _isAvailable = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPresence();
  }

  Future<void> _loadPresence() async {
    try {
      final user = await _apiService.getMe();
      setState(() => _isAvailable = user.statutPresence == 'en_travail');
    } catch (e) {
      debugPrint('Error loading presence: $e');
    }
  }

  Future<void> _togglePresence(bool val) async {
    setState(() => _isAvailable = val);
    try {
      await _apiService.updatePresence(val ? 'en_travail' : 'hors_travail');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed));
        setState(() => _isAvailable = !val);
      }
    }
  }

  final List<ChefMenuItem> _menuItems = [
    ChefMenuItem(title: 'Vue d\'Équipe', icon: FontAwesomeIcons.users),
    ChefMenuItem(title: 'Techniciens', icon: FontAwesomeIcons.userGear),
    ChefMenuItem(title: 'Chat d\'Équipe', icon: FontAwesomeIcons.message),
    ChefMenuItem(title: 'Interventions Groupe', icon: FontAwesomeIcons.clipboardList),
  ];

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return ChefDashboardView(
          onNavigate: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return const TeamManagementView();
      case 2:
        return const TeamChatView();
      case 3:
        return const TeamInterventionsView();
      default:
        return const Center(child: Text('Vue non implémentée'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          const Icon(FontAwesomeIcons.rocket, color: AppTheme.primaryBlue, size: 24),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 12),
            const Text(
              'CHEF EQUIPE',
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
              const SizedBox(width: 24),
              const SizedBox(width: 24),
              _buildHeaderIcon(Icons.notifications_none_rounded),
              const SizedBox(width: 24),
              const VerticalDivider(indent: 20, endIndent: 20),
              const SizedBox(width: 24),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Chef d\'Équipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Maintenance Industrielle', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              const CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryBlue, child: Icon(Icons.person, color: Colors.white, size: 20)),

            ],
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

}

class ChefMenuItem {
  final String title;
  final IconData icon;
  ChefMenuItem({required this.title, required this.icon});
}
