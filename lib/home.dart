import 'package:chatapp/login.dart';
import 'package:chatapp/new_chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat.dart';

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;

  HomePage({this.prefs});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chats"),
        automaticallyImplyLeading: false,
        actions: [
          MaterialButton(
            child: Text("Sign Out"),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await googleSignIn.signOut();
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => LoginPage()));
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: Firestore.instance
            .collection("users")
            .document(widget.prefs.get("id"))
            .collection("chats")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Text("Empty"),
            );
          }
          return ListView.builder(
              itemCount: snapshot.data.documents.length,
              itemBuilder: (context, index) {
                DocumentSnapshot doc = snapshot.data.documents[index];
                String peerId = doc["chattingWith"];
                String photoUrl = doc["photoUrl"];
                String nickname = doc["nickname"];

                String chatId = "";

                if (peerId.codeUnitAt(0) >
                    widget.prefs.get("id").toString().codeUnitAt(0)) {
                  chatId = peerId.substring(0, 14) +
                      widget.prefs.get("id").toString().substring(14, 28);
                } else {
                  chatId = widget.prefs.get("id").toString().substring(0, 14) +
                      peerId.substring(14, 28);
                }

                return Card(
                  margin: EdgeInsets.all(10.0),
                  child: Container(
                    height: 80,
                    child: Center(
                      child: ListTile(
                        title: Text(nickname),
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(photoUrl),
                        ),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                        chatId: chatId,
                                        peerId: peerId,
                                        photoUrl: photoUrl,
                                        nickname: nickname,
                                        prefs: widget.prefs,
                                      )));
                        },
                        onLongPress: () async {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return Dialog(
                                  backgroundColor: Colors.black45,
                                  child: Container(
                                    height: 100.0,
                                    color: Colors.black45,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text(
                                          "Removed from list",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18.0),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.check,
                                                color: Colors.green,
                                              ),
                                              onPressed: () async {
                                                await Firestore.instance
                                                    .collection("users")
                                                    .document(widget.prefs.get("id"))
                                                      .collection("chats")
                                                      .document(peerId)
                                                      .collection("messages")
                                                          .getDocuments()
                                                          .then((snapshot) {
                                                        for (DocumentSnapshot ds
                                                            in snapshot
                                                                .documents) {
                                                          ds.reference.delete();
                                                        }
                                                      });

                                                await Firestore.instance
                                                    .collection("users")
                                                    .document(
                                                        widget.prefs.get("id"))
                                                    .collection("chats")
                                                    .document(peerId)
                                                    .delete();

                                                Navigator.pop(context);
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context);
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
                  ),
                );
              });
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.message),
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => NewChat(prefs: widget.prefs)));
        },
      ),
    );
  }
}
