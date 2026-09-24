import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart' as ap;
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  
  bool _isRegister = false;
  bool _loading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    final auth = context.read<ap.AuthProvider>();
    
    try {
      if (_isRegister) {
        await auth.registerWithEmail(
          _emailCtrl.text.trim(),
          _passCtrl.text,
          _nameCtrl.text.trim(),
        );
      } else {
        await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      }
      if (mounted) {
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await context.read<ap.AuthProvider>().signInWithGoogle();
      if (mounted) {
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
       if (mounted) {
        // আসল এরর মেসেজ দেখানোর জন্য e.toString() ব্যবহার করছি
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _loading = true);
    try {
      await context.read<ap.AuthProvider>().signInWithApple();
      if (mounted) {
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.themeTextDark),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isRegister ? 'Create Account' : 'Welcome Back',
                    style: GoogleFonts.outfit(
                        fontSize: 32, fontWeight: FontWeight.w900, color: context.themeTextDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister 
                      ? 'Sign up to start ordering our services'
                      : 'Sign in to manage your orders and profile',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 15),
                  ),
                  const SizedBox(height: 40),
                  
                  if (_isRegister) ...[
                    _buildField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildField(
                    controller: _passCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureText,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: context.themeTextLight, size: 20),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    ),
                    validator: (v) => v!.length < 6 ? 'Password must be 6+ chars' : null,
                  ),
                  
                  if (!_isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          if (_emailCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter email to reset password'))
                            );
                            return;
                          }
                          context.read<ap.AuthProvider>().resetPassword(_emailCtrl.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reset link sent to your email'))
                          );
                        },
                        child: Text('Forgot Password?', 
                          style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _loading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isRegister ? 'Sign Up' : 'Sign In', 
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.themeBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: GoogleFonts.inter(color: context.themeTextLight, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: context.themeBorder)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _googleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.themeBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 20), // Replace with Google icon if available
                          const SizedBox(width: 12),
                          Text('Continue with Google', 
                            style: GoogleFonts.inter(color: context.themeTextDark, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  if (!kIsWeb && Platform.isIOS) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _appleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, size: 24),
                            const SizedBox(width: 12),
                            Text('Continue with Apple', 
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  TextButton(
                    onPressed: () => setState(() {
                      _isRegister = !_isRegister;
                      _formKey.currentState?.reset();
                    }),
                    child: RichText(
                      text: TextSpan(
                        text: _isRegister ? 'Already have an account? ' : 'New here? ',
                        style: GoogleFonts.inter(color: context.themeTextLight),
                        children: [
                          TextSpan(
                            text: _isRegister ? 'Sign In' : 'Create Account',
                            style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 15, color: context.themeTextDark),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: context.themeTextLight),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.themeBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        filled: true,
        fillColor: context.themeSurface,
      ),
    );
  }
}
