import 'dart:async';
import 'dart:io';
import 'package:briddgy/widgets/progress_indicator_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:briddgy/screens/add_order_screen.dart';
import 'package:briddgy/screens/add_trip_screen.dart';
import 'package:briddgy/screens/auth_screen.dart';
import 'package:briddgy/screens/my_trips_screen.dart';
import 'package:briddgy/screens/trips_screen.dart';
import 'package:persistent_bottom_nav_bar/persistent-tab-view.dart';
import 'package:provider/provider.dart';
import './providers/auth.dart';
import './screens/orders_screen.dart';
import 'package:flutter/foundation.dart';
import './screens/account_screen.dart';
import './screens/notification_screen.dart';
import './screens/chats_screen.dart';
import './screens/chat_window.dart';
import 'package:briddgy/screens/profile_screen.dart';
import 'package:briddgy/screens/order_screen.dart';
//import 'package:flutter_facebook_login/flutter_facebook_login.dart';
import 'package:web_socket_channel/io.dart';
import 'package:briddgy/providers/messages.dart';
import 'package:briddgy/providers/ordersandtrips.dart';
import 'package:briddgy/screens/my_orders_screen.dart';
import 'package:briddgy/screens/contracts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:badges/badges.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/demo_localization.dart';
import 'localization/localization_constants.dart';
import 'models/api.dart';

