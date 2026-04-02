import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a single turn in an interview conversation
class TranscriptTurn {
  final String speaker;
  final String text;
  final String? timestamp;
  final int speakerId; // 0 for Candidate, 1-3+ for Interviewers, -1 for System

  TranscriptTurn({
    required this.speaker,
    required this.text,
    this.timestamp,
    this.speakerId = -1,
  });

  bool get isInterviewer =>
      speaker.toLowerCase().contains('interviewer') ||
      speaker.toLowerCase().contains('speaker 1');
  bool get isCandidate =>
      speaker.toLowerCase().contains('candidate') ||
      speaker.toLowerCase().contains('speaker 2');
}

/// Error prefix for transcription errors
const String sttErrorPrefix = 'STT_ERROR:';

/// Utility for parsing raw transcript text into a structured conversation
class TranscriptParser {
  /// Parses a transcript string into a list of [TranscriptTurn]s.
  static List<TranscriptTurn> parse(String rawTranscript) {
    if (rawTranscript.isEmpty) return [];

    // Check for transcription errors and return empty list gracefully
    if (rawTranscript.trim().startsWith(sttErrorPrefix)) {
      debugPrint('⚠️ Transcription not available: ${rawTranscript.trim()}');
      return [];
    }

    // Detect if the string starts with a JSON bracket (Structured Diarization)
    final trimmed = rawTranscript.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        return _parseJson(trimmed);
      } catch (e) {
        // Fallback to legacy parsing if JSON is malformed
      }
    }

    return _parseLegacy(rawTranscript);
  }

  /// Parses structured JSON diarization output
  static List<TranscriptTurn> _parseJson(String jsonStr) {
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((item) {
      final speaker = item['speaker']?.toString() ?? 'Unknown';
      return TranscriptTurn(
        speaker: speaker,
        text: item['text']?.toString() ?? '',
        timestamp: item['time']?.toString(),
        speakerId: _getSpeakerId(speaker),
      );
    }).toList();
  }

  /// Helper to map speaker names to IDs for UI color coding
  static int _getSpeakerId(String speaker) {
    final s = speaker.toLowerCase().trim();
    if (s.contains('candidate') ||
        s.contains('applicant') ||
        s.contains('user')) {
      return 0;
    }
    if (s.contains('interviewer 1') ||
        s.contains('speaker 1') ||
        s == 'interviewer') {
      return 1;
    }
    if (s.contains('interviewer 2') || s.contains('speaker 2')) {
      return 2;
    }
    if (s.contains('interviewer 3') || s.contains('speaker 3')) {
      return 3;
    }
    if (s.contains('ai') || s.contains('system')) {
      return -1; // System/AI colors
    }
    return 1; // Default to Interviewer 1 for unknown interviewer-like roles
  }

  /// Legacy parsing logic for plain text transcripts
  static List<TranscriptTurn> _parseLegacy(String rawTranscript) {
    if (rawTranscript.isEmpty) return [];

    // 1. Aggressively clean up common AI preambles/intros
    // We look for any text followed by a newline that doesn't start with a speaker label
    final lines = rawTranscript.split('\n');
    final List<String> filteredLines = [];
    bool conversationStarted = false;

    // Speaker pattern: Optional markdown stars, followed by Keyword, optional colon/stars
    final speakerPattern = RegExp(
      r'^[\*]*\s*(Interviewer|Candidate|AI|System|Speaker \d|User|Applicant)\s*[:\*]*',
      caseSensitive: false,
    );

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (!conversationStarted) {
        if (speakerPattern.hasMatch(trimmed)) {
          conversationStarted = true;
          filteredLines.add(line);
        }
        // Skip lines before the first speaker label
        continue;
      }
      filteredLines.add(line);
    }

    // If we filtered out everything (e.g., no labels found), fallback to original lines
    final List<String> processLines = filteredLines.isEmpty
        ? lines
        : filteredLines;

    final List<TranscriptTurn> turns = [];
    String currentSpeaker = 'Interviewer';
    StringBuffer currentText = StringBuffer();

    for (var line in processLines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Check for speaker tokens with broad resilience to markdown: **Speaker:**, Speaker:, etc.
      final interviewerMatch = RegExp(
        r'^[\*]*\s*(Interviewer|AI|System|Speaker 1)\s*[:\*]*\s*',
        caseSensitive: false,
      ).firstMatch(trimmedLine);

      final candidateMatch = RegExp(
        r'^[\*]*\s*(Candidate|User|Applicant|Speaker 2)\s*[:\*]*\s*',
        caseSensitive: false,
      ).firstMatch(trimmedLine);

      if (interviewerMatch != null) {
        if (currentText.isNotEmpty) {
          turns.add(
            TranscriptTurn(
              speaker: currentSpeaker,
              text: currentText.toString().trim(),
            ),
          );
        }
        currentSpeaker = 'Interviewer';
        currentText = StringBuffer()
          ..write(trimmedLine.substring(interviewerMatch.end).trim());
      } else if (candidateMatch != null) {
        if (currentText.isNotEmpty) {
          turns.add(
            TranscriptTurn(
              speaker: currentSpeaker,
              text: currentText.toString().trim(),
            ),
          );
        }
        currentSpeaker = 'Candidate';
        currentText = StringBuffer()
          ..write(trimmedLine.substring(candidateMatch.end).trim());
      } else {
        if (currentText.isNotEmpty) {
          currentText.write('\n$trimmedLine');
        } else {
          currentText.write(trimmedLine);
        }
      }
    }

    // Add final turn
    if (currentText.isNotEmpty) {
      turns.add(
        TranscriptTurn(
          speaker: currentSpeaker,
          text: currentText.toString().trim(),
        ),
      );
    }

    // Secondary cleanup: Strip any remaining wrapping asterisks from the start/end of texts
    return turns
        .map(
          (t) => TranscriptTurn(
            speaker: t.speaker,
            text: t.text.replaceAll(RegExp(r'^\*+|\*+$'), '').trim(),
            speakerId: _getSpeakerId(t.speaker),
          ),
        )
        .toList();
  }
}
