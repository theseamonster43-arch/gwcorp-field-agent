import 'dart:async';
import 'dart:io' show HttpServer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/user_repository.dart';
import '../../theme/gw_theme.dart';
import '../../widgets/gw_glass.dart';

class IosSignInScreen extends StatefulWidget {
  const IosSignInScreen({super.key});
  @override
  State<IosSignInScreen> createState() => _IosSignInScreenState();
}

class _IosSignInScreenState extends State<IosSignInScreen> {
  bool   _loading    = false;
  bool   _emailMode  = false;
  bool   _isRegister = false;
  bool   _obscure    = true;
  String _error      = '';
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = ''; });
    HttpServer? server;
    bool dialogOpen = false;
    try {
      server = await HttpServer.bind('127.0.0.1', 0);
      final port = server.port;
      final url = Uri.parse('https://ihs-gwcorp.firebaseapp.com/app-auth.html?port=$port');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open browser');
      }
      final completer = Completer<Map<String, String>?>();
      Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) completer.complete(null);
      });
      server.listen((req) async {
        req.response.headers
          ..set('Access-Control-Allow-Origin', '*')
          ..set('Access-Control-Allow-Methods', 'GET, OPTIONS');
        if (req.method == 'OPTIONS') { req.response.statusCode = 200; await req.response.close(); return; }
        final p = req.requestedUri.queryParameters;
        if (p.containsKey('id_token') && !completer.isCompleted) {
          completer.complete({'id_token': p['id_token'] ?? '', 'access_token': p['access_token'] ?? ''});
        }
        req.response.statusCode = 200;
        await req.response.close();
      });
      if (mounted) {
        final gw = GwTheme.of(context);
        dialogOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: gw.bg2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Complete sign-in',
              style: TextStyle(color: gw.text, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            content: Text(
              'A browser window has opened.\nComplete your Google sign-in there.',
              style: TextStyle(color: gw.muted, fontSize: 13, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dialogOpen = false;
                  if (!completer.isCompleted) completer.complete(null);
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: gw.red, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }
      final tokens = await completer.future;
      await server.close(force: true);
      server = null;
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      if (tokens == null || (tokens['id_token'] ?? '').isEmpty) {
        setState(() => _loading = false); return;
      }
      final cred   = GoogleAuthProvider.credential(idToken: tokens['id_token'], accessToken: tokens['access_token']);
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final u = result.user;
      if (u != null) {
        await UserRepository.saveProfile(AppUser(email: u.email ?? '', name: u.displayName ?? u.email ?? '', photoUrl: u.photoURL));
      }
      if (mounted) context.go('/main');
    } catch (e) {
      if (dialogOpen && mounted) { dialogOpen = false; try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {} }
      await server?.close(force: true);
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) { setState(() => _error = 'Please fill in all fields'); return; }
    setState(() { _loading = true; _error = ''; });
    try {
      User? u;
      if (_isRegister) {
        final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
        final name = _nameCtrl.text.trim();
        if (name.isNotEmpty) await c.user?.updateDisplayName(name);
        u = c.user;
      } else {
        final c = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
        u = c.user;
      }
      if (u != null) {
        final typedName = _nameCtrl.text.trim();
        await UserRepository.saveProfile(AppUser(
          email: u.email ?? '',
          name: u.displayName?.isNotEmpty == true ? u.displayName! : typedName.isNotEmpty ? typedName : (u.email ?? ''),
          photoUrl: u.photoURL,
        ));
      }
      if (mounted) context.go('/main');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message ?? 'Authentication failed'; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { setState(() => _error = 'Enter your email first'); return; }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _error = 'Reset link sent — check your email');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  bool get _isSuccess => _error.contains('sent');

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final banner = _isSuccess ? gw.green : gw.red;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GwScreenBg(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: GwGlass(
                        radius: 26,
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: gw.green.withOpacity(.15),
                                border: Border.all(color: gw.green.withOpacity(.4), width: 1.5),
                              ),
                              child: Icon(Icons.recycling, size: 36, color: gw.green),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'GWCORP',
                              style: TextStyle(
                                color: gw.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Waste Intelligence Platform',
                              style: TextStyle(color: gw.muted, fontSize: 12.5),
                            ),
                            const SizedBox(height: 30),

                            if (_error.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: banner.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: banner.withOpacity(.35), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                                      size: 16,
                                      color: banner,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: TextStyle(color: banner, fontSize: 12, height: 1.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            _GlassButton(
                              label: _loading ? 'Signing in…' : 'Sign in with Google',
                              icon: Icons.g_mobiledata_rounded,
                              primary: true,
                              enabled: !_loading,
                              onTap: _signInWithGoogle,
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(child: Divider(color: gw.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'or',
                                    style: TextStyle(color: gw.muted, fontSize: 11.5),
                                  ),
                                ),
                                Expanded(child: Divider(color: gw.border)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            if (!_emailMode)
                              _GlassButton(
                                label: 'Continue with Email',
                                icon: Icons.email_outlined,
                                onTap: () => setState(() => _emailMode = true),
                              )
                            else ...[
                              if (_isRegister) ...[
                                _field('Display Name', Icons.person_outline, _nameCtrl, false),
                                const SizedBox(height: 10),
                              ],
                              _field('Email', Icons.email_outlined, _emailCtrl, false),
                              const SizedBox(height: 10),
                              _field(
                                'Password',
                                Icons.lock_outline,
                                _passCtrl,
                                _obscure,
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscure = !_obscure),
                                  child: Icon(
                                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: gw.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _GlassButton(
                                label: _loading ? 'Please wait…' : (_isRegister ? 'Create Account' : 'Sign In'),
                                primary: true,
                                enabled: !_loading,
                                onTap: _submitEmail,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (!_isRegister)
                                    TextButton(
                                      onPressed: _resetPassword,
                                      child: Text(
                                        'Forgot password?',
                                        style: TextStyle(color: gw.muted, fontSize: 12),
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  TextButton(
                                    onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
                                    child: Text(
                                      _isRegister ? 'Already have an account?' : 'Create account',
                                      style: TextStyle(
                                        color: gw.green,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, IconData icon, TextEditingController ctrl, bool obscure, {Widget? suffix}) {
    final gw = GwTheme.of(context);
    return GwGlass(
      radius: 14,
      blur: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: label == 'Email' ? TextInputType.emailAddress : TextInputType.text,
        style: TextStyle(color: gw.text, fontSize: 14.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          hintText: label,
          hintStyle: TextStyle(color: gw.muted, fontSize: 14),
          icon: Icon(icon, size: 18, color: gw.muted),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool enabled;

  const _GlassButton({
    required this.label,
    this.icon,
    this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final gw = GwTheme.of(context);
    final fg = primary ? gw.green : gw.text;

    Widget button = GwGlass(
      radius: 16,
      accent: primary ? gw.green : null,
      padding: const EdgeInsets.symmetric(vertical: 15),
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 9),
          ],
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    if (!enabled) button = Opacity(opacity: 0.55, child: button);
    return SizedBox(width: double.infinity, child: button);
  }
}
