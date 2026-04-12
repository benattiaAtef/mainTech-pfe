import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class MagasinScreen extends StatefulWidget {
  final Intervention intervention;

  const MagasinScreen({super.key, required this.intervention});

  @override
  State<MagasinScreen> createState() => _MagasinScreenState();
}

class _MagasinScreenState extends State<MagasinScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<PieceRechange> _pieces = [];
  List<DemandeRechange> _demandes = [];
  String? _errorMessage;
  
  // Shopping Cart state: id_piece -> quantite
  final Map<int, int> _panier = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('DEBUG Magasin: Starting load for intervention ${widget.intervention.id}');
      
      // Fetch both in parallel
      final results = await Future.wait([
        _apiService.getPieces(),
        _apiService.getDemandesIntervention(widget.intervention.id),
      ]);
      
      final pieces = results[0] as List<PieceRechange>;
      final demandes = results[1] as List<DemandeRechange>;
      
      debugPrint('DEBUG Magasin: Successfully fetched ${pieces.length} pieces and ${demandes.length} demandes');

      if (mounted) {
        setState(() {
          _pieces = pieces;
          _demandes = demandes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG Magasin ERROR: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _ajouterAuPanier(PieceRechange piece) {
    setState(() {
      final currentQte = _panier[piece.id] ?? 0;
      if (currentQte < piece.quantiteStock) {
        _panier[piece.id] = currentQte + 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stock insuffisant"))
        );
      }
    });
  }

  void _retirerDuPanier(PieceRechange piece) {
    setState(() {
      final currentQte = _panier[piece.id] ?? 0;
      if (currentQte > 0) {
        _panier[piece.id] = currentQte - 1;
        if (_panier[piece.id] == 0) {
          _panier.remove(piece.id);
        }
      }
    });
  }

  Future<void> _submitPanier() async {
    if (_panier.isEmpty) return;

    final List<Map<String, dynamic>> batch = _panier.entries.map((e) => {
      'id_intervention': widget.intervention.id,
      'id_piece': e.key,
      'quantite_demandee': e.value,
    }).toList();

    setState(() => _isLoading = true);
    try {
      await _apiService.demanderPiecesBatch(batch);
      setState(() {
        _panier.clear();
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Demandes envoyées avec succès"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}"))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReceipt(DemandeRechange demande) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateDemandeStatut(demande.idDemande, 'livree');
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Réception confirmée et stock mis à jour"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}"))
        );
      }
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
          title: const Text('Catalogue Magasin', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
              tooltip: "Rafraîchir les données",
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined), SizedBox(width: 8), Text("PIÈCES")])),
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded), SizedBox(width: 8), Text("DEMANDES")])),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : TabBarView(
              children: [
                _buildCatalogueTab(),
                _buildDemandesTab(),
              ],
            ),
        bottomNavigationBar: _buildPanierBottomBar(),
      ),
    );
  }

  Widget _buildCatalogueTab() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    if (_pieces.isEmpty) {
      return _buildEmptyState(Icons.inventory_2_outlined, "Le catalogue est vide");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pieces.length,
      itemBuilder: (context, index) {
        final piece = _pieces[index];
        final bool isOutOfStock = piece.quantiteStock <= 0;
        final int inCart = _panier[piece.id] ?? 0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        piece.nom,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text("Réf: ${piece.reference}", style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.storage_rounded, size: 14, color: isOutOfStock ? AppTheme.errorRed : AppTheme.successGreen),
                          const SizedBox(width: 4),
                          Text(
                            isOutOfStock ? "Rupture de stock" : "Stock: ${piece.quantiteStock} ${piece.unite}",
                            style: TextStyle(
                              color: isOutOfStock ? AppTheme.errorRed : AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildPlusMinusButton(piece, inCart, isOutOfStock),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlusMinusButton(PieceRechange piece, int inCart, bool outOfStock) {
    if (outOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: const Text("INDISP.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }

    if (inCart == 0) {
      return ElevatedButton(
        onPressed: () => _ajouterAuPanier(piece),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text("AJOUTER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle, color: AppTheme.errorRed),
            onPressed: () => _retirerDuPanier(piece),
          ),
          Text("$inCart", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle, color: AppTheme.successGreen),
            onPressed: () => _ajouterAuPanier(piece),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandesTab() {
    if (_demandes.isEmpty) {
      return _buildEmptyState(Icons.history_rounded, "Aucune demande en cours");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _demandes.length,
      itemBuilder: (context, index) {
        final d = _demandes[index];
        final bool isApproved = d.statut == 'approuvee';
        
        Color statusColor;
        switch (d.statut) {
          case 'en_attente': statusColor = AppTheme.warningOrange; break;
          case 'approuvee': statusColor = AppTheme.primaryBlue; break;
          case 'livree': statusColor = AppTheme.successGreen; break;
          case 'refusee': statusColor = AppTheme.errorRed; break;
          default: statusColor = AppTheme.textGrey;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(d.piece?.nom ?? 'Pièce inconnue', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Quantité demandée: ${d.quantiteDemandee}"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    d.statut.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ),
              if (isApproved)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmReceipt(d),
                    icon: const Icon(Icons.verified_rounded, size: 20),
                    label: const Text("CONFIRMER LA RÉCEPTION"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanierBottomBar() {
    if (_panier.isEmpty) return const SizedBox.shrink();
    int total = _panier.values.fold(0, (sum, q) => sum + q);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _submitPanier,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_checkout_rounded),
              const SizedBox(width: 12),
              Text(
                "ENVOYER LES DEMANDES ($total)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textGrey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppTheme.textGrey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            const Text("Une erreur est survenue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? "Impossible de charger les données", textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textGrey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text("RÉESSAYER")),
          ],
        ),
      ),
    );
  }
}
