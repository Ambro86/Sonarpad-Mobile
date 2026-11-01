import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/document_item.dart';
import '../screens/translator_screen.dart' show TranslationDocumentPickerScreen;
import '../utils/app_logger.dart';
import '../utils/status_message.dart';
import 'cloud_file_picker_service.dart';
import 'document_library_service.dart';

/// Reuses the library picker and the existing device/cloud import path.
class MediaFilePicker {
  static Future<FilePickerResult?> pickFiles({
    required BuildContext context,
    required List<String> allowedExtensions,
    String? title,
    FileType type = FileType.custom,
    bool allowMultiple = false,
    bool withData = false,
    String? Function(String extension)? unsupportedFileMessage,
  }) async {
    final l10n = AppLocalizations.of(context);
    final fromLibrary = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title ?? l10n.openItem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.translationLibraryDocuments),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.audioDescriptionBrowseProject),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (!context.mounted || fromLibrary == null) return null;
    if (fromLibrary) {
      return pickFromDocuments(
        context: context,
        allowedExtensions: allowedExtensions,
        withData: withData,
      );
    }
    return CloudFilePicker.pickFiles(
      context: context,
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: withData,
      unsupportedFileMessage: unsupportedFileMessage,
    );
  }

  static Future<FilePickerResult?> pickFromDocuments({
    required BuildContext context,
    required List<String> allowedExtensions,
    bool withData = false,
  }) async {
    try {
      final library = DocumentLibraryService();
      final document = await Navigator.push<DocumentItem>(
        context,
        MaterialPageRoute(
          builder: (_) => TranslationDocumentPickerScreen(
            library: library,
            allowedExtensions: allowedExtensions,
          ),
        ),
      );
      if (!context.mounted || document == null) return null;
      final path = await library.resolveFilePath(document);
      final file = File(path);
      return FilePickerResult([
        PlatformFile(
          name: document.name,
          path: path,
          size: await file.length(),
          bytes: withData ? await file.readAsBytes() : null,
        ),
      ]);
    } catch (error) {
      await AppLogger.log('Media picker: library selection failed: $error');
      if (context.mounted) {
        showStatusMessage(
          context,
          AppLocalizations.of(context).technicalErrorGeneric,
        );
      }
      return null;
    }
  }
}
