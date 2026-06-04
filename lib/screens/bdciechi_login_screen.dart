import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_settings_service.dart';
import '../services/bdciechi_service.dart';
import 'bdciechi_dashboard_screen.dart';

class BdCiechiLoginScreen extends StatefulWidget {
  const BdCiechiLoginScreen({super.key});

  @override
  State<BdCiechiLoginScreen> createState() => _BdCiechiLoginScreenState();
}

class _BdCiechiLoginScreenState extends State<BdCiechiLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _settings = AppSettingsService();
  final _bdCiechiService = BdCiechiService();

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    final username = await _settings.getBdCiechiUsername();
    final password = await _settings.getBdCiechiPassword();

    if (username.isNotEmpty && password.isNotEmpty) {
      _usernameController.text = username;
      _passwordController.text = password;
      await _doLogin(username, password);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _doLogin(String username, String password) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _bdCiechiService.identify(username, password);

      // Save credentials if successful
      await _settings.setBdCiechiUsername(username);
      await _settings.setBdCiechiPassword(password);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/bdciechi_dashboard'),
            builder: (_) => BdCiechiDashboardScreen(
              username: username,
              password: password,
              identifyResponse: response,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onLoginPressed() {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    if (user.isEmpty || pass.isEmpty) {
      setState(() {
        _errorMessage = 'Inserisci nome utente e password';
      });
      return;
    }
    _doLogin(user, pass);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accesso alla Biblioteca Digitale'),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Semantics(
                  label: 'Accesso in corso',
                  child: const CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Biblioteca dei Ciechi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome Utente',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _onLoginPressed(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _onLoginPressed,
                      child:
                          const Text('Accedi', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Iscrizione'),
                            content: const Text('Scegli dove vuoi iscriverti:'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  launchUrl(Uri.parse(
                                      'https://www.salottopertutti.it/login/signupform.asp'));
                                },
                                child: const Text(
                                    'Iscriviti a salottopertutti.it'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  launchUrl(Uri.parse(
                                      'https://www.bdciechi.it/iscrizione/'));
                                },
                                child: const Text('Iscriviti a bdciechi.it'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Annulla'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text(
                          'Iscriviti a Bdciechi o Salotto per tutti',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
