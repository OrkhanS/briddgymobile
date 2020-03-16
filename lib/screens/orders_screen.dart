import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:optisend/widgets/filter_panel.dart';
import 'package:optisend/screens/item_screen.dart';
import 'package:optisend/main.dart';
import 'package:optisend/screens/add_item_screen.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter/foundation.dart';
import 'package:dropdown_formfield/dropdown_formfield.dart';
import 'package:provider/provider.dart';

import 'package:optisend/widgets/filter_bar.dart';

import 'package:optisend/providers/ordersandtrips.dart';

class OrdersScreen extends StatefulWidget {
  static const routeName = '/orders';
  OrdersTripsProvider orderstripsProvider;
  var token;
  OrdersScreen({this.orderstripsProvider, this.token});

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
//  var deviceSize = MediaQuery.of(context).size;
  bool expands = false;
  var filterColor = Colors.white;
  var _itemCount = 0;
  // String _startDate = "Starting from";
  // String _endDate = "Untill";
  // String _time = "Not set";
  // String _searchBarFrom = "Anywhere";
  // String _searchBarTo = "Anywhere";
  // String _searchBarWeight = "Any";
  DateTime startDate = DateTime.now();
  String imageUrl;
  bool flagFrom = false;
  bool flagTo = false;
  bool flagWeight = false;
  String from, to;
  String _value = "Sort By";
  String weight, price;
  final formKey = new GlobalKey<FormState>();

  List _suggested = [];
  List _cities = [];
  final TextEditingController _typeAheadController = TextEditingController();
  final TextEditingController _typeAheadController2 = TextEditingController();
  final TextEditingController _typeAheadController3 = TextEditingController();
  final TextEditingController _typeAheadController4 = TextEditingController();

  @override
  void initState() {
    if (widget.orderstripsProvider.myorders.isEmpty) {
      widget.orderstripsProvider.fetchAndSetOrders();
    }

    super.initState();
  }

  String urlFilter = "";
  String _myActivity;
  String _myActivityResult;

  Future sortData(value, OrdersTripsProvider provider) async {
    String url = "http://briddgy.herokuapp.com/api/orders/?order_by=";
    if (urlFilter.isNotEmpty) {
      url = urlFilter + "&order_by=";
    }
    if (value.toString().compareTo("WeightLow") == 0) {
      url = url + "weight";
    } else if (value.toString().compareTo("WeightMax") == 0) {
      url = url + "-weight";
    } else if (value.toString().compareTo("Price") == 0) {
      url = url + "-price";
    } else if (value.toString().compareTo("Ranking") == 0) {
      url = url + "-ranking";
    }
    await http.get(
      url,
      headers: {HttpHeaders.CONTENT_TYPE: "application/json"},
    ).then((response) {
      setState(
        () {
          final dataOrders = json.decode(response.body) as Map<String, dynamic>;
          provider.orders = dataOrders["results"];
          provider.isLoading = false;
        },
      );
    });
  }

  _saveForm() {
    var form = formKey.currentState;
    if (form.validate()) {
      form.save();
      setState(() {
        _myActivityResult = _myActivity;
      });
    }
  }

