import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class InterventionDetailsScreen extends StatefulWidget {
  final Intervention intervention;

  const InterventionDetailsScreen({super.key, required this.intervention});

  @override
  State<InterventionDetailsScreen> createState() => _InterventionDetailsScreenState();
}

class _InterventionDetailsScreenState extends State<InterventionDetailsScreen> {
  final _apiService = ApiService();
  bool _isEnding = false;

  Future<void> _endIntervention() async {
    setState(() => _isEnding = true);
    try {
      await _apiService.terminerIntervention(widget.intervention.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Intervention terminée avec succès'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime.toLocal());
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en_attente':
        return AppTheme.warningOrange;
      case 'acceptee':
      case 'en_cours':
        return AppTheme.primaryBlue;
      case 'terminee':
        return AppTheme.successGreen;
      case 'annulee':
        return AppTheme.errorRed;
      default:
        return AppTheme.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inter = widget.intervention;
    final isPending = inter.statut.toLowerCase() == 'en_attente' || inter.statut.toLowerCase() == 'acceptee' || inter.statut.toLowerCase() == 'en_cours';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Intervention #${inter.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Status & General Info Card ──────────────────────────────
            _buildStatusCard(inter),
            const SizedBox(height: 20),

            // ─── Machine & Equipment Card ────────────────────────────────
            _buildSectionHeader('Équipement & Localisation', Icons.precision_manufacturing_outlined),
            const SizedBox(height: 10),
            _buildMachineCard(inter.panne?.machine),
            const SizedBox(height: 20),

            // ─── Technician Card ─────────────────────────────────────────
            _buildSectionHeader('Technicien Assigné', Icons.engineering_outlined),
            const SizedBox(height: 10),
            _buildTechnicianCard(inter.technicien),
            const SizedBox(height: 20),

            // ─── Failure (Panne) Card ────────────────────────────────────
            _buildSectionHeader('Détails du Signalement', Icons.warning_amber_rounded),
            const SizedBox(height: 10),
            _buildPanneCard(inter.panne),
            const SizedBox(height: 20),

            // ─── Intervention Report (Rapport) Card ──────────────────────
            if (inter.rapport != null) ...[
              _buildSectionHeader('Rapport d\'Intervention', Icons.assignment_outlined),
              const SizedBox(height: 10),
              _buildRapportCard(inter.rapport!),
              const SizedBox(height: 30),
            ],

            // ─── Action Button (Mark as Complete) ────────────────────────
            if (isPending) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isEnding ? null : _endIntervention,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isEnding
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Marquer comme Terminée',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(Intervention inter) {
    final statusColor = _getStatusColor(inter.statut);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'STATUT : ${inter.statut.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: inter.typeAffectation == 'urgente' ? Colors.red.shade900.withOpacity(0.4) : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  inter.typeAffectation == 'urgente' ? '🚨 URGENTE' : '🔧 STANDARD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Période d\'activité',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Début : ${_formatDateTime(inter.dateDebut)}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (inter.dateFin != null) ...[
            const SizedBox(height: 4),
            Text(
              'Fin : ${_formatDateTime(inter.dateFin)}',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Durée totale : ${inter.dureeMinutes?.toStringAsFixed(1) ?? 'N/A'} minutes',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMachineCard(Machine? machine) {
    if (machine == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Aucune machine associée à cette intervention.'),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.nom,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                    ),
                    Text(
                      machine.fonction ?? 'Machine Technique',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildDetailRow('Localisation', machine.localisation, Icons.location_on_outlined),
          _buildDetailRow('Numéro de Série', machine.numSerie ?? 'N/A', Icons.qr_code_rounded),
          _buildDetailRow('Groupe', machine.groupeNom ?? 'N/A', Icons.groups_outlined),
          _buildDetailRow('Statut Machine', machine.statut, Icons.info_outline, color: machine.statut == 'Opérationnel' ? AppTheme.successGreen : AppTheme.errorRed),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard(Technician? tech) {
    if (tech == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        padding: const EdgeInsets.all(16.0),
        child: const Row(
          children: [
            Icon(Icons.person_off_outlined, color: AppTheme.textGrey),
            SizedBox(width: 12),
            Text('Aucun technicien affecté pour le moment.', style: TextStyle(color: AppTheme.textGrey)),
          ],
        ),
      );
    }

    final String presenceText = tech.statutPresence == 'en_travail' ? 'En poste' : 'Hors poste';
    final Color presenceColor = tech.statutPresence == 'en_travail' ? AppTheme.successGreen : AppTheme.warningOrange;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                radius: 24,
                child: Text(
                  '${tech.prenom.isNotEmpty ? tech.prenom[0] : ''}${tech.nom.isNotEmpty ? tech.nom[0] : ''}'.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tech.prenom} ${tech.nom}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                    ),
                    Text(
                      tech.email,
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _buildDetailRow('Matricule', tech.matricule ?? 'N/A', Icons.badge_outlined),
          _buildDetailRow('Disponibilité', tech.statut.toUpperCase(), Icons.check_circle_outline, color: tech.statut == 'disponible' ? AppTheme.successGreen : AppTheme.warningOrange),
          _buildDetailRow('Présence', presenceText, Icons.lens, color: presenceColor),
        ],
      ),
    );
  }

  Widget _buildPanneCard(Panne? panne) {
    if (panne == null) {
      return const SizedBox.shrink();
    }

    final priorityColor = panne.priorite >= 4
        ? AppTheme.errorRed
        : panne.priorite >= 3
            ? AppTheme.warningOrange
            : AppTheme.primaryBlue;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDetailRow('ID Panne', '#${panne.id}', Icons.tag),
          _buildDetailRow('Signalée le', _formatDateTime(panne.dateDeclaration), Icons.calendar_month_outlined),
          _buildDetailRow(
            'Priorité',
            'Niveau ${panne.priorite} / 5',
            Icons.priority_high_rounded,
            color: priorityColor,
          ),
          _buildDetailRow(
            'Statut Signalement',
            panne.statut.toUpperCase(),
            Icons.info_outline,
            color: panne.statut == 'resolu' ? AppTheme.successGreen : AppTheme.warningOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildRapportCard(RapportPanne rapport) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Rapport ID', '#${rapport.id}', Icons.tag),
          _buildDetailRow('Date du Rapport', _formatDateTime(rapport.dateRapport), Icons.calendar_month_outlined),
          if (rapport.tempsArret != null)
            _buildDetailRow('Temps d\'arrêt machine', '${rapport.tempsArret} min', Icons.stop_circle_outlined, color: AppTheme.errorRed),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          _buildRapportSection('Description du problème', rapport.descriptionPanne),
          _buildRapportSection('Travaux effectués', rapport.travauxEffectues),
          _buildRapportSection('Causes détectées', rapport.causes),
          _buildRapportSection('Solutions apportées', rapport.solutions),
          _buildRapportSection('État final de la machine', rapport.etatFinal, isLast: true),
        ],
      ),
    );
  }

  Widget _buildRapportSection(String title, String? content, {bool isLast = false}) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.textGrey),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
