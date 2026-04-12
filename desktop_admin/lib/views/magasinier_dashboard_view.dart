import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MagasinierDashboardView extends StatefulWidget {
  final Function(int)? onNavigate;
  const MagasinierDashboardView({super.key, this.onNavigate});

  @override
  State<MagasinierDashboardView> createState() => _MagasinierDashboardViewState();
}

class _MagasinierDashboardViewState extends State<MagasinierDashboardView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<PieceRechange> _pieces = [];
  List<DemandeRechange> _demandes = [];
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getPieces(),
        _apiService.getAllDemandesRechange(),
      ]);

      _pieces = results[0] as List<PieceRechange>;
      _demandes = results[1] as List<DemandeRechange>;
      
      _lowStockCount = _pieces.where((p) => p.quantiteStock < 5).length;
    } catch (e) {
      debugPrint('Error loading magasinier dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final pendingRequests = _demandes.where((d) => d.statut == 'en_attente').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, Magasinier',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Text(
                  'Voici l\'état actuel du stock et des demandes.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualiser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Stat Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Articles en Stock',
                _pieces.length.toString(),
                FontAwesomeIcons.boxesStacked,
                AppTheme.primaryBlue,
                onTap: () => widget.onNavigate?.call(1),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildStatCard(
                'Demandes en Attente',
                pendingRequests.length.toString(),
                FontAwesomeIcons.clockRotateLeft,
                AppTheme.warningOrange,
                onTap: () => widget.onNavigate?.call(2),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildStatCard(
                'Stock Faible (< 5)',
                _lowStockCount.toString(),
                FontAwesomeIcons.triangleExclamation,
                AppTheme.errorRed,
                onTap: () => widget.onNavigate?.call(1),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        // Recent Requests Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dernières Demandes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            TextButton(
              onPressed: () => widget.onNavigate?.call(2),
              child: const Text('Voir tout'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildRequestsList(pendingRequests),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 24),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            Text(title, style: const TextStyle(color: AppTheme.textGrey, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList(List<DemandeRechange> requests) {
    if (requests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 48),
              SizedBox(height: 16),
              Text('Toutes les demandes ont été traitées !', style: TextStyle(color: AppTheme.textGrey)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: requests.take(5).length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final request = requests[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: AppTheme.secondaryBlue,
              child: const Icon(Icons.shopping_cart_outlined, color: AppTheme.primaryBlue, size: 20),
            ),
            title: Text(request.piece?.nom ?? 'Pièce inconnue', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Quantité demandée: ${request.quantiteDemandee} ${request.piece?.unite ?? "pcs"}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'EN ATTENTE',
                style: TextStyle(color: AppTheme.warningOrange, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
          );
        },
      ),
    );
  }
}
