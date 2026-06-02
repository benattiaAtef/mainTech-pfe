import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PanneDetailDialog extends StatefulWidget {
  final Map<String, dynamic> panne;
  final VoidCallback? onRefresh;

  const PanneDetailDialog({
    super.key,
    required this.panne,
    this.onRefresh,
  });

  @override
  State<PanneDetailDialog> createState() => _PanneDetailDialogState();
}

class _PanneDetailDialogState extends State<PanneDetailDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _machineDetails;
  Map<String, dynamic>? _typePanneDetails;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      // Load machine details
      final machineId = widget.panne['id_machine'];
      if (machineId != null) {
        try {
          final machine = await _apiService.getMachineDetail(machineId);
          _machineDetails = {
            'nom': machine.nom,
            'localisation': machine.localisation,
            'qr_code': machine.qrCode,
            'num_serie': machine.numSerie,
            'statut': machine.statut,
            'fonction': machine.fonction,
          };
        } catch (_) {}
      }

      // Load type panne details
      try {
        final types = await _apiService.getTypePannes();
        final typePanneId = widget.panne['id_type_panne'];
        _typePanneDetails = types.firstWhere(
          (t) => t['id_type_panne'] == typePanneId,
          orElse: () => <String, dynamic>{},
        );
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panne = widget.panne;
    final priority = panne['priorite'] ?? 3;
    final statut = panne['statut'] ?? 'Inconnu';
    final statusColor = _getStatusColor(statut);
    final priorityInfo = _getPriorityInfo(priority);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Panne #${panne['id_panne']}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          _buildStatusBadge(statut, statusColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _machineDetails != null
                            ? 'Machine: ${_machineDetails!['nom']} - ${_machineDetails!['localisation']}'
                            : 'Machine #${panne['id_machine']}',
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Priority & Status Banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              priorityInfo['color'].withOpacity(0.05),
                              priorityInfo['color'].withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: priorityInfo['color'].withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: priorityInfo['color'].withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.flag_rounded, color: priorityInfo['color'], size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Priorité: ${priorityInfo['label']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: priorityInfo['color'],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Niveau $priority / 5',
                                    style: TextStyle(color: priorityInfo['color'].withOpacity(0.7), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                statut.toString().toUpperCase(),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Two-column info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Machine Info
                          Expanded(
                            child: _buildInfoSection(
                              'Informations Machine',
                              Icons.precision_manufacturing,
                              [
                                _buildInfoRow(Icons.label, 'Nom', _machineDetails?['nom'] ?? 'Machine #${panne['id_machine']}'),
                                _buildInfoRow(Icons.location_on, 'Localisation', _machineDetails?['localisation'] ?? 'N/A'),
                                _buildInfoRow(Icons.qr_code, 'Code QR', _machineDetails?['qr_code'] ?? 'N/A'),
                                _buildInfoRow(Icons.numbers, 'N° de Série', _machineDetails?['num_serie'] ?? 'N/A'),
                                _buildInfoRow(Icons.settings, 'Fonction', _machineDetails?['fonction'] ?? 'N/A'),
                                _buildInfoRow(Icons.circle, 'Statut Machine', _machineDetails?['statut'] ?? 'N/A'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right: Panne Info
                          Expanded(
                            child: _buildInfoSection(
                              'Détails de la Panne',
                              Icons.report_problem,
                              [
                                _buildInfoRow(Icons.tag, 'ID Panne', '#${panne['id_panne']}'),
                                _buildInfoRow(Icons.category, 'Type de Panne',
                                    _typePanneDetails != null && _typePanneDetails!.isNotEmpty
                                        ? _typePanneDetails!['nom_panne'] ?? 'Type #${panne['id_type_panne']}'
                                        : 'Type #${panne['id_type_panne']}'),
                                _buildInfoRow(Icons.priority_high, 'Priorité', priorityInfo['label']),
                                _buildInfoRow(Icons.info_outline, 'Statut', statut.toString().toUpperCase()),
                                _buildInfoRow(Icons.calendar_today, 'Date de Déclaration',
                                    panne['date_declaration'] != null
                                        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(panne['date_declaration'].toString()).toLocal())
                                        : 'N/A'),
                                _buildInfoRow(Icons.person, 'ID Superviseur', '#${panne['id_superviseur'] ?? 'N/A'}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Bottom actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('FERMER'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData titleIcon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(titleIcon, size: 20, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
          ],
        ),
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
          Icon(icon, size: 18, color: AppTheme.textGrey),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toString().toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toString().toLowerCase()) {
      case 'en_attente':
        return AppTheme.warningOrange;
      case 'en_cours':
        return AppTheme.primaryBlue;
      case 'resolue':
        return AppTheme.successGreen;
      case 'a_valider':
        return Colors.purple;
      default:
        return AppTheme.textGrey;
    }
  }

  Map<String, dynamic> _getPriorityInfo(int priority) {
    switch (priority) {
      case 1:
        return {'label': 'Critique', 'color': AppTheme.errorRed};
      case 2:
        return {'label': 'Haute', 'color': Colors.orange};
      case 3:
        return {'label': 'Moyenne', 'color': Colors.blue};
      case 4:
        return {'label': 'Basse', 'color': AppTheme.successGreen};
      case 5:
        return {'label': 'Très Basse', 'color': AppTheme.textGrey};
      default:
        return {'label': 'Basse', 'color': AppTheme.successGreen};
    }
  }
}
