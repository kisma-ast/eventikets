import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/ticket.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'scan_ticket_screen.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final List<Ticket> _tickets = <Ticket>[];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMoreTickets();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadMoreTickets() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final newTickets = await firebaseService.getUserTickets();
      final ticketsList = (newTickets as List).map((json) => Ticket.fromJson(json)).toList();
      
      if (ticketsList.isEmpty) {
        _hasMore = false;
      } else {
        setState(() {
          _tickets.addAll(ticketsList);
          _currentPage++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasMore && !_isLoading) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 200) {
        _loadMoreTickets();
      }
    }
  }

  void _showTicketDetails(Ticket ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Billet #${ticket.ticketNumber}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              QrImageView(
                data: ticket.qrCode,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 16),
              Text(
                'Code du billet: ${ticket.ticketNumber}',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Statut:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ticket.isPaid
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ticket.isPaid ? 'Payé' : 'En attente',
                  style: TextStyle(
                    color: ticket.isPaid ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Prix:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${ticket.price.toStringAsFixed(2)} €',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        actions: [
          if (!ticket.isPaid)
            TextButton(
              onPressed: () {
                // TODO: Implémenter le paiement
              },
              child: const Text('Payer'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes billets'),
        actions: [
          if (Provider.of<FirebaseService>(context).user?.role == 'organizer')
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScanTicketScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _tickets.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? const Center(child: Text('Aucun billet trouvé'))
              : RefreshIndicator(
                  onRefresh: () async {
                    _tickets.clear();
                    setState(() {
                      _hasMore = true;
                    });
                    await _loadMoreTickets();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _tickets.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _tickets.length) {
                        if (_hasMore) {
                          return const LoadingIndicator();
                        }
                        return const SizedBox();
                      }
                      final ticket = _tickets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () => _showTicketDetails(ticket),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Billet #${ticket.ticketNumber}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ticket.isPaid
                                            ? Colors.green[100]
                                            : Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ticket.isPaid ? 'Payé' : 'En attente',
                                        style: TextStyle(
                                          color: ticket.isPaid
                                              ? Colors.green[900]
                                              : Colors.orange[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Prix: ${ticket.price.toStringAsFixed(2)} €',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}