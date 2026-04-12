import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';

class CollapsibleSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const CollapsibleSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isCollapsed ? 80 : 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildMenuItem(0, 'Tableau de Bord', FontAwesomeIcons.chartLine),
                _buildMenuItem(1, 'Utilisateurs', FontAwesomeIcons.users),
                _buildMenuItem(2, 'Machines', FontAwesomeIcons.microchip),
                _buildMenuItem(3, 'Interventions', FontAwesomeIcons.tools),
                _buildMenuItem(4, 'Pannes', FontAwesomeIcons.exclamationTriangle),
                _buildMenuItem(5, 'Performance (BI)', FontAwesomeIcons.tachometerAlt),
                const Divider(height: 40, thickness: 1, color: Color(0xFFF1F5F9)),
                _buildMenuItem(6, 'Configuration', FontAwesomeIcons.cog),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        children: [
          if (!widget.isCollapsed)
            const Row(
              children: [
                Icon(FontAwesomeIcons.rocket, color: AppTheme.primaryBlue, size: 24),
                SizedBox(width: 12),
                Text(
                  'MAINTECH',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          IconButton(
            icon: Icon(
              widget.isCollapsed ? FontAwesomeIcons.chevronRight : FontAwesomeIcons.chevronLeft,
              size: 16,
              color: AppTheme.textGrey,
            ),
            onPressed: widget.onToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, String title, IconData icon) {
    bool isSelected = widget.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onItemSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: widget.isCollapsed ? 0 : 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primaryBlue : AppTheme.textGrey,
              ),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textGrey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => Navigator.of(context).pushReplacementNamed('/'),
        child: Row(
          mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const Icon(FontAwesomeIcons.signOutAlt, size: 20, color: AppTheme.errorRed),
            if (!widget.isCollapsed) ...[
              const SizedBox(width: 16),
              const Text(
                'Déconnexion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
