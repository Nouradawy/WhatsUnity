import 'package:url_launcher/url_launcher.dart';

Future<void> openWhatsApp(String phoneNumber, String message, {String defaultCountryCode = "20"}) async {
  String cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '').replaceAll('+', '');
  if (!cleanPhone.startsWith(defaultCountryCode) && !phoneNumber.startsWith('+')) {
    cleanPhone = defaultCountryCode + cleanPhone;
  }
  
  final Uri whatsappUrl = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
  
  if (await canLaunchUrl(whatsappUrl)) {
    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
  } else {
    throw 'Could not launch $whatsappUrl';
  }
}
