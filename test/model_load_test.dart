import 'package:flutter_test/flutter_test.dart';
import 'package:smartbridgeapp/services/model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModelService baseline contract', () {
    test('exposes gesture class labels for inference output', () {
      final modelService = ModelService();
      expect(modelService.signLabels, isNotEmpty);
      expect(modelService.signLabels, contains('Open_Palm'));
      expect(modelService.signLabels, contains('Closed_Fist'));
      expect(modelService.signLabels, contains('ILoveYou'));
    });

    test('reports not loaded before initialization', () {
      final modelService = ModelService();
      expect(modelService.isModelLoaded, isFalse);
      expect(modelService.getModelInfo(), contains('Model not loaded'));
    });
  });
}
