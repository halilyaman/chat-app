import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String peerId;
  final String nickname;
  final String photoUrl;
  final SharedPreferences prefs;

  ChatPage(
      {this.chatId, this.peerId, this.nickname, this.photoUrl, this.prefs});
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _key = GlobalKey<FormState>();
  String _message = "";
  List<String> messagePool = [];
  Firestore db;
  int messageCounter = 0;
  ScrollController _controller = ScrollController();
  File imageFile;
  String imageUrl;
  ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    db = Firestore.instance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: ListTile(
            trailing: CircleAvatar(
              backgroundImage: NetworkImage(widget.photoUrl),
            ),
            title: Text(
              widget.nickname,
              style: TextStyle(fontSize: 20.0, color: Colors.white),
            ),
          ),
        ),
        body: Stack(children: [
          Container(
            height: double.maxFinite,
            width: double.maxFinite,
            color: Colors.grey,
          ),
          Column(
            children: [
              // display messages
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                      child: StreamBuilder(
                    stream: db
                        .collection("users")
                        .document(widget.prefs.get("id"))
                        .collection("chats")
                        .document(widget.peerId)
                        .collection("messages")
                        .orderBy("sentTime", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(
                          child: Text("No message"),
                        );
                      }

                      return ListView.builder(
                        controller: _controller,
                        itemCount: snapshot.data.documents.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          return _buildMessages(snapshot, index);
                        },
                      );
                    },
                  )),
                ),
              ),

              // write and send message
              Form(
                key: _key,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // text input
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 10.0, right: 10.0, bottom: 6.0),
                      child: Container(
                        height: 50.0,
                        constraints: BoxConstraints(maxHeight: 200.0),
                        width: MediaQuery.of(context).size.width - 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50.0),
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.only(left: 14.0, right: 20.0),
                          child: TextFormField(
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                icon: Icon(Icons.image),
                                onPressed: getImage,
                              ),
                              icon: Icon(Icons.message),
                              hintText: "Type a message",
                              border: InputBorder.none,
                            ),
                            onChanged: (text) {
                              setState(() {
                                _message = text;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // send button
                    Container(
                      height: 55,
                      width: 55,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50.0),
                          color: Colors.indigoAccent),
                      child: IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () => sendMessage(0),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ]));
  }

  getImage() async {
    final pickedFile = await _picker.getImage(source: ImageSource.gallery);
    imageFile = File(pickedFile.path);

    if (pickedFile != null) {
      uploadFile();
    }
  }

  uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(imageFile);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
      _message = downloadUrl;
      sendMessage(1);
    }, onError: (err) {
      Fluttertoast.showToast(msg: "This file is not an image");
    });
  }

  sendMessage(int type) {
    // types: 0 = text, 1 = image

    if (_checkMessageContent()) {
      _key.currentState.reset();

      messagePool.add(_message);
      uploadMessageData(type);

      setState(() {
        _message = "";
      });
    }
  }

  uploadMessageData(int type) async {
    while (messagePool.isNotEmpty) {
      String message = messagePool.removeLast();

      String time = DateTime.now().millisecondsSinceEpoch.toString();

      // save message in sender's document
      await db.runTransaction((transaction) => transaction.set(
              db
                  .collection("users")
                  .document(widget.prefs.get("id"))
                  .collection("chats")
                  .document(widget.peerId)
                  .collection("messages")
                  .document(time),
              {
                "sender": widget.prefs.get("id"),
                "receiver": widget.peerId,
                "sentTime": time,
                "message": message,
                "type": type.toString()
              }));

      // save message in receiver's document
      await db.runTransaction((transaction) => transaction.set(
              db
                  .collection("users")
                  .document(widget.peerId)
                  .collection("chats")
                  .document(widget.prefs.get("id"))
                  .collection("messages")
                  .document(time),
              {
                "sender": widget.prefs.get("id"),
                "receiver": widget.peerId,
                "sentTime": time,
                "message": message,
                "type": type.toString()
              }));

      // notify receiver
      await db.runTransaction((transaction) => transaction.set(
              db
                  .collection("users")
                  .document(widget.peerId)
                  .collection("chats")
                  .document(widget.prefs.get("id")),
              {
                "chattingWith": widget.prefs.get("id"),
                "photoUrl": widget.prefs.get("photoUrl"),
                "nickname": widget.prefs.get("nickname")
              }));

      // notify sender
      await db.runTransaction((transaction) => transaction.set(
              db
                  .collection("users")
                  .document(widget.prefs.get("id"))
                  .collection("chats")
                  .document(widget.peerId),
              {
                "chattingWith": widget.peerId,
                "photoUrl": widget.photoUrl,
                "nickname": widget.nickname
              }));

      // save message permanently
      await db.runTransaction((transaction) => transaction.set(
              db
                  .collection("messages")
                  .document(widget.chatId)
                  .collection(widget.chatId)
                  .document(time),
              {
                "sender": widget.prefs.get("id"),
                "receiver": widget.peerId,
                "sentTime": time,
                "message": message,
                "type": type.toString()
              }));
    }
  }

  _checkMessageContent() {
    if (_message.isEmpty) {
      return false;
    }

    bool flag = false;
    for (int i = 0; i < _message.length; i++) {
      if (_message[i] != " ") {
        flag = true;
        break;
      }
    }

    if (!flag) {
      return false;
    }

    return true;
  }

  _buildMessages(snapshot, index) {
    bool isMe =
        snapshot.data.documents[index]["sender"] == widget.prefs.get("id");
    String message = snapshot.data.documents[index]["message"];
    String millis = snapshot.data.documents[index]["sentTime"];
    DateTime time = DateTime.fromMillisecondsSinceEpoch(int.parse(millis));
    int type = int.parse(snapshot.data.documents[index]["type"]);

    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * (3 / 4)),
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: MessageBox(message, time, isMe, db, widget.chatId,
                widget.prefs, widget.peerId, type)),
      ),
    );
  }
}

