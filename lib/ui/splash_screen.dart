import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
final Widget nextScreen;

const SplashScreen({
super.key,
required this.nextScreen,
});

@override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
with TickerProviderStateMixin {
late AnimationController _logoController;
late AnimationController _paperController;
late AnimationController _scanController;
late AnimationController _exitController;

late Animation<double> _logoScale;
late Animation<double> _logoOpacity;
late Animation<double> _paperAnimation;
late Animation<double> _scanAnimation;
late Animation<double> _exitOpacity;
late Animation<double> _exitScale;

Timer? _timer;

@override
void initState() {
super.initState();

// ------------------------------------------------------------
// LOGO ANIMATION
// ------------------------------------------------------------

_logoController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 1000),
);

_logoScale = CurvedAnimation(
parent: _logoController,
curve: Curves.easeOutBack,
);

_logoOpacity = CurvedAnimation(
parent: _logoController,
curve: Curves.easeOut,
);

// ------------------------------------------------------------
// PAPER ANIMATION
// ------------------------------------------------------------

_paperController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 1400),
);

_paperAnimation = CurvedAnimation(
parent: _paperController,
curve: Curves.easeOutCubic,
);

// ------------------------------------------------------------
// SCANNER ANIMATION
// ------------------------------------------------------------

_scanController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 1700),
)..repeat(reverse: true);

_scanAnimation = CurvedAnimation(
parent: _scanController,
curve: Curves.easeInOut,
);

// ------------------------------------------------------------
// EXIT ANIMATION
// ------------------------------------------------------------

_exitController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 450),
);

_exitOpacity = Tween<double>(
begin: 1,
end: 0,
).animate(
CurvedAnimation(
parent: _exitController,
curve: Curves.easeIn,
),
);

_exitScale = Tween<double>(
begin: 1,
end: 1.04,
).animate(
CurvedAnimation(
parent: _exitController,
curve: Curves.easeIn,
),
);

// Start animations.
_logoController.forward();

Future.delayed(const Duration(milliseconds: 250), () {
if (mounted) {
_paperController.forward();
}
});

// Move to next screen after splash.
_timer = Timer(
const Duration(milliseconds: 3000),
_finishSplash,
);
}

Future<void> _finishSplash() async {
if (!mounted) return;

await _exitController.forward();

if (!mounted) return;

Navigator.of(context).pushReplacement(
PageRouteBuilder(
pageBuilder: (_, __, ___) => widget.nextScreen,
transitionDuration: const Duration(milliseconds: 450),
reverseTransitionDuration: const Duration(milliseconds: 300),
transitionsBuilder: (_, animation, __, child) {
return FadeTransition(
opacity: animation,
child: child,
);
},
),
);
}

@override
void dispose() {
_timer?.cancel();

_logoController.dispose();
_paperController.dispose();
_scanController.dispose();
_exitController.dispose();

super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFF0B0F0D),
body: AnimatedBuilder(
animation: Listenable.merge([
_logoController,
_paperController,
_scanController,
_exitController,
]),
builder: (context, child) {
return Opacity(
opacity: _exitOpacity.value,
child: Transform.scale(
scale: _exitScale.value,
child: child,
),
);
},
child: Stack(
children: [
// Background.
const Positioned.fill(
child: _Background(),
),

// Main content.
Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
// ------------------------------------------------
// LOGO
// ------------------------------------------------

FadeTransition(
opacity: _logoOpacity,
child: ScaleTransition(
scale: _logoScale,
child: const _ParchiLogo(),
),
),

const SizedBox(height: 32),

// ------------------------------------------------
// PAPER / RECEIPT
// ------------------------------------------------

ClipRect(
child: SizedBox(
width: 230,
height: 100,
child: Transform.translate(
offset: Offset(
0,
90 * (1 - _paperAnimation.value),
),
child: Opacity(
opacity: _paperAnimation.value,
child: const _ReceiptPreview(),
),
),
),
),

const SizedBox(height: 38),

// ------------------------------------------------
// STATUS
// ------------------------------------------------

FadeTransition(
opacity: _logoOpacity,
child: const _StatusText(),
),
],
),
),

// ----------------------------------------------------
// BOTTOM VERSION
// ----------------------------------------------------

Positioned(
left: 0,
right: 0,
bottom: 28,
child: FadeTransition(
opacity: _logoOpacity,
child: const Text(
'PARCHI  •  SMART PRINTING',
textAlign: TextAlign.center,
style: TextStyle(
color: Color(0xFF68716B),
fontSize: 10,
fontWeight: FontWeight.w600,
letterSpacing: 2.2,
),
),
),
),
],
),
),
);
}
}

// ============================================================================
// BACKGROUND
// ============================================================================

class _Background extends StatelessWidget {
const _Background();

@override
Widget build(BuildContext context) {
return Stack(
children: [
Container(
decoration: const BoxDecoration(
gradient: RadialGradient(
center: Alignment(0, -0.2),
radius: 1.2,
colors: [
Color(0xFF17231C),
Color(0xFF0B0F0D),
],
),
),
),

// Decorative circles.
Positioned(
top: -150,
right: -130,
child: Container(
width: 330,
height: 330,
decoration: BoxDecoration(
shape: BoxShape.circle,
border: Border.all(
color: Color(0x142D9158),
width: 1,
),
),
),
),

Positioned(
bottom: -180,
left: -150,
child: Container(
width: 360,
height: 360,
decoration: BoxDecoration(
shape: BoxShape.circle,
border: Border.all(
color: Color(0x102D9158),
width: 1,
),
),
),
),
],
);
}
}

