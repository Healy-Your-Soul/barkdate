import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isSignUp = false;
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.barkdate://login-callback',
      );
      
      if (mounted && response == true) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Google: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    
    try {
      print('🔑 Attempting email sign-in with: ${_emailController.text.trim()}');
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      print('✅ Sign-in successful: ${response.user?.email}');
      
      if (mounted && response.user != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AuthException catch (e) {
      print('❌ AuthException: ${e.message}');
      if (mounted) {
        String message = 'Authentication failed';
        switch (e.message) {
          case 'Invalid login credentials':
            message = 'Invalid email or password.';
            break;
          case 'Email not confirmed':
            message = 'Please verify your email address before signing in.';
            break;
          default:
            message = e.message;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      print('❌ General error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    
    try {
      print('🔑 Attempting email registration with: ${_emailController.text.trim()}');
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      print('✅ Registration successful: ${response.user?.email}');
      
      if (mounted) {
        if (response.user != null && response.user!.emailConfirmedAt == null) {
          // Email verification required
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please check your email and verify your account before signing in.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Switch to sign in mode
          setState(() => isSignUp = false);
        } else {
          // User created and verified, redirect to home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } on AuthException catch (e) {
      print('❌ AuthException: ${e.message}');
      if (mounted) {
        String message = 'Registration failed';
        if (e.message.contains('already registered')) {
          message = 'An account already exists with this email address.';
        } else if (e.message.contains('weak password')) {
          message = 'Password is too weak. Please choose a stronger password.';
        } else if (e.message.contains('invalid email')) {
          message = 'Invalid email address.';
        } else {
          message = e.message;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      print('❌ General error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return _buildWideLayout(context, isDark);
            } else {
              return _buildNarrowLayout(context, isDark);
            }
          },
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Left side with branding
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                    ? [
                        DarkModeColors.darkPrimaryContainer,
                        DarkModeColors.darkPrimary.withOpacity(0.1),
                      ]
                    : [
                        LightModeColors.lightPrimaryContainer,
                        LightModeColors.lightPrimary.withOpacity(0.1),
                      ],
              ),
            ),
            child: _buildBrandingSection(context, isDark, isWide: true),
          ),
        ),
        // Right side with auth form
        Expanded(
          flex: 2,
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: _buildAuthForm(context, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom,
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              Flexible(
                flex: 2,
                child: _buildBrandingSection(context, isDark, isWide: false),
              ),
              Flexible(
                flex: 3,
                child: _buildAuthForm(context, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingSection(BuildContext context, bool isDark, {required bool isWide}) {
    return Container(
      padding: EdgeInsets.all(isWide ? 48 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo from SVG
          SizedBox(
            width: isWide ? 160 : 100,
            height: isWide ? 160 : 100,
            child: SvgPicture.asset(
              'assets/images/logo.svg',
              fit: BoxFit.contain,
              placeholderBuilder: (context) {
                // Fallback while loading or if SVG fails
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? DarkModeColors.darkSurface : LightModeColors.lightSurface,
                    borderRadius: BorderRadius.circular(isWide ? 30 : 20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.pets,
                    size: isWide ? 60 : 40,
                    color: const Color(0xFFED924D), // New primary color
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isWide ? 32 : 16),
          
          // Title - using Joti One font for 'Bark'
          Text(
            'Bark',
            style: GoogleFonts.jotiOne(
              fontSize: isWide ? 48 : 36,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFED924D), // New primary color
            ),
          ),
          SizedBox(height: isWide ? 16 : 8),
          
          // Tagline
          Text(
            'Connect. Play. Grow Together.',
            style: GoogleFonts.poppins(
              fontSize: isWide ? FontSizes.titleLarge : FontSizes.bodyLarge,
              fontWeight: FontWeight.w400,
              color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (isWide) ...[
            const SizedBox(height: 32),
            Text(
              'The perfect platform for dog owners to connect, schedule playdates, and build a community of furry friends.',
              style: GoogleFonts.poppins(
                fontSize: FontSizes.bodyLarge,
                fontWeight: FontWeight.w300,
                color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Auth mode toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: () => setState(() => isSignUp = false),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: FontSizes.titleMedium,
                      fontWeight: isSignUp ? FontWeight.normal : FontWeight.bold,
                      color: isSignUp 
                          ? (isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary)
                          : (isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: TextButton(
                  onPressed: () => setState(() => isSignUp = true),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: FontSizes.titleMedium,
                      fontWeight: !isSignUp ? FontWeight.normal : FontWeight.bold,
                      color: !isSignUp 
                          ? (isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary)
                          : (isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Welcome message
          Text(
            isSignUp ? 'Join the Pack!' : 'Welcome Back!',
            style: GoogleFonts.inter(
              fontSize: FontSizes.headlineMedium,
              fontWeight: FontWeight.bold,
              color: isDark ? DarkModeColors.darkOnSurface : LightModeColors.lightOnSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isSignUp 
                ? 'Create your account to start connecting with fellow dog lovers.'
                : 'Sign in to continue your pawsome journey.',
            style: GoogleFonts.inter(
              fontSize: FontSizes.bodyMedium,
              color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Google Sign In Button
          _buildGoogleSignInButton(isDark),
          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or',
                  style: GoogleFonts.inter(
                    fontSize: FontSizes.bodySmall,
                    color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary)),
            ],
          ),
          const SizedBox(height: 24),

          // Email/Password Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(
                      Icons.lock_outlined,
                      color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (isSignUp && value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Field (Sign Up only)
                if (isSignUp) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          // Submit Button
          ElevatedButton(
            onPressed: isLoading ? null : (isSignUp ? _signUpWithEmail : _signInWithEmail),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? DarkModeColors.darkPrimary : LightModeColors.lightPrimary,
              foregroundColor: isDark ? DarkModeColors.darkOnPrimary : LightModeColors.lightOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isSignUp ? 'Create Account' : 'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: FontSizes.labelLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 32),

          // Footer
          Text(
            'By continuing, you agree to our Terms of Service and Privacy Policy.',
            style: GoogleFonts.inter(
              fontSize: FontSizes.bodySmall,
              color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildGoogleSignInButton(bool isDark) {
    return OutlinedButton(
      onPressed: isLoading ? null : _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(
          color: isDark ? DarkModeColors.darkSecondary : LightModeColors.lightSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google Logo placeholder (you can replace with actual Google logo)
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: GoogleFonts.inter(
              fontSize: FontSizes.labelLarge,
              fontWeight: FontWeight.w600,
              color: isDark ? DarkModeColors.darkOnSurface : LightModeColors.lightOnSurface,
            ),
          ),
        ],
      ),
    );
  }
}
