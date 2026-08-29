import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Una foto scattata in cantiere con la posizione, quando il dispositivo
/// riesce a darla.
final class CapturedPhoto {
  const CapturedPhoto({
    required this.fileName,
    required this.bytes,
    required this.capturedAt,
    this.latitude,
    this.longitude,
  });

  final String fileName;
  final Uint8List bytes;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
}

final class PhotoCapture {
  PhotoCapture([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Scatta o sceglie una foto e le allega la posizione.
  ///
  /// La posizione è un di più, non un requisito: sotto una chioma fitta il GPS
  /// non aggancia, e una foto senza coordinate vale comunque più di nessuna
  /// foto. Il permesso negato si comporta allo stesso modo.
  Future<CapturedPhoto?> capture({required bool fromCamera}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,

      // La foto viaggia dentro il database locale del dispositivo: a piena
      // risoluzione riempirebbe lo storage in una settimana di cantiere.
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) {
      return null;
    }

    final position = await _currentPosition();
    return CapturedPhoto(
      fileName: file.name,
      bytes: await file.readAsBytes(),
      capturedAt: DateTime.now().toUtc(),
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }

  Future<Position?> _currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on Object {
      return null;
    }
  }
}
