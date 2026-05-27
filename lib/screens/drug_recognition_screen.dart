import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/app_logger.dart';

class DrugRecognitionScreen extends StatefulWidget {
  const DrugRecognitionScreen({super.key});

  @override
  State<DrugRecognitionScreen> createState() => _DrugRecognitionScreenState();
}

class _DrugRecognitionScreenState extends State<DrugRecognitionScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final FlutterTts _tts = FlutterTts();

  List<CameraDescription> _cameras = [];
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _hasPermission = false;
  
  String _statusText = 'Inizializzazione...';
  String? _recognizedDrug;
  String? _spokenExpiry;
  String? _expiryDateText;

  Timer? _instructionTimer;
  DateTime _lastDetectionTime = DateTime.now();
  int _noTextCount = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _checkPermissionsAndInit();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _checkPermissionsAndInit() async {
    AppLogger.log('DrugRecognition: Avvio richiesta permessi...');
    final status = await Permission.camera.request();
    if (status.isGranted) {
      AppLogger.log('DrugRecognition: Permesso fotocamera accordato.');
      setState(() => _hasPermission = true);
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Avvia con la posteriore di default se disponibile
        final backCamera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
        await _initCamera(backCamera);
      } else {
        setState(() => _statusText = 'Nessuna fotocamera trovata.');
        _speak('Nessuna fotocamera trovata sul dispositivo.');
      }
    } else {
      setState(() {
        _hasPermission = false;
        _statusText = 'Permesso fotocamera negato. Abilitalo nelle impostazioni.';
      });
      _speak('Permesso fotocamera negato. Per favore abilitalo nelle impostazioni di sistema.');
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      AppLogger.log('DrugRecognition: Fotocamera inizializzata con successo.');
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      _startAnalysis();
      _startInstructionLoop();
    } catch (e) {
      setState(() => _statusText = 'Errore inizializzazione fotocamera');
      _speak('Errore durante l\'avvio della fotocamera');
    }
  }

  void _startInstructionLoop() {
    _instructionTimer?.cancel();
    _speak('Inquadra la scatola di un farmaco. Tieni la fotocamera a circa 20 centimetri.');
    _instructionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_recognizedDrug != null) return;

      final now = DateTime.now();
      if (now.difference(_lastDetectionTime).inSeconds > 2) {
        _noTextCount++;
        if (_noTextCount % 2 == 0) {
           _speak('Non vedo testo. Sposta o allontana la scatola per mettere a fuoco.');
        }
      }
    });
  }

  void _startAnalysis() {
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessing || _recognizedDrug != null) return;
      _isProcessing = true;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        _processText(recognizedText);
      } catch (e) {
        // Ignora piccoli errori di frame
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _processText(RecognizedText recognizedText) {
    if (recognizedText.text.isEmpty) {
      return;
    }

    _lastDetectionTime = DateTime.now();
    _noTextCount = 0; // reset
    AppLogger.log('DrugRecognition: Analisi di un blocco di testo...');

    // Analisi euristica: cerca un blocco che possa essere il nome di un farmaco.
    // Ignoriamo i blocchi troppo corti, le date di scadenza o "Lotto".
    String? possibleDrug;
    for (TextBlock block in recognizedText.blocks) {
      final text = block.text.trim();
      final lines = text.split('\n');
      
      for (var line in lines) {
        final upperLine = line.toUpperCase();
        if (upperLine.contains('SCAD') || upperLine.contains('EXP')) {
          AppLogger.log('DrugRecognition: Riga scadenza trovata -> "$line"');
          if (_spokenExpiry != line) {
            _spokenExpiry = line;
            if (mounted) {
              setState(() => _expiryDateText = line);
            }
            _speak('Questo farmaco scade il $line. Attenzione, la data è generata da un algoritmo, potrebbe non essere sempre preciso.');
          }
          continue;
        }

        if (upperLine.contains('LOTTO') || upperLine.contains('L.')) {
          AppLogger.log('DrugRecognition: Ignorata riga probabile lotto -> "$line"');
          continue;
        }
        
        // Cerca parole che sembrino nomi validi: almeno 4 lettere
        // Evitiamo cifre secche, cerchiamo lettere.
        if (line.length > 4 && RegExp(r'[A-Za-z]{4,}').hasMatch(line)) {
          AppLogger.log('DrugRecognition: Trovato probabile farmaco -> "$line"');
          // Prendi la riga migliore (più lunga o con un formato da farmaco)
          if (possibleDrug == null || line.length > possibleDrug.length) {
            possibleDrug = line;
          }
        }
      }
    }

    if (possibleDrug != null && _recognizedDrug == null) {
      AppLogger.log('DrugRecognition: FARMCO SELEZIONATO: "$possibleDrug"');
      // Annuncia il possibile farmaco
      _speak('Vedo testo, potrebbe essere: $possibleDrug. Premi il pulsante per leggere le informazioni, oppure continua a inquadrare.');
      setState(() {
        _recognizedDrug = possibleDrug;
        _statusText = 'Trovato testo: $possibleDrug';
      });

      // Riavvia l'analisi dopo 4 secondi per cercare risultati migliori se l'utente non fa nulla
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _recognizedDrug == possibleDrug) {
          setState(() => _recognizedDrug = null); // Riprende la scansione
        }
      });
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = sensorOrientation;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: Platform.isAndroid ? image.planes[0].bytes : image.planes[0].bytes, // Note: per BGRA basta il piano 0
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    
    final currentDirection = _cameraController?.description.lensDirection;
    final newCamera = _cameras.firstWhere(
      (c) => c.lensDirection != currentDirection,
      orElse: () => _cameras.first,
    );
    
    setState(() {
      _isCameraInitialized = false;
      _recognizedDrug = null;
    });
    
    await _speak('Cambio fotocamera');
    await _initCamera(newCamera);
  }

  @override
  void dispose() {
    _instructionTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _textRecognizer.close();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riconosci il Farmaco'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized && _cameraController != null)
                    CameraPreview(_cameraController!)
                  else if (_hasPermission)
                    const Center(child: CircularProgressIndicator())
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Permesso fotocamera negato.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  
                  // Overlay testo e info
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _statusText,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          if (_expiryDateText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Scadenza letta: $_expiryDateText\n(Attenzione: potrebbe non essere preciso)',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottone cambio fotocamera
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _switchCamera,
                      tooltip: 'Cambia fotocamera anteriore o posteriore',
                      child: const Icon(Icons.flip_camera_ios),
                    ),
                  )
                ],
              ),
            ),
            
            // Area bottoni azione
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _recognizedDrug != null
                      ? () {
                          _tts.stop();
                          Navigator.pop(context, _recognizedDrug);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 60),
                  ),
                  icon: const Icon(Icons.search),
                  label: Text(
                    _recognizedDrug != null
                        ? 'Leggi informazioni: $_recognizedDrug'
                        : 'Inquadra una scatola per continuare...',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
