import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/result.dart';
import '../data/music_models.dart';
import '../data/music_repository.dart';

class MusicState {
  final Result<List<MusicCategory>>? categories;
  final Result<List<Playlist>>? playlists;
  final bool refreshing;
  final bool creating;
  const MusicState(
      {this.categories,
      this.playlists,
      this.refreshing = false,
      this.creating = false});
}

class MusicController extends StateNotifier<MusicState> {
  final MusicRepository _repository;
  int _playlistRequest = 0;
  MusicController(this._repository) : super(const MusicState()) {
    refresh();
  }

  Future<void> refresh() async {
    if (state.refreshing) return;
    state = MusicState(
        categories: state.categories,
        playlists: state.playlists,
        refreshing: true,
        creating: state.creating);
    final categories = _repository.fetchCatalogResult();
    final playlists = refreshPlaylists();
    final result = await categories;
    await playlists;
    if (!mounted) return;
    state = MusicState(
        categories: result,
        playlists: state.playlists,
        creating: state.creating);
  }

  Future<void> refreshPlaylists() async {
    final request = ++_playlistRequest;
    final result = await _repository.fetchPlaylistsResult();
    if (!mounted || request != _playlistRequest) return;
    state = MusicState(
        categories: state.categories,
        playlists: result,
        refreshing: state.refreshing,
        creating: state.creating);
  }

  Future<Result<void>> createPlaylist(String name) async {
    state = MusicState(
        categories: state.categories,
        playlists: state.playlists,
        refreshing: state.refreshing,
        creating: true);
    final result = await _repository.createPlaylistResult(name: name);
    if (!mounted) return result;
    if (result is Success<void>) await refreshPlaylists();
    if (mounted) {
      state = MusicState(
          categories: state.categories,
          playlists: state.playlists,
          refreshing: state.refreshing);
    }
    return result;
  }
}

final musicControllerProvider =
    StateNotifierProvider.autoDispose<MusicController, MusicState>(
  (ref) => MusicController(ref.watch(musicRepositoryProvider)),
);
