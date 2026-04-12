import 'package:flutter/material.dart';
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
          const SnackBar(content: Text('Intervention terminée avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Détails Intervention #${widget.intervention.id}'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.report_problem, 'ID Panne', widget.intervention.idPanne.toString()),
            const Divider(height: 32),
            _buildInfoRow(Icons.history, 'Débuté le', widget.intervention.dateDebut.toLocal().toString().split('.')[0]),
            const Divider(height: 32),
            _buildInfoRow(Icons.assignment_ind, 'Type Affectation', widget.intervention.typeAffectation),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isEnding ? null : _endIntervention,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isEnding
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Marquer comme Terminée',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
