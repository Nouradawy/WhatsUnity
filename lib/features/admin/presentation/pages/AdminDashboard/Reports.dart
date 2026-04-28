import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/theme/lightTheme.dart';
import '../../../../../../core/config/Enums.dart';
import '../../bloc/admin_cubit.dart';
import '../../bloc/admin_state.dart';
import '../../../domain/entities/user_report.dart';

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadUserReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.reportHistory),
      ),
      body: BlocBuilder<AdminCubit, AdminState>(
        builder: (context, state) {
          final cubit = context.read<AdminCubit>();
          return Column(
            children: [
              Wrap(
                spacing: 8,
                children: List.generate(ReportAUserFilter.values.length, (i) {
                  return FilterChip(
                    label: Text(i == 2 ? 'In Review' : ReportAUserFilter.values[i].name),
                    selected: cubit.filterIndex == i, 
                    onSelected: (selected) {
                      cubit.changeFilter(i); // We might want a separate index for reports filter
                      cubit.loadUserReports(filter: ReportAUserFilter.values[i]);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state is AdminLoading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : state is AdminError
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(state.message, textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: () => cubit.loadUserReports(
                                    filter: ReportAUserFilter.values[cubit.filterIndex],
                                  ),
                                  child: Text(context.loc.retry),
                                ),
                              ],
                            ),
                          )
                        : _ReportsList(
                            reports: cubit.userReports,
                            onRefresh: () => cubit.loadUserReports(
                              filter: ReportAUserFilter.values[cubit.filterIndex],
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportsList extends StatelessWidget {
  final List<UserReport> reports;
  final VoidCallback onRefresh;
  const _ReportsList({required this.reports, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.loc.noReportsFound),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onRefresh,
              child: Text(context.loc.refresh),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(context.loc.reportedUserIdLabel(report.reportedUserId)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.loc.reasonLabel(report.reportedFor)),
                Text(context.loc.descriptionLabel(report.description)),
                Text(context.loc.dateLabel(report.createdAt.toString())),
              ],
            ),
            trailing: Chip(
              label: Text(report.state),
              backgroundColor: _getStatusColor(report.state),
            ),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.copy_all_outlined),
                          title: Text(context.loc.copyReportDetails),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: 'Report ID: ${report.id}\n'
                                    'Reported User ID: ${report.reportedUserId}\n'
                                    'Reason: ${report.reportedFor}\n'
                                    'Description: ${report.description}\n'
                                    'State: ${report.state}',
                              ),
                            );
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(context.loc.reportDetailsCopied),
                                ),
                              );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.close),
                          title: Text(context.loc.close),
                          onTap: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String state) {
    switch (state.toLowerCase()) {
      case 'new':
        return Colors.blue.shade100;
      case 'resolved':
        return Colors.green.shade100;
      case 'in review':
      case 'inreview':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