void main() {
  SharedPreferences.setMockInitialValues({});
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  final StreamController<String> streamController = StreamController<String>.broadcast();
  IOWebSocketChannel _channel;
  ObserverList<Function> _listeners = new ObserverList<Function>();
  final Widget button = ChatsScreen();
  static void setLocale(BuildContext context, Locale locale) {
    _MyAppState state = context.findAncestorStateOfType<_MyAppState>();
    state.setLocale(locale);
  }

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  final notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  bool _isOn = false;
  PageController _pageController;
  String tokenforROOM;
  Map valueMessages = {};
  bool socketConnected = false;
  bool socketConnectedFirebase = false;
  var neWMessage;
  var authProvider, messageProvider;
  IOWebSocketChannel alertChannel;

  Locale _locale;
  SharedPreferences sharedPreferences;



  PersistentTabController _controller = PersistentTabController(initialIndex: 0);

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }


  @override
  void initState() {
    _currentIndex = 0;
    super.initState();
    getToken();
    _pageController = PageController(initialPage: 0);
    // SharedPreferences.getInstance().then((SharedPreferences sp) {
    //   sharedPreferences = sp;
    //   // _testValue = sharedPreferences.getBool(spKey);
    //   // // will be null if never previously saved
    //   print("sp:");
    //   print(sharedPreferences.getString("authData"));
    //   setState(() {});
    // });
  }
   _configureFirebaseListerners() async {
    socketConnectedFirebase = true;
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        if(Platform.isIOS){
          neWMessage.addMessages(json.encode(message), authProvider);
        }
        else{
           neWMessage.addMessages(message.values.last, authProvider);
        }
      },
      onLaunch: (Map<String, dynamic> message) async {
        if(Platform.isIOS){
          neWMessage.addMessages(json.encode(message), authProvider);
        }
        else{
          neWMessage.addMessages(message.values.last, authProvider);
        }
        setState(() {
          _controller.index = 2;
        });
      },
      onBackgroundMessage: null,
      onResume: (Map<String, dynamic> message) async {
        if(Platform.isIOS){
          neWMessage.addMessages(json.encode(message), authProvider);
        }
        else{
          neWMessage.addMessages(message.values.last, authProvider);
        }
        setState(() {
          _controller.index = 2;
        });
      },
    );
    _firebaseMessaging.requestNotificationPermissions(const IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered.listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
  }

  Future getToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData = json.decode(prefs.getString('userData')) as Map<String, Object>;
    tokenforROOM = extractedUserData['token'];
  }

  Future onSelectNotification(String payload) async => await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatsScreen()),
      );

  Future initCommunication(auth, newmessage) async {
    if (socketConnected == false) {
      reset();
      try {
        var f, d;
        auth.removeListener(f);
        newmessage.removeListener(d);
        neWMessage = newmessage;
        final prefs = await SharedPreferences.getInstance();
        if (!prefs.containsKey('userData')) {
          return false;
        }
        final extractedUserData = json.decode(prefs.getString('userData')) as Map<String, Object>;

        auth.token = extractedUserData['token'];

        if (extractedUserData['token'] != null) {
          alertChannel = new IOWebSocketChannel.connect(Api.alertSocket + auth.user.id.toString() + "/?token=" + auth.token.toString());
          alertChannel.stream.listen(_onReceptionOfMessageFromServer).onDone(() {
            reset();
            initCommunication(authProvider, messageProvider);
          });
          socketConnected = true;
        }
      } catch (e) {
        print(e);
        reset();
      }
    } else {
      return;
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
    try {
      message = json.decode(message);
      if (message["type"] == "ReadMessage") messageProvider.userReadMessage(authProvider, message);
    } catch (e) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget navbar(newmessage) {
    return BottomNavigationBar(
      elevation: 4,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      selectedItemColor: Colors.teal[700],
      unselectedItemColor: Colors.grey[500],
      unselectedFontSize: 9,
      selectedFontSize: 11,
      onTap: (index) {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(index, duration: Duration(milliseconds: 200), curve: Curves.ease);
      },
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(title: Text('Orders'), icon: Icon(MdiIcons.packageVariantClosed), activeIcon: Icon(MdiIcons.packageVariant)),
        BottomNavigationBarItem(
          title: Text('Trips'),
          icon: Icon(MdiIcons.roadVariant),
          activeIcon: Icon(MdiIcons.road),
        ),
        BottomNavigationBarItem(
          title: Text('Chats'),
          icon: newmessage.arethereNewMessage == true
              ? Badge(
                  badgeColor: Colors.green,
                  badgeContent: Text(
                    newmessage.newMessages.length.toString(),
                    style: TextStyle(color: Colors.white),
                  ),
                  child: Icon(MdiIcons.forumOutline),
                )
              : Icon(MdiIcons.forumOutline),
          activeIcon: Icon(MdiIcons.forum),
        ),
//        BottomNavigationBarItem(
//          title: Text('Notifications'),
//          icon: Icon(Icons.notifications_none),
//          activeIcon: Icon(Icons.notifications),
//        ),
        BottomNavigationBarItem(
          title: Text('Profile'),
          icon: Icon(MdiIcons.accountSettingsOutline),
          activeIcon: Icon(MdiIcons.accountSettings),
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    getLocale().then((locale) {
      setState(() {
        this._locale = locale;
      });
    });
    super.didChangeDependencies();
  }

  var a = 0;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => Auth(),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersTripsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => Messages(),
        ),
      ],
      child: Consumer3<Auth, Messages, OrdersTripsProvider>(builder: (
        ctx,
        auth,
        message,
        orderstripsProvider,
        _,
      ) {
        authProvider = auth;
        messageProvider = message;
        if (auth.isAuth == false) {
          auth.tryAutoLogin();
        }
        if (message.isChatsLoadingForMain && auth.isAuth && auth.user != null) message.fetchAndSetRooms(auth, false);
        if (!socketConnectedFirebase) _configureFirebaseListerners();
        if (auth.user != null && !socketConnected) initCommunication(auth, message);
        if (auth.isAuth && orderstripsProvider.loadedMyOrders) orderstripsProvider.fetchAndSetMyOrders(auth.token);
        if (auth.isAuth && orderstripsProvider.loadedMyTrips) orderstripsProvider.fetchAndSetMyTrips(auth.token);
        if (orderstripsProvider.isLoadingOrders && !orderstripsProvider.filtering) orderstripsProvider.fetchAndSetOrders();
        if (orderstripsProvider.isLoadingTrips && !orderstripsProvider.filtering) orderstripsProvider.fetchAndSetTrips();
        if (auth.isLoadingUserForMain && auth.token != null)
          auth.fetchAndSetUserDetails().whenComplete(() {
            if (auth.user == null) {
              auth.isLoadingUserForMain = true;
              auth.isLoadingUserDetails = true;
            }
          });
        //if (auth.reviewsNotReady && auth.isNotLoadingUserDetails == false) auth.fetchAndSetReviews();
        //if (auth.statsNotReady && auth.isNotLoadingUserDetails == false) auth.fetchAndSetStatistics();
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.white10,
          statusBarIconBrightness: Brightness.dark,
        ));

        return MaterialApp(
          locale: _locale,
          localizationsDelegates: [
            DemoLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            const Locale('en', 'US'), // English, no country code
            const Locale('ru', 'RU'), // Russian, no country code
            const Locale('az', 'AZ'), // Azeri, no country code
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            for (var locale in supportedLocales) {
              if (locale.languageCode == deviceLocale.languageCode && locale.countryCode == deviceLocale.countryCode) {
                return deviceLocale;
              }
            }

            return supportedLocales.first;
          },
          title: 'briddgy',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            backgroundColor: Colors.white,
            primarySwatch: Colors.blue,
            primaryColor: Colors.teal[700],
            accentColor: Colors.green,
            fontFamily: 'Open Sans',
          ),
          home: NBItem1(
            orderstripsProvider: orderstripsProvider,
            message: message,
            auth: auth,
            tokenforROOM: tokenforROOM,
            controller: _controller,
          ),
          routes: {
            OrdersScreen.routeName: (ctx) => OrdersScreen(),
            TripsScreen.routeName: (ctx) => TripsScreen(),
            ChatWindow.routeName: (ctx) => ChatWindow(),
            AddOrderScreen.routeName: (ctx) => AddOrderScreen(),
            AddTripScreen.routeName: (ctx) => AddTripScreen(),
            Contracts.routeName: (ctx) => Contracts(),
            AccountScreen.routeName: (ctx) => AccountScreen(),
          },
        );
      }),
    );
  }
}

