import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class MachineDetailScreen extends StatefulWidget {
  final Machine machine;

  const MachineDetailScreen({super.key, required this.machine});

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  final _apiService = ApiService();
  late Machine _machine;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _machine = widget.machine;
  }

  Future<void> _refreshMachineData() async {
    setState(() => _isLoading = true);
    try {
      final updatedMachine = await _apiService.getMachineDetail(_machine.id);
      if (mounted) {
        setState(() {
          _machine = updatedMachine;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du rafraîchissement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOperational = _machine.statut == 'Opérationnel';
    final bool isAValider = _machine.statut == 'A valider';
    final String dateInstall = _machine.dateInstallation != null 
        ? DateFormat('dd MMM yyyy').format(_machine.dateInstallation!)
        : 'Non renseignée';
    
    Color statusColor = AppTheme.successGreen;
    if (!isOperational) {
      statusColor = isAValider ? Colors.orange : AppTheme.errorRed;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la Machine'),
        titleTextStyle: const TextStyle(fontSize: 16, color: AppTheme.textGrey, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            onPressed: _refreshMachineData,
            icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_machine.nom,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Série #${_machine.numSerie ?? 'N/A'} • Installée le $dateInstall',
                          style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('● ${_machine.statut}',
                      style: TextStyle(
                        color: statusColor, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 12
                      )),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('NOM DE LA MACHINE', _machine.nom),
                  _buildDetailRow('TYPE', _machine.groupeNom ?? 'Non défini'),
                  _buildDetailRow('FONCTION', _machine.fonction ?? 'Non définie'),
                  _buildDetailRow('LIEU D\'INSTALLATION', _machine.localisation),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildActionSection(),
            const SizedBox(height: 24),
            _buildIncidentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textGrey, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final bool isOperational = _machine.statut == 'Opérationnel';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions Rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          if (isOperational)
            ElevatedButton.icon(
              onPressed: () => _handleReportBreakdown(),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Signaler une panne'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else if (_machine.statut == 'A valider')
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final pannes = await _apiService.getPannesByMachine(_machine.id);
                  final aValiderList = pannes.where((p) => p['statut'] == 'a_valider').toList();
                  final aValider = aValiderList.isNotEmpty ? aValiderList.first : null;
                  if (aValider != null) {
                    await _apiService.validerPanne(aValider['id_panne']);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Machine validée'), backgroundColor: AppTheme.successGreen),
                    );
                    _refreshMachineData();
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Valider et remettre en service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _handleManualIntervention(),
              icon: const Icon(Icons.build_circle_outlined),
              label: const Text('Lancer une intervention'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

          TextButton.icon(
            onPressed: () => _handleDeleteMachine(),
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
            label: const Text('Supprimer la machine', style: TextStyle(color: AppTheme.errorRed)),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleManualIntervention() async {
    try {
      setState(() => _isLoading = true);
      final technicians = await _apiService.getTechnicians(idMachine: widget.machine.id);
      setState(() => _isLoading = false);

      if (!mounted) return;

      // Filtrer les techniciens par compétence
      final allCompetent = technicians.where((tech) {
        final bool isSameGroup = tech.idGroupe == _machine.idGroupeTechPrincipal;
        final bool hasCompetence = tech.competenceIds.contains(_machine.idGroupe);
        return isSameGroup || hasCompetence;
      }).toList();

      // Règle de priorité locale : Si un tech du groupe est disponible, on ne montre que le groupe local
      final bool localAvailable = allCompetent.any((tech) => 
        tech.idGroupe == _machine.idGroupeTechPrincipal && tech.statut == 'disponible'
      );

      final List<Technician> displayedTechnicians = localAvailable
          ? allCompetent.where((tech) => tech.idGroupe == _machine.idGroupeTechPrincipal).toList()
          : allCompetent;

      if (displayedTechnicians.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun technicien compétent disponible'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }

      final selectedTech = await showDialog<Technician>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choisir un technicien'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: displayedTechnicians.length,
              itemBuilder: (context, index) {
                final tech = displayedTechnicians[index];
                final bool isAvailable = tech.statut == 'disponible';
                final bool isSameGroup = tech.idGroupe == _machine.idGroupeTechPrincipal;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAvailable 
                        ? (isSameGroup ? AppTheme.successGreen.withOpacity(0.1) : Colors.blue.withOpacity(0.1))
                        : Colors.grey.withOpacity(0.1),
                    child: Icon(Icons.person, 
                        color: isAvailable ? (isSameGroup ? AppTheme.successGreen : Colors.blue) : Colors.grey),
                  ),
                  title: Text('${tech.prenom} ${tech.nom}'),
                  subtitle: Text('Statut: ${tech.statut}${!isSameGroup ? " (Autre groupe)" : ""}'),
                  enabled: isAvailable,
                  onTap: isAvailable ? () => Navigator.pop(context, tech) : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ],
        ),
      );

      if (selectedTech != null) {
        String typeAffectation = 'manuelle';
        
        // Vérifier si c'est une intervention inter-groupe (Exceptionnelle)
        final bool isInterGroupe = selectedTech.idGroupe != _machine.idGroupeTechPrincipal;
        
        if (isInterGroupe) {
          final confirmExceptional = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Intervention Exceptionnelle'),
              content: Text('${selectedTech.prenom} ${selectedTech.nom} appartient à un autre groupe. Voulez-vous lancer une intervention inter-groupe ?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmer', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          
          if (confirmExceptional != true) return;
          typeAffectation = 'urgente';
        }

        // Obtenir les pannes spécifiques à cette machine
        final pannes = await _apiService.getPannesByMachine(_machine.id);
        final matchingPannes = pannes.where((p) {
          final statut = (p['statut'] as String?)?.toLowerCase() ?? '';
          return statut == 'en_attente' || statut == 'en_cours';
        }).toList();
        
        if (matchingPannes.isEmpty) {
          throw Exception('Aucune panne active trouvée pour cette machine');
        }
        final activePanne = matchingPannes.first;

        await _apiService.createManualIntervention(
          activePanne['id_panne'] as int, 
          selectedTech.id,
          typeAffectation: typeAffectation,
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isInterGroupe ? 'Intervention inter-groupe lancée' : 'Intervention lancée avec succès'), 
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _refreshMachineData();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  void _handleDeleteMachine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette machine ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: AppTheme.errorRed))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteMachine(_machine.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine supprimée'), backgroundColor: AppTheme.successGreen),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  Widget _buildIncidentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dernier Incident Enregistré', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Icon(Icons.info_outline, color: AppTheme.textGrey, size: 20),
            ],
          ),
          SizedBox(height: 16),
          Text('Aucun incident récent', style: TextStyle(color: AppTheme.textGrey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  void _handleReportBreakdown() async {
    try {
      final types = await _apiService.getTypePannes();

      if (!mounted) return;

      final selectedType = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Type de Panne'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                return ListTile(
                  title: Text(type['nom_panne']),
                  subtitle: Text('Gravité: ${type['gravite']}'),
                  onTap: () => Navigator.pop(context, type),
                );
              },
            ),
          ),
        ),
      );

      if (selectedType != null) {
        await _apiService.reportMachineBreakdown(
          _machine.id,
          selectedType['id_type_panne'],
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Panne signalée avec succès'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        _refreshMachineData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}
