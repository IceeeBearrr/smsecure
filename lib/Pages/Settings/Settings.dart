import 'package:flutter/material.dart';
import 'package:smsecure/Pages/PredictionModel/PredictionModelHomePage.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          const SizedBox(height: 20),
          SettingsTile(
            title: 'Account',
            onTap: () {
            },
          ),
          const SizedBox(height: 10),
          SettingsTile(
            title: 'Prediction Model',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PredictionModelHomePage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          SettingsTile(
            title: 'Customisation Filtering Setting',
            onTap: () {
            },
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const SettingsTile({
    required this.title,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