// ============================================================================
// PARCHI LOGO
// ============================================================================

class _ParchiLogo extends StatelessWidget {
const _ParchiLogo();

@override
Widget build(BuildContext context) {
return Column(
children: [
// Printer icon.
Container(
width: 88,
height: 88,
decoration: BoxDecoration(
color: const Color(0xFF16241B),
borderRadius: BorderRadius.circular(26),
border: Border.all(
color: const Color(0xFF2D9158).withOpacity(.35),
width: 1,
),
boxShadow: [
BoxShadow(
color: const Color(0xFF2D9158).withOpacity(.14),
blurRadius: 35,
spreadRadius: 3,
),
],
),
child: Stack(
alignment: Alignment.center,
children: [
// Printer body.
Container(
width: 49,
height: 32,
decoration: BoxDecoration(
color: const Color(0xFFE9EEE9),
borderRadius: BorderRadius.circular(7),
),
),

// Paper.
Positioned(
top: 15,
child: Container(
width: 32,
height: 28,
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(2),
),
child: Column(
children: [
const SizedBox(height: 7),
Container(
width: 20,
height: 2,
color: const Color(0xFFB9C0BB),
),
const SizedBox(height: 4),
Container(
width: 15,
height: 2,
color: const Color(0xFFB9C0BB),
),
],
),
),
),

// Green indicator.
Positioned(
right: 22,
bottom: 19,
child: Container(
width: 5,
height: 5,
decoration: const BoxDecoration(
shape: BoxShape.circle,
color: Color(0xFF45C879),
),
),
),
],
),
),

const SizedBox(height: 18),

const Text(
'PARCHI',
style: TextStyle(
color: Colors.white,
fontSize: 30,
fontWeight: FontWeight.w800,
letterSpacing: 4,
),
),

const SizedBox(height: 4),

const Text(
'PRINT WITHOUT LIMITS',
style: TextStyle(
color: Color(0xFF7B857E),
fontSize: 9,
fontWeight: FontWeight.w600,
letterSpacing: 2.4,
),
),
],
);
}
}

// ============================================================================
// RECEIPT PREVIEW
// ============================================================================

class _ReceiptPreview extends StatefulWidget {
const _ReceiptPreview();

@override
State<_ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<_ReceiptPreview>
with SingleTickerProviderStateMixin {
late AnimationController _controller;

@override
void initState() {
super.initState();

_controller = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 1700),
)..repeat(reverse: true);
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return AnimatedBuilder(
animation: _controller,
builder: (context, child) {
return Stack(
children: [
// Receipt.
Positioned(
left: 25,
right: 25,
top: 8,
bottom: 5,
child: Container(
decoration: BoxDecoration(
color: const Color(0xFFF4F5F3),
borderRadius: BorderRadius.circular(4),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.25),
blurRadius: 20,
offset: const Offset(0, 10),
),
],
),
child: Padding(
padding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 12,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 45,
height: 5,
decoration: BoxDecoration(
color: const Color(0xFF1D241F),
borderRadius: BorderRadius.circular(3),
),
),
const Spacer(),
Container(
width: 20,
height: 5,
color: const Color(0xFFB5BBB7),
),
],
),

const SizedBox(height: 9),

_line(100),
_line(72),
_line(88),

const Spacer(),

Row(
children: [
_lineSmall(35),
const Spacer(),
_lineSmall(35),
],
),
],
),
),
),
),

// Scanner light.
Positioned(
left: 28,
right: 28,
top: 12 + (65 * _controller.value),
child: Container(
height: 2,
decoration: BoxDecoration(
color: const Color(0xFF45C879),
boxShadow: [
BoxShadow(
color: const Color(0xFF45C879).withOpacity(.8),
blurRadius: 8,
spreadRadius: 2,
),
],
),
),
),
],
);
},
);
}

Widget _line(double width) {
return Container(
margin: const EdgeInsets.only(bottom: 5),
width: width,
height: 3,
decoration: BoxDecoration(
color: const Color(0xFFC2C7C3),
borderRadius: BorderRadius.circular(2),
),
);
}

Widget _lineSmall(double width) {
return Container(
width: width,
height: 4,
decoration: BoxDecoration(
color: const Color(0xFF737A75),
borderRadius: BorderRadius.circular(2),
),
);
}
}

// ============================================================================
// STATUS TEXT
// ============================================================================

class _StatusText extends StatefulWidget {
const _StatusText();

@override
State<_StatusText> createState() => _StatusTextState();
}

class _StatusTextState extends State<_StatusText>
with SingleTickerProviderStateMixin {
late AnimationController _controller;

@override
void initState() {
super.initState();

_controller = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 1200),
)..repeat();
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return AnimatedBuilder(
animation: _controller,
builder: (context, child) {
final value = (_controller.value * 3).floor();

return Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Text(
'Preparing printer',
style: TextStyle(
color: Color(0xFF9AA39D),
fontSize: 12,
fontWeight: FontWeight.w500,
),
),
SizedBox(
width: 18,
child: Text(
'.' * value,
style: const TextStyle(
color: Color(0xFF45C879),
fontSize: 13,
fontWeight: FontWeight.bold,
),
),
),
],
);
},
);
}
}
