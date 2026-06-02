import 'package:flutter/material.dart';
import 'orari_apertura_results_screen.dart';

class OrariAperturaSearchScreen extends StatefulWidget {
  const OrariAperturaSearchScreen({super.key});

  @override
  State<OrariAperturaSearchScreen> createState() =>
      _OrariAperturaSearchScreenState();
}

class _OrariAperturaSearchScreenState extends State<OrariAperturaSearchScreen> {
  final TextEditingController _cosaController = TextEditingController();
  final TextEditingController _doveController = TextEditingController();
  int _distanza = 30;
  final List<int> _distanzePossibili = [5, 10, 15, 20, 25, 30];

  void _performSearch() {
    final cosa = _cosaController.text.trim();
    final dove = _doveController.text.trim();
    if (cosa.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrariAperturaResultsScreen(
          cosa: cosa,
          dove: dove,
          distanza: _distanza,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cosaController.dispose();
    _doveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Orari di Apertura',
          semanticsLabel: 'Ricerca orari di apertura',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _cosaController,
              decoration: InputDecoration(
                labelText: 'Cosa (es. farmacie, cinema, bar, ecc)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _doveController,
                    decoration: InputDecoration(
                      labelText: 'Dove (es. torino)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _performSearch(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButton<int>(
                    value: _distanza,
                    isExpanded: true,
                    items: _distanzePossibili.map((d) {
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text('$d km'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _distanza = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _performSearch,
              icon: Icon(Icons.search),
              label: Text('Cerca'),
            ),
          ],
        ),
      ),
    );
  }
}