class NBItem1 extends StatefulWidget {
  NBItem1({this.orderstripsProvider, this.message, this.auth, this.tokenforROOM, @required this.controller});
  var orderstripsProvider, message, auth, tokenforROOM, controller;

  @override
  _NBItem1State createState() => _NBItem1State();
}

class _NBItem1State extends State<NBItem1> {
  List<Widget> _buildScreens() {
    return [
      OrdersScreen(orderstripsProvider: widget.orderstripsProvider, room: widget.message, auth: widget.auth, token: widget.tokenforROOM),
      TripsScreen(orderstripsProvider: widget.orderstripsProvider, room: widget.message, auth: widget.auth, token: widget.tokenforROOM),
      ChatsScreen(provider: widget.message, auth: widget.auth),
//                  NotificationScreen(),
      widget.auth.isAuth
          ?
//            AccountScreen(token: tokenforROOM, auth: auth, provider: orderstripsProvider)
          widget.auth.user != null
              ? ProfileScreen(
                  user: widget.auth.user,
                )
              : ProgressIndicatorWidget(show: true)
          : AuthScreen(),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems(context) {
    return [
      PersistentBottomNavBarItem(
        title: t(context, "order_plural"),
        icon: widget.controller.index == 0 ? Icon(MdiIcons.packageVariant) : Icon(MdiIcons.packageVariantClosed),
        activeColor: Colors.teal[700],
        inactiveColor: Colors.grey[400],
      ),
      PersistentBottomNavBarItem(
        title: t(context, "trip_plural"),
        icon: widget.controller.index == 1 ? Icon(MdiIcons.roadVariant) : Icon(MdiIcons.road),
        activeColor: Colors.teal[700],
        inactiveColor: Colors.grey[400],
      ),
      PersistentBottomNavBarItem(
        title: t(context, "chats"),
        icon: widget.controller.index == 2
            ? widget.message.arethereNewMessage == true
                ? Badge(
                    badgeColor: Colors.green,
                    badgeContent: Text(
                      widget.message.newMessages.length.toString(),
                      style: TextStyle(color: Colors.white),
                    ),
                    child: Icon(MdiIcons.forum),
                  )
                : Icon(MdiIcons.forum)
            : widget.message.arethereNewMessage == true
                ? Badge(
                    badgeColor: Colors.green,
                    badgeContent: Text(
                      widget.message.newMessages.length.toString(),
                      style: TextStyle(color: Colors.white),
                    ),
                    child: Icon(MdiIcons.forumOutline),
                  )
                : Icon(MdiIcons.forumOutline),
        activeColor: Colors.teal[700],
        inactiveColor: Colors.grey[400],
      ),
      PersistentBottomNavBarItem(
        title: t(context, "profile"),
        icon: widget.controller.index == 3 ? Icon(MdiIcons.accountSettings) : Icon(MdiIcons.accountSettingsOutline),
        activeColor: Colors.teal[700],
        inactiveColor: Colors.grey[400],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      controller: widget.controller,
      screens: _buildScreens(),
      items: _navBarsItems(context),
      confineInSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true, // This needs to be true if you want to move up the screen when keyboard appears.
      stateManagement: true,
      hideNavigationBarWhenKeyboardShows: true, // Recommended to set 'resizeToAvoidBottomInset' as true while using this argument.
      decoration: NavBarDecoration(
        borderRadius: BorderRadius.circular(10.0),
        colorBehindNavBar: Colors.white,
      ),
      popAllScreensOnTapOfSelectedTab: true,
      navBarHeight: 50,
      itemAnimationProperties: ItemAnimationProperties(
        // Navigation Bar's items animation properties.
        duration: Duration(milliseconds: 400),
        curve: Curves.ease,
      ),

      screenTransitionAnimation: ScreenTransitionAnimation(
        animateTabTransition: false,
//        curve: Curves.ease,
//        duration: Duration(milliseconds: 400),
      ),
      onItemSelected: (index) {
        setState(() {});
      },
      navBarStyle: NavBarStyle.style6, // Choose the nav bar style with this property.
    );
  }
}
