import 'package:intl/intl.dart';

class Event {
  final int id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final double price;
  final int capacity;
  final int organizerId;
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
    return Event(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      title: json['title'],
      description: json['description'],
      date: json['date'] is String ? DateTime.parse(json['date']) : json['date'],
      location: json['location'],
      organizerId: json['organizer_id'] ?? json['organizerId'] ?? 1,
      price: double.parse(json['price'].toString()),
      capacity: json['capacity'] ?? json['total_tickets'] ?? 100,
      availableTickets: json['available_tickets'] ?? json['availableTickets'] ?? json['capacity'] ?? 100,
      status: json['status'] ?? 'active',
      category: json['category'] ?? 'Divers',
      imageUrl: json['image_url'] ?? json['imageUrl'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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