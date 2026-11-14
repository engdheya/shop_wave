import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads store and listing photos to private owner-scoped paths.
/// Firebase Storage rules enforce ownership and image MIME/size limits.
class FirebaseStorageRepository {
  FirebaseStorageRepository({FirebaseStorage? storage})
      : storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage storage;

  Future<String> uploadProductImage({
    required String storeId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _validateImage(bytes, contentType);
    final ref = storage.ref().child(
      'stores/$storeId/products/${_safeName(fileName)}',
    );
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadStoreImage({
    required String storeId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _validateImage(bytes, contentType);
    final ref = storage.ref().child(
      'stores/$storeId/assets/${_safeName(fileName)}',
    );
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  static void _validateImage(Uint8List bytes, String contentType) {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Image must be between 1 byte and 10 MB.');
    }
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(contentType)) {
      throw ArgumentError('Only JPEG, PNG, or WebP images are supported.');
    }
  }

  static String _safeName(String input) {
    final name = input
        .split('/')
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return name.isEmpty ? '${DateTime.now().millisecondsSinceEpoch}.jpg' : name;
  }
}
