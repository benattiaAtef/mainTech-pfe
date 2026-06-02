import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'panne_details_screen.dart';

class PanneManagementScreen extends StatefulWidget {
  const PanneManagementScreen({super.key});

  @override
  State<PanneManagementScreen> createState() => _PanneManagementScreenState();
}

class _PanneManagementScreenState extends State<PanneManagementScreen> {
  final _apiService = ApiService();
  List<Map<String, dynamic>> _pannes = [];
  List<Map<String, dynamic>> _filteredPannes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String? _selectedStatut;

  static const _statuts = ['en_attente', 'en_cours', 'resolu', 'a_valider', 'annulee'];

  @override
  void initState() {
    super.initState();
    _fetchPannes();
  }

  Future<void> _fetchPannes() async {
    setState(() => _isLoading = true);
    try {
      final pannes = await _apiService.getPannes();
      setState(() {
        _pannes = pannes;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPannes = _pannes.where((p) {
        final machine = p['machine'] as Map<String, dynamic>?;
        final machineName = (machine?['nom'] as String? ?? '').toLowerCase();
        final id = 'panne #${p['id_panne']}'.toLowerCase();
        final statut = (p['statut'] as String? ?? '').toLowerCase();

        final matchesQuery = machineName.contains(query) || id.contains(query) || statut.contains(query);
        final matchesStatut = _selectedStatut == null || p['statut'] == _selectedStatut;
        return matchesQuery && matchesStatut;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatut = null;
      _searchController.clear();
      _isSearching = false;
    });
    _applyFilters();
  }

  Color _getPriorityColor(dynamic priority) {
    final p = (priority as int?) ?? 0;
    if (p >= 4) return AppTheme.errorRed;
    if (p >= 3) return AppTheme.warningOrange;
    return AppTheme.primaryBlue;
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

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      String s = dateStr.toString();
      if (!s.endsWith('Z') && !s.contains('+')) s += 'Z';
      final dt = DateTime.parse(s).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Chercher par machine, statut...',
                    hintStyle: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(Icons.search, color: AppTheme.textGrey, size: 20),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              )
            : const Text('Gestion des Pannes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() => _isSearching = false);
                _searchController.clear();
                _applyFilters();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _isSearching = true),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _clearFilters();
              _fetchPannes();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('Tous', null),
                  const SizedBox(width: 8),
                  ..._statuts.map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          s.toUpperCase().replaceAll('_', ' '),
                          s,
                        ),
                      )),
                ],
              ),
            ),
          ),
          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
                : _filteredPannes.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchPannes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPannes.length,
                          itemBuilder: (context, index) {
                            return _buildPanneCard(_filteredPannes[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedStatut == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatut = value);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildPanneCard(Map<String, dynamic> panne) {
    final machine = panne['machine'] as Map<String, dynamic>?;
    final typePanne = panne['type_panne'] as Map<String, dynamic>?;
    final statut = panne['statut'] as String? ?? 'en_attente';
    final priorite = panne['priorite'];
    final priorityColor = _getPriorityColor(priorite);
    final statutColor = _getStatutColor(statut);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: priorityColor.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PanneDetailsScreen(panne: panne)),
        ).then((_) => _fetchPannes()),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ───────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.report_problem_rounded, color: priorityColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panne #${panne['id_panne']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          machine != null ? machine['nom'] as String : 'Machine #${panne['id_machine']}',
                          style: const TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (machine?['localisation'] != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textGrey),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  machine!['localisation'] as String,
                                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                          color: statutColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statut.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(color: statutColor, fontWeight: FontWeight.bold, fontSize: 9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'P${priorite ?? '?'}',
                          style: TextStyle(color: priorityColor, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              // ── Footer Row ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report_outlined, size: 14, color: AppTheme.textGrey),
                      const SizedBox(width: 5),
                      Text(
                        typePanne != null
                            ? (typePanne['nom_panne'] as String? ?? 'Type inconnu')
                            : 'Type #${panne['id_type_panne'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textGrey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(panne['date_declaration']),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textGrey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 72, color: AppTheme.successGreen.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Aucune panne trouvée', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Effacer les filtres'),
          ),
        ],
      ),
    );
  }
}
