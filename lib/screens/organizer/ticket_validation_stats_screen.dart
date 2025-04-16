import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firebase_service.dart';

class TicketValidationStatsScreen extends StatefulWidget {
  const TicketValidationStatsScreen({super.key});

  @override
  State<TicketValidationStatsScreen> createState() => _TicketValidationStatsScreenState();
}

class _TicketValidationStatsScreenState extends State<TicketValidationStatsScreen> {
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final stats = await firebaseService.getValidationStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques de validation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
              ? const Center(child: Text('Aucune statistique disponible'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total des billets: ${_stats['total_tickets'] ?? 0}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Billets validés: ${_stats['validated_tickets'] ?? 0}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Billets non validés: ${_stats['unvalidated_tickets'] ?? 0}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_stats['total_tickets'] != null && _stats['total_tickets'] > 0)
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      color: Colors.green,
                                      value: (_stats['validated_tickets'] ?? 0).toDouble(),
                                      title: '${((_stats['validated_tickets'] ?? 0) / _stats['total_tickets'] * 100).toStringAsFixed(1)}%',
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      color: Colors.red,
                                      value: (_stats['unvalidated_tickets'] ?? 0).toDouble(),
                                      title: '${((_stats['unvalidated_tickets'] ?? 0) / _stats['total_tickets'] * 100).toStringAsFixed(1)}%',
                                      radius: 100,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Évolution des validations',
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
                                            // Afficher les jours de la semaine
                                            final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                                            String text = '';
                                            if (value >= 0 && value < days.length) {
                                              text = days[value.toInt()];
                                            }
                                            return Text(text, style: const TextStyle(fontSize: 10));
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    lineBarsData: [
                                      LineChartBarData(
                                        // Données de démonstration pour l'évolution des validations
                                        spots: List.generate(7, (index) {
                                          return FlSpot(index.toDouble(), (index * 1.5 + 3).toDouble());
                                        }),
                                        isCurved: true,
                                        color: Colors.green,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(show: true),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                  ),
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
}