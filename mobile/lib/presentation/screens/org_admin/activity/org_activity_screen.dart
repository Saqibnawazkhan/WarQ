import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/models.dart';
import '../../../state/base_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/domain/activity_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Full organization activity log, grouped by day.
class OrgActivityScreen extends StatefulWidget {
  const OrgActivityScreen({super.key});

  @override
  State<OrgActivityScreen> createState() => _OrgActivityScreenState();
}

class _OrgActivityScreenState extends State<OrgActivityScreen> {
  List<ActivityLog> _logs = const <ActivityLog>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser admin = context.read<SessionController>().requireUser;
    final String? organizationId = admin.organizationId;

    try {
      final List<ActivityLog> logs = organizationId == null
          ? const <ActivityLog>[]
          : await deps.activity.listForOrganization(organizationId, limit: 200);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = BaseController.describeFailure(error);
        _loading = false;
      });
    }
  }

  Map<String, List<ActivityLog>> get _grouped {
    final Map<String, List<ActivityLog>> grouped = <String, List<ActivityLog>>{};
    for (final ActivityLog log in _logs) {
      grouped
          .putIfAbsent(AppDate.relativeDay(log.createdAt), () => <ActivityLog>[])
          .add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_loading) return const LoadingView();
            if (_error != null) {
              return ErrorView(message: _error!, onRetry: _load);
            }
            if (_logs.isEmpty) {
              return const EmptyView(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                message:
                    'Everything your teachers do — classes, attendance, marks '
                    'and reports — is logged here.',
              );
            }

            final Map<String, List<ActivityLog>> grouped = _grouped;
            return RefreshIndicator(
              onRefresh: _load,
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    for (final MapEntry<String, List<ActivityLog>> entry
                        in grouped.entries) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: AppSpacing.md,
                        ),
                        child: Text(
                          entry.key,
                          style: context.text.labelLarge?.copyWith(
                            color: context.semantic.mutedText,
                          ),
                        ),
                      ),
                      AppCard(
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < entry.value.length; i++)
                              ActivityTile(
                                log: entry.value[i],
                                showActor: true,
                                isLast: i == entry.value.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const Gap.xxl(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
