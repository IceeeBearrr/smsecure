import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddCustomisableFilteringPage extends StatefulWidget {
  const AddCustomisableFilteringPage({super.key});

  @override
  _AddCustomisableFilteringPageState createState() =>
      _AddCustomisableFilteringPageState();
}

class _AddCustomisableFilteringPageState
    extends State<AddCustomisableFilteringPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _filterNameController;
  late TextEditingController _criteriaController;

  @override
  void initState() {
    super.initState();
    _filterNameController = TextEditingController();
    _criteriaController = TextEditingController();
  }

  Future<String?> getSmsUserID() async {
    try {
      const FlutterSecureStorage secureStorage = FlutterSecureStorage();
      String? userPhone = await secureStorage.read(key: 'userPhone');

      if (userPhone == null) {
        return null;
      }

      final firestore = FirebaseFirestore.instance;
      final QuerySnapshot querySnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      } else {
        return null;
      }
    } catch (e) {
      print("Error retrieving smsUserID: $e");
      return null;
    }
  }

  Future<void> _saveFilterDetails() async {
    if (_formKey.currentState!.validate()) {
      final String? smsUserID = await getSmsUserID();

      if (smsUserID == null) {
        print("Error: Could not retrieve smsUserID.");
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final String filterName = _filterNameController.text.trim();
      final String criteria = _criteriaController.text.trim();

      // Check if the filter with the same name and criteria already exists
      final existingFilterQuery = await firestore
          .collection('customFilter')
          .where('smsUserID', isEqualTo: smsUserID)
          .where('filterName', isEqualTo: filterName)
          .where('criteria', isEqualTo: criteria)
          .get();

      if (existingFilterQuery.docs.isNotEmpty) {
        _showMessageDialog(
          context,
          "Error",
          "A filter with the same name and criteria already exists.",
        );
        return;
      }

      // Add the new filter to Firestore
      await firestore.collection('customFilter').add({
        'smsUserID': smsUserID,
        'filterName': filterName,
        'criteria': criteria,
        'createdAt': Timestamp.now(),
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Filter added successfully.'),
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
    }
  }

  void _showMessageDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Custom Filter',
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
                const SizedBox(height: 50),
                TextFormField(
                  controller: _filterNameController,
                  decoration: const InputDecoration(
                    labelText: 'Filter Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a filter name';
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
                      'Submit',
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
