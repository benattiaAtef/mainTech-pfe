import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MagasinManagementScreen extends StatefulWidget {
  const MagasinManagementScreen({super.key});

  @override
  State<MagasinManagementScreen> createState() => _MagasinManagementScreenState();
}

class _MagasinManagementScreenState extends State<MagasinManagementScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<PieceRechange> _pieces = [];
  List<DemandeRechange> _demandes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pieces = await _apiService.getPieces();
      final demandes = await _apiService.getAllDemandesRechange();
      setState(() {
        _pieces = pieces;
        _demandes = demandes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPieceDialog() {
    final refController = TextEditingController();
    final nomController = TextEditingController();
    final descController = TextEditingController();
    final qteController = TextEditingController(text: '0');
    final uniteController = TextEditingController(text: 'pcs');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle Pièce', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: refController, decoration: const InputDecoration(labelText: 'Référence')),
                const SizedBox(height: 12),
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 12),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextField(controller: qteController, decoration: const InputDecoration(labelText: 'Quantité Initiale'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: uniteController, decoration: const InputDecoration(labelText: 'Unité (pcs, L, m, kg)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _apiService.createPiece({
                    'reference': refController.text,
                    'nom': nomController.text,
                    'description': descController.text,
                    'quantite_stock': int.tryParse(qteController.text) ?? 0,
                    'unite': uniteController.text,
                  });
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 45)),
              child: const Text('CRÉER'),
            ),
          ],
        );
      },
    );
  }

  void _showEditPieceDialog(PieceRechange piece) {
    final nomController = TextEditingController(text: piece.nom);
    final descController = TextEditingController(text: piece.description);
    final qteController = TextEditingController(text: piece.quantiteStock.toString());
    final uniteController = TextEditingController(text: piece.unite);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier: ${piece.reference}', style: const TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 12),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextField(controller: qteController, decoration: const InputDecoration(labelText: 'Quantité Stock'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: uniteController, decoration: const InputDecoration(labelText: 'Unité')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _apiService.updatePiece(piece.id, {
                    'nom': nomController.text,
                    'description': descController.text,
                    'quantite_stock': int.tryParse(qteController.text) ?? 0,
                    'unite': uniteController.text,
                  });
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 45)),
              child: const Text('ENREGISTRER'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDemandeStatut(DemandeRechange demande, String statut) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateDemandeStatut(demande.idDemande, statut);
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          title: const Text('Gestion Magasin', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.brown[700],
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.6),
            indicatorColor: Colors.white,
            tabs: const [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_rounded), SizedBox(width: 8), Text("STOCK")])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.pending_actions_rounded), SizedBox(width: 8), Text("DEMANDES")])),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.brown))
            : TabBarView(
                children: [
                  _buildStockTab(),
                  _buildDemandesTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildStockTab() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pieces.length,
        itemBuilder: (context, index) {
          final piece = _pieces[index];
          final bool isOutOfStock = piece.quantiteStock <= 0;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.brown[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings_suggest_outlined, color: Colors.brown[700]),
              ),
              title: Text(piece.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Réf: ${piece.reference}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${piece.quantiteStock} ${piece.unite}',
                    style: TextStyle(
                      color: isOutOfStock ? AppTheme.errorRed : AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.brown, size: 28),
                onPressed: () => _showEditPieceDialog(piece),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.brown[700],
        onPressed: _showAddPieceDialog,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("AJOUTER PIÈCE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDemandesTab() {
    if (_demandes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_actions_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text("Aucune demande de pièce de rechange", style: TextStyle(color: AppTheme.textGrey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _demandes.length,
      itemBuilder: (context, index) {
        final demande = _demandes[index];
        final piece = demande.piece;
        
        Color statusColor;
        switch (demande.statut) {
          case 'en_attente': statusColor = AppTheme.warningOrange; break;
          case 'approuvee': statusColor = AppTheme.primaryBlue; break;
          case 'livree': statusColor = AppTheme.successGreen; break;
          case 'refusee': statusColor = AppTheme.errorRed; break;
          default: statusColor = AppTheme.textGrey;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.shopping_cart_outlined, color: statusColor, size: 28),
                ),
                title: Text(piece?.nom ?? 'Pièce inconnue', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Intervention ID: ${demande.idIntervention}', style: const TextStyle(fontSize: 14)),
                    Text('Quantité: ${demande.quantiteDemandee} ${piece?.unite ?? ""}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        demande.statut.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              if (demande.statut == 'en_attente')
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateDemandeStatut(demande, 'refusee'),
                          icon: const Icon(Icons.close_rounded, color: AppTheme.errorRed),
                          label: const Text("REFUSER", style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorRed),
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateDemandeStatut(demande, 'approuvee'),
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                          label: const Text("APPROUVER", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
