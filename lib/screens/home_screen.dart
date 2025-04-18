import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lostify/screens/add_item_screen.dart';
import 'package:lostify/screens/edit_item_screen.dart';
import 'package:lostify/screens/item_details_screen.dart';
import 'package:lostify/screens/login_screen.dart';
import 'package:lostify/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isLoading = true;
  String searchQuery = '';
  RealtimeChannel? _subscription;

  // Toggle state for viewing own posts vs all posts
  bool viewingOwnPosts = false;

  @override
  void initState() {
    super.initState();
    fetchItems();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _subscription = supabase
        .channel('public:items')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            final newItem = payload.newRecord;
            if (newItem != null) {
              setState(() {
                items.insert(0, newItem);
                _applyFilters();
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            final updatedItem = payload.newRecord;
            if (updatedItem != null) {
              setState(() {
                final index =
                    items.indexWhere((i) => i['id'] == updatedItem['id']);
                if (index != -1) items[index] = updatedItem;

                _applyFilters();
              });
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            final deletedId = payload.oldRecord?['id'];
            if (deletedId != null) {
              setState(() {
                items.removeWhere((i) => i['id'] == deletedId);
                filteredItems.removeWhere((i) => i['id'] == deletedId);
              });
            }
          },
        )
        .subscribe();
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final title = item['title']?.toString().toLowerCase() ?? '';
    final description = item['description']?.toString().toLowerCase() ?? '';
    return title.contains(searchQuery) || description.contains(searchQuery);
  }

  bool _matchesViewFilter(Map<String, dynamic> item) {
    if (!viewingOwnPosts) {
      // Show all posts when not in "My Posts" mode
      return true;
    }

    // In "My Posts" mode, only show user's own posts
    final userId = supabase.auth.currentUser?.id;
    return item['user_id'] == userId;
  }

  void _applyFilters() {
    setState(() {
      filteredItems = items
          .where((item) => _matchesSearch(item) && _matchesViewFilter(item))
          .toList();
    });
  }

  Future<void> fetchItems() async {
    try {
      final response = await supabase
          .from('items')
          .select()
          .order('created_at', ascending: false);
      final itemList = List<Map<String, dynamic>>.from(response);
      if (mounted) {
        setState(() {
          items = itemList;
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching items: $error');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _logout() async {
    await supabase.auth.signOut();
    if (mounted)
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  void _onSearch(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      _applyFilters();
    });
  }

  void _toggleViewMode() {
    setState(() {
      viewingOwnPosts = !viewingOwnPosts;
      _applyFilters();
    });
  }

  void _confirmDelete(String itemId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Delete this item?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(itemId);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      print('Attempting to delete item: $itemId for user: $userId');

      // First, check if the item exists
      try {
        final checkItem = await supabase
            .from('items')
            .select()
            .eq('id', itemId)
            .eq('user_id', userId)
            .maybeSingle();

        print('Item to delete: $checkItem');

        if (checkItem == null) {
          print('Item not found or not owned by current user');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item not found or not owned by you')),
          );
          return;
        }
      } catch (e) {
        print('Error checking item: $e');
      }

      // Execute the delete operation
      await supabase
          .from('items')
          .delete()
          .eq('id', itemId)
          .eq('user_id', userId);

      print('Delete operation completed');

      // Manually check if the item was deleted
      try {
        final checkAfterDelete = await supabase
            .from('items')
            .select()
            .eq('id', itemId)
            .maybeSingle();

        print('After delete check: $checkAfterDelete');

        if (checkAfterDelete == null) {
          print('Item successfully deleted from database');
          // Manually update the UI since realtime might not be working
          setState(() {
            items.removeWhere((i) => i['id'] == itemId);
            filteredItems.removeWhere((i) => i['id'] == itemId);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        } else {
          print('Item still exists in database after delete attempt');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
          );
        }
      } catch (e) {
        print('Error checking deletion: $e');
      }
    } catch (e) {
      print('Error during deletion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    }
  }

  // Determine item status (Lost or Found)
  String _getItemStatus(Map<String, dynamic> item) {
    final status = item['category']?.toString().toLowerCase() ?? '';
    if (status == 'lost' || status == 'found') {
      return status[0].toUpperCase() +
          status.substring(1); // Capitalize first letter
    } else {
      // Default to 'Lost' if status is not specified or invalid
      return 'Lost';
    }
  }

  // Get status color based on lost/found
  Color _getStatusColor(String status) {
    return status.toLowerCase() == 'found' ? Colors.green : Colors.orangeAccent;
  }

  // Get card gradient based on status
  List<Color> _getCardGradient(String status) {
    if (status.toLowerCase() == 'found') {
      return [
        Colors.green.withOpacity(0.1),
        Colors.grey[850]!,
      ];
    } else {
      return [
        Colors.orangeAccent.withOpacity(0.1),
        Colors.grey[850]!,
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LOST & FOUND',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 0, // Remove appbar shadow for modern look
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
            color: Colors.white,
          ),
          // Profile navigation button
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen()),
              );
            },
            tooltip: 'Profile',
            color: Colors.white,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: GoogleFonts.poppins(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                isDense: true,
              ),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),

          // Toggle buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !viewingOwnPosts ? null : _toggleViewMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            !viewingOwnPosts ? primaryColor : Colors.grey[800],
                        disabledBackgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(12),
                          ),
                        ),
                        elevation: !viewingOwnPosts ? 0 : 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'All Posts',
                        style: GoogleFonts.poppins(
                          fontWeight: !viewingOwnPosts
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: viewingOwnPosts ? null : _toggleViewMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            viewingOwnPosts ? primaryColor : Colors.grey[800],
                        disabledBackgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                        ),
                        elevation: viewingOwnPosts ? 0 : 0,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'My Posts',
                        style: GoogleFonts.poppins(
                          fontWeight: viewingOwnPosts
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items list
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          viewingOwnPosts
                              ? 'You haven\'t posted any items yet'
                              : 'No items found',
                          style: GoogleFonts.poppins(color: Colors.black),
                        ),
                      )
                    : RefreshIndicator(
                        color: primaryColor,
                        onRefresh: fetchItems,
                        child: ListView.builder(
                          itemCount: filteredItems.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isMyPost = item['user_id'] ==
                                supabase.auth.currentUser?.id;
                            final status = _getItemStatus(item);
                            final statusColor = _getStatusColor(status);
                            final cardGradient = _getCardGradient(status);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: cardGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    // Main outer shadow
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                    // Subtle inner glow based on status
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.15),
                                      blurRadius: 12,
                                      spreadRadius: -2,
                                      offset: Offset(0, 2),
                                    ),
                                    // Sharp edge highlight for top
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.05),
                                      blurRadius: 0.5,
                                      spreadRadius: 0,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ItemDetailScreen(item: item),
                                        ),
                                      ),
                                      splashColor: statusColor.withOpacity(0.1),
                                      highlightColor:
                                          statusColor.withOpacity(0.05),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (item['image_url'] != null)
                                            Stack(
                                              children: [
                                                Hero(
                                                  tag:
                                                      'item-image-${item['id']}',
                                                  child: Container(
                                                    height: 200,
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          blurRadius: 8,
                                                          offset: Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Image.network(
                                                      item['image_url'],
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Container(
                                                          color:
                                                              Colors.grey[700],
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              size: 50,
                                                              color: Colors
                                                                  .white60,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return Container(
                                                          color:
                                                              Colors.grey[800],
                                                          child: Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              value: loadingProgress
                                                                          .expectedTotalBytes !=
                                                                      null
                                                                  ? loadingProgress
                                                                          .cumulativeBytesLoaded /
                                                                      (loadingProgress
                                                                              .expectedTotalBytes ??
                                                                          1)
                                                                  : null,
                                                              color:
                                                                  primaryColor,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                // Status badge
                                                Positioned(
                                                  top: 16,
                                                  right: 16,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Left side banner indicating status
                                                Positioned(
                                                  top: 12,
                                                  left: 0,
                                                  bottom: 12,
                                                  child: Container(
                                                    width: 4,
                                                    decoration: BoxDecoration(
                                                      color: statusColor,
                                                      borderRadius: BorderRadius
                                                          .horizontal(
                                                        right:
                                                            Radius.circular(2),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      height: 16,
                                                      width: 16,
                                                      decoration: BoxDecoration(
                                                        color: statusColor,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: statusColor
                                                                .withOpacity(
                                                                    0.4),
                                                            blurRadius: 6,
                                                            offset:
                                                                Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        item['title'],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  item['description'] ?? '',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Container(
                                                  padding: EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                              Icons.location_on,
                                                              size: 16,
                                                              color:
                                                                  statusColor),
                                                          const SizedBox(
                                                              width: 6),
                                                          Expanded(
                                                            child: Text(
                                                              item['location'] ??
                                                                  'No location specified',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (item['created_at'] !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 8),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .access_time,
                                                                size: 16,
                                                                color:
                                                                    statusColor),
                                                            const SizedBox(
                                                                width: 6),
                                                            Text(
                                                              _formatDate(item[
                                                                  'created_at']),
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isMyPost)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                  bottom: Radius.circular(20),
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  // Edit button with improved design
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                EditItemScreen(
                                                                    item: item),
                                                          ),
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 12,
                                                                vertical: 8),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                            color:
                                                                Colors.white30,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.edit,
                                                                size: 16,
                                                                color: Colors
                                                                    .white),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Edit',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Delete button with improved design
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        _confirmDelete(
                                                            item['id']);
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 12,
                                                                vertical: 8),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          color: Colors.red
                                                              .withOpacity(0.1),
                                                          border: Border.all(
                                                            color: Colors.red
                                                                .withOpacity(
                                                                    0.3),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.delete,
                                                                size: 16,
                                                                color: Colors
                                                                    .redAccent),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Delete',
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .redAccent,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddItemScreen()),
            );
          },
          backgroundColor: primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
          tooltip: 'Add New Item',
          elevation: 0, // Removed default elevation since we use custom shadow
        ),
      ),
    );
  }
}