class MessageBox extends StatelessWidget {
  final String message;
  final DateTime time;
  final bool isMe;
  final Firestore db;
  final String chatId;
  final SharedPreferences prefs;
  final String peerId;
  final int type;

  MessageBox(this.message, this.time, this.isMe, this.db, this.chatId,
      this.prefs, this.peerId, this.type);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 50.0),
              backgroundColor: Colors.black45,
              child: Container(
                height: 120.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      time.day.toString() +
                          " " +
                          getMonthName(time.month) +
                          " " +
                          time.year.toString(),
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      getDayName(time.weekday) +
                          " - " +
                          time.hour.toString() +
                          ":" +
                          time.minute.toString(),
                      style: TextStyle(color: Colors.white),
                    ),
                    isMe
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MaterialButton(
                                child: Text(
                                  "Delete From Me",
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed: () async {
                                  await db.runTransaction((transaction) async =>
                                      await transaction.delete(db
                                          .collection("users")
                                          .document(prefs.get("id"))
                                          .collection("chats")
                                          .document(peerId)
                                          .collection("messages")
                                          .document(time.millisecondsSinceEpoch
                                              .toString())));

                                  Navigator.pop(context);
                                },
                              ),
                              MaterialButton(
                                child: Text(
                                  "Delete From Everyone",
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed: () async {
                                  await db.runTransaction((transaction) async =>
                                      await transaction.delete(db
                                          .collection("users")
                                          .document(prefs.get("id"))
                                          .collection("chats")
                                          .document(peerId)
                                          .collection("messages")
                                          .document(time.millisecondsSinceEpoch
                                              .toString())));

                                  await db.runTransaction((transaction) async =>
                                      await transaction.delete(db
                                          .collection("users")
                                          .document(peerId)
                                          .collection("chats")
                                          .document(prefs.get("id"))
                                          .collection("messages")
                                          .document(time.millisecondsSinceEpoch
                                              .toString())));

                                  Navigator.pop(context);
                                },
                              )
                            ],
                          )
                        : Container(),
                  ],
                ),
              ),
            );
          }),
      child: Container(
        decoration: BoxDecoration(
            color: isMe ? Colors.lightGreenAccent[100] : Colors.white,
            borderRadius: BorderRadius.circular(10.0)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: type == 0
              ? Text(message)
              : CachedNetworkImage(
                  width: 200,
                  height: 200,
                  placeholder: (context, url) => Container(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                    width: 200.0,
                    height: 200.0,
                    padding: EdgeInsets.all(70.0),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.all(
                        Radius.circular(8.0),
                      ),
                    ),
                  ),
                  imageUrl: message,
                ),
        ),
      ),
    );
  }

  getMonthName(monthNumber) {
    if (monthNumber == DateTime.january) {
      return "January";
    } else if (monthNumber == DateTime.february) {
      return "February";
    } else if (monthNumber == DateTime.march) {
      return "March";
    } else if (monthNumber == DateTime.april) {
      return "April";
    } else if (monthNumber == DateTime.may) {
      return "May";
    } else if (monthNumber == DateTime.june) {
      return "June";
    } else if (monthNumber == DateTime.july) {
      return "July";
    } else if (monthNumber == DateTime.august) {
      return "August";
    } else if (monthNumber == DateTime.september) {
      return "September";
    } else if (monthNumber == DateTime.october) {
      return "October";
    } else if (monthNumber == DateTime.november) {
      return "November";
    } else if (monthNumber == DateTime.december) {
      return "December";
    }
  }

  getDayName(dayNumber) {
    if (dayNumber == DateTime.sunday) {
      return "Sunday";
    } else if (dayNumber == DateTime.monday) {
      return "Monday";
    } else if (dayNumber == DateTime.tuesday) {
      return "Tuesday";
    } else if (dayNumber == DateTime.wednesday) {
      return "Wednesday";
    } else if (dayNumber == DateTime.thursday) {
      return "Thursday";
    } else if (dayNumber == DateTime.friday) {
      return "Friday";
    } else if (dayNumber == DateTime.saturday) {
      return "Saturday";
    }
  }
}
