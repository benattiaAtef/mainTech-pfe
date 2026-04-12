DateTime parseUtc(dynamic dateStr) {
  if (dateStr == null) return DateTime.now();
  String s = dateStr.toString();
  if (!s.endsWith('Z') && !s.contains('+')) {
    s += 'Z';
  }
  return DateTime.parse(s).toLocal();
}

class User {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final String statutPresence;

  User({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    this.statutPresence = 'en_travail',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id_utilisateur'] ?? json['id'] ?? 0,
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      statutPresence: json['statut_presence'] ?? 'en_travail',
    );
  }
}

class Machine {
  final int id;
  final String nom;
  final int idGroupe;
  final int? idGroupeTechPrincipal;
  final String qrCode;
  final String localisation;
  final String? groupeNom;
  final String? numSerie;
  final DateTime? dateInstallation;
  final String? fonction;
  final String statut;

  Machine({
    required this.id,
    required this.nom,
    required this.idGroupe,
    required this.qrCode,
    required this.localisation,
    this.idGroupeTechPrincipal,
    this.groupeNom,
    this.numSerie,
    this.dateInstallation,
    this.fonction,
    this.statut = 'Opérationnel',
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id_machine'] ?? 0,
      nom: json['nom'] ?? '',
      idGroupe: json['id_groupe_machine'] ?? 0,
      qrCode: json['qr_code'] ?? '',
      localisation: json['localisation'] ?? '',
      idGroupeTechPrincipal: json['id_groupe_tech_principal'],
      groupeNom: json['groupe_nom'],
      numSerie: json['num_serie'],
      dateInstallation: json['date_installation'] != null ? parseUtc(json['date_installation']) : null,
      fonction: json['fonction'],
      statut: json['statut'] ?? 'Opérationnel',
    );
  }

  Machine copyWith({
    int? id,
    String? nom,
    int? idGroupe,
    String? qrCode,
    String? localisation,
    String? groupeNom,
    String? numSerie,
    DateTime? dateInstallation,
    String? fonction,
    String? statut,
  }) {
    return Machine(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      idGroupe: idGroupe ?? this.idGroupe,
      qrCode: qrCode ?? this.qrCode,
      localisation: localisation ?? this.localisation,
      groupeNom: groupeNom ?? this.groupeNom,
      numSerie: numSerie ?? this.numSerie,
      dateInstallation: dateInstallation ?? this.dateInstallation,
      fonction: fonction ?? this.fonction,
      statut: statut ?? this.statut,
    );
  }
}

class Technician {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String statut;
  final int? idGroupe;
  final String? matricule;
  final int? interventionsToday;
  final int? totalTimeToday;
  final List<int> competenceIds;
  final String? statutPresence;

  Technician({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.statut,
    this.idGroupe,
    this.matricule,
    this.interventionsToday,
    this.totalTimeToday,
    this.competenceIds = const [],
    this.statutPresence,
  });

  factory Technician.fromJson(Map<String, dynamic> json) {
    final userData = json['utilisateur'] ?? {};
    return Technician(
      id: json['id_technicien'] ?? 0,
      nom: userData['nom'] ?? '',
      prenom: userData['prenom'] ?? '',
      email: userData['email'] ?? '',
      statut: json['statut'] ?? 'disponible',
      idGroupe: json['id_groupe_principal'],
      matricule: json['matricule'],
      interventionsToday: json['interventions_count_today'] as int?,
      totalTimeToday: json['total_time_today_minutes'] as int?,
      competenceIds: (json['competences'] as List? ?? [])
          .map((c) => c['id_groupe_machine'] as int)
          .toList(),
      statutPresence: userData['statut_presence'],
    );
  }

  Technician copyWith({
    int? id,
    String? nom,
    String? prenom,
    String? email,
    String? statut,
    int? idGroupe,
    String? matricule,
    int? interventionsToday,
    int? totalTimeToday,
    List<int>? competenceIds,
  }) {
    return Technician(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      statut: statut ?? this.statut,
      idGroupe: idGroupe ?? this.idGroupe,
      matricule: matricule ?? this.matricule,
      interventionsToday: interventionsToday ?? this.interventionsToday,
      totalTimeToday: totalTimeToday ?? this.totalTimeToday,
      competenceIds: competenceIds ?? this.competenceIds,
    );
  }
}

