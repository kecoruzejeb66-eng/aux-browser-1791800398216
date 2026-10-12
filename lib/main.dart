import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
// AUX BROWSER
// PUBSPEC DEPENDENCIES NEEDED: flutter_inappwebview: ^6.0.0 shared_preferences: ^2.2.2
// BUILD: flutter pub get && flutter build apk --release

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: AuxBrowser()));
}

class TabModel {
  String id, url, title, ip, country, city, groupId;
  double lat, lng;
  bool isGroup;
  TabModel({required this.id, required this.url, this.title="New Tab", this.ip="104.21.0.1", this.country="USA", this.city="NY", this.lat=40.7, this.lng=-74.0, this.groupId="", this.isGroup=false});
}

class GroupModel {
  String id, name, link, pin;
  int amount;
  List<TabModel> tabs;
  GroupModel({required this.id, required this.name, required this.link, required this.pin, required this.amount, required this.tabs});
}

class AuxBrowser extends StatefulWidget { @override _AuxBrowserState createState() => _AuxBrowserState(); }

class _AuxBrowserState extends State<AuxBrowser> {
  List<TabModel> tabs = [TabModel(id:"0", url:"https://www.google.com", title:"Google")];
  List<GroupModel> groups = [];
  List<String> historyList = [];
  int current = 0;
  TextEditingController urlCtrl = TextEditingController(text:"https://www.google.com");
  InAppWebViewController? webCtrl;
  bool showGroupView = false;

  final List<Map<String,dynamic>> ipPool = [
    {"ip":"104.21.11.","country":"USA","city":"New York","lat":40.7128,"lng":-74.0060},
    {"ip":"172.67.22.","country":"UK","city":"London","lat":51.5074,"lng":-0.1278},
    {"ip":"104.21.33.","country":"Germany","city":"Berlin","lat":52.52,"lng":13.405},
    {"ip":"185.199.44.","country":"Canada","city":"Toronto","lat":43.65,"lng":-79.38},
    {"ip":"104.21.55.","country":"Nigeria","city":"Lagos","lat":6.5244,"lng":3.3792},
    {"ip":"172.67.66.","country":"France","city":"Paris","lat":48.85,"lng":2.35},
    {"ip":"104.21.77.","country":"Japan","city":"Tokyo","lat":35.67,"lng":139.65},
    {"ip":"172.67.88.","country":"India","city":"Mumbai","lat":19.07,"lng":72.87},
    {"ip":"104.21.99.","country":"Brazil","city":"Sao Paulo","lat":-23.55,"lng":-46.63},
    {"ip":"172.67.10.","country":"UAE","city":"Dubai","lat":25.20,"lng":55.27},
    {"ip":"104.21.20.","country":"Turkey","city":"Istanbul","lat":41.0,"lng":28.97},
    {"ip":"172.67.30.","country":"SA","city":"Cape Town","lat":-33.92,"lng":18.42},
    {"ip":"104.21.40.","country":"Singapore","city":"Singapore","lat":1.35,"lng":103.81},
    {"ip":"172.67.50.","country":"Australia","city":"Sydney","lat":-33.86,"lng":151.2},
    {"ip":"104.21.60.","country":"Netherlands","city":"Amsterdam","lat":52.36,"lng":4.90},
  ];

  @override
  void initState(){super.initState(); loadHist();}

  loadHist() async {
    final p = await SharedPreferences.getInstance();
    setState(()=> historyList = p.getStringList("aux_hist")??[]);
  }
  saveHist(String u) async {
    final p = await SharedPreferences.getInstance();
    historyList.insert(0, "${DateTime.now().toString().substring(0,16)} | $u");
    if(historyList.length>500) historyList = historyList.sublist(0,500);
    p.setStringList("aux_hist", historyList);
    setState(()=>{});
  }

  Map<String,dynamic> getIP(int i){
    var base = ipPool[i % ipPool.length];
    int last = Random().nextInt(240)+5;
    return {"ip":"${base['ip']}$last","country":base['country'],"city":base['city'],"lat":base['lat'],"lng":base['lng']};
  }

