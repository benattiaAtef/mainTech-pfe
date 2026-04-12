import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PanneManagementScreen extends StatefulWidget {
  const PanneManagementScreen({super.key});

  @override
  State<PanneManagementScreen> createState() => _PanneManagementScreenState();
}

class _PanneManagementScreenState extends State<PanneManagementScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _pannes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPannes();
  }

  Future<void> _fetchPannes() async {
    setState(() => _isLoading = true);
    try {
      final pannes = await _apiService.getPannes();
      setState(() => _pannes = pannes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toutes les Pannes'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPannes,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pannes.length,
                itemBuilder: (context, index) {
                  final panne = _pannes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_rounded,
                        color: _getPriorityColor(panne['priorite']),
                      ),
                      title: Text('Panne #${panne['id_panne']}'),
                      subtitle: Text('Machine #${panne['id_machine']} • Statut: ${panne['statut']}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Show details
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 4) return Colors.red;
    if (priority >= 2) return Colors.orange;
    return Colors.blue;
  }
}
