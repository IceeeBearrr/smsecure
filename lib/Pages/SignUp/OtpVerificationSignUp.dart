import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:smsecure/Pages/Login/CustLogin.dart';

class OtpVerificationSignUp extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String password;

  const OtpVerificationSignUp({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  _OtpVerificationSignUpState createState() => _OtpVerificationSignUpState();
}

class _OtpVerificationSignUpState extends State<OtpVerificationSignUp> {
  final List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> otpFocusNodes = List.generate(6, (index) => FocusNode());
  int _remainingTime = 60;
  late Timer _timer;
  bool _canResend = false;
  String generatedOtp = '';
  late TwilioFlutter twilioFlutter;

  @override
  void initState() {
    super.initState();
    twilioFlutter = TwilioFlutter(
      accountSid: 'ACeb000c82d06c291817006b2e6c2b7aa6',
      authToken: 'fd828490e438dbc1113c99b1019668f7',
      twilioNumber: '+18145805618',
    );
    _startCountdown();
    _sendOtp();
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        setState(() {
          _canResend = true;
          _timer.cancel();
        });
      }
    });
  }

  void _sendOtp() {
    setState(() {
      generatedOtp = _generateOtp();
    });
    try {
      twilioFlutter.sendSMS(
        toNumber: widget.phone,
        messageBody: 'Your OTP code is: $generatedOtp',
      ).then((_) {
        print('OTP sent to ${widget.phone}: $generatedOtp');
      }).catchError((error, stackTrace) {
        print('Failed to send OTP. Error: $error');
        print('StackTrace: $stackTrace');
        _showErrorDialog('Failed to send OTP. Please try again.');
      });
    } catch (e) {
      print('Error occurred while sending OTP: $e');
      _showErrorDialog('An unexpected error occurred while sending OTP. Please try again later.');
    }
  }

  String _generateOtp() {
    var rng = Random();
    return List.generate(6, (_) => rng.nextInt(10).toString()).join();
  }

  void _resendCode() {
    setState(() {
      _remainingTime = 60;
      _startCountdown();
      _sendOtp();
    });
  }

  Future<void> _verifyOtpAndRegisterUser() async {
    String enteredOtp = otpControllers.map((controller) => controller.text).join();
    if (enteredOtp == generatedOtp) {
      // Step 1: Register the user in Firestore
      String smsUserID = await _registerUserInFirestore();

      // Step 2: Update the contact collection if the phone number matches
      if (smsUserID.isNotEmpty) {
        await _updateRegisteredSMSUserID(smsUserID);
      }
      _showSuccessDialog(); // Show success message and redirect to login
    } else {
      _showErrorDialog('Invalid OTP. Please try again.');
    }
  }

  Future<String> _registerUserInFirestore() async {
    CollectionReference smsUsers = FirebaseFirestore.instance.collection('smsUser');
    // Generate a unique smsUserID by combining the current timestamp and a random integer
    String smsUserID = DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(10000).toString();

    try {
      await smsUsers.doc(smsUserID).set({
        'smsUserID': smsUserID,
        'name': widget.name,
        'phoneNo': widget.phone,
        'emailAddress': widget.email,
        'password': widget.password,
      });
      print("User registered successfully.");
      return smsUserID;
    } catch (e) {
      print("Error adding user: $e");
      _showErrorDialog("An error occurred while registering the user. Please try again.");
      return '';
    }
  }

  Future<void> _updateRegisteredSMSUserID(String smsUserID) async {
    try {
      final contactQuery = await FirebaseFirestore.instance
          .collection('contact')
          .where('phoneNo', isEqualTo: widget.phone)
          .get();

      if (contactQuery.docs.isNotEmpty) {
        for (var doc in contactQuery.docs) {
          await doc.reference.update({'registeredSMSUserID': smsUserID});
          print("Updated registeredSMSUserID for contact: ${doc.id}");
        }
      } else {
        print("No matching contact found for phone number: ${widget.phone}");
      }
    } catch (e) {
      print("Error updating registeredSMSUserID in contact collection: $e");
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside the dialog
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Your account has been created successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Custlogin()),
              ); // Redirect to login page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 10.0),
                child: Text(
                  "Almost there",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 30.0),
                child: Text(
                  "Please enter the 6-digit code sent to your phone number.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 50,
                      height: 55,
                      child: TextField(
                        controller: otpControllers[index],
                        focusNode: otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        onTap: () {
                          SystemChannels.textInput.invokeMethod('TextInput.show');
                        },
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            FocusScope.of(context).requestFocus(otpFocusNodes[index + 1]);
                          } else if (value.isEmpty && index > 0) {
                            FocusScope.of(context).requestFocus(otpFocusNodes[index - 1]);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ElevatedButton(
                  onPressed: _verifyOtpAndRegisterUser,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Verify",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive any code? ",
                    style: TextStyle(color: Colors.black54),
                  ),
                  GestureDetector(
                    onTap: _canResend ? _resendCode : null,
                    child: Text(
                      "Resend Again",
                      style: TextStyle(
                        color: _canResend
                            ? const Color.fromARGB(255, 47, 77, 129)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Text(
                  _canResend
                      ? "Request a new code now."
                      : "Request new code in 00:${_remainingTime.toString().padLeft(2, '0')}s",
                  style: const TextStyle(color: Colors.black38),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
