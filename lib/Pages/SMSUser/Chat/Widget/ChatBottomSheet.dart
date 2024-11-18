import 'package:flutter/material.dart';

class Chatbottomsheet extends StatefulWidget {
  final Function(String) onSendMessage;
  const Chatbottomsheet({super.key, required this.onSendMessage});

  @override
  State<Chatbottomsheet> createState() => _ChatbottomsheetState();
}

class _ChatbottomsheetState extends State<Chatbottomsheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      decoration: BoxDecoration(color: Colors.white, boxShadow:[
        BoxShadow(
          color: Colors.grey.withOpacity(0.5),
          spreadRadius: 2,
          blurRadius: 10,
          offset: const Offset(0,3),
        ),
      ]),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.add,
              color: Color(0xFF113953),
              size: 30,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: Icon(
              Icons.emoji_emotions_outlined,
              color: Color(0xFF113953),
              size: 30,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Container(
              alignment: Alignment.centerRight,
              width: 270,
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: "Type something",
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: const Icon(
                Icons.send,
                color: Color(0xFF113953),
                size: 30,
              ),
              onPressed: (){
                String messageContent = _controller.text.trim();
                if (messageContent.isNotEmpty) {
                  debugPrint("Button pressed with message: $messageContent");
                  widget.onSendMessage(messageContent);
                  _controller.clear();
                }
              },
            ),
          ),
        ],
      )
    );
  }
}