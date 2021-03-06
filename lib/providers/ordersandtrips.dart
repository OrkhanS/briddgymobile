import 'package:briddgy/providers/auth.dart';
import 'package:flutter/material.dart';
import 'package:briddgy/models/api.dart';
import 'package:briddgy/models/order.dart';
import 'package:briddgy/models/trip.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class OrdersTripsProvider with ChangeNotifier {
  List _orders = [];
  List _myorders = [];
  List _trips = [];
  List _mytrips = [];
  bool isLoadingOrders = true;
  bool isLoadingTrips = true;
  bool loadedMyOrders = true;
  bool loadedMyTrips = true;
  String token;
  Map allTripsDetails = {};
  Map allOrdersDetails = {};
  Map allMyOrderDetails = {};
  Map allMyTripsDetails = {};
  bool filtering = false;

  List get orders {
    return _orders;
  }

  List get myorders {
    return _myorders;
  }

  Map get detailsOrder {
    return allOrdersDetails;
  }

  Map get detailsMyOrder {
    return allMyOrderDetails;
  }

  set startLoading(trueFalse) {
    isLoadingOrders = trueFalse;
    notifyListeners();
  }

  set orders(List temporders) {
    _orders = [];
    allOrdersDetails = {};
    _orders = temporders;
    notifyListeners();
  }

  set myorders(List temporders) {
    _myorders = temporders;
    notifyListeners();
  }

  notify() {
    notifyListeners();
  }

  Future fetchAndSetOrders() async {
    String url = Api.orders + "?order_by=-date";
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('userData')) {
      final extractedUserData = json.decode(prefs.getString('userData')) as Map<String, Object>;
      token = extractedUserData['token'];
    }
    http
        .get(
      url,
      headers: prefs.containsKey('userData')
          ? {
              HttpHeaders.contentTypeHeader: "application/json",
              "Authorization": "Token " + token,
            }
          : {
              HttpHeaders.contentTypeHeader: "application/json",
            },
    )
        .then((onValue) {
      orders = [];
      allOrdersDetails = {};
      Map<String, dynamic> data = json.decode(onValue.body) as Map<String, dynamic>;
      for (var i = 0; i < data["results"].length; i++) {
        orders.add(Order.fromJson(data["results"][i]));
      }
      allOrdersDetails = {"next": data["next"], "count": data["count"]};
      isLoadingOrders = false;
      notifyListeners();
    });
  }

  Future fetchAndSetMyOrders(myToken) async {
    var token = myToken;
    const url = Api.myOrders;
    http.get(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        "Authorization": "Token " + token,
      },
    ).then((onValue) {
      Map<String, dynamic> data = json.decode(onValue.body) as Map<String, dynamic>;
      myorders = [];
      for (var i = 0; i < data["results"].length; i++) {
        myorders.add(Order.fromJson(data["results"][i]));
      }
      allMyOrderDetails = {"next": data["next"], "count": data["count"]};
      loadedMyOrders = false;
      notifyListeners();
    });
  }
  //

  Future<List> loadOrders(int id) async {
    List<Order> orders = [];
    final url = Api.orderById + id.toString() + "/orders/";
    http.get(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      },
    ).then((onValue) {
      Map<String, dynamic> data = json.decode(onValue.body) as Map<String, dynamic>;

      for (var i = 0; i < data["results"].length; i++) {
        orders.add(Order.fromJson(data["results"][i]));
      }
    });
    return orders;
  }

  Future<List> loadTrips(int id) async {
    List<Trip> trips = [];
    final url = Api.orderById + id.toString() + "/trips/";
    http.get(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      },
    ).then((onValue) {
      Map<String, dynamic> data = json.decode(onValue.body) as Map<String, dynamic>;

      for (var i = 0; i < data["results"].length; i++) {
        trips.add(Trip.fromJson(data["results"][i]));
      }
    });
    return trips;
  }

  //_________________________________________________________TRIPS__________________________________________________________
  set trips(List temptrips) {
    _trips = temptrips;
    notifyListeners();
  }

  List get trips {
    return _trips;
  }

  List get mytrips {
    return _mytrips;
  }

  Map get detailsTrip {
    return allTripsDetails;
  }

  Map get detailsMyTrip {
    return allMyTripsDetails;
  }

  set mytrips(List temporders) {
    _mytrips = temporders;
    notifyListeners();
  }

  Future fetchAndSetTrips() async {
    const url = Api.trips + "?order_by=date";
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('userData')) {
      final extractedUserData = json.decode(prefs.getString('userData')) as Map<String, Object>;
      token = extractedUserData['token'];
    }
    http
        .get(
      url,
      headers: prefs.containsKey('userData')
          ? {
              HttpHeaders.contentTypeHeader: "application/json",
              "Authorization": "Token " + token,
            }
          : {
              HttpHeaders.contentTypeHeader: "application/json",
            },
    )
        .then(
      (response) {
        Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        trips = [];
        for (var i = 0; i < data["results"].length; i++) {
          trips.add(Trip.fromJson(data["results"][i]));
        }
        isLoadingTrips = false;
        allTripsDetails = {"next": data["next"], "count": data["count"]};
        notifyListeners();
      },
    );
  }

  Future fetchAndSetMyTrips(myToken) async {
    var token = myToken;
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('userData')) {
        return false;
      }
      token = json.decode(prefs.getString('userData')) as Map<String, Object>;
    }
    const url = Api.myTrips;
    http.get(
      url,
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        "Authorization": "Token " + token,
      },
    ).then((onValue) {
      Map<String, dynamic> data = json.decode(onValue.body) as Map<String, dynamic>;
      mytrips = [];
      for (var i = 0; i < data["results"].length; i++) mytrips.add(Trip.fromJson(data["results"][i]));

      allMyTripsDetails = {"next": data["next"], "count": data["count"]};
      loadedMyTrips = false;
      notifyListeners();
    });
  }

  removeAllDataOfProvider() {
    _orders = [];
    _myorders = [];
    _trips = [];
    _mytrips = [];
    isLoadingOrders = true;
    isLoadingTrips = true;
    loadedMyOrders = true;
    token = null;
    allTripsDetails = {};
    allOrdersDetails = {};
    allMyOrderDetails = {};
    allMyTripsDetails = {};
    notifyListeners();
  }

  Future<http.Response> deleteOrder(BuildContext context, Order order) async {
    myorders.remove(order);

    final http.Response response = await http.delete(
      Api.orders + order.id.toString() + '/',
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        "Authorization": "Token " + Provider.of<Auth>(context, listen: false).myTokenFromStorage,
      },
    );
    if (response.statusCode != 204) mytrips.add(order);
    notifyListeners();
    return response;
  }

  Future<http.Response> deleteTrip(BuildContext context, Trip trip) async {
    mytrips.remove(trip);
    final http.Response response = await http.delete(
      Api.trips + trip.id.toString() + '/',
      headers: {
        HttpHeaders.contentTypeHeader: "application/json",
        "Authorization": "Token " + Provider.of<Auth>(context, listen: false).myTokenFromStorage,
      },
    );
    if (response.statusCode != 204) mytrips.add(trip);

    notifyListeners();
    return response;
  }
}

