import 'dart:async';

import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// Lightweight fake [JustAudioPlatform] implementation for widget tests.
///
/// It simulates a single track with a configurable default duration so tests can
/// exercise UI state transitions without binding to real platform channels.
class FakeJustAudioPlatform extends JustAudioPlatform {
  FakeJustAudioPlatform({this.defaultDuration = const Duration(seconds: 120)});

  final Duration defaultDuration;
  final Map<String, _FakeAudioPlayerPlatform> _players = {};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = _FakeAudioPlayerPlatform(
      id: request.id,
      defaultDuration: defaultDuration,
    );
    _players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    final player = _players.remove(request.id);
    await player?._close();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final player in _players.values) {
      await player._close();
    }
    _players.clear();
    return DisposeAllPlayersResponse();
  }
}

class _FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  _FakeAudioPlayerPlatform({
    required String id,
    required this.defaultDuration,
  }) : super(id) {
    _emitState();
  }

  final Duration defaultDuration;
  final _playbackController =
      StreamController<PlaybackEventMessage>.broadcast();
  final _playerDataController = StreamController<PlayerDataMessage>.broadcast();

  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  double _speed = 1.0;
  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;
  bool _disposed = false;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      _playbackController.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      _playerDataController.stream;

  Future<void> _close() async {
    _disposed = true;
    await _playbackController.close();
    await _playerDataController.close();
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _processingState = ProcessingStateMessage.loading;
    _emitState();

    _duration = defaultDuration;
    _position = Duration.zero;
    _processingState = ProcessingStateMessage.ready;
    _emitState();
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _playing = true;
    _processingState = ProcessingStateMessage.ready;
    _emitState();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    _emitState();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _position = request.position ?? Duration.zero;
    _emitState();
    return SeekResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    _speed = request.speed;
    _emitState();
    return SetSpeedResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    // Volume does not impact current tests, but we still acknowledge the call.
    return SetVolumeResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    return SetPitchResponse();
  }

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async {
    return SetSkipSilenceResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async {
    return SetShuffleOrderResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async {
    return SetAutomaticallyWaitsToMinimizeStallingResponse();
  }

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
      setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async {
    return SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  }

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async {
    return SetPreferredPeakBitRateResponse();
  }

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async {
    return SetAllowsExternalPlaybackResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _close();
    return DisposeResponse();
  }

  void _emitState() {
    if (_disposed) {
      return;
    }

    _playbackController.add(
      PlaybackEventMessage(
        processingState: _processingState,
        updateTime: DateTime.now(),
        updatePosition: _position,
        bufferedPosition: _position,
        duration: _duration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
      ),
    );

    _playerDataController.add(
      PlayerDataMessage(
        playing: _playing,
        speed: _speed,
      ),
    );
  }
}
