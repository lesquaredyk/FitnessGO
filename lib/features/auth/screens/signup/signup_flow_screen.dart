import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/storage/api_session_store.dart';
import '../../../../data/local_auth_store.dart';
import '../../../../data/local_calorie_store.dart';
import '../../../../data/local_user_store.dart';
import '../../data/auth_api.dart';
import '../../../../models/signup_data.dart';
import '../../../../screens/dashboard_screen.dart';
import 'steps/account_credentials_step.dart';
import 'steps/activity_level_step.dart';
import 'steps/goal_step.dart';
import 'steps/health_condition_step.dart';
import 'steps/personal_info_step.dart';
import 'steps/profile_photo_step.dart';
import 'steps/signup_result_step.dart';
import 'steps/terms_step.dart';
import '../../../../data/user_session.dart';

class SignupFlowScreen extends StatefulWidget {
  static const routeName = '/signup';

  const SignupFlowScreen({super.key});

  @override
  State<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends State<SignupFlowScreen> {
  final SignupData data = SignupData();

  int currentStep = 0;
  bool isCreatingAccount = false;
  static const totalSteps = 8;

  void nextStep() {
    if (currentStep < totalSteps - 1) {
      setState(() {
        currentStep++;
      });
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  String currentHealthAnswer() {
    return data.hasHealthCondition.trim().isEmpty
        ? 'No'
        : data.hasHealthCondition.trim();
  }

  String primaryHealthCondition() {
    if (currentHealthAnswer() != 'Yes') return 'None';

    if (data.otherHealthCondition.trim().isNotEmpty) {
      return data.otherHealthCondition.trim();
    }

    if (data.healthConditions.isNotEmpty) {
      return data.healthConditions.first.trim();
    }

    return 'None';
  }

  double responseDouble(
    Map<String, dynamic> source,
    List<String> keys,
    double fallback,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  int responseInt(
    Map<String, dynamic> source,
    List<String> keys,
    int fallback,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed.round();
      }
    }
    return fallback;
  }

  String responseString(
    Map<String, dynamic> source,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  Future<String?> showSignupOtpDialog(String email) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignupOtpDialog(
        email: email,
        onResend: () async {
          final result = await AuthApi.requestSignupOtp(
            username: data.username.trim(),
            email: email,
          );

          return result['success'] == true;
        },
      ),
    );
  }

  Future<void> registerAndContinue() async {
    if (isCreatingAccount) return;

    final username = data.username.trim();
    final email = data.email.trim();

    setState(() {
      isCreatingAccount = true;
    });

    try {
      final otpResult = await AuthApi.requestSignupOtp(
        username: username,
        email: email,
      );

      if (!mounted) return;

      setState(() {
        isCreatingAccount = false;
      });

      if (otpResult['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              otpResult['message']?.toString() ??
                  otpResult['detail']?.toString() ??
                  'Failed to send OTP. Please try again.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully. Please check your email.'),
          backgroundColor: Color(0xFF008000),
        ),
      );

      final otp = await showSignupOtpDialog(email);

      if (!mounted) return;

      if (otp == null || otp.trim().isEmpty) {
        return;
      }

      setState(() {
        isCreatingAccount = true;
      });

      final hasCondition = currentHealthAnswer();
      final conditionText = primaryHealthCondition();

      final registerResult = await AuthApi.register(
        username: username,
        email: email,
        password: data.password,
        fullname: data.fullName,
        age: data.age ?? 0,
        gender: data.gender,
        height: data.height ?? 0,
        weight: data.weight ?? 0,
        goal: data.goal,
        activityLevel: data.activityLevel,
        desiredWeight: data.desiredWeight,
        hasHealthConditions: hasCondition,
        whatHealthConditions: hasCondition == 'Yes' ? conditionText : null,
        otp: otp.trim(),
      );

      if (registerResult['success'] != true) {
        if (!mounted) return;

        setState(() {
          isCreatingAccount = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              registerResult['message']?.toString() ??
                  registerResult['detail']?.toString() ??
                  'Signup failed. Please try again.',
            ),
          ),
        );
        return;
      }

      final userId =
          int.tryParse(
            '${registerResult['UserId'] ?? registerResult['userId'] ?? registerResult['user_id'] ?? 0}',
          ) ??
          0;

      if (userId <= 0) {
        if (!mounted) return;

        setState(() {
          isCreatingAccount = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signup failed: User ID was not returned by API.'),
          ),
        );
        return;
      }

      final backendDailyGoal = responseInt(registerResult, [
        'DailyNetGoal',
        'dailyNetGoal',
        'daily_goal',
        'dailyGoal',
      ], data.dailyCalorieGoal);

      final backendBmi = responseDouble(registerResult, [
        'BMI',
        'bmi',
      ], data.bmi);

      final backendBmiStatus = responseString(registerResult, [
        'BMIStatus',
        'bmiStatus',
        'bmi_status',
      ], data.bmiStatus);

      data.userId = userId;
      data.backendDailyCalorieGoal = backendDailyGoal;
      data.backendBmi = backendBmi;
      data.backendBmiStatus = backendBmiStatus;

      await ApiSessionStore.saveUserId(userId);

      await LocalAuthStore.saveSignup(
        fullName: data.fullName,
        email: email,
        password: data.password,
        dailyGoal: backendDailyGoal,
        goal: data.goal,
        desiredWeight: data.desiredWeight ?? 0,
        bmi: backendBmi,
        bmiStatus: backendBmiStatus,
        activityLevel: data.activityLevel,
        healthCondition: conditionText,
        age: data.age ?? 0,
        gender: data.gender,
        height: data.height ?? 0,
        weight: data.weight ?? 0,
      );

      LocalUserStore.setFullName(data.fullName);
      LocalCalorieStore.setDailyGoal(backendDailyGoal);
      LocalCalorieStore.clear();

      if (!mounted) return;

      setState(() {
        isCreatingAccount = false;
        currentStep++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully. You can add a photo next.',
          ),
          backgroundColor: Color(0xFF008000),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isCreatingAccount = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signup failed: $error')));
    }
  }

