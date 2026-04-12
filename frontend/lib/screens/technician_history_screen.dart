import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'rapport_intervention_screen.dart';

class TechnicianHistoryScreen extends StatefulWidget {
  final Technician technician;

  const TechnicianHistoryScreen({super.key, required this.technician});

  @override
  State<TechnicianHistoryScreen> createState() => _TechnicianHistoryScreenState();
}

class _TechnicianHistoryScreenState extends State<TechnicianHistoryScreen> {
  final _apiService = ApiService();
  late Future<List<Intervention>> _interventionsFuture;

  @override
  void initState() {
    super.initState();
    _interventionsFuture = _apiService.getTechnicianInterventions(widget.technician.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique Interventions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${widget.technician.prenom} ${widget.technician.nom}', 
              style: TextStyle(fontSize: 12, color: AppTheme.textGrey, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: FutureBuilder<List<Intervention>>(
        future: _interventionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Aucune intervention trouvée', style: TextStyle(color: AppTheme.textGrey)),
                ],
              ),
            );
          }

          final interventions = snapshot.data!.reversed.toList(); // Newest first

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: interventions.length,
            itemBuilder: (context, index) {
              final intervention = interventions[index];
              return _buildInterventionCard(intervention);
            },
          );
        },
      ),
    );
  }

  Widget _buildInterventionCard(Intervention intervention) {
    bool isCompleted = intervention.statut == 'terminee';
    Color statusColor = isCompleted ? AppTheme.successGreen : AppTheme.primaryBlue;
    if (intervention.statut == 'annulee') statusColor = AppTheme.errorRed;

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_outline : Icons.pending_outlined,
              color: statusColor,
            ),
          ),
          title: Text(
            intervention.panne?.machine?.nom ?? 'Machine inconnue',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            '${intervention.statut.toUpperCase()} • ${dateFormat.format(intervention.dateDebut)}',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.place_outlined, 'Localisation', intervention.panne?.machine?.localisation ?? 'N/A'),
                  _buildDetailRow(Icons.timer_outlined, 'Durée', intervention.dureeMinutes != null ? '${intervention.dureeMinutes!.toStringAsFixed(1)} min' : 'N/A'),
                  if (intervention.rapport != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryBlue),
                        label: const Text(
                          'Consulter / Modifier le Rapport',
                          style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.primaryBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RapportInterventionScreen(intervention: intervention),
                            ),
                          ).then((_) {
                            // Refresh the list when coming back
                            setState(() {
                              _interventionsFuture = _apiService.getTechnicianInterventions(widget.technician.id);
                            });
                          });
                        },
                      ),
                    ),
                  ] else if (isCompleted)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Aucun rapport détaillé soumis', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textGrey, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textGrey),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 13, color: AppTheme.textGrey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildRapportSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textGrey)),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
