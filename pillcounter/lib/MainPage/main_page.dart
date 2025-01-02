import 'dart:io';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:image_picker/image_picker.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../util_helper/util.dart';

class ImageAnalyzerPage extends StatefulWidget {
  @override
  _ImageAnalyzerPageState createState() => _ImageAnalyzerPageState();
}

class _ImageAnalyzerPageState extends State<ImageAnalyzerPage> {
  drive.DriveApi? _driveApi;
  String _link = '';
  MqttServerClient? _mqttClient;
  String payload = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
    _connectToMqtt();
  }

  void _connectToMqtt() {
    _mqttClient = MqttServerClient.withPort(
        'broker.hivemq.com', 'clientId-MCvIEl5ga0', 1883);
    _mqttClient!.logging(on: true);

    _mqttClient!.onConnected = _onMqttConnected;
    _mqttClient!.onDisconnected = _onMqttDisconnected;

    _mqttClient!.connect();
  }

  void _onMqttConnected() {
    print('Connected to MQTT');
    _subscribeToMqtt();
  }

  void _onMqttDisconnected() {
    print('Disconnected from MQTT');
  }

  void _publishToMqtt(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    _mqttClient!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }

  void _authenticate() async {
    final credentials = auth.ServiceAccountCredentials.fromJson({
      "type": "service_account",
      "project_id": "purnesh",
      "private_key_id": "private key",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\n-----END PRIVATE KEY-----\n",
      "client_email": "purnesh@purnesh14.iam.gserviceaccount.com",
      "client_id": "102234358957578193853",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/karthikey14%40karthikey14.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    });

    final scopes = [drive.DriveApi.driveFileScope];
    final client = await auth.clientViaServiceAccount(credentials, scopes);
    _driveApi = drive.DriveApi(client);
  }

  Future<dynamic> _uploadImage(ImageSource source) async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.getImage(source: source);

    if (pickedFile != null) {
      setState(() {
        isLoading = true;
      });
      final file = File(pickedFile.path);
      final filename = file.path.split('/').last;

      final media = drive.Media(
        Stream.fromIterable(file.readAsBytesSync().map((e) => [e])),
        file.lengthSync(),
      );

      final driveFile = drive.File()
        ..name = filename
        ..parents = ['1GAlenFjBtlyU6dEDruyRlrVpepOQj1B6'];

      final result =
          await _driveApi?.files.create(driveFile, uploadMedia: media);

      if (result?.webViewLink != null) {
        setState(() {
          _link = result!.webViewLink!;
        });
      } else if (result?.id != null) {
        setState(() {
          _link =
              'https://drive.google.com/file/d/${result!.id}/view?usp=sharing';
        });
      }

      if (_link.isNotEmpty) {
        print('Image uploaded successfully!');
        print('Image Link: $_link');
        _publishToMqtt('tabletUsageAnalyserOS', _link);
        Util.getFlashBar(context, "Uploaded");
      }
    }
  }

  void _subscribeToMqtt() {
    _mqttClient!.subscribe('tabletUsageAnalyserIS', MqttQos.exactlyOnce);
    _mqttClient!.updates!.listen(_onMqttMessageReceived);
  }

  void _onMqttMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    final String topic = messages[0].topic;
    final MqttPublishMessage message =
        messages[0].payload as MqttPublishMessage;
    payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);

    // Handle the received message
    print('Received MQTT message:');
    print('Topic: $topic');
    print('Payload: $payload');
    setState(() {});
    // Add your logic to process the received message
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Home Page'),
        centerTitle: true,
      ),
      body: Stack(children: [
        SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Image.asset(
              "assets/tablet.jpg",
              fit: BoxFit.fill,
            )),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                    border: Border.all(),
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  "PILL COUNTER",
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 150),
              Container(
                  decoration: BoxDecoration(
                      border: Border.all(),
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10)),
                  child: isLoading == false && payload == ""
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(Icons.camera_alt),
                              iconSize: 100,
                              color: Colors.white,
                              onPressed: () {
                                _uploadImage(ImageSource.camera);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.attach_file_sharp),
                              color: Colors.white,
                              iconSize: 100,
                              onPressed: () {
                                _uploadImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: 20,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  payload == ""
                                      ? "Waiting for results"
                                      : payload,
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                payload == ""
                                    ? Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          color: Colors.tealAccent,
                                        ),
                                      )
                                    : SizedBox(),
                              ],
                            ),
                            SizedBox(height: 50),
                            Container(
                              height: 50,
                              width: 200,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isLoading = false;
                                    payload = "";
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        20.0), // Set the border radius
                                  ),
                                  primary:
                                      Colors.green, // Set the background color
                                ),
                                child: Text(
                                  "Upload again",
                                  style: TextStyle(fontSize: 20),
                                ),
                              ),
                            )
                          ],
                        )),
              SizedBox(
                height: 50,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
