import '../../../core/network/api_client.dart';

class CalorieCounterApi {
  static int asInt(dynamic value) => ApiClient.asInt(value);
  static double asDouble(dynamic value) => ApiClient.asDouble(value);
  static String asString(dynamic value) => ApiClient.asString(value);

  static Future<Map<String, dynamic>> calculateCalories({
    required String foodName,
    required double foodQuantity,
  }) {
    return ApiClient.post(
      '/foods/calculate',
      body: {
        'FoodName': foodName.trim(),
        'FoodQuantity': foodQuantity,
      },
    );
  }

  static Future<Map<String, dynamic>> getFoodCalories({
    required String foodName,
  }) {
    final encodedFoodName = Uri.encodeComponent(foodName.trim());
    return ApiClient.get('/foods/calories?food_name=$encodedFoodName');
  }

  static Future<Map<String, dynamic>> createFood({
    required int userId,
    required String foodName,
    required double foodQuantity,
    required String mealCategory,
    required double calories,
  }) {
    return ApiClient.post(
      '/foods/',
      body: {
        'UserId': userId,
        'FoodName': foodName.trim(),
        'FoodQuantity': foodQuantity,
        'MealCategory': mealCategory,
        'Calories': calories,
      },
    );
  }

  static Future<Map<String, dynamic>> getFoodsByUserAndDate({
    required int userId,
    required String logDate,
  }) {
    return ApiClient.get('/foods/user/$userId?log_date=$logDate');
  }

  static Future<Map<String, dynamic>> getAllFoodByUser({
    required int userId,
  }) {
    return ApiClient.get('/foods/user/$userId/all');
  }

  static Future<Map<String, dynamic>> updateFood({
    required int foodId,
    required String foodName,
    required double foodQuantity,
    required String mealCategory,
    required double calories,
  }) {
    return ApiClient.put(
      '/foods/$foodId',
      body: {
        'FoodName': foodName.trim(),
        'FoodQuantity': foodQuantity,
        'MealCategory': mealCategory,
        'Calories': calories,
      },
    );
  }

  static Future<Map<String, dynamic>> deleteFood({
    required int foodId,
  }) {
    return ApiClient.delete('/foods/$foodId');
  }

  static int extractCalories(Map<String, dynamic> result) {
    final directCalories = _readCaloriesFromMap(result);
    if (directCalories > 0) return directCalories;

    final data = result['data'];
    if (data is Map) {
      final dataCalories = _readCaloriesFromMap(data);
      if (dataCalories > 0) return dataCalories;
    }

    final possibleLists = [
      result['items'],
      result['foods'],
      result['food'],
      result['results'],
      result['raw'],
      result['data'],
    ];

    for (final item in possibleLists) {
      if (item is List) {
        final total = _sumCaloriesFromList(item);
        if (total > 0) return total;
      }

      if (item is Map) {
        final nestedLists = [
          item['items'],
          item['foods'],
          item['food'],
          item['results'],
          item['raw'],
          item['data'],
        ];

        for (final nestedItem in nestedLists) {
          if (nestedItem is List) {
            final total = _sumCaloriesFromList(nestedItem);
            if (total > 0) return total;
          }
        }
      }
    }

    return 0;
  }

  static int _readCaloriesFromMap(Map<dynamic, dynamic> map) {
    final possibleKeys = [
      'Calories',
      'calories',
      'Calorie',
      'calorie',
      'totalCalories',
      'total_calories',
      'TotalCalories',
      'Total_Calories',
      'kcal',
      'Kcal',
    ];

    for (final key in possibleKeys) {
      final value = map[key];
      final calories = asDouble(value).round();

      if (calories > 0) return calories;
    }

    return 0;
  }

  static int _sumCaloriesFromList(List<dynamic> items) {
    double total = 0;

    for (final item in items) {
      if (item is Map) {
        total += asDouble(
          item['Calories'] ??
              item['calories'] ??
              item['totalCalories'] ??
              item['total_calories'] ??
              item['kcal'],
        );
      }
    }

    return total.round();
  }
}
