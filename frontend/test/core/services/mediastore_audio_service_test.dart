import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/services/mediastore_audio_service.dart';

void main() {
  group('MediaStoreAudioService.buildFolderTree', () {
    test('construye árbol plano cuando los archivos no tienen subcarpetas', () {
      final files = [
        const CopiedAudioFile(
          path: '/dummy/kick.wav',
          relativeSubPath: '',
          name: 'kick.wav',
        ),
        const CopiedAudioFile(
          path: '/dummy/snare.wav',
          relativeSubPath: '',
          name: 'snare.wav',
        ),
      ];

      final tree = MediaStoreAudioService.buildFolderTree('Descargas', files);

      expect(tree.name, equals('Descargas'));
      expect(tree.audioFiles.length, equals(2));
      expect(tree.subfolders, isEmpty);
      expect(tree.totalAudioCount, equals(2));
    });

    test('construye árbol jerárquico recursivo con múltiples niveles', () {
      final files = [
        const CopiedAudioFile(
          path: '/dummy/root.wav',
          relativeSubPath: '',
          name: 'root.wav',
        ),
        const CopiedAudioFile(
          path: '/dummy/Drums/Kicks/kick1.wav',
          relativeSubPath: 'Drums/Kicks',
          name: 'kick1.wav',
        ),
        const CopiedAudioFile(
          path: '/dummy/Drums/Snares/snare1.wav',
          relativeSubPath: 'Drums/Snares',
          name: 'snare1.wav',
        ),
        const CopiedAudioFile(
          path: '/dummy/Vocals/drop.mp3',
          relativeSubPath: 'Vocals',
          name: 'drop.mp3',
        ),
      ];

      final tree = MediaStoreAudioService.buildFolderTree('Mi Biblioteca', files);

      expect(tree.name, equals('Mi Biblioteca'));
      expect(tree.audioFiles.length, equals(1));
      expect(tree.audioFiles.first.path, equals('/dummy/root.wav'));
      expect(tree.subfolders.length, equals(2)); // Drums, Vocals
      expect(tree.totalAudioCount, equals(4));

      final drums = tree.subfolders.firstWhere((f) => f.name == 'Drums');
      expect(drums.audioFiles, isEmpty);
      expect(drums.subfolders.length, equals(2)); // Kicks, Snares
      expect(drums.totalAudioCount, equals(2));

      final kicks = drums.subfolders.firstWhere((f) => f.name == 'Kicks');
      expect(kicks.audioFiles.length, equals(1));
      expect(kicks.audioFiles.first.path, equals('/dummy/Drums/Kicks/kick1.wav'));

      final vocals = tree.subfolders.firstWhere((f) => f.name == 'Vocals');
      expect(vocals.audioFiles.length, equals(1));
      expect(vocals.audioFiles.first.path, equals('/dummy/Vocals/drop.mp3'));
    });

    test('maneja lista vacía correctamente', () {
      final tree = MediaStoreAudioService.buildFolderTree('Vacio', []);

      expect(tree.name, equals('Vacio'));
      expect(tree.audioFiles, isEmpty);
      expect(tree.subfolders, isEmpty);
      expect(tree.totalAudioCount, equals(0));
    });

    test('AudioFolderEntry.displayName extrae el último segmento', () {
      const entry = AudioFolderEntry(
        path: '/storage/emulated/0/Download/DJ Sets',
        volume: 'external_primary',
        count: 5,
        totalBytes: 1024,
      );
      expect(entry.displayName, equals('DJ Sets'));
    });
  });
}
