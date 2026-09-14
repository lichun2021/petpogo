import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petpogo_app/core/api/result.dart';
import 'package:petpogo_app/features/device/data/repository/device_repository.dart';
import 'package:petpogo_app/features/music/data/music_models.dart';
import 'package:petpogo_app/features/music/data/music_repository.dart';
import 'package:petpogo_app/features/music/pet_music_page.dart';
import 'package:petpogo_app/features/pet/data/models/pet_peer_models.dart';
import 'package:petpogo_app/features/pet/data/repository/pet_peer_repository.dart';
import 'package:petpogo_app/features/pet/pet_list_page.dart';
import 'package:petpogo_app/features/pet_circle/data/models/pet_circle_post.dart';

class _Music implements MusicRepository {
  @override
  Future<Result<List<MusicCategory>>> fetchCatalogResult() async =>
      const Success([MusicCategory(name: '放松助眠', songs: [])]);
  @override
  Future<Result<List<Playlist>>> fetchPlaylistsResult() async => const Success([
        Playlist(id: 1, name: '这是一张名字很长很长的晚安陪伴歌单', songCount: 3),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pets implements PetPeerRepository {
  @override
  Future<List<PetInfoModel>> fetchPetList() async => const [
        PetInfoModel(
            petId: '1',
            petName: '名字很长很长的布偶猫',
            breed: '布偶猫',
            sex: 'GG_sterilization'),
      ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Devices implements DeviceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('Music and pet cards fit width $width, scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(Widget page) => ProviderScope(
                overrides: [
                  musicRepositoryProvider.overrideWithValue(_Music()),
                  petPeerRepositoryProvider.overrideWithValue(_Pets()),
                  deviceListProvider
                      .overrideWith((_) => DeviceListNotifier(_Devices())),
                ],
                child: MaterialApp(
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: page));
        await tester.pumpWidget(app(const PetMusicPage()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('3 首'), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.text('3 首'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const PetListPage()));
        await tester.pumpAndSettle();
        expect(find.text('布偶猫 · 公(绝育)'), findsOneWidget);
        expect(find.text('♂ 公'), findsNothing);
        for (final label in ['成员管理', '编辑资料', '删除宠物']) {
          final button = find.byTooltip(label);
          expect(button, findsOneWidget);
          expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('Image cover fallback and video without cover remain distinct', () {
    final image = PetCirclePost.fromJson(
        {'mediaType': 'image', 'coverUrl': 'https://example.test/pet.jpg'});
    expect(image.imageUrls, ['https://example.test/pet.jpg']);
    final video = PetCirclePost.fromJson({
      'mediaType': 'video',
      'mediaUrls': ['https://example.test/pet.mp4']
    });
    expect(video.imageUrls, isEmpty);
    expect(video.displayMediaUrl, isEmpty);
  });
}
