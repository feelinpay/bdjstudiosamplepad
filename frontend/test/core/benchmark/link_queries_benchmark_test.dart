import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_helper.dart';
import 'package:path/path.dart' as p;

import '../../helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/services/filesystem_sync_service.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';


Future<Isar> _openIsar(Directory tempRoot) {
  final dbDir = Directory(p.join(tempRoot.path, 'db'))..createSync(recursive: true);
  return Isar.open([
    WorkspaceModelSchema,
    PageModelSchema,
    PadModelSchema,
    SampleModelSchema,
    FolderModelSchema,
    GenreModelSchema,
  ], directory: dbDir.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    await ensureTestIsarInitialized();
  });

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('isar_link_bench_');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('T11 Equivalencia de consultas por Link vs Colección', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    // Crear 3 workspaces con páginas compartidas en índice (0 y páginas ocultas 1000..1002)
    final wsList = <WorkspaceModel>[];
    await isar.writeTxn(() async {
      for (int w = 1; w <= 3; w++) {
        final ws = WorkspaceModel()
          ..name = 'Workspace $w'
          ..createdAt = DateTime.now();
        await isar.workspaceModels.put(ws);
        wsList.add(ws);

        // Root page (index 0)
        final rootPage = PageModel()
          ..pageIndex = 0
          ..name = 'Root W$w'
          ..columns = 4
          ..rows = 4
          ..workspace.value = ws;
        await isar.pageModels.put(rootPage);
        await rootPage.workspace.save();

        for (int pIdx = 1000; pIdx <= 1002; pIdx++) {
          final hiddenPage = PageModel()
            ..pageIndex = pIdx
            ..name = 'Hidden W$w P$pIdx'
            ..columns = 4
            ..rows = 4
            ..parentPageId = rootPage.id
            ..workspace.value = ws;
          await isar.pageModels.put(hiddenPage);
          await hiddenPage.workspace.save();

          // Pads para cada página
          for (int p = 0; p < 8; p++) {
            final pad = PadModel()
              ..padId = (7 - p) // desordenado para probar sort
              ..label = 'W$w P$pIdx Pad $p'
              ..colorHex = 0xFF00FF00
              ..page.value = hiddenPage;
            await isar.padModels.put(pad);
            await pad.page.save();
          }
        }

        // Pads para root page
        for (int p = 0; p < 16; p++) {
          final pad = PadModel()
            ..padId = (15 - p) // orden inverso
            ..label = 'W$w Root Pad $p'
            ..colorHex = 0xFFFF0000
            ..page.value = rootPage;
          await isar.padModels.put(pad);
          await pad.page.save();
        }
      }
    });

    // 1. Probar equivalencia en búsqueda de páginas por Workspace
    for (final ws in wsList) {
      for (final testIdx in [0, 1000, 1001, 1002]) {
        // Consulta vieja (por colección)
        final oldPage = await isar.pageModels
            .filter()
            .workspace((q) => q.idEqualTo(ws.id))
            .pageIndexEqualTo(testIdx)
            .findFirst();

        // Consulta nueva (por link)
        final newPage = await ws.pages
            .filter()
            .pageIndexEqualTo(testIdx)
            .findFirst();

        expect(newPage, isNotNull);
        expect(oldPage, isNotNull);
        expect(newPage!.id, oldPage!.id);
        expect(newPage.name, oldPage.name);
        expect(newPage.pageIndex, oldPage.pageIndex);
        expect(newPage.workspace.value?.id, ws.id);

        // 2. Probar equivalencia en búsqueda de pads por página con orden sortByPadId()
        final oldPads = await isar.padModels
            .filter()
            .page((q) => q.idEqualTo(oldPage.id))
            .sortByPadId()
            .findAll();

        final newPads = await newPage.pads
            .filter()
            .sortByPadId()
            .findAll();

        expect(newPads.length, oldPads.length);
        for (int i = 0; i < oldPads.length; i++) {
          expect(newPads[i].id, oldPads[i].id);
          expect(newPads[i].padId, oldPads[i].padId);
          expect(newPads[i].label, oldPads[i].label);
          // Verificar que estén ordenados ascendentemente
          if (i > 0) {
            expect(newPads[i].padId > newPads[i - 1].padId, isTrue);
          }
        }
      }

      // 3. Probar equivalencia en páginas ocultas
      final oldHiddenPages = (await isar.pageModels
              .filter()
              .workspace((w) => w.idEqualTo(ws.id))
              .findAll())
          .where((p) => p.pageIndex >= 1000)
          .toList()
        ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

      final newHiddenPages = await ws.pages
          .filter()
          .pageIndexGreaterThan(999)
          .sortByPageIndex()
          .findAll();

      expect(newHiddenPages.length, oldHiddenPages.length);
      for (int i = 0; i < oldHiddenPages.length; i++) {
        expect(newHiddenPages[i].id, oldHiddenPages[i].id);
        expect(newHiddenPages[i].pageIndex, oldHiddenPages[i].pageIndex);
      }
    }
  });

  test('T11 Benchmark de rendimiento (200 consultas de página y 200 de pads)', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    // Cargar base con 5 workspaces y páginas/pads
    final wsList = <WorkspaceModel>[];
    await isar.writeTxn(() async {
      for (int w = 1; w <= 5; w++) {
        final ws = WorkspaceModel()
          ..name = 'Benchmark WS $w'
          ..createdAt = DateTime.now();
        await isar.workspaceModels.put(ws);
        wsList.add(ws);

        for (int pIdx = 0; pIdx < 10; pIdx++) {
          final page = PageModel()
            ..pageIndex = pIdx == 0 ? 0 : 1000 + pIdx
            ..name = 'WS $w Page $pIdx'
            ..columns = 4
            ..rows = 4
            ..workspace.value = ws;
          await isar.pageModels.put(page);
          await page.workspace.save();

          for (int p = 0; p < 16; p++) {
            final pad = PadModel()
              ..padId = (15 - p)
              ..label = 'W$w P$pIdx Pad $p'
              ..colorHex = 0xFFFFFFFF
              ..page.value = page;
            await isar.padModels.put(pad);
            await pad.page.save();
          }
        }
      }
    });

    final targetWs = wsList.first;
    final targetPage = await targetWs.pages.filter().pageIndexEqualTo(0).findFirst();
    expect(targetPage, isNotNull);

    // Warm-up
    for (int i = 0; i < 20; i++) {
      await isar.pageModels.filter().workspace((w) => w.idEqualTo(targetWs.id)).pageIndexEqualTo(0).findFirst();
      await targetWs.pages.filter().pageIndexEqualTo(0).findFirst();
      await isar.padModels.filter().page((q) => q.idEqualTo(targetPage!.id)).sortByPadId().findAll();
      await targetPage!.pads.filter().sortByPadId().findAll();
    }

    // Benchmark 200 Page Queries
    final swOldPage = Stopwatch()..start();
    for (int i = 0; i < 200; i++) {
      final pIdx = (i % 10 == 0) ? 0 : 1000 + (i % 10);
      await isar.pageModels.filter().workspace((w) => w.idEqualTo(targetWs.id)).pageIndexEqualTo(pIdx).findFirst();
    }
    swOldPage.stop();

    final swNewPage = Stopwatch()..start();
    for (int i = 0; i < 200; i++) {
      final pIdx = (i % 10 == 0) ? 0 : 1000 + (i % 10);
      await targetWs.pages.filter().pageIndexEqualTo(pIdx).findFirst();
    }
    swNewPage.stop();

    // Benchmark 200 Pad Queries
    final swOldPads = Stopwatch()..start();
    for (int i = 0; i < 200; i++) {
      await isar.padModels.filter().page((q) => q.idEqualTo(targetPage!.id)).sortByPadId().findAll();
    }
    swOldPads.stop();

    final swNewPads = Stopwatch()..start();
    for (int i = 0; i < 200; i++) {
      await targetPage!.pads.filter().sortByPadId().findAll();
    }
    swNewPads.stop();

    print('=== T11 BENCHMARK RESULTADOS ===');
    print('200 Consultas de Página:');
    print('  - Colección (Vieja): ${swOldPage.elapsedMicroseconds} µs (${swOldPage.elapsedMilliseconds} ms)');
    print('  - Por Link (Nueva):   ${swNewPage.elapsedMicroseconds} µs (${swNewPage.elapsedMilliseconds} ms)');
    final pageDiffPercent = ((swOldPage.elapsedMicroseconds - swNewPage.elapsedMicroseconds) / swOldPage.elapsedMicroseconds) * 100;
    print('  - Diferencia: ${pageDiffPercent.toStringAsFixed(2)}%');

    print('200 Consultas de Pads (ordenadas por padId):');
    print('  - Colección (Vieja): ${swOldPads.elapsedMicroseconds} µs (${swOldPads.elapsedMilliseconds} ms)');
    print('  - Por Link (Nueva):   ${swNewPads.elapsedMicroseconds} µs (${swNewPads.elapsedMilliseconds} ms)');
    final padsDiffPercent = ((swOldPads.elapsedMicroseconds - swNewPads.elapsedMicroseconds) / swOldPads.elapsedMicroseconds) * 100;
    print('  - Diferencia: ${padsDiffPercent.toStringAsFixed(2)}%');
  });

  test('T11 Benchmark de FilesystemSyncService con biblioteca grande (1.000 archivos)', () async {
    final mediaDir = await AppStorageService.mediaDirectory();
    final wsDir = Directory(p.join(mediaDir.path, 'Benchmark Big Set'));
    await wsDir.create(recursive: true);

    for (var i = 0; i < 1000; i++) {
      final numStr = i.toString().padLeft(4, '0');
      File(p.join(wsDir.path, 'audio_$numStr.wav')).writeAsBytesSync([1]);
    }

    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    // Medir primera pasada (inserción en lote de 1.000 archivos)
    final swInitial = Stopwatch()..start();
    final count = await FilesystemSyncService.reconcileOnStartup(isar);
    swInitial.stop();
    expect(count, 1001);

    // Medir segunda pasada (reconciliación sin cambios con 1.000 pads ya indexados)
    final swSteady = Stopwatch()..start();
    final secondCount = await FilesystemSyncService.reconcileOnStartup(isar);
    swSteady.stop();
    expect(secondCount, 0);

    print('=== T11 BENCHMARK RECONCILIACIÓN (1.000 ARCHIVOS) ===');
    print('  - Pasada Inicial (1.000 archivos creados): ${swInitial.elapsedMilliseconds} ms');
    print('  - Segunda Pasada (Estado estable / 0 cambios): ${swSteady.elapsedMilliseconds} ms');
  });
}
