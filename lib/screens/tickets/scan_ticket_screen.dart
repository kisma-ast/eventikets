import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../../services/firebase_service.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class ScanTicketScreen extends StatefulWidget {
  const ScanTicketScreen({super.key});

  @override
  State<ScanTicketScreen> createState() => _ScanTicketScreenState();
}

class _ScanTicketScreenState extends State<ScanTicketScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Color _overlayColor = Colors.green;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (isProcessing || scanData.code == null) return;

      setState(() {
        isProcessing = true;
      });

      try {
        // Extraire les informations du ticket du QR code
        final ticketData = scanData.code!.split('|');
        if (ticketData.length != 2) throw Exception('QR code invalide');

        final ticketId = ticketData[0];
        final eventId = ticketData[1];

        // Valider le ticket dans Firebase
        final firebaseService = FirebaseService();
        await firebaseService.validateTicket(ticketId, eventId);

        // Retour haptique et sonore
        HapticFeedback.heavyImpact();
        await _audioPlayer.play(AssetSource('sounds/success.mp3'));

        setState(() => _overlayColor = Colors.green);

        // Afficher un message de succès
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket validé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        // Retour haptique et sonore pour l'erreur
        HapticFeedback.vibrate();
        await _audioPlayer.play(AssetSource('sounds/error.mp3'));

        setState(() => _overlayColor = Colors.red);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            isProcessing = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un ticket'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: _overlayColor,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                isProcessing ? 'Traitement en cours...' : 'Scannez un ticket',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}