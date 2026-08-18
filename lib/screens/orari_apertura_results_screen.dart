import 'package:flutter/material.dart';
import '../services/orari_apertura_service.dart';
import 'orari_apertura_detail_screen.dart';

class OrariAperturaResultsScreen extends StatefulWidget {
  final String cosa;
  final String dove;
  final int distanza;

  const OrariAperturaResultsScreen({
    super.key,
    required this.cosa,
    required this.dove,
    required this.distanza,
  });

  @override
  State<OrariAperturaResultsScreen> createState() =>
      _OrariAperturaResultsScreenState();
}

class _OrariAperturaResultsScreenState
    extends State<OrariAperturaResultsScreen> {
  final OrariAperturaService _orariService = OrariAperturaService();
  List<OrariSearchResult> _results = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  void _performSearch() async {
    final results = await _orariService.search(
      cosa: widget.cosa,
      dove: widget.dove,
      distanza: widget.distanza,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results.isEmpty) {
          _errorMessage = 'Nessun risultato trovato per la ricerca.';
        } else {
          _results = results;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Risultati Ricerca'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Card(
                      child: ListTile(
                        title: Text(result.title,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (result.address.isNotEmpty)
                              Text(result.address,
                                  style: TextStyle(fontSize: 14)),
                            if (result.status.isNotEmpty)
                              Text(result.status,
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.blueGrey)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrariAperturaDetailScreen(
                                title: result.title,
                                detailUrl: result.url,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
