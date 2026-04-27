import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/Enums.dart';
import '../../../maintenance/presentation/bloc/maintenance_cubit.dart';
import '../../../maintenance/presentation/pages/maintenance_page.dart';
import '../../../security/presentation/pages/security_center_page.dart';
import '../pages/announcement_screen.dart';

SliverAppBar headerServices(context, isEnabledMultiCompound, currentSelectedCompoundId, currentMyCompounds, authCubit, services) {
  // We increase expandedHeight slightly to allow room for the animation
  // while keeping the initial state looking very similar to the original.
  final double expandedHeight = 89.h;
  final double collapsedHeight =6;

  return SliverAppBar(
    backgroundColor: Colors.white,
    pinned: true,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: false,
    expandedHeight: expandedHeight,
    toolbarHeight: collapsedHeight,
    flexibleSpace: LayoutBuilder(
      builder: (context, constraints) {
        final double currentHeight = constraints.maxHeight;
        // t = 1.0 when fully expanded, 0.0 when fully collapsed
        final double t = ((currentHeight - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

        return FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: Container(
            color: Colors.white,
            alignment: Alignment.bottomCenter,
            height: lerpDouble(50.h, 90.h, t),
            child: Container(
              margin: EdgeInsets.only(left: 10.w),
              // Card container height shrinks as we scroll up
              height: lerpDouble(10.h, 90.h, t),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];

                  // Width: initially 0.23 (original), expands to 0.36 to fit side-by-side
                  final double cardWidth = MediaQuery.sizeOf(context).width * lerpDouble(0.36, 0.23, t)!;

                  return Container(
                    width: cardWidth,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: service["Background"],
                    ),
                    child: MaterialButton(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onPressed: () {
                        if (index == 1) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SecurityCenterPage(),
                            ),
                          );
                        } else if (index == 3) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AnnouncementScreen()));
                        } else if (currentSelectedCompoundId != null) {
                          context.read<MaintenanceCubit>().getMaintenanceReports(
                                compoundId: currentSelectedCompoundId.toString(),
                                type: MaintenanceReportType.values[index],
                              );
                          Navigator.push(context, MaterialPageRoute(builder: (context) => Maintenance(maintenanceType: MaintenanceReportType.values[index])));
                        }
                      },
                      child: Stack(
                        children: [
                          // Icon Container
                          Align(
                            alignment: Alignment(
                              lerpDouble(-0.8, 0.0, t)!, // Move from center to left
                              lerpDouble(0.0, -0.2, t)!,  // Move from top-ish to center vertically
                            ),
                            child: Container(
                              width: lerpDouble(20.h, 38.h, t),
                              height: lerpDouble(32.h, 38.h, t),
                              padding: EdgeInsets.all(lerpDouble(6.h, 9.5.h, t)!),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: service["icon bg"],
                              ),
                              child: SvgPicture.asset(
                                service['icon'],
                                colorFilter: ColorFilter.mode(service["icon color"], BlendMode.srcIn),
                              ),
                            ),
                          ),
                          // Text Container
                          Align(
                            alignment: Alignment(
                              lerpDouble(0.55, 0.0, t)!, // Move from center to right
                              lerpDouble(0.0, 0.6, t)!,  // Move from bottom-ish to center vertically
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: lerpDouble(38.h, 0, t)!, // Push text right when icon is left
                              ),
                              child: SizedBox(
                                width: lerpDouble(cardWidth * 0.6, 100, t),
                                child: Text(
                                  service['Name'],
                                  textAlign: t > 0.5 ? TextAlign.center : TextAlign.left,
                                  maxLines: t > 0.5 ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: lerpDouble(10, 13, t),
                                    fontWeight: FontWeight.bold,
                                    color: service["text Color"],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}