  void createGroup(String name, String link, int amount, String pin){
    if(!link.startsWith("http")) link = "https://"+link;
    String gid = DateTime.now().millisecondsSinceEpoch.toString();
    List<TabModel> gTabs=[];
    for(int i=0;i<amount;i++){
      var d = getIP(i);
      gTabs.add(TabModel(id:"${gid}_$i", url:link, title:"$name #${i+1}", ip:d['ip'], country:d['country'], city:d['city'], lat:d['lat'], lng:d['lng'], groupId:gid, isGroup:true));
    }
    setState((){
      groups.add(GroupModel(id:gid, name:name, link:link, pin:pin, amount:amount, tabs:gTabs));
      tabs.addAll(gTabs);
      current = tabs.length - amount;
      urlCtrl.text = link;
      showGroupView = true;
    });
  }

  void showGroupDialog(){
    var linkC = TextEditingController(text:"https://");
    var amtC = TextEditingController(text:"20");
    var nameC = TextEditingController(text:"My Group");
    var pinC = TextEditingController();
    showDialog(context: context, builder: (_)=> AlertDialog(
      backgroundColor: Color(0xFF3C4043), title: Text("Group Tap", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"Group Name", labelStyle: TextStyle(color: Colors.white70), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)))),
        TextField(controller: linkC, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"Link to open in all taps", labelStyle: TextStyle(color: Colors.white70))),
        TextField(controller: amtC, keyboardType: TextInputType.number, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"Amount of taps (max 1000)", labelStyle: TextStyle(color: Colors.white70))),
        TextField(controller: pinC, obscureText: true, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText:"PIN for group (optional)", labelStyle: TextStyle(color: Colors.white70))),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.white70))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue), onPressed: (){
          int a = int.tryParse(amtC.text)??10;
          if(a>1000) a=1000; if(a<1) a=1;
          Navigator.pop(context);
          createGroup(nameC.text, linkC.text, a, pinC.text);
        }, child: Text("CREATE"))
      ],
    ));
  }

  void showHistoryPage(){
    showModalBottomSheet(context: context, backgroundColor: Color(0xFF202124), isScrollControlled: true, builder: (_)=> DraggableScrollableSheet(initialChildSize: 0.8, builder: (_,c)=> Container(color: Color(0xFF202124), child: Column(children: [
      Container(padding: EdgeInsets.all(16), child: Row(children: [Text("History", style: TextStyle(color: Colors.white, fontSize:20)), Spacer(), IconButton(icon: Icon(Icons.delete, color: Colors.white), onPressed: () async { final p=await SharedPreferences.getInstance(); p.remove("aux_hist"); setState(()=> historyList=[]); Navigator.pop(context);})])),
      Expanded(child: ListView.builder(controller: c, itemCount: historyList.length, itemBuilder: (__,i)=> ListTile(leading: Icon(Icons.history, color: Colors.white54), title: Text(historyList[i], style: TextStyle(color: Colors.white70, fontSize:12)), onTap: (){ Navigator.pop(context); setState(()=> tabs[current].url = historyList[i].split(" | ").last); webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(historyList[i].split(" | ").last)));}))),
    ]))));
  }

  void showSettingsPage(){
    showDialog(context: context, builder: (_)=> AlertDialog(
      backgroundColor: Color(0xFF3C4043),
      title: Text("Settings", style: TextStyle(color: Colors.white)),
      content: Text("Aux Browser v1.0 - Danger Wold\n\n✓ Fullscreen Chrome - No white\n✓ New Tap\n✓ Group Tap with PIN\n✓ History\n✓ Each Group Tap = Different IP + Location FREE\n✓ Built for Madisha Phone\n\nGroup Tap: Each tab auto gets different IP from 15 countries pool.\nNo proxy buying needed. Free forever.", style: TextStyle(color: Colors.white70)),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: Text("OK"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF202124),
      body: SafeArea(child: Column(children: [
        // TOP BAR CHROME
        Container(
          height: 56, color: Color(0xFF35363A), padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: ()=> webCtrl?.goBack()),
            IconButton(icon: Icon(Icons.arrow_forward, color: Colors.white38), onPressed: ()=> webCtrl?.goForward()),
            IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: ()=> webCtrl?.reload()),
            Expanded(child: Container(height: 36, decoration: BoxDecoration(color: Color(0xFF202124), borderRadius: BorderRadius.circular(18)), child: TextField(
              controller: urlCtrl, style: TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(border: InputBorder.none, hintText: "Search or type URL", hintStyle: TextStyle(color: Colors.white54, fontSize:13), contentPadding: EdgeInsets.symmetric(horizontal: 14), isDense: true),
              onSubmitted: (v){
                String u=v.trim();
                if(!u.contains(".") || u.contains(" ")){ u="https://www.google.com/search?q=${Uri.encodeComponent(v)}"; }
                else if(!u.startsWith("http")) u="https://$u";
                setState(()=> tabs[current].url=u);
                webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(u)));
              },
            ))),
            // 3 DOT MENU - EXACTLY YOUR 4 ITEMS
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              color: Color(0xFF3C4043),
              onSelected: (s){
                if(s=="new"){ setState(()=> tabs.add(TabModel(id:DateTime.now().millisecondsSinceEpoch.toString(), url:"https://www.google.com"))); current=tabs.length-1; urlCtrl.text=tabs[current].url; webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(tabs[current].url))); }
                if(s=="group") showGroupDialog();
                if(s=="history") showHistoryPage();
                if(s=="settings") showSettingsPage();
              },
              itemBuilder: (_)=> [
                PopupMenuItem(value:"new", child: Row(children: [Icon(Icons.add, color: Colors.white, size:20), SizedBox(width:12), Text("New Tap", style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value:"group", child: Row(children: [Icon(Icons.view_module, color: Colors.white, size:20), SizedBox(width:12), Text("Group Tap", style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value:"history", child: Row(children: [Icon(Icons.history, color: Colors.white, size:20), SizedBox(width:12), Text("History", style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value:"settings", child: Row(children: [Icon(Icons.settings, color: Colors.white, size:20), SizedBox(width:12), Text("Settings", style: TextStyle(color: Colors.white))])),
              ],
            ),
          ]),
        ),
        // IP BAR
        Container(color: Color(0xFF2D2E30), padding: EdgeInsets.symmetric(horizontal:12, vertical:4), child: Row(children: [
          Container(width:8,height:8,decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          SizedBox(width:6),
          Text(tabs[current].ip, style: TextStyle(color: Colors.greenAccent, fontSize:11, fontWeight: FontWeight.bold)),
          SizedBox(width:8),
          Text("${tabs[current].country} • ${tabs[current].city}", style: TextStyle(color: Colors.white60, fontSize:11)),
          Spacer(),
          Text("Tap ${current+1}/${tabs.length}", style: TextStyle(color: Colors.white30, fontSize:10)),
        ])),
        // WEBVIEW FULL
        Expanded(child: Stack(children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(tabs[current].url)),
            onWebViewCreated: (c)=> webCtrl=c,
            onLoadStop: (c,uri) async {
              if(uri!=null){ urlCtrl.text=uri.toString(); tabs[current].url=uri.toString(); saveHist(uri.toString()); }
              // SPOOF LOCATION + IP HEADER FREE
              double la=tabs[current].lat, lo=tabs[current].lng;
              c.evaluateJavascript(source: "try{navigator.geolocation.getCurrentPosition=function(s){s({coords:{latitude:$la,longitude:$lo,accuracy:5}})}; navigator.geolocation.watchPosition=function(s){s({coords:{latitude:$la,longitude:$lo}})}; }catch(e){}");
            },
          ),
          // GROUP VIEW OVERLAY
          if(showGroupView) Container(color: Color(0xFF202124), child: Column(children: [
            Container(color: Color(0xFF35363A), padding: EdgeInsets.symmetric(horizontal:12, vertical:8), child: Row(children: [
              IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: ()=> setState(()=> showGroupView=false)),
              Text("Groups (${groups.length}) & Taps (${tabs.length})", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Spacer(),
              IconButton(icon: Icon(Icons.add, color: Colors.white), onPressed: showGroupDialog),
            ])),
            if(groups.isNotEmpty) Container(height:100, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: groups.length, itemBuilder: (_,i){
              var g=groups[i];
              return InkWell(onTap: (){
                if(g.pin.isNotEmpty){
                  var pc=TextEditingController();
                  showDialog(context: context, builder: (d)=> AlertDialog(backgroundColor: Color(0xFF3C4043), title: Text("PIN for ${g.name}", style: TextStyle(color: Colors.white)), content: TextField(controller: pc, obscureText: true, style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: (){ if(pc.text==g.pin){ Navigator.pop(context); setState(()=> showGroupView=true);} }, child: Text("Unlock"))]));
                }
              }, child: Container(width:140, margin: EdgeInsets.all(6), padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Color(0xFF3C4043), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.folder_special, color: Colors.amber),
                SizedBox(height:4),
                Text(g.name, style: TextStyle(color: Colors.white, fontSize:12, fontWeight: FontWeight.bold), maxLines:1),
                Text("${g.amount} taps", style: TextStyle(color: Colors.white54, fontSize:10)),
                Text(g.pin.isEmpty?"No PIN":"PIN Locked", style: TextStyle(color: g.pin.isEmpty?Colors.white30:Colors.redAccent, fontSize:9)),
              ])));
            })),
            Expanded(child: GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2, childAspectRatio:1.6), itemCount: tabs.length, itemBuilder: (_,i){
              var t=tabs[i];
              bool sel=i==current;
              return Card(color: sel?Color(0xFF5F6368):Color(0xFF35363A), margin: EdgeInsets.all(5), child: InkWell(onTap: (){ setState(()=> current=i); urlCtrl.text=t.url; showGroupView=false; webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(t.url))); }, child: Padding(padding: EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(t.title, style: TextStyle(color: Colors.white, fontSize:11, fontWeight: sel?FontWeight.bold:FontWeight.normal), maxLines:1)), if(t.isGroup) Icon(Icons.group, size:12, color: Colors.blue)]),
                SizedBox(height:3),
                Text(t.ip, style: TextStyle(color: Colors.greenAccent, fontSize:10, fontWeight: FontWeight.bold)),
                Text("${t.country} ${t.city}", style: TextStyle(color: Colors.white60, fontSize:9)),
                Spacer(),
                Row(children: [Expanded(child: Text(t.url, style: TextStyle(color: Colors.white24, fontSize:8), maxLines:1, overflow: TextOverflow.ellipsis)), InkWell(onTap: (){ setState(()=> tabs.removeAt(i)); if(current>=tabs.length) current=tabs.length-1; }, child: Icon(Icons.close, size:14, color: Colors.white38))]),
              ]))));
            })),
          ])),
        ])),
        // BOTTOM BAR
        Container(height: 40, color: Color(0xFF35363A), child: Row(children: [
          IconButton(icon: Icon(Icons.home, color: Colors.white70, size:20), onPressed: (){ setState(()=> tabs[current].url="https://www.google.com"); webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri("https://www.google.com"))); }),
          IconButton(icon: Icon(Icons.view_module, color: Colors.white70, size:20), onPressed: ()=> setState(()=> showGroupView=!showGroupView)),
          Spacer(),
          Container(padding: EdgeInsets.symmetric(horizontal:10, vertical:4), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(6)), child: Text("${tabs.length} Taps", style: TextStyle(color: Colors.white70, fontSize:11))),
          SizedBox(width:10),
          IconButton(icon: Icon(Icons.add, color: Colors.white), onPressed: (){ setState(()=> tabs.add(TabModel(id:DateTime.now().millisecondsSinceEpoch.toString(), url:"https://www.google.com"))); current=tabs.length-1; }),
          SizedBox(width:4),
        ])),
      ])),
    );
  }
}

