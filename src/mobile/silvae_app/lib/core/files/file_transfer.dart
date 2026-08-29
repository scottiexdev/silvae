import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:silvae_api_client/silvae_api_client.dart';

/// Scelta e salvataggio di file. Un solo pacchetto copre entrambi i versi su
/// tutte le piattaforme: sul web il salvataggio diventa un download del
/// browser, sul telefono una finestra di sistema.
final class FileTransfer {
  const FileTransfer();

  Future<PickedFile?> pick() async {
    final file = await FilePicker.pickFile();
    if (file == null) {
      return null;
    }
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  Future<void> save(DownloadedFile file) async {
    await FilePicker.saveFile(
      fileName: file.fileName,
      bytes: Uint8List.fromList(file.bytes),
      mimeType: file.contentType,
    );
  }
}

final class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
