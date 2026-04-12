import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class RapportInterventionScreen extends StatefulWidget {
  final Intervention intervention;

  const RapportInterventionScreen({super.key, required this.intervention});

  @override
  State<RapportInterventionScreen> createState() => _RapportInterventionScreenState();
}

class _RapportInterventionScreenState extends State<RapportInterventionScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  String _typeTravail = 'MNP'; 
  String _etatFinal = 'Opérationnel';
  final _descriptionController = TextEditingController();
  final _causesController = TextEditingController();
  final _solutionsController = TextEditingController();
  final _travauxController = TextEditingController();
  final _observationsController = TextEditingController();
  final _tempsArretController = TextEditingController();

  Map<String, String> _codesDefaut = {
    'what': '',
    'why': '',
    'where': '',
  };

  List<Map<String, dynamic>> _piecesRechange = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill data if a report already exists (modifying an existing report)
    if (widget.intervention.rapport != null) {
      final rapport = widget.intervention.rapport!;
      _descriptionController.text = rapport.descriptionPanne ?? "";
      _causesController.text = rapport.causes ?? "";
      _solutionsController.text = rapport.solutions ?? "";
      _travauxController.text = rapport.travauxEffectues ?? "";
      _observationsController.text = rapport.observations ?? "";
      if (rapport.tempsArret != null) {
        _tempsArretController.text = rapport.tempsArret.toString();
      }
      _typeTravail = rapport.typeTravail ?? 'MNP';
      _etatFinal = rapport.etatFinal ?? 'Opérationnel';
      
      if (rapport.codesDefaut != null) {
        _codesDefaut = Map<String, String>.from(rapport.codesDefaut!.map((key, value) => MapEntry(key, value.toString())));
      }
      
      if (rapport.piecesRechange != null) {
        _piecesRechange = List<Map<String, dynamic>>.from(rapport.piecesRechange!);
      }
    } else {
       _descriptionController.text = widget.intervention.panne?.typePanneId.toString() ?? "";
    }
  }

  Future<void> _submitRapport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final data = {
        'description_panne': _descriptionController.text,
        'causes': _causesController.text,
        'solutions': _solutionsController.text,
        'travaux_effectues': _travauxController.text,
        'type_travail': _typeTravail,
        'etat_final': _etatFinal,
        'codes_defaut': _codesDefaut,
        'pieces_rechange': _piecesRechange,
        'temps_arret': int.tryParse(_tempsArretController.text),
        'observations': _observationsController.text,
      };

      await _apiService.soumettreRapport(widget.intervention.id, data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rapport enregistré avec succès')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addPiece() {
    setState(() {
      _piecesRechange.add({'part_name': '', 'quantity': 1});
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isTerminee = widget.intervention.statut == 'terminee';
    String documentTitle = isTerminee ? "MODIFICATION DU RAPPORT" : "SAISIE DU RAPPORT";

    return Scaffold(
      backgroundColor: Colors.grey[300], // Background simulating a desk
      appBar: AppBar(
        title: Text(documentTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _submitRapport,
              tooltip: 'Enregistrer',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDocumentHeader(),
                    _buildFicheTechnique(),
                    _buildDocumentSection('1. DESCRIPTION DE LA PANNE / ANOMALIE', _buildTextField(_descriptionController, 'Saisir les constatations...')),
                    _buildDocumentSection('2. CAUSES PROBABLES IDENTIFIÉES', _buildTextField(_causesController, 'Saisir les causes...')),
                    _buildDocumentSection('3. SOLUTIONS APPORTÉES ET TRAVAUX', Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_solutionsController, 'Saisir les solutions...'),
                        const Divider(color: Colors.black26),
                        _buildTextField(_travauxController, 'Détail des réparations / actes effectués...'),
                      ],
                    )),
                    _buildDocumentSection('4. MODALITÉS D\'INTERVENTION', Column(
                      children: [
                        _buildRowField('TYPE DE TRAVAIL:', _buildTypeTravailSelector()),
                        const Divider(color: Colors.black26),
                        _buildRowField('ÉTAT FINAL DE L\'ÉQUIPEMENT:', _buildEtatFinalSelector()),
                        const Divider(color: Colors.black26),
                        _buildRowField('TEMPS D\'ARRÊT ESTIMÉ (MIN):', SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _tempsArretController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        )),
                      ],
                    )),
                    _buildDocumentSection('5. PIÈCES DE RECHANGE UTILISÉES', Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_piecesRechange.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Aucune pièce renseignée.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          ),
                        ..._piecesRechange.asMap().entries.map((entry) => _buildPieceItem(entry.key, entry.value)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addPiece, 
                            icon: const Icon(Icons.add_box, color: Colors.black87), 
                            label: const Text('Ajouter une ligne', style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                      ],
                    )),
                    _buildDocumentSection('6. OBSERVATIONS ET CONCLUSION', _buildTextField(_observationsController, 'Notes complémentaires, remarques...')),
                    _buildSignatureSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentHeader() {
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RAPPORT D\'INTERVENTION TECHNIQUE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('Document N°: INT-${widget.intervention.id.toString().padLeft(6, '0')}', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Date: ${dateFormat.format(now)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Heure: ${timeFormat.format(now)}', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                child: Text(
                  widget.intervention.statut == 'terminee' ? 'CLÔTURÉ' : 'EN COURS', 
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFicheTechnique() {
    final machine = widget.intervention.panne?.machine;
    final technicien = widget.intervention.technicien;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[200],
            width: double.infinity,
            child: const Text('INFORMATIONS GÉNÉRALES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoText('Équipement ciblée:', machine?.nom ?? 'N/A'),
                      const SizedBox(height: 4),
                      _buildInfoText('Numéro de série:', machine?.numSerie ?? 'N/A'),
                      const SizedBox(height: 4),
                      _buildInfoText('Localisation:', machine?.localisation ?? 'N/A'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoText('Technicien assigné:', '${technicien?.prenom ?? ''} ${technicien?.nom ?? ''}'.trim().isEmpty ? 'N/A' : '${technicien?.prenom} ${technicien?.nom}'),
                      const SizedBox(height: 4),
                      _buildInfoText('Date de début:', DateFormat('dd/MM/yyyy HH:mm').format(widget.intervention.dateDebut.toLocal())),
                      const SizedBox(height: 4),
                      _buildInfoText('Priorité panne:', '${widget.intervention.panne?.priorite ?? 3}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 13),
        children: [
          TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildDocumentSection(String title, Widget content) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[100],
            width: double.infinity,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      maxLines: null,
      minLines: 2,
      style: const TextStyle(fontSize: 14, height: 1.5, fontFamily: 'Courier'), // Gives a typed document look
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontStyle: FontStyle.italic),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildRowField(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(flex: 3, child: field),
        ],
      ),
    );
  }

  Widget _buildTypeTravailSelector() {
    return Wrap(
      spacing: 16,
      children: [
        _buildRadioOption('MCP (Planifié)', 'MCP', _typeTravail, (val) => setState(() => _typeTravail = val!)),
        _buildRadioOption('MNP (Non Planifié)', 'MNP', _typeTravail, (val) => setState(() => _typeTravail = val!)),
        _buildRadioOption('AUT (Autre)', 'AUT', _typeTravail, (val) => setState(() => _typeTravail = val!)),
      ],
    );
  }

  Widget _buildEtatFinalSelector() {
    return Wrap(
      spacing: 16,
      children: [
        _buildRadioOption('Opérationnel', 'Opérationnel', _etatFinal, (val) => setState(() => _etatFinal = val!)),
        _buildRadioOption('Dégradé', 'Dégradé', _etatFinal, (val) => setState(() => _etatFinal = val!)),
        _buildRadioOption('Hors Service', 'Hors Service', _etatFinal, (val) => setState(() => _etatFinal = val!)),
      ],
    );
  }

  Widget _buildRadioOption(String label, String value, String groupValue, void Function(String?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          activeColor: Colors.black,
        ),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildPieceItem(int index, Map<String, dynamic> piece) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('${index + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: TextFormField(
              initialValue: piece['part_name'],
              style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Désignation de la pièce',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
              ),
              onChanged: (val) => piece['part_name'] = val,
            ),
          ),
          const SizedBox(width: 16),
          const Text('Qté: '),
          SizedBox(
            width: 60,
            child: TextFormField(
              initialValue: piece['quantity']?.toString(),
              style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
              ),
              onChanged: (val) => piece['quantity'] = int.tryParse(val) ?? 1,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.black54, size: 20),
            onPressed: () {
              setState(() {
                _piecesRechange.removeAt(index);
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('VISA TECHNICIEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 60),
                Container(height: 1, color: Colors.black),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('VISA RESPONSABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 60),
                Container(height: 1, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
