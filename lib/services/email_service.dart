import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailService {
  // Méthode pour envoyer un email via l'application email par défaut
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
    List<String> bcc = const [],
    List<String> attachmentPaths = const [],
  }) async {
    try {
      final Email email = Email(
        body: body,
        subject: subject,
        recipients: [to],
        cc: cc,
        bcc: bcc,
        attachmentPaths: attachmentPaths,
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      return true;
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
      // Fallback: ouvrir l'URL mailto si l'envoi direct échoue
      return _launchMailto(to, subject, body);
    }
  }

  // Méthode alternative utilisant URL mailto
  static Future<bool> _launchMailto(String to, String subject, String body) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      return await launchUrl(emailLaunchUri);
    } catch (e) {
      print('Erreur lors de l\'ouverture de mailto: $e');
      return false;
    }
  }

  // Envoyer un email de confirmation d'achat de ticket
  static Future<bool> sendTicketConfirmation({
    required String to,
    required String eventName,
    required String ticketCode,
    required String eventDate,
    required String eventLocation,
  }) async {
    final subject = 'Confirmation de votre billet pour $eventName';
    final body = '''
Cher utilisateur,

Nous vous confirmons l'achat de votre billet pour l'événement "$eventName".

Détails de votre billet:
- Code du billet: $ticketCode
- Date de l'événement: $eventDate
- Lieu: $eventLocation

Veuillez présenter ce code lors de votre arrivée à l'événement.

Merci de votre achat et à bientôt!

L'équipe Eventikets
''';

    return await sendEmail(to: to, subject: subject, body: body);
  }

  // Envoyer un email de bienvenue après inscription
  static Future<bool> sendWelcomeEmail({
    required String to,
    required String name,
    String additionalContent = '',
  }) async {
    final subject = 'Bienvenue sur Eventikets!';
    final body = '''
Bonjour $name,

Nous sommes ravis de vous accueillir sur Eventikets, votre plateforme de gestion d'événements et de billetterie.

Vous pouvez dès maintenant :
- Parcourir les événements disponibles
- Acheter des billets
- Gérer vos réservations

N'hésitez pas à nous contacter si vous avez des questions.

Cordialement,
L'équipe Eventikets
''' + (additionalContent.isNotEmpty ? '\n$additionalContent' : '');

    return await sendEmail(to: to, subject: subject, body: body);
  }

  // Envoyer un email de notification d'événement
  static Future<bool> sendEventNotification({
    required String to,
    required String eventName,
    required String eventDate,
    required String eventLocation,
  }) async {
    final subject = 'Nouvel événement disponible: $eventName';
    final body = '''
Bonjour,

Nous sommes ravis de vous informer qu'un nouvel événement "$eventName" est disponible !

Détails de l'événement :
- Date : $eventDate
- Lieu : $eventLocation

N'hésitez pas à consulter l'application pour plus d'informations.

Cordialement,
L'équipe Eventikets
''';


    return await sendEmail(to: to, subject: subject, body: body);
  }

  // Envoyer un email de rappel d'événement
  static Future<bool> sendEventReminder({
    required String to,
    required String eventName,
    required String eventDate,
    required String eventLocation,
    required String ticketCode,
  }) async {
    final subject = 'Rappel: Votre événement $eventName approche!';
    final body = '''
Cher utilisateur,

Nous vous rappelons que l'événement "$eventName" auquel vous participez approche!

Détails de l'événement:
- Date: $eventDate
- Lieu: $eventLocation
- Code de votre billet: $ticketCode

N'oubliez pas de présenter votre billet à l'entrée.

À bientôt!
L'équipe Eventikets
''';

    return await sendEmail(to: to, subject: subject, body: body);
  }

  // Envoyer un email de contact à l'organisateur
  static Future<bool> sendContactOrganizer({
    required String to,
    required String from,
    required String eventName,
    required String message,
  }) async {
    final subject = 'Question concernant l\'événement: $eventName';
    final body = '''
Message de: $from

Concernant l'événement: $eventName

Message:
$message

---
Ce message a été envoyé via l'application Eventikets.
''';

    return await sendEmail(to: to, subject: subject, body: body);
  }
}
