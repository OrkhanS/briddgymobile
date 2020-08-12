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
  bool _isloadingMessages = true;
  bool ismessagesAdded = false;
  List lastMessageID = [];
  Map userdetail = {};
  Map allChatRoomDetails = {};
  bool isChatRoomCreated = false;
  bool isChatRoomPageActive = false;
  var auth;

  String get getToken {
    return tokenforROOM;
  }

  Future fetchAndSetMessages(int roomId) async {
    if (chats.isNotEmpty) {
      var token = tokenforROOM;
      String url = Api.messages + _chatRooms[roomId].id.toString();
      try {
        await http.get(
          url,
          headers: {
            HttpHeaders.CONTENT_TYPE: "application/json",
            "Authorization": "Token " + token,
          },
        ).then((response) {
          Map<String, dynamic> data =
              json.decode(response.body) as Map<String, dynamic>;
          var a = Message.fromJson(data["results"][0]);
          print(a);
          try {
            List<Message> temp = [];
            for (var i = 0; i < data["results"].length; i++) {
              temp.add(Message.fromJson(data["results"][i]));
            }
            _messages[chats[roomId].id] = temp;
          } catch (e) {
            print(e);
          }

          _isloadingMessages = false;
          notifyListeners();
        });
      } catch (e) {}
    }
  }

  bool get messagesNotLoaded {
    return _isloadingMessages;
  }

  Map get newMessages {
    return newMessage;
  }

  addMessages(message, auth) {
    var temp = {
      "id": int.parse(message["session_id"]),
      "date_created": DateTime.now().toString(),
      "date_modified": DateTime.now().toString(),
      "text": message["message"],
      "sender": int.parse(message["sender"]),
      "recipients": []
    };
    var tempMessage = Message.fromJson(temp);
    if (_messages[message["room_id"]] == null) {
    } else {
      if (_messages[message["room_id"]][0].id.toString() !=
          message["session_id"].toString()) {
        _messages[message["room_id"]].insert(0, tempMessage);
      }
    }

    // Check if user_id == sender then don't add it to newmessages list
    if (!isChatRoomPageActive) {}
    notifyListeners();
  }

  Map get messages => _messages;

  void readMessages(id) {
    newMessage[id] = 0;
    //newMessage.remove(id);
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
          HttpHeaders.CONTENT_TYPE: "application/json",
          "Authorization": "Token " + tokenforROOM,
        },
      ).then((value) {
        if (value.statusCode == 200) {
          isChatRoomCreated = true;
          fetchAndSetRooms(auth);
          isChatsLoading = true;
        } else {
          isChatRoomCreated = false;
        }
        notifyListeners();
      });
    }
  }

  bool changeChatRoomPlace(id) {
    newMessage[id] = 0;
    for (var i = 0; i < _chatRooms.length; i++) {
      if (_chatRooms[i].id == id) {
        _chatRooms.insert(0, _chatRooms.removeAt(i));
        newMessage[id] = 0;
        return true;
      }
    }
    newMessage[id] = 0;
    return false;
  }

  Future fetchAndSetRooms(auth) async {
    isChatsLoading = false;
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
            HttpHeaders.CONTENT_TYPE: "application/json",
            "Authorization": "Token " + tokenforROOM,
          },
        ).then((value) {
          Map<String, dynamic> data =
              json.decode(value.body) as Map<String, dynamic>;
          for (var i = 0; i < data["results"].length; i++) {
            _chatRooms.add(Chats.fromJson(data["results"][i]));
          }
          // allChatRoomDetails = dataOrders;
          isChatsLoading = false;
          isUserlogged = true;
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
