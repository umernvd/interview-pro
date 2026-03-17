import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../extensions/verdict_pdf_extension.dart';
import '../../presentation/providers/report_data_provider.dart';

/// Service responsible for generating and downloading interview report PDFs
class ReportPdfService {
  /// Generate the PDF and return the saved file path
  static Future<String> generatePdfFile(
    ReportData reportData, {
    bool isPreview = true,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(reportData),
          pw.SizedBox(height: 24),
          _buildCandidateInfo(reportData),
          pw.SizedBox(height: 32),
          _buildScoreSection(reportData),
          pw.SizedBox(height: 32),
          _buildTechnicalQuestions(reportData),
          pw.SizedBox(height: 32),
          _buildSoftSkills(reportData),
          if (reportData.additionalComments.isNotEmpty) ...[
            pw.SizedBox(height: 32),
            _buildComments(reportData),
          ],
          pw.SizedBox(height: 32),
          _buildFooter(),
        ],
      ),
    );

    final dir = isPreview
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final fileName =
        'Interview_Report_${reportData.interview.candidateName.replaceAll(' ', '_')}.pdf';
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static pw.Widget _buildHeader(ReportData reportData) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'InterviewPro',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red600,
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INTERVIEW EVALUATION',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              'REPORT',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCandidateInfo(ReportData reportData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoItem('CANDIDATE NAME', reportData.interview.candidateName),
              _infoItem('POSITION', reportData.roleName.toUpperCase()),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _infoItem(
                'LEVEL',
                reportData.interview.level.title.toUpperCase(),
              ),
              _infoItem('DATE', _formatDate(reportData.interview.startTime)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey50,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildScoreSection(ReportData reportData) {
    // Determine color and text based on verdict (if available) or score (fallback)
    PdfColor color;
    PdfColor textColor;
    String text;

    if (reportData.verdict != null) {
      text = reportData.verdict!.displayName.toUpperCase();
      color = reportData.verdict!.pdfColor;
      textColor = reportData.verdict!.pdfTextColor;
    } else {
      // Fallback for legacy data
      final isPassing = reportData.overallScore >= 70;
      text = isPassing ? 'RECOMMENDED' : 'NOT RECOMMENDED';
      color = isPassing ? PdfColors.green100 : PdfColors.red100;
      textColor = isPassing ? PdfColors.green800 : PdfColors.red800;
    }

    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            '${reportData.overallScore.toInt()}%',
            style: pw.TextStyle(
              fontSize: 64,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red600,
            ),
          ),
          pw.Text(
            'OVERALL SCORE',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
            ),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTechnicalQuestions(ReportData reportData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'KEY TECHNICAL QUESTIONS',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 12),
        ...reportData.interview.responses
            .take(3)
            .map((r) => _buildQuestionRow(r)),
      ],
    );
  }

  static pw.Widget _buildQuestionRow(dynamic response) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 2),
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: response.isCorrect ? PdfColors.green500 : PdfColors.red500,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  response.questionText,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  response.notes ?? 'No feedback provided',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSoftSkills(ReportData reportData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SOFT SKILLS ASSESSMENT',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: _skillItem(
                'Communication',
                reportData.communicationSkills,
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _skillItem(
                'Problem Solving',
                reportData.problemSolvingApproach,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: _skillItem('Cultural Fit', reportData.culturalFit),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _skillItem(
                'Overall Impression',
                reportData.overallImpression,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _skillItem(String label, int rating) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Row(
          children: List.generate(5, (index) {
            return pw.Container(
              width: 10,
              height: 10,
              margin: const pw.EdgeInsets.only(right: 2),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: index < rating ? PdfColors.red600 : PdfColors.grey300,
              ),
            );
          }),
        ),
      ],
    );
  }

  static pw.Widget _buildComments(ReportData reportData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INTERVIEWER COMMENTS',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.grey200),
          ),
          child: pw.Text(
            reportData.additionalComments.isEmpty
                ? 'No additional comments provided.'
                : reportData.additionalComments,
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by InterviewPro',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              _formatDate(DateTime.now()),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
