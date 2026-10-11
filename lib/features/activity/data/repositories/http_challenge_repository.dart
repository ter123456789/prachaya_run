import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../../../core/storage/kv_store.dart';
import '../../domain/entities/monthly_challenge.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../models/activity_json_mapper.dart';

/// `GET /challenges/current`, cached. Signed out or never fetched, a
/// built-in challenge for the current month is used so the card always
/// has something to track.
class HttpChallengeRepository implements ChallengeRepository {
  HttpChallengeRepository(
    this._api,
    this._tokens,
    this._kv, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  final ApiClient _api;
  final TokenStore _tokens;
  final KvStore _kv;
  final DateTime Function() _clock;

  static const _key = 'challenge:current';
  static const defaultGoalMeters = 50000.0;

  @override
  Future<MonthlyChallenge?> current() async {
    final now = _clock();
    if (await _tokens.read() != null) {
      try {
        final json = await _api.get('/challenges/current') as Json;
        await _kv.write(_key, json);
        return _fromJson(json);
      } on NetworkException {
        // Fall through to the cache.
      } on ApiException {
        // Fall through to the cache.
      }
    }
    final cached = await _kv.read(_key);
    if (cached != null) {
      final challenge = _fromJson(cached);
      if (challenge.contains(now)) return challenge;
    }
    return builtIn(now);
  }

  static MonthlyChallenge builtIn(DateTime now) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return MonthlyChallenge(
      id: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      title: 'ความท้าทายประจำเดือน${months[now.month - 1]}',
      badge: 'Monthly 50K',
      goalMeters: defaultGoalMeters,
      startsAt: DateTime(now.year, now.month),
      endsAt: DateTime(now.year, now.month + 1),
    );
  }

  static MonthlyChallenge _fromJson(Json json) => MonthlyChallenge(
    id: json['id']! as String,
    title: json['title']! as String,
    badge: json['badge']! as String,
    goalMeters: (json['goalM']! as num).toDouble(),
    startsAt: ActivityJsonMapper.parseTime(json['startsAt']),
    endsAt: ActivityJsonMapper.parseTime(json['endsAt']),
  );
}
