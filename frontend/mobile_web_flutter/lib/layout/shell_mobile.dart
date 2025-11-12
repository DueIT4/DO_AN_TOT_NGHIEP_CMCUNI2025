import 'package:flutter/material.dart';

/// Shell layout cho mobile
class ShellMobile extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  
  const ShellMobile({
    super.key,
    required this.body,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
            )
          : null,
      body: body,
    );
  }
}

