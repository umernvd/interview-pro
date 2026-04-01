import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Service for transcribing audio files using a Groq-centered pipeline (Whisper + Llama 3)
/// with a resilient fallback to Gemini for high-fidelity audio processing.
class TranscriptionService {
  final String _apiKey;
  final String _groqApiKey;
  final String _deepgramApiKey;
  GenerativeModel? _flashModel;
  GenerativeModel? _fallbackModel;

  /// Robust error identifier for UI differentiation
  static const String errorPrefix = 'STT_ERROR:';

  /// Global registry of active transcription tasks
  static final Map<String, Future<String>> _activeTasks = {};

  /// Global registry of pending tasks waiting for connectivity
  static final Map<String, String> _pendingTasks = {};

  /// Stream for notifying listeners about transcription progress/completion
  static final StreamController<Map<String, String>> _statusController =
      StreamController<Map<String, String>>.broadcast();

  TranscriptionService()
    : _apiKey = dotenv.get('GEMINI_API_KEY', fallback: ''),
      _groqApiKey = dotenv.get('GROQ_API_KEY', fallback: ''),
      _deepgramApiKey = dotenv.get('DEEPGRAM_API_KEY', fallback: '') {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      debugPrint('⚠️ Gemini API Key not found or invalid in .env');
    }

    if (_groqApiKey.isEmpty) {
      debugPrint('⚠️ Groq API Key not found in .env (Hybrid Mode disabled)');
    } else {
      debugPrint('🚀 Groq Hybrid Mode initialized and ready.');
    }

    if (_deepgramApiKey.isEmpty) {
      debugPrint(
        '⚠️ Deepgram API Key not found in .env (Acoustic Mode disabled)',
      );
    } else {
      debugPrint('🎙️ Deepgram Acoustic Mode initialized and ready.');
    }

    if (_apiKey.isNotEmpty) {
      _flashModel = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: _apiKey,
      );
      _fallbackModel = GenerativeModel(
        model: 'gemini-2.0-flash-lite',
        apiKey: _apiKey,
      );

