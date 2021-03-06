import 'package:flutter/material.dart';
import 'package:briddgy/models/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:briddgy/models/chats.dart';
import 'package:briddgy/models/message.dart';

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
  String contractBody = "";
  bool readMessageText = false;
  bool readMessageRequest = false;
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
          Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
          if (data["results"].isNotEmpty) {
            try {
              // cannot directly add Message object to Map. So need TemporaryList
              List<Message> temp = [];
              for (var i = 0; i < data["results"].length; i++) {
                temp.add(Message.fromJson(data["results"][i]));
              }
              _messages[chats[roomId].id] = {"next": data["next"], "data": temp};
            } catch (e) {
              print(e + "salam");
            }
          } else {
            _messages[chats[roomId].id] = null;
          }

          _isloadingMessages = false;
          notifyListeners();
        });
      } catch (e) {
        print(e + "72");
      }
    }
  }

  bool get messagesLoading {
    return _isloadingMessages;
  }

  set messagesLoading(bool loading) {
    _isloadingMessages = loading;
  }

  Map get newMessages {
    return newMessage;
  }

  addMessages(message, auth) {
    if(Platform.isIOS){
      message = json.decode(message);
    }
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
        bool fetchRoom = true;
        if (_messages[roomid] == null) {
          for (var i = 0; i < chats.length; i++) {
            if (chats[i].id == roomid) {
              fetchRoom = false;
            }
          }
          if (fetchRoom) fetchRoomDetails(roomid, auth);
        }

        _messages[roomid] = {};
        // cannot directly add Message object to Map. So need TemporaryList
        List<Message> temporary = [];
        temporary.add(tempMessage);
        _messages[roomid]["data"] = temporary;
      } else {
        // Checking if FCM sends the same notification twice
        if (_messages[roomid]["data"][0].id != tempMessage.id) {
          _messages[roomid]["data"].insert(0, tempMessage);
        }
      }
      try {
        var c = json.decode(tempMessage.text) as Map<String, dynamic>;
        for (var i = 0; i < chats.length; i++) {
          if (chats[i].id == roomid) {
            chats[i].lastMessage = "Contract";
          }
        }
      }catch (e) {
        for (var i = 0; i < chats.length; i++) {
          if (chats[i].id == roomid) {
            chats[i].lastMessage = tempMessage.text;
          }
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
        if (newMessage[roomid] == null || newMessage[roomid] == 0) {
          // cannot directly add Message object to Map. So need TemporaryList
          newMessage.putIfAbsent(roomid, () => null);
          newMessage[roomid] = 1;
          notifyListeners();
        } else {
          // Checking if FCM sends the same notification twice
          if (_messages[roomid]["data"][0].id == tempMessage.id) {
            newMessage[roomid] = newMessage[roomid] + 1;
            notifyListeners();
          }
        }
        // if (isChatRoomPageActive) {
        //   if (!roomIDsWhileChatRoomActive.contains(roomid)) roomIDsWhileChatRoomActive.add(roomid);
        // } else {
          
        // }
      }
      else{ readMessageRequest = true; notifyListeners();}
      changeChatRoomPlace(roomid);
      notifyListeners();
    }
    
  }

  Map get messages => _messages;

  void readMessages(id) {
    roomIDofActiveChatroom = id;
    if (newMessage[id] != null) newMessage.remove(id);
    notifyListeners();
  }

  bool get arethereNewMessage {
    var key = newMessage.keys.firstWhere((k) => newMessage[k] != 0, orElse: () => null);
    if (key != null) {
      return true;
    } else {
      return false;
    }
  }

  //______________________________________________CHATS________________________________________

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
          fetchAndSetRooms(auth, false);
        } else {
          isChatRoomCreated = false;
        }
        notifyListeners();
      });
    }
  }

  userReadMessage(auth,data){
      for (var i = 0; i < chats.length; i++) {
        if (chats[i].id == data["room_id"]) {
          if(auth.user.id == chats[i].unread1[1])chats[i].unread2[0] = 0;
          else chats[i].unread1[0] = 0;
          notifyListeners();
        }
    }
  }

  changeChatRoomPlace(id) {
    if (id == "ChangewithList") {
      for (var i = 0; i < roomIDsWhileChatRoomActive.length; i++) {
        for (var j = 0; j < chats.length; j++) {
          if (chats[j].id.toString() == roomIDsWhileChatRoomActive[i].toString()) {
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
    notifyListeners();
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
        Map<String, dynamic> data = json.decode(value.body) as Map<String, dynamic>;
        chats.insert(0, Chats.fromJson(data));
        if (!isChatRoomPageActive) notifyListeners();
      }
    });
  }

  Future fetchAndSetRooms(auth, isNewMessage) async {
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
        final extractedUserData = json.decode(prefs.getString('userData')) as Map<String, Object>;

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
          Map<String, dynamic> data = json.decode(value.body) as Map<String, dynamic>;
          _chatRooms = [];
          for (var i = 0; i < data["results"].length; i++) {
            _chatRooms.add(Chats.fromJson(data["results"][i]));
            if(_chatRooms[i].unread1[1] == auth.user.id){
              if(_chatRooms[i].unread1[0]!=0){
                newMessage.putIfAbsent(_chatRooms[i].id, () => null);
                newMessage[_chatRooms[i].id] = _chatRooms[i].unread1[0];
              }

            }else{
              if(_chatRooms[i].unread2[0]!=0){
                newMessage.putIfAbsent(_chatRooms[i].id, () => null);
                newMessage[_chatRooms[i].id] = _chatRooms[i].unread2[0];
              }
            }
          }
          allChatRoomDetails = {"next": data["next"], "count": data["count"]};
          isChatsLoading = false;
          isChatsLoadingForMain = false;

          if (!isChatRoomPageActive) notifyListeners();
        });
        return _chatRooms;
      } catch (e) {
        print(e);
        return;
      }
  }


  changeLastMessage(id,text,auth){
    for (var i = 0; i < chats.length; i++) {
      if (chats[i].id == id) {
        chats[i].lastMessage = text;
        if(auth.user.id == chats[i].unread1[1])chats[i].unread2[0] = 1;
        else chats[i].unread1[0] = 1;
        chats.insert(0, chats.removeAt(i));
        notifyListeners();
      }
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


//________________________________________________CONTRACTS________________________________________________

  Future createContract(id, auth) async {
    String token = auth.myTokenFromStorage;
    if (token != null) {
      String url = Api.contracts;
      await http.get(
        url,
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          "Authorization": "Token " + token,
        },
      ).then((value) {
        if (value.statusCode == 200) {
          isChatsLoading = true;
          isChatRoomCreated = true;
          _chatRooms = [];
          fetchAndSetRooms(auth, false);
        } else {
          isChatRoomCreated = false;
        }
        notifyListeners();
      });
    }
  }

  removeAllDataOfProvider() {
    roomIDsWhileChatRoomActive = [];
    roomIDofActiveChatRoom = " ";
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
    isChatsLoadingForMain = true;
    lastMessageID = [];
    userdetail = {};
    allChatRoomDetails = {};
    isChatRoomCreated = false;
    isChatRoomPageActive = false;
    notifyListeners();
  }
}
