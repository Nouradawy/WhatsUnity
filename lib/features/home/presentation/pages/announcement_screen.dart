import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../core/theme/lightTheme.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // const SizedBox(height: 60,),
          SvgPicture.asset("assets/Svg/announcement.svg",height: 130,),
          Text(context.loc.announcements),
          Text(context.loc.comingSoon),
        ],
      ),
    );

    if (context.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(context.loc.announcements),
        ),
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.announcements),
      ),
      body: body,
    );
  }
}
