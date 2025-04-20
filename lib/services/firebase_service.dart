import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/user.dart' as app_user;
import '../models/event.dart';
import 'email_service.dart';

class FirebaseService with ChangeNotifier {
  // Firebase instances
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload d'image d'événement
  Future<String> uploadEventImage(File imageFile) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final reference = _storage.ref().child('event_images/$fileName');
      final uploadTask = await reference.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Erreur lors de l\'upload de l\'image: ${e.toString()}');
    }
  }
  
  // Informations de connexion par défaut pour l'organisateur
  static const String defaultOrganizerEmail = 'organizer@eventikets.com';
  static const String defaultOrganizerPassword = 'password123';
  static const String defaultOrganizerName = 'Organisateur';
  
  // User
  app_user.User? _user;
  app_user.User? get user => _user;
  
  // Constructeur
  FirebaseService() {
    // Écouter les changements d'authentification
    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _getUserData(firebaseUser.uid);
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }
  
  // Récupérer les données utilisateur depuis Firestore
  Future<void> _getUserData(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        // Utiliser directement l'ID comme chaîne
        userData['id'] = uid;
        
        _user = app_user.User.fromJson(userData);
        notifyListeners();
      }
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
    }
  }
  
  // Connexion utilisateur
  Future<app_user.User> login(String email, String password) async {
    try {
      // Connexion avec Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        // Récupérer les données utilisateur depuis Firestore
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          // Utiliser directement l'UID comme ID
          userData['id'] = userCredential.user!.uid;
          userData['token'] = await userCredential.user!.getIdToken();
          
          _user = app_user.User.fromJson(userData);
          notifyListeners();
          return _user!;
        } else {
          throw Exception('Utilisateur non trouvé dans la base de données');
        }
      } else {
        throw Exception('Échec de la connexion');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        // Si l'utilisateur n'existe pas et qu'il s'agit de l'organisateur par défaut,
        // essayer de créer le compte
        if (email == defaultOrganizerEmail && password == defaultOrganizerPassword) {
          return await _createDefaultOrganizer();
        }
      }
      throw Exception('Échec de la connexion: ${e.message}');
    } catch (e) {
      throw Exception('Échec de la connexion: ${e.toString()}');
    }
  }
  
  // Création d'un organisateur par défaut
  Future<app_user.User> _createDefaultOrganizer() async {
    try {
      return await register(
        defaultOrganizerName,
        defaultOrganizerEmail,
        defaultOrganizerPassword,
        role: 'organizer'
      );
    } catch (e) {
      throw Exception('Impossible de créer l\'organisateur par défaut: ${e.toString()}');
    }
  }
  
  // Inscription utilisateur
  Future<app_user.User> register(String name, String email, String password, {String role = 'user', bool hasDefaultCredentials = false}) async {
    try {
      // Créer l'utilisateur dans Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        // Créer le document utilisateur dans Firestore
        final userData = {
          'name': name,
          'email': email,
          'role': role,
          'has_default_credentials': hasDefaultCredentials || role == 'organizer',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        };
        
        await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
        
        // Récupérer le token
        final token = await userCredential.user!.getIdToken() ?? '';
        
        // Créer l'objet utilisateur
        _user = app_user.User(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          role: role,
          token: token,
          hasDefaultCredentials: hasDefaultCredentials || role == 'organizer'
        );
        
        // Envoyer un email de bienvenue
        await EmailService.sendWelcomeEmail(
          to: email,
          name: name,
        );
        
        notifyListeners();
        return _user!;
      } else {
        throw Exception('Échec de l\'inscription');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Cette adresse email est déjà utilisée');
      }
      throw Exception('Échec de l\'inscription: ${e.message}');
    } catch (e) {
      throw Exception('Échec de l\'inscription: ${e.toString()}');
    }
  }
  
  // Déconnexion
  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }
  
  // Mise à jour des identifiants utilisateur
  Future<void> updateCredentials(String currentPassword, String newPassword) async {
    try {
      // Vérifier si l'utilisateur est connecté
      firebase_auth.User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Récupérer l'email de l'utilisateur
      String email = currentUser.email ?? '';
      
      // Pour les utilisateurs avec des identifiants par défaut (première connexion)
      if (_user != null && _user!.hasDefaultCredentials && currentPassword.isEmpty) {
        // Cas spécial pour les gestionnaires avec mot de passe temporaire
        // Dans un cas réel, il faudrait une méthode plus sécurisée
        // Cette implémentation est simplifiée pour la démonstration
        try {
          // Mettre à jour directement le mot de passe
          await currentUser.updatePassword(newPassword);
        } catch (e) {
          // Si l'authentification échoue, essayer de se reconnecter
          // Note: Ceci est une simplification, en production il faudrait une meilleure gestion
          throw Exception('Impossible de mettre à jour le mot de passe. Veuillez vous reconnecter et réessayer.');
        }
      } else {
        // Cas normal: réauthentifier l'utilisateur avec son mot de passe actuel
        firebase_auth.AuthCredential credential = firebase_auth.EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        );
        
        await currentUser.reauthenticateWithCredential(credential);
        
        // Mettre à jour le mot de passe
        await currentUser.updatePassword(newPassword);
      }
      
      // Mettre à jour le champ hasDefaultCredentials dans Firestore
      if (_user != null && _user!.hasDefaultCredentials) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'has_default_credentials': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
        
        // Mettre à jour l'utilisateur local
        _user = app_user.User(
          id: _user!.id,
          name: _user!.name,
          email: _user!.email,
          role: _user!.role,
          token: _user!.token,
          hasDefaultCredentials: false
        );
        
        notifyListeners();
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Mot de passe actuel incorrect');
      }
      throw Exception('Échec de la mise à jour des identifiants: ${e.message}');
    } catch (e) {
      throw Exception('Échec de la mise à jour des identifiants: ${e.toString()}');
    }
  }
  
  // Ajouter un gestionnaire
  Future<app_user.User> addManager(String email) async {
    try {
      if (_user == null || _user!.role != 'organizer') {
        throw Exception('Seuls les organisateurs peuvent ajouter des gestionnaires');
      }
      
      // Générer un mot de passe temporaire
      final temporaryPassword = 'Manager${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      // Vérifier si l'email existe déjà
      final existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      
      if (existingUsers.docs.isNotEmpty) {
        throw Exception('Un utilisateur avec cet email existe déjà');
      }
      
      // Créer le compte gestionnaire
      final newManager = await register(
        'Gestionnaire', // Nom par défaut
        email,
        temporaryPassword,
        role: 'manager',
        hasDefaultCredentials: true
      );
      
      // Envoyer un email avec les identifiants temporaires
      await EmailService.sendWelcomeEmail(
        to: email,
        name: 'Gestionnaire',
        additionalContent: 'Votre mot de passe temporaire est: $temporaryPassword\nVeuillez le changer lors de votre première connexion.'
      );
      
      return newManager;
    } catch (e) {
      throw Exception("Échec de l'ajout du gestionnaire: ${e.toString()}");
    }
  }
  
  // Supprimer un gestionnaire
  Future<void> removeManager(String managerId) async {
    try {
      if (_user == null || _user!.role != 'organizer') {
        throw Exception('Seuls les organisateurs peuvent supprimer des gestionnaires');
      }
      
      // Vérifier si l'utilisateur existe et est un gestionnaire
      final userDoc = await _firestore.collection('users').doc(managerId).get();
      
      if (!userDoc.exists) {
        throw Exception('Gestionnaire non trouvé');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['role'] != 'manager') {
        throw Exception('L\'utilisateur n\'est pas un gestionnaire');
      }
      
      // Supprimer le compte dans Firebase Auth
      // Note: Cela nécessite des fonctions Cloud Firebase pour être complètement sécurisé
      // Cette implémentation est simplifiée pour la démonstration
      await _firestore.collection('users').doc(managerId).delete();
      
      return;
    } catch (e) {
      throw Exception('Échec de la suppression du gestionnaire: ${e.toString()}');
    }
  }
  
  // Récupérer la liste des gestionnaires
  Future<List<Map<String, dynamic>>> getManagers() async {
    try {
      if (_user == null || _user!.role != 'organizer') {
        throw Exception('Seuls les organisateurs peuvent voir les gestionnaires');
      }
      
      final managersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();
      
      return managersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? '',
          'name': data['name'] ?? 'Gestionnaire',
          'hasDefaultCredentials': data['has_default_credentials'] ?? false,
        };
      }).toList();
    } catch (e) {
      throw Exception('Échec de la récupération des gestionnaires: ${e.toString()}');
    }
  }
  
  // Récupération des événements
  Future<List<Event>> getEvents() async {
    try {
      
      // Récupérer les événements depuis Firestore
      Query eventsQuery = _firestore.collection('events');
      
      // Exécuter la requête
      QuerySnapshot eventSnapshot = await eventsQuery.get();
      
      List<Event> events = [];
      
      for (var doc in eventSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // S'assurer que tous les champs de type String sont non-null
        data['title'] = data['title'] ?? 'Sans titre';
        data['description'] = data['description'] ?? 'Aucune description';
        data['location'] = data['location'] ?? 'Emplacement non spécifié';
        data['category'] = data['category'] ?? 'Divers';
        data['status'] = data['status'] ?? 'active';
        
        // Convertir les timestamps en DateTime
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        } else if (data['date'] == null) {
          data['date'] = DateTime.now().toIso8601String();
        }
        
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
        } else if (data['created_at'] == null) {
          data['created_at'] = DateTime.now().toIso8601String();
        }
        
        if (data['updated_at'] is Timestamp) {
          data['updated_at'] = (data['updated_at'] as Timestamp).toDate().toIso8601String();
        } else if (data['updated_at'] == null) {
          data['updated_at'] = DateTime.now().toIso8601String();
        }
        
        events.add(Event.fromJson(data));
      }
      
      // Si aucun événement n'existe et que l'utilisateur est connecté en tant qu'organisateur, créer des événements par défaut
      if (_user != null && events.isEmpty && _user!.role == 'organizer') {
        await _createDefaultEvents();
        return getEvents();
      }
      
      return events;
    } catch (e) {
      if (e.toString().contains('ProgressEvent')) {
        throw Exception('Erreur de connexion. Veuillez vérifier votre connexion internet.');
      }
      throw Exception('Erreur lors du chargement des événements: ${e.toString()}');
    }
  }
  
  // Création d'événements par défaut
  Future<void> _createDefaultEvents() async {
    if (_user == null || _user!.role != 'organizer') {
      return;
    }
    
    final batch = _firestore.batch();
    
    // Événement 1
    DocumentReference event1Ref = _firestore.collection('events').doc();
    batch.set(event1Ref, {
      'title': 'Concert de Jazz',
      'description': 'Un concert de jazz avec les meilleurs musiciens de la région',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 5))),
      'location': 'Salle de concert, Paris',
      'price': 25.0,
      'capacity': 200,
      'organizer_id': _user!.id,
      'image_url': 'https://source.unsplash.com/random/800x600/?jazz',
      'category': 'Musique',
      'status': 'active',
      'available_tickets': 200,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    // Événement 2
    DocumentReference event2Ref = _firestore.collection('events').doc();
    batch.set(event2Ref, {
      'title': 'Festival de Cinéma',
      'description': 'Projection de films indépendants',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 10))),
      'location': 'Cinéma Le Rex, Lyon',
      'price': 15.0,
      'capacity': 150,
      'organizer_id': _user!.id,
      'image_url': 'https://source.unsplash.com/random/800x600/?cinema',
      'category': 'Cinéma',
      'status': 'active',
      'available_tickets': 150,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    // Événement 3
    DocumentReference event3Ref = _firestore.collection('events').doc();
    batch.set(event3Ref, {
      'title': 'Conférence Tech',
      'description': 'Les dernières innovations en IA et machine learning',
      'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 15))),
      'location': 'Centre de conférences, Bordeaux',
      'price': 50.0,
      'capacity': 300,
      'organizer_id': _user!.id,
      'image_url': 'https://source.unsplash.com/random/800x600/?technology',
      'category': 'Technologie',
      'status': 'active',
      'available_tickets': 300,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
  
  // Achat de ticket
  Future<void> purchaseTicket(String eventId) async {
    try {
      
      // Vérifier si l'événement existe
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) {
        throw Exception('Événement non trouvé');
      }
      
      Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
      
      // Vérifier si des billets sont disponibles
      int availableTickets = eventData['available_tickets'] ?? 0;
      
      if (availableTickets <= 0) {
        throw Exception('Plus de billets disponibles pour cet événement');
      }
      
      // Générer un code de ticket unique
      String ticketCode = 'TIX-${_user!.id}-${DateTime.now().millisecondsSinceEpoch}';
      
      // Créer un ticket dans Firestore
      DocumentReference ticketRef = await _firestore.collection('tickets').add({
        'event_id': eventId,
        'user_id': _auth.currentUser!.uid,
        'purchase_date': FieldValue.serverTimestamp(),
        'is_validated': false,
        'ticket_code': ticketCode,
        'qr_code': '$ticketCode|$eventId', // Format: ticketCode|eventId
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Mettre à jour le nombre de billets disponibles
      await _firestore.collection('events').doc(eventId).update({
        'available_tickets': availableTickets - 1,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Mettre à jour le ticket avec son ID
      await ticketRef.update({
        'id': ticketRef.id,
      });
      
      // Envoyer un email de confirmation d'achat de ticket
      String eventDate = '';
      if (eventData['date'] != null) {
        try {
          var dateValue = eventData['date'];
          DateTime date;
          if (dateValue is Timestamp) {
            date = dateValue.toDate();
          } else if (dateValue is String) {
            date = DateTime.parse(dateValue);
          } else if (dateValue is DateTime) {
            date = dateValue;
          } else {
            date = DateTime.now();
          }
          eventDate = DateFormat('dd/MM/yyyy').format(date);
          if (eventData['time'] != null) {
            eventDate += ' à ${eventData['time']}';
          }
        } catch (e) {
          eventDate = eventData['date'].toString();
        }
      }
      
      await EmailService.sendTicketConfirmation(
        to: _user!.email,
        eventName: eventData['title'] ?? 'Événement',
        ticketCode: ticketCode,
        eventDate: eventDate,
        eventLocation: eventData['location'] ?? 'Lieu non spécifié',
      );
    } catch (e) {
      throw Exception('Échec de l\'achat du ticket: ${e.toString()}');
    }
  }
  
  // Récupération des tickets de l'utilisateur
  Future<List<dynamic>> getUserTickets() async {
    try {
      
      // Récupérer les tickets de l'utilisateur
      QuerySnapshot ticketSnapshot = await _firestore
          .collection('tickets')
          .where('user_id', isEqualTo: _auth.currentUser!.uid)
          .get();
      
      List<dynamic> tickets = [];
      
      for (var doc in ticketSnapshot.docs) {
        Map<String, dynamic> ticketData = doc.data() as Map<String, dynamic>;
        ticketData['id'] = doc.id;
        
        // Récupérer les informations de l'événement
        String eventId = ticketData['event_id'] ?? '';
        if (eventId.isEmpty) continue; // Ignorer les tickets sans event_id valide
        
        DocumentSnapshot eventDoc = await _firestore
            .collection('events')
            .doc(eventId)
            .get();
        
        if (eventDoc.exists) {
          Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
          
          // Convertir les timestamps en String
          Timestamp purchaseDate = ticketData['purchase_date'] ?? Timestamp.now();
          Timestamp eventDate = eventData['date'] ?? Timestamp.now();
          
          tickets.add({
            'id': doc.id,
            'event_id': ticketData['event_id'] ?? '',
            'event_name': eventData['title'] ?? 'Sans titre',
            'ticket_code': ticketData['ticket_code'] ?? 'CODE-${doc.id}',
            'purchase_date': purchaseDate.toDate().toIso8601String(),
            'is_validated': ticketData['is_validated'] ?? false,
            'event_date': eventDate.toDate().toIso8601String(),
            'event_location': eventData['location'] ?? 'Emplacement non spécifié',
          });
        }
      }
      
      return tickets;
    } catch (e) {
      throw Exception('Échec de la récupération des tickets: ${e.toString()}');
    }
  }
  
  // Validation d'un ticket
  Future<void> validateTicket(String ticketId, String eventId) async {
    try {

      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }

      // Vérifier si le ticket existe
      DocumentSnapshot ticketDoc = await _firestore.collection('tickets').doc(ticketId).get();

      if (!ticketDoc.exists) {
        throw Exception('Ticket non trouvé');
      }

      Map<String, dynamic> ticketData = ticketDoc.data() as Map<String, dynamic>;

      // Vérifier si le ticket correspond à l'événement
      if (ticketData['event_id'] != eventId) {
        throw Exception('Ticket invalide pour cet événement');
      }

      // Vérifier si le ticket n'a pas déjà été validé
      if (ticketData['is_validated'] == true) {
        throw Exception('Ticket déjà validé');
      }

      // Valider le ticket
      await _firestore.collection('tickets').doc(ticketId).update({
        'is_validated': true,
        'validated_at': FieldValue.serverTimestamp(),
        'validated_by': _user!.id,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Échec de la validation du ticket: ${e.toString()}');
    }
  }

  // Récupération des statistiques de validation
  Future<Map<String, dynamic>> getValidationStats() async {
    try {
      
      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }
      
      // Récupérer tous les tickets
      QuerySnapshot ticketSnapshot = await _firestore.collection('tickets').get();
      
      int totalTickets = ticketSnapshot.docs.length;
      int validatedTickets = 0;
      
      // Compter les tickets validés
      for (var doc in ticketSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['is_validated'] == true) {
          validatedTickets++;
        }
      }
      
      // Récupérer les statistiques par événement
      QuerySnapshot eventSnapshot = await _firestore.collection('events').get();
      List<Map<String, dynamic>> eventStats = [];
      
      for (var eventDoc in eventSnapshot.docs) {
        String eventId = eventDoc.id;
        Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
        
        // Récupérer les tickets pour cet événement
        QuerySnapshot eventTickets = await _firestore
            .collection('tickets')
            .where('event_id', isEqualTo: eventId)
            .get();
        
        int eventTotalTickets = eventTickets.docs.length;
        int eventValidatedTickets = 0;
        
        for (var ticketDoc in eventTickets.docs) {
          Map<String, dynamic> ticketData = ticketDoc.data() as Map<String, dynamic>;
          if (ticketData['is_validated'] == true) {
            eventValidatedTickets++;
          }
        }
        
        // S'assurer que le titre de l'événement n'est pas null
        String eventTitle = (eventData['title'] ?? 'Sans titre').toString();
        
        eventStats.add({
          'event_id': eventId,
          'event_name': eventTitle,
          'total_tickets': eventTotalTickets,
          'validated_tickets': eventValidatedTickets,
        });
      }
      
      return {
        'total_tickets': totalTickets,
        'validated_tickets': validatedTickets,
        'events': eventStats,
      };
    } catch (e) {
      throw Exception('Échec de la récupération des statistiques: ${e.toString()}');
    }
  }
  
  // Récupération du token d'authentification
  Future<String?> getToken() async {
    try {
      firebase_auth.User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        return await currentUser.getIdToken();
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération du token: $e');
      return null;
    }
  }
  
  // Récupération des en-têtes HTTP pour les requêtes authentifiées
  Future<Map<String, String>> getHeaders() async {
    final String? token = await getToken();
    if (token == null) {
      throw Exception('Token non disponible. Utilisateur non connecté.');
    }
    final String authToken = token; // Conversion explicite en String non-nullable
    return {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  // Récupération des événements de l'organisateur
  Future<List<Map<String, dynamic>>> getOrganizerEvents() async {
    try {
      
      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Récupérer les événements de l'organisateur
      QuerySnapshot eventSnapshot = await _firestore.collection('events')
          .where('organizer_id', isEqualTo: _user!.id)
          .get();
      
      List<Map<String, dynamic>> events = [];
      
      for (var doc in eventSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['name'] = data['title'] ?? 'Sans titre';
        
        // Convertir la date Timestamp en String
        if (data['date'] is Timestamp) {
          data['date'] = DateFormat('dd/MM/yyyy').format((data['date'] as Timestamp).toDate());
        } else {
          data['date'] = 'Date non spécifiée';
        }
        
        events.add(data);
      }
      
      
      return events;
    } catch (e) {
      throw Exception('Échec de la récupération des événements: ${e.toString()}');
    }
  }
  
  // Création d'un événement
  Future<String> createEvent(Map<String, dynamic> eventData) async {
    try {
      
      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Préparer les données de l'événement
      final data = {
        'title': eventData['title'] ?? eventData['name'] ?? 'Sans titre',
        'description': eventData['description'],
        'location': eventData['location'],
        'price': eventData['price'],
        'date': eventData['date'],
        'time': eventData['time'],
        'imageUrl': eventData['imageUrl'] ?? 'https://via.placeholder.com/400x200?text=Eventikets',
        'isAvailable': true,
        'capacity': eventData['capacity'] ?? 100,
        'organizer_id': _user!.id,
        'created_at': FieldValue.serverTimestamp(),
      };
      
      // Ajouter l'événement à Firestore
      DocumentReference docRef = await _firestore.collection('events').add(data);
      
      // Envoyer une notification par email aux utilisateurs
      if (eventData['notifyUsers'] == true) {
        await _notifyUsersAboutNewEvent(data);
      }
      
      return docRef.id;
    } catch (e) {
      throw Exception('Échec de la création de l\'événement: ${e.toString()}');
    }
  }
  
  // Notifier les utilisateurs d'un nouvel événement
  Future<void> _notifyUsersAboutNewEvent(Map<String, dynamic> eventData) async {
    try {
      // Récupérer tous les utilisateurs standards
      QuerySnapshot userSnapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'user')
          .get();
      
      String eventDate = '';
      if (eventData['date'] != null) {
        try {
          final date = DateTime.parse(eventData['date']);
          eventDate = DateFormat('dd/MM/yyyy').format(date);
          if (eventData['time'] != null) {
            eventDate += ' à ${eventData['time']}';
          }
        } catch (e) {
          eventDate = eventData['date'];
        }
      }
      
      // Envoyer un email à chaque utilisateur
      for (var doc in userSnapshot.docs) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        String userEmail = userData['email'];
        
        await EmailService.sendEventNotification(
          to: userEmail,
          eventName: eventData['title'],
          eventDate: eventDate,
          eventLocation: eventData['location'],
        );
      }
    } catch (e) {
      print('Erreur lors de la notification des utilisateurs: $e');
      // Ne pas propager l'erreur pour ne pas bloquer la création d'événement
    }
  }
  
  // Mise à jour d'un événement
  Future<void> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      
      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Vérifier si l'événement existe et appartient à l'organisateur
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) {
        throw Exception('Événement non trouvé');
      }
      
      Map<String, dynamic> data = eventDoc.data() as Map<String, dynamic>;
      
      if (data['organizer_id'] != _user!.id) {
        throw Exception('Vous n\'êtes pas autorisé à modifier cet événement');
      }
      
      // Préparer les données de mise à jour
      final updateData = {
        'title': eventData['title'] ?? eventData['name'] ?? 'Sans titre',
        'description': eventData['description'],
        'location': eventData['location'],
        'price': eventData['price'],
        'date': eventData['date'],
        'time': eventData['time'],
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Si une nouvelle image est fournie, mettre à jour l'URL
      if (eventData['imageUrl'] != null) {
        updateData['imageUrl'] = eventData['imageUrl'];
      }
      
      // Si la capacité est fournie, mettre à jour
      if (eventData['capacity'] != null) {
        updateData['capacity'] = eventData['capacity'];
      }
      
      // Mettre à jour l'événement
      await _firestore.collection('events').doc(eventId).update(updateData);
    } catch (e) {
      throw Exception('Échec de la mise à jour de l\'événement: ${e.toString()}');
    }
  }
  
  // Suppression d'un événement
  Future<void> deleteEvent(String eventId) async {
    try {
      
      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Vérifier si l'événement existe et appartient à l'organisateur
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) {
        throw Exception('Événement non trouvé');
      }
      
      Map<String, dynamic> data = eventDoc.data() as Map<String, dynamic>;
      
      if (data['organizer_id'] != _user!.id) {
        throw Exception('Vous n\'êtes pas autorisé à supprimer cet événement');
      }
      
      // Supprimer l'événement
      await _firestore.collection('events').doc(eventId).delete();
      
      // Supprimer également tous les tickets associés à cet événement
      QuerySnapshot ticketSnapshot = await _firestore
          .collection('tickets')
          .where('event_id', isEqualTo: eventId)
          .get();
      
      for (var doc in ticketSnapshot.docs) {
        await _firestore.collection('tickets').doc(doc.id).delete();
      }
    } catch (e) {
      throw Exception('Échec de la suppression de l\'événement: ${e.toString()}');
    }
  }
  
  // Mise à jour du profil utilisateur
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Préparer les données de mise à jour
      final updateData = {
        'name': profileData['name'],
      };
      
      // Si un email est fourni et différent de l'actuel, mettre à jour
      if (profileData['email'] != null && profileData['email'] != _user!.email) {
        // Mettre à jour l'email dans Firebase Auth
        await _auth.currentUser!.updateEmail(profileData['email']);
        updateData['email'] = profileData['email'];
      }
      
      // Mettre à jour le profil dans Firestore
      await _firestore.collection('users').doc(_user!.id).update(updateData);
      
      // Mettre à jour l'utilisateur local
      _getUserData(_user!.id);
      
      // Envoyer un email de confirmation de mise à jour du profil
      if (profileData['sendEmail'] == true) {
        await EmailService.sendEmail(
          to: _user!.email,
          subject: 'Confirmation de mise à jour du profil',
          body: 'Votre profil a été mis à jour avec succès.\n\nNom: ${profileData['name']}\nEmail: ${profileData['email'] ?? _user!.email}',
        );
      }
    } catch (e) {
      throw Exception('Échec de la mise à jour du profil: ${e.toString()}');
    }
  }
  
  // Contacter un organisateur d'événement
  Future<bool> contactOrganizer(String eventId, String message) async {
    try {
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Récupérer les informations de l'événement
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) {
        throw Exception('Événement non trouvé');
      }
      
      Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
      String organizerId = eventData['organizer_id'];
      
      // Récupérer les informations de l'organisateur
      DocumentSnapshot organizerDoc = await _firestore.collection('users').doc(organizerId).get();
      
      if (!organizerDoc.exists) {
        throw Exception('Organisateur non trouvé');
      }
      
      Map<String, dynamic> organizerData = organizerDoc.data() as Map<String, dynamic>;
      String organizerEmail = organizerData['email'];
      
      // Envoyer l'email à l'organisateur
      bool success = await EmailService.sendContactOrganizer(
        to: organizerEmail,
        from: _user!.email,
        eventName: eventData['title'],
        message: message,
      );
      
      return success;
    } catch (e) {
      print('Erreur lors du contact avec l\'organisateur: $e');
      return false;
    }
  }
  
  // Envoyer un rappel d'événement aux participants
  Future<void> sendEventReminders(String eventId) async {
    try {
      
      // Vérifier si l'utilisateur est un organisateur
      if (_user!.role != 'organizer') {
        throw Exception('Accès non autorisé');
      }
      
      // Simuler un délai réseau
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Récupérer les informations de l'événement
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) {
        throw Exception('Événement non trouvé');
      }
      
      Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
      
      // Vérifier si l'événement appartient à l'organisateur
      if (eventData['organizer_id'] != _user!.id) {
        throw Exception('Vous n\'êtes pas autorisé à envoyer des rappels pour cet événement');
      }
      
      // Récupérer tous les tickets pour cet événement
      QuerySnapshot ticketSnapshot = await _firestore
          .collection('tickets')
          .where('event_id', isEqualTo: eventId)
          .get();
      
      String eventDate = '';
      if (eventData['date'] != null) {
        try {
          final date = DateTime.parse(eventData['date']);
          eventDate = DateFormat('dd/MM/yyyy').format(date);
          if (eventData['time'] != null) {
            eventDate += ' à ${eventData['time']}';
          }
        } catch (e) {
          eventDate = eventData['date'];
        }
      }
      
      // Pour chaque ticket, envoyer un rappel à l'utilisateur
      for (var doc in ticketSnapshot.docs) {
        Map<String, dynamic> ticketData = doc.data() as Map<String, dynamic>;
        String userId = ticketData['user_id'];
        
        // Récupérer les informations de l'utilisateur
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          String userEmail = userData['email'];
          
          await EmailService.sendEventReminder(
            to: userEmail,
            eventName: eventData['title'],
            eventDate: eventDate,
            eventLocation: eventData['location'],
            ticketCode: ticketData['ticket_code'],
          );
        }
      }
    } catch (e) {
      throw Exception('Échec de l\'envoi des rappels: ${e.toString()}');
    }
  }
}
