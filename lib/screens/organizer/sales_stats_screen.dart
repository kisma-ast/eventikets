import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firebase_service.dart';

class SalesStatsScreen extends StatefulWidget {
  const SalesStatsScreen({super.key});

  @override
  State<SalesStatsScreen> createState() => _SalesStatsScreenState();
}

class _SalesStatsScreenState extends State<SalesStatsScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _statsData = {};
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      // TODO: Implement API call to get sales statistics
      // final stats = await apiService.getSalesStats(_selectedPeriod);
      setState(() {
        _statsData = {
          'totalRevenue': 0.0,
          'ticketsSold': 0,
          'averagePrice': 0.0,
          'topEvents': [],
          'salesByDay': [],
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'week',
          label: Text('Semaine'),
        ),
        ButtonSegment<String>(
          value: 'month',
          label: Text('Mois'),
        ),
        ButtonSegment<String>(
          value: 'year',
          label: Text('Année'),
        ),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() {
          _selectedPeriod = newSelection.first;
        });
        _loadStats();
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEventsList() {
    final topEvents = _statsData['topEvents'] as List? ?? [];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Événements les plus vendus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (topEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Aucune donnée disponible'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topEvents.length,
              itemBuilder: (context, index) {
                final event = topEvents[index];
                return ListTile(
                  title: Text(event['name'] ?? ''),
                  subtitle: Text('${event['tickets_sold']} billets vendus'),
                  trailing: Text(
                    '${event['revenue'].toStringAsFixed(2)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildSalesChart() {
    final salesByDay = _statsData['salesByDay'] as List? ?? [];
    
    // Données par défaut pour la démonstration si aucune donnée n'est disponible
    List<FlSpot> spots = [];
    if (salesByDay.isEmpty) {
      // Générer des données de démonstration
      spots = List.generate(7, (index) {
        return FlSpot(index.toDouble(), (index * 2 + 5).toDouble());
      });
    } else {
      spots = salesByDay.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return FlSpot(
          index.toDouble(), 
          (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0,
        );
      }).toList();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Évolution des ventes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // Afficher les jours de la semaine ou les dates selon la période
                          String text = '';
                          if (_selectedPeriod == 'week') {
                            final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                            if (value >= 0 && value < days.length) {
                              text = days[value.toInt()];
                            }
                          } else {
                            text = value.toInt().toString();
                          }
                          return Text(text, style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
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
        title: const Text('Statistiques des Ventes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Revenus Totaux',
                      '${_statsData['totalRevenue']?.toStringAsFixed(2) ?? '0.00'} €',
                      'Pour la période sélectionnée',
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Billets Vendus',
                      _statsData['ticketsSold']?.toString() ?? '0',
                      'Pour la période sélectionnée',
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Prix Moyen',
                      '${_statsData['averagePrice']?.toStringAsFixed(2) ?? '0.00'} €',
                      'Par billet',
                    ),
                    const SizedBox(height: 24),
                    _buildSalesChart(),
                    const SizedBox(height: 16),
                    _buildTopEventsList(),
                  ],
                ),
              ),
            ),
    );
  }
}