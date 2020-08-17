import 'package:flutter/material.dart';
import 'package:optisend/models/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:optisend/models/chats.dart';
import 'package:optisend/models/message.dart';

class Messages extends ChangeNotifier {
  Map _messages = {};
  List _chatRooms = [];
  Map tmp = {};
  Map newMessage = {};
  int newMessageCount;
  int tmpIDofMessage = 0;
  String tokenforROOM;
  bool isUserlogged = false;
  bool isChatsLoading = true;
  bool isChatsLoadingForMain = true;
  bool _isloadingMessages = true;
  bool ismessagesAdded = false;
  List lastMessageID = [];
  Map userdetail = {};
  Map allChatRoomDetails = {};
  bool isChatRoomCreated = false;
  bool isChatRoomPageActive = false;
  List roomIDsWhileChatRoomActive = [];
  String roomIDofActiveChatRoom = " ";
  var auth;

  String get getToken {
    return tokenforROOM;
  }

  set roomIDofActiveChatroom(val) {
    roomIDofActiveChatRoom = val;
  }

  Future fetchAndSetMessages(int roomId) async {
    if (chats.isNotEmpty) {
      var token = tokenforROOM;
      String url = Api.messages + _chatRooms[roomId].id.toString();
      try {
        await http.get(
          url,
          headers: {
            HttpHeaders.contentTypeHeader: "application/json",
            "Authorization": "Token " + token,
          },
        ).then((response) {
          Map<String, dynamic> data =
              json.decode(response.body) as Map<String, dynamic>;
          if (data["results"].isNotEmpty) {
            try {
              // cannot directly add Message object to Map. So need TemporaryList
              List<Message> temp = [];
              for (var i = 0; i < data["results"].length; i++) {
                temp.add(Message.fromJson(data["results"][i]));
              }
              _messages[chats[roomId].id] = temp;
            } catch (e) {
              print(e);
            }
          } else {
            _messages[chats[roomId].id] = null;
          }

          _isloadingMessages = false;
          notifyListeners();
        });
      } catch (e) {
        print(e);
      }
    }
  }

  bool get messagesLoading {
    return _isloadingMessages;
  }

  Map get newMessages {
    return newMessage;
  }

  addMessages(message, auth) {
    var tempMessage = Message.fromJson({
      "id": int.parse(message["session_id"]),
      "date_created": DateTime.now().toString(),
      "date_modified": DateTime.now().toString(),
      "text": message["message"],
      "sender": int.parse(message["sender"]),
      "recipients": []
    });
    var roomid = message["room_id"];

    // Checking if ChatRoom is already exists
    try {
      if (_messages[roomid] == null || _messages[roomid].isEmpty) {
        _messages[roomid] = {};
        // cannot directly add Message object to Map. So need TemporaryList
        List<Message> temporary = [];
        temporary.add(tempMessage);
        _messages[roomid] = temporary;
        if(_messages[roomid] == null)fetchRoomDetails(roomid, auth);
      } else {
        // Checking if FCM sends the same notification twice
        if (_messages[roomid][0].id.toString() !=
            message["session_id"].toString()) {
          _messages[roomid].insert(0, tempMessage);
        }
      }
    } catch (e) {
      print(e);
    }

    // Checking if Message is sent by ME, if not add it to newMessage list
    if (tempMessage.sender != auth.userdetail.id) {
      // Checking if ChatRoomPage is Active with the roomid, then don't give Notifications
      if (roomid != roomIDofActiveChatRoom) {
        // Checking if ChatRoom is already exists
        if (newMessage[roomid] == null || newMessage[roomid].isEmpty) {
          // cannot directly add Message object to Map. So need TemporaryList
          List<Message> temporary = [];
          temporary.add(tempMessage);
          newMessage[roomid] = {};
          newMessage[roomid] = temporary;
          notifyListeners();
        } else {
          // Checking if FCM sends the same notification twice
          if (newMessage[roomid][0].id.toString() !=
              message["session_id"].toString()) {
            newMessage[roomid].insert(0, tempMessage);
          }
        }
        if (isChatRoomPageActive) {
          if (!roomIDsWhileChatRoomActive.contains(roomid))
            roomIDsWhileChatRoomActive.add(roomid);
        } else {
          changeChatRoomPlace(roomid);
        }
      }
      notifyListeners();
    }
  }

  Map get messages => _messages;

  void readMessages(id) {
    if (newMessage[id] != null) newMessage.remove(id);
    //Here also send readmessage request (backend not ready)
  }

