import 'package:chatapp/home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences prefs;

  bool isLoading = false;
  bool isLoggedIn = false;
  FirebaseUser currentUser;

  @override
  void initState() {
    super.initState();
    isSignedIn();
  }

  void isSignedIn() async {
    this.setState(() {
      isLoading = true;
    });

    prefs = await SharedPreferences.getInstance();

    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => HomePage(prefs: prefs)));
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<Null> handleSignIn() async {
    prefs = await SharedPreferences.getInstance();

    this.setState(() {
      isLoading = true;
    });

    GoogleSignInAccount googleUser = await googleSignIn.signIn();
    GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
        idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);

    FirebaseUser firebaseUser =
        (await firebaseAuth.signInWithCredential(credential)).user;

    if (firebaseUser != null) {
      // Check is already sign up
      final QuerySnapshot result = await Firestore.instance
          .collection("users")
          .where("id", isEqualTo: firebaseUser.uid)
          .getDocuments();
      final List<DocumentSnapshot> documents = result.documents;

      if (documents.length == 0) {
        // Update data to server if new user
        Firestore.instance
            .collection("users")
            .document(firebaseUser.uid)
            .setData({
          "nickname": firebaseUser.displayName,
          "photoUrl": firebaseUser.photoUrl,
          "id": firebaseUser.uid,
          "createdAt": DateTime.now().millisecondsSinceEpoch.toString(),
        });

        // Write data to local
        currentUser = firebaseUser;
        await prefs.setString('id', currentUser.uid);
        await prefs.setString('nickname', currentUser.displayName);
        await prefs.setString('photoUrl', currentUser.photoUrl);
      } else {
        // Write data to local
        await prefs.setString('id', documents[0]['id']);
        await prefs.setString('nickname', documents[0]['nickname']);
        await prefs.setString('photoUrl', documents[0]['photoUrl']);
      }

      Fluttertoast.showToast(msg: "Sign in success");
      this.setState(() {
        isLoading = false;
      });

      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => HomePage(prefs: prefs)));
    } else {
      Fluttertoast.showToast(msg: "Sign in fail");
      this.setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          color: Colors.black45,
          height: double.maxFinite,
          width: double.maxFinite,
          child: Center(
            child: RaisedButton.icon(
                color: Colors.red,
                onPressed: handleSignIn,
                icon: Icon(Icons.account_circle),
                label: Text("Sign In With Google")),
          ),
        ),
        Positioned(
          child: isLoading
              ? Container(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                    ),
                  ),
                  color: Colors.white.withOpacity(0.8),
                )
              : Container(),
        )
      ]),
    );
  }
}