      // Initialize connectivity listener to resume pending tasks
      Connectivity().onConnectivityChanged.listen((results) {
        // results is a List<ConnectivityResult> in newer versions
        final isConnected = results.any((r) => r != ConnectivityResult.none);
        if (isConnected && _pendingTasks.isNotEmpty) {
          debugPrint(
            '🌐 Connection restored. Resuming ${_pendingTasks.length} pending STT tasks...',
          );
          _processPendingTasks();
        }
      });
    }
  }

  /// Process all tasks that were queued while offline
  void _processPendingTasks() {
    final tasks = Map<String, String>.from(_pendingTasks);
    _pendingTasks.clear();
    tasks.forEach((id, path) {
      queueTranscription(id, path);
    });
  }

  /// Check if the device is currently online
  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Start transcription in background and track it globally
  void queueTranscription(String interviewId, String filePath) async {
    if (_activeTasks.containsKey(interviewId)) return;

    // Check connectivity before starting
    if (!await _isOnline()) {
      debugPrint(
        '📶 Device offline. Queuing STT for $interviewId until connection is restored.',
      );
      _pendingTasks[interviewId] = filePath;
      return;
    }

    debugPrint('🚀 Proactive STT started for: $interviewId');
    final future = transcribeFile(filePath);
    _activeTasks[interviewId] = future;

    future
        .then((transcript) {
          _statusController.add({interviewId: transcript});
        })
        .catchError((e) {
          debugPrint('❌ Proactive STT failed for $interviewId: $e');
        });
  }

  /// Get the existing task future if it exists
  Future<String>? getActiveTask(String interviewId) =>
      _activeTasks[interviewId];

  /// Stream of completed transcriptions
  Stream<Map<String, String>> get statusStream => _statusController.stream;

  /// Transcribes the given audio file using either Groq (Primary) or Gemini (Fallback)
  Future<String> transcribeFile(
    String filePath, {
    String? role,
    String? level,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return '$errorPrefix Gemini API Key not found. Please set GEMINI_API_KEY in .env';
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Transcription error: File not found at $filePath');
        return '$errorPrefix Audio file not found.';
      }

      final bytes = await file.readAsBytes();
      debugPrint('🎙️ Transcribing: ${file.path.split('/').last}');
      debugPrint('📂 Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB');

      final content = [
        Content.multi([
          DataPart('audio/mp4', bytes),
          TextPart(
            'Transcribe this interview audio verbatim. \n'
            'Identify and separate multiple speakers. \n'
            'Label the primary candidate as "Candidate". \n'
            'Label different interviewers as "Interviewer 1", "Interviewer 2", etc., based on their voice and context. \n'
            'RULES:\n'
            '1. Return ONLY a valid JSON array of objects. NO preamble or intro text.\n'
            '2. Each object must have "speaker", "text", and "time" (in M:SS format) keys.\n'
            '3. Use dialogue context to infer which interviewer is speaking if possible.\n'
            '4. NO markdown bolding in the text content.\n'
            '5. IF THE AUDIO IS SILENT OR NO SPEECH IS DETECTED, RETURN AN EMPTY ARRAY: []\n'
            'Format Example (DO NOT HALLUCINATE THESE NAMES/TEXT):\n'
            '[\n'
            '  {"speaker": "Interviewer 1", "time": "0:00", "text": "Hello..."}, \n'
            '  {"speaker": "Candidate", "time": "0:05", "text": "Hi..."}\n'
            ']',
          ),
        ]),
      ];

      // Use the Groq-centered pipeline (Whisper STT + Llama Diarization)
      if (_groqApiKey.isNotEmpty && _groqApiKey.length > 10) {
        return await _transcribeWithGroqPipeline(
          filePath,
          role: role,
          level: level,
        );
      } else {
        final rawResult = await _generateWithRetry(content);
        return _validateAndCleanJson(rawResult);
      }
    } catch (e) {
      debugPrint('❌ STT Error: $e');
      if (e.toString().contains('429')) {
        return '$errorPrefix AI Speed Limit reached. Please wait 30 seconds and try again.';
      }
      return '$errorPrefix AI Transcription failed: ${e.toString().split('\n').first}';
    }
  }

  /// Validates that the output is valid JSON and strips any AI markdown wrappers
  String _validateAndCleanJson(String rawOutput) {
    try {
      // 1. Strip potential markdown blocks: ```json [...] ```
      String cleaned = rawOutput.trim();
      if (cleaned.startsWith('```')) {
        final lines = cleaned.split('\n');
        // Remove first line if it starts with ``` (e.g. ```json)
        if (lines.isNotEmpty && lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        // Remove last line if it starts with ```
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleaned = lines.join('\n').trim();
      }

      // 2. Validate it's actually valid JSON to catch AI hallucinations
      jsonDecode(cleaned);

      // 3. Hallucination Guard: Filter out boilerplate examples from the prompt
      // If the AI just regurgitated the example because of silence/error, clear it
      if (cleaned.contains('Can you explain your experience with Flutter?') ||
          cleaned.contains('Sure, I have worked with Flutter for 3 years') ||
          (cleaned.contains('Hello...') && cleaned.contains('Hi...'))) {
        debugPrint(
          '⚠️ Hallucination detected: AI returned boilerplate example. Returning empty.',
        );
        return '[]';
      }

      return cleaned;
    } catch (e) {
      debugPrint('⚠️ JSON Validation failed, returning raw string: $e');
      return rawOutput;
    }
  }

  /// Private helper to handle generative AI calls with exponential backoff
  Future<String> _generateWithRetry(
    List<Content> content, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        // Primary Attempt with Flash Lite (Optimized for speed/cost)
        final response =
            await (_fallbackModel ??
                    GenerativeModel(
                      model: 'gemini-2.0-flash-lite',
                      apiKey: _apiKey,
                    ))
                .generateContent(content);

        if (response.text != null && response.text!.isNotEmpty) {
          debugPrint('✅ STT Success (Attempt ${attempts + 1})');
          return response.text!.trim();
        }

        throw Exception('Empty response from AI');
      } catch (e) {
        attempts++;
        final errorStr = e.toString();

        // Handle transient errors or rate limits
        bool isTransient =
            errorStr.contains('429') ||
            errorStr.contains('500') ||
            errorStr.contains('503') ||
            errorStr.contains('deadline') ||
            errorStr.contains('SocketException');

        if (isTransient && attempts < maxRetries) {
          final delaySeconds = attempts * attempts * 2; // 2s, 8s, 18s...
          debugPrint(
            '⚠️ STT Attempt $attempts failed (Transient). Retrying in ${delaySeconds}s... ($e)',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }

        // If not transient or we've reached max retries, try the secondary fallback model
        if (attempts >= maxRetries) {
          debugPrint(
            '🔄 Max retries reached with Flash Lite. Trying Flash Latest as last resort...',
          );
          try {
            final fallbackResponse =
                await (_flashModel ??
                        GenerativeModel(
                          model: 'gemini-flash-latest',
                          apiKey: _apiKey,
                        ))
                    .generateContent(content);

            if (fallbackResponse.text != null &&
                fallbackResponse.text!.isNotEmpty) {
              debugPrint('✅ STT Success (Secondary Fallback)');
              return fallbackResponse.text!.trim();
            }
          } catch (e2) {
            debugPrint('❌ Final STT fallback also failed: $e2');
            rethrow;
          }
        }

        rethrow;
      }
    }
    return '$errorPrefix Transcription failed after multiple attempts.';
  }

  /// High-speed Raw STT via Groq Whisper (Large V3 Turbo) with Resilience
  Future<String> _transcribeWithGroq(String filePath) async {
    return _retry(() async {
      final url = Uri.parse(
        'https://api.groq.com/openai/v1/audio/transcriptions',
      );
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_groqApiKey'
        ..fields['model'] = 'whisper-large-v3-turbo'
        ..fields['response_format'] = 'verbose_json'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final segments = data['segments'] as List?;

        if (segments != null && segments.isNotEmpty) {
          return segments
              .map((s) {
                final start = s['start']?.toStringAsFixed(2) ?? '0.00';
                final end = s['end']?.toStringAsFixed(2) ?? '0.00';
                final text = s['text']?.trim() ?? '';
                return '[$start - $end]: $text';
              })
              .join('\n');
        }

        return data['text'] ?? '';
      } else {
        throw Exception(
          'Groq Whisper Error: ${response.statusCode} - ${response.body}',
        );
      }
    }, label: 'Groq Whisper');
  }

  /// High-fidelity Acoustic Transcription via Deepgram (Nova-2)
  Future<String> _transcribeWithDeepgram(String filePath) async {
    return _retry(() async {
      final url = Uri.parse(
        'https://api.deepgram.com/v1/listen?model=nova-2&diarize=true&smart_format=true&punctuate=true',
      );

      final bytes = await File(filePath).readAsBytes();

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Token $_deepgramApiKey',
              'Content-Type':
                  'audio/wav', // Nova-2 handles most formats automatically
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results']?['channels']?[0]?['alternatives']?[0];

        // Extract speaker-tagged segments if available
        final words = results?['words'] as List?;
        if (words != null && words.isNotEmpty) {
          final List<String> segments = [];
          int lastSpeaker = -1;
          StringBuffer currentSegment = StringBuffer();
          double segmentStart = 0.0;

          for (final word in words) {
            final int speaker = word['speaker'] ?? 0;
            final double start = (word['start'] as num).toDouble();
            final String text = word['punctuated_word'] ?? word['word'] ?? '';

            if (speaker != lastSpeaker) {
              if (currentSegment.isNotEmpty) {
                segments.add(
                  '[${segmentStart.toStringAsFixed(2)} - ${start.toStringAsFixed(2)}] Speaker $lastSpeaker: ${currentSegment.toString().trim()}',
                );
              }
              currentSegment = StringBuffer();
              segmentStart = start;
              lastSpeaker = speaker;
            }
            currentSegment.write('$text ');
          }

          if (currentSegment.isNotEmpty) {
            segments.add(
              '[${segmentStart.toStringAsFixed(2)}] Speaker $lastSpeaker: ${currentSegment.toString().trim()}',
            );
          }
          return segments.join('\n');
        }

        return data['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] ??
            '';
      } else {
        throw Exception(
          'Deepgram Error: ${response.statusCode} - ${response.body}',
        );
      }
    }, label: 'Deepgram Nova-2');
  }

  /// Generic Groq Chat Completion helper (Llama 3.3 70B) with Resilience
  Future<String> _callGroqChat(String prompt) async {
    return _retry(() async {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.3-70b-versatile',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a high-integrity transcription editor. Your SOLE task is to assign speaker labels to provided audio segments. \n\n'
                      'CRITICAL LINGUISTIC RULES:\n'
                      '1. SEMANTIC CONTINUITY: If a segment starts with a lowercase letter or follows a segment without ending punctuation (., ?, !), it MUST be assigned to the same speaker unless there is a huge timestamp gap.\n'
                      '2. SEGMENT SPLITTING: If a single segment contains a speaker shift (e.g., a question followed by an answer), you MUST split it into multiple JSON objects. \n'
                      '3. NO WORD EDITS: NEVER change, add, or remove a single word from the "text" field of the segments.\n'
                      '4. SPEAKER ROLES: Candidates provide technical explanations; Interviewers ask questions.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.1,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? '';
      } else {
        throw Exception(
          'Groq Chat Error: ${response.statusCode} - ${response.body}',
        );
      }
    }, label: 'Groq Llama');
  }

  /// Generic retry helper with exponential backoff
  Future<T> _retry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
    required String label,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await action();
      } catch (e) {
        attempts++;
        final errorStr = e.toString();

        bool isTransient =
            errorStr.contains('429') ||
            errorStr.contains('500') ||
            errorStr.contains('503') ||
            errorStr.contains('deadline') ||
            errorStr.contains('SocketException') ||
            errorStr.contains('TimeoutException');

        if (isTransient && attempts < maxRetries) {
          final delaySeconds = attempts * attempts * 2; // 2s, 8s, 18s...
          debugPrint(
            '⚠️ $label Attempt $attempts failed. Retrying in ${delaySeconds}s... ($e)',
          );
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('$label failed after $maxRetries attempts');
  }

  /// Converts raw text to structured JSON turns using Groq Llama 3.3
  Future<String> _diarizeWithGroq(
    String rawText, {
    String? role,
    String? level,
  }) async {
    final contextInfo = (role != null && level != null)
        ? 'This is a technical interview for a **$level $role** role.'
        : 'This is a technical interview session.';

    final prompt =
        'Role: Advanced Diarization & Role Assignment AI\n'
        'Task: Map numeric Acoustic IDs (Speaker 0, Speaker 1, etc.) to semantic roles based on dialogue context.\n\n'
        'INTERVIEW CONTEXT:\n'
        '$contextInfo\n\n'
        'SPECIFIC DIARIZATION RULES:\n'
        '1. **Acoustic Ground Truth**: The numeric IDs are high-fidelity. If "Speaker 0" talks, it is usually the same person.\n'
        '2. **Interviewer Attribution (HIGHEST PRIORITY)**: Any segment that is a QUESTION (ends with "?"), gives instructions ("Tell me about...", "Explain...", "Can you..."), or introduces a topic IS the Interviewer. Label it "Interviewer 1".\n'
        '3. **Candidate Attribution**: Segments that ANSWER questions, explain technical concepts, describe personal experience, or respond to prompts belong to the Candidate.\n'
        '4. **Single Speaker Fallback**: If the raw text has only ONE speaker ID (e.g., only "Speaker 0"), you MUST still split turns by detecting question/answer boundaries in the dialogue. Do NOT label everything as "Candidate".\n'
        '5. **Semantic Merging**: If Deepgram splits a single person into two IDs due to a stutter or noise but sentences are semantically continuous, MERGE them.\n'
        '6. **Role Labels**: Use exactly "Candidate", "Interviewer 1", or "Interviewer 2".\n'
        '7. IF THE PROVIDED TEXT IS EMPTY, SILENT, OR NONSENSICAL, RETURN: {"transcript": []}\n\n'
        'JSON FORMAT REQUIREMENT:\n'
        'Return ONLY a JSON object with a "transcript" array. Example (FOR FORMATTING ONLY, DO NOT COPY TEXT):\n'
        '{\n'
        '  "transcript": [\n'
        '    {"speaker": "Interviewer 1", "time": "0:00", "text": "Can you explain your experience with Flutter?"},\n'
        '    {"speaker": "Candidate", "time": "0:05", "text": "Sure, I have worked with Flutter for 3 years..."}\n'
        '  ]\n'
        '}\n\n'
        'RAW SEGMENTS TO PROCESS:\n$rawText';

    final result = await _callGroqChat(prompt);

    try {
      final decoded = jsonDecode(result);
      if (decoded is Map && decoded.containsKey('transcript')) {
        return jsonEncode(decoded['transcript']);
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ Groq JSON unwrapping failed, returning raw result: $e');
      return result;
    }
  }

  /// Total Orchestrator with Deepgram -> Groq Llama -> Gemini Fallback
  Future<String> _transcribeWithGroqPipeline(
    String filePath, {
    String? role,
    String? level,
  }) async {
    try {
      String rawAcousticText;

      // 1. Acoustic Stage: Use Deepgram (Nova-2) if available
      if (_deepgramApiKey.isNotEmpty) {
        try {
          debugPrint('🎙️ Using Deepgram for Acoustic Diarization...');
          rawAcousticText = await _transcribeWithDeepgram(filePath);
        } catch (e) {
          debugPrint('⚠️ Deepgram failed, falling back to Whisper: $e');
          rawAcousticText = await _transcribeWithGroq(filePath);
        }
      } else {
        // Fallback to Groq Whisper if no Deepgram key
        rawAcousticText = await _transcribeWithGroq(filePath);
      }

      // 2. Semantic Stage: Use Llama 3 to assign roles to the acoustic IDs
      debugPrint('🧠 Using Groq Llama for Semantic Role Assignment...');
      debugPrint('📝 Raw acoustic text passed to Llama:\n$rawAcousticText');
      final structuredJson = await _diarizeWithGroq(
        rawAcousticText,
        role: role,
        level: level,
      );

      return _validateAndCleanJson(structuredJson);
    } catch (e) {
      debugPrint(
        '⚠️ Groq Pipeline failed: $e. Falling back to Gemini Audio...',
      );
      // Final Fallback: Revert to legacy audio-processing mode with high-quality prompt
      final bytes = await File(filePath).readAsBytes();
      final content = [
        Content.multi([
          DataPart('audio/mp4', bytes),
          TextPart(
            'Transcribe this interview audio verbatim. \n'
            'Identify and separate multiple speakers. \n'
            'Label the primary candidate as "Candidate". \n'
            'Label different interviewers as "Interviewer 1", "Interviewer 2", etc.\n'
            'RULES:\n'
            '1. Return ONLY a valid JSON array of objects.\n'
            '2. Each object must have "speaker", "text", and "time" (in M:SS format) keys.\n'
            '3. IF NO SPEECH DETECTED, RETURN [].\n'
            'Format Example: [{"speaker": "Interviewer 1", "time": "0:00", "text": "..."}]',
          ),
        ]),
      ];
      final backupResult = await _generateWithRetry(content);
      return _validateAndCleanJson(backupResult);
    }
  }
}