  bool get arethereNewMessage {
    var key = newMessage.keys
        .firstWhere((k) => newMessage[k] != 0, orElse: () => null);
    if (key != null) {
      return true;
    } else {
      return false;
    }
  }

  //______________________________________________________________________________________

  Future createRooms(id, auth) async {
    String tokenforROOM = auth.myTokenFromStorage;
    if (tokenforROOM != null) {
      String url = Api.itemConnectOwner + id.toString() + '/';
      await http.get(
        url,
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          "Authorization": "Token " + tokenforROOM,
        },
      ).then((value) {
        if (value.statusCode == 200) {
          isChatsLoading = true;
          isChatRoomCreated = true;
          _chatRooms = [];
          fetchAndSetRooms(auth);
        } else {
          isChatRoomCreated = false;
        }
        notifyListeners();
      });
    }
  }

  changeChatRoomPlace(id) {
    if (id == "ChangewithList") {
      for (var i = 0; i < roomIDsWhileChatRoomActive.length; i++) {
        for (var j = 0; j < chats.length; j++) {
          if (chats[j].id.toString() ==
              roomIDsWhileChatRoomActive[i].toString()) {
            chats.insert(0, chats.removeAt(j));
            notifyListeners();
          }
        }
      }
      roomIDsWhileChatRoomActive = [];
    } else {
      for (var i = 0; i < chats.length; i++) {
        if (chats[i].id.toString() == id.toString()) {
          chats.insert(0, chats.removeAt(i));
        }
      }
    }
  }

  notifFun() {
    notifyListeners();
  }

  Future fetchRoomDetails(id, auth) async {
    String token = auth.myTokenFromStorage;
    final url = Api.chats + id.toString() + '/';
    http.get(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        "Authorization": "Token " + token,
      },
    ).then((value) {
      if (value.statusCode == 200) {
        Map<String, dynamic> data =
            json.decode(value.body) as Map<String, dynamic>;
        chats.insert(0, Chats.fromJson(data));
        if (!isChatRoomPageActive)notifyListeners();
      }
    });
  }

  Future fetchAndSetRooms(auth) async {
    isChatsLoadingForMain = false;
    if (chats.isEmpty) {
      if (auth.isAuth) {
        tokenforROOM = auth.myTokenFromStorage;
      } else {
        var f;
        auth.removeListener(f);
        final prefs = await SharedPreferences.getInstance();
        if (!prefs.containsKey('userData')) {
          isUserlogged = false;
          return false;
        }
        final extractedUserData =
            json.decode(prefs.getString('userData')) as Map<String, Object>;

        auth.token = extractedUserData['token'];
        tokenforROOM = extractedUserData['token'];
      }
      try {
        const url = Api.chats;
        final response = await http.get(
          url,
          headers: {
            HttpHeaders.contentTypeHeader: "application/json",
            "Authorization": "Token " + tokenforROOM,
          },
        ).then((value) {
          Map<String, dynamic> data =
              json.decode(value.body) as Map<String, dynamic>;
          _chatRooms = [];
          for (var i = 0; i < data["results"].length; i++) {
            _chatRooms.add(Chats.fromJson(data["results"][i]));
          }
          // allChatRoomDetails = dataOrders;
          isChatsLoading = false;
          isChatsLoadingForMain = false;
          notifyListeners();
        });
        return _chatRooms;
      } catch (e) {
        return;
      }
    } else {
      isChatsLoading = false;
    }
  }

  set addChats(Map mesaj) {
    //here goes new room
    notifyListeners();
  }

  List allAddChats(List rooms) {
    _chatRooms = rooms;
    //notifyListeners();
    return _chatRooms;
  }

  bool get userLogged {
    return isUserlogged;
  }

  bool get chatsLoading {
    return isChatsLoading;
  }

  List get chats => _chatRooms;

  Map get chatDetails => allChatRoomDetails;
  Map user_detail = {};
  Map get userDetails {
    return user_detail;
  }

  removeAllDataOfProvider() {
    _messages = {};
    _chatRooms = [];
    tmp = {};
    newMessage = {};
    newMessageCount;
    tmpIDofMessage = 0;
    tokenforROOM = null;
    isUserlogged = false;
    isChatsLoading = true;
    _isloadingMessages = true;
    ismessagesAdded = false;
    lastMessageID = [];
    userdetail = {};
    allChatRoomDetails = {};
  }
}
