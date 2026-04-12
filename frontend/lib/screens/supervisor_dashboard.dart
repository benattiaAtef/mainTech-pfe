import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'qr_scanner_screen.dart';
import 'signalement_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;

  Future<void> _handleScan(BuildContext context) async {
    final String? qrCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (qrCode == null || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final machineData = await _apiService.scanQrCode(qrCode);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignalementScreen(machineData: machineData),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Machine non reconnue : ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            ),
          ),
        ),
        title: const Text(
          'Scanner QR',
          style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sensor_door_outlined, color: AppTheme.primaryBlue),
            onPressed: () => _showPresenceDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            if (_isProcessing)
              const CircularProgressIndicator()
            else ...[
              const Text(
                'Scanner un code QR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Appuyez sur le bouton ci-dessous\npour ouvrir la caméra et scanner votre\ncode QR.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _isProcessing ? null : () => _handleScan(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Scanner QR code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Future<void> _showPresenceDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ma Présence'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'en_travail'),
            child: const Row(children: [Icon(Icons.work, color: Colors.teal), SizedBox(width: 8), Text('En travail')]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'hors_travail'),
            child: const Row(children: [Icon(Icons.home, color: Colors.orange), SizedBox(width: 8), Text('Hors travail')]),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _apiService.updatePresence(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Présence mise à jour : $result')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}
