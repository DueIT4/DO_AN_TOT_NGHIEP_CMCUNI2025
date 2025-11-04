import 'package:flutter/material.dart';
import 'src/routes/web_routes.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2F6D3A)),
      initialRoute: WebRoutes.home,
      onGenerateRoute: WebRoutes.onGenerate,
    );
  }
}
