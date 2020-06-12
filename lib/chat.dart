import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
                        onPressed: () async {
                          if (_checkMessageContent()) {
                            _key.currentState.reset();

                            messagePool.add(_message);

                            sendMessage();

                            setState(() {
                              _message = "";
                            });

                            _controller
                                .jumpTo(_controller.position.maxScrollExtent);
                          }
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ]));
  }

  sendMessage() async {

    while (messagePool.isNotEmpty) {

      String message = messagePool.removeLast();

      String time = DateTime
          .now()
          .millisecondsSinceEpoch
          .toString();

      // save message in sender's document
      await db.runTransaction((transaction) =>
          transaction
              .set(
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
                "message": message
              }));

      // save message in receiver's document
      await db.runTransaction((transaction) =>
          transaction
              .set(
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
                "message": message
              }));

      // notify receiver
      await db.runTransaction((transaction) =>
          transaction
              .set(
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
      await db.runTransaction((transaction) =>
          transaction
              .set(
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
      await db.runTransaction((transaction) =>
          transaction
              .set(
              db
                  .collection("messages")
                  .document(widget.chatId)
                  .collection(widget.chatId)
                  .document(time),
              {
                "sender": widget.prefs.get("id"),
                "receiver": widget.peerId,
                "sentTime": time,
                "message": message
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

    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * (3 / 4)),
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: MessageBox(message, time, isMe, db, widget.chatId)),
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

  MessageBox(this.message, this.time, this.isMe, this.db, this.chatId);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 120.0),
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
                        ? MaterialButton(
                            child: Text(
                              "Delete Message",
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () async {
                              int time1 = time.millisecondsSinceEpoch;
                              await db.runTransaction((transaction) async =>
                                  await transaction.delete(db
                                      .collection("messages")
                                      .document(chatId)
                                      .collection(chatId)
                                      .document(time1.toString())));

                              int time2 = time1 - 1;
                              await db.runTransaction((transaction) async =>
                                  await transaction.delete(db
                                      .collection("messages")
                                      .document(chatId)
                                      .collection(chatId)
                                      .document(time2.toString())));

                              int time3 = time1 + 1;
                              await db.runTransaction((transaction) async =>
                                  await transaction.delete(db
                                      .collection("messages")
                                      .document(chatId)
                                      .collection(chatId)
                                      .document(time3.toString())));

                              Navigator.pop(context);
                            },
                          )
                        : Container()
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
          child: Text(message),
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
