import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/runtime_env.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/appwrite.dart';
import '../../../../core/services/PresenceManager.dart';
import '../bloc/auth_cubit.dart';
import '../../../home/presentation/pages/main_screen.dart';

/// Email **ownership** verification (sets `user.emailVerification`).
///
/// - Send: [Account.createEmailVerification] — the email may include a link
///   (with `userId` + `secret` query params) and/or a short code, depending
///   on the template in the Appwrite Console.
/// - Confirm: [Account.updateEmailVerification] with that **same** `secret`
///   string (not [Account.createEmailToken], which is for passwordless
///   [Account.createSession] and would cause `user_invalid_token` here).
///
/// Requires a whitelisted `APPWRITE_EMAIL_VERIFICATION_URL` (or
/// `APPWRITE_OAUTH_SUCCESS`) at compile time ([RuntimeEnv]) for the send step.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.email, this.isProfile});

  final String? email;
  final bool? isProfile;

  OtpScreen copyWithEmail(String email) => OtpScreen(
        email: email,
        isProfile: false,
      );

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _isEditingEmail = false;

  final _digitControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  final _pastedSecretController = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  int _secondsLeft = 60;
  Timer? _timer;


  @override
  void initState() {
    super.initState();

    var init = (widget.email ?? '').trim();
    _emailController.text = init;

    _isEditingEmail = init.isEmpty;
    if (_isEditingEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emailFocusNode.requestFocus();
      });
    }

    _emailController.addListener(() => setState(() {}));
    _pastedSecretController.addListener(() => setState(() {}));

    _startTimer();

    if (init.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstFrame());
  }

  Future<void> _onFirstFrame() async {
    try {
      final me = await appwriteAccount.get();
      if (_emailController.text.trim().isEmpty && me.email.isNotEmpty) {
        _emailController.text = me.email;
        if (mounted) setState(() {});
      }
      if (me.emailVerification) {
        if (!mounted) return;
        if (widget.isProfile == true) {
          Navigator.of(context).pop();
        } else {
          await _finishSignUpAfterVerification();
        }
        return;
      }
      await _sendVerificationEmail();
    } on AppwriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is StateError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Whitelisted platform URL for [Account.createEmailVerification] (not optional).
  String? get _emailVerificationRedirectUrl {
    final direct = RuntimeEnv.appwriteEmailVerificationUrl?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final oauth = RuntimeEnv.appwriteOauthSuccess?.trim();
    if (oauth != null && oauth.isNotEmpty) return oauth;
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pastedSecretController.dispose();
    _emailController.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _collectCode() => _digitControllers.map((c) => c.text).join();

  /// Resolves the verification `secret` for [updateEmailVerification] — either
  /// a pasted full URL (query `secret` / optional `userId`) or the raw code
  /// string from the 6-box fields.
  ({String secret, String? userIdFromUrl})? _parseVerificationInput(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.contains('secret=') ||
        t.contains('userId=') ||
        t.contains('?') ||
        t.startsWith('http:') ||
        t.startsWith('https:') ||
        t.contains('://')) {
      final u = Uri.tryParse(t);
      if (u != null) {
        final s = u.queryParameters['secret'] ?? u.queryParameters['token'];
        if (s != null && s.isNotEmpty) {
          return (secret: s, userIdFromUrl: u.queryParameters['userId']);
        }
      }
    }
    return (secret: t, userIdFromUrl: null);
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      _fillFromPasted(value, index);
      return;
    }
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[index + 1].requestFocus();
      });
    }
    if (value.isEmpty && index > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[index - 1].requestFocus();
      });
    }
    setState(() {});
  }

  void _fillFromPasted(String value, int startIndex) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < 6; i++) {
      final v = (i < digits.length) ? digits[i] : '';
      _digitControllers[i].text = v;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nextEmpty = _digitControllers.indexWhere((c) => c.text.isEmpty);
      final idx = nextEmpty == -1 ? 5 : nextEmpty;
      _focusNodes[idx].requestFocus();
    });
    setState(() {});
  }

  /// Sends the verification message ([Account.createEmailVerification]) so the
  /// [secret] in the email / link matches [Account.updateEmailVerification].
  Future<void> _sendVerificationEmail() async {
    await appwriteAccount.get();
    final url = _emailVerificationRedirectUrl;
    if (url == null) {
      throw StateError(
        'Set APPWRITE_EMAIL_VERIFICATION_URL (or APPWRITE_OAUTH_SUCCESS) at build time '
        '(e.g. flutter run --dart-define-from-file=.env) to a URL allowed under your '
        'project platforms, e.g. your app custom scheme for deep link (myapp://verify) '
        'or an https app link.',
      );
    }
    await appwriteAccount.createEmailVerification(url: url);
  }

  Future<void> _finishSignUpAfterVerification() async {
    final authCubit = context.read<AuthCubit>();
    await authCubit.presetBeforeSignin();
    await authCubit.verificationFilesUpload();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PresenceManager(child: const MainScreen()),
      ),
      (route) => false,
    );
  }

  Future<void> _verify() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailController.text.trim();
    final pasted = _pastedSecretController.text.trim();
    final fromBoxes = _collectCode();
    final raw = pasted.isNotEmpty ? pasted : fromBoxes;
    if (email.isEmpty || raw.isEmpty) return;
    final parsed = _parseVerificationInput(raw);
    if (parsed == null) return;

    setState(() => _verifying = true);
    try {
      final me = await appwriteAccount.get();
      if (parsed.userIdFromUrl != null && parsed.userIdFromUrl != me.$id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This code is for a different account. Use the same session you registered with.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      await appwriteAccount.updateEmailVerification(
        userId: me.$id,
        secret: parsed.secret,
      );

      if (!mounted) return;

      final authCubit = context.read<AuthCubit>();
      if (widget.isProfile == true) {
        await authCubit.presetBeforeSignin();
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final u = await appwriteAccount.get();
      if (u.prefs.data['role_id'] != null) {
        final roleId = u.prefs.data['role_id'];
        final rid = roleId is int ? roleId : int.tryParse(roleId.toString());
        if (rid != null && rid > 0 && rid <= Roles.values.length) {
          authCubit.updateRole(Roles.values[rid - 1]);
        }
      }

      await _finishSignUpAfterVerification();
    } on AppwriteException catch (e) {
      if (kDebugMode) {
        debugPrint('verify email: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Verification failed. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('verifyOTP unknown error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || _secondsLeft > 0) return;
    setState(() => _resending = true);
    try {
      await _sendVerificationEmail();
      _startTimer();
    } on AppwriteException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (e is StateError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        debugPrint('Resend unknown error: $e');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  bool get _canVerify {
    if (_emailController.text.trim().isEmpty || _verifying) return false;
    if (_pastedSecretController.text.trim().length >= 4) return true;
    return _digitControllers.every((c) => c.text.length == 1);
  }

  Widget _buildOtpBoxes() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(6, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 44,
              child: TextField(
                controller: _digitControllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (v) => _onDigitChanged(i, v),
                onTap: () {
                  final firstEmpty =
                      _digitControllers.indexWhere((c) => c.text.isEmpty);
                  if (firstEmpty != -1 && i > firstEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _focusNodes[firstEmpty].requestFocus();
                    });
                  }
                },
                onSubmitted: (_) {
                  if (i == 5 && _canVerify) _verify();
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCompactEmailField() {
    final emailEmpty = _emailController.text.trim().isEmpty;
    final textStyle = Theme.of(context).textTheme.bodyMedium!;
    const hint = 'name@example.com';
    final value = _emailController.text.trim().isEmpty
        ? hint
        : _emailController.text.trim();

    final painter = TextPainter(
      text: TextSpan(text: value, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final measured = painter.width + 6;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.6;
    final fieldWidth = measured.clamp(60.0, maxWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "We Just sent an Email",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        const Text(
          "Enter the code we sent, or paste the full verification link",
          style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                enabled: _isEditingEmail,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration.collapsed(hintText: 'name@example.com'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (widget.isProfile == false) ...[
              IconButton(
                tooltip: _isEditingEmail ? 'Lock' : 'Edit',
                onPressed: () {
                  setState(() {
                    _isEditingEmail = !_isEditingEmail;
                    if (_isEditingEmail) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _emailFocusNode.requestFocus();
                      });
                    } else {
                      FocusScope.of(context).unfocus();
                    }
                  });
                },
                icon: Icon(_isEditingEmail ? Icons.lock_open : Icons.edit),
              ),
              Icon(
                emailEmpty ? Icons.warning_amber_rounded : Icons.check_circle,
                color: emailEmpty ? Colors.orange : Colors.green,
                size: 20,
              ),
            ]
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: widget.isProfile == true
            ? null
            : AppBar(title: const Text('Verify email')),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: widget.isProfile == false ? 100 : 5),
                      _buildCompactEmailField(),
                      const SizedBox(height: 8),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pastedSecretController,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Code or full verification link',
                          hintText: 'Paste link from the email, or use the 6 boxes below',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _buildOtpBoxes(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _canVerify ? _verify : null,
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Verify'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          if (_resending ||
                              _secondsLeft > 0 ||
                              _emailController.text.isEmpty) {
                            return;
                          }
                          _resend();
                        },
                        child: _resending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _secondsLeft > 0
                                    ? 'Resend code in $_secondsLeft s'
                                    : 'Resend code',
                              ),
                      ),
                      if (widget.isProfile == true)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
