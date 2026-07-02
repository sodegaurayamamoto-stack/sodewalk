import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// レシピの詳細（材料・手順）を表示する画面。
/// 人数を変更すると、材料の量が自動的に再計算される。
class RecipeDetailPage extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late int _servings;

  static const int _minServings = 1;
  static const int _maxServings = 20;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.baseServings;
  }

  double _scaledAmount(double baseAmount) {
    return baseAmount * _servings / widget.recipe.baseServings;
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(1);
  }

  /// 英語の単位表記を、日本語でよく使われる表記に変換する
  String _formatUnit(String? unit) {
    switch (unit) {
      case 'tbsp':
        return '大さじ';
      case 'tsp':
        return '小さじ';
      case 'cup':
        return 'カップ';
      case 'g':
        return 'g';
      case 'kg':
        return 'kg';
      case 'ml':
        return 'ml';
      case 'l':
        return 'L';
      case 'fl_oz':
        return 'オンス';
      case 'oz':
        return 'オンス';
      case 'lb':
        return 'ポンド';
      case 'pinch':
        return 'つまみ';
      default:
        return '';
    }
  }

  /// 「大さじ」「小さじ」「カップ」は数字の前に単位を置く（大さじ3）、
  /// それ以外は数字の後に単位を置く（200g）日本語の慣習に合わせる
  String _formatIngredientAmount(double amount, String? unit) {
    final formattedAmount = _formatAmount(amount);
    final formattedUnit = _formatUnit(unit);
    if (unit == 'tbsp' || unit == 'tsp' || unit == 'cup') {
      return '$formattedUnit$formattedAmount';
    }
    return '$formattedAmount$formattedUnit';
  }

  void _changeServings(int delta) {
    setState(() {
      final next = _servings + delta;
      if (next >= _minServings && next <= _maxServings) {
        _servings = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.blueGrey, size: 28),
                label: const Text('戻る', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          recipe.title,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          softWrap: false,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(recipe.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5)),
                    const SizedBox(height: 24),
                    _buildServingsControl(),
                    const SizedBox(height: 24),
                    const Text('材料', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...recipe.ingredients.map((ingredient) => _buildIngredientRow(ingredient)),
                    const SizedBox(height: 32),
                    const Text('作り方', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...recipe.steps.asMap().entries.map((entry) => _buildStepCard(entry.key + 1, entry.value)),
                    if (recipe.notes != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(recipe.notes!, style: const TextStyle(fontSize: 14, height: 1.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServingsControl() {
    final canDecrease = _servings > _minServings;
    final canIncrease = _servings < _maxServings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('人数', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(
                onPressed: canDecrease ? () => _changeServings(-1) : null,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: canDecrease ? Colors.orange : Colors.grey.shade300,
                  size: 28,
                ),
              ),
              Text('$_servings人分', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: canIncrease ? () => _changeServings(1) : null,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: canIncrease ? Colors.orange : Colors.grey.shade300,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(RecipeIngredient ingredient) {
    final scaled = _scaledAmount(ingredient.amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ingredient.name,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatIngredientAmount(scaled, ingredient.unit),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int stepNumber, RecipeStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$stepNumber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_resolveStepContent(step), style: const TextStyle(fontSize: 15, height: 1.5)),
                if (step.timerSeconds != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('約${(step.timerSeconds! / 60).round()}分', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// {0001}のような材料IDの埋め込みを、実際の材料名に置き換える
  String _resolveStepContent(RecipeStep step) {
    String content = step.content;
    for (final ingredient in widget.recipe.ingredients) {
      content = content.replaceAll('{${ingredient.id}}', ingredient.name);
    }
    return content;
  }
}