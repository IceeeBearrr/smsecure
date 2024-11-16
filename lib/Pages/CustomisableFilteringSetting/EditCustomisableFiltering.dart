import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditCustomisableFilteringPage extends StatefulWidget {
  final String filterId;

  const EditCustomisableFilteringPage({super.key, required this.filterId});

  @override
  _EditCustomisableFilteringPageState createState() =>
      _EditCustomisableFilteringPageState();
}

class _EditCustomisableFilteringPageState
    extends State<EditCustomisableFilteringPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _filterNameController;
  late TextEditingController _criteriaController;
  String? _profileImageBase64;

  @override
  void initState() {
    super.initState();
    _filterNameController = TextEditingController();
    _criteriaController = TextEditingController();
    _fetchFilterDetails();
  }

  Future<void> _fetchFilterDetails() async {
    final firestore = FirebaseFirestore.instance;
    final filterSnapshot =
        await firestore.collection('customFilter').doc(widget.filterId).get();

    if (filterSnapshot.exists) {
      final filterData = filterSnapshot.data()!;
      setState(() {
        _filterNameController.text = filterData['filterName'] ?? '';
        _criteriaController.text = filterData['criteria'] ?? '';
        _profileImageBase64 = filterData['profileImageUrl'];
      });
    }
  }

  Future<void> _saveFilterDetails() async {
    if (_formKey.currentState!.validate()) {
      final firestore = FirebaseFirestore.instance;

      final updatedFilterName = _filterNameController.text.trim();
      final updatedCriteria = _criteriaController.text.trim();

      // Check for duplicates in other filters
      final duplicateCheckQuery = await firestore
          .collection('customFilter')
          .where('filterName', isEqualTo: updatedFilterName)
          .where('criteria', isEqualTo: updatedCriteria)
          .get();

      final isDuplicate = duplicateCheckQuery.docs
          .any((doc) => doc.id != widget.filterId); // Exclude current filter

      if (isDuplicate) {
        _showMessageDialog(
          context,
          "Error",
          "A filter with the same name and criteria already exists.",
        );
        return;
      }

      // Update filter details in Firestore
      await firestore.collection('customFilter').doc(widget.filterId).update({
        'filterName': updatedFilterName,
        'criteria': updatedCriteria,
      });

      // Show success dialog
      _showMessageDialog(
        context,
        "Success",
        "Filter updated successfully.",
        onClose: () {
          Navigator.pop(context, true); // Pass true to indicate success
        },
      );
    }
  }

  void _showMessageDialog(BuildContext context, String title, String message,
      {VoidCallback? onClose}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
                if (onClose != null) onClose(); // Execute callback
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showCriteriaModal(BuildContext context) {
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
            children: [
              const ListTile(
                title: Text(
                  'Select Criteria',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Allow'),
                onTap: () {
                  setState(() {
                    _criteriaController.text = 'Allow';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Block'),
                onTap: () {
                  setState(() {
                    _criteriaController.text = 'Block';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileImage =
        _profileImageBase64 != null && _profileImageBase64!.isNotEmpty
            ? MemoryImage(base64Decode(_profileImageBase64!))
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Custom Filter',
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profileImage as ImageProvider<Object>?,
                  child: profileImage == null
                      ? const Icon(Icons.filter_alt,
                          size: 50, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _filterNameController,
                  decoration: const InputDecoration(
                    labelText: 'Filter Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the filter name';
                    } else if (value.split(' ').length > 1) {
                      return 'Filter name must be one word';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showCriteriaModal(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _criteriaController,
                      decoration: const InputDecoration(
                        labelText: 'Criteria',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a criteria';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveFilterDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
