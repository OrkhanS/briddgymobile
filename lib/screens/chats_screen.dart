import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:optisend/screens/chat_window.dart';
import 'package:provider/provider.dart';
import './auth_screen.dart';
import '../providers/auth.dart';
import 'splash_screen.dart';

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:optisend/main.dart';
import 'chat_window.dart';
import 'package:optisend/web_sockets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:optisend/providers/messages.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatsScreen extends StatefulWidget {
  final StreamController<String> streamController =
      StreamController<String>.broadcast();
  IOWebSocketChannel _channel;

  ObserverList<Function> _listeners = new ObserverList<Function>();
  var rooms;
  ChatsScreen({this.rooms});
  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  PageController pageController;
  int numberOfPages = 6;
  double viewportFraction = 0.75;
  String imageUrl;
  Map _details = {};
  bool _isOn = false;
  bool _islogged = true;
  List<dynamic> _messages = [];
  Map _mesaj = {};
  bool isMessagesLoaded = false;
  Future<int> roomLength;
  List _rooms = [];
  @override
  void initState() {
    pageController = PageController(viewportFraction: viewportFraction);
    super.initState();
    fetchMessageCaller();
  }

  Future fetchMessageCaller() async {
    // if (!Provider.of<Auth>(context, listen: false).isAuth) {
    //   _islogged = false;
    //   return 0;
    // }

    for (var i = 0; i < widget.rooms.length; i++) {
      await fetchAndSetMessages(i);
    }
  }

  /// ----------------------------------------------------------
  /// Fetch Messages Of User
  /// ----------------------------------------------------------
  Future fetchAndSetMessages(int i) async {
    var token = "40694c366ab5935e997a1002fddc152c9566de90";
    String url = "https://briddgy.herokuapp.com/api/chat/messages/?room_id=" +
        widget.rooms[i]["id"].toString();
    await http.get(
      url,
      headers: {
        HttpHeaders.CONTENT_TYPE: "application/json",
        "Authorization": "Token " + token,
      },
    ).then((response) {
      _mesaj = {};
      var dataOrders = json.decode(response.body) as Map<String, dynamic>;
      _mesaj.addAll(dataOrders);
    });
    _messages.add(_mesaj);
    Provider.of<Messages>(context, listen: false).addMessages(_mesaj);
//    todo: remove comment
  }

  /// ----------------------------------------------------------
  /// End Fetching Rooms Of User
  /// ----------------------------------------------------------

  // /// ----------------------------------------------------------
  // /// Creates the WebSocket communication
  // /// ----------------------------------------------------------
  // initCommunication() async {
  //   reset();
  //   try {
  //     widget._channel = new IOWebSocketChannel.connect(
  //         'ws://briddgy.herokuapp.com/ws/alert/?token=40694c366ab5935e997a1002fddc152c9566de90'); //todo
  //     widget._channel.stream.listen(_onReceptionOfMessageFromServer);
  //     print("Alert Connected");
  //   } catch (e) {
  //     print("Error Occured");
  //     reset();
  //   }
  // }

  // /// ----------------------------------------------------------
  // /// Closes the WebSocket communication
  // /// ----------------------------------------------------------
  // reset() {
  //   if (widget._channel != null) {
  //     if (widget._channel.sink != null) {
  //       widget._channel.sink.close();
  //       _isOn = false;
  //     }
  //   }
  // }

  // /// ---------------------------------------------------------
  // /// Adds a callback to be invoked in case of incoming
  // /// notification
  // /// ---------------------------------------------------------
  // addListener(Function callback) {
  //   widget._listeners.add(callback);
  // }

  // removeListener(Function callback) {
  //   widget._listeners.remove(callback);
  // }

  // /// ----------------------------------------------------------
  // /// Callback which is invoked each time that we are receiving
  // /// a message from the server
  // /// ----------------------------------------------------------
  // _onReceptionOfMessageFromServer(message) {
  //   _mesaj = [];

  //   _mesaj.add(json.decode(message));
  //   // if(_mesaj[0]["id"]){
  //   // Check if "ID" of image sent before, then check its room ID, search in _room and get message ID and use
  //   // it in Message Provider, find message, then add the mesaj into that
  //   // }
  //   _isOn = true;
  // }

  @override
  Widget build(BuildContext context) {
    // getAvatarUrl(String a) {
    //   String helper = 'https://briddgy.herokuapp.com/media/';
    //   imageUrl =
    //       'https://moonvillageassociation.org/wp-content/uploads/2018/06/default-profile-picture1.jpg';
    //   if (a != null) {
    //     imageUrl = 'https://briddgy.herokuapp.com/media/' + a.toString() + "/";
    //   }

    //   return imageUrl;
    // }

    List<MaterialColor> colors = [
      Colors.amber,
      Colors.red,
      Colors.green,
      Colors.lightBlue,
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Center(
          child: Text(
            "Chats",
            style: TextStyle(
                color: (Theme.of(context).primaryColor),
                fontWeight: FontWeight.bold),
          ),
        ),
        elevation: 1,
      ),
      body: Container(
        child:
            // _islogged == true
            //     ? Center(child: Text('You do not have chats yet'))
            //:
            // Center(child: CircularProgressIndicator())

            ListView.builder(
          itemCount:
              // _islogged == true ?
              widget.rooms.length,
          //: 0,
          itemBuilder: (context, int index) {
            return Column(
              children: <Widget>[
                Divider(
                  height: 12.0,
                ),
                ListTile(
                  leading: CircleAvatar(
                      radius: 24.0,
                      child: FadeInImage(
                        image: NetworkImage(
                            'https://toppng.com/uploads/preview/person-icon-white-icon-11553393970jgwtmsc59i.png'),
                        placeholder: NetworkImage(
                            'https://toppng.com/uploads/preview/person-icon-white-icon-11553393970jgwtmsc59i.png'),
                      )),
                  title: Row(
                    children: <Widget>[
                      Text(
                        widget.rooms[index]["members"][0]["first_name"]
                                .toString() +
                            " " +
                            widget.rooms[index]["members"][0]["last_name"]
                                .toString(),
                        style: TextStyle(fontSize: 15.0),
                      ),
                      SizedBox(
                        width: 16.0,
                      ),
                      // Text(
                      //   widget.rooms[index]["date_modified"]
                      //       .toString()
                      //       .substring(0, 10),
                      //   style: TextStyle(fontSize: 15.0),
                      // ),
                    ],
                  ),
                  subtitle: Text(
                    "Last Message:" +
                        "  " +
                        timeago
                            .format(DateTime.parse(widget.rooms[index]
                                        ["date_modified"]
                                    .toString()
                                    .substring(0, 10) +
                                " " +
                                widget.rooms[index]["date_modified"]
                                    .toString()
                                    .substring(11, 26)))
                            .toString(),
                    style: TextStyle(fontSize: 15.0),
                    // _messages[index]["results"][0]["text"]
                    //   .toString().substring(0,15)
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14.0,
                  ),
                  onTap: () {
                    // Navigator.of(context).pushNamed('/chats/chat_window');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (__) => ChatWindow(
                              messages: _messages[index],
                              room: widget.rooms[index]["id"],
                              user: widget.rooms[index]["members"])),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
