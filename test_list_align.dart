import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: Test()));

class Test extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ListView.builder(
          reverse: true,
          shrinkWrap: true,
          itemCount: 5,
          itemBuilder: (ctx, i) => Text('Item $i'),
        ),
      )
    );
  }
}
