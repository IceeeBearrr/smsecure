import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:smsecure/Pages/SMSUser/Contact/ContactDetail.dart';

class EditContactPage extends StatefulWidget {
  final String contactId;

  const EditContactPage({super.key, required this.contactId});

  @override
  _EditContactPageState createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _noteController;
  String? _profileImageBase64;
  File? _selectedImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _noteController = TextEditingController();
    _fetchContactDetails();
  }

  Future<void> _fetchContactDetails() async {
    final firestore = FirebaseFirestore.instance;
    final contactSnapshot = await firestore.collection('contact').doc(widget.contactId).get();

    if (contactSnapshot.exists) {
      final contactData = contactSnapshot.data()!;
      _nameController.text = contactData['name'] ?? '';
      _phoneController.text = contactData['phoneNo'] ?? '';
      _noteController.text = contactData['note'] == 'No note' ? '' : contactData['note'];

      if (contactData.containsKey('profileImageUrl') && contactData['profileImageUrl'].isNotEmpty) {
        setState(() {
          _profileImageBase64 = contactData['profileImageUrl'];
        });
      } else if (contactData.containsKey('registeredSMSUserID') && contactData['registeredSMSUserID'].isNotEmpty) {
        final smsUserId = contactData['registeredSMSUserID'];
        final smsUserSnapshot = await firestore.collection('smsUser').doc(smsUserId).get();
        if (smsUserSnapshot.exists) {
          final smsUserData = smsUserSnapshot.data();
          if (smsUserData != null && smsUserData['profileImageUrl'] != null) {
            setState(() {
              _profileImageBase64 = smsUserData['profileImageUrl'];
            });
          }
        }
      }
    }
  }

  Future<void> _showImageSourceModal(BuildContext context) {
    return showModalBottomSheet(
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
                  'Choose Image Source',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    await _checkAndCropImage(File(pickedFile.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_album),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    await _checkAndCropImage(File(pickedFile.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkAndCropImage(File imageFile) async {
    final int fileSize = await imageFile.length();
    if (fileSize > 1048576) { // 1 MB limit check
      _showFileSizeError(); // Show error message
      return; // Exit the function without proceeding to crop
    }

    // Crop the image if it meets the size limit
    await _cropImage(imageFile);
  }
  
  Future<void> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          minimumAspectRatio: 1.0,
        ),
      ],
    );

    if (croppedFile != null) {
      final int fileSize = await File(croppedFile.path).length();
      if (fileSize > 1048576) { // Check if file size is greater than 1 MB (1 MB = 1048576 bytes)
        _showFileSizeError();
        return; // Exit the function if file size is too large
      }

      setState(() {
        _selectedImage = File(croppedFile.path);
      });
      _profileImageBase64 = await _convertImageToBase64(File(croppedFile.path));
    }
  }

  void _showFileSizeError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("File Size Exceeded"),
          content: const Text("The selected image is larger than 1 MB. Please choose a smaller image."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Check if file size exceeds 1 MB
      if (bytes.length > 1048487) {
        _showFileSizeError();
        return null; // Return null if file is too large
      }

      return base64Encode(bytes);
    } catch (e) {
      print("Error converting image to Base64: $e");
      return null;
    }
  }


  Future<void> _saveContactDetails() async {
    if (_formKey.currentState!.validate()) {
      final firestore = FirebaseFirestore.instance;
      final contactName = _nameController.text.trim();
      final contactPhoneNumber = _phoneController.text.trim();

      // Get the current contact details
      final currentContactSnapshot = await firestore.collection('contact').doc(widget.contactId).get();
      if (!currentContactSnapshot.exists) {
        _showMessageDialog(context, "Error", "Contact does not exist.");
        return;
      }

      final currentContactData = currentContactSnapshot.data()!;
      final currentName = currentContactData['name'] ?? '';
      final currentPhone = currentContactData['phoneNo'] ?? '';

      // Skip duplicate checks if the name and phone number are the same as the current values
      if (contactName == currentName && contactPhoneNumber == currentPhone) {
        await _updateContactDetails();
        return;
      }

      // Check if the name or phone number already exists in other contacts
      final existingPhoneQuery = await firestore
          .collection('contact')
          .where('phoneNo', isEqualTo: contactPhoneNumber)
          .get();

      final existingNameQuery = await firestore
          .collection('contact')
          .where('name', isEqualTo: contactName)
          .get();

      final isDuplicatePhone = existingPhoneQuery.docs.any((doc) => doc.id != widget.contactId);
      final isDuplicateName = existingNameQuery.docs.any((doc) => doc.id != widget.contactId);

      if (isDuplicatePhone || isDuplicateName) {
        // Show error message if duplicates are found
        _showMessageDialog(
          context,
          "Error",
          "A contact with this phone number or name already exists.",
        );
        return;
      }

      // If no duplicates, proceed to update the contact details
      await _updateContactDetails();
    }
  }

  Future<void> _updateContactDetails() async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('contact').doc(widget.contactId).update({
      'name': _nameController.text.trim(),
      'phoneNo': _phoneController.text.trim(),
      'note': _noteController.text.isEmpty ? 'No note' : _noteController.text.trim(),
      if (_profileImageBase64 != null) 'profileImageUrl': _profileImageBase64,
    });

    // Show success dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Contact updated successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => ContactDetailsPage(contactId: widget.contactId),
                  ),
                  (Route<dynamic> route) => route.isFirst,
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final profileImage = _selectedImage != null
        ? FileImage(_selectedImage!)
        : _profileImageBase64 != null
            ? MemoryImage(base64Decode(_profileImageBase64!))
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Contact',
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
                GestureDetector(
                  onTap: () => _showImageSourceModal(context),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileImage as ImageProvider<Object>?,
                    child: profileImage == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                      return 'Only letters and spaces are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!RegExp(r'^\+60\d{9,10}$').hasMatch(value)) {
                      return 'Please enter in the format +60123456789';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveContactDetails,
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
