class Ticket {
  final int id;
  final int eventId;
  final int userId;
  final String ticketNumber;
  final double price;
  final String status;
  final String? paymentIntentId;
  final String? paymentStatus;
  final String qrCode;

  Ticket({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.ticketNumber,
    required this.price,
    required this.status,
    this.paymentIntentId,
    this.paymentStatus,
    required this.qrCode,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      ticketNumber: json['ticket_number'],
      price: double.parse(json['price'].toString()),
      status: json['status'],
      paymentIntentId: json['payment_intent_id'],
      paymentStatus: json['payment_status'],
      qrCode: json['ticket_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'ticket_number': ticketNumber,
      'price': price,
      'status': status,
      'payment_intent_id': paymentIntentId,
      'payment_status': paymentStatus,
      'qr_code': qrCode,
    };
  }

  bool get isPaid => status == 'paid' && paymentStatus == 'completed';
}