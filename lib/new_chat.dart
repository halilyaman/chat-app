import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat.dart';

class NewChat extends StatefulWidget {
  final SharedPreferences prefs;

  NewChat({this.prefs});

  @override
  _NewChatState createState() => _NewChatState();
}

class _NewChatState extends State<NewChat> {
  TextEditingController _controller = TextEditingController();
  List<Widget> searchResults = [];
  List<Widget> friends = [];
  Firestore db;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    db = Firestore.instance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? Container(
                child: TextField(
                  autofocus: true,
                  onEditingComplete: searchUsers,
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Search by name",
                  ),
                ),
              )
            : Text("Contacts"),
        actions: [
          isSearching
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      isSearching = false;
                      searchResults = [];
                    });
                  },
                )
              : IconButton(
                  icon: Icon(Icons.search),
                  onPressed: searchUsers,
                )
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 10.0,
          ),
          searchResults.length != 0
              ? Text(
                  "Search Results",
                  style: TextStyle(fontSize: 16.0),
                )
              : Container(),
          searchResults.length != 0
              ? Divider(
                  color: Colors.black,
                )
              : Container(),
          searchResults.length != 0
              ? Expanded(
                  flex: 1,
                  child: ListView(
                    children: searchResults,
                  ),
                )
              : Container(),
          searchResults.length == 0
              ? Expanded(
                  flex: 1,
                  child: StreamBuilder(
                      stream: db
                          .collection("users")
                          .document(widget.prefs.get("id"))
                          .collection("contacts")
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: Text("No Connection"),
                          );
                        }

                        return ListView.builder(
                            itemCount: snapshot.data.documents.length,
                            itemBuilder: (context, index) {
                              DocumentSnapshot doc =
                                  snapshot.data.documents[index];

                              return Card(
                                margin: EdgeInsets.all(10.0),
                                child: Container(
                                  height: 80.0,
                                  child: Center(
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: NetworkImage(
                                            doc["contactPhotoUrl"]),
                                      ),
                                      title: Text(doc["contactNickname"]),
                                      trailing: Container(
                                        width: 100.0,
                                        child: IconButton(
                                          icon: Icon(Icons.person_add,
                                              color: Colors.green),
                                          onPressed: () async {
                                            showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return Dialog(
                                                    backgroundColor:
                                                        Colors.black45,
                                                    child: Container(
                                                      height: 100.0,
                                                      color: Colors.black45,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceEvenly,
                                                        children: [
                                                          Text(
                                                            "User will be removed from contacts.",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 18.0),
                                                          ),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceEvenly,
                                                            children: [
                                                              IconButton(
                                                                icon: Icon(
                                                                  Icons.check,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                                onPressed:
                                                                    () async {
                                                                  await db.runTransaction((transaction) async => await transaction.delete(db
                                                                      .collection(
                                                                          "users")
                                                                      .document(widget
                                                                          .prefs
                                                                          .get(
                                                                              "id"))
                                                                      .collection(
                                                                          "contacts")
                                                                      .document(
                                                                          doc["contactId"])));
                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                              ),
                                                              IconButton(
                                                                icon: Icon(
                                                                  Icons.clear,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                              )
                                                            ],
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                });
                                          },
                                        ),
                                      ),
                                      onTap: () async {
                                        String peerId = doc["contactId"];
                                        String chatId = "";
                                        if (peerId.codeUnitAt(0) >
                                            widget.prefs
                                                .get("id")
                                                .toString()
                                                .codeUnitAt(0)) {
                                          chatId = peerId.substring(0, 14) +
                                              widget.prefs
                                                  .get("id")
                                                  .toString()
                                                  .substring(14, 28);
                                        } else {
                                          chatId = widget.prefs
                                                  .get("id")
                                                  .toString()
                                                  .substring(0, 14) +
                                              peerId.substring(14, 28);
                                        }

                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => ChatPage(
                                                      chatId: chatId,
                                                      peerId: peerId,
                                                      photoUrl: doc[
                                                          "contactPhotoUrl"],
                                                      nickname: doc[
                                                          "contactNickname"],
                                                      prefs: widget.prefs,
                                                    )));
                                      },
                                    ),
                                  ),
                                ),
                              );
                            });
                      }),
                )
              : Container(),
        ],
      ),
    );
  }

  searchUsers() async {
    setState(() {
      searchResults = [];
      isSearching = true;
    });

    final QuerySnapshot userResults = await Firestore.instance
        .collection("users")
        .where("nickname", isEqualTo: _controller.text)
        .getDocuments();
    final List<DocumentSnapshot> userDocs = userResults.documents;

    for (int i = 0; i < userDocs.length; i++) {
      final QuerySnapshot contactResults = await Firestore.instance
          .collection("users")
          .document(widget.prefs.get("id"))
          .collection("contacts")
          .where("contactId", isEqualTo: userDocs[i]["id"])
          .getDocuments();
      final List<DocumentSnapshot> contactDocs = contactResults.documents;

      bool isAdded = contactDocs.length != 0;

      setState(() {
        if (userDocs[i]["id"] != widget.prefs.get("id")) {
          searchResults.add(Card(
            margin: EdgeInsets.all(20.0),
            child: Container(
              height: 80.0,
              child: Center(
                child: ListTile(
                  title: Text(userDocs[i]["nickname"]),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(userDocs[i]["photoUrl"]),
                  ),
                  onTap: () async {
                    String peerId = userDocs[i]["id"];
                    String chatId = "";
                    if (peerId.codeUnitAt(0) >
                        widget.prefs.get("id").toString().codeUnitAt(0)) {
                      chatId = peerId.substring(0, 14) +
                          widget.prefs.get("id").toString().substring(14, 28);
                    } else {
                      chatId =
                          widget.prefs.get("id").toString().substring(0, 14) +
                              peerId.substring(14, 28);
                    }

                    await db
                        .collection("users")
                        .document(widget.prefs.get("id"))
                        .collection("chats")
                        .document(peerId)
                        .setData({
                      "chattingWith": peerId,
                      "photoUrl": userDocs[i]["photoUrl"],
                      "nickname": userDocs[i]["nickname"]
                    });

                    await db
                        .collection("users")
                        .document(peerId)
                        .collection("chats")
                        .document(widget.prefs.get("id"))
                        .setData({
                      "chattingWith": widget.prefs.get("id"),
                      "photoUrl": widget.prefs.get("photoUrl"),
                      "nickname": widget.prefs.get("nickname"),
                    });

                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ChatPage(
                                  chatId: chatId,
                                  peerId: userDocs[i]["id"],
                                  photoUrl: userDocs[i]["photoUrl"],
                                  nickname: userDocs[i]["nickname"],
                                  prefs: widget.prefs,
                                )));
                  },
                  trailing: IconButton(
                    icon: Icon(
                      Icons.person_add,
                      color: isAdded ? Colors.green : null,
                    ),
                    onPressed: () async {
                      if (isAdded) {
                        Fluttertoast.showToast(msg: "Already added");
                      } else {
                        DocumentSnapshot doc = userDocs[i];
                        String contactId = doc["id"];
                        String contactPhotoUrl = doc["photoUrl"];
                        String contactNickname = doc["nickname"];

                        await db
                            .collection("users")
                            .document(widget.prefs.get("id"))
                            .collection("contacts")
                            .document(userDocs[i]["id"])
                            .setData({
                          "contactId": contactId,
                          "contactNickname": contactNickname,
                          "contactPhotoUrl": contactPhotoUrl
                        });

                        Fluttertoast.showToast(
                            msg: "Person is added to contacts.");
                      }
                    },
                  ),
                ),
              ),
            ),
          ));
        }
      });
    }
    setState(() {
      _controller.clear();
    });
  }
}
