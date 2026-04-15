import 'package:flutter_test/flutter_test.dart';
import 'package:smartbridgeapp/services/model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelService baseline contract', () {
    test('exposes ASL class labels for inference output', () {
      final modelService = ModelService();
      expect(modelService.signLabels, isNotEmpty);
      expect(modelService.signLabels, contains('<pad>'));
      expect(modelService.signLabels, contains('A'));
      expect(modelService.signLabels, contains('<blank>'));
    });

    test('reports not loaded before initialization', () {
      final modelService = ModelService();
      expect(modelService.isModelLoaded, isFalse);
      expect(modelService.getModelInfo(), contains('Model not loaded'));
    });
  });
}
