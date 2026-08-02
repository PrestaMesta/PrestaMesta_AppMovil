import 'package:flutter/material.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PrestaMestaApp());
}

class PrestaMestaApp extends StatelessWidget {
  const PrestaMestaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrestaMesta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootShell(),
    );
  }
}
