import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          item['title'] ?? 'Item Details',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            if (item['image_url'] != null)
              Image.network(
                item['image_url'],
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),

            // Item details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status and date
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDetailDate(item['created_at']),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(item['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['status'] ?? 'Open',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _buildSectionHeader(context, 'Information'),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    item['description'] ?? 'No description available.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  if (item['category'] != null) ...[
                    _buildInfoRow(context, Icons.category, 'Category',
                        item['category'].toString()),
                    const SizedBox(height: 8),
                  ],

                  // Location
                  _buildInfoRow(context, Icons.location_on, 'Location',
                      item['location'] ?? 'Unknown location'),

                  const SizedBox(height: 8),

                  // Date found/lost
                  _buildInfoRow(context, Icons.event, 'Date',
                      _formatFullDate(item['created_at'] ?? '')),

                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Contact Information'),
                  const SizedBox(height: 8),

                  if (item['phone_no'] != null &&
                      item['phone_no'].toString().isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.phone,
                      'Phone',
                      item['phone_no'].toString(),
                    ),

                  if (item['email'] != null &&
                      item['email'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _buildInfoRow(
                        context,
                        Icons.email,
                        'Email',
                        item['email'].toString(),
                      ),
                    ),

                  const SizedBox(height: 32),

                  if (item['notes'] != null &&
                      item['notes'].toString().isNotEmpty) ...[
                    _buildSectionHeader(context, 'Additional Notes'),
                    const SizedBox(height: 8),
                    Text(
                      item['notes'].toString(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final shareText = '''
Check out this item:

Title: ${item['title'] ?? 'N/A'}
Status: ${item['status'] ?? 'N/A'}
Location: ${item['location'] ?? 'N/A'}
Date: ${_formatFullDate(item['created_at'] ?? '')}
Description: ${item['description'] ?? 'No description'}
Phone: ${item['phone_no'] ?? 'Not provided'}
Email: ${item['email'] ?? 'Not provided'}
                    ''';
                    Share.share(shareText);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final phone = item['phone_no'];
                    final email = item['email'];

                    if (phone != null && phone.toString().isNotEmpty) {
                      _launchPhoneCall(phone.toString());
                    } else if (email != null && email.toString().isNotEmpty) {
                      _launchEmail(
                          email.toString(), item['title'] ?? 'Item Inquiry');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No contact info.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.contact_mail),
                  label: const Text('Contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  Future<void> _launchEmail(String email, String subject) async {
    final Uri uri =
        Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  String _formatDetailDate(dynamic dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) return 'Today';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays} days ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _formatFullDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'found':
        return Colors.green;
      case 'lost':
        return Colors.orange;
      case 'claimed':
        return Colors.purple;
      case 'resolved':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
}
