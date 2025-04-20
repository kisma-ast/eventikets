import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/welcome_gate_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/force_password_change_screen.dart';
import 'screens/events/events_screen.dart';
import 'screens/events/contact_organizer_screen.dart';
import 'screens/tickets/tickets_screen.dart';
import 'screens/organizer/dashboard_screen.dart';
import 'screens/organizer/events_management_screen.dart';
import 'screens/organizer/event_form_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'theme/app_theme.dart';
import 'models/user.dart';
import 'models/favorite_event.dart';

void main() async {
  // Initialiser Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => FavoriteEvent()),
      ],
      child: Consumer<FirebaseService>(
        builder: (context, firebaseService, _) {
          // Vérifier si l'utilisateur doit changer son mot de passe
          final user = firebaseService.user;
          if (user != null && user.hasDefaultCredentials) {
            return MaterialApp(
              title: 'Eventikets',
              theme: AppTheme.darkTheme(),
              debugShowCheckedModeBanner: false,
              home: const ForcePasswordChangeScreen(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/force_password_change': (context) => const ForcePasswordChangeScreen(),
              },
            );
          }
          
          return MaterialApp(
            title: 'Eventikets',
            theme: AppTheme.darkTheme(),
            debugShowCheckedModeBanner: false,
            home: const WelcomeGateScreen(),
            routes: {
              '/main': (context) => const MainScreen(),
              '/events': (context) => const EventsScreen(),
              '/login': (context) => const LoginScreen(),
              '/favorites': (context) => const FavoritesScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isOrganizer = false;
  bool _isLoading = true;
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navigationItems;

  void _initializeScreens(bool isOrganizer) {
    if (isOrganizer) {
      _screens = const [
        DashboardScreen(),
        EventsManagementScreen(),
        ProfileScreen(),
      ];
      _navigationItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Tableau de bord',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_note),
          label: 'Gestion',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    } else {
      _screens = const [
        EventsScreen(),
        TicketsScreen(),
        ProfileScreen(),
      ];
      _navigationItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Événements',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.confirmation_number),
          label: 'Tickets',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeScreens(false);
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (!mounted) return;
    
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);

      if (firebaseService.user != null) {
        _setUserAndNavigation(firebaseService.user!);
      } else {
        // L'utilisateur n'est pas connecté, mais nous sommes déjà sur MainScreen
        // Nous ne redirigerons pas car cela créerait une boucle
      }
    } catch (e) {
      // Gérer l'erreur sans redirection
      print('Erreur lors de la vérification du rôle: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setUserAndNavigation(User user) {
    if (!mounted) return;
    
    final isOrganizer = user.role == 'organizer';
    if (isOrganizer != _isOrganizer) {
      setState(() {
        _isOrganizer = isOrganizer;
        _initializeScreens(isOrganizer);
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: AppTheme.surfaceColor,
            selectedItemColor: AppTheme.accentColor,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontSize: 14),
            elevation: 8,
            type: BottomNavigationBarType.fixed,
          ),
        ),
        child: BottomNavigationBar(
          items: _navigationItems,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}
