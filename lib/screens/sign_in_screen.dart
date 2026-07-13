import 'dart:async';
import 'dart:io' show HttpServer, Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/user_repository.dart';
import '../theme/gw_theme.dart';
import '../widgets/desktop_chrome.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with SingleTickerProviderStateMixin {
  bool _loading    = false;
  bool _emailMode  = false;
  bool _isRegister = false;
  bool _obscure    = true;
  String _error    = '';
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final isDesktopPlatform = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktopPlatform) {
      await _signInWithGoogleDesktop();
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final gsi     = GoogleSignIn();
      final account = await gsi.signIn();
      if (account == null) { setState(() => _loading = false); return; }
      final auth = await account.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken);
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final u = result.user;
      if (u != null) {
        await UserRepository.saveProfile(AppUser(
          email: u.email ?? '',
          name: u.displayName ?? u.email ?? '',
          photoUrl: u.photoURL,
        ));
      }
      if (mounted) context.go('/main');
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _signInWithGoogleDesktop() async {
    setState(() { _loading = true; _error = ''; });
    HttpServer? server;
    bool dialogOpen = false;
    try {
      server = await HttpServer.bind('127.0.0.1', 0);
      final port = server.port;

      final url = Uri.parse('https://ihs-gwcorp.web.app/app-auth.html?port=$port');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser');
      }

      final completer = Completer<Map<String, String>?>();
      Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      server.listen((request) async {
        request.response.headers
          ..set('Access-Control-Allow-Origin', '*')
          ..set('Access-Control-Allow-Methods', 'GET, OPTIONS');
        if (request.method == 'OPTIONS') {
          request.response.statusCode = 200;
          await request.response.close();
          return;
        }
        final params = request.requestedUri.queryParameters;
        if (params.containsKey('id_token') && !completer.isCompleted) {
          completer.complete({
            'id_token':     params['id_token']     ?? '',
            'access_token': params['access_token'] ?? '',
          });
        }
        request.response.statusCode = 200;
        await request.response.close();
      });

      // Show confirmation dialog so user knows to complete sign-in in the browser
      if (mounted) {
        dialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _BrowserSignInDialog(
            onCancel: () {
              dialogOpen = false;
              if (!completer.isCompleted) completer.complete(null);
            },
          ),
        );
      }

      final tokens = await completer.future;
      await server.close(force: true);
      server = null;

      // Dismiss dialog once we have a result
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (tokens == null || tokens['id_token']!.isEmpty || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final cred = GoogleAuthProvider.credential(
        idToken:     tokens['id_token'],
        accessToken: tokens['access_token'],
      );
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final u = result.user;
      if (u != null) {
        await UserRepository.saveProfile(AppUser(
          email:    u.email ?? '',
          name:     u.displayName ?? u.email ?? '',
          photoUrl: u.photoURL,
        ));
      }
      if (mounted) context.go('/main');
    } catch (e) {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
      }
      await server?.close(force: true);
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      User? u;
      if (_isRegister) {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email, password: pass);
        final name = _nameCtrl.text.trim();
        if (name.isNotEmpty) await cred.user?.updateDisplayName(name);
        u = cred.user;
      } else {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, password: pass);
        u = cred.user;
      }
      if (u != null) {
        final typedName = _nameCtrl.text.trim();
        await UserRepository.saveProfile(AppUser(
          email: u.email ?? '',
          name: u.displayName?.isNotEmpty == true
              ? u.displayName!
              : typedName.isNotEmpty ? typedName : (u.email ?? ''),
          photoUrl: u.photoURL,
        ));
      }
      if (mounted) context.go('/main');
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Authentication failed'; _loading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { setState(() => _error = 'Enter your email first'); return; }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => _error = 'Reset link sent — check your email');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  bool get _isSuccess => _error.contains('sent');

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Scaffold(
      backgroundColor: gw.bg,
      body: Column(children: [
        const DesktopTitleBar(),
        Expanded(child: SafeArea(
          top: !isDesktop,
          child: LayoutBuilder(builder: (ctx, constraints) =>
          SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Logo
                Container(
                  width: 82, height: 82,
                  decoration: BoxDecoration(
                    color: gw.greenGlow, shape: BoxShape.circle,
                    border: Border.all(color: gw.green.withOpacity(0.4), width: 1.5),
                    boxShadow: [BoxShadow(
                        color: gw.green.withOpacity(0.25), blurRadius: 36, spreadRadius: 4)],
                  ),
                  child: Icon(Icons.recycling, color: gw.green, size: 40),
                ),
                const SizedBox(height: 22),
                Text('GWCORP',
                    style: TextStyle(color: gw.text, fontSize: 28,
                        fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                const SizedBox(height: 6),
                Text('Waste Intelligence Platform',
                    style: TextStyle(color: gw.muted, fontSize: 13)),
                const SizedBox(height: 44),

                // Error / success message
                if (_error.isNotEmpty) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isSuccess ? gw.green : gw.red).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: (_isSuccess ? gw.green : gw.red).withOpacity(0.25)),
                    ),
                    child: Text(_error, style: TextStyle(
                        color: _isSuccess ? gw.green : gw.red, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Google button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: _loading
                        ? SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: gw.bg))
                        : const Icon(Icons.g_mobiledata, size: 26),
                    label: Text(_loading ? 'Signing in…' : 'Sign in with Google',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gw.green,
                      foregroundColor: gw.isDark ? gw.bg : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  Expanded(child: Divider(color: gw.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('or', style: TextStyle(color: gw.muted, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: gw.border)),
                ]),
                const SizedBox(height: 20),

                // Email section
                if (!_emailMode)
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _emailMode = true),
                      icon: const Icon(Icons.email_outlined, size: 20),
                      label: const Text('Continue with Email',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: gw.text,
                        side: BorderSide(color: gw.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  )
                else ...[
                  if (_isRegister) ...[
                    _field(gw, _nameCtrl, 'Display Name', Icons.person_outline, false),
                    const SizedBox(height: 12),
                  ],
                  _field(gw, _emailCtrl, 'Email', Icons.email_outlined, false),
                  const SizedBox(height: 12),
                  _field(gw, _passCtrl, 'Password', Icons.lock_outline, _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined, color: gw.muted, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gw.green,
                        foregroundColor: gw.isDark ? gw.bg : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: gw.bg))
                          : Text(_isRegister ? 'Create Account' : 'Sign In',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    if (!_isRegister)
                      TextButton(
                        onPressed: _resetPassword,
                        child: Text('Forgot Password?',
                            style: TextStyle(color: gw.muted, fontSize: 12)),
                      )
                    else
                      const SizedBox(),
                    TextButton(
                      onPressed: () => setState(() {
                        _isRegister = !_isRegister;
                        _error = '';
                      }),
                      child: Text(
                        _isRegister ? 'Already have an account?' : 'Create Account',
                        style: TextStyle(color: gw.green, fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
          )),
        )))),
      )),
    ]),
    );
  }

  Widget _field(GwColors gw, TextEditingController ctrl, String label,
      IconData icon, bool obscure, {Widget? suffix}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: label == 'Email' ? TextInputType.emailAddress : TextInputType.text,
        style: TextStyle(color: gw.text, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: gw.muted, fontSize: 13),
          prefixIcon: Icon(icon, color: gw.muted, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: gw.bg2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: gw.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: gw.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: gw.green, width: 1.5)),
        ),
      );
}

class _BrowserSignInDialog extends StatefulWidget {
  final VoidCallback onCancel;
  const _BrowserSignInDialog({required this.onCancel});
  @override
  State<_BrowserSignInDialog> createState() => _BrowserSignInDialogState();
}

class _BrowserSignInDialogState extends State<_BrowserSignInDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    return Dialog(
      backgroundColor: gw.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: gw.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.center, children: [
              RotationTransition(
                turns: _spin,
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [
                      gw.green.withOpacity(0.0),
                      gw.green.withOpacity(0.6),
                    ]),
                  ),
                ),
              ),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: gw.greenGlow,
                  shape: BoxShape.circle,
                  border: Border.all(color: gw.green.withOpacity(0.35), width: 1.5),
                ),
                child: Icon(Icons.open_in_browser_rounded, color: gw.green, size: 24),
              ),
            ]),
            const SizedBox(height: 18),
            Text(
              'Sign in via your browser',
              style: TextStyle(
                color: gw.text, fontSize: 16, fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A browser window has opened.\nComplete your Google sign-in there —\nthis dialog will close automatically.',
              style: TextStyle(color: gw.muted, fontSize: 13, height: 1.55),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.onCancel();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: gw.muted,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: gw.border),
                  ),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
