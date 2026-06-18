class RecipeIngredient {
  final String id;
  final String name;
  final double amount;
  final String? unit;

  RecipeIngredient({
    required this.id,
    required this.name,
    required this.amount,
    this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'],
    );
  }
}

class RecipeStep {
  final String id;
  final String title;
  final String content;
  final int? timerSeconds;

  RecipeStep({
    required this.id,
    required this.title,
    required this.content,
    this.timerSeconds,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      timerSeconds: json['timer_seconds'],
    );
  }
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final int baseServings;
  final String? notes;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.baseServings,
    this.notes,
    required this.ingredients,
    required this.steps,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      baseServings: json['base_servings'] ?? 4,
      notes: json['notes'],
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VegetableRecipeGroup {
  final String id;
  final String name;
  final List<Recipe> recipes;

  VegetableRecipeGroup({
    required this.id,
    required this.name,
    required this.recipes,
  });

  factory VegetableRecipeGroup.fromJson(Map<String, dynamic> json) {
    return VegetableRecipeGroup(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      recipes: (json['recipes'] as List<dynamic>? ?? [])
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
