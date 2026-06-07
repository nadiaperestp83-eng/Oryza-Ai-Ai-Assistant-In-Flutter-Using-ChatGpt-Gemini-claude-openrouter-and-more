import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';

class AIResponse {
  final String text;
  final String provider;
  AIResponse({required this.text, required this.provider});
}

class APIs {

  // ── OPENROUTER (acesso a 400+ modelos) ───────────
  static Future<String> getAnswerOpenRouter(String question, String model) async {
    try {
      final res = await post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openrouterKey',
          'HTTP-Referer': 'https://github.com/nadiaperesoficial-hash',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final data = jsonDecode(res.body);
      if (data['choices'] == null) return '';
      final text = data['choices'][0]['message']['content'] ?? '';
      return text;
    } catch (e) {
      log('getAnswerOpenRouterE: $e');
      return '';
    }
  }

  // ── GEMINI ──────────────────────────────────────
  static Future<String> getAnswerGemini(String question) async {
    try {
      final res = await post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': question}
              ]
            }
          ]
        }),
      );
      final data = jsonDecode(res.body);
      if (data['candidates'] == null) return '';
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } catch (e) {
      log('getAnswerGeminiE: $e');
      return '';
    }
  }

  // ── GROQ ─────────────────────────────────────────
  static Future<String> getAnswerGroq(String question, String model) async {
    try {
      final res = await post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqKey',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final data = jsonDecode(res.body);
      if (data['choices'] == null) return '';
      return data['choices'][0]['message']['content'] ?? '';
    } catch (e) {
      log('getAnswerGroqE: $e');
      return '';
    }
  }

  // ── CLAUDE via OpenRouter ────────────────────────
  static Future<String> getAnswerClaude(String question) async {
    return getAnswerOpenRouter(question, 'anthropic/claude-sonnet-4-5');
  }

  // ── DEEPSEEK via OpenRouter ──────────────────────
  static Future<String> getAnswerDeepSeek(String question) async {
    return getAnswerOpenRouter(question, 'deepseek/deepseek-chat');
  }

  // ── ROTEADOR COM FALLBACK ────────────────────────
  static Future<AIResponse> getAnswer(String question) async {
    final q = question.toLowerCase();
    final prompt = 'Responda sempre em português brasileiro. $question';

    // Define ordem de tentativas por tipo de pergunta
    List<Future<String> Function()> attempts;

    if (q.contains('código') || q.contains('code') ||
        q.contains('dart') || q.contains('python') ||
        q.contains('flutter') || q.contains('função') ||
        q.contains('erro') || q.contains('bug')) {
      attempts = [
        () => getAnswerGroq(prompt, 'llama-3.3-70b-versatile'),
        () => getAnswerDeepSeek(prompt),
        () => getAnswerOpenRouter(prompt, 'meta-llama/llama-3.3-70b-instruct:free'),
        () => getAnswerGemini(prompt),
      ];
    } else if (q.contains('explica') || q.contains('redija') ||
        q.contains('resumo') || q.contains('analise') ||
        q.contains('escreva') || q.contains('texto') ||
        q.length > 300) {
      attempts = [
        () => getAnswerClaude(prompt),
        () => getAnswerGroq(prompt, 'mixtral-8x7b-32768'),
        () => getAnswerOpenRouter(prompt, 'google/gemma-3-27b-it:free'),
        () => getAnswerGemini(prompt),
      ];
    } else {
      attempts = [
        () => getAnswerGemini(prompt),
        () => getAnswerGroq(prompt, 'gemma2-9b-it'),
        () => getAnswerOpenRouter(prompt, 'google/gemma-3-12b-it:free'),
        () => getAnswerClaude(prompt),
      ];
    }

    // Tenta cada provider na ordem
    final providerNames = {
      0: q.contains('código') || q.contains('code') || q.contains('dart') ? 'Llama' : q.length > 100 ? 'Claude' : 'Gemini',
    };

    for (int i = 0; i < attempts.length; i++) {
      try {
        final result = await attempts[i]();
        if (result.isNotEmpty && !result.startsWith('Erro')) {
          String name = '';
          if (i == 0) {
            if (q.contains('código') || q.contains('dart') || q.contains('flutter')) name = 'Llama';
            else if (q.contains('escreva') || q.contains('texto')) name = 'Claude';
            else name = 'Gemini';
          } else if (i == 1) {
            if (q.contains('código')) name = 'DeepSeek';
            else name = 'Mixtral';
          } else {
            name = 'Gemma';
          }
          return AIResponse(text: result, provider: name);
        }
      } catch (e) {
        log('Tentativa $i falhou: $e');
      }
    }

    return AIResponse(
        text: 'Nenhuma IA disponível no momento. Tente novamente.',
        provider: 'Erro');
  }

  // ── IMAGENS ──────────────────────────────────────
  static Future<List<String>> searchAiImages(String prompt) async {
    try {
      final res =
          await get(Uri.parse('https://lexica.art/api/v1/search?q=$prompt'));
      final data = jsonDecode(res.body);
      return List.from(data['images']).map((e) => e['src'].toString()).toList();
    } catch (e) {
      log('searchAiImagesE: $e');
      return [];
    }
  }

  // ── TRADUÇÃO ─────────────────────────────────────
  static Future<String> googleTranslate({
    required String from,
    required String to,
    required String text,
  }) async {
    try {
      final res = await GoogleTranslator().translate(text, from: from, to: to);
      return res.text;
    } catch (e) {
      log('googleTranslateE: $e');
      return 'Algo deu errado!';
    }
  }
}