  void finishSignup() async {
    await UserSession.saveUser(
      name: data.fullName,
      age: data.age ?? 0,
      gender: data.gender,
      weight: data.weight ?? 0,
      height: data.height ?? 0,
      goal: data.goal,
      calorieGoal: data.displayDailyCalorieGoal,
    );

    Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
  }

  Widget buildCurrentStep() {
    return switch (currentStep) {
      0 => TermsStep(
        data: data,
        onAccept: nextStep,
        onDecline: () => Navigator.pop(context),
      ),
      1 => PersonalInfoStep(data: data, onNext: nextStep, onBack: previousStep),
      2 => ActivityLevelStep(
        data: data,
        onNext: nextStep,
        onBack: previousStep,
      ),
      3 => GoalStep(data: data, onNext: nextStep, onBack: previousStep),
      4 => HealthConditionStep(
        data: data,
        onNext: nextStep,
        onBack: previousStep,
      ),
      5 => AccountCredentialsStep(
        data: data,
        onNext: registerAndContinue,
        onBack: previousStep,
      ),
      6 => ProfilePhotoStep(
        userId: data.userId,
        onNext: nextStep,
        onBack: previousStep,
      ),
      _ => SignupResultStep(
        data: data,
        onFinish: finishSignup,
        onBack: previousStep,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(currentStep),
            child: buildCurrentStep(),
          ),
        ),
      ),
    );
  }
}

class _SignupOtpDialog extends StatefulWidget {
  const _SignupOtpDialog({required this.email, required this.onResend});

  final String email;
  final Future<bool> Function() onResend;

  @override
  State<_SignupOtpDialog> createState() => _SignupOtpDialogState();
}

class _SignupOtpDialogState extends State<_SignupOtpDialog> {
  final TextEditingController otpController = TextEditingController();

  Timer? countdownTimer;
  int secondsRemaining = 300;
  bool isResending = false;
  String? errorText;
  String? statusText;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void startCountdown() {
    countdownTimer?.cancel();

    setState(() {
      secondsRemaining = 300;
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          secondsRemaining = 0;
        });
        return;
      }

      setState(() {
        secondsRemaining--;
      });
    });
  }

  String get countdownText {
    final minutes = secondsRemaining ~/ 60;
    final seconds = secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> resendCode() async {
    if (isResending) return;

    setState(() {
      isResending = true;
      errorText = null;
      statusText = null;
    });

    final success = await widget.onResend();

    if (!mounted) return;

    setState(() {
      isResending = false;
      if (success) {
        statusText = 'A new OTP has been sent.';
        errorText = null;
      } else {
        errorText = 'Could not resend OTP. Please try again.';
        statusText = null;
      }
    });

    if (success) {
      startCountdown();
    }
  }

  void verifyOtp() {
    final otp = otpController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        errorText = 'Enter the 6-digit OTP.';
        statusText = null;
      });
      return;
    }

    Navigator.of(context).pop(otp);
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = secondsRemaining <= 0;

    return AlertDialog(
      backgroundColor: const Color(0xFFF7F7F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF008000).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF008000),
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Verify your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'We sent a 6-digit OTP to\n${widget.email}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: Color(0xFF1F1F1F),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                letterSpacing: 8,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w600,
              ),
              errorText: errorText,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF008000),
                  width: 1.8,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.4,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isExpired
                  ? Colors.redAccent.withOpacity(0.10)
                  : const Color(0xFF008000).withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isExpired
                  ? 'OTP expired. Please resend code.'
                  : 'OTP expires in $countdownText',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isExpired ? Colors.redAccent : const Color(0xFF008000),
              ),
            ),
          ),
          if (statusText != null) ...[
            const SizedBox(height: 10),
            Text(
              statusText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF008000),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: isResending ? null : resendCode,
            child: Text(
              isResending ? 'Sending...' : 'Resend code',
              style: const TextStyle(
                color: Color(0xFF008000),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF008000),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: verifyOtp,
          child: const Text(
            'Verify',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
