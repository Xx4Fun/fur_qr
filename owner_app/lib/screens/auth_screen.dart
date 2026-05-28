import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _termsAccepted = false;

  // Colors from the design
  final Color _primaryBlue = const Color(0xFF0047CC); // Exact blue from mockup
  final Color _primaryOrange = const Color(0xFFFF7A1A); // Exact orange from mockup

  Future<void> _submit() async {
    // Validation for register
    if (!_isLogin) {
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must agree to the Terms of Service and Privacy Policy.')),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await SupabaseService.instance.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await SupabaseService.instance.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
          '', // Removed phone from this UI based on mockup
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.instance.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _isLogin ? _primaryBlue : _primaryOrange, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearBindingGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.orange.shade50.withOpacity(0.3),
            ]
          )
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _isLogin ? _primaryBlue : Colors.grey.shade100,
                        child: Icon(
                          Icons.pets, 
                          size: 40, 
                          color: _isLogin ? Colors.white : _primaryBlue
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Header Texts
                      Text(
                        _isLogin ? 'Welcome Back, Fur Parent!' : 'Join the Pack',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isLogin 
                            ? 'Log in to continue your search or help others.' 
                            : 'Create an account to protect your fur babies.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Inputs
                      if (!_isLogin) ...[
                        TextField(
                          controller: _nameController,
                          decoration: _inputDecoration('Full Name', Icons.person_outline),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      TextField(
                        controller: _emailController,
                        decoration: _inputDecoration('Email Address', Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field + Forgot Password Link
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_isLogin)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Forgot Password not implemented yet.')),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: _primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          TextField(
                            controller: _passwordController,
                            decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey.shade500,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            obscureText: _obscurePassword,
                          ),
                        ],
                      ),
                      
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          decoration: _inputDecoration('Confirm Password', Icons.password_outlined),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _termsAccepted,
                                onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: 'Terms of Service\n',
                                      style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w500),
                                    ),
                                    const TextSpan(text: 'and '),
                                    TextSpan(
                                      text: 'Privacy Policy.',
                                      style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 32),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLogin ? _primaryBlue : _primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isLogin ? 'Login to PawTrace' : 'Create Account',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 20),
                                  ],
                                ),
                        ),
                      ),
                      
                      // Social Logins (Only on Login)
                      if (_isLogin) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('or continue with', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _submitGoogle,
                                icon: Image.network('https://developers.google.com/identity/images/g-logo.png', height: 20), // Placeholder
                                label: const Text('Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.apple, color: Colors.black, size: 24),
                                label: const Text('Apple', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 32),
                      
                      // Footer Toggle
                      GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = !_isLogin;
                          if (_isLogin) {
                            _nameController.clear();
                            _confirmPasswordController.clear();
                            _termsAccepted = false;
                          }
                        }),
                        child: RichText(
                          text: TextSpan(
                            text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            children: [
                              TextSpan(
                                text: _isLogin ? 'Sign Up' : 'Log In',
                                style: TextStyle(
                                  color: _primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
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
        ),
      ),
    );
  }
}

// Helper to create the subtle gradient background
class LinearBindingGradient extends LinearGradient {
  const LinearBindingGradient({required super.colors, super.begin, super.end});
}