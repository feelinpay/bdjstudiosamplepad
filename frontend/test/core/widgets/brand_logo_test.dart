import 'package:bdj_studio_sample_pad/core/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BrandLogo decodifica con cacheWidth y cacheHeight proporcionales al DPR', (tester) async {
    const testDpr = 2.5;
    const testSize = 104.0;
    final expectedPx = (testSize * testDpr).round();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: testDpr),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: BrandLogo(size: testSize),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<ResizeImage>());

    final resizeImage = imageWidget.image as ResizeImage;
    expect(resizeImage.width, equals(expectedPx));
    expect(resizeImage.height, equals(expectedPx));
  });

  testWidgets('BrandLogo aplica tamaño y radio personalizados', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 1.0),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: BrandLogo(size: 64, radius: 18),
        ),
      ),
    );

    final containerFinder = find.byType(Container).first;
    final containerWidget = tester.widget<Container>(containerFinder);
    expect(containerWidget.constraints?.maxWidth, equals(64.0));
    expect(containerWidget.constraints?.maxHeight, equals(64.0));

    final clipFinder = find.byType(ClipRRect);
    expect(clipFinder, findsOneWidget);
    final clipWidget = tester.widget<ClipRRect>(clipFinder);
    expect(clipWidget.borderRadius, equals(BorderRadius.circular(18)));
  });
}
