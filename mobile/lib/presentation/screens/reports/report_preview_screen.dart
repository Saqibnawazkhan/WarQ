import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/route_args.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/services/report_service.dart';
import '../../state/base_controller.dart';

/// Full-screen PDF preview with print, share and save-to-device actions.
///
/// Preview, printing and sharing are provided by the platform through the
/// `printing` plugin, so the app uses the native share sheet rather than a
/// custom one.
class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({super.key, required this.args});

  final ReportPreviewArgs args;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  bool _saving = false;
  String? _savedPath;

  GeneratedReport get _report => widget.args.report;

  Future<void> _save() async {
    setState(() => _saving = true);
    final AppDependencies deps = context.read<AppDependencies>();
    try {
      final String path = await deps.reports.saveToDevice(_report);
      if (!mounted) return;
      setState(() {
        _savedPath = path;
        _saving = false;
      });
      context.showSuccess('Saved to $path');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showError(BaseController.describeFailure(error));
    }
  }

  Future<void> _share() async {
    final AppDependencies deps = context.read<AppDependencies>();
    try {
      await deps.reports.share(_report);
    } catch (_) {
      if (!mounted) return;
      context.showError('Could not open the share sheet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _report.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_report.subtitle} · ${_report.sizeInKb} KB',
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.mutedText),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share',
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Save to device',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_savedPath != null) _SavedBanner(path: _savedPath!),
          Expanded(
            child: PdfPreview(
              build: (PdfPageFormat format) async => _report.bytes,
              initialPageFormat: _report.pageFormat,
              pdfFileName: _report.fileName,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              maxPageWidth: 760,
              padding: const EdgeInsets.all(AppSpacing.md),
              loadingWidget: const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
              onError: (BuildContext context, Object error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    'The preview could not be rendered on this device, but the '
                    'report can still be shared or saved.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: context.semantic.successContainer,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: context.semantic.success,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Saved to $path',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.onSuccessContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kept for callers that only need the raw bytes (e.g. tests).
typedef ReportBytesBuilder = Future<Uint8List> Function(PdfPageFormat format);
