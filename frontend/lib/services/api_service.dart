import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  // Use localhost for web and 192.168.100.34 for physical devices/emulators
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8000' : 'http://192.168.100.34:8000',
  );

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  Future<User> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    print('DEBUG: Tentative de connexion à: $url');
    print('DEBUG: Email: $email');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'mot_de_passe': password,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Timeout lors de la connexion. Le serveur met trop de temps à répondre.');
        },
      );

      print('DEBUG: Status Code : ${response.statusCode}');
      print('DEBUG: Body : ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('user_role', data['role']);
        await prefs.setInt('user_id', data['user_id']);
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Email ou mot de passe incorrect');
      } else {
        throw Exception('Erreur de connexion: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('DEBUG TIMEOUT: $e');
      rethrow;
    } catch (e) {
      print('DEBUG ERROR: Erreur lors de l\'appel API : $e');
      rethrow;
    }
  }

  // --- Machine Management ---

  Future<List<Machine>> getMachines() async {
    final response = await http.get(
      Uri.parse('$baseUrl/machines/'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((m) => Machine.fromJson(m)).toList();
    } else {
      throw Exception('Failed to load machines');
    }
  }

  Future<Machine> getMachineDetail(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/machines/$id'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return Machine.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load machine details');
    }
  }

  Future<Map<String, dynamic>> createMachine(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/machines/create'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create machine: ${response.body}');
    }
  }

  Future<void> deleteMachine(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/machines/$id'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete machine');
    }
  }

  Future<Map<String, dynamic>> scanQrCode(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/machines/qrcode'),
      headers: await _getHeaders(),
      body: jsonEncode({'qrcode': code}),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String detail = 'Machine introuvable';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('detail')) {
          detail = body['detail'];
        }
      } catch (_) {}
      throw Exception(detail);
    }
  }

  // --- Panne Management ---

  Future<List<Map<String, dynamic>>> getPannes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/pannes/'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load pannes');
    }
  }

  Future<List<Map<String, dynamic>>> getPannesByMachine(int machineId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/pannes/machine/$machineId'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load pannes for machine $machineId');
    }
  }

  Future<List<Map<String, dynamic>>> getTypePannes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/types-pannes/'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Échec de chargement des types de pannes');
    }
  }

  Future<Map<String, dynamic>> createPanne({int? machineId, String? qrCode, required int typePanneId, int priority = 3, String? gravite}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;

    final response = await http.post(
      Uri.parse('$baseUrl/pannes/create'),
      headers: await _getHeaders(),
      body: jsonEncode({
        if (machineId != null) 'id_machine': machineId,
        if (qrCode != null) 'qr_code': qrCode,
        'id_type_panne': typePanneId,
        'id_superviseur': userId,
        'priorite': priority,
        if (gravite != null) 'gravite': gravite,
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la déclaration: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> reportMachineBreakdown(int machineId, int typePanneId, {int priority = 3}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/pannes/machine/$machineId'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'id_type_panne': typePanneId,
        'priorite': priority,
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la déclaration: ${response.body}');
    }
  }

  // --- Intervention Management ---

  Future<List<Intervention>> getInterventions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/interventions/'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((i) => Intervention.fromJson(i)).toList();
    } else {
      throw Exception('Failed to load interventions');
    }
  }

  Future<void> deleteIntervention(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/interventions/$id'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete intervention');
    }
  }

  Future<Map<String, dynamic>> createManualIntervention(int panneId, int techId, {String typeAffectation = 'manuelle'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/interventions/create'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'id_panne': panneId,
        'id_technicien': techId,
        'type_affectation': typeAffectation,
      }),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create manual intervention: ${response.body}');
    }
  }

  // --- Admin User Management (Global) ---

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<void> deleteUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  // --- Superviseurs ---

  Future<List<Map<String, dynamic>>> getSupervisors() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/superviseurs'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load supervisors');
    }
  }

  Future<Map<String, dynamic>> createSupervisor(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/superviseurs/create'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create supervisor');
    }
  }

  // --- Chefs d'équipe ---

  Future<Map<String, dynamic>> createChef(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/create-chef'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create chef');
    }
  }

  // --- Magasiniers ---

  Future<Map<String, dynamic>> createMagasinier(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/magasiniers/create'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create magasinier: ${response.body}');
    }
  }

  // --- Techniciens ---

  Future<List<Technician>> getTechnicians({int? idMachine}) async {
    final queryParams = idMachine != null ? '?id_machine=$idMachine' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/techniciens/$queryParams'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((t) => Technician.fromJson(t)).toList();
    } else {
      throw Exception('Failed to load technicians');
    }
  }

  Future<Technician> getMeTechnician() async {
    final response = await http.get(
      Uri.parse('$baseUrl/techniciens/me'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Technician.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load my technician profile');
    }
  }

  Future<Map<String, dynamic>> getMeChef() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me/chef'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chef profile');
    }
  }

  Future<Map<String, dynamic>?> getChefByGroup(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/chef-by-group/$groupId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>> createTechnician(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/techniciens/create'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to create technician';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<void> deleteTechnician(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/techniciens/$id'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete technician');
    }
  }

  // --- Groups & Config ---

  Future<Map<String, dynamic>> createMachineGroup(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groupes/machines'),
      headers: await _getHeaders(),
      body: jsonEncode({'nom_groupe': name}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create machine group');
    }
  }

  Future<Map<String, dynamic>> createTechnicianGroup(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groupes/techniciens'),
      headers: await _getHeaders(),
      body: jsonEncode({'nom_groupe': name}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create technician group');
    }
  }

  Future<List<Map<String, dynamic>>> getGroupesMachines() async {
    final response = await http.get(
      Uri.parse('$baseUrl/groupes/machines'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load machine groups');
    }
  }

  Future<List<Map<String, dynamic>>> getGroupesTechniciens() async {
    final response = await http.get(
      Uri.parse('$baseUrl/groupes/techniciens'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load technician groups');
    }
  }

  Future<Map<String, dynamic>> createTypePanne(String name, String gravite) async {
    final response = await http.post(
      Uri.parse('$baseUrl/types-pannes/create'),
      headers: await _getHeaders(),
      body: jsonEncode({'nom_panne': name, 'gravite': gravite}),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create failure type');
    }
  }

  // --- Technician Specific ---

  Future<void> updateTechnicianStatut(int techId, String statut) async {
    final response = await http.put(
      Uri.parse('$baseUrl/techniciens/$techId/statut'),
      headers: await _getHeaders(),
      body: jsonEncode({'statut': statut}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update status: ${response.body}');
    }
  }

  Future<List<Intervention>> getTechnicianInterventions(int techId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/interventions/technicien/$techId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((i) => Intervention.fromJson(i)).toList();
    } else {
      throw Exception('Failed to load technician interventions');
    }
  }

  Future<Map<String, dynamic>> terminerIntervention(int interventionId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/interventions/$interventionId/terminer'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to terminate intervention: ${response.body}');
    }
  }

  Future<Intervention> accepterIntervention(int interventionId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/interventions/$interventionId/accepter'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return Intervention.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to accept intervention: ${response.body}');
    }
  }

  Future<Intervention> demarrerIntervention(int interventionId, String qrCode) async {
    final encodedQr = Uri.encodeComponent(qrCode);
    final response = await http.put(
      Uri.parse('$baseUrl/interventions/$interventionId/demarrer?qr_code=$encodedQr'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return Intervention.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to start intervention: ${response.body}');
    }
  }

  Future<RapportPanne> soumettreRapport(int interventionId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/interventions/$interventionId/rapport'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return RapportPanne.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to submit report: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> annulerIntervention(int interventionId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/interventions/$interventionId/annuler'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to cancel intervention: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingAutorisations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/interventions/autorisations/pending'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load pending authorisations: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> approuverAutorisation(int interventionId, bool approuver) async {
    final response = await http.put(
      Uri.parse('$baseUrl/interventions/$interventionId/autoriser?approuver=$approuver'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to process authorisation: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updatePresence(String statut) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/me/presence?statut=$statut'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update presence: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> validerPanne(int panneId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/pannes/$panneId/valider'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to validate machine: ${response.body}');
    }
  }

  // --- Magasin Management ---

  Future<List<PieceRechange>> getPieces() async {
    final response = await http.get(
      Uri.parse('$baseUrl/magasin/pieces'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      print('getPieces response: \${response.body}');
      try {
        List jsonResponse = jsonDecode(response.body);
        final pieces = jsonResponse.map<PieceRechange>((p) => PieceRechange.fromJson(p)).toList();
        print('Parsed \${pieces.length} pieces');
        return pieces;
      } catch (e) {
        print('Error in getPieces parsing: \$e');
        rethrow;
      }
    } else {
      throw Exception('Failed to load pieces de rechange');
    }
  }

  Future<DemandeRechange> demanderPiece(int interventionId, int pieceId, int quantite, {String? commentaire}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/magasin/demandes'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'id_intervention': interventionId,
        'id_piece': pieceId,
        'quantite_demandee': quantite,
        if (commentaire != null) 'commentaire': commentaire,
      }),
    );
    if (response.statusCode == 201) {
      return DemandeRechange.fromJson(jsonDecode(response.body));
    } else {
      String errorMessage = 'Échec de la demande de pièce';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<List<DemandeRechange>> demanderPiecesBatch(List<Map<String, dynamic>> demandes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/magasin/demandes/batch'),
      headers: await _getHeaders(),
      body: jsonEncode({'demandes': demandes}),
    );

    if (response.statusCode == 201) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((d) => DemandeRechange.fromJson(d)).toList();
    } else {
      throw Exception('Échec de la demande groupée');
    }
  }

  Future<List<DemandeRechange>> getDemandesIntervention(int interventionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/magasin/demandes/intervention/$interventionId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map<DemandeRechange>((d) => DemandeRechange.fromJson(d)).toList();
    } else {
      throw Exception('Failed to load demandes for intervention');
    }
  }

  // --- Admin Magasin Management ---

  Future<PieceRechange> createPiece(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/magasin/pieces'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return PieceRechange.fromJson(jsonDecode(response.body));
    } else {
      String errorMessage = 'Failed to create piece';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<PieceRechange> updatePiece(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/magasin/pieces/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return PieceRechange.fromJson(jsonDecode(response.body));
    } else {
      String errorMessage = 'Failed to update piece';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<List<DemandeRechange>> getAllDemandesRechange() async {
    final response = await http.get(
      Uri.parse('$baseUrl/magasin/demandes'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map<DemandeRechange>((d) => DemandeRechange.fromJson(d)).toList();
    } else {
      throw Exception('Failed to load all demandes');
    }
  }

  Future<DemandeRechange> updateDemandeStatut(int idDemande, String statut) async {
    final response = await http.put(
      Uri.parse('$baseUrl/magasin/demandes/$idDemande/statut'),
      headers: await _getHeaders(),
      body: jsonEncode({'statut': statut}),
    );
    if (response.statusCode == 200) {
      return DemandeRechange.fromJson(jsonDecode(response.body));
    } else {
      String errorMessage = 'Failed to update demande status';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> requestReinforcement(int interventionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/interventions/$interventionId/renfort'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body)['detail'];
      throw Exception(error ?? 'Erreur lors de la demande de renfort');
    }
  }

  Future<void> updateFCMToken(String token) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/me/fcm'),
      headers: await _getHeaders(),
      body: jsonEncode({'fcm_token': token}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update FCM token');
    }
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groupes/$groupId/membres'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Erreur lors de la récupération des membres du groupe');
    }
  }
}
