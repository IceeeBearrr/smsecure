import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:smsecure/Pages/SMSUser/CustomisableFilteringSetting/EditCustomisableFiltering.dart';
import 'package:intl/intl.dart'; // For formatting dates

class CustomisableFilteringDetailPage extends StatefulWidget {
  final String filterId;

  const CustomisableFilteringDetailPage({super.key, required this.filterId});

  @override
  _CustomisableFilteringDetailPageState createState() =>
      _CustomisableFilteringDetailPageState();
}

class _CustomisableFilteringDetailPageState
    extends State<CustomisableFilteringDetailPage> {
  late Future<Map<String, dynamic>> _filterDetailsFuture;

  @override
  void initState() {
    super.initState();
    _filterDetailsFuture = _fetchFilterDetails();
  }

  Future<Map<String, dynamic>> _fetchFilterDetails() async {
    final firestore = FirebaseFirestore.instance;
    final filterSnapshot =
        await firestore.collection('customFilter').doc(widget.filterId).get();

    if (filterSnapshot.exists) {
      final filterData = filterSnapshot.data()!;
      final createdAt = filterData['createdAt'] != null
          ? DateFormat.yMMMMd()
              .add_jm()
              .format((filterData['createdAt'] as Timestamp).toDate())
          : 'Unknown';
      return {
        'filterName': filterData['filterName'] ?? 'Unnamed Filter',
        'criteria': filterData['criteria'] ?? 'No Criteria',
        'createdAt': createdAt,
      };
    } else {
      return {
        'filterName': 'No Name',
        'criteria': 'No Criteria',
        'createdAt': 'Unknown',
      };
    }
  }

  Future<void> _navigateToEditFilter(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCustomisableFilteringPage(
          filterId: widget.filterId,
        ),
      ),
    );

    if (result == true) {
      // Reload filter details if edit was successful
      setState(() {
        _filterDetailsFuture = _fetchFilterDetails();
      });
    }
  }

  Future<void> _deleteFilter(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;

    final bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Are you sure you want to delete this filter?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await firestore.collection('customFilter').doc(widget.filterId).delete();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Filter deleted successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(true); // Return to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('An error occurred: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Filter Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF113953),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _filterDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error fetching filter details."));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No filter details available."));
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(Icons.filter_alt, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      data['filterName'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF113953),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Created At',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const Spacer(),
                                Text(
                                  data['createdAt'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Criteria',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  data['criteria'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildProfileOption(
                          Icons.edit,
                          'Edit Filter',
                          onTap: () => _navigateToEditFilter(context),
                        ),
                        _buildProfileOption(
                          Icons.delete,
                          'Delete Filter',
                          color: Colors.red,
                          onTap: () => _deleteFilter(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title,
      {Color? color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 20.0),
        child: Row(
          children: [
            Icon(icon, color: color ?? const Color.fromARGB(255, 47, 77, 129)),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: color ?? const Color.fromARGB(188, 0, 0, 0),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
