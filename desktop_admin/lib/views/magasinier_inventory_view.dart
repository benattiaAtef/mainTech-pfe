import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class MagasinierInventoryView extends StatefulWidget {
  const MagasinierInventoryView({super.key});

  @override
  State<MagasinierInventoryView> createState() => _MagasinierInventoryViewState();
}

class _MagasinierInventoryViewState extends State<MagasinierInventoryView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<PieceRechange> _pieces = [];
  List<PieceRechange> _filteredPieces = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterPieces);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _pieces = await _apiService.getPieces();
      _filteredPieces = List.from(_pieces);
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterPieces() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPieces = _pieces.where((p) {
        return p.nom.toLowerCase().contains(query) || 
               p.reference.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showAddDialog() {
    final refController = TextEditingController();
    final nomController = TextEditingController();
    final descController = TextEditingController();
    final qteController = TextEditingController();
    final uniteController = TextEditingController(text: 'pcs');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une Pièce', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(refController, 'Référence', Icons.tag),
              _buildField(nomController, 'Nom de la pièce', Icons.title),
              _buildField(descController, 'Description (Optionnel)', Icons.description),
              _buildField(qteController, 'Quantité initiale', Icons.inventory, keyboardType: TextInputType.number),
              _buildField(uniteController, 'Unité (pcs, L, m, kg)', Icons.straighten),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('CRÉER'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(PieceRechange piece) {
    final nomController = TextEditingController(text: piece.nom);
    final descController = TextEditingController(text: piece.description);
    final qteController = TextEditingController(text: piece.quantiteStock.toString());
    final uniteController = TextEditingController(text: piece.unite);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier: ${piece.reference}', style: const TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(nomController, 'Nom de la pièce', Icons.title),
              _buildField(descController, 'Description', Icons.description),
              _buildField(qteController, 'Quantité en Stock', Icons.inventory, keyboardType: TextInputType.number),
              _buildField(uniteController, 'Unité', Icons.straighten),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
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
              'Gestion du Stock',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une Pièce'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Rechercher par nom ou référence...',
              prefixIcon: Icon(Icons.search_rounded),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 32),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_filteredPieces.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: Text('Aucune pièce trouvée.', style: TextStyle(color: AppTheme.textGrey)),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 2.2,
            ),
            itemCount: _filteredPieces.length,
            itemBuilder: (context, index) {
              final piece = _filteredPieces[index];
              return _buildPieceCard(piece);
            },
          ),
      ],
    );
  }

  Widget _buildPieceCard(PieceRechange piece) {
    final bool isLowStock = piece.quantiteStock < 5;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLowStock ? AppTheme.errorRed.withOpacity(0.1) : AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              FontAwesomeIcons.gears,
              color: isLowStock ? AppTheme.errorRed : AppTheme.successGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  piece.reference,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  piece.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${piece.quantiteStock} ${piece.unite}',
                      style: TextStyle(
                        color: isLowStock ? AppTheme.errorRed : AppTheme.successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLowStock)
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 16),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditDialog(piece),
            icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 28),
            tooltip: 'Modifier le stock',
          ),
        ],
      ),
    );
  }
}
