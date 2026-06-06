import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/italiaonline_service.dart';
import '../services/document_library_service.dart';

class ItaliaOnlineDetailScreen extends StatefulWidget {
  final DetailResponse detail;

  const ItaliaOnlineDetailScreen({super.key, required this.detail});

  @override
  State<ItaliaOnlineDetailScreen> createState() => _ItaliaOnlineDetailScreenState();
}

class _ItaliaOnlineDetailScreenState extends State<ItaliaOnlineDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    await _tts.setLanguage('it-IT');
    if (mounted) setState(() => _isPlaying = true);
    await _tts.speak(widget.detail.body);
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _launchUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $urlStr');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail.title),
        actions: [
          if (!_isPlaying)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Avvia lettura',
              onPressed: _speak,
            )
          else
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Ferma lettura',
              onPressed: _stop,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salva nei documenti',
            onPressed: () async {
              try {
                final doc = await DocumentLibraryService().createTextDocument(
                  name: '${detail.title}.txt',
                  content: detail.body,
                  isTemporary: false,
                );
                final lib = DocumentLibraryService();
                await lib.load();
                await lib.add(doc);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Salvato nei documenti!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore durante il salvataggio: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (detail.description != null && detail.description!.isNotEmpty) ...[
            Text(
              detail.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
          if (detail.category != null && detail.category!.isNotEmpty) ...[
            Text(
              'Categoria: ${detail.category}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
          ],
          if (detail.address != null || (detail.locality != null && detail.locality!.isNotEmpty)) ...[
            const Text(
              'Indirizzo:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (detail.address != null && detail.address!.isNotEmpty) Text(detail.address!),
            if (detail.locality != null && detail.locality!.isNotEmpty) Text(detail.locality!),
            const SizedBox(height: 16),
          ],
          if (detail.phones.isNotEmpty) ...[
            const Text(
              'Telefoni (tocca per chiamare):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...detail.phones.map((p) => ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(p),
                  onTap: () => _launchUrl('tel:$p'),
                )),
            const SizedBox(height: 16),
          ],
          if (detail.websites.isNotEmpty) ...[
            const Text(
              'Siti web (tocca per aprire):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...detail.websites.map((w) => ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(w),
                  onTap: () {
                    var url = w;
                    if (!url.startsWith('http')) {
                      url = 'https://$url';
                    }
                    _launchUrl(url);
                  },
                )),
            const SizedBox(height: 16),
          ],
          if (detail.emails.isNotEmpty) ...[
            const Text(
              'Email:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...detail.emails.map((e) => ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(e),
                  onTap: () => _launchUrl('mailto:$e'),
                )),
            const SizedBox(height: 16),
          ],
          if (detail.publicUrl != null && detail.publicUrl!.isNotEmpty) ...[
            const Text(
              'Scheda web:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Apri scheda originale'),
              onTap: () => _launchUrl(detail.publicUrl!),
            ),
          ],
        ],
      ),
    );
  }
}
