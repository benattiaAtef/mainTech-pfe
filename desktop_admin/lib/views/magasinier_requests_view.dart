import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MagasinierRequestsView extends StatefulWidget {
  const MagasinierRequestsView({super.key});

  @override
  State<MagasinierRequestsView> createState() => _MagasinierRequestsViewState();
}

class _MagasinierRequestsViewState extends State<MagasinierRequestsView> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  List<DemandeRechange> _demandes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _demandes = await _apiService.getAllDemandesRechange();
      // Sort by date descending
      _demandes.sort((a, b) => b.dateDemande.compareTo(a.dateDemande));
    } catch (e) {
      debugPrint('Error loading requests: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateStatus(DemandeRechange demande, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateDemandeStatut(demande.idDemande, newStatus);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demande ${newStatus == "approuvee" ? "approuvée" : "refusée"} avec succès'),
            backgroundColor: newStatus == "approuvee" ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Demandes de Pièces',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualiser',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tabs
        Container(
          width: 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.primaryBlue,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textGrey,
            tabs: const [
              Tab(text: 'En Attente'),
              Tab(text: 'Approuvées'),
              Tab(text: 'Archives'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList(_demandes.where((d) => d.statut == 'en_attente').toList()),
                _buildRequestsList(_demandes.where((d) => d.statut == 'approuvee').toList()),
                _buildRequestsList(_demandes.where((d) => d.statut == 'livree' || d.statut == 'refusee').toList()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRequestsList(List<DemandeRechange> requests) {
    if (requests.isEmpty) {
      return const Center(child: Text('Aucune demande dans cette catégorie.'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 2.5,
      ),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final d = requests[index];
        return _buildRequestCard(d);
      },
    );
  }

  Widget _buildRequestCard(DemandeRechange d) {
    Color statusColor;
    switch (d.statut) {
      case 'en_attente': statusColor = AppTheme.warningOrange; break;
      case 'approuvee': statusColor = AppTheme.primaryBlue; break;
      case 'livree': statusColor = AppTheme.successGreen; break;
      case 'refusee': statusColor = AppTheme.errorRed; break;
      default: statusColor = AppTheme.textGrey;
    }

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: AppTheme.primaryBlue, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Intervention #${d.idIntervention}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.statut.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            d.piece?.nom ?? 'Pièce inconnue',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Quantité: ${d.quantiteDemandee} ${d.piece?.unite ?? ""}',
            style: const TextStyle(color: AppTheme.textGrey),
          ),
          const Spacer(),
          if (d.statut == 'en_attente')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleUpdateStatus(d, 'refusee'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('REFUSER'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleUpdateStatus(d, 'approuvee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('APPROUVER'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
