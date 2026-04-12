import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class DashboardOverviewView extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardOverviewView({super.key, this.onNavigate});

  @override
  State<DashboardOverviewView> createState() => _DashboardOverviewViewState();
}

class _DashboardOverviewViewState extends State<DashboardOverviewView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _userCount = 0;
  int _machineCount = 0;
  int _interventionCount = 0;
  int _panneCount = 0;
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getDashboardStats(),
        _apiService.getRecentActivities(),
      ]);
      
      final stats = results[0] as Map<String, dynamic>;
      _recentActivities = results[1] as List<Map<String, dynamic>>;
      
      debugPrint('Dashboard Stats result: $stats');
      
      setState(() {
        _userCount = stats['users']?['total'] ?? 0;
        _machineCount = stats['machines']?['total'] ?? 0;
        _interventionCount = stats['interventions']?['today'] ?? 0;
        _panneCount = stats['pannes']?['en_cours'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tableau de Bord Global',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        const Text(
          'Aperçu en temps réel de votre écosystème de maintenance',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
        ),
        const SizedBox(height: 40),
        
        // Key Metrics Grid
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildStatBox('Utilisateurs', _userCount.toString(), FontAwesomeIcons.users, AppTheme.primaryBlue, 1),
            _buildStatBox('Machines', _machineCount.toString(), FontAwesomeIcons.industry, Colors.orange, 2),
            _buildStatBox('Interventions (Auj.)', _interventionCount.toString(), FontAwesomeIcons.tools, Colors.green, 4),
            _buildStatBox('Interventions en cours', _panneCount.toString(), FontAwesomeIcons.bolt, AppTheme.errorRed, 5),
          ],
        ),
        
        const SizedBox(height: 48),
        
        // Secondary section (Placeholder for Charts or Activity Feed)
        _buildTrendChart(),
        const SizedBox(height: 32),
        _buildActivityFeed(),
      ],
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color, int navigationIndex) {
    final width = (MediaQuery.of(context).size.width - 320 - 48*2) / 4; 
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          if (widget.onNavigate != null) {
            widget.onNavigate!(navigationIndex);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: width < 200 ? 250 : width,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10)),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 24),
              Text(
                value,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tendance des Pannes (7j)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 1),
                      const FlSpot(1, 3),
                      const FlSpot(2, 2),
                      const FlSpot(3, 1),
                      const FlSpot(4, 4),
                      const FlSpot(5, 3),
                      const FlSpot(6, 2),
                    ],
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: AppTheme.primaryBlue.withOpacity(0.05)),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activités Récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_recentActivities.isEmpty)
            const Text('Aucune activité récente', style: TextStyle(color: AppTheme.textGrey))
          else
            ..._recentActivities.map((act) {
              Color color = Colors.blue;
              if (act['color'] == 'errorRed') color = AppTheme.errorRed;
              if (act['color'] == 'successGreen') color = AppTheme.successGreen;
              if (act['color'] == 'primaryBlue') color = AppTheme.primaryBlue;
              if (act['color'] == 'warningOrange') color = AppTheme.warningOrange;

              // Helper for time ago formatting
              String timeStr = 'Aujourd\'hui';
              if (act['date'] != null) {
                try {
                  final date = DateTime.parse(act['date']);
                  final diff = DateTime.now().difference(date);
                  if (diff.inMinutes < 60) {
                    timeStr = 'Il y a ${diff.inMinutes} min';
                  } else if (diff.inHours < 24) {
                    timeStr = 'Il y a ${diff.inHours} h';
                  } else {
                    timeStr = 'Il y a ${diff.inDays} j';
                  }
                } catch (_) {}
              }

              return _buildActivityItem(act['text'], timeStr, color);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String text, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(time, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

}