  @override //todo: check for future
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  FutureOr<Iterable> getSuggestions(String pattern) async {
    String url = "https://briddgy.herokuapp.com/api/cities/?search=" + pattern;
    await http.get(
      url,
      headers: {HttpHeaders.CONTENT_TYPE: "application/json"},
    ).then((response) {
      setState(
        () {
          final dataOrders = json.decode(response.body) as Map<String, dynamic>;
          _suggested = dataOrders["results"];
          // isLoading = false;
        },
      );
    });
    _cities = [];
    for (var i = 0; i < _suggested.length; i++) {
      _cities.add(_suggested[i]["city_ascii"].toString() +
          ", " +
          _suggested[i]["country"].toString() +
          ", " +
          _suggested[i]["id"].toString());
    }
    return _cities;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future filterAndSetOrders(provider, from, to, weight, price) async {
    urlFilter = "http://briddgy.herokuapp.com/api/orders/?";
    if (from != null) {
      urlFilter = urlFilter + "origin=" + from;
      flagFrom = true;
    }
    if (to != null) {
      flagFrom == false
          ? urlFilter = urlFilter + "dest=" + to.toString()
          : urlFilter = urlFilter + "&dest=" + to.toString();
      flagTo = true;
    }
    if (weight != null) {
      flagTo == false && flagFrom == false
          ? urlFilter = urlFilter + "weight=" + weight.toString()
          : urlFilter = urlFilter + "&weight=" + weight.toString();
      flagWeight = true;
    }
    if (price != null) {
      flagWeight == false && flagTo == false && flagFrom == false
          ? urlFilter = urlFilter + "min_price=" + price.toString()
          : urlFilter = urlFilter + "&min_price=" + price.toString();
    }
    await http.get(
      urlFilter,
      headers: {HttpHeaders.CONTENT_TYPE: "application/json"},
    ).then((response) {
      setState(
        () {
          final dataOrders = json.decode(response.body) as Map<String, dynamic>;
          provider.orders = dataOrders["results"];
          provider.isLoading = false;
          // _itemCount = dataOrders["count"];
        },
      );
    });
  }
//    return Form(

  @override
  Widget build(BuildContext context) {
    //print(widget.orderstripsProvider.orders);
    return Consumer<OrdersTripsProvider>(
      builder: (context, orderstripsProvider, child) {
        //print(widget.provider.messages);

        return Scaffold(
          resizeToAvoidBottomPadding: true,
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (__) => AddItemScreen(
                          token: widget.token,
                          orderstripsProvider: widget.orderstripsProvider,
                        )),
              );
            },
          ),
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Center(
              child: Text(
                "Items",
                style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold),
              ),
            ),
            elevation: 1,
          ),
          body: GestureDetector(
            child: SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height * .83,
                child: Column(
                  children: <Widget>[
                    FilterBar(
                        ordersProvider: orderstripsProvider,
                        from: from,
                        to: to,
                        weight: weight,
                        price: price),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              "Results: " +
                                  orderstripsProvider.orders.length.toString(),
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold),
                            ),
                            DropdownButton(
                              hint: Text(_value),
                              items: [
                                DropdownMenuItem(
                                  value: "Ranking",
                                  child: Text(
                                    "Highest Ranking",
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "Price",
                                  child: Text(
                                    "Highest Reward",
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "WeightLow",
                                  child: Text(
                                    "Lowest Weight",
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "WeightMax",
                                  child: Text(
                                    "Highest Weight",
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                sortData(value, orderstripsProvider);
                              },
                            ),
                          ]),
                    ),
                    Expanded(
                      child: orderstripsProvider.notLoadingOrders
                          ? Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemBuilder: (context, int i) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (__) => new ItemScreen(
                                          id: orderstripsProvider.orders[i]
                                              ["id"],
                                          owner: orderstripsProvider.orders[i]
                                              ["owner"],
                                          title: orderstripsProvider.orders[i]
                                              ["title"],
                                          destination: orderstripsProvider
                                              .orders[i]["destination"],
                                          source: orderstripsProvider.orders[i]
                                              ["source"]["city_ascii"],
                                          weight: orderstripsProvider.orders[i]
                                              ["weight"],
                                          price: orderstripsProvider.orders[i]
                                              ["price"],
                                          date: orderstripsProvider.orders[i]
                                              ["date"],
                                          description: orderstripsProvider
                                              .orders[i]["description"],
                                          image: orderstripsProvider.orders[i]
                                              ["orderimage"],
                                          token: widget.token,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 140,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Card(
                                      elevation: 4,
                                      child: Row(
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(15)),
                                              child: Stack(
                                                children: <Widget>[
                                                  Image(
                                                    image: NetworkImage(
                                                        // "https://briddgy.herokuapp.com/media/" + _user["avatarpic"].toString() +"/"
                                                        "https://picsum.photos/250?image=9"), //Todo,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  orderstripsProvider.orders[i]
                                                                  ["title"]
                                                              .toString()
                                                              .length >
                                                          20
                                                      ? orderstripsProvider
                                                              .orders[i]
                                                                  ["title"]
                                                              .toString()
                                                              .substring(
                                                                  0, 20) +
                                                          "..."
                                                      : orderstripsProvider
                                                          .orders[i]["title"]
                                                          .toString(), //Todo: title
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    color: Colors.grey[800],
//                                          fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  children: <Widget>[
                                                    Icon(
                                                      MdiIcons
                                                          .mapMarkerMultipleOutline,
                                                      color: Theme.of(context)
                                                          .primaryColor,
                                                    ),
                                                    Text(
                                                      orderstripsProvider
                                                                      .orders[i]
                                                                  ["source"]
                                                              ["city_ascii"] +
                                                          "  >  " +
                                                          orderstripsProvider
                                                                      .orders[i]
                                                                  [
                                                                  "destination"]
                                                              ["city_ascii"],
                                                      //Todo: Source -> Destination
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          color:
                                                              Colors.grey[600],
                                                          fontWeight: FontWeight
                                                              .normal),
                                                    ),
                                                  ],
                                                ),
                                                Row(
//                                        mainAxisSize: MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: <Widget>[
                                                    Row(
                                                      children: <Widget>[
                                                        Icon(
                                                          MdiIcons
                                                              .calendarRange,
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                        ),
                                                        Text(
                                                          orderstripsProvider
                                                              .orders[i]["date"]
                                                              .toString(),
                                                          //Todo: date
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[600]),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(
                                                      width: 50,
                                                    ),
                                                    Row(
                                                      children: <Widget>[
                                                        Icon(
                                                          Icons.attach_money,
                                                          color:
                                                              Theme.of(context)
                                                                  .primaryColor,
                                                        ),
                                                        Text(
                                                          orderstripsProvider
                                                              .orders[i]
                                                                  ["price"]
                                                              .toString(),
                                                          //Todo: date
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[600]),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              itemCount: orderstripsProvider.orders.length,
                            ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
