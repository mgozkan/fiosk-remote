import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:flutter_hbb/web/settings_page.dart';
import 'package:get/get.dart';
import '../../common.dart';
import '../../common/widgets/chat_page.dart';
import '../../models/platform_model.dart';
import '../../models/state_model.dart';
import 'connection_page.dart';

abstract class PageShape extends Widget {
  final String title = "";
  final Widget icon = Icon(null);
  final List<Widget> appBarActions = [];
}

// Fiosk Remote: simplified single-page UI.
// Only ServerPage (the host/screen-share page) is shown. Settings reachable
// via the gear icon in the AppBar. No bottom navigation, no chat, no outgoing
// connection — Fiosk devices are only controlled, never controllers.
class HomePage extends StatefulWidget {
  static final homeKey = GlobalKey<HomePageState>();

  HomePage() : super(key: homeKey);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final ServerPage _serverPage;

  // Backward-compat shims for code that still queries home tab state.
  int get selectedIndex => 0;
  bool get isChatPageCurrentTab => false;

  void refreshPages() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _serverPage = ServerPage();
  }

  void _openSettings() {
    // SettingsPage is a PageShape (designed as tab content) and has no Scaffold
    // of its own. Wrap it in a Scaffold + AppBar so the user gets a back button
    // and is not stuck on the page.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          final settings = SettingsPage();
          return Scaffold(
            appBar: AppBar(
              title: Text(settings.title),
              actions: settings.appBarActions,
            ),
            body: settings,
          );
        },
      ),
    );
  }

  // Closes the Fiosk Remote activity and returns the user to whatever task
  // was running before (FioskLauncher home / Fiosk Price Checker kiosk).
  // The foreground MainService keeps running — Fiosk Remote remains
  // reachable from outside, only the UI is dismissed. Required because
  // the kiosk has no swipe-up / home button to leave the app.
  void _closeApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close),
          tooltip: translate('Close'),
          onPressed: _closeApp,
        ),
        title: Text(bind.mainGetAppNameSync()),
        actions: [
          ..._serverPage.appBarActions,
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: translate('Settings'),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _serverPage,
    );
  }
}

class WebHomePage extends StatelessWidget {
  final connectionPage =
      ConnectionPage(appBarActions: <Widget>[const WebSettingsPage()]);

  @override
  Widget build(BuildContext context) {
    stateGlobal.isInMainPage = true;
    handleUnilink(context);
    return Scaffold(
      // backgroundColor: MyTheme.grayBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text("${bind.mainGetAppNameSync()} (Preview)"),
        actions: connectionPage.appBarActions,
      ),
      body: connectionPage,
    );
  }

  handleUnilink(BuildContext context) {
    if (webInitialLink.isEmpty) {
      return;
    }
    final link = webInitialLink;
    webInitialLink = '';
    final splitter = ["/#/", "/#", "#/", "#"];
    var fakelink = '';
    for (var s in splitter) {
      if (link.contains(s)) {
        var list = link.split(s);
        if (list.length < 2 || list[1].isEmpty) {
          return;
        }
        list.removeAt(0);
        fakelink = "rustdesk://${list.join(s)}";
        break;
      }
    }
    if (fakelink.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(fakelink);
    if (uri == null) {
      return;
    }
    final args = urlLinkToCmdArgs(uri);
    if (args == null || args.isEmpty) {
      return;
    }
    bool isFileTransfer = false;
    bool isViewCamera = false;
    bool isTerminal = false;
    String? id;
    String? password;
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--connect':
        case '--play':
          id = args[i + 1];
          i++;
          break;
        case '--file-transfer':
          isFileTransfer = true;
          id = args[i + 1];
          i++;
          break;
        case '--view-camera':
          isViewCamera = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal':
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal-admin':
          setEnvTerminalAdmin();
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--password':
          password = args[i + 1];
          i++;
          break;
        default:
          break;
      }
    }
    if (id != null) {
      connect(context, id,
        isFileTransfer: isFileTransfer,
        isViewCamera: isViewCamera,
        isTerminal: isTerminal,
        password: password);
    }
  }
}
