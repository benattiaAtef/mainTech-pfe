import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class PerformanceBIView extends StatefulWidget {
  const PerformanceBIView({super.key});

  @override
  State<PerformanceBIView> createState() => _PerformanceBIViewState();
}

class _PerformanceBIViewState extends State<PerformanceBIView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Intervention> _interventions = [];
  List<Machine> _machines = [];
  List<Map<String, dynamic>> _pannes = [];

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getInterventions(),
        _apiService.getMachines(),
        _apiService.getPannes(),
      ]);
      setState(() {
        _interventions = results[0] as List<Intervention>;
        _machines = results[1] as List<Machine>;
        _pannes = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Analyses de Performance & BI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const Text('Vision stratégique et indicateurs clés de maintenance', style: TextStyle(color: AppTheme.textGrey)),
        const SizedBox(height: 32),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildLineChartCard()),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildPieChartCard()),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildBarChartCard()),
            const SizedBox(width: 24),
            Expanded(child: _buildStatsGrid()),
          ],
        ),
      ],
    );
  }

  Widget _buildLineChartCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tendance des Interventions (7 jours)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 40),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Text('J-${7 - val.toInt()}', style: const TextStyle(fontSize: 10, color: AppTheme.textGrey)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 3),
                      const FlSpot(1, 4),
                      const FlSpot(2, 2),
                      const FlSpot(3, 5),
                      const FlSpot(4, 3),
                      const FlSpot(5, 4),
                      const FlSpot(6, 6),
                    ],
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primaryBlue.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Répartition par Priorité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 40),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(color: AppTheme.errorRed, value: 30, title: 'Urgentes', titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold), radius: 60),
                  PieChartSectionData(color: AppTheme.warningOrange, value: 45, title: 'Moyennes', titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold), radius: 55),
                  PieChartSectionData(color: AppTheme.successGreen, value: 25, title: 'Mineures', titleStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold), radius: 50),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend('P1 - Critique', AppTheme.errorRed),
          _buildLegend('P2 - Standard', AppTheme.warningOrange),
          _buildLegend('P3 - Mineure', AppTheme.successGreen),
        ],
      ),
    );
  }

  Widget _buildLegend(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        ],
      ),
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Machines en Panne', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: AppTheme.primaryBlue, width: 22, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 6, color: AppTheme.primaryBlue, width: 22, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 5, color: AppTheme.primaryBlue, width: 22, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 4, color: AppTheme.primaryBlue, width: 22, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return SizedBox(
      height: 350,
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: [
          _buildMiniStat('Disponibilité', '94.2%', Icons.check_circle_outline, AppTheme.successGreen),
          _buildMiniStat('MTTR (Moyen)', '42 min', Icons.timer_outlined, AppTheme.warningOrange),
          _buildMiniStat('MTBF', '128 h', Icons.update, AppTheme.primaryBlue),
          _buildMiniStat('Budget Pièces', '2.4k €', Icons.account_balance_wallet_outlined, AppTheme.textDark),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF1F5F9)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
    );
  }
}
