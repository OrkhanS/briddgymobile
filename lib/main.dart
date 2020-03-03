import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:optisend/screens/add_item_screen.dart';
import 'package:optisend/screens/add_trip_screen.dart';
import 'package:optisend/screens/my_trips.dart';
import 'package:optisend/screens/trip_screen.dart';
import 'package:provider/provider.dart';

import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import './screens/splash_screen.dart';
import './screens/cart_screen.dart';
import './screens/products_overview_screen.dart';
import './screens/product_detail_screen.dart';
import './providers/products.dart';
import './providers/cart.dart';
import './providers/auth.dart';
import './screens/orders_screen.dart';
import './screens/user_products_screen.dart';
import './screens/edit_product_screen.dart';
import './screens/auth_screen.dart';
import 'package:flutter/foundation.dart';

import './screens/account_screen.dart';
import './screens/notification_screen.dart';
import './screens/chats_screen.dart';
import './screens/chat_window.dart';
import 'package:optisend/screens/profile_screen.dart';
import 'package:optisend/screens/item_screen.dart';

import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:optisend/web_sockets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:optisend/providers/messages.dart';
import 'package:optisend/providers/orders.dart';
import 'package:optisend/screens/my_items.dart';
import 'package:optisend/screens/contracts.dart';
import 'package:background_fetch/background_fetch.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:optisend/local_notications_helper.dart';

