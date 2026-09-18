import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    final auth = Supabase.instance.client.auth;
    try {
      if (_registering) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (response.session == null && mounted) {
          setState(() {
            _notice = '注册成功。若项目开启了邮箱确认，请先到邮箱点确认链接再登录。';
          });
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyMessage(error.message));
    } catch (error) {
      if (mounted) setState(() => _error = '连接失败，检查一下网络：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    _registering ? '创建账号' : '备忘录',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '手机和电脑用同一个账号登录，笔记自动保持一致',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '请输入邮箱';
                      if (!text.contains('@')) return '邮箱格式看起来不对';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) {
                      if (!_busy) unawaited(_submit());
                    },
                    validator: (value) {
                      if ((value ?? '').length < 6) return '密码至少 6 位';
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _Banner(text: _error!, tone: _Tone.error),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    _Banner(text: _notice!, tone: _Tone.info),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_registering ? '注册' : '登录'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _registering = !_registering;
                            _error = null;
                            _notice = null;
                          }),
                    child: Text(_registering ? '已有账号，去登录' : '第一次用？创建账号'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Tone { error, info }

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone});

  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = tone == _Tone.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? scheme.errorContainer
            : scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: isError ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Supabase 的报错是英文的，挑几条常见的翻译一下。
String _friendlyMessage(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('invalid login credentials')) return '邮箱或密码不对';
  if (lower.contains('email not confirmed')) return '邮箱还没确认，去邮箱点一下确认链接';
  if (lower.contains('user already registered')) return '这个邮箱已经注册过了，直接登录';
  if (lower.contains('password should be at least')) return '密码太短了';
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return '操作太频繁，等一会儿再试';
  }
  return raw;
}
