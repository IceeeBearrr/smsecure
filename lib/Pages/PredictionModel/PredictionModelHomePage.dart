import 'package:flutter/material.dart';
import 'package:smsecure/Pages/PredictionModel/BidirectionalLSTM.dart';
import 'package:smsecure/Pages/PredictionModel/LinearSVM.dart';
import 'package:smsecure/Pages/PredictionModel/MultinomialNaiveBayes.dart';

class PredictionModelHomePage extends StatelessWidget {
  const PredictionModelHomePage({super.key});

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'What are Prediction Models?',
            style: TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  textAlign: TextAlign.justify, // Justify the text
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 14, color: Colors.black87, height: 1.5),
                    children: [
                      TextSpan(
                        text:
                            'Prediction models are smart tools that help classify or identify spam messages. These models analyze message patterns and decide whether a message is spam or not. \n\nHere’s what each model does:\n\n',
                      ),
                      TextSpan(
                        text: '- ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Bidirectional LSTM (Default)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            ': This is an advanced tool designed to carefully study the content of your messages. It’s best for understanding longer and more complex texts, which is why it’s set as the default.\n\n',
                      ),
                      TextSpan(
                        text: '- ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Linear SVM',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            ': A simpler tool that works great for straightforward spam detection tasks. It’s faster but not as powerful for complex texts.\n\n',
                      ),
                      TextSpan(
                        text: '- ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Multinomial Naive Bayes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            ': A lightweight tool that is ideal for handling simpler datasets and quick decisions but may not perform as well with more complicated text patterns.\n\n',
                      ),
                      TextSpan(
                        text:
                            'By default, Bidirectional LSTM is selected because it offers the most reliable and accurate results for detecting spam messages, especially for longer or tricky content.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select your Prediction Model',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info',
            onPressed: () {
              _showInfoDialog(context); // Show model information dialog
            },
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          const SizedBox(height: 20),
          PredictionModelTile(
            modelName: 'Bidirectional LSTM',
            isDefault: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BidirectionalLSTMPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          PredictionModelTile(
            modelName: 'Linear SVM',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LinearSVMPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          PredictionModelTile(
            modelName: 'Multinomial NB',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MultinomialNaiveBayesPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PredictionModelTile extends StatelessWidget {
  final String modelName;
  final bool isDefault;
  final VoidCallback onTap;

  const PredictionModelTile({super.key, 
    required this.modelName,
    this.isDefault = false,
    required this.onTap,
  });

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
              modelName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                if (isDefault)
                  const Text(
                    'Default',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey, // Light color for "Default"
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                const SizedBox(width: 8), // Space between "Default" and arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
