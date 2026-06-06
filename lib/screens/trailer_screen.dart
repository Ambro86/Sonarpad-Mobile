import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrailerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const TrailerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<TrailerScreen> createState() => _TrailerScreenState();
}

class _TrailerScreenState extends State<TrailerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Converte il link standard in un link di tipo "embed" per nascondere distrazioni (commenti, ecc.)
    String embedUrl = widget.videoUrl;
    if (widget.videoUrl.contains('watch?v=')) {
      final videoId = widget.videoUrl.split('watch?v=')[1].split('&').first;
      embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1&rel=0';
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trailer: ${widget.title}'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
