import 'package:flutter/material.dart';
import '../services/orari_apertura_service.dart';

class OrariAperturaDetailScreen extends StatefulWidget {
  final String title;
  final String detailUrl;

  const OrariAperturaDetailScreen({
    super.key,
    required this.title,
    required this.detailUrl,
  });

  @override
  State<OrariAperturaDetailScreen> createState() => _OrariAperturaDetailScreenState();
}

class _OrariAperturaDetailScreenState extends State<OrariAperturaDetailScreen> {
  final OrariAperturaService _orariService = OrariAperturaService();
  OrariDetailResult? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() async {
    final detail = await _orariService.getOrari(widget.detailUrl);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (detail == null) {
          _errorMessage = 'Impossibile caricare i dettagli o gli orari.';
        } else {
          _detail = detail;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(semanticsLabel: 'Caricamento orari in corso'))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 18)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _detail!.title.isNotEmpty ? _detail!.title : widget.title,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      if (_detail!.status.isNotEmpty)
                        Text(
                          _detail!.status,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                      SizedBox(height: 20),
                      if (_detail!.hours.isEmpty)
                        Text('Orari non disponibili o attività chiusa definitivamente.', style: TextStyle(fontSize: 18))
                      else
                        ..._detail!.hours.map((hourLine) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              hourLine,
                              style: TextStyle(fontSize: 18),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
