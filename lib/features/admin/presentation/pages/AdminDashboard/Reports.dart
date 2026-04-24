import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        title: const Text("Chat Reports"),
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
                    ? const Center(child: CircularProgressIndicator())
                    : _ReportsList(reports: cubit.userReports),
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
  const _ReportsList({required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(child: Text("No reports found."));
    }
    return ListView.builder(
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text("Reported User ID: ${report.reportedUserId}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Reason: ${report.reportedFor}"),
                Text("Description: ${report.description}"),
                Text("Date: ${report.createdAt}"),
              ],
            ),
            trailing: Chip(
              label: Text(report.state),
              backgroundColor: _getStatusColor(report.state),
            ),
            onTap: () {
              // Add detail view or action sheet here
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
