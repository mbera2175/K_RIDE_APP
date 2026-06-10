import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'utils/app_colors.dart';
import 'utils/constants.dart';
import 'services/auth_service.dart';
import 'services/driver_background_service.dart';
import 'screens/rider/rider_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/driver/incoming_ride_overlay.dart';

// Global navigator key for force logout
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Note: mappls_gl 2.0.5 reads API keys from AndroidManifest.xml meta-data
  // (injected via build.gradle.kts manifestPlaceholders) — no Dart init needed.

  await AuthService.init(); // load saved session
  await initializeBackgroundService();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const KRideApp());
}

class KRideApp extends StatelessWidget {
  const KRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'KRide',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            textTheme: GoogleFonts.soraTextTheme(),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              centerTitle: true,
            ),
          ),
          home: AuthService.isLoggedIn
              ? const _AutoLoginRedirect()
              : const RoleSelectionScreen(),
          routes: {
            '/chat': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              final tripId = args?['trip_id'] as int?;
              return DriverTripChatScreen(
                tripId: tripId ?? 0,
                riderName: args?['rider_name'] as String? ?? 'Rider',
                onClose: () {
                  Navigator.of(context).pop();
                },
              );
            },
          },
        );
      },
    );
  }
}

// Redirects to correct home based on saved role
class _AutoLoginRedirect extends StatelessWidget {
  const _AutoLoginRedirect();

  @override
  Widget build(BuildContext context) {
    if (AuthService.isRider) return const RiderHomeScreen();
    if (AuthService.isDriver) return const DriverHomeScreen();
    return const RoleSelectionScreen();
  }
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: IncomingRideOverlay(),
  ));
}

