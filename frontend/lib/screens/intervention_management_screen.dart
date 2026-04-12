import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';

class InterventionManagementScreen extends StatefulWidget {
  const InterventionManagementScreen({super.key});

  @override
  State<InterventionManagementScreen> createState() => _InterventionManagementScreenState();
}

class _InterventionManagementScreenState extends State<InterventionManagementScreen> {
  final _apiService = ApiService();
  List<Intervention> _interventions = [];
  List<Intervention> _filteredInterventions = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchInterventions();
  }

  Future<void> _fetchInterventions() async {
    setState(() => _isLoading = true);
    try {
      final interventions = await _apiService.getInterventions();
      setState(() {
        _interventions = interventions;
        _applyFilters();
      });
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

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInterventions = _interventions.where((interv) {
        // Search by name/machine/id
        final techName = interv.technicien != null 
            ? '${interv.technicien!.prenom} ${interv.technicien!.nom}'.toLowerCase()
            : 'id: ${interv.idTechnicien}';
        final machineName = (interv.panne?.machine?.nom ?? '').toLowerCase();
        final intervId = 'interv #${interv.id}'.toLowerCase();
        
        final matchesQuery = techName.contains(query) || 
                            machineName.contains(query) || 
                            intervId.contains(query);
        
        // Filter by date
        bool matchesDate = true;
        if (_selectedDate != null) {
          matchesDate = interv.dateDebut.year == _selectedDate!.year &&
                        interv.dateDebut.month == _selectedDate!.month &&
                        interv.dateDebut.day == _selectedDate!.day;
        }
        
        return matchesQuery && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = null;
      _searchController.clear();
      _isSearching = false;
    });
    _applyFilters();
  }

  Future<void> _deleteIntervention(int id) async {
    try {
      await _apiService.deleteIntervention(id);
      _fetchInterventions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intervention supprimée')),
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
                    hintText: 'Chercher par technicien, machine...',
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
            : const Text('Gestion des Interventions', style: TextStyle(fontWeight: FontWeight.bold)),
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded),
                onPressed: _selectDate,
              ),
              if (_selectedDate != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppTheme.errorRed, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _clearFilters();
              _fetchInterventions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDate != null)
            _buildActiveFiltersHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
                : _filteredInterventions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredInterventions.length,
                        itemBuilder: (context, index) {
                          final interv = _filteredInterventions[index];
                          return _buildInterventionCard(interv);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 16, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            'Filtre: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          const Spacer(),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Effacer', style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionCard(Intervention interv) {
    Color statusColor;
    switch (interv.statut.toLowerCase()) {
      case 'en_attente': statusColor = AppTheme.warningOrange; break;
      case 'acceptee': statusColor = AppTheme.primaryBlue; break;
      case 'en_cours': statusColor = AppTheme.primaryBlue; break;
      case 'terminee': statusColor = AppTheme.successGreen; break;
      case 'annulee': statusColor = AppTheme.errorRed; break;
      default: statusColor = AppTheme.textGrey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.engineering_rounded, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intervention #${interv.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.precision_manufacturing_outlined, size: 14, color: AppTheme.textGrey.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              interv.panne?.machine?.nom ?? 'Machine inconnue',
                              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Localisation: ${interv.panne?.machine?.localisation ?? "N/A"}',
                        style: TextStyle(color: AppTheme.textGrey.withOpacity(0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        interv.statut.toUpperCase(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Priorité: ${interv.panne?.priorite ?? "N/A"}',
                      style: TextStyle(
                        color: (interv.panne?.priorite ?? 0) >= 3 ? AppTheme.errorRed : AppTheme.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TECHNICIEN', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(
                        interv.technicien != null 
                          ? '${interv.technicien!.prenom} ${interv.technicien!.nom}'
                          : 'ID: ${interv.idTechnicien}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('DÉBUT', style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM HH:mm').format(interv.dateDebut),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
                  onPressed: () => _confirmDelete(interv.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cette intervention ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteIntervention(id);
            },
            child: const Text('SUPPRIMER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppTheme.textGrey.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text("Aucune intervention trouvée", style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
        ],
      ),
    );
  }
}
