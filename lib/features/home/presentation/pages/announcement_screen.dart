import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../core/theme/lightTheme.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // const SizedBox(height: 60,),
            SvgPicture.asset("assets/Svg/announcement.svg",height: 130,),
            Text(context.loc.announcements),
            Text(context.loc.comingSoon),
          ],
        ),
      ),
    );
  }
}
