import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

// Only the Web compiler will ever see this file
Widget buildGoogleWebButton() {
  return web.renderButton();
}