import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

// This widget embeds an iframe that loads `web/hls_player.html` with the
// HLS URL provided as a query parameter. It only runs on web; on other
// platforms you should use the native VideoPlayer controller.
//
// Usage: WebHlsPlayer(hlsUrl: 'http://.../index.m3u8', viewId: 'player-1')

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui' as ui;

class WebHlsPlayer extends StatefulWidget {
  final String hlsUrl;
  final String viewId;

  const WebHlsPlayer({super.key, required this.hlsUrl, required this.viewId});

  @override
  State<WebHlsPlayer> createState() => _WebHlsPlayerState();
}

class _WebHlsPlayerState extends State<WebHlsPlayer> {
  late html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'autoplay'
      ..src = '/hls_player.html?url=' + Uri.encodeComponent(widget.hlsUrl);

    // Register the view factory for this viewId. Multiple registrations with
    // same id will throw, so use unique viewId per instance.
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry
        .registerViewFactory(widget.viewId, (int viewId) => _iframe);
  }

  @override
  void dispose() {
    try {
      _iframe.contentWindow?.postMessage({'cmd': 'stop'}, '*');
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return HtmlElementView(viewType: widget.viewId);
  }
}
