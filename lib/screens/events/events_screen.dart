import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:lottie/lottie.dart';
import '../../services/firebase_service.dart';
import '../../models/event.dart';
import '../../models/event_card.dart';
import '../../models/favorite_event.dart';
import '../../theme/app_theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<Event>> _eventsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  double _maxPrice = 5000000.0;
  DateTime? _selectedDate;

  final List<String> _categories = [
    'Tous',
    'Musique',
    'Cinéma',
    'Technologie',
    'Sport',
    'Culture',
  ];

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Event> _filterEvents(List<Event> events) {
    return events.where((event) {
      final matchesSearch = event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          event.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          event.location.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'Tous' || event.category == _selectedCategory;

      final matchesPrice = event.price <= _maxPrice;

      final matchesDate = _selectedDate == null ||
          (event.date.year == _selectedDate!.year &&
              event.date.month == _selectedDate!.month &&
              event.date.day == _selectedDate!.day);

      return matchesSearch && matchesCategory && matchesPrice && matchesDate;
    }).toList();
  }

  Future<List<Event>> _loadEvents() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    return firebaseService.getEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Événements',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            tooltip: 'Voir mes favoris',
            onPressed: () => Navigator.pushNamed(context, '/favorites'),
          ),
          IconButton(
            icon: const Icon(Icons.confirmation_number, color: AppTheme.accentColor),
            onPressed: () => Navigator.pushNamed(context, '/events'),
            tooltip: 'Voir les événements',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un événement...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedCategory,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue!;
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null
                          ? 'Date'
                          : DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Prix max: ${_maxPrice.toStringAsFixed(0)} FCFA'),
                        SizedBox(
                          width: 200,
                          child: Slider(
                            value: _maxPrice,
                            min: 0,
                            max: 5000000,
                            divisions: 100,
                            onChanged: (value) {
                              setState(() {
                                _maxPrice = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withAlpha(204),
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: FutureBuilder<List<Event>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Lottie.asset(
                  'assets/animations/loading.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              );
            }

            if (snapshot.hasError) {
              String errorMessage = 'Une erreur est survenue';
              if (snapshot.error.toString().contains('ProgressEvent')) {
                errorMessage = 'Erreur de connexion. Veuillez vérifier votre connexion internet.';
              } else {
                errorMessage = snapshot.error.toString();
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _eventsFuture = _loadEvents();
                        });
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final allEvents = snapshot.data!;
            final filteredEvents = _filterEvents(allEvents);
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _eventsFuture = _loadEvents();
                });
              },
              child: Consumer<FavoriteEvent>(
                builder: (context, favoriteEvent, _) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return EventCard(
                        event: event,
                        isFavorite: favoriteEvent.isFavorite(event.id),
                        onFavorite: () => favoriteEvent.toggleFavorite(event.id),
                        onBuy: () {
                          Navigator.pushNamed(
                            context,
                            '/payment-method',
                            arguments: event,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
