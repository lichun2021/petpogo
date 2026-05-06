import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ai_image_model.dart';

/// 全局存储最近一次 AI 图像分析结果
/// AiImagePanel 分析完成后写入，PetMoodSection 读取显示
class AiImageResultNotifier extends StateNotifier<PetImageAnalysisResult?> {
  AiImageResultNotifier() : super(null);

  void setResult(PetImageAnalysisResult result) => state = result;
  void clear() => state = null;
}

final aiImageResultProvider =
    StateNotifierProvider<AiImageResultNotifier, PetImageAnalysisResult?>(
  (ref) => AiImageResultNotifier(),
);
