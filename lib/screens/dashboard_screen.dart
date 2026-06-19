import 'package:flutter/material.dart';

import '../data/local_user_store.dart';
import '../data/local_calorie_store.dart';
import '../data/local_post_store.dart';
import 'activity_log_screen.dart';
import 'calorie_counter_screen.dart';
import 'create_post_screen.dart';
import 'fitness_buddy_screen.dart';
import 'profile_screen.dart';
import 'my_profile_screen.dart';
import 'wellness_hub_screen.dart';
import '../features/auth/screens/login/login_screen.dart';

import '../widgets/profile_photo_avatar.dart';
import '../core/storage/api_session_store.dart';
import '../core/network/api_client.dart';
import '../features/caloriecounter/data/calorie_counter_api.dart';
class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
    double dashboardCalorieIntake = 0.0;
  double dashboardRemainingCalories = 0.0;
  int dashboardDailyGoal = 0;

  @override
  void initState() {
    super.initState();
    loadDashboardCalories();
  }
Future<void> openCreatePost() async {
    final result = await Navigator.pushNamed(
      context,
      CreatePostScreen.routeName,
    );

    if (result is! Map) return;

    LocalPostStore.add(result);

    if (!mounted) return;

    if (result['audience'] == 'Only Me') {
      Navigator.pushNamed(
        context,
        ProfileScreen.routeName,
        arguments: result,
      );
      return;
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post added to Fitness Wall.'),
      ),
    );
  }

  void showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be added later.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publicPosts = LocalPostStore.publicPosts;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                children: [
                  buildHeader(),
                  const SizedBox(height: 18),
                  buildGreetingCard(),
                  const SizedBox(height: 18),
                  buildCalorieBoxes(),
                  const SizedBox(height: 24),
                  buildFitnessWall(publicPosts),
                ],
              ),
            ),
            buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: 54,
          width: 54,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Container(
              height: 54,
              width: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF7EA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: Color(0xFF168A2A),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FitnessGo',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Home Dashboard',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            LocalUserStore.setFullName('');
            LocalCalorieStore.setDailyGoal(0);
            LocalCalorieStore.clear();

            Navigator.pushNamedAndRemoveUntil(
              context,
              LoginScreen.routeName,
              (route) => false,
            );
          },
          icon: const Icon(
            Icons.logout_rounded,
            color: Color(0xFF168A2A),
            size: 27,
          ),
        ),
      ],
    );
  }

  Widget buildGreetingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF009600),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009600).withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi ${LocalUserStore.displayName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stay active and keep your progress going.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () {
              Navigator.pushNamed(
                context,
                MyProfileScreen.routeName,
              );
            },
            child: const ProfilePhotoAvatar(
              radius: 34,
              iconSize: 38,
              backgroundColor: Colors.white24,
              iconColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  int extractDashboardDailyGoal(Map<String, dynamic> result) {
    final roots = [
      result,
      result['data'],
      result['profile'],
      result['user'],
    ];

    for (final root in roots) {
      if (root is Map) {
        final parsed = CalorieCounterApi.asInt(
          root['DailyNetGoal'] ??
              root['dailyNetGoal'] ??
              root['daily_goal'] ??
              root['dailyGoal'] ??
              root['DailyGoal'],
        );

        if (parsed > 0) return parsed;
      }
    }

    return 0;
  }

  Future<void> loadDashboardCalories() async {
    try {
      final userId = await ApiSessionStore.getUserId();

      if (userId <= 0) return;

      int loadedDailyGoal = dashboardDailyGoal;

      try {
        final profileResult = await ApiClient.get('/profile/$userId');
        final parsedGoal = extractDashboardDailyGoal(profileResult);

        if (parsedGoal > 0) {
          loadedDailyGoal = parsedGoal;
        }
      } catch (_) {
        // Keep fallback below.
      }

      if (loadedDailyGoal <= 0) {
        loadedDailyGoal = 2000;
      }

      final today = DateTime.now().toIso8601String().split('T').first;

      final result = await CalorieCounterApi.getFoodsByUserAndDate(
        userId: userId,
        logDate: today,
      );

      final rawFoods = result['foods'] ?? result['data'] ?? [];
      final logs = <Map<String, dynamic>>[];

      if (rawFoods is List) {
        for (final item in rawFoods) {
          if (item is Map) {
            logs.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final total = logs.fold<double>(
        0.0,
        (sum, item) =>
            sum +
            CalorieCounterApi.asDouble(
              item['Calories'] ?? item['calories'] ?? item['kcal'] ?? 0,
            ),
      );

      if (!mounted) return;

      setState(() {
        dashboardDailyGoal = loadedDailyGoal;
        dashboardCalorieIntake = total;
        dashboardRemainingCalories = loadedDailyGoal.toDouble() - total;
      });
    } catch (_) {
      // Keep dashboard visible even if calories fail to load.
    }
  }
  Widget buildCalorieBoxes() {
  final intake = dashboardCalorieIntake;
  final remaining = dashboardRemainingCalories;

  final displayedIntake = intake.round();
  final displayedRemaining = remaining < 0
      ? remaining.abs().round()
      : remaining.round();

  return Row(
    children: [
      Expanded(
        child: buildCalorieBox(
          icon: Icons.restaurant_rounded,
          title: 'Calorie Intake',
          value: '$displayedIntake kcal',
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: buildCalorieBox(
          icon: remaining < 0 ? Icons.warning_rounded : Icons.flag_rounded,
          title: remaining < 0 ? 'Calorie Goal Exceeded' : 'Remaining Calories',
          value: '$displayedRemaining kcal',
        ),
      ),
    ],
  );
}
  Widget buildCalorieBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE1E8DE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF168A2A),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            width: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF7EA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF168A2A),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
  Widget buildFitnessWall(List<Map<String, String>> userPosts) {
    final starterPosts = [
      {
        'name': 'FitnessGo Team',
        'time': 'Today',
        'content':
            'Welcome to FitnessGo! Share your progress and stay consistent.',
      },
      {
        'name': 'System Reminder',
        'time': 'Today',
        'content':
            'Track your meals, log your activities, and keep moving toward your goal.',
      },
    ];

    final posts = [
      ...userPosts,
      ...starterPosts,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fitness Wall',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        buildPostComposer(),
        const SizedBox(height: 18),
        ...posts.map(buildPostCard),
      ],
    );
  }

  Widget buildProfileShortcut() {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.pushNamed(
          context,
          ProfileScreen.routeName,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE1E8DE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 13,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const ProfilePhotoAvatar(
              radius: 24,
              iconSize: 27,
              backgroundColor: Color(0xFFEAF7EA),
              iconColor: Color(0xFF168A2A),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Profile',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'View your posts and profile activity',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF168A2A),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPostComposer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE1E8DE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 13,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              Navigator.pushNamed(
                context,
                ProfileScreen.routeName,
              );
            },
            child: const ProfilePhotoAvatar(
              radius: 24,
              iconSize: 28,
              backgroundColor: Color(0xFFEAF7EA),
              iconColor: Color(0xFF168A2A),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: openCreatePost,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE1E8DE),
                  ),
                ),
                child: const Text(
                  "What's on your mind?",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              showComingSoon('Post Photo');
            },
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EA),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFFBFE7C3),
                ),
              ),
              child: const Icon(
                Icons.photo_rounded,
                color: Color(0xFF168A2A),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget buildPostCard(Map<String, String> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE1E8DE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 13,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfilePhotoAvatar(
              radius: 24,
              iconSize: 27,
              backgroundColor: Color(0xFFEAF7EA),
              iconColor: Color(0xFF168A2A),
            ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['name'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  post['time'] ?? 'Just now',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  post['content'] ?? '',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomNavigation() {
    return Container(
      height: 74,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE1E8DE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          buildNavItem(
            icon: Icons.smart_toy_rounded,
            label: 'Fitness\nBuddy',
            onTap: () {
              Navigator.pushNamed(context, FitnessBuddyScreen.routeName);
            },
          ),
          buildNavItem(
            icon: Icons.local_drink_rounded,
            label: 'Calorie\nCounter',
            onTap: () {
              Navigator.pushNamed(context, CalorieCounterScreen.routeName);
            },
          ),
          buildHomeButton(),
          buildNavItem(
            icon: Icons.assignment_rounded,
            label: 'Activity\nLog',
            onTap: () {
              Navigator.pushNamed(context, ActivityLogScreen.routeName);
            },
          ),
          buildNavItem(
            icon: Icons.spa_rounded,
            label: 'Wellness\nHub',
            onTap: () {
              Navigator.pushNamed(context, WellnessHubScreen.routeName);
            },
          ),
        ],
      ),
    );
  }

  Widget buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF00A30B),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF00A30B),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHomeButton() {
    return Expanded(
      child: Center(
        child: Container(
          height: 52,
          width: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF00A30B),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: 31,
          ),
        ),
      ),
    );
  }
}















