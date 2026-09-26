import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:bdj_studio_sample_pad/core/platform/device_tier.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';

import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/macros/data/models/macro_model.dart';

import '../../helpers/isar_test_helper.dart';
import '../../helpers/mock_audio_engine.dart';

Future<Isar> _openIsar(Directory tempRoot) async {
  final dbDir = Directory(p.join(tempRoot.path, 'db'))..createSync(recursive: true);
  return Isar.open(
    [
      WorkspaceModelSchema,
      PageModelSchema,
      PadModelSchema,
      SampleModelSchema,
      GenreModelSchema,
      FolderModelSchema,
      MacroModelSchema,
    ],
    directory: dbDir.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late MockAudioEngine mockAudio;

  setUpAll(() async {
    await ensureTestIsarInitialized();
  });

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('preload_test');
    mockAudio = MockAudioEngine();
  });

  tearDown(() async {
    DeviceTierDetector.updateOverride(PerformanceOverride.auto);
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  group('Next page preloading (T27)', () {
    test('low and mid tier profiles do NOT preload next pages', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      final workspace = WorkspaceModel()
        ..name = 'Test Set'
        ..createdAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.workspaceModels.put(workspace);
      });

      // Configure high cache budget room (low usage)
      mockAudio.mockCacheUsageRatio = 0.2;

      final currentPads = [
        const PadEntity(
          id: '1',
          index: 0,
          type: PadType.folder,
          targetPageIndex: 1000,
        ),
      ];

      // Test Low Tier (powerSave)
      DeviceTierDetector.updateOverride(PerformanceOverride.powerSave);
      expect(DeviceTierDetector.current, equals(DeviceTier.low));

      await PadPageNotifier.maybePreloadNextPages(
        currentEntities: currentPads,
        currentPageIndex: 0,
        workspace: workspace,
        audioEngine: mockAudio,
      );

      expect(mockAudio.preloadIdleCalls, isEmpty);

      // Test Mid Tier (balanced)
      DeviceTierDetector.updateOverride(PerformanceOverride.balanced);
      expect(DeviceTierDetector.current, equals(DeviceTier.mid));

      await PadPageNotifier.maybePreloadNextPages(
        currentEntities: currentPads,
        currentPageIndex: 0,
        workspace: workspace,
        audioEngine: mockAudio,
      );

      expect(mockAudio.preloadIdleCalls, isEmpty);
    });

    test('does NOT preload when cache weight exceeds 70% of budget', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      final workspace = WorkspaceModel()
        ..name = 'Test Set'
        ..createdAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.workspaceModels.put(workspace);
      });

      DeviceTierDetector.updateOverride(PerformanceOverride.performance);
      expect(DeviceTierDetector.current, equals(DeviceTier.high));

      final currentPads = [
        const PadEntity(
          id: '1',
          index: 0,
          type: PadType.folder,
          targetPageIndex: 1000,
        ),
      ];

      // Cache usage at 71% (> 70%)
      mockAudio.mockCacheUsageRatio = 0.71;

      await PadPageNotifier.maybePreloadNextPages(
        currentEntities: currentPads,
        currentPageIndex: 0,
        workspace: workspace,
        audioEngine: mockAudio,
      );

      expect(mockAudio.preloadIdleCalls, isEmpty);

      // Cache usage at 95%
      mockAudio.mockCacheUsageRatio = 0.95;

      await PadPageNotifier.maybePreloadNextPages(
        currentEntities: currentPads,
        currentPageIndex: 0,
        workspace: workspace,
        audioEngine: mockAudio,
      );

      expect(mockAudio.preloadIdleCalls, isEmpty);
    });

    test('collects destination folder pads and next root page pads up to 32 items', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      DeviceTierDetector.updateOverride(PerformanceOverride.performance);
      mockAudio.mockCacheUsageRatio = 0.40; // 40% < 70%

      final workspace = WorkspaceModel()
        ..name = 'Test Set'
        ..createdAt = DateTime.now();
      final root0 = PageModel()
        ..pageIndex = 0
        ..parentPageId = null;

      final root1 = PageModel()
        ..pageIndex = 1
        ..parentPageId = null;

      final folderPage = PageModel()
        ..pageIndex = 1000
        ..parentPageId = 0;

      final folderPads = <PadModel>[];
      for (int i = 0; i < 20; i++) {
        final pad = PadModel()
          ..padId = i
          ..label = 'Folder Pad $i'
          ..colorHex = 0xFF00FF00
          ..samplePath = 'folder_sample_$i.wav';
        folderPads.add(pad);
      }

      final root1Pads = <PadModel>[];
      for (int i = 0; i < 20; i++) {
        final pad = PadModel()
          ..padId = i
          ..label = 'Root1 Pad $i'
          ..colorHex = 0xFF00FF00
          ..samplePath = 'root1_sample_$i.wav'
          ..reverse = (i == 0); // Reverse pad needs random access
        root1Pads.add(pad);
      }

      await isar.writeTxn(() async {
        await isar.workspaceModels.put(workspace);

        root0.workspace.value = workspace;
        root1.workspace.value = workspace;
        folderPage.workspace.value = workspace;
        await isar.pageModels.putAll([root0, root1, folderPage]);
        await root0.workspace.save();
        await root1.workspace.save();
        await folderPage.workspace.save();

        folderPage.parentPageId = root0.id;
        await isar.pageModels.put(folderPage);

        for (final pad in folderPads) {
          pad.page.value = folderPage;
        }
        await isar.padModels.putAll(folderPads);
        for (final pad in folderPads) {
          await pad.page.save();
        }

        for (final pad in root1Pads) {
          pad.page.value = root1;
        }
        await isar.padModels.putAll(root1Pads);
        for (final pad in root1Pads) {
          await pad.page.save();
        }
      });

      // Current page is root0 with a folder pointing to folderPage (1000)
      final currentPads = [
        const PadEntity(
          id: '1',
          index: 0,
          type: PadType.folder,
          targetPageIndex: 1000,
        ),
      ];

      // Mark the first pad of folderPage as already loaded to test deduplication
      final firstPadId = folderPads.first.id.toString();
      final loadedPads = <String>{firstPadId};
      final testEngine = _FilteringMockAudioEngine(mockAudio, loadedPads);

      await PadPageNotifier.maybePreloadNextPages(
        currentEntities: currentPads,
        currentPageIndex: 0,
        workspace: workspace,
        audioEngine: testEngine,
        maxPads: 32,
      );

      expect(mockAudio.preloadIdleCalls.length, equals(1));
      final requests = mockAudio.preloadIdleCalls.first as List;

      // Max 32 pads limit respected
      expect(requests.length, equals(32));

      // Loaded first pad was skipped: first request is the second pad
      expect(requests.first.id, equals(folderPads[1].id.toString()));

      // 19 pads from folderPage + 13 pads from root1 = 32
      expect(requests[18].id, equals(folderPads[19].id.toString()));
      expect(requests[19].id, equals(root1Pads[0].id.toString()));
      expect(requests[19].needsRandomAccess, isTrue); // root1Pads[0] had reverse = true
      expect(requests[20].needsRandomAccess, isFalse);
    });
  });
}

class _FilteringMockAudioEngine extends MockAudioEngine {
  _FilteringMockAudioEngine(this.delegate, this.loadedIds);
  final MockAudioEngine delegate;
  final Set<String> loadedIds;

  @override
  double get cacheUsageRatio => delegate.mockCacheUsageRatio;

  @override
  bool isLoaded(String id) => loadedIds.contains(id);

  @override
  void preloadIdle(dynamic requests) {
    delegate.preloadIdle(requests);
  }
}