Future<List<Order>> fetchOrderSuggestions(String source, String dest, BuildContext context) async {
  List<Order> _orders = [];
  final response = await http.get(Api.orders + "?origin=" + source + "&dest=" + dest, headers: {
    HttpHeaders.contentTypeHeader: "application/json",
    if (Provider.of<Auth>(context, listen: false).isAuth) "Authorization": "Token " + Provider.of<Auth>(context, listen: false).myTokenFromStorage
  });

  if (response.statusCode == 200) {
    Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
    for (var i = 0; i < data["results"].length; i++) {
      _orders.add(Order.fromJson(data["results"][i]));
    }

    return _orders;
  } else {
    throw Exception('Failed to load order Suggestions');
  }
}

Future<List<Trip>> fetchTripSuggestions(String source, String dest, BuildContext context) async {
  List<Trip> trips = [];
//  Trip trip;
//  Order order;
//  if (object is Trip)
//    trip = object;
//  else
//    order = object;
//
//  String origin, dest;

  final response = await http.get(Api.trips + "?origin=" + source + "&dest=" + dest, headers: {
    HttpHeaders.contentTypeHeader: "application/json",
    if (Provider.of<Auth>(context, listen: false).isAuth) "Authorization": "Token " + Provider.of<Auth>(context, listen: false).myTokenFromStorage
  });

  if (response.statusCode == 200) {
    Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
    for (var i = 0; i < data["results"].length; i++) {
      trips.add(Trip.fromJson(data["results"][i]));
    }

    return trips;
  } else {
    throw Exception('Failed to load trip Suggestions');
  }
}
