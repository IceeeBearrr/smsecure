import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class OtpVerificationCustLogin extends StatefulWidget {
  final String phone;
  final String password;

  const OtpVerificationCustLogin({
    super.key,
    required this.phone,
    required this.password,
  });

  @override
  _OtpVerificationCustLoginState createState() => _OtpVerificationCustLoginState();
}

class _OtpVerificationCustLoginState extends State<OtpVerificationCustLogin> with WidgetsBindingObserver {
  final List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  int _remainingTime = 60;
  Timer? _timer;
  bool _canResend = false;
  String generatedOtp = '';
  late TwilioFlutter twilioFlutter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    twilioFlutter = TwilioFlutter(
      accountSid: 'ACeb000c82d06c291817006b2e6c2b7aa6',
      authToken: 'fd828490e438dbc1113c99b1019668f7',
      twilioNumber: '+18145805618',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOtpProcess();
    });
  }

  void _initializeOtpProcess() {
    _startCountdown();
    _sendOtp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _remainingTime > 0 && _timer == null) {
      _startCountdown();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  void _startCountdown() {
    _canResend = false;
    _timer?.cancel(); // Ensure the previous timer is cancelled before starting a new one
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) { // Check if mounted
        if (_remainingTime > 0) {
          setState(() {
            _remainingTime--;
          });
        } else {
          setState(() {
            _canResend = true;
          });
          _timer?.cancel();
          _timer = null;
        }
      } else {
        timer.cancel(); // Cancel the timer if the widget is not mounted
      }
    });
  }

  void _sendOtp() {
    generatedOtp = _generateOtp();
    twilioFlutter.sendSMS(
      toNumber: widget.phone,
      messageBody: 'Your OTP code is: $generatedOtp',
    ).then((_) {
      if (mounted) {
        print('OTP sent to ${widget.phone}: $generatedOtp');
      }
    }).catchError((error) {
      if (mounted) {
        print('Failed to send OTP. Error: $error');
        _showErrorDialog('Failed to send OTP. Please try again.');
      }
    });
  }

  String _generateOtp() {
    var rng = Random();
    return List.generate(6, (_) => rng.nextInt(10).toString()).join();
  }

  void _resendCode() {
    if (mounted) {
      setState(() {
        _remainingTime = 60;
        _startCountdown();
        _sendOtp();
      });
    }
  }

  Future<void> _verifyOtpAndProceed() async {
    String enteredOtp = otpControllers.map((controller) => controller.text).join();
    if (enteredOtp == generatedOtp) {
      await secureStorage.write(key: 'userPhone', value: widget.phone);
      if (mounted) {
        _showSuccessDialog(); // Show success dialog and then redirect
      }
    } else {
      if (mounted) {
        _showErrorDialog('Invalid OTP. Please try again.');
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside the dialog
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('OTP verified successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  void _showErrorDialog(String message) {
    if (mounted) {
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
                        color: _canResend ? const Color.fromARGB(255, 47, 77, 129) : Colors.grey,
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