/// This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask(String taskId) async {
  print('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish(taskId);
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  final StreamController<String> streamController =
      StreamController<String>.broadcast();
  IOWebSocketChannel _channel;
  ObserverList<Function> _listeners = new ObserverList<Function>();

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final notifications = FlutterLocalNotificationsPlugin();

  List<dynamic> _rooms;
  bool _isOn = false;
  bool _loggedIn = true;
  List<dynamic> _messages = [];
  List<dynamic> _mesaj = [];
  int _currentIndex = 1;
  PageController _pageController;
  bool _enabled = true;
  int _status = 0;
  List<DateTime> _events = [];
  @override
  void initState() {
    _currentIndex = 1;
    super.initState();
    _pageController = PageController(initialPage: 1);
    initPlatformState();
    initCommunication();
    fetchAndSetRooms();
    final settingsAndroid = AndroidInitializationSettings('app_icon');
    final settingsIOS = IOSInitializationSettings(
        onDidReceiveLocalNotification: (id, title, body, payload) =>
            onSelectNotification(payload));

    notifications.initialize(
        InitializationSettings(settingsAndroid, settingsIOS),
        onSelectNotification: onSelectNotification);
  }
  Future onSelectNotification(String payload) async => await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OrdersScreen()),
      );

  Future<void> initPlatformState() async {
    // Configure BackgroundFetch.
    BackgroundFetch.configure(
        BackgroundFetchConfig(
            minimumFetchInterval: 15,
            stopOnTerminate: false,
            enableHeadless: true,
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresStorageNotLow: false,
            requiresDeviceIdle: false,
            requiredNetworkType: NetworkType.NONE), (String taskId) async {
      // This is the fetch-event callback.
      print("[BackgroundFetch] Event received $taskId");
      setState(() {
        List temp = [];
        fetchAndSetRooms().then((onValue) {
          print(onValue);
        });
        _events.insert(0, new DateTime.now());
      });
      // IMPORTANT:  You must signal completion of your task or the OS can punish your app
      // for taking too long in the background.
      BackgroundFetch.finish(taskId);
    }).then((int status) {
      print('[BackgroundFetch] configure success: $status');
      setState(() {
        _status = status;
      });
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
      setState(() {
        _status = e;
      });
    });

    // Optionally query the current BackgroundFetch status.
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    } else {
      BackgroundFetch.stop().then((int status) {
        print('[BackgroundFetch] stop success: $status');
      });
    }
  }

  void _onClickStatus() async {
    int status = await BackgroundFetch.status;
    print('[BackgroundFetch] status: $status');
    setState(() {
      _status = status;
    });
  }

  /// ----------------------------------------------------------
  /// Fetch Rooms Of User
  /// ----------------------------------------------------------
  Future fetchAndSetRooms() async {
    // if(Provider.of<Orders>(context, listen: true).notLoaded){
    //   print("Still loading");
    // }
    // else{
    //   print("ALready Loaded");
    //   print(Provider.of<Orders>(context, listen:false).orders);
    // }

    var token = "40694c366ab5935e997a1002fddc152c9566de90";

    // if(Provider.of<Auth>(context, listen: false).isAuth){
    //   token =  Provider.of<Auth>(context, listen: false).token;
    // }
    // else{
    //   _loggedIn = false;
    //   return 0;
    // }

    const url = "http://briddgy.herokuapp.com/api/chats/";
    final response = await http.get(
      url,
      headers: {
        HttpHeaders.CONTENT_TYPE: "application/json",
        "Authorization": "Token " + token,
      },
    );
    if (this.mounted) {
      setState(() {
        final dataOrders = json.decode(response.body) as Map<String, dynamic>;
        _rooms = dataOrders["results"];
      });
    }
    return _rooms;
  }

  /// ----------------------------------------------------------
  /// End Fetching Rooms Of User
  /// ----------------------------------------------------------

  initCommunication() async {
    reset();
    try {
      widget._channel = new IOWebSocketChannel.connect(
          'ws://briddgy.herokuapp.com/ws/alert/?token=40694c366ab5935e997a1002fddc152c9566de90'); //todo
      widget._channel.stream.listen(_onReceptionOfMessageFromServer);
      showOngoingNotification(notifications,
                  title: 'Briddgy', body: 'You have a new message!');
      print("Alert Connected");
    } catch (e) {
      print("Error Occured");
      reset();
    }
  }

  /// ----------------------------------------------------------
  /// Closes the WebSocket communication
  /// ----------------------------------------------------------
  reset() {
    if (widget._channel != null) {
      if (widget._channel.sink != null) {
        widget._channel.sink.close();
        _isOn = false;
      }
    }
  }

  /// ---------------------------------------------------------
  /// Adds a callback to be invoked in case of incoming
  /// notification
  /// ---------------------------------------------------------
  addListener(Function callback) {
    widget._listeners.add(callback);
  }

  removeListener(Function callback) {
    widget._listeners.remove(callback);
  }

  /// ----------------------------------------------------------
  /// Callback which is invoked each time that we are receiving
  /// a message from the server
  /// ----------------------------------------------------------
  _onReceptionOfMessageFromServer(message) {
    showOngoingNotification(notifications,
                  title: 'Briddgy', body: 'You have a new message!');
    //_mesaj = [];
    //_mesaj.add(json.decode(message));
    // if(_mesaj[0]["id"]){
    // Check if "ID" of image sent before, then check its room ID, search in _room and get message ID and use
    // it in Message Provider, find message, then add the mesaj into that
    // }

    //Here Call a function to notify user that he has a message

    _isOn = true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget navbar() {
    return BottomNavigationBar(
      elevation: 4,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: Colors.blue[900],
      unselectedItemColor: Colors.grey[400],
      unselectedFontSize: 9,
      selectedFontSize: 11,
      onTap: (index) {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(index,
            duration: Duration(milliseconds: 200), curve: Curves.ease);
      },
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
            title: Text('Items'),
            icon: Icon(MdiIcons.packageVariantClosed),
            activeIcon: Icon(MdiIcons.packageVariant)),
        BottomNavigationBarItem(
          title: Text('Trips'),
          icon: Icon(MdiIcons.roadVariant),
          activeIcon: Icon(MdiIcons.road),
        ),
        BottomNavigationBarItem(
          title: Text('Chats'),
          icon: Icon(MdiIcons.forumOutline),
          activeIcon: Icon(MdiIcons.forum),
        ),
        BottomNavigationBarItem(
          title: Text('Notifications'),
          icon: Icon(Icons.notifications_none),
          activeIcon: Icon(Icons.notifications),
        ),
        BottomNavigationBarItem(
          title: Text('Account'),
          icon: Icon(MdiIcons.accountSettingsOutline),
          activeIcon: Icon(MdiIcons.accountSettings),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print("main build");
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: Auth(),
        ),

        ChangeNotifierProvider.value(
          value: Orders(),
        ),

        // ChangeNotifierProvider.value(
        //   value: Messages(),
        // ),
        // ChangeNotifierProxyProvider<Auth, Products>(
        //   builder: (ctx, auth, previousProducts) => Products(
        //     auth.token,
        //     auth.userId,
        //     previousProducts == null ? [] : previousProducts.items,
        //   ),
        // ),
        // ChangeNotifierProvider.value(
        //   value: Cart(),
        // ),
//        ChangeNotifierProxyProvider<Auth, Orders>(
//          builder: (ctx, auth, previousOrders) => Orders(
//            auth.token,
//            auth.userId,
//            previousOrders == null ? [] : previousOrders.orders,
//          ),
//        ),
      ],
      child: Consumer<Auth>(builder: (ctx, auth, _) {
        return MaterialApp(
          title: 'Optisend',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            primaryColor: Colors.blue[900],
            accentColor: Colors.indigoAccent,
            fontFamily: 'Lato',
          ),
          home: Scaffold(
            body: SizedBox.expand(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                children: <Widget>[
                  OrdersScreen(),
                  TripsScreen(),
                  ChatsScreen(rooms: _loggedIn == true ? _rooms : 0),
                  NotificationScreen(),
                  DetailsScreen(),
                ],
              ),
            ),
            bottomNavigationBar: navbar(),
          ),
          routes: {
            ProductDetailScreen.routeName: (ctx) => ProductDetailScreen(),
            CartScreen.routeName: (ctx) => CartScreen(),
            OrdersScreen.routeName: (ctx) => OrdersScreen(),
            TripsScreen.routeName: (ctx) => TripsScreen(),
            UserProductsScreen.routeName: (ctx) => UserProductsScreen(),
            EditProductScreen.routeName: (ctx) => EditProductScreen(),
            ChatWindow.routeName: (ctx) => ChatWindow(),
            ItemScreen.routeName: (ctx) => ItemScreen(),
            AddItemScreen.routeName: (ctx) => AddItemScreen(),
            AddTripScreen.routeName: (ctx) => AddTripScreen(),
            ProfileScreen.routeName: (ctx) => ProfileScreen(),
            MyItems.routeName: (ctx) => MyItems(),
            MyTrips.routeName: (ctx) => MyTrips(),
            Contracts.routeName: (ctx) => Contracts(),
          },
        );
      }),
    );
  }
}
