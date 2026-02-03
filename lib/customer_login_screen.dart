import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _codeSent = false;

  ConfirmationResult? _confirmationResult;
  String? _verificationId; // For mobile

  Timer? _resendTimer;
  int _resendCooldown = 60;
  bool _canResendCode = false;

  @override
  void initState() {
    super.initState();
    _auth.setSettings(appVerificationDisabledForTesting: false);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _canResendCode = false;
      _resendCooldown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        if (mounted) setState(() => _resendCooldown--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _canResendCode = true);
      }
    });
  }

  Future<void> _sendOtp() async {
    final String phoneNumber = '+52${_phoneController.text.trim()}';
    if (_phoneController.text.trim().length != 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un número de 10 dígitos.')),
      );
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      if (kIsWeb) {
        _confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
        developer.log('Web: ConfirmationResult received.', name: 'CustomerLogin');
        if (mounted) {
          setState(() => _codeSent = true);
          _startResendTimer();
        }
      } else {
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: _handleVerificationCompleted,
          verificationFailed: _handleVerificationFailed,
          codeSent: (String verificationId, int? resendToken) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _codeSent = true;
              });
              _startResendTimer();
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            if (mounted) _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      _handleError(e, 'Error al enviar el código de verificación');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verifyOtp() async {
    final String smsCode = _otpController.text.trim();
    if (smsCode.length != 6) return;

    setState(() => _isVerifyingCode = true);

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        if (_confirmationResult == null) throw ('El resultado de confirmación no está disponible.');
        userCredential = await _confirmationResult!.confirm(smsCode);
      } else {
        if (_verificationId == null) throw ('El ID de verificación no está disponible.');
        final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: smsCode);
        userCredential = await _auth.signInWithCredential(credential);
      }
      
      _resendTimer?.cancel();
      await _checkAndRedirect(userCredential.user);

    } catch (e) {
      _handleError(e, 'El código ingresado es incorrecto o ha expirado.');
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  /// Checks if a customer profile exists and redirects accordingly.
  Future<void> _checkAndRedirect(User? user) async {
    if (!mounted || user == null || user.phoneNumber == null) return;

    // Hybrid search: Check for old and new user structures
    final phoneNumber = user.phoneNumber!;
    final oldUserQuery = await _firestore
        .collection('clientes')
        .where('telefono', isEqualTo: phoneNumber.substring(3))
        .limit(1)
        .get();

    if (oldUserQuery.docs.isNotEmpty) {
      // Found existing user with old structure
      context.go('/customer-profile');
      return;
    }

    final newUserDoc = await _firestore.collection('clientes').doc(phoneNumber).get();
    if (newUserDoc.exists) {
      // Found existing user with new structure
      context.go('/customer-profile');
    } else {
      // No profile found, go to creation screen
      context.go('/create-profile');
    }
  }

  void _handleVerificationCompleted(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      await _checkAndRedirect(userCredential.user);
    } catch(e) {
      _handleError(e, 'Error durante el inicio de sesión automático');
    }
  }

  void _handleVerificationFailed(FirebaseAuthException e) {
    _handleError(e, 'La verificación del número de teléfono falló');
  }

  void _handleError(Object? e, String message) {
    developer.log(message, name: 'CustomerLogin', error: e, level: 1000);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _codeSent ? _buildOtpView(defaultPinTheme) : _buildPhoneView(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Bienvenido a Saturno', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text(
          'Ingresa tu número de teléfono para acceder a tu perfil y ver tus puntos de lealtad.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Número de Teléfono (10 dígitos)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixText: '+52 ',
            prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
          ),
        ),
        const SizedBox(height: 24),
        if (_isSendingCode)
          const CircularProgressIndicator(color: Color(0xFFFFD700))
        else
          ElevatedButton(
            onPressed: _sendOtp,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text('Enviar Código'),
          ),
      ],
    );
  }

  Widget _buildOtpView(PinTheme defaultPinTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Verifica tu Número', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(
          'Ingresa el código de 6 dígitos que enviamos a +52${_phoneController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 40),
        Pinput(
          controller: _otpController,
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              border: Border.all(color: const Color(0xFFFFD70f),), // Corrected color code
            ),
          ),
          onCompleted: (pin) => _verifyOtp(),
        ),
        const SizedBox(height: 30),
        if (_isVerifyingCode)
          const CircularProgressIndicator(color: Color(0xFFFFD700))
        else
          _buildResendCodeWidget(),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            _resendTimer?.cancel();
            setState(() {
              _codeSent = false;
              _otpController.clear();
            });
          },
          child: const Text('¿Número incorrecto? Volver'),
        ),
      ],
    );
  }

  Widget _buildResendCodeWidget() {
    return _canResendCode
        ? TextButton(onPressed: _sendOtp, child: const Text('Reenviar Código'))
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Reenviar código en 0:${_resendCooldown.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
  }
}
