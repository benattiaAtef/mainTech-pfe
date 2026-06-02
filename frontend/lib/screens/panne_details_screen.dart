import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'intervention_details_screen.dart';

class PanneDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> panne;

  const PanneDetailsScreen({super.key, required this.panne});

  @override
  State<PanneDetailsScreen> createState() => _PanneDetailsScreenState();
}

class _PanneDetailsScreenState extends State<PanneDetailsScreen> {
  final _apiService = ApiService();
  List<Intervention> _interventions = [];
  bool _isLoadingInterventions = true;

  @override
  void initState() {
    super.initState();
    _fetchInterventions();
  }

  Future<void> _fetchInterventions() async {
    setState(() => _isLoadingInterventions = true);
    try {
      final all = await _apiService.getInterventions();
      final panneId = widget.panne['id_panne'] as int? ?? 0;
      setState(() {
        _interventions = all.where((i) => i.idPanne == panneId).toList();
      });
    } catch (_) {
      // Silently fail — interventions are supplementary info
    } finally {
      if (mounted) setState(() => _isLoadingInterventions = false);
    }
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      String s = dateStr.toString();
      if (!s.endsWith('Z') && !s.contains('+')) s += 'Z';
      final dt = DateTime.parse(s).toLocal();
      return DateFormat('dd/MM/yyyy à HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Color _getPriorityColor(dynamic priority) {
    final p = (priority as int?) ?? 0;
    if (p >= 4) return AppTheme.errorRed;
    if (p >= 3) return AppTheme.warningOrange;
    return AppTheme.primaryBlue;
  }

  String _getPriorityLabel(dynamic priority) {
    final p = (priority as int?) ?? 0;
    if (p >= 5) return 'CRITIQUE';
    if (p >= 4) return 'ÉLEVÉE';
    if (p >= 3) return 'MOYENNE';
    if (p >= 2) return 'FAIBLE';
    return 'TRÈS FAIBLE';
  }

  Color _getStatutColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'en_attente': return AppTheme.warningOrange;
      case 'en_cours':   return AppTheme.primaryBlue;
      case 'resolu':     return AppTheme.successGreen;
      case 'a_valider':  return Colors.purple;
      case 'annulee':    return AppTheme.errorRed;
      default:           return AppTheme.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.panne;
    final priorite = p['priorite'] as int? ?? 0;
    final statut = (p['statut'] as String? ?? 'en_attente');
    final machine = p['machine'] as Map<String, dynamic>?;
    final typePanne = p['type_panne'] as Map<String, dynamic>?;
    final priorityColor = _getPriorityColor(priorite);
    final statutColor = _getStatutColor(statut);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Panne #${p['id_panne'] ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInterventions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status Header Card ───────────────────────────────────────
              _buildHeaderCard(priorite, statut, priorityColor, statutColor),
              const SizedBox(height: 20),

              // ── Machine Card ─────────────────────────────────────────────
              _buildSectionHeader('Équipement concerné', Icons.precision_manufacturing_outlined),
              const SizedBox(height: 10),
              _buildMachineCard(machine),
              const SizedBox(height: 20),

              // ── Failure Type Card ────────────────────────────────────────
              _buildSectionHeader('Type de défaillance', Icons.report_problem_outlined),
              const SizedBox(height: 10),
              _buildTypeCard(typePanne, p),
              const SizedBox(height: 20),

              // ── Linked Interventions ─────────────────────────────────────
              _buildSectionHeader(
                'Interventions liées (${_interventions.length})',
                Icons.engineering_outlined,
              ),
              const SizedBox(height: 10),
              _buildInterventionsSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Card ────────────────────────────────────────────────────────────
  Widget _buildHeaderCard(int priorite, String statut, Color priorityColor, Color statutColor) {
    final p = widget.panne;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [priorityColor, priorityColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.3),
            blurRadius: 16,
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
              // Priority badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'PRIORITÉ : ${_getPriorityLabel(priorite)} ($priorite/5)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  statut.toUpperCase().replaceAll('_', ' '),
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
            'Date de déclaration',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(p['date_declaration']),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (p['date_resolution'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Résolue le : ${_formatDate(p['date_resolution'])}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  // ── Machine Card ──────────────────────────────────────────────────────────
  Widget _buildMachineCard(Map<String, dynamic>? machine) {
    if (machine == null) {
      return _buildEmptyCard(
        'Machine #${widget.panne['id_machine'] ?? 'Inconnue'}',
        'Les détails de la machine ne sont pas disponibles.',
        Icons.settings_suggest_outlined,
      );
    }

    final isOp = (machine['statut'] as String? ?? '') == 'Opérationnel';
    return _buildInfoCard(children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryBlue, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine['nom'] as String? ?? 'Machine inconnue',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textDark),
                ),
                Text(
                  machine['fonction'] as String? ?? 'Équipement technique',
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      const Divider(height: 24, color: Color(0xFFF1F5F9)),
      _buildDetailRow('Localisation', machine['localisation'] as String? ?? 'N/A', Icons.location_on_outlined),
      _buildDetailRow('Numéro de série', machine['num_serie'] as String? ?? 'N/A', Icons.qr_code_rounded),
      _buildDetailRow(
        'Statut machine',
        machine['statut'] as String? ?? 'N/A',
        Icons.info_outline,
        color: isOp ? AppTheme.successGreen : AppTheme.errorRed,
      ),
    ]);
  }

  // ── Failure Type Card ─────────────────────────────────────────────────────
  Widget _buildTypeCard(Map<String, dynamic>? typePanne, Map<String, dynamic> p) {
    return _buildInfoCard(children: [
      _buildDetailRow(
        'Type de panne',
        typePanne != null ? (typePanne['nom_panne'] as String? ?? 'N/A') : 'Type #${p['id_type_panne'] ?? 'N/A'}',
        Icons.bug_report_outlined,
      ),
      if (typePanne != null && typePanne['gravite'] != null)
        _buildDetailRow('Gravité', typePanne['gravite'].toString(), Icons.trending_up_rounded,
            color: AppTheme.warningOrange),
      _buildDetailRow('Priorité numérique', '${p['priorite'] ?? 'N/A'} / 5', Icons.priority_high_rounded,
          color: _getPriorityColor(p['priorite'])),
      _buildDetailRow(
        'Statut signalement',
        (p['statut'] as String? ?? 'N/A').toUpperCase().replaceAll('_', ' '),
        Icons.assignment_outlined,
        color: _getStatutColor(p['statut'] as String? ?? ''),
      ),
      _buildDetailRow('Machine ID', '#${p['id_machine'] ?? 'N/A'}', Icons.tag),
    ]);
  }

  // ── Interventions Section ─────────────────────────────────────────────────
  Widget _buildInterventionsSection() {
    if (_isLoadingInterventions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    if (_interventions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Column(
          children: [
            Icon(Icons.engineering_outlined, size: 40, color: AppTheme.textGrey),
            SizedBox(height: 12),
            Text(
              'Aucune intervention liée à cette panne.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: _interventions.map((inter) {
        final statusColor = _interventionStatusColor(inter.statut);
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InterventionDetailsScreen(intervention: inter)),
          ).then((_) => _fetchInterventions()),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.engineering_rounded, color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intervention #${inter.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inter.technicien != null
                            ? '${inter.technicien!.prenom} ${inter.technicien!.nom}'
                            : 'Technicien non assigné',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        inter.statut.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textGrey),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _interventionStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'en_attente': return AppTheme.warningOrange;
      case 'acceptee':
      case 'en_cours':   return AppTheme.primaryBlue;
      case 'terminee':   return AppTheme.successGreen;
      case 'annulee':    return AppTheme.errorRed;
      default:           return AppTheme.textGrey;
    }
  }

  // ── Shared Helpers ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
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
      child: Column(children: children),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle, IconData icon) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textGrey, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
              ],
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
          Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
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
