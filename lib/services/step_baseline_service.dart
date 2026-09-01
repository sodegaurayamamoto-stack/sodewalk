import 'package:pedometer/pedometer.dart';
import 'storage_service.dart';

// バックグラウンドから直接呼ばれるため、この注釈が必要です
@pragma('vm:entry-point')
Future<void> captureMidnightStepBaseline() async {
  try {
    final event = await Pedometer.stepCountStream.first
        .timeout(const Duration(seconds: 10));
    final storage = StorageService();
    await storage.saveStepBase(event.steps);
  } catch (e) {
    // センサー取得に失敗した場合は何もしない（アプリ起動時のフォールバックに任せる）
  }
}
