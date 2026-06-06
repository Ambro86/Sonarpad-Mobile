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
    
    String videoId = '';
    if (widget.videoUrl.contains('watch?v=')) {
      videoId = widget.videoUrl.split('watch?v=')[1].split('&').first;
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
      );

    if (videoId.isNotEmpty) {
      _controller.loadRequest(Uri.parse('https://m.youtube.com/watch?v=$videoId'));
    } else {
      _controller.loadRequest(Uri.parse(widget.videoUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trailer: ${widget.title}'),
      ),
      backgroundColor: Colors.black,
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
