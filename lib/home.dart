import 'dart:convert';

import 'package:chatapp/login.dart';
import 'package:chatapp/new_chat.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_picker/flutter_picker.dart';
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
  List<String> languageNames = [];
  String _currentLanguage;
  int _currentLanguageIndex;

  @override
  void initState() {
    super.initState();

    Constants.user = widget.prefs.get("nickname");

    for (Map lang in languages) {
      languageNames.add(lang["nativeName"]);
    }

    _currentLanguageIndex = widget.prefs.get("langIndex");
    if (_currentLanguageIndex == null) {
      _currentLanguageIndex = 162;
      _currentLanguage = languages[_currentLanguageIndex]["nativeName"];
      widget.prefs
          .setString("langCode", languages[_currentLanguageIndex]["code"]);
      widget.prefs.setInt("langIndex", _currentLanguageIndex);
    } else {
      _currentLanguageIndex = _currentLanguageIndex;
      _currentLanguage = languages[_currentLanguageIndex]["nativeName"];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
              text: "Chats - ",
              style: TextStyle(fontSize: 20.0),
              children: [
                TextSpan(
                    text: "$_currentLanguage", style: TextStyle(fontSize: 13.0))
              ]),
        ),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton(
            onSelected: choiceAction,
            itemBuilder: (context) {
              return Constants.choices.map((choice) {
                return PopupMenuItem(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
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
                                                    .document(
                                                        widget.prefs.get("id"))
                                                    .collection("chats")
                                                    .document(peerId)
                                                    .collection("messages")
                                                    .getDocuments()
                                                    .then((snapshot) {
                                                  for (DocumentSnapshot ds
                                                      in snapshot.documents) {
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

  choiceAction(String choice) async {
    if (choice == Constants.signOut) {
      await FirebaseAuth.instance.signOut();
      await googleSignIn.signOut();
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => LoginPage()));
    } else if (choice == Constants.languages) {
      Picker(
          adapter: PickerDataAdapter<String>(pickerdata: languageNames),
          hideHeader: true,
          title: Text("Select Language"),
          itemExtent: 40.0,
          onConfirm: (picker, value) {
            setState(() {
              _currentLanguage = picker.getSelectedValues()[0];
              _currentLanguageIndex = value[0];
              widget.prefs.setString(
                  "langCode", languages[_currentLanguageIndex]["code"]);
              widget.prefs.setInt("langIndex", _currentLanguageIndex);
            });
          }).showDialog(context);
    }
  }
}

class Constants {
  static String user = "";
  static const String languages = "Languages";
  static const String signOut = "Sign Out";

  static List<String> choices = [user, languages, signOut];
}

final List<Map<String, String>> languages = [
  {"code": "ab", "name": "Abkhaz", "nativeName": "аҧсуа"},
  {"code": "aa", "name": "Afar", "nativeName": "Afaraf"},
  {"code": "af", "name": "Afrikaans", "nativeName": "Afrikaans"},
  {"code": "ak", "name": "Akan", "nativeName": "Akan"},
  {"code": "sq", "name": "Albanian", "nativeName": "Shqip"},
  {"code": "am", "name": "Amharic", "nativeName": "አማርኛ"},
  {"code": "ar", "name": "Arabic", "nativeName": "العربية"},
  {"code": "an", "name": "Aragonese", "nativeName": "Aragonés"},
  {"code": "hy", "name": "Armenian", "nativeName": "Հայերեն"},
  {"code": "as", "name": "Assamese", "nativeName": "অসমীয়া"},
  {"code": "av", "name": "Avaric", "nativeName": "авар мацӀ, магӀарул мацӀ"},
  {"code": "ae", "name": "Avestan", "nativeName": "avesta"},
  {"code": "ay", "name": "Aymara", "nativeName": "aymar aru"},
  {"code": "az", "name": "Azerbaijani", "nativeName": "azərbaycan dili"},
  {"code": "bm", "name": "Bambara", "nativeName": "bamanankan"},
  {"code": "ba", "name": "Bashkir", "nativeName": "башҡорт теле"},
  {"code": "eu", "name": "Basque", "nativeName": "euskara, euskera"},
  {"code": "be", "name": "Belarusian", "nativeName": "Беларуская"},
  {"code": "bn", "name": "Bengali", "nativeName": "বাংলা"},
  {"code": "bh", "name": "Bihari", "nativeName": "भोजपुरी"},
  {"code": "bi", "name": "Bislama", "nativeName": "Bislama"},
  {"code": "bs", "name": "Bosnian", "nativeName": "bosanski jezik"},
  {"code": "br", "name": "Breton", "nativeName": "brezhoneg"},
  {"code": "bg", "name": "Bulgarian", "nativeName": "български език"},
  {"code": "my", "name": "Burmese", "nativeName": "ဗမာစာ"},
  {"code": "ca", "name": "Catalan; Valencian", "nativeName": "Català"},
  {"code": "ch", "name": "Chamorro", "nativeName": "Chamoru"},
  {"code": "ce", "name": "Chechen", "nativeName": "нохчийн мотт"},
  {
    "code": "ny",
    "name": "Chichewa; Chewa; Nyanja",
    "nativeName": "chiCheŵa, chinyanja"
  },
  {"code": "zh", "name": "Chinese", "nativeName": "中文 (Zhōngwén), 汉语, 漢語"},
  {"code": "cv", "name": "Chuvash", "nativeName": "чӑваш чӗлхи"},
  {"code": "kw", "name": "Cornish", "nativeName": "Kernewek"},
  {"code": "co", "name": "Corsican", "nativeName": "corsu, lingua corsa"},
  {"code": "cr", "name": "Cree", "nativeName": "ᓀᐦᐃᔭᐍᐏᐣ"},
  {"code": "hr", "name": "Croatian", "nativeName": "hrvatski"},
  {"code": "cs", "name": "Czech", "nativeName": "česky, čeština"},
  {"code": "da", "name": "Danish", "nativeName": "dansk"},
  {"code": "dv", "name": "Divehi; Dhivehi; Maldivian;", "nativeName": "ދިވެހި"},
  {"code": "nl", "name": "Dutch", "nativeName": "Nederlands, Vlaams"},
  {"code": "en", "name": "English", "nativeName": "English"},
  {"code": "eo", "name": "Esperanto", "nativeName": "Esperanto"},
  {"code": "et", "name": "Estonian", "nativeName": "eesti, eesti keel"},
  {"code": "ee", "name": "Ewe", "nativeName": "Eʋegbe"},
  {"code": "fo", "name": "Faroese", "nativeName": "føroyskt"},
  {"code": "fj", "name": "Fijian", "nativeName": "vosa Vakaviti"},
  {"code": "fi", "name": "Finnish", "nativeName": "suomi, suomen kieli"},
  {"code": "fr", "name": "French", "nativeName": "français, langue française"},
  {
    "code": "ff",
    "name": "Fula; Fulah; Pulaar; Pular",
    "nativeName": "Fulfulde, Pulaar, Pular"
  },
  {"code": "gl", "name": "Galician", "nativeName": "Galego"},
  {"code": "ka", "name": "Georgian", "nativeName": "ქართული"},
  {"code": "de", "name": "German", "nativeName": "Deutsch"},
  {"code": "el", "name": "Greek, Modern", "nativeName": "Ελληνικά"},
  {"code": "gn", "name": "Guaraní", "nativeName": "Avañeẽ"},
  {"code": "gu", "name": "Gujarati", "nativeName": "ગુજરાતી"},
  {
    "code": "ht",
    "name": "Haitian; Haitian Creole",
    "nativeName": "Kreyòl ayisyen"
  },
  {"code": "ha", "name": "Hausa", "nativeName": "Hausa, هَوُسَ"},
  {"code": "he", "name": "Hebrew (modern)", "nativeName": "עברית"},
  {"code": "hz", "name": "Herero", "nativeName": "Otjiherero"},
  {"code": "hi", "name": "Hindi", "nativeName": "हिन्दी, हिंदी"},
  {"code": "ho", "name": "Hiri Motu", "nativeName": "Hiri Motu"},
  {"code": "hu", "name": "Hungarian", "nativeName": "Magyar"},
  {"code": "ia", "name": "Interlingua", "nativeName": "Interlingua"},
  {"code": "id", "name": "Indonesian", "nativeName": "Bahasa Indonesia"},
  {"code": "ie", "name": "Interlingue", "nativeName": "Interlingue"},
  {"code": "ga", "name": "Irish", "nativeName": "Gaeilge"},
  {"code": "ig", "name": "Igbo", "nativeName": "Asụsụ Igbo"},
  {"code": "ik", "name": "Inupiaq", "nativeName": "Iñupiaq, Iñupiatun"},
  {"code": "io", "name": "Ido", "nativeName": "Ido"},
  {"code": "is", "name": "Icelandic", "nativeName": "Íslenska"},
  {"code": "it", "name": "Italian", "nativeName": "Italiano"},
  {"code": "iu", "name": "Inuktitut", "nativeName": "ᐃᓄᒃᑎᑐᑦ"},
  {"code": "ja", "name": "Japanese", "nativeName": "日本語 (にほんご／にっぽんご)"},
  {"code": "jv", "name": "Javanese", "nativeName": "basa Jawa"},
  {
    "code": "kl",
    "name": "Kalaallisut, Greenlandic",
    "nativeName": "kalaallisut, kalaallit oqaasii"
  },
  {"code": "kn", "name": "Kannada", "nativeName": "ಕನ್ನಡ"},
  {"code": "kr", "name": "Kanuri", "nativeName": "Kanuri"},
  {"code": "ks", "name": "Kashmiri", "nativeName": "कश्मीरी, كشميري‎"},
  {"code": "kk", "name": "Kazakh", "nativeName": "Қазақ тілі"},
  {"code": "km", "name": "Khmer", "nativeName": "ភាសាខ្មែរ"},
  {"code": "ki", "name": "Kikuyu, Gikuyu", "nativeName": "Gĩkũyũ"},
  {"code": "rw", "name": "Kinyarwanda", "nativeName": "Ikinyarwanda"},
  {"code": "ky", "name": "Kirghiz, Kyrgyz", "nativeName": "кыргыз тили"},
  {"code": "kv", "name": "Komi", "nativeName": "коми кыв"},
  {"code": "kg", "name": "Kongo", "nativeName": "KiKongo"},
  {"code": "ko", "name": "Korean", "nativeName": "한국어 (韓國語), 조선말 (朝鮮語)"},
  {"code": "ku", "name": "Kurdish", "nativeName": "Kurdî, كوردی‎"},
  {"code": "kj", "name": "Kwanyama, Kuanyama", "nativeName": "Kuanyama"},
  {"code": "la", "name": "Latin", "nativeName": "latine, lingua latina"},
  {
    "code": "lb",
    "name": "Luxembourgish, Letzeburgesch",
    "nativeName": "Lëtzebuergesch"
  },
  {"code": "lg", "name": "Luganda", "nativeName": "Luganda"},
  {
    "code": "li",
    "name": "Limburgish, Limburgan, Limburger",
    "nativeName": "Limburgs"
  },
  {"code": "ln", "name": "Lingala", "nativeName": "Lingála"},
  {"code": "lo", "name": "Lao", "nativeName": "ພາສາລາວ"},
  {"code": "lt", "name": "Lithuanian", "nativeName": "lietuvių kalba"},
  {"code": "lu", "name": "Luba-Katanga", "nativeName": "Luba-Katanga"},
  {"code": "lv", "name": "Latvian", "nativeName": "latviešu valoda"},
  {"code": "gv", "name": "Manx", "nativeName": "Gaelg, Gailck"},
  {"code": "mk", "name": "Macedonian", "nativeName": "македонски јазик"},
  {"code": "mg", "name": "Malagasy", "nativeName": "Malagasy fiteny"},
  {"code": "ms", "name": "Malay", "nativeName": "bahasa Melayu, بهاس ملايو‎"},
  {"code": "ml", "name": "Malayalam", "nativeName": "മലയാളം"},
  {"code": "mt", "name": "Maltese", "nativeName": "Malti"},
  {"code": "mi", "name": "Māori", "nativeName": "te reo Māori"},
  {"code": "mr", "name": "Marathi (Marāṭhī)", "nativeName": "मराठी"},
  {"code": "mh", "name": "Marshallese", "nativeName": "Kajin M̧ajeļ"},
  {"code": "mn", "name": "Mongolian", "nativeName": "монгол"},
  {"code": "na", "name": "Nauru", "nativeName": "Ekakairũ Naoero"},
  {
    "code": "nv",
    "name": "Navajo, Navaho",
    "nativeName": "Diné bizaad, Dinékʼehǰí"
  },
  {"code": "nb", "name": "Norwegian Bokmål", "nativeName": "Norsk bokmål"},
  {"code": "nd", "name": "North Ndebele", "nativeName": "isiNdebele"},
  {"code": "ne", "name": "Nepali", "nativeName": "नेपाली"},
  {"code": "ng", "name": "Ndonga", "nativeName": "Owambo"},
  {"code": "nn", "name": "Norwegian Nynorsk", "nativeName": "Norsk nynorsk"},
  {"code": "no", "name": "Norwegian", "nativeName": "Norsk"},
  {"code": "ii", "name": "Nuosu", "nativeName": "ꆈꌠ꒿ Nuosuhxop"},
  {"code": "nr", "name": "South Ndebele", "nativeName": "isiNdebele"},
  {"code": "oc", "name": "Occitan", "nativeName": "Occitan"},
  {"code": "oj", "name": "Ojibwe, Ojibwa", "nativeName": "ᐊᓂᔑᓈᐯᒧᐎᓐ"},
  {
    "code": "cu",
    "name":
        "Old Church Slavonic, Church Slavic, Church Slavonic, Old Bulgarian, Old Slavonic",
    "nativeName": "ѩзыкъ словѣньскъ"
  },
  {"code": "om", "name": "Oromo", "nativeName": "Afaan Oromoo"},
  {"code": "or", "name": "Oriya", "nativeName": "ଓଡ଼ିଆ"},
  {"code": "os", "name": "Ossetian, Ossetic", "nativeName": "ирон æвзаг"},
  {"code": "pa", "name": "Panjabi, Punjabi", "nativeName": "ਪੰਜਾਬੀ, پنجابی‎"},
  {"code": "pi", "name": "Pāli", "nativeName": "पाऴि"},
  {"code": "fa", "name": "Persian", "nativeName": "فارسی"},
  {"code": "pl", "name": "Polish", "nativeName": "polski"},
  {"code": "ps", "name": "Pashto, Pushto", "nativeName": "پښتو"},
  {"code": "pt", "name": "Portuguese", "nativeName": "Português"},
  {"code": "qu", "name": "Quechua", "nativeName": "Runa Simi, Kichwa"},
  {"code": "rm", "name": "Romansh", "nativeName": "rumantsch grischun"},
  {"code": "rn", "name": "Kirundi", "nativeName": "kiRundi"},
  {
    "code": "ro",
    "name": "Romanian, Moldavian, Moldovan",
    "nativeName": "română"
  },
  {"code": "ru", "name": "Russian", "nativeName": "русский язык"},
  {"code": "sa", "name": "Sanskrit (Saṁskṛta)", "nativeName": "संस्कृतम्"},
  {"code": "sc", "name": "Sardinian", "nativeName": "sardu"},
  {"code": "sd", "name": "Sindhi", "nativeName": "सिन्धी, سنڌي، سندھی‎"},
  {"code": "se", "name": "Northern Sami", "nativeName": "Davvisámegiella"},
  {"code": "sm", "name": "Samoan", "nativeName": "gagana faa Samoa"},
  {"code": "sg", "name": "Sango", "nativeName": "yângâ tî sängö"},
  {"code": "sr", "name": "Serbian", "nativeName": "српски језик"},
  {"code": "gd", "name": "Scottish Gaelic; Gaelic", "nativeName": "Gàidhlig"},
  {"code": "sn", "name": "Shona", "nativeName": "chiShona"},
  {"code": "si", "name": "Sinhala, Sinhalese", "nativeName": "සිංහල"},
  {"code": "sk", "name": "Slovak", "nativeName": "slovenčina"},
  {"code": "sl", "name": "Slovene", "nativeName": "slovenščina"},
  {"code": "so", "name": "Somali", "nativeName": "Soomaaliga, af Soomaali"},
  {"code": "st", "name": "Southern Sotho", "nativeName": "Sesotho"},
  {
    "code": "es",
    "name": "Spanish; Castilian",
    "nativeName": "español, castellano"
  },
  {"code": "su", "name": "Sundanese", "nativeName": "Basa Sunda"},
  {"code": "sw", "name": "Swahili", "nativeName": "Kiswahili"},
  {"code": "ss", "name": "Swati", "nativeName": "SiSwati"},
  {"code": "sv", "name": "Swedish", "nativeName": "svenska"},
  {"code": "ta", "name": "Tamil", "nativeName": "தமிழ்"},
  {"code": "te", "name": "Telugu", "nativeName": "తెలుగు"},
  {"code": "tg", "name": "Tajik", "nativeName": "тоҷикӣ, toğikī, تاجیکی‎"},
  {"code": "th", "name": "Thai", "nativeName": "ไทย"},
  {"code": "ti", "name": "Tigrinya", "nativeName": "ትግርኛ"},
  {
    "code": "bo",
    "name": "Tibetan Standard, Tibetan, Central",
    "nativeName": "བོད་ཡིག"
  },
  {"code": "tk", "name": "Turkmen", "nativeName": "Türkmen, Түркмен"},
  {
    "code": "tl",
    "name": "Tagalog",
    "nativeName": "Wikang Tagalog, ᜏᜒᜃᜅ᜔ ᜆᜄᜎᜓᜄ᜔"
  },
  {"code": "tn", "name": "Tswana", "nativeName": "Setswana"},
  {"code": "to", "name": "Tonga (Tonga Islands)", "nativeName": "faka Tonga"},
  {"code": "tr", "name": "Turkish", "nativeName": "Türkçe"},
  {"code": "ts", "name": "Tsonga", "nativeName": "Xitsonga"},
  {"code": "tt", "name": "Tatar", "nativeName": "татарча, tatarça, تاتارچا‎"},
  {"code": "tw", "name": "Twi", "nativeName": "Twi"},
  {"code": "ty", "name": "Tahitian", "nativeName": "Reo Tahiti"},
  {"code": "ug", "name": "Uighur, Uyghur", "nativeName": "Uyƣurqə, ئۇيغۇرچە‎"},
  {"code": "uk", "name": "Ukrainian", "nativeName": "українська"},
  {"code": "ur", "name": "Urdu", "nativeName": "اردو"},
  {"code": "uz", "name": "Uzbek", "nativeName": "zbek, Ўзбек, أۇزبېك‎"},
  {"code": "ve", "name": "Venda", "nativeName": "Tshivenḓa"},
  {"code": "vi", "name": "Vietnamese", "nativeName": "Tiếng Việt"},
  {"code": "vo", "name": "Volapük", "nativeName": "Volapük"},
  {"code": "wa", "name": "Walloon", "nativeName": "Walon"},
  {"code": "cy", "name": "Welsh", "nativeName": "Cymraeg"},
  {"code": "wo", "name": "Wolof", "nativeName": "Wollof"},
  {"code": "fy", "name": "Western Frisian", "nativeName": "Frysk"},
  {"code": "xh", "name": "Xhosa", "nativeName": "isiXhosa"},
  {"code": "yi", "name": "Yiddish", "nativeName": "ייִדיש"},
  {"code": "yo", "name": "Yoruba", "nativeName": "Yorùbá"},
  {
    "code": "za",
    "name": "Zhuang, Chuang",
    "nativeName": "Saɯ cueŋƅ, Saw cuengh"
  }
];
