// lib/ui/widgets/web_hls_player.dart
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// WebHlsPlayer - HLS player cho Flutter Web sử dụng hls.js
///
/// Widget này tạo một iframe với video player sử dụng hls.js để play HLS stream
class WebHlsPlayer extends StatefulWidget {
  final String hlsUrl;
  final String viewId;

  const WebHlsPlayer({
    super.key,
    required this.hlsUrl,
    required this.viewId,
  });

  @override
  State<WebHlsPlayer> createState() => _WebHlsPlayerState();
}

class _WebHlsPlayerState extends State<WebHlsPlayer> {
  @override
  void initState() {
    super.initState();
    _registerViewFactory();
  }

  void _registerViewFactory() {
    // Register platform view factory cho iframe
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      widget.viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..srcdoc = _getHtmlContent();

        return iframe;
      },
    );
  }

  String _getHtmlContent() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      background: #000;
      overflow: hidden;
    }
    #video-container {
      width: 100vw;
      height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    video {
      width: 100%;
      height: 100%;
      object-fit: contain;
    }
    .error {
      color: white;
      text-align: center;
      padding: 20px;
      font-family: Arial, sans-serif;
    }
  </style>
</head>
<body>
  <div id="video-container">
    <video id="video" controls autoplay muted></video>
  </div>
  
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <script>
    const video = document.getElementById('video');
    const videoSrc = '${widget.hlsUrl}';
    
    console.log('[HLS Player] Loading:', videoSrc);
    
    if (Hls.isSupported()) {
      const hls = new Hls({
        debug: false,
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 90
      });
      
      hls.loadSource(videoSrc);
      hls.attachMedia(video);
      
      hls.on(Hls.Events.MANIFEST_PARSED, function() {
        console.log('[HLS Player] Manifest parsed, starting playback');
        video.play().catch(e => {
          console.error('[HLS Player] Auto-play failed:', e);
          // Muted autoplay thường được allow
          video.muted = true;
          video.play();
        });
      });
      
      hls.on(Hls.Events.ERROR, function(event, data) {
        console.error('[HLS Player] Error:', data);
        if (data.fatal) {
          switch(data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              console.log('[HLS Player] Network error, trying to recover...');
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              console.log('[HLS Player] Media error, trying to recover...');
              hls.recoverMediaError();
              break;
            default:
              console.error('[HLS Player] Fatal error, cannot recover');
              document.getElementById('video-container').innerHTML = 
                '<div class="error">Cannot load video stream<br>Check camera connection</div>';
              break;
          }
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      // Native HLS support (Safari)
      video.src = videoSrc;
      video.addEventListener('loadedmetadata', function() {
        console.log('[HLS Player] Native HLS loaded');
        video.play();
      });
    } else {
      document.getElementById('video-container').innerHTML = 
        '<div class="error">HLS is not supported in this browser</div>';
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: widget.viewId);
  }
}
