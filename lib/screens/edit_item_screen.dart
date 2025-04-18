import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lostify/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditItemScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  String _category = 'lost';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item['title']);
    _descriptionController =
        TextEditingController(text: widget.item['description']);
    _locationController = TextEditingController(text: widget.item['location']);

    String categoryValue =
        (widget.item['category'] ?? 'lost').toString().toLowerCase();
    _category = categoryValue;

    // Debug print
    print('Editing item: ${widget.item}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final updatedData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'category': _category,
    };

    try {
      final itemId = widget.item['id'];

      // Debug info
      print('Updating item where id = $itemId');
      print('Update data: $updatedData');

      final response = await supabase
          .from('items')
          .update(updatedData)
          .eq('id', itemId)
          .select();

      print(response);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating item: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Edit Item', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_titleController, 'Title'),
              const SizedBox(height: 12),
              _buildField(_descriptionController, 'Description', maxLines: 4),
              const SizedBox(height: 12),
              _buildField(_locationController, 'Location'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Category',
                  labelStyle: GoogleFonts.poppins(color: AppColors.primary),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                dropdownColor: Colors.white,
                style: GoogleFonts.poppins(color: Colors.black),
                items: [
                  DropdownMenuItem(
                    value: 'lost',
                    child: Text('Lost',
                        style: GoogleFonts.poppins(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: 'found',
                    child: Text('Found',
                        style: GoogleFonts.poppins(color: Colors.black)),
                  ),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('Other',
                        style: GoogleFonts.poppins(color: Colors.black)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Update', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: AppColors.primary),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Enter $label' : null,
    );
  }
}
