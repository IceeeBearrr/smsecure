import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'package:smsecure/Pages/SMSUser/CustomisableFilteringSetting/CustomisableFilteringDetails.dart';

class CustomisableFilteringList extends StatelessWidget {
  final String currentUserID;
  final String searchText;

  const CustomisableFilteringList({
    super.key,
    required this.currentUserID,
    required this.searchText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customFilter')
            .where('smsUserID', isEqualTo: currentUserID)
            .orderBy('filterName')
            .snapshots(),
        builder: (context, filtersSnapshot) {
          if (filtersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!filtersSnapshot.hasData || filtersSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No filters available"));
          }

          var filters = filtersSnapshot.data!.docs;

          // Filter filters by search text
          filters = filters.where((doc) {
            final filterName =
                doc['filterName']?.toString().toLowerCase() ?? '';
            final filterCriteria =
                doc['criteria']?.toString().toLowerCase() ?? '';
            return filterName.contains(searchText.toLowerCase()) ||
                filterCriteria.contains(searchText.toLowerCase());
          }).toList();

          return ListView.builder(
            itemCount: filters.length,
            itemBuilder: (context, index) {
              var filter = filters[index];
              var filterName = filter['filterName'] ?? 'Unnamed Filter';
              var filterCriteria = filter['criteria'] ?? 'No criteria';
              var createdAt = filter['createdAt'] != null
                  ? (filter['createdAt'] as Timestamp).toDate()
                  : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CustomisableFilteringDetailPage(filterId: filter.id),
                    ),
                  );
                },
                onLongPress: () {
                  _showFilterOptions(context, filter.id, filterName);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          Colors.white, // Ensure the background is pure white
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                      boxShadow: [], // No shadows
                      border: Border.all(
                          color: Colors.transparent), // Transparent border
                    ),
                    padding: const EdgeInsets.all(12.0), // Internal spacing
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filterName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF113953),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                filterCriteria,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            createdAt != null
                                ? DateFormat.yMMMd().format(createdAt)
                                : 'Unknown Date',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterOptions(
      BuildContext context, String filterId, String filterName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  filterName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CustomisableFilteringDetailPage(filterId: filterId),
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text(
                  'Delete Filter',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFilter(context, filterId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteFilter(BuildContext context, String filterId) async {
    try {
      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          print("Displaying confirmation dialog...");
          return AlertDialog(
            title: const Text('Confirmation'),
            content: const Text('Are you sure you want to delete this filter?'),
            actions: [
              TextButton(
                onPressed: () {
                  print("User canceled deletion.");
                  Navigator.of(dialogContext).pop(false); // Cancel deletion
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  print("User confirmed deletion.");
                  Navigator.of(dialogContext).pop(true); // Confirm deletion
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        print("Deletion canceled.");
        return; // User canceled deletion
      }

      print("Deleting filter...");
      await FirebaseFirestore.instance
          .collection('customFilter')
          .doc(filterId)
          .delete();
      print("Filter deleted successfully in Firestore.");

      // Show success dialog
      if (context.mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          print("Displaying success dialog...");
          showDialog<void>(
            context: context,
            builder: (BuildContext successContext) {
              return AlertDialog(
                title: const Text("Success"),
                content: const Text("Filter deleted successfully."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(successContext).pop(); // Close dialog
                    },
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );
        });
      }
    } catch (e) {
      // Handle errors
      print("Error during deletion: $e");
      if (context.mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          showDialog<void>(
            context: context,
            builder: (BuildContext errorContext) {
              return AlertDialog(
                title: const Text("Error"),
                content: Text("Error deleting filter: $e"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(errorContext).pop(); // Close dialog
                    },
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );
        });
      }
    }
  }

  void _showMessageDialog(BuildContext context, String title, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}
