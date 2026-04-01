import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import '../config/chat_config.dart';
import '../utils/constants.dart';

/// Result of a successful image upload containing the full-resolution URL
/// and an optional compressed thumbnail URL.
class UploadedImage {
  const UploadedImage({required this.imageUrl, this.thumbnailUrl});

  final String imageUrl;
  final String? thumbnailUrl;
}

/// Firebase Storage service for the bws_chat module.
///
/// Handles image compression, thumbnail generation, upload, and deletion.
class StorageService {
  StorageService({
    FirebaseStorage? storage,
    ImageSettings? imageSettings,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _imageSettings = imageSettings ?? const ImageSettings();

  final FirebaseStorage _storage;
  final ImageSettings _imageSettings;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Compresses [imageFile], uploads both the compressed image and a smaller
  /// thumbnail to Firebase Storage under [roomId], and returns the download
  /// URLs.
  ///
  /// Throws a [StorageException] if the file is too large after compression, or
  /// a [FirebaseException] on upload failures.
  Future<UploadedImage> uploadChatImage({
    required String roomId,
    required File imageFile,
  }) async {
    _assertFileExists(imageFile);

    final fileName = _uniqueFileName(imageFile);

    // Compress the full-size image.
    final compressedBytes = await _compressImage(
      imageFile,
      maxDimension: _imageSettings.maxDimension,
      quality: _imageSettings.compressionQuality,
    );

    if (compressedBytes.length > _imageSettings.maxFileSizeBytes) {
      throw Exception(
        'Compressed image size (${compressedBytes.length} bytes) exceeds '
        'limit (${_imageSettings.maxFileSizeBytes} bytes).',
      );
    }

    // Generate thumbnail (256 px, quality 70).
    final thumbnailBytes = await _compressImage(
      imageFile,
      maxDimension: 256,
      quality: 70,
    );

    // Upload in parallel.
    final imagePath = StoragePaths.roomImage(roomId, fileName);
    final thumbPath =
        StoragePaths.roomImage(roomId, 'thumb_$fileName');

    final results = await Future.wait([
      _uploadBytes(imagePath, compressedBytes),
      _uploadBytes(thumbPath, thumbnailBytes),
    ]);

    return UploadedImage(
      imageUrl: results[0],
      thumbnailUrl: results[1],
    );
  }

  /// Deletes the image at [imageUrl] from Firebase Storage.
  /// Silently ignores [FirebaseException] with code `object-not-found`.
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _uploadBytes(String path, Uint8List bytes) async {
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = await ref.putData(bytes, metadata);
    return task.ref.getDownloadURL();
  }

  Future<Uint8List> _compressImage(
    File file, {
    required int maxDimension,
    required int quality,
  }) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Image compression failed for ${file.path}');
    }

    return result;
  }

  String _uniqueFileName(File file) {
    final ext = p.extension(file.path).isNotEmpty
        ? p.extension(file.path)
        : '.jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp$ext';
  }

  void _assertFileExists(File file) {
    if (!file.existsSync()) {
      throw FileSystemException('File does not exist', file.path);
    }
  }
}
