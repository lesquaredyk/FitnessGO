import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'screens/role_screen.dart';
import 'features/auth/screens/login/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'features/caloriecounter/screens/calorie_counter_screen.dart';
import 'screens/fitness_buddy_screen.dart';
import 'screens/activity_log_screen.dart';
import 'screens/wellness_hub_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_profile_screen.dart';
import 'screens/create_post_screen.dart';
import 'features/auth/screens/signup/signup_flow_screen.dart';

void main() {
  runApp(const FitnessGoApp());
}

class FitnessGoApp extends StatelessWidget {
  const FitnessGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitnessGo',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NoStretchScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008000),
        ),
        scaffoldBackgroundColor: const Color(0xFFE6E6E6),
      ),
      initialRoute: WelcomeScreen.routeName,
      routes: {
        WelcomeScreen.routeName: (context) => const WelcomeScreen(),
        RoleScreen.routeName: (context) => const RoleScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignupFlowScreen.routeName: (context) => const SignupFlowScreen(),
        DashboardScreen.routeName: (context) => const DashboardScreen(),
        CalorieCounterScreen.routeName: (context) => const CalorieCounterScreen(),
        FitnessBuddyScreen.routeName: (context) => const FitnessBuddyScreen(),
        ActivityLogScreen.routeName: (context) => const ActivityLogScreen(),
        WellnessHubScreen.routeName: (context) => const WellnessHubScreen(),
        ProfileScreen.routeName: (context) => const ProfileScreen(),
        MyProfileScreen.routeName: (context) => const MyProfileScreen(),
        CreatePostScreen.routeName: (context) => const CreatePostScreen(),
      },
    );
  }
}

class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}









