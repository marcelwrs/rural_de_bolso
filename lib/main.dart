import 'package:flutter/material.dart';
import 'package:web_scraper/web_scraper.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rural de bolso',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'Rural de bolso'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _username = TextEditingController();
  final _pass = TextEditingController();
  var _loginClicked = false;
  var _displayMessage = "Login";
  var _loggedIn = false;
  var _fullName = "";
  var _deptName = "";
  var _semester = "";

  Future<void> _doLogin(user, pass) async {
    print("Usuario: $user");
    print("Senha: ***");
    final webScraper = WebScraper();
    var dio = Dio();
    var cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));

    // Set default request headers
    dio.options.headers['Connection'] = 'keep-alive';
    dio.options.headers['Host'] = 'sigaa.ufrrj.br';
    dio.options.headers['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.93 Safari/537.36';
    dio.options.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    dio.options.followRedirects = false; // It is imporant to follow redirects
    dio.options.maxRedirects = 20;
    dio.options.validateStatus = (status) {
      return status < 500;
    };
    //print(dio.options.headers.toString());

    // Get login page to obtain cookies
    await dio.get("https://sigaa.ufrrj.br/sigaa/verTelaLogin.do");
    // Extract JSESSIONID from cookie
    var cookie = await cookieJar.loadForRequest(Uri.parse("https://sigaa.ufrrj.br/"));
    var _jsessionId = cookie.toString().split(';')[0].split('=')[1];

    // Do login
    Response response = await dio.get(
        'https://sigaa.ufrrj.br/sigaa/logar.do;jsessionid=$_jsessionId?dispatch=logOn&user.login=$user&user.senha=$pass');
    print("Status: " + response.statusCode.toString() + " " + response.statusMessage);
    print("Headers: " + response.headers.toString());
    print("Data: " + response.data);

    var url;
    while (response.statusCode == 302) {
      if (response.headers.toString().contains("location:")){
        var loc = response.headers['location'].toString().split(':');
        print(loc.toString());
        loc[0] = "https";
        loc[1] = loc[1].substring(0,loc[1].length-1);
        url = loc.join(':');
        print(url.toString());
      }
      response = await dio.get(url);
      print("Status: " + response.statusCode.toString() + " " + response.statusMessage);
      print("Headers: " + response.headers.toString());
      print("Data: " + response.data);
    }

    // Handle vinculos (bond) page - TODO
/*    if (response.data.toString().contains("listagem table tabela-selecao-vinculo")) {
      var bond = "";
      response.data.toString().split('\n').forEach((line) {
        if (line.contains('Servidor') && line.contains('withoutFormat')) {
          bond = line.split('"')[1].toString();
        }
      });

      response = await dio.get(bond);
      while (response.statusCode == 302) {
        if (response.headers.toString().contains("location:")){
          var loc = response.headers['location'].toString().split(':');
          print(loc.toString());
          loc[0] = "https";
          loc[1] = loc[1].substring(0,loc[1].length-1);
          url = loc.join(':');
          print(url.toString());
        }
        response = await dio.get(url);
        print("Status: " + response.statusCode.toString() + " " + response.statusMessage);
        print("Headers: " + response.headers.toString());
        print("Data: " + response.data);
      }
    }
*/

    // Handle login error
    if (response.data.toString().contains('rio e/ou senha inv')) {
      print("Login error");
      _loginClicked = false;
      return;
    }

    // Scrap usefull info from SIGAA home page
    var name, dept, sem;
    if (webScraper.loadFromString(response.data)) {
      List<Map<String, dynamic>> elements;
      elements = webScraper.getElement('div#container > div#cabecalho > div#painel-usuario > div#info-usuario > p.usuario', []);
      name = elements[0]['title'].toString().trim();
      elements = webScraper.getElement('div#container > div#cabecalho > div#painel-usuario > div#info-usuario > p.periodo-atual > strong', []);
      sem = elements[0]['title'].toString().trim();
      elements = webScraper.getElement('div#container > div#cabecalho > div#painel-usuario > div#info-usuario > p.unidade', []);
      dept = elements[0]['title'].toString().split('(')[0].trim();
    }
    setState(() {
      _fullName = name;
      _semester = sem;
      _deptName = dept;
      _displayMessage = "Dashboard";
      _loggedIn = true;
    });
    _loginClicked = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Rural de bolso: " + _displayMessage),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Nome: $_fullName', style: TextStyle(fontSize: 12)),
              Text('Unidade: $_deptName', style: TextStyle(fontSize: 12)),
              Text('Período atual: $_semester', style: TextStyle(fontSize: 12)),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _displayMessage = "Login";
                    _loggedIn = false;
                  });
                },
                child: Text('Sair', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: Text("Rural de bolso: " + _displayMessage),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Credenciais do SIGAA:', style: TextStyle(fontSize: 20)),
              SizedBox(height: 10),
              SizedBox(
                width: 600,
                child: TextField(
                  controller: _username,
                  //keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    labelText: 'Usuário',
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                width: 600,
                child: TextField(
                  controller: _pass,
                  //keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    labelText: 'Senha',
                  ),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  if (!_loginClicked) {
                    _loginClicked = true;
                    await _doLogin(_username.text, _pass.text);
                  }
                },
                child: Text('Entrar', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      );
    }
  }
}
