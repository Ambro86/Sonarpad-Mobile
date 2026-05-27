import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:sonarpad_mobile_starter/services/aifa_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../utils/app_logger.dart';
import '../utils/gs1_parser.dart';
import '../services/aifa_service.dart';

class DrugRecognitionScreen extends StatefulWidget {
  const DrugRecognitionScreen({super.key});

  @override
  State<DrugRecognitionScreen> createState() => _DrugRecognitionScreenState();
}

class _DrugRecognitionScreenState extends State<DrugRecognitionScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
  final ObjectDetector _objectDetector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: false,
      multipleObjects: false,
    ),
  );
  final FlutterTts _flutterTts = FlutterTts();
  final AifaService _aifaService = AifaService();

  List<CameraDescription> _cameras = [];
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _hasPermission = false;
  bool _isRearCamera = true;
  
  String _statusText = 'Inizializzazione fotocamera...';
  String? _recognizedDrug;
  DrugMatchLevel? _matchLevel;
  
  // Timer e Logica Ibrida
  DateTime _startTime = DateTime.now();
  bool _ocrFallbackActive = false;
  bool _scanCompleted = false;

  // Multi-frame stabilization
  String? _lastBarcodeRawValue;
  int _barcodeConsecutiveReads = 0;
  DateTime? _lastBarcodeTime;

  String? _lastOcrCandidate;
  int _ocrConsecutiveReads = 0;
  DateTime? _lastOcrTime;
  
  DateTime? _lastFrameTime;
  DateTime? _lastEdgeWarningTime;

  Timer? _instructionTimer;

  @override
  void initState() {
    super.initState();
    _initTts();
    _checkPermissionsAndInit();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("it-IT");
    await _flutterTts.setSpeechRate(0.5);
    if (Platform.isIOS) {
       await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ],
        IosTextToSpeechAudioMode.defaultMode
      );
    }
  }

  Future<void> _checkPermissionsAndInit() async {
    AppLogger.log('DrugRecognition: Avvio richiesta permessi...');
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
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
      _speak('Permesso fotocamera negato.');
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      try {
        await _cameraController!.setFlashMode(FlashMode.torch);
      } catch (e) {
        AppLogger.log('DrugRecognition: Torcia non supportata.');
      }
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
      _resetScanState();
      _startAnalysis();
    } catch (e) {
      setState(() => _statusText = 'Errore inizializzazione fotocamera');
      _speak('Errore durante l\'avvio della fotocamera');
    }
  }

  void _resetScanState() {
    if (_recognizedDrug != null) return;
    setState(() {
      _recognizedDrug = null;
      _matchLevel = null;
      _scanCompleted = false;
      _statusText = 'Inquadra codice a barre o etichetta...';
    });

    _startTime = DateTime.now();
    _ocrFallbackActive = false;
    _scanCompleted = false;
    
    _lastBarcodeRawValue = null;
    _barcodeConsecutiveReads = 0;
    _lastBarcodeTime = null;
    
    _lastOcrCandidate = null;
    _ocrConsecutiveReads = 0;
    _lastOcrTime = null;

    _startInstructionLoop();
  }

  void _startInstructionLoop() {
    _instructionTimer?.cancel();
    _speak('Inquadra la scatola del farmaco. Allontana o avvicina il telefono finché non ti dico ferma.');
    
    _instructionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_recognizedDrug != null || _scanCompleted) {
        timer.cancel();
        return;
      }
      
      final elapsed = DateTime.now().difference(_startTime).inSeconds;
      if (elapsed > 10) {
        _speak('Assicurati di avere abbastanza luce e muovi lentamente la confezione.');
      }
    });
  }

  void _startAnalysis() {
    _cameraController!.startImageStream((CameraImage image) async {
      final now = DateTime.now();
      // Drop late frames
      if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < 150) {
        return; 
      }
      
      if (_isProcessing || _recognizedDrug != null || _scanCompleted) return;
      
      _isProcessing = true;
      _lastFrameTime = now;

      try {
        final inputImage = _inputImageFromCameraImage(image);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        final objects = await _objectDetector.processImage(inputImage);
        
        if (objects.isNotEmpty) {
           final object = objects.first;
           final rect = object.boundingBox;
           
           bool isRotated = inputImage.metadata!.rotation == InputImageRotation.rotation90deg ||
                            inputImage.metadata!.rotation == InputImageRotation.rotation270deg;
           
           double imgW = isRotated ? inputImage.metadata!.size.height : inputImage.metadata!.size.width;
           double imgH = isRotated ? inputImage.metadata!.size.width : inputImage.metadata!.size.height;
           
           double margin = 10.0; // Tolleranza ridotta per permettere alla scatola di stare comodamente nell'inquadratura
           List<String> warnings = [];
           if (rect.left <= margin) warnings.add("sinistro");
           if (rect.right >= imgW - margin) warnings.add("destro");
           if (rect.top <= margin) warnings.add("superiore");
           if (rect.bottom >= imgH - margin) warnings.add("inferiore");
           
           if (warnings.isNotEmpty) {
               if (_lastEdgeWarningTime == null || now.difference(_lastEdgeWarningTime!).inMilliseconds > 2500) {
                   _lastEdgeWarningTime = now;
                   String edgeText = warnings.join(" e ");
                   _speak("Bordo $edgeText non visibile");
               }
           } else {
               // Oggetto centrato
               double area = rect.width * rect.height;
               double totalArea = imgW * imgH;
               if (area > totalArea * 0.05) { // Ridotto al 5% per facilitare lo scatto anche se si allontana il telefono
                   _scanCompleted = true;
                   _speak("Ferma!");
                   HapticFeedback.heavyImpact();
                   await _captureAndAnalyze();
                   return;
               }
           }
        }
        
      } catch (e) {
        // Ignora piccoli errori di frame
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<void> _captureAndAnalyze() async {
      try {
          if (_cameraController!.value.isStreamingImages) {
              await _cameraController!.stopImageStream();
          }
          if (!mounted) return;
          setState(() => _statusText = 'Analisi in corso...');
          
          final XFile file = await _cameraController!.takePicture();
          final inputImage = InputImage.fromFilePath(file.path);
          
          // 1. Priorità Barcode/DataMatrix
          final barcodes = await _barcodeScanner.processImage(inputImage);
          if (barcodes.isNotEmpty) {
              final bestBarcode = barcodes.first;
              final rawValue = bestBarcode.rawValue ?? bestBarcode.displayValue ?? '';
              if (rawValue.isNotEmpty) {
                  final parsed = Gs1Parser.parse(rawValue);
                  if (parsed.hasValidAic) {
                      _speak('Codice letto. Cerco il farmaco.');
                      await _searchDrugsByQuery(parsed.aic!, isGtin: false);
                      return;
                  } else if (parsed.gtin != null) {
                      _speak('GTIN letto. Verifico.');
                      await _searchDrugsByQuery(parsed.gtin!, isGtin: true);
                      return;
                  }
              }
          }
          
          // 2. Fallback OCR
          final recognizedText = await _textRecognizer.processImage(inputImage);
          if (recognizedText.text.isNotEmpty) {
              String? possibleDrug;
              for (TextBlock block in recognizedText.blocks) {
                  final text = block.text.trim();
                  final lines = text.split('\n');
                  
                  for (var line in lines) {
                      final upperLine = line.toUpperCase();
                      if (upperLine.contains('SCAD') || upperLine.contains('EXP')) continue;
                      if (upperLine.contains('LOTTO') || upperLine.contains('L.')) continue;
                      
                      if (line.length > 4 && RegExp(r'[A-Za-z]{4,}').hasMatch(line)) {
                          if (possibleDrug == null || line.length > possibleDrug.length) {
                              possibleDrug = line;
                          }
                      }
                  }
              }
              
              if (possibleDrug != null) {
                  final normalizedCandidate = _normalizeOcrString(possibleDrug);
                  if (mounted) setState(() => _statusText = 'Ricerca per "$normalizedCandidate"...');
                  await _searchDrugsByQuery(normalizedCandidate, isFuzzy: true);
                  return;
              }
          }
          
          // Fallback if nothing found
          _speak("Non ho riconosciuto nulla, riproviamo.");
          _resetScanState();
          await _initCamera(_cameraController!.description); // riavvia stream
          
      } catch (e) {
          AppLogger.log('DrugRecognition: Errore captureAndAnalyze: $e');
          _resetScanState();
          if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
             await _initCamera(_cameraController!.description);
          }
      }
  }

  String _normalizeOcrString(String raw) {
    String norm = raw.toUpperCase();
    norm = norm.replaceAll('1', 'I');
    norm = norm.replaceAll('L', 'I');
    norm = norm.replaceAll('0', 'O');
    norm = norm.replaceAll(RegExp(r'[^A-Z]'), '');
    return norm;
  }

  Future<void> _searchDrugsByQuery(String query, {bool isFuzzy = false, bool isGtin = false}) async {
    try {
      late DrugMatch resultMatch;
      if (isFuzzy) {
        resultMatch = await _aifaService.searchByOcrFuzzy(query);
      } else if (isGtin) {
        resultMatch = await _aifaService.searchByGtin(query);
      } else {
        resultMatch = await _aifaService.searchByAic(query, onNetworkFallback: () {
          _speak('Codice AIC letto, provo aggiornamento online.');
        });
      }

      if (resultMatch.level != DrugMatchLevel.unknown && resultMatch.drug != null) {
        final drugName = resultMatch.drug!.denominazione;
        setState(() {
          _recognizedDrug = drugName;
          _statusText = 'Trovato: $drugName';
          _matchLevel = resultMatch.level;
        });
        
        switch (resultMatch.level) {
          case DrugMatchLevel.confirmed:
            _speak('Identificazione confermata dal database locale: $drugName.');
            break;
          case DrugMatchLevel.strong:
            _speak('Ho trovato un codice prodotto associato a $drugName. Verifica prima di procedere.');
            break;
          case DrugMatchLevel.possible:
            _speak('Possibile farmaco: $drugName. Conferma solo se il nome corrisponde alla confezione. Puoi ripetere la scansione o cercare manualmente.');
            break;
          case DrugMatchLevel.unknown:
            break;
        }
        
        // Se l'utente non conferma in 8 sec, sblocchiamo per continuare a cercare
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted && _recognizedDrug == drugName && _matchLevel != DrugMatchLevel.possible) {
            _resetScanState();
          }
        });
      } else {
        // Nessun risultato
        AppLogger.log('DrugRecognition: Nessun risultato AIFA trovato.');
        if (!isFuzzy && !isGtin) {
          _speak('Codice AIC letto, ma non lo trovo. Controlla la scatola o chiedi al medico.');
        }
        _resetScanState();
        if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
           await _initCamera(_cameraController!.description);
        }
      }
    } catch (e) {
      AppLogger.log('DrugRecognition: Errore API AIFA -> $e');
      _resetScanState();
    }
  }

  Future<void> _showDatabaseInfo() async {
    try {
      final meta = await AifaCacheManager().getDatabaseMetadata();
      final version = meta['aifa_dataset_version'] ?? 'Sconosciuta';
      final syncStr = meta['last_successful_sync_at'];
      
      String syncMsg = 'Oggi (Seed Base)';
      bool isOld = false;
      if (syncStr != null) {
        final syncDate = DateTime.tryParse(syncStr);
        if (syncDate != null) {
          syncMsg = '${syncDate.day}/${syncDate.month}/${syncDate.year}';
          if (DateTime.now().difference(syncDate).inDays > 30) {
            isOld = true;
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Informazioni Database'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fonte dati: Informazioni pubbliche AIFA.'),
                const SizedBox(height: 8),
                Text('Ultimo aggiornamento: $syncMsg'),
                const SizedBox(height: 8),
                Text('Versione dataset: $version'),
                if (isOld) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Avviso: Database non aggiornato da più di 30 giorni. Alcuni farmaci recenti potrebbero non essere riconosciuti.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Disclaimer: Questo sistema è un supporto assistivo per identificare la confezione e non sostituisce il controllo medico, la verifica del farmacista o l\'attenta lettura dell\'etichetta.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile leggere le informazioni del database.')));
      }
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
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
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
      _isRearCamera = newCamera.lensDirection == CameraLensDirection.back;
    });
    
    await _speak('Cambio fotocamera');
    await _initCamera(newCamera);
  }

  Future<void> _saveDebugPhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      final file = await _cameraController!.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final targetPath = p.join(dir.path, 'Debug_Farmaco_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.saveTo(targetPath);
      AppLogger.log('DrugRecognition: Salvata foto debug in $targetPath');
      _speak('Foto salvata nei documenti per debug');
      
      _isProcessing = false;
      _startAnalysis();
    } catch(e) {
      AppLogger.log('DrugRecognition: Errore foto debug: $e');
    }
  }

  @override
  void dispose() {
    _instructionTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    _objectDetector.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riconosci il Farmaco'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Informazioni Database',
            onPressed: _showDatabaseInfo,
          ),
        ],
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
                  
                  Positioned(
                    top: 16,
                    left: 60,
                    right: 60,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  Positioned(
                    top: 16,
                    right: 16,
                    child: Semantics(
                      label: 'Fotocamera attiva: ${_isRearCamera ? "posteriore" : "anteriore"}. Doppio tap per invertire.',
                      button: true,
                      excludeSemantics: true,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _switchCamera,
                        child: const Icon(Icons.flip_camera_ios),
                      ),
                    ),
                  ),
                  
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Semantics(
                      label: 'Salva foto di debug nei documenti',
                      button: true,
                      excludeSemantics: true,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.redAccent,
                        onPressed: _saveDebugPhoto,
                        child: const Icon(Icons.bug_report),
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'Questo strumento non sostituisce il medico o il farmacista. Verifica sempre la corrispondenza con la confezione fisica.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: _matchLevel == DrugMatchLevel.possible
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, _recognizedDrug),
                            icon: const Icon(Icons.check_circle),
                            label: Text('Conferma: $_recognizedDrug'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetScanState,
                                child: const Text('Ripeti Scansione'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text('Cerca Manualmente'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _recognizedDrug != null
                            ? () {
                                Navigator.pop(context, _recognizedDrug);
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 60),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _recognizedDrug != null
                              ? 'Conferma: $_recognizedDrug'
                              : 'Inquadra codice o etichetta...',
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
