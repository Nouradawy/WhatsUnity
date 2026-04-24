import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PolicyDialog extends StatelessWidget {
  final String mdFileName;
  const PolicyDialog({
    required this.mdFileName,
    super.key}) ;

  @override
  Widget build(BuildContext context) {

    return FutureBuilder(
        future: Future.delayed(Duration(microseconds: 150)).then((value){
          return rootBundle.loadString('assets/Privacy and policy/$mdFileName');
        }),
        builder: (context , snapshot){
          if(snapshot.hasData) {
            return Markdown(
              data: snapshot.data.toString(),
              styleSheet:MarkdownStyleSheet(
                p: const TextStyle(
                  color: Colors.black, // Change this to your desired color
                  fontSize: 13,     // You can also set other text properties
                ),
              ),

            );
          }
          return Center(child: CircularProgressIndicator());
        });
  }
}
