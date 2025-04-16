import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';

class EventFormScreen extends StatefulWidget {
  final Map<String, dynamic>? event;

  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _imageUrl = widget.event!['imageUrl'];
      _nameController.text = widget.event!['title'] ?? widget.event!['name'] ?? '';
      _descriptionController.text = widget.event!['description'] ?? '';
      _locationController.text = widget.event!['location'] ?? '';
      _priceController.text = widget.event!['price']?.toString() ?? '';
      
      // Définir la date et l'heure à partir de l'événement
      if (widget.event!['date'] != null) {
        try {
          _selectedDate = DateTime.parse(widget.event!['date']);
        } catch (e) {
          print('Erreur lors de la conversion de la date: $e');
        }
      }
      
      if (widget.event!['time'] != null) {
        try {
          final timeParts = widget.event!['time'].split(':');
          if (timeParts.length >= 2) {
            _selectedTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
          }
        } catch (e) {
          print('Erreur lors de la conversion de l\'heure: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      setState(() => _selectedTime = pickedTime);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une heure')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final eventData = {
        'title': _nameController.text, // Changé de 'name' à 'title' pour correspondre au modèle Event
        'description': _descriptionController.text,
        'location': _locationController.text,
        'price': double.parse(_priceController.text),
        'date': _selectedDate!.toIso8601String(),
        'time': '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      };

      if (_imageFile != null) {
        final imageUrl = await firebaseService.uploadEventImage(_imageFile!);
        eventData['imageUrl'] = imageUrl;
      }

      if (widget.event != null) {
        await firebaseService.updateEvent(widget.event!['id'], eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Événement mis à jour avec succès')),
          );
        }
      } else {
        await firebaseService.createEvent(eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Événement créé avec succès')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image sélectionnée avec succès')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune image sélectionnée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l\'image: ${e.toString()}')),
      );
    }
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        if (_imageFile != null)
          Stack(
            alignment: Alignment.topRight,
            children: [
              Image.file(
                _imageFile!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _imageFile = null;
                }),
              ),
            ],
          )
        else if (_imageUrl != null)
          Stack(
            alignment: Alignment.topRight,
            children: [
              Image.network(
                _imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _imageUrl = null;
                }),
              ),
            ],
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.image),
          label: Text(_imageFile == null && _imageUrl == null
              ? 'Ajouter une image'
              : 'Changer l\'image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Créer un Événement' : 'Modifier l\'Événement'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImagePicker(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'événement',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lieu',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un lieu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Prix',
                        border: OutlineInputBorder(),
                        suffixText: '€',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un prix';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Veuillez entrer un prix valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _selectedDate == null
                                  ? 'Sélectionner une date'
                                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _selectedTime == null
                                  ? 'Sélectionner une heure'
                                  : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveEvent,
                      child: Text(
                        widget.event == null ? 'Créer l\'Événement' : 'Mettre à jour l\'Événement',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}