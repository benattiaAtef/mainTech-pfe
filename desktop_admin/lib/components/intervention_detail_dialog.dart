import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class InterventionDetailDialog extends StatefulWidget {
  final Intervention intervention;
  final VoidCallback? onRefresh;

  const InterventionDetailDialog({
    super.key,
    required this.intervention,
    this.onRefresh,
  });

  @override
  State<InterventionDetailDialog> createState() => _InterventionDetailDialogState();
}

class _InterventionDetailDialogState extends State<InterventionDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isSaving = false;
  late Intervention _currentIntervention;

  // Form controllers for Rapport
  final _descriptionController = TextEditingController();
  final _causesController = TextEditingController();
  final _solutionsController = TextEditingController();
  final _travauxController = TextEditingController();
  final _observationsController = TextEditingController();
  final _tempsArretController = TextEditingController();
  String _typeTravail = 'MNP';
  String _etatFinal = 'Opérationnel';
  List<Map<String, dynamic>> _piecesRechange = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentIntervention = widget.intervention;
    _initRapportFields();
  }

  void _initRapportFields() {
    if (_currentIntervention.rapport != null) {
      final rapport = _currentIntervention.rapport!;
      _descriptionController.text = rapport.descriptionPanne ?? "";
      _causesController.text = rapport.causes ?? "";
      _solutionsController.text = rapport.solutions ?? "";
      _travauxController.text = rapport.travauxEffectues ?? "";
      _observationsController.text = rapport.observations ?? "";
      _tempsArretController.text = rapport.tempsArret?.toString() ?? "";
      _typeTravail = rapport.typeTravail ?? 'MNP';
      _etatFinal = rapport.etatFinal ?? 'Opérationnel';
      if (rapport.piecesRechange != null) {
        _piecesRechange = List<Map<String, dynamic>>.from(
          rapport.piecesRechange!.map((p) => Map<String, dynamic>.from(p as Map)),
        );
      }
    } else {
      _descriptionController.text = _currentIntervention.panne?.typePanneId.toString() ?? "";
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _causesController.dispose();
    _solutionsController.dispose();
    _travauxController.dispose();
    _observationsController.dispose();
    _tempsArretController.dispose();
    super.dispose();
  }

  Future<void> _saveRapport() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'description_panne': _descriptionController.text,
        'causes': _causesController.text,
        'solutions': _solutionsController.text,
        'travaux_effectues': _travauxController.text,
        'type_travail': _typeTravail,
        'etat_final': _etatFinal,
        'pieces_rechange': _piecesRechange,
        'temps_arret': int.tryParse(_tempsArretController.text),
        'observations': _observationsController.text,
      };

      await _apiService.soumettreRapport(_currentIntervention.id, data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapport enregistré avec succès'), backgroundColor: AppTheme.successGreen),
        );
        if (widget.onRefresh != null) widget.onRefresh!();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _terminerIntervention() async {
    setState(() => _isSaving = true);
    try {
      await _apiService.terminerIntervention(_currentIntervention.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention terminée'), backgroundColor: AppTheme.successGreen),
        );
        if (widget.onRefresh != null) widget.onRefresh!();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _annulerIntervention() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'annulation'),
        content: const Text('Voulez-vous vraiment annuler cette intervention ? Le technicien redeviendra disponible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NON')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('OUI, ANNULER'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await _apiService.annulerIntervention(_currentIntervention.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention annulée'), backgroundColor: AppTheme.warningOrange),
        );
        if (widget.onRefresh != null) widget.onRefresh!();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_currentIntervention.statut);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Intervention #${_currentIntervention.id}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        _buildStatusBadge(_currentIntervention.statut, statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Machine: ${_currentIntervention.panne?.machine?.nom ?? "N/A"} - ${_currentIntervention.panne?.machine?.localisation ?? "N/A"}',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'DÉTAILS GÉNÉRAUX'),
                Tab(text: 'MACHINE & PANNE'),
                Tab(text: 'RAPPORT TECHNIQUE'),
              ],
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textGrey,
              indicatorColor: AppTheme.primaryBlue,
              indicatorWeight: 3,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildMachinePanneTab(),
                  _buildRapportTab(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildInfoSection('Personnel', [
              _buildInfoRow(Icons.person, 'Technicien', 
                _currentIntervention.technicien != null 
                  ? '${_currentIntervention.technicien!.prenom} ${_currentIntervention.technicien!.nom}' 
                  : 'Chargement...'),
              _buildInfoRow(Icons.email, 'Email', _currentIntervention.technicien?.email ?? 'N/A'),
              _buildInfoRow(Icons.groups, 'Groupe', 'Groupe ${_currentIntervention.technicien?.idGroupe ?? "N/A"}'),
            ]),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _buildInfoSection('Dates et Statuts', [
              _buildInfoRow(Icons.calendar_today, 'Date de début', DateFormat('dd/MM/yyyy HH:mm').format(_currentIntervention.dateDebut)),
              _buildInfoRow(Icons.check_circle_outline, 'Date acceptation', 
                _currentIntervention.dateAcceptation != null ? DateFormat('dd/MM/yyyy HH:mm').format(_currentIntervention.dateAcceptation!) : 'Non acceptée'),
              _buildInfoRow(Icons.qr_code_scanner, 'Date scan QR', 
                _currentIntervention.dateScanQr != null ? DateFormat('dd/MM/yyyy HH:mm').format(_currentIntervention.dateScanQr!) : 'Non scannée'),
              _buildInfoRow(Icons.flag, 'Date de fin', 
                _currentIntervention.dateFin != null ? DateFormat('dd/MM/yyyy HH:mm').format(_currentIntervention.dateFin!) : 'En cours'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMachinePanneTab() {
    final machine = _currentIntervention.panne?.machine;
    final panne = _currentIntervention.panne;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildInfoSection('Informations Machine', [
              _buildInfoRow(Icons.precision_manufacturing, 'Nom', machine?.nom ?? 'N/A'),
              _buildInfoRow(Icons.location_on, 'Localisation', machine?.localisation ?? 'N/A'),
              _buildInfoRow(Icons.qr_code, 'Code QR', machine?.qrCode ?? 'N/A'),
              _buildInfoRow(Icons.tag, 'Numéro de Série', machine?.numSerie ?? 'N/A'),
              _buildInfoRow(Icons.history, 'Interv. Totales', 'Non dispo.'),
            ]),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _buildInfoSection('Détails de la Panne', [
              _buildInfoRow(Icons.report_problem, 'ID Panne', '#${panne?.id ?? "N/A"}'),
              _buildInfoRow(Icons.priority_high, 'Priorité', panne?.priorite.toString() ?? 'N/A'),
              _buildInfoRow(Icons.info_outline, 'Statut Panne', panne?.statut.toUpperCase() ?? 'N/A'),
              _buildInfoRow(Icons.event, 'Déclarée le', panne?.dateDeclaration != null ? DateFormat('dd/MM/yyyy HH:mm').format(panne!.dateDeclaration!) : 'N/A'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildRapportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTENU DU RAPPORT TECHNIQUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDropdownField('Type de travail', ['MCP', 'MNP', 'AUT'], _typeTravail, (val) => setState(() => _typeTravail = val!))),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdownField('État final', ['Opérationnel', 'Dégradé', 'Hors Service'], _etatFinal, (val) => setState(() => _etatFinal = val!))),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('Temps d\'arrêt (min)', _tempsArretController, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Description des constatations', _descriptionController, maxLines: 3),
          const SizedBox(height: 16),
          _buildTextField('Causes identifiées', _causesController, maxLines: 3),
          const SizedBox(height: 16),
          _buildTextField('Solutions apportées', _solutionsController, maxLines: 3),
          const SizedBox(height: 16),
          _buildTextField('Travaux effectués', _travauxController, maxLines: 3),
          const SizedBox(height: 16),
          _buildTextField('Observations / Conclusion', _observationsController, maxLines: 3),
          const SizedBox(height: 24),
          const Text('PIÈCES DE RECHANGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ..._piecesRechange.asMap().entries.map((e) => _buildPieceItem(e.key, e.value)),
          TextButton.icon(
            onPressed: () => setState(() => _piecesRechange.add({'part_name': '', 'quantity': 1})),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une pièce'),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceItem(int index, Map<String, dynamic> piece) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: piece['part_name'],
              decoration: const InputDecoration(hintText: 'Nom de la pièce', isDense: true),
              onChanged: (val) => piece['part_name'] = val,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: piece['quantity']?.toString(),
              decoration: const InputDecoration(hintText: 'Qté', isDense: true),
              keyboardType: TextInputType.number,
              onChanged: (val) => piece['quantity'] = int.tryParse(val) ?? 1,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorRed),
            onPressed: () => setState(() => _piecesRechange.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    bool isTerminee = _currentIntervention.statut == 'terminee';
    bool canModify = !isTerminee;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (canModify) ...[
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _annulerIntervention,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('ANNULER L\'INTERVENTION'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              side: const BorderSide(color: AppTheme.errorRed),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _terminerIntervention,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('MARQUER TERMINÉE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.successGreen,
              side: const BorderSide(color: AppTheme.successGreen),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveRapport,
          icon: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
          label: Text(isTerminee ? 'MODIFIER LE RAPPORT' : 'ENREGISTRER LE RAPPORT'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textGrey),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: AppTheme.textGrey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> options, String value, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14)))).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en_attente': return AppTheme.warningOrange;
      case 'en_cours': return AppTheme.primaryBlue;
      case 'terminee': return AppTheme.successGreen;
      case 'annulee': return AppTheme.errorRed;
      default: return AppTheme.textGrey;
    }
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
