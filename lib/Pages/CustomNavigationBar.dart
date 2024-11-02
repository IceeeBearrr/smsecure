import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:smsecure/Pages/Home/HomePage.dart';
import 'package:smsecure/Pages/Contact/ContactPage.dart';
import 'package:smsecure/Pages/Messages/Messages.dart';
import 'package:smsecure/Pages/Profile/Profile.dart';

class Customnavigationbar extends StatefulWidget {

  const Customnavigationbar({super.key});

  @override
  State<Customnavigationbar> createState() => _CustomnavigationbarState();
}

class _CustomnavigationbarState extends State<Customnavigationbar> {
  int _selectedIndex = 0;

  // Pass widget.userID to HomePage
  late final List<Widget> _widgetOptions = <Widget>[
    const HomePage(), // Use widget.userID here
    const Contactpage(),
    const Messages(),
    const Profile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: GNav(
              rippleColor: Colors.grey[300]!,
              hoverColor: Colors.grey[100]!,
              gap: 8,
              activeColor: const Color(0xFF113953),
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              tabBackgroundColor: Colors.grey[100]!,
              color: Colors.black,
              tabs: const [
                GButton(
                  icon: LineIcons.home,
                  text: "Home",
                ),
                GButton(
                  icon: LineIcons.file,
                  text: "Contacts",
                ),
                GButton(
                  icon: LineIcons.comments,
                  text: "Messages",
                ),
                GButton(
                  icon: LineIcons.user,
                  text: "Personal",
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
