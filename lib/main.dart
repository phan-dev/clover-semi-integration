import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clover Semi-integration with Flutter POS',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter POS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

var _platform = MethodChannel('phan.dev/clover');

class _MyHomePageState extends State<MyHomePage> {
  // Get connection status.
  String _connectionStatus = 'Unknown connection status.';
  String _pairingCode = 'Unknown pairing code.';
  String _paymentStatus = 'Unknown payment status.';

  Future<void> _connect() async {
    String connectionStatus;

    _platform.setMethodCallHandler(this._methodCallHandler);

    try {
      final String result = await _platform.invokeMethod('connect');
      connectionStatus = 'Connection status: $result';
    } on PlatformException catch (e) {
      connectionStatus = "Failed to connect: '${e.message}'.";
    }

    setState(() {
      _connectionStatus = connectionStatus;
    });
  }

  Future<void> _takePayment() async {
    String paymentStatus;
    try {
      final String result = await _platform.invokeMethod('takePayment');
      paymentStatus = 'Payment status: $result';
    } on PlatformException catch (e) {
      paymentStatus = "Failed to take payment: '${e.message}'.";
    }

    setState(() {
      _paymentStatus = paymentStatus;
    });
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'getCode':
        setState(() {
          _pairingCode = call.arguments;
        });
        break;
      case 'getConnectionStatus':
        setState(() {
          _connectionStatus = call.arguments;
        });
        break;
      case 'getPaymentStatus':
        setState(() {
          _paymentStatus = call.arguments;
        });
        break;
      default:
        setState(() {
          _pairingCode = 'N/A';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              child: Text('Connect'),
              onPressed: _connect,
            ),
            Text(_connectionStatus),
            Text(_pairingCode),
            ElevatedButton(
              child: Text('Take Payment'),
              onPressed: _takePayment,
            ),
            Text(_paymentStatus),
          ],
        ),
      ),
    );
  }
}
