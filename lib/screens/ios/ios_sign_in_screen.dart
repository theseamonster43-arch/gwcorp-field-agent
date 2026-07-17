import 'dart:async';
import 'dart:io' show HttpServer, Platform;
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/user_repository.dart';

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
        dialogOpen = true;
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Complete sign-in'),
            content: const Text('A browser window has opened.\nComplete your Google sign-in there.'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  dialogOpen = false;
                  if (!completer.isCompleted) completer.complete(null);
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: const Text('Cancel'),
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
      if (tokens == null || tokens['id_token']!.isEmpty || !mounted) {
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
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: Stack(
        children: [
          // Rich gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0A1F10), const Color(0xFF071409), const Color(0xFF0D1A0F)]
                      : [const Color(0xFFB8F5D4), const Color(0xFFE8FAF0), const Color(0xFFD4F5E3)],
                ),
              ),
            ),
          ),
          // Glowing blobs for glass to contrast against
          Positioned(top: -60, left: -40,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withOpacity(isDark ? 0.30 : 0.45),
              ),
            ),
          ),
          Positioned(top: 120, right: -80,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF16A34A).withOpacity(isDark ? 0.22 : 0.35),
              ),
            ),
          ),
          Positioned(bottom: 80, left: 20,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4ADE80).withOpacity(isDark ? 0.18 : 0.30),
              ),
            ),
          ),
          Positioned(bottom: -40, right: 30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF86EFAC).withOpacity(isDark ? 0.15 : 0.25),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: LiquidGlassContainer(
                          config: LiquidGlassConfig(
                            effect: CNGlassEffect.regular,
                            shape: CNGlassEffectShape.rect,
                            cornerRadius: 20,
                            interactive: false,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo
                                Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF22C55E).withOpacity(0.15),
                                    border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4), width: 1.5),
                                  ),
                                  child: const Icon(CupertinoIcons.arrow_2_circlepath, color: Color(0xFF22C55E), size: 36),
                                ),
                                const SizedBox(height: 18),
                                Text('GWCORP',
                                    style: TextStyle(
                                      fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2,
                                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                    )),
                                const SizedBox(height: 4),
                                Text('Waste Intelligence Platform',
                                    style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context))),
                                const SizedBox(height: 32),

                                // Error / success
                                if (_error.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (_isSuccess ? CupertinoColors.systemGreen : CupertinoColors.systemRed).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: (_isSuccess ? CupertinoColors.systemGreen : CupertinoColors.systemRed).withOpacity(0.3)),
                                    ),
                                    child: Text(_error,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _isSuccess ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                                        )),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Google sign-in
                                SizedBox(
                                  width: double.infinity,
                                  child: CNButton(
                                    label: _loading ? 'Signing in…' : 'Sign in with Google',
                                    icon: CNSymbol('person.crop.circle'),
                                    config: CNButtonConfig(style: CNButtonStyle.glass),
                                    enabled: !_loading,
                                    onPressed: _signInWithGoogle,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Divider
                                Row(children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('or',
                                        style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context))),
                                  ),
                                  const Expanded(child: Divider()),
                                ]),
                                const SizedBox(height: 20),

                                // Email section
                                if (!_emailMode)
                                  SizedBox(
                                    width: double.infinity,
                                    child: CNButton(
                                      label: 'Continue with Email',
                                      icon: CNSymbol('envelope'),
                                      config: CNButtonConfig(style: CNButtonStyle.glass),
                                      onPressed: () => setState(() => _emailMode = true),
                                    ),
                                  )
                                else ...[
                                  if (_isRegister) ...[
                                    _field('Display Name', CupertinoIcons.person, _nameCtrl, false),
                                    const SizedBox(height: 10),
                                  ],
                                  _field('Email', CupertinoIcons.mail, _emailCtrl, false),
                                  const SizedBox(height: 10),
                                  _field('Password', CupertinoIcons.lock, _passCtrl, _obscure,
                                      suffix: GestureDetector(
                                        onTap: () => setState(() => _obscure = !_obscure),
                                        child: Icon(_obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                                            color: CupertinoColors.secondaryLabel.resolveFrom(context), size: 18),
                                      )),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: CNButton(
                                      label: _loading ? 'Please wait…' : (_isRegister ? 'Create Account' : 'Sign In'),
                                      config: CNButtonConfig(style: CNButtonStyle.glass),
                                      enabled: !_loading,
                                      onPressed: _submitEmail,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    if (!_isRegister)
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: _resetPassword,
                                        child: Text('Forgot Password?',
                                            style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context))),
                                      )
                                    else
                                      const SizedBox(),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
                                      child: Text(
                                        _isRegister ? 'Already have an account?' : 'Create Account',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF22C55E)),
                                      ),
                                    ),
                                  ]),
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
        ],
      ),
    );
  }

  Widget _field(String label, IconData icon, TextEditingController ctrl, bool obscure, {Widget? suffix}) {
    final context = this.context;
    return CupertinoTextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: label == 'Email' ? TextInputType.emailAddress : TextInputType.text,
      placeholder: label,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Icon(icon, color: CupertinoColors.secondaryLabel.resolveFrom(context), size: 18),
      ),
      suffix: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
      ),
      style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontSize: 15),
    );
  }
}