class Intervention {
  final int id;
  final int idPanne;
  final int idTechnicien;
  final DateTime dateDebut;
  final DateTime? dateAcceptation;
  final DateTime? dateScanQr;
  final DateTime? dateFin;
  final String typeAffectation;
  final double? dureeMinutes;
  final String statut;
  final RapportPanne? rapport;
  final Panne? panne;
  final Technician? technicien;

  Intervention({
    required this.id,
    required this.idPanne,
    required this.idTechnicien,
    required this.dateDebut,
    this.dateAcceptation,
    this.dateScanQr,
    this.dateFin,
    required this.typeAffectation,
    this.dureeMinutes,
    required this.statut,
    this.rapport,
    this.panne,
    this.technicien,
  });

  factory Intervention.fromJson(Map<String, dynamic> json) {
    return Intervention(
      id: json['id_intervention'] ?? 0,
      idPanne: json['id_panne'] ?? 0,
      idTechnicien: json['id_technicien'] ?? 0,
      dateDebut: parseUtc(json['date_debut']),
      dateAcceptation: json['date_acceptation'] != null ? parseUtc(json['date_acceptation']) : null,
      dateScanQr: json['date_scan_qr'] != null ? parseUtc(json['date_scan_qr']) : null,
      dateFin: json['date_fin'] != null ? parseUtc(json['date_fin']) : null,
      typeAffectation: json['type_affectation'] ?? 'automatique',
      dureeMinutes: json['duree_minutes']?.toDouble(),
      statut: json['statut'] ?? 'en_attente',
      rapport: json['rapport'] != null ? RapportPanne.fromJson(json['rapport']) : null,
      panne: json['panne'] != null ? Panne.fromJson(json['panne']) : null,
      technicien: json['technicien'] != null ? Technician.fromJson(json['technicien']) : null,
    );
  }

  Intervention copyWith({
    int? id,
    int? idPanne,
    int? idTechnicien,
    DateTime? dateDebut,
    DateTime? dateAcceptation,
    DateTime? dateScanQr,
    DateTime? dateFin,
    String? typeAffectation,
    double? dureeMinutes,
    String? statut,
    RapportPanne? rapport,
    Panne? panne,
    Technician? technicien,
  }) {
    return Intervention(
      id: id ?? this.id,
      idPanne: idPanne ?? this.idPanne,
      idTechnicien: idTechnicien ?? this.idTechnicien,
      dateDebut: dateDebut ?? this.dateDebut,
      dateAcceptation: dateAcceptation ?? this.dateAcceptation,
      dateScanQr: dateScanQr ?? this.dateScanQr,
      dateFin: dateFin ?? this.dateFin,
      typeAffectation: typeAffectation ?? this.typeAffectation,
      dureeMinutes: dureeMinutes ?? this.dureeMinutes,
      statut: statut ?? this.statut,
      rapport: rapport ?? this.rapport,
      panne: panne ?? this.panne,
      technicien: technicien ?? this.technicien,
    );
  }
}

class RapportPanne {
  final int id;
  final int idIntervention;
  final String? descriptionPanne;
  final String? travauxEffectues;
  final String? typeTravail;
  final Map<String, dynamic>? codesDefaut;
  final List<dynamic>? piecesRechange;
  final int? tempsArret;
  final String? observations;
  final String? causes;
  final String? solutions;
  final String? etatFinal;
  final DateTime dateRapport;

  RapportPanne({
    required this.id,
    required this.idIntervention,
    this.descriptionPanne,
    this.travauxEffectues,
    this.typeTravail,
    this.codesDefaut,
    this.piecesRechange,
    this.tempsArret,
    this.observations,
    this.causes,
    this.solutions,
    this.etatFinal,
    required this.dateRapport,
  });

