import 'dart:async';

import 'package:flutter/material.dart';

import '../features/caloriecounter/data/calorie_counter_api.dart';
import '../core/storage/api_session_store.dart';
import '../core/network/api_client.dart';
import 'dashboard_screen.dart';

class CalorieCounterScreen extends StatefulWidget {
  static const routeName = '/calorie-counter';

  const CalorieCounterScreen({super.key});

  @override
  State<CalorieCounterScreen> createState() => _CalorieCounterScreenState();
}

class _CalorieCounterScreenState extends State<CalorieCounterScreen> {
  final foodController = TextEditingController();
  final quantityController = TextEditingController();

  String selectedMeal = 'Breakfast';
  double calculatedCalories = 0;
  int dailyGoal = 0;
  double calorieIntake = 0.0;
  double calorieLeft = 0.0;
  List<Map<String, dynamic>> foodLogs = [];
@override
  void initState() {
    super.initState();
    loadFoodData();
  }

  @override
  void dispose() {
    foodController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  void recalculateCalories() {
    setState(() {
      calculatedCalories = 0;
    });
  }

  Future<void> getCalories({bool showErrors = true}) async {
    final foodName = foodController.text.trim();
    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;

    if (foodName.isEmpty) {
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a food name.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (quantity <= 0) {
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid food quantity in grams.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final result = await CalorieCounterApi.calculateCalories(
        foodName: foodName,
        foodQuantity: quantity,
      );

      final calories = CalorieCounterApi.asDouble(
        result['Calories'] ?? result['calories'] ?? result['kcal'] ?? 0,
      );

      if (!mounted) return;

      if (calories <= 0) {
        if (showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to calculate calories for this food.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        calculatedCalories = calories;
      });
    } catch (e) {
      if (!mounted || !showErrors) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to calculate calories: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> saveCalories() async {
    final foodName = foodController.text.trim();
    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;

    if (foodName.isEmpty || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter food name and quantity first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (calculatedCalories <= 0) {
      await getCalories(showErrors: true);
    }

    if (calculatedCalories <= 0) return;

    final projectedLeft = dailyGoal - (calorieIntake + calculatedCalories);
    final willExceedForFirstTime =
        dailyGoal > 0 && calorieLeft >= 0 && projectedLeft < 0;

    try {
      final userId = await ApiSessionStore.getUserId();

      if (userId <= 0) {
        throw Exception('User is not logged in.');
      }

      await CalorieCounterApi.createFood(
        userId: userId,
        foodName: foodName,
        foodQuantity: quantity,
        mealCategory: selectedMeal,
        calories: calculatedCalories.toDouble(),
      );

      setState(() {
        foodController.clear();
        quantityController.clear();
        calculatedCalories = 0;
      });

      await loadFoodData();

      if (willExceedForFirstTime && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Calorie Goal Notice'),
              content: Text(
                'Saving this food will exceed your daily calorie goal.\n\n'
                'This is allowed, but please be mindful of your intake.\n\n'
                'Remaining Calories: ${projectedLeft.toStringAsFixed(2)} kcal',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calories saved.'),
          backgroundColor: Color(0xFF008000),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save calories: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  int extractDailyGoal(Map<String, dynamic> result) {
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

  Future<void> loadFoodData() async {
    try {
      final userId = await ApiSessionStore.getUserId();

      if (userId <= 0) return;

      int loadedDailyGoal = dailyGoal;

      try {
        final profileResult = await ApiClient.get('/profile/$userId');
        final parsedGoal = extractDailyGoal(profileResult);

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
        dailyGoal = loadedDailyGoal;
        foodLogs = logs;
        calorieIntake = total;
        calorieLeft = loadedDailyGoal.toDouble() - total;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load food logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final intake = calorieIntake;
    final left = calorieLeft;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF8),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          children: [
            buildTopBar(),
            const SizedBox(height: 12),
            buildSubtitle(),
            const SizedBox(height: 16),
            buildSummaryRow(intake, left),
            const SizedBox(height: 18),
            buildInputCard(),
            const SizedBox(height: 16),
            buildRecentLog(),
          ],
        ),
      ),
    );
  }

  Widget buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF008000),
            size: 29,
          ),
        ),
        Container(
          height: 52,
          width: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFF008000),
            size: 31,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Calorie Counter',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EA),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFC7EBCB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFF168A2A),
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  'Daily Goal • $dailyGoal kcal',
                  style: const TextStyle(
                    color: Color(0xFF2B5F35),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget buildSummaryRow(double intake, double left) {
  final displayedIntake = intake.round().toString();
  final displayedLeft = left < 0
      ? left.abs().round().toString()
      : left.round().toString();

  return Row(
    children: [
      Expanded(
        child: buildSummaryBox(
          title: 'Calorie Intake',
          value: displayedIntake,
          icon: Icons.restaurant_menu_rounded,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: buildSummaryBox(
          title: left < 0 ? 'Calorie Goal Exceeded' : 'Remaining Calories',
          value: displayedLeft,
          icon: left < 0 ? Icons.warning_rounded : Icons.flag_rounded,
        ),
      ),
    ],
  );
}

  Widget buildSummaryBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B8F2E),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
  Widget buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE1E8DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildLabel('Food Type'),
          buildFoodAutocomplete(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildLabel('Quantity (g)'),
                    buildQuantityField(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildLabel('Select Meal'),
                    buildMealDropdown(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: buildActionButton(
              text: 'Get Calories',
              icon: Icons.local_fire_department_rounded,
              light: true,
              onTap: () {
                getCalories();
              },
            ),
          ),
          const SizedBox(height: 14),
          buildLabel('Food Calorie'),
          buildCalorieResult(),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: buildActionButton(
              text: 'Save Calories',
              icon: Icons.save_rounded,
              light: false,
              onTap: saveCalories,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget buildFoodAutocomplete() {
    return TextField(
      controller: foodController,
      onChanged: (_) {
        recalculateCalories();
      },
      decoration: inputDecoration(
        hint: 'Enter food name',
        icon: Icons.fastfood_rounded,
      ),
    );
  }

  Widget buildQuantityField() {
    return TextField(
      controller: quantityController,
      keyboardType: TextInputType.number,
      onChanged: (_) {
        recalculateCalories();
      },
      decoration: inputDecoration(
        hint: 'grams',
        icon: Icons.scale_rounded,
      ),
    );
  }

  Widget buildMealDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedMeal,
      decoration: inputDecoration(
        hint: 'Meal',
        icon: Icons.arrow_drop_down_circle_rounded,
      ),
      items: const [
        DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
        DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
        DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
        DropdownMenuItem(value: 'Snack', child: Text('Snack')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          selectedMeal = value;
        });
      },
    );
  }

  Widget buildCalorieResult() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8DE)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          calculatedCalories <= 0
    ? '0 kcal'
    : '${calculatedCalories.toStringAsFixed(2)} kcal',
          style: const TextStyle(
            color: Color(0xFF008000),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget buildActionButton({
    required String text,
    required IconData icon,
    required bool light,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: light ? Colors.white : const Color(0xFF1B8F2E),
        foregroundColor: light ? const Color(0xFF1B8F2E) : Colors.white,
        elevation: light ? 0 : 2,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(
          color: Color(0xFF168A2A),
          width: 1.3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF008000)),
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.black38,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAF6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1E8DE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1E8DE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF008000), width: 1.4),
      ),
    );
  }

  Widget buildRecentLog() {
    final entries = foodLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Food Log',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE1E8DE)),
            ),
            child: const Text(
              'No saved food yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          ...entries.map((entry) {
            final foodName = CalorieCounterApi.asString(
              entry['FoodName'] ?? entry['food_name'] ?? entry['food'] ?? '',
            );

            final meal = CalorieCounterApi.asString(
              entry['MealCategory'] ?? entry['meal_category'] ?? '',
            );

            final calories = CalorieCounterApi.asDouble(
              entry['Calories'] ?? entry['calories'] ?? entry['kcal'] ?? 0,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1E8DE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.restaurant_rounded,
                    color: Color(0xFF008000),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meal.isEmpty ? foodName : '$foodName - $meal',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${calories.toStringAsFixed(2)} kcal',
                    style: const TextStyle(
                      color: Color(0xFF008000),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}







