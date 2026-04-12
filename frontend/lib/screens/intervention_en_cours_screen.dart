import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/models.dart';
import 'rapport_intervention_screen.dart';
import 'qr_scanner_screen.dart';

class InterventionEnCoursScreen extends StatefulWidget {
  final Intervention intervention;

  const InterventionEnCoursScreen({super.key, required this.intervention});

  @override
  State<InterventionEnCoursScreen> createState() => _InterventionEnCoursScreenState();
}

class _InterventionEnCoursScreenState extends State<InterventionEnCoursScreen> {
  final _apiService = ApiService();
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _isStarted = false;

  @override
  void initState() {
    super.initState();
    _isStarted = widget.intervention.statut == 'en_cours';
    if (_isStarted) {
      _startTimer();
    }
  }

  void _startTimer() {
    final startTime = widget.intervention.dateDebut;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    if (_isStarted) _timer.cancel();
    super.dispose();
  }

  Future<void> _demarrer() async {
    // Navigate to QR scanner
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && result is String) {
      try {
        await _apiService.demarrerIntervention(widget.intervention.id, result);
        setState(() {
          _isStarted = true;
        });
        _startTimer();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur QR: $e')),
          );
        }
      }
    }
  }

  Future<void> _demanderRenfort() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander du renfort'),
        content: const Text('Souhaitez-vous demander l\'aide d\'un autre technicien pour cette panne ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('DEMANDER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _apiService.requestReinforcement(widget.intervention.id);
        if (mounted) {
          final statut = result['statut'] ?? 'ok';
          if (statut == 'en_attente') {
            // Aucun technicien dispo → renfort mis en file d'attente
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.hourglass_empty, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Aucun technicien disponible. Le renfort sera assigné automatiquement dès qu\'un technicien sera libre.')),
                ]),
                backgroundColor: const Color(0xFFD97706), // Orange
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (statut == 'deja_en_attente') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Une demande de renfort est déjà en attente.'),
                backgroundColor: Color(0xFF6366F1),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Demande de renfort envoyée ! Un technicien a été assigné.'),
                backgroundColor: Color(0xFF059669),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Intervention en cours',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Actif',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('IDENTIFICATION MACHINE'),
            const SizedBox(height: 16),
            _buildQRCard(),
            const SizedBox(height: 32),
            _buildSectionTitle('SUIVI DU TEMPS'),
            const SizedBox(height: 16),
            _buildTimeRow(),
            if (_isStarted) ...[
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RapportInterventionScreen(intervention: widget.intervention),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Accéder au rapport',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: _demanderRenfort,
                  icon: const Icon(Icons.group_add, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Demander du renfort',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2563EB), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildQRCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Icon(Icons.qr_code_2, size: 60, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scanner le code QR',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Validez l\'équipement avant de commencer',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          if (!_isStarted)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _demarrer,
                icon: const Icon(Icons.qr_code_scanner_outlined, color: Colors.white),
                label: const Text('Ouvrir le scanner', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle, color: Color(0xFF059669)),
                SizedBox(width: 8),
                Text(
                  'Équipement validé',
                  style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTimeCard(
            Icons.access_time, 
            widget.intervention.dateDebut.toLocal().toString().split(' ')[1].substring(0, 5), 
            'Heure de début',
            false
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimeCard(
            Icons.timer_outlined, 
            _formatDuration(_elapsed), 
            'Durée écoulée',
            true
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard(IconData icon, String time, String label, bool highlight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? Border.all(color: const Color(0xFF2563EB), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: highlight ? const Color(0xFF2563EB) : Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: highlight ? Colors.white : const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(
            time,
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold, 
              color: highlight ? const Color(0xFF2563EB) : const Color(0xFF1E293B)
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
