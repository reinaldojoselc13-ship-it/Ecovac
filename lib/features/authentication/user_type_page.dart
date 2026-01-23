import 'package:flutter/material.dart';
import 'login_page.dart';

// Color tokens for easy tuning (tuned to mock)
const _kGradientStart = Color(0xFFEFA6D1); // soft pink
const _kGradientEnd = Color(0xFFB8A9E8); // soft purple
const _kButtonColor = Color(0xFF9FC8C8); // muted teal for pills

// Layout tokens
const _kHeaderHeightFactor = 0.46;
const _kCircleRadius = 56.0;
const _kTitleSize = 36.0;
const _kButtonWidth = 280.0;
const _kButtonHeight = 56.0;
const _kButtonGap = 24.0;

class UserTypePage extends StatelessWidget {
  const UserTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top gradient with diagonal bottom edge
            ClipPath(
              clipper: _DiagonalClipper(),
              child: Container(
                height: size.height * _kHeaderHeightFactor,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kGradientStart, _kGradientEnd],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircleAvatar(
                        radius: _kCircleRadius,
                        backgroundColor: Colors.white,
                        child: Text('ECOVAC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // White curved container to mimic the mock's lower panel
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32),
                child: Column(
                  children: [
                    const Text('Tipo de Usuario', style: TextStyle(fontSize: _kTitleSize, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Text('Log in', style: TextStyle(color: Colors.black, fontSize: 12)),
                    const SizedBox(height: 22),

                    // Veterinario button (fixed width, pill style)
                    SizedBox(
                      width: _kButtonWidth,
                      height: _kButtonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kButtonColor,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shadowColor: Colors.black26,
                        ),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (_) => const LoginPage(initialUserType: 'Veterinario'),
                          ));
                        },
                        child: const Text('Veterinario'),
                      ),
                    ),

                    const SizedBox(height: _kButtonGap),

                    // Administrador button
                    SizedBox(
                      width: _kButtonWidth,
                      height: _kButtonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kButtonColor,
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shadowColor: Colors.black26,
                        ),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (_) => const LoginPage(initialUserType: 'Administrador'),
                          ));
                        },
                        child: const Text('Administrador'),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);
    path.lineTo(size.width * 0.6, size.height - 20);
    path.lineTo(size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
