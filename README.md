# 📱 SMSecure: Advanced SMS Filtering System

This repository contains the source code and resources for **SMSecure**, an advanced SMS filtering system developed using **Flutter** and **Firestore**. The system leverages machine learning algorithms such as **Linear SVM**, **Multinomial Naive Bayes**, and **Bi-LSTM** to classify SMS messages as spam or non-spam, providing a robust and secure solution to filter unwanted messages.

## 📂 Repository Contents

- **Frontend Components:**
  - Flutter project files for the mobile application's user interface, including **Dart** source files and UI widgets.
  - Pages for the app, such as **HomePage**, **ChatPage**, **ContactPage**, and more, providing a seamless user experience.
  - Custom components like **CustomNavigationBar** for an enhanced navigation experience.

- **Backend Components:**
  - **Firestore** integration for real-time database management and user data storage.
  - Firebase configuration files for connecting the app to the Firebase backend services.

- **Machine Learning Models:**
  - Implementation of **Linear SVM**, **Multinomial Naive Bayes**, and **Bi-LSTM** models to classify incoming SMS messages accurately.
  - Scripts and configurations for training, testing, and deploying machine learning models within the application.

## 🌟 Key Features

- **Advanced SMS Filtering:** Uses machine learning algorithms to detect and filter spam messages effectively.
- **Real-Time Processing:** Integrates with Firestore to provide real-time updates and a seamless user experience.
- **Cross-Platform Support:** Built with Flutter, enabling the app to run on both iOS and Android devices.
- **Secure Data Handling:** Utilizes Firebase authentication and Firestore to ensure secure data storage and access.
- **Customizable User Interface:** Provides a user-friendly and customizable interface with Flutter's versatile widget system.

## 🚀 Getting Started

To run the application locally:

1. Clone the repository to your local machine.
2. Open the project in **Android Studio** or **Visual Studio Code**.
3. Run `flutter pub get` to install the necessary dependencies.
4. Configure the Firebase project and download the `google-services.json` or `GoogleService-Info.plist` files.
5. Run the app on an emulator or a physical device.

## 📊 Machine Learning Models

The application uses three primary machine learning models to classify SMS messages:
- **Linear SVM**: A supervised learning algorithm that separates spam and non-spam messages with a linear hyperplane.
- **Multinomial Naive Bayes**: A probabilistic classifier based on applying Bayes' theorem with strong independence assumptions.
- **Bi-LSTM (Bidirectional Long Short-Term Memory)**: A deep learning model that captures contextual information in both forward and backward directions, improving classification accuracy.

## 💡 Contribution

Feel free to fork the repository, create issues, or submit pull requests if you'd like to contribute or improve the application.
