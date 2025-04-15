import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../models/user.dart' as app_user;
import '../models/event.dart';

class FirebaseService with ChangeNotifier {
  // Firebase instances
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
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
  Future<app_user.User> register(String name, String email, String password, {String role = 'user'}) async {
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
          'has_default_credentials': role == 'organizer',
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
          hasDefaultCredentials: role == 'organizer'
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
      
      // Réauthentifier l'utilisateur avec son mot de passe actuel
      firebase_auth.AuthCredential credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      
      await currentUser.reauthenticateWithCredential(credential);
      
      // Mettre à jour le mot de passe
      await currentUser.updatePassword(newPassword);
      
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
  
  // Récupération des événements
  Future<List<Event>> getEvents() async {
    try {
      if (_user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Récupérer les événements depuis Firestore
      QuerySnapshot eventSnapshot = await _firestore.collection('events').get();
      
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
      
      // Si aucun événement n'existe, créer des événements par défaut pour l'organisateur
      if (events.isEmpty && _user!.role == 'organizer') {
        await _createDefaultEvents();
        return getEvents();
      }
      
      return events;
    } catch (e) {
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
  Future<void> purchaseTicket(int eventId) async {
    try {
      if (_user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Vérifier si l'événement existe
      DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId.toString()).get();
      
      if (!eventDoc.exists) {
        throw Exception('Événement non trouvé');
      }
      
      Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;
      
      // Vérifier si des billets sont disponibles
      int availableTickets = eventData['available_tickets'] ?? 0;
      
      if (availableTickets <= 0) {
        throw Exception('Plus de billets disponibles pour cet événement');
      }
      
      // Créer un ticket dans Firestore
      await _firestore.collection('tickets').add({
        'event_id': eventId.toString(),
        'user_id': _auth.currentUser!.uid,
        'purchase_date': FieldValue.serverTimestamp(),
        'is_validated': false,
        'ticket_code': 'TIX-${_user!.id}-${DateTime.now().millisecondsSinceEpoch}',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Mettre à jour le nombre de billets disponibles
      await _firestore.collection('events').doc(eventId.toString()).update({
        'available_tickets': availableTickets - 1,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Échec de l\'achat du ticket: ${e.toString()}');
    }
  }
  
  // Récupération des tickets de l'utilisateur
  Future<List<dynamic>> getUserTickets() async {
    try {
      if (_user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
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
  
  // Récupération des statistiques de validation
  Future<Map<String, dynamic>> getValidationStats() async {
    try {
      if (_user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
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
}
