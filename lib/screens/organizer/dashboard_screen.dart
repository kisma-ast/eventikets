import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../events/events_screen.dart';
import '../tickets/tickets_screen.dart';
import 'event_form_screen.dart';
import 'ticket_validation_stats_screen.dart';
import 'sales_stats_screen.dart';
import '../tickets/scan_ticket_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      // Récupérer les événements et tickets via les méthodes publiques de FirebaseService
      final events = await firebaseService.getEvents();
      final tickets = await firebaseService.getUserTickets();
      
      // Calculer le total des revenus
      double totalRevenue = 0.0;
      int totalSoldTickets = 0;
      
      for (var ticket in tickets) {
        if (ticket['status'] == 'paid') {
          totalSoldTickets++;
          if (ticket.containsKey('price')) {
            totalRevenue += (ticket['price'] is num) 
                ? (ticket['price'] as num).toDouble() 
                : double.tryParse(ticket['price'].toString()) ?? 0.0;
          }
        }
      }
      
      setState(() {
        _dashboardData = {
          'totalEvents': events.length,
          'totalTickets': totalSoldTickets,
          'totalRevenue': totalRevenue,
        };
      });
    } catch (e) {
      print('Erreur lors du chargement des données: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du chargement des données: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vue d\'ensemble',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          'Événements',
                          _dashboardData['totalEvents']?.toString() ?? '0',
                          Icons.event,
                        ),
                        _buildStatCard(
                          'Billets Vendus',
                          _dashboardData['totalTickets']?.toString() ?? '0',
                          Icons.confirmation_number,
                        ),
                        _buildStatCard(
                          'Revenus',
                          '${_dashboardData['totalRevenue']?.toStringAsFixed(2) ?? '0.00'} €',
                          Icons.euro,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Actions Rapides',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 2.5,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildActionButton(
                          'Créer un Événement',
                          Icons.add,
                          Colors.blue.shade600,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventFormScreen(event: null),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          'Gérer les Billets',
                          Icons.list,
                          Colors.blue.shade500,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TicketsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          'Statistiques de Validation',
                          Icons.bar_chart,
                          Colors.blue.shade700,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TicketValidationStatsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          'Statistiques de Ventes',
                          Icons.trending_up,
                          Colors.blue.shade400,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SalesStatsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          'Scanner un Ticket',
                          Icons.qr_code_scanner,
                          Colors.blue.shade800,
                          () {
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
                  ],
                ),
              ),
            ),
    );
  }
}

Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.blue.shade300,
          color == Colors.blue.shade700 ? Colors.blue.shade800 : Colors.blue.shade700,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.blue.shade700.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}