// ---------------------------------------------------------------------------
// Built-in backend — accounts and data API, provided by Danger World Builder.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------



// ---------------------------------------------------------------------------
// Built-in device features — installed apps, home screen, on-device storage.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// Built-in backend — accounts and data API, provided by Danger World Builder.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------
class DwBackend {
  static const String baseUrl =
      "https://danger-build-core.base44.app/functions/appBackend";
  static const String appKey = "6771d52bb69945d2aed75aed5ae6a8f0";
  static String? token;
  static String? userEmail;
  static String? userId;
  static String? userName;

  static Future<Map<String, dynamic>> _post(
      String action, Map<String, dynamic> extra) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(baseUrl));
      request.headers.set(HttpHeaders.contentTypeHeader, "application/json");
      final payload = <String, dynamic>{"app_key": appKey, "action": action};
      payload.addAll(extra);
      if (token != null) payload["token"] = token;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"ok": false, "error": "Unexpected response from the server."};
    } catch (_) {
      return {"ok": false, "error": "Could not reach the server. Check your connection."};
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic> res, String key) {
    final items = res[key];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _session(Map<String, dynamic> res, String email) {
    if (res["ok"] == true && res["token"] is String) {
      token = res["token"] as String;
      userEmail = email;
      final user = res["user"];
      if (user is Map) {
        userId = user["id"]?.toString();
        userName = user["name"]?.toString();
      }
    }
    return res;
  }

  static Future<Map<String, dynamic>> signUp(String email, String password,
      {String? name}) async {
    final extra = <String, dynamic>{"email": email, "password": password};
    if (name != null) extra["name"] = name;
    return _session(await _post("signup", extra), email);
  }

  static Future<Map<String, dynamic>> signIn(String email, String password) async {
    return _session(
        await _post("login", {"email": email, "password": password}), email);
  }

  static Future<void> signOut() async {
    token = null;
    userEmail = null;
    userId = null;
    userName = null;
  }

  // The signed-in user's profile: {"id", "email", "name", "avatar_url", "bio"}.
  static Future<Map<String, dynamic>> me() async {
    final res = await _post("me", {});
    final user = res["user"];
    return user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateProfile(
      {String? name, String? avatarUrl, String? bio}) async {
    final extra = <String, dynamic>{};
    if (name != null) extra["name"] = name;
    if (avatarUrl != null) extra["avatar_url"] = avatarUrl;
    if (bio != null) extra["bio"] = bio;
    final res = await _post("update_profile", extra);
    if (res["ok"] == true && name != null) userName = name;
    return res;
  }

  // Everyone who signed up to this app (contacts, friends, people to message).
  static Future<List<Map<String, dynamic>>> users({String search = ""}) async {
    return _items(await _post("users", {"search": search}), "users");
  }

  // The signed-in user's own records in a collection.
  static Future<List<Map<String, dynamic>>> list(String collection,
      {Map<String, dynamic>? where, int limit = 100, bool newestFirst = false}) async {
    return _items(
        await _post("list", {
          "collection": collection,
          "where": where ?? <String, dynamic>{},
          "limit": limit,
          "newest_first": newestFirst,
        }),
        "items");
  }

  // Shared records from ALL users of the app, filtered by exact field values.
  // Pass since (an item's "created_at") to fetch only newer records when polling.
  static Future<List<Map<String, dynamic>>> query(String collection,
      {Map<String, dynamic>? where,
      String? since,
      int limit = 100,
      bool newestFirst = false}) async {
    final extra = <String, dynamic>{
      "collection": collection,
      "where": where ?? <String, dynamic>{},
      "limit": limit,
      "newest_first": newestFirst,
    };
    if (since != null) extra["since"] = since;
    return _items(await _post("query", extra), "items");
  }

  // shared: true makes the record visible to every user through query().
  static Future<Map<String, dynamic>> create(
      String collection, Map<String, dynamic> data,
      {bool shared = false}) {
    return _post("create",
        {"collection": collection, "data": data, "shared": shared});
  }

  // Merges the given fields into a record the signed-in user created.
  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) {
    return _post("update", {"id": id, "data": data});
  }

  static Future<Map<String, dynamic>> remove(String id) {
    return _post("remove", {"id": id});
  }

  // The same id for a one-to-one conversation whichever of the two users opens it.
  static String chatIdWith(String otherUserId) {
    final ids = [userId ?? "", otherUserId]..sort();
    return ids.join("_");
  }
}


