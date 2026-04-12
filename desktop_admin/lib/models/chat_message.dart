class ChatMessage {
  final int id;
  final int idExpediteur;
  final int idGroupe;
  final String contenu;
  final DateTime dateEnvoi;
  final String? expediteurNom;
  final String? expediteurPrenom;

  ChatMessage({
    required this.id,
    required this.idExpediteur,
    required this.idGroupe,
    required this.contenu,
    required this.dateEnvoi,
    this.expediteurNom,
    this.expediteurPrenom,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id_message'] ?? 0,
      idExpediteur: json['id_expediteur'] ?? 0,
      idGroupe: json['id_groupe'] ?? 0,
      contenu: json['contenu'] ?? '',
      dateEnvoi: DateTime.parse(json['date_envoi']).toLocal(),
      expediteurNom: json['expediteur_nom'],
      expediteurPrenom: json['expediteur_prenom'],
    );
  }

  String get displayName =>
      (expediteurPrenom != null && expediteurNom != null)
          ? "$expediteurPrenom $expediteurNom"
          : "Utilisateur $idExpediteur";
}
