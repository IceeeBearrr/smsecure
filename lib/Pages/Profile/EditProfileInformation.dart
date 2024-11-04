import 'dart:convert'; // for base64 encoding and decoding
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class EditProfileInformation extends StatefulWidget {
  const EditProfileInformation({super.key});

  @override
  State<EditProfileInformation> createState() => _EditProfileInformationState();
}

class _EditProfileInformationState extends State<EditProfileInformation> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  DateTime? _selectedBirthday;
  File? _selectedImage;
  String? _profileImageBase64;

  final ImagePicker _picker = ImagePicker();

  String? userPhone;
  String? currentSmsUserID;
  bool isLoading = true; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true; // Start loading
    });
    userPhone = await secureStorage.read(key: 'userPhone');
    if (userPhone != null) {
      await _fetchUserProfile();
    }
    setState(() {
      isLoading = false; // Stop loading after data is fetched
    });
  }

  Future<void> _fetchUserProfile() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      final QuerySnapshot findSmsUserIDSnapshot = await firestore
          .collection('smsUser')
          .where('phoneNo', isEqualTo: userPhone)
          .limit(1)
          .get();

      if (findSmsUserIDSnapshot.docs.isNotEmpty) {
        currentSmsUserID = findSmsUserIDSnapshot.docs.first.id;

        final DocumentSnapshot userSnapshot = await firestore
            .collection('smsUser')
            .doc(currentSmsUserID)
            .get();

        if (userSnapshot.exists) {
          final data = userSnapshot.data() as Map<String, dynamic>?;
          setState(() {
            _nameController.text = data?['name'] ?? '';
            _emailController.text = data?['emailAddress'] ?? '';
            _phoneController.text = data?['phoneNo'] ?? '';
            _genderController.text = data?['gender'] ?? '';
            _profileImageBase64 = data?['profileImageUrl'];
            if (data?['birthday'] != null) {
              _selectedBirthday = DateTime.parse(data!['birthday']);
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
  }

  Future<void> _pickDate() async {
    DateTime initialDate = _selectedBirthday ?? DateTime(2000);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
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
                    await _cropImage(File(pickedFile.path));
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
                    await _cropImage(File(pickedFile.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Enforce 1:1 aspect ratio
      aspectRatioPresets: [
        CropAspectRatioPreset.square, // Only allow square aspect ratio
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color.fromARGB(255, 47, 77, 129),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, // Lock the aspect ratio to 1:1
        ),
        IOSUiSettings(
          minimumAspectRatio: 1.0, // Lock aspect ratio to 1:1 on iOS
        ),
      ],
    );

    if (croppedFile != null) {
      // Copy the cropped file to the application's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final newImage = await File(croppedFile.path).copy('$path/profile_image.png');

      setState(() {
        _selectedImage = newImage;
      });
    }
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print("Error converting image to Base64: $e");
      return null;
    }
  }

  Future<void> _submit() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    if (currentSmsUserID != null) {
      String? profileImageUrl;

      // If a new profile image is selected, convert it to Base64
      if (_selectedImage != null) {
        profileImageUrl = await _convertImageToBase64(_selectedImage!);
      }

      // Update Firestore with the profile data and Base64 image string if available
      await firestore.collection('smsUser').doc(currentSmsUserID).update({
        'name': _nameController.text,
        'emailAddress': _emailController.text,
        'phoneNo': _phoneController.text,
        'gender': _genderController.text,
        'birthday': _selectedBirthday != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!)
            : null,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  Future<bool> _onBackButtonPressed() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });
    await Future.delayed(const Duration(seconds: 1)); // Brief delay
    setState(() {
      isLoading = false; // Hide loading indicator after delay
    });
    return true; // Allow pop after loading
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113953)),
          onPressed: () async {
            setState(() {
              isLoading = true; // Show loading indicator
            });
            await Future.delayed(const Duration(seconds: 1)); // Brief delay
            setState(() {
              isLoading = false; // Hide loading indicator after delay
            });
            Navigator.pop(context); // Perform the pop after delay
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator if isLoading is true
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showImageSourceModal(context),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : _profileImageBase64 != null
                                ? MemoryImage(base64Decode(_profileImageBase64!))
                                : null,
                        child: (_selectedImage == null && _profileImageBase64 == null)
                            ? const Icon(Icons.person, size: 60, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      _nameController, 
                      'Name',
                      prefixIcon: const Icon(Icons.badge, color: Color(0xFF113953)),
                      textStyle: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)),
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      _emailController, 
                      'Email',
                      prefixIcon: const Icon(Icons.email, color: Color(0xFF113953)),
                      textStyle: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)),
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      _phoneController,
                      'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.call, color: Color(0xFF113953)),
                      textStyle: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)),
                    ),
                    const SizedBox(height: 10),
                    
                    _buildGenderField(context),
                    const SizedBox(height: 10),

                    _buildDateField('Birthday'),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
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
    );
  }


  Widget _buildTextField(
      TextEditingController controller, String label, {
      Widget? prefixIcon,
      TextInputType? keyboardType,
      TextStyle? textStyle,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: textStyle,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showGenderModal(BuildContext context) {
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
                  'Gender',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Prefer not to say'),
                onTap: () {
                  setState(() {
                    _genderController.text = 'Prefer not to say';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Male'),
                onTap: () {
                  setState(() {
                    _genderController.text = 'Male';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Female'),
                onTap: () {
                  setState(() {
                    _genderController.text = 'Female';
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

  Widget _buildGenderField(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGenderModal(context),
      child: AbsorbPointer(
        child: TextFormField(
          controller: _genderController,
          style: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)), 
          decoration: InputDecoration(
            labelText: 'Gender',
            prefixIcon: const Icon(Icons.person, color: Color(0xFF113953)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF113953)),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label) {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(
            text: _selectedBirthday != null
                ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!)
                : '',
          ),
          style: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)), 
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.cake, color: Color(0xFF113953)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF113953)),
          ),
        ),
      ),
    );
  }
}