  factory RapportPanne.fromJson(Map<String, dynamic> json) {
    return RapportPanne(
      id: json['id_rapport'] ?? 0,
      idIntervention: json['id_intervention'] ?? 0,
      descriptionPanne: json['description_panne'],
      travauxEffectues: json['travaux_effectues'],
      typeTravail: json['type_travail'],
      codesDefaut: json['codes_defaut'],
      piecesRechange: json['pieces_rechange'],
      tempsArret: json['temps_arret'],
      observations: json['observations'],
      causes: json['causes'],
      solutions: json['solutions'],
      etatFinal: json['etat_final'],
      dateRapport: parseUtc(json['date_rapport']),
    );
  }
}

class Panne {
  final int id;
  final int machineId;
  final int typePanneId;
  final int priorite;
  final String statut;
  final DateTime? dateDeclaration;
  final Machine? machine;

  Panne({
    required this.id,
    required this.machineId,
    required this.typePanneId,
    required this.priorite,
    required this.statut,
    this.dateDeclaration,
    this.machine,
  });

  factory Panne.fromJson(Map<String, dynamic> json) {
    return Panne(
      id: json['id_panne'] ?? 0,
      machineId: json['id_machine'] ?? 0,
      typePanneId: json['id_type_panne'] ?? 0,
      priorite: json['priorite'] ?? 3,
      statut: json['statut'] ?? 'en_attente',
      dateDeclaration: json['date_declaration'] != null ? parseUtc(json['date_declaration']) : null,
      machine: json['machine'] != null ? Machine.fromJson(json['machine']) : null,
    );
  }

  Panne copyWith({
    int? id,
    int? machineId,
    int? typePanneId,
    int? priorite,
    String? statut,
    DateTime? dateDeclaration,
    Machine? machine,
  }) {
    return Panne(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      typePanneId: typePanneId ?? this.typePanneId,
      priorite: priorite ?? this.priorite,
      statut: statut ?? this.statut,
      dateDeclaration: dateDeclaration ?? this.dateDeclaration,
      machine: machine ?? this.machine,
    );
  }
}

class PieceRechange {
  final int id;
  final String reference;
  final String nom;
  final String? description;
  final int quantiteStock;
  final String unite;
  final DateTime dateMaj;

  PieceRechange({
    required this.id,
    required this.reference,
    required this.nom,
    this.description,
    required this.quantiteStock,
    required this.unite,
    required this.dateMaj,
  });

  factory PieceRechange.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing PieceRechange: $json');
      return PieceRechange(
        id: json['id_piece'] ?? 0,
        reference: json['reference'] ?? '',
        nom: json['nom'] ?? '',
        description: json['description'],
        quantiteStock: json['quantite_stock'] ?? 0,
        unite: json['unite'] ?? 'pcs',
        dateMaj: json['date_maj'] != null ? parseUtc(json['date_maj']) : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing PieceRechange: $e');
      rethrow;
    }
  }
}

class DemandeRechange {
  final int idDemande;
  final int idIntervention;
  final int idPiece;
  final int quantiteDemandee;
  final String statut;
  final String? commentaire;
  final DateTime dateDemande;
  final PieceRechange? piece;

  DemandeRechange({
    required this.idDemande,
    required this.idIntervention,
    required this.idPiece,
    required this.quantiteDemandee,
    required this.statut,
    this.commentaire,
    required this.dateDemande,
    this.piece,
  });

  factory DemandeRechange.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing DemandeRechange: $json');
      return DemandeRechange(
        idDemande: json['id_demande'] ?? 0,
        idIntervention: json['id_intervention'] ?? 0,
        idPiece: json['id_piece'] ?? 0,
        quantiteDemandee: json['quantite_demandee'] ?? 1,
        statut: json['statut'] ?? 'en_attente',
        commentaire: json['commentaire'],
        dateDemande: json['date_demande'] != null ? parseUtc(json['date_demande']) : DateTime.now(),
        piece: json['piece'] != null ? PieceRechange.fromJson(json['piece']) : null,
      );
    } catch (e) {
      print('Error parsing DemandeRechange: $e');
      rethrow;
    }
  }
}
