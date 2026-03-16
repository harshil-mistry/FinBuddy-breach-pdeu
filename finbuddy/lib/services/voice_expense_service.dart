import 'package:http/http.dart' as http;
import 'dart:convert';

class VoiceExpenseResult {
  final String description;
  final double? amount;
  final List<String> participantUids;
  final String? paidByUid;
  final String transcript;

  VoiceExpenseResult({
    required this.description,
    required this.amount,
    required this.participantUids,
    required this.paidByUid,
    required this.transcript,
  });
}

class VoiceExpenseService {
  // Use 10.118.66.183 for physical device via USB debugging
  // Use 10.0.2.2 for Android emulator
  // Use localhost for iOS simulator
  static const String _baseUrl = 'http://10.118.66.183:3000';

  /// Sends the audio file at [audioPath] plus [members] list to the backend.
  /// Returns a [VoiceExpenseResult] on success, throws a descriptive [Exception] on failure.
  static Future<VoiceExpenseResult> analyze({
    required String audioPath,
    required List<Map<String, String>> members, // [{ 'uid': '...', 'name': '...' }]
  }) async {
    final uri = Uri.parse('$_baseUrl/api/voice-expense');

    final request = http.MultipartRequest('POST', uri);

    // Attach the audio file
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioPath),
    );

    // Attach members JSON
    request.fields['members'] = jsonEncode(members);

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      late Map<String, dynamic> body;
      try { body = jsonDecode(response.body); } catch (_) { body = {}; }
      throw Exception(body['error'] ?? 'Server error (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != true) {
      throw Exception(data['error'] ?? 'Could not parse the recording.');
    }

    return VoiceExpenseResult(
      description:     data['description'] as String? ?? '',
      amount:          (data['amount'] as num?)?.toDouble(),
      participantUids: List<String>.from(data['participantUids'] ?? []),
      paidByUid:       data['paidByUid'] as String?,
      transcript:      data['transcript'] as String? ?? '',
    );
  }
}
