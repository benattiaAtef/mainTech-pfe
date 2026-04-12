import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class MagasinManagementView extends StatefulWidget {
  const MagasinManagementView({super.key});

  @override
  State<MagasinManagementView> createState() => _MagasinManagementViewState();
}

class _MagasinManagementViewState extends State<MagasinManagementView> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  List<PieceRechange> _inventory = [];
  List<DemandeRechange> _pendingDemands = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final results = await Future.wait([
        _apiService.getPieces(),
        _apiService.getAllDemandesRechange(),
      ]);
      setState(() {
        _inventory = results[0] as List<PieceRechange>;
        _pendingDemands = (results[1] as List<DemandeRechange>)
            .where((d) => d.statut == 'en_attente')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading magasin data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processDemand(int demandId, String newStatus) async {
    try {
      await _apiService.updateDemandeStatut(demandId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approuvee' ? 'Demande approuvée' : 'Demande rejetée'),
            backgroundColor: newStatus == 'approuvee' ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        );
      }
      _loadData();
    } catch (e) {
      debugPrint('Error processing demand: $e');
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestion du Magasin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                Text('Inventaire des pièces de rechange et validation des sorties', style: TextStyle(color: AppTheme.textGrey)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddPieceDialog,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Nouvelle Référence'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: [
            Tab(text: 'Inventaire (${_inventory.length})'),
            Tab(text: 'Demandes en attente (${_pendingDemands.length})'),
          ],
        ),
        const SizedBox(height: 24),
        
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInventoryTab(),
              _buildDemandsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    final filtered = _inventory.where((p) => 
      p.nom.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      p.reference.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Rechercher une pièce par nom ou référence...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textGrey),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columnSpacing: 40,
                  columns: const [
                    DataColumn(label: Text('REFERENCE', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('NOM', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('QUANTITÉ', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('DERNIÈRE MÀJ', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: filtered.map((piece) {
                    final bool isLowStock = piece.quantiteStock < 5;
                    return DataRow(cells: [
                      DataCell(Text(piece.reference, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(piece.nom)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isLowStock ? Colors.red : Colors.green).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${piece.quantiteStock} ${piece.unite}',
                          style: TextStyle(color: isLowStock ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                        ),
                      )),
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(piece.dateMaj))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.history, size: 18), onPressed: () {}),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_pendingDemands.isEmpty) {
      return const Center(child: Text('Aucune demande de pièce en attente.'));
    }

    return ListView.builder(
      itemCount: _pendingDemands.length,
      itemBuilder: (context, index) {
        final demand = _pendingDemands[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_cart_outlined, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${demand.piece?.nom ?? 'Pièce inconnue'} (Ref: ${demand.piece?.reference ?? 'N/A'})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quantité demandée: ${demand.quantiteDemandee} | Demandé le: ${DateFormat('dd/MM HH:mm').format(demand.dateDemande)}',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
                    ),
                    if (demand.commentaire != null)
                      Text('Note: ${demand.commentaire}', style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textGrey)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              OutlinedButton(
                onPressed: () => _processDemand(demand.idDemande, 'rejetee'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
                child: const Text('REJETER'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _processDemand(demand.idDemande, 'approuvee'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, elevation: 0),
                child: const Text('APPROUVER'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddPieceDialog() {
    final refCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'pcs');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle Référence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Référence (Unique)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom de la pièce')),
            Row(
              children: [
                Expanded(child: TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock Initial'), keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unité (ex: pcs, L, m)'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () async {
              await _apiService.createPiece({
                'reference': refCtrl.text,
                'nom': nameCtrl.text,
                'quantite_stock': int.tryParse(stockCtrl.text) ?? 0,
                'unite': unitCtrl.text,
              });
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('AJOUTER'),
          ),
        ],
      ),
    );
  }
}
