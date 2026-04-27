import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/lightTheme.dart';
import '../../../../core/constants/Constants.dart';
import '../../../home/presentation/pages/main_screen.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';

class JoinCommunity extends StatefulWidget {
  final bool atWelcome;
  const JoinCommunity({
    super.key,
    this.atWelcome = false,
  });

  @override
  State<JoinCommunity> createState() => _JoinCommunityState();
}

class _JoinCommunityState extends State<JoinCommunity> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Do not call [loadCompounds] from [build] — every [AuthLoading] emit rebuilt the tree
    // and re-triggered load, causing an infinite AuthInitial ↔ AuthLoading loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<AuthCubit>();
      final s = cubit.state;
      if (kDebugMode) {
        debugPrint(
          '[JoinCommunity] init: state=${s.runtimeType} categories=${s.categories.length} '
          'logos=${s.compoundsLogos.length} — will call loadCompounds='
          '${s.categories.isEmpty || s.compoundsLogos.isEmpty}',
        );
      }
      if (cubit.state.categories.isEmpty) {
        cubit.loadCompounds();
      } else if (cubit.state.compoundsLogos.isEmpty) {
        // Categories already in memory (e.g. from preset) but logo manifest not loaded.
        cubit.loadCompounds();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(context.loc.joinCommunity),
        ),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();
            final categories = state.categories;

            if (categories.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                defaultTextForm(context,
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    SuffixIcon: Icons.search,
                    onChanged: (s) {
                  cubit.getSuggestions(_searchController);
                }),
                Expanded(
                  child: BlocConsumer<AuthCubit, AuthState>(
                      listenWhen: (p, c) => p.runtimeType != c.runtimeType,
                      listener: (context, states) {
                    if (states is CompoundSelected && widget.atWelcome == false) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => MainScreen()),
                        (Route<dynamic> route) =>
                            false, // This predicate removes all previous routes
                      );
                    } else if (states is CompoundSelected && widget.atWelcome == true) {
                      Navigator.pop(context);
                    }
                  }, builder: (context, states) {
                    final currentCategories = states.categories;
                    final currentLogos = states.compoundsLogos;
                    
                    return ListView.builder(
                      itemCount: _searchController.text.isEmpty
                          ? currentCategories.length
                          : cubit.compoundSuggestions.length,
                      itemBuilder: (context, index) {
                        final category = _searchController.text.isEmpty
                            ? currentCategories[index]
                            : cubit.compoundSuggestions[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Display the category name as a title
                              Text(
                                category.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const Divider(),

                              // Map the list of compounds to a list of ListTile widgets
                              ...category.compounds.reversed.map((compound) {
                                final assetPath =
                                    currentLogos.firstWhere((file) {
                                  final fileName = file.split('/').last; // "23.png"
                                  final nameWithoutExt =
                                      fileName.split('.').first; // "23"
                                  return nameWithoutExt ==
                                      compound.id.toString();
                                }, orElse: () => 'null');

                                return ListTile(
                                  tileColor: Colors.white38,
                                  minTileHeight: 70,
                                  onTap: () => context
                                      .read<AuthCubit>()
                                      .selectCompound(
                                          compoundId: compound.id,
                                          compoundName: compound.name,
                                          atWelcome: widget.atWelcome),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: assetPath != 'null'
                                        ? Image.asset(
                                            assetPath,
                                            width: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _compoundFallbackThumb(
                                                compound.pictureUrl,
                                              ),
                                          )
                                        : (compound.pictureUrl != null
                                            ? Image.network(
                                                compound.pictureUrl.toString(),
                                                width: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox.shrink(),
                                              )
                                            : const SizedBox.shrink()),
                                  ),
                                  subtitle: Text(compound.developer ?? ''),
                                  title: Text(compound.name),
                                  // You can add more details here if needed
                                  // subtitle: Text(compound.location ?? ''),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          },
        ));
  }
}

Widget _compoundFallbackThumb(String? pictureUrl) {
  if (pictureUrl == null || pictureUrl.isEmpty) {
    return const SizedBox.shrink();
  }
  return Image.network(
    pictureUrl,
    width: 80,
    height: 80,
    fit: BoxFit.cover,
  );
}