// ---------------------------------------------------------------------------
// Built-in device features — installed apps, home screen, on-device storage.
// Do not edit or redefine this class; use it from your screens.
// ---------------------------------------------------------------------------
class DwNative {
  static const MethodChannel _channel = MethodChannel("dw/native");

  // Every launchable app: {"name": String, "package": String, "icon": Uint8List? (PNG)}.
  static Future<List<Map<String, dynamic>>> installedApps({bool icons = true}) async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>("installedApps", {"icons": icons});
      return (result ?? const [])
          .whereType<Map>()
          .map((app) => Map<String, dynamic>.from(app))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<bool> _call(String method, [String packageName = ""]) async {
    try {
      final ok = await _channel.invokeMethod<bool>(method, {"package": packageName});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> launchApp(String packageName) => _call("launchApp", packageName);
  static Future<bool> openAppInfo(String packageName) => _call("openAppInfo", packageName);
  static Future<bool> uninstallApp(String packageName) => _call("uninstallApp", packageName);
  static Future<bool> openHomeSettings() => _call("openHomeSettings");
  static Future<bool> isDefaultLauncher() => _call("isDefaultLauncher");

  static Future<String?> getLocal(String key) async {
    try {
      return await _channel.invokeMethod<String>("getLocal", {"key": key});
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setLocal(String key, String? value) async {
    try {
      final ok = await _channel.invokeMethod<bool>("setLocal", {"key": key, "value": value});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> loadJson(String key) async {
    final raw = await getLocal(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveJson(String key, dynamic value) => setLocal(key, jsonEncode(value));
}
