import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:interview_pro_app/features/splash/presentation/pages/splash_page.dart';
import 'package:interview_pro_app/features/splash/presentation/providers/splash_provider.dart';
import 'package:interview_pro_app/core/constants/app_colors.dart';
import 'package:interview_pro_app/core/constants/app_strings.dart';

void main() {
  group('Splash Screen Tests', () {
    testWidgets('should display InterviewPro branding with correct colors', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SplashProvider(),
            child: const SplashPage(),
          ),
        ),
      );

      // Act & Assert
      // Verify InterviewPro text is displayed
      expect(find.text(AppStrings.appName), findsOneWidget);

      // Verify mic icon is displayed
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Verify primary color is used for branding elements
      final Container logoContainer = tester.widget(
        find.byType(Container).first,
      );
      expect(
        (logoContainer.decoration as BoxDecoration).color,
        AppColors.primary,
      );
    });

    testWidgets('should show loading animation components', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SplashProvider(),
            child: const SplashPage(),
          ),
        ),
      );

      // Act & Assert
      // Verify animation components are present
      expect(find.byType(AnimatedBuilder), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('should have proper layout structure', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SplashProvider(),
            child: const SplashPage(),
          ),
        ),
      );

      // Act & Assert
      // Verify scaffold background color
      final Scaffold scaffold = tester.widget(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.backgroundLight);

      // Verify main layout structure using widget keys
      expect(find.byKey(const Key('splash_center')), findsOneWidget);
      expect(find.byKey(const Key('splash_content')), findsOneWidget);
      expect(find.byKey(const Key('logo_container')), findsOneWidget);
      expect(find.byKey(const Key('loading_spinner')), findsOneWidget);

      // Verify that the splash content is properly structured
      final centerWidget = tester.widget<Center>(
        find.byKey(const Key('splash_center')),
      );
      expect(centerWidget, isNotNull);

      final columnWidget = tester.widget<Column>(
        find.byKey(const Key('splash_content')),
      );
      expect(columnWidget.mainAxisAlignment, MainAxisAlignment.center);

      // Verify Container is used for logo and has proper decoration
      final logoContainer = tester.widget<Container>(
        find.byKey(const Key('logo_container')),
      );
      expect(logoContainer.decoration, isA<BoxDecoration>());

      // Verify the logo container has the expected styling
      final decoration = logoContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
      expect(decoration.borderRadius, isA<BorderRadius>());
    });
  });
}
