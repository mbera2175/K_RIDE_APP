import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'utils/app_colors.dart';
import 'services/auth_service.dart';
import 'screens/rider/rider_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/auth/role_selection_screen.dart';

// Global navigator key for force logout
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Mappls (MapMyIndia) is initialized natively in AndroidManifest.xml / Info.plist for v2.x
  // MapplsAccountManager.setMapSDKKey("c59951af1ef53a9e6cc8fb8a7080d5d8");
  // MapplsAccountManager.setRestAPIKey("c59951af1ef53a9e6cc8fb8a7080d5d8");
  // MapplsAccountManager.setAtlasClientId("96dHZVzsAutf7JmkOzGCFwHsVMopiBc3omOm6Nz9I61Oj27HCVNsH44gi4vQBl9ZxAk3l9rrauxdqOYwUmUkOlCz7RrIFlKN");
  // MapplsAccountManager.setAtlasClientSecret("lrFxI-iSEg8FAEuoX9z0UYKFbEDDr2gtxSFnMaxGyAmNBp8A__5GQ8yGbmpIL3g5qYPFCzw-0wb_u9xpbjl1i8lZ49AasxwH3PCiRF2PpuY=");

  await AuthService.init(); // ← load saved session

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
