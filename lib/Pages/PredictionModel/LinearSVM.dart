import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class LinearSVMPage extends StatefulWidget {
  const LinearSVMPage({super.key});

  @override
  _LinearSVMPageState createState() => _LinearSVMPageState();
}

class _LinearSVMPageState extends State<LinearSVMPage> {
  Map<String, dynamic>? svmMetrics;
  bool isLoading = true;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchSVMMetrics();
  }

  Future<void> fetchSVMMetrics() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Check if the Linear SVM model exists
      final modelQuery = await firestore
          .collection('predictionModel')
          .where('name', isEqualTo: 'Linear SVM')
          .get();

      String modelDocID;

      if (modelQuery.docs.isNotEmpty) {
        modelDocID = modelQuery.docs.first.id;
      } else {
        // Create a new document for the model if it doesn't exist
        final newModelDoc = await firestore
            .collection('predictionModel')
            .add({'name': 'Linear SVM'});
        modelDocID = newModelDoc.id;
      }

      // Fetch the most recent metrics from the `Metrics` subcollection
      final metricsQuery = await firestore
          .collection('predictionModel')
          .doc(modelDocID)
          .collection('Metrics')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (metricsQuery.docs.isNotEmpty) {
        setState(() {
          svmMetrics = metricsQuery.docs.first.data();
          isLoading = false;
        });
      } else {
        setState(() {
          svmMetrics = null;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching SVM metrics: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveSelectedModel() async {
    try {
      String? userPhone = await storage.read(key: 'userPhone');
      if (userPhone == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('User phone not found in secure storage.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final smsUserCollection =
          FirebaseFirestore.instance.collection('smsUser');
      final smsUserSnapshot =
          await smsUserCollection.where('phoneNo', isEqualTo: userPhone).get();

      if (smsUserSnapshot.docs.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content:
                const Text('smsUser not found for the provided phone number.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final smsUserID = smsUserSnapshot.docs.first.id;
      final smsUserDocRef = smsUserCollection.doc(smsUserID);
      final smsUserData = smsUserSnapshot.docs.first.data();

      if (smsUserData['selectedModel'] == 'Linear SVM') {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Info'),
            content:
                const Text('You have already selected the Linear SVM model.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        await smsUserDocRef.update({'selectedModel': 'Linear SVM'});

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Prediction model updated to Linear SVM.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error saving selected model: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('An error occurred: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget buildDecodedImage(String base64String) {
    try {
      final Uint8List decodedBytes = base64Decode(base64String);
      return InteractiveViewer(
        child: Image.memory(
          decodedBytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: 300,
        ),
      );
    } catch (e) {
      return const Text(
        'Error decoding image',
        style: TextStyle(color: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (svmMetrics == null) {
      return const Scaffold(
        body: Center(child: Text('No data available')),
      );
    }

    String formattedTimestamp = DateFormat('yyyy-MM-dd hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(
          svmMetrics!['timestamp'].seconds * 1000),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Linear SVM',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated At: $formattedTimestamp',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            const Text(
              'What is Linear SVM?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Linear SVM (Support Vector Machine) is a simple and effective machine learning model. '
              'It works well for spam detection by identifying boundaries between spam and non-spam messages.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            const Text(
              'Model Metrics:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.grey),
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Train Accuracy',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          '${(svmMetrics!['trainAccuracy'] * 100).toStringAsFixed(2)}%'),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Test Accuracy',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          '${(svmMetrics!['testAccuracy'] * 100).toStringAsFixed(2)}%'),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Precision',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          '${(svmMetrics!['testPrecision'] * 100).toStringAsFixed(2)}%'),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Recall',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          '${(svmMetrics!['testRecall'] * 100).toStringAsFixed(2)}%'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'What do these metrics mean?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: 'Train Accuracy: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text:
                          'Indicates how well the model performed on the data it was trained on.\n'),
                  TextSpan(
                      text: 'Test Accuracy: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text:
                          'Shows the model\'s performance on new, unseen data.\n'),
                  TextSpan(
                      text: 'Precision: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text:
                          'Measures the percentage of messages predicted as spam that are actually spam.\n'),
                  TextSpan(
                      text: 'Recall: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text:
                          'Indicates how well the model identifies all spam messages from the dataset.'),
                ],
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            const Text(
              'Confusion Matrix:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            buildDecodedImage(svmMetrics!['confusionMatrix']),
            const SizedBox(height: 8),
            const Text(
              'A Confusion Matrix is a table that shows how well the model predicted spam and non-spam messages, displaying correct and incorrect predictions.\n\nA good confusion matrix has high numbers in the correct prediction boxes (diagonal cells) and very low or zero numbers in the incorrect prediction boxes (off-diagonal cells).',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            const Text(
              'Learning Curve:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            buildDecodedImage(svmMetrics!['accuracyCurve']),
            const SizedBox(height: 8),
            const Text(
              'The learning curve is a graph that shows how a models performance improves over time or with more training data, helping to assess its learning progress and identify overfitting or underfitting.\n\nA good learning curve shows steady improvement with the training and validation lines getting closer, indicating the model learns well without overfitting or underfitting.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 20),
            const Text(
              'ROC Curve:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            buildDecodedImage(svmMetrics!['rocCurve']),
            const SizedBox(height: 8),
            const Text(
              'The ROC Curve is a graph that shows how well the model separates spam from non-spam messages.\n\nA good ROC curve stays close to the top-left corner, meaning the model is making more correct predictions and fewer mistakes.',
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveSelectedModel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 47, 77, 129),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Select This Prediction Model',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
