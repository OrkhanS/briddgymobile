import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:briddgy/models/review.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:briddgy/models/api.dart';
import 'package:briddgy/models/user.dart';
import 'package:briddgy/providers/messages.dart';
import 'package:briddgy/providers/ordersandtrips.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/http_exception.dart';

class Auth with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  var user;
  bool isLoadingUserForMain = true;
  bool isLoadingUserDetails = true;
  String myTokenFromStorage;
  List _reviews = [];
  List _stats = [];
  bool statsNotReady = true;
  bool statsNotReadyForProfile = true;
  bool reviewsNotReady = true;
  bool reviewsloading = true;
  bool verificationStatus = false;
  bool passwordResetStatus = false;
  String deviceToken;
  Map reviewDetail = {};

  String get myToken {
    return myTokenFromStorage;
  }

  set myToken(string) {
    myTokenFromStorage = string;
  }

  bool get isNotLoadingUserDetails {
    return isLoadingUserDetails;
  }

  List get reviews => _reviews;
  List get stats => _stats;
  set reviews(reviews) {
    _reviews = reviews;
  }

  bool get isAuth {
    return _token != null;
  }

  String get token => _token;

  set token(String tokenlox) {
    _token = tokenlox;
  }

  String get userId {
    return _userId;
  }

  get userdetail {
    return user;
  }

  bool get isNotLoading {
    return isLoadingUserForMain;
  }

  changeUserAvatar(url) {
    user.avatarpic = url;
    notifyListeners();
  }

  Future fetchAndSetStatistics() async {
    const url = Api.myStats;
    if (_token != null) {
      statsNotReady = false;
      final response = await http.get(
        url,
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          "Authorization": "Token " + _token,
        },
      );

      final dataOrders = json.decode(response.body) as Map<String, dynamic>;
      _stats = dataOrders["results"];
      statsNotReadyForProfile = false;
      notifyListeners();
    }
  }

  notifyAuth() {
    notifyListeners();
  }

  Future fetchAndSetReviews(url) async {
    reviewsNotReady = false;
    final response = await http.get(
      url,
      headers: isAuth
          ? {
              HttpHeaders.contentTypeHeader: "application/json",
              "Authorization": "Token " + token,
            }
          : {
              HttpHeaders.contentTypeHeader: "application/json",
            },
    );
    _reviews = [];
    final data = json.decode(response.body) as Map<String, dynamic>;
    for (var i = 0; i < data["results"].length; i++) {
      _reviews.add(Review.fromJson(data["results"][i]));
    }
    reviewDetail = {"next": data["next"], "count": data["count"]};
    reviewsloading = false;
    notifyListeners();
  }

  Future fetchAndSetUserDetails() async {
    const url = Api.currentUserDetails;
    try {
      final response = await http.get(
        url,
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          "Authorization": "Token " + myTokenFromStorage,
        },
      ).then((response) {
        Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        user = User.fromJson(data);
        isLoadingUserForMain = false;
        isLoadingUserDetails = false;
        notifyListeners();
      });
    } catch (e) {
      print(e);
      return;
    }
  }

  Future<void> _authenticate(String email, String password, String urlSegment) async {
    const url = "http://briddgy.herokuapp.com/api/auth/";
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'email': email,
            'password': password,
            'returnSecureToken': true,
          },
        ),
      );
      final responseData = json.decode(response.body);
      if (responseData['error'] != null) {
        throw HttpException(responseData['error']['message']);
      }
      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(
        {
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate.toIso8601String(),
        },
      );
      prefs.setString('userData', userData);
    } catch (error) {
      throw error;
    }
  }

  Future<bool> requestPasswordReset(email) async {
    const url = Api.forgetPassword;
    await http
        .post(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      },
      body: json.encode(
        {
          'email': email,
        },
      ),
    )
        .then((response) {
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Requested");
        passwordResetStatus = true;
        return true;
      } else {
        print("Failed to send email");
        return false;
      }
    });
  }

  Future<bool> requestEmailVerification() async {
    const url = Api.requestEmailVerification;
    await http.get(url, headers: {
      HttpHeaders.contentTypeHeader: "application/json",
      "Authorization": "Token " + myTokenFromStorage,
    }).then((response) {
      if (response.statusCode == 200) {
        print("Requested");
        verificationStatus = false;
        return true;
      } else {
        print("Failed to send email");
        return false;
      }
    });
  }

  Future<bool> verifyEmailCode(key) async {
    const url = Api.verifyEmail;
    await http
        .post(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        "Authorization": "Token " + myTokenFromStorage,
      },
      body: json.encode(
        {
          'key': key,
        },
      ),
    )
        .then((response) {
      if (response.statusCode == 200) {
        print("Success");
        verificationStatus = true;
        fetchAndSetUserDetails();
        return true;
      } else {
        print("Incorrect Confirmation Key");
        return false;
      }
    });
  }

  Future<void> signup(String email, String password, String firstname, String lastname, String deviceID) async {
    const url = Api.signUp;
    try {
      final response = await http.post(
        url,
        headers: {HttpHeaders.contentTypeHeader: "application/json"},
        body: json.encode(
          {
            'email': email,
            'password': password,
            'password2': password,
            'first_name': firstname,
            'last_name': lastname,
            'deviceToken': deviceID,
          },
        ),
      );
      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        _token = responseData["token"];
        myToken = responseData["token"];
        myTokenFromStorage = responseData["token"];
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        final userData = json.encode(
          {
            'token': _token,
          },
        );
        prefs.setString('userData', userData);
        verificationStatus = false;
        requestEmailVerification();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> login(String email, String password, String deviceID, context) async {
    const url = Api.login;
    deviceToken = deviceID;
    try {
      final response = await http.post(
        url,
        headers: {HttpHeaders.contentTypeHeader: "application/json"},
        body: json.encode(
          {
            'username': email,
            'password': password,
            'deviceToken': deviceID,
          },
        ),
      );
      final responseData = json.decode(response.body);
      Provider.of<OrdersTripsProvider>(context, listen: false).removeAllDataOfProvider();
      Provider.of<Messages>(context, listen: false).removeAllDataOfProvider();
      removeAllDataOfProvider();
      _token = responseData;
      myToken = responseData;
      myTokenFromStorage = responseData;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(
        {
          'token': _token,
        },
      );
      prefs.setString('userData', userData);
      // print(prefs.get("userData"));
      fetchAndSetUserDetails();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      // print("no user data in shared preference");

      return false;
    }
    final extractedUserData = json.decode(prefs.getString('userData')) as Map<String, Object>;
    // print(prefs.getString('userData'));
    _token = extractedUserData['token'];
    myToken = extractedUserData['token'];
    myTokenFromStorage = extractedUserData['token'];
    fetchAndSetUserDetails();
    notifyListeners();
    return true;
  }

  Future<void> logout(context) async {
    const url = Api.login;
    http.patch(url,
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          "Authorization": "Token " + _token,
        },
        body: json.encode({"token": _token}));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');

    prefs.commit();
    prefs.clear();
    Provider.of<OrdersTripsProvider>(context, listen: false).removeAllDataOfProvider();
    Provider.of<Messages>(context, listen: false).removeAllDataOfProvider();
    removeAllDataOfProvider();
    notifyListeners();
  }

  removeAllDataOfProvider() {
    _expiryDate = null;
    _userId = null;
    _token = null;
    user = null;
    isLoadingUserForMain = true;
    isLoadingUserDetails = true;
    myTokenFromStorage = null;
    _reviews = [];
    _stats = [];
    statsNotReady = true;
    reviewsNotReady = true;
    notifyListeners();
  }
}
