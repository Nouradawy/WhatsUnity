import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/admin_repository.dart';
import '../../bloc/admin_cubit.dart';
import '../../bloc/report_cubit.dart';
import 'AdminDashboard.dart';

/// Provides admin-specific cubits only when the admin dashboard is mounted.
class AdminDashboardScope extends StatelessWidget {
  const AdminDashboardScope({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ReportCubit(
            adminRepository: context.read<AdminRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => AdminCubit(
            adminRepository: context.read<AdminRepository>(),
          ),
        ),
      ],
      child: const AdminDashboard(),
    );
  }
}
