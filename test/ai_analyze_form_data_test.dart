import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/features/home/data/repository/ai_repository.dart';

void main() {
  test('AI analyze form data includes required account and optional pet id',
      () {
    final formData = buildAiAnalyzeFormData(
      url: 'https://cdn.example.com/pet.jpg',
      account: '13800138000',
      petId: 'pet-1',
    );
    final fields = Map<String, String>.fromEntries(formData.fields);

    expect(fields['url'], 'https://cdn.example.com/pet.jpg');
    expect(fields['account'], '13800138000');
    expect(fields['pet_id'], 'pet-1');
  });

  test('AI analyze form data rejects an empty account', () {
    expect(
      () => buildAiAnalyzeFormData(
        url: 'https://cdn.example.com/pet.wav',
        account: ' ',
      ),
      throwsArgumentError,
    );
  });
}
