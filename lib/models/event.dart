import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final double price;
  final int capacity;
  final String organizerId;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final String status;
  final int availableTickets;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.price,
    required this.capacity,
    required this.organizerId,
    this.imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.category = 'Divers',
    this.status = 'active',
    int? availableTickets,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now(),
    this.availableTickets = availableTickets ?? capacity;

  factory Event.fromJson(Map<String, dynamic> json) {
    // Fonction pour convertir différents types de date en DateTime
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue is String) return DateTime.parse(dateValue);
      // Gestion des Timestamp de Firebase
      if (dateValue.runtimeType.toString().contains('Timestamp')) {
        return DateTime.fromMillisecondsSinceEpoch(
          dateValue.millisecondsSinceEpoch,
        );
      }
      return DateTime.now();
    }

    return Event(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      date: parseDate(json['date']),
      location: json['location'] ?? '',
      organizerId: json['organizer_id'].toString(),
      price: json['price'] is double
          ? json['price']
          : double.parse(json['price'].toString()),
      capacity: json['capacity'] is int
          ? json['capacity']
          : int.parse(json['capacity'].toString()),
      availableTickets: json['available_tickets'] ?? json['availableTickets'] ?? json['capacity'] ?? 100,
      status: json['status'] ?? 'active',
      category: json['category'] ?? 'Divers',
      imageUrl: json['image_url'] ?? json['imageUrl'],
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'location': location,
      'organizer_id': organizerId,
      'category': category,
      'price': price,
      'capacity': capacity,
      'available_tickets': availableTickets,
      'status': status,
      'image_url': imageUrl,
      'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt),
      'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(updatedAt),
    };
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(date);
  String get formattedTime => DateFormat('HH:mm').format(date);
  bool get isAvailable => availableTickets > 0 && status == 'active';
}