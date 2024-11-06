import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({Key? key}) : super(key: key);

  @override
  _AddContactPageState createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _noteController;
  String? _profileImageBase64;
  File? _selectedImage;
  String? _whitelistChoice = "No"; // Default to "No"

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _noteController = TextEditingController();
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
      if (fileSize > 1048576) { // 1 MB limit check
        _showFileSizeError(); // Show error message
        setState(() {
          _selectedImage = null; // Reset selected image
          _profileImageBase64 = null; // Clear the base64 image string
        });
        return; // Exit the function without saving the large image
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


  Future<String?> getSmsUserID() async {
    try {
      const FlutterSecureStorage secureStorage = FlutterSecureStorage();
      String? userPhone = await secureStorage.read(key: 'userPhone');
      
      if (userPhone == null) {
        print("Error: userPhone is not set in secure storage.");
        return null;
      }

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final QuerySnapshot querySnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      } else {
        print("Error: No smsUserID found for the given phone number.");
        return null;
      }
    } catch (e) {
      print("Error retrieving smsUserID: $e");
      return null;
    }
  }

  Future<void> _saveContactDetails() async {
    if (_formKey.currentState!.validate()) {
      final String? smsUserID = await getSmsUserID();

      if (smsUserID == null) {
        print("Error: Could not retrieve smsUserID.");
        return;
      }
      
      if (_profileImageBase64 != null && _profileImageBase64!.length > 1048487) {
        _showFileSizeError();
        return; // Exit if profile image is too large
      }

      final firestore = FirebaseFirestore.instance;
      String? registeredSMSUserID;

      final String contactPhoneNumber = _phoneController.text;
      final QuerySnapshot querySnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: contactPhoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        registeredSMSUserID = querySnapshot.docs.first.id;
      } else {
        registeredSMSUserID = "";
      }

      await firestore.collection('contact').add({
        'isBlacklisted': false,
        'isSpam': false,
        'name': _nameController.text,
        'phoneNo': contactPhoneNumber,
        'note': _noteController.text.isEmpty ? 'No note' : _noteController.text,
        'smsUserID': smsUserID,
        'registeredSMSUserID': registeredSMSUserID,
        if (_profileImageBase64 != null) 'profileImageUrl': _profileImageBase64,
      });

      // Add to whitelist if selected
      if (_whitelistChoice == "Yes") {
        String documentID = firestore.collection('whitelist').doc().id;
        await firestore.collection('whitelist').doc(documentID).set({
          'smsUserID': smsUserID,
          'phoneNo': contactPhoneNumber,
        });
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Contact added successfully.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  Navigator.of(context).pop(true); // Close AddContactPage and return true
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // Function to build the whitelist field with Yes/No options
  Widget _buildWhitelistField(BuildContext context) {
    return GestureDetector(
      onTap: () => _showWhitelistModal(context),
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: _whitelistChoice),
          decoration: InputDecoration(
            labelText: 'Add to Whitelist',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF113953)),
          ),
        ),
      ),
    );
  }

  Future<void> _showWhitelistModal(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Yes'),
              onTap: () {
                setState(() {
                  _whitelistChoice = "Yes";
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('No'),
              onTap: () {
                setState(() {
                  _whitelistChoice = "No";
                });
                Navigator.pop(context);
              },
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
          'Add Contact',
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
                _buildWhitelistField(context), // Add whitelist field
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
