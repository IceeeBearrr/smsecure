import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpVerificationCustLogin extends StatefulWidget {
  final String phone;
  final String password;

  const OtpVerificationCustLogin({
    Key? key,
    required this.phone,
    required this.password,
  }) : super(key: key);

  @override
  _OtpVerificationCustLoginState createState() => _OtpVerificationCustLoginState();
}

class _OtpVerificationCustLoginState extends State<OtpVerificationCustLogin> {
  final List<TextEditingController> otpControllers =
      List.generate(6, (index) => TextEditingController());
  int _remainingTime = 60;
  late Timer _timer;
  bool _canResend = false;
  String generatedOtp = '';
  late TwilioFlutter twilioFlutter;

  @override
  void initState() {
    super.initState();
    twilioFlutter = TwilioFlutter(
      accountSid: 'ACbde03b214375773dc7bd448871cdbb50',
      authToken: '2fe2aca2c0c733457a6bcb1efbc1e273',
      twilioNumber: '+12053862557',
    );
    _startCountdown();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer.cancel();
    otpControllers.forEach((controller) => controller.dispose());
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
    twilioFlutter.sendSMS(
      toNumber: widget.phone,
      messageBody: 'Your OTP code is: $generatedOtp',
    ).then((_) {
      print('OTP sent to ${widget.phone}: $generatedOtp');
    }).catchError((error, stackTrace) {
      print('Failed to send OTP. Error: $error');
      _showErrorDialog('Failed to send OTP. Please try again.');
    });
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

  Future<void> _verifyOtpAndProceed() async {
    String enteredOtp = otpControllers.map((controller) => controller.text).join();
    if (enteredOtp == generatedOtp) {
      // Update isLoggedIn to true and save the userID
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userID', widget.phone);

      _showSuccessDialog();
    } else {
      _showErrorDialog('Invalid OTP. Please try again.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('OTP verified successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                // Close the dialog and navigate to the home page
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
                  "OTP Verification",
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
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            FocusScope.of(context).nextFocus();
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
                  onPressed: _verifyOtpAndProceed,
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
