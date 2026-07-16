import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../apis/apis.dart';
import '../helper/my_dialog.dart';
import '../helper/weather_service.dart';
import '../model/message.dart';

class ChatController extends GetxController {
  final textC = TextEditingController();
  final scrollC = ScrollController();

  final list = <Message>[
    Message(msg: 'Hello, How can I help you?', msgType: MessageType.bot)
  ].obs;

  Future<void> askQuestion() async {
    if (textC.text.trim().isEmpty) {
      MyDialog.info('Ask Something!');
      return;
    }

    final question = textC.text;
    list.add(Message(msg: question, msgType: MessageType.user));
    textC.text = '';

    if (APIs.isImageRequest(question)) {
      await _askImage(question);
      return;
    }

    if (APIs.isVideoRequest(question)) {
      await _askVideo(question);
      return;
    }

    final weatherIntent = await APIs.classifyWeatherIntent(question);
    if (weatherIntent.isWeather) {
      await _askWeather(weatherIntent.city);
      return;
    }

    final classified = await APIs.classifyTranslationIntent(question);
    if (classified.isTranslation) {
      await _askTranslation(classified.text, classified.targetLanguage);
      return;
    }

    await _askText(question);
  }

  Future<void> _askWeather(String city) async {
    list.add(Message(msg: '', msgType: MessageType.bot));
    _scrollDown();

    if (city.trim().isEmpty) {
      list.removeLast();
      list.add(Message(
        msg: 'De qual cidade você quer saber o clima? 🌍',
        msgType: MessageType.bot,
      ));
      _scrollDown();
      return;
    }

    try {
      final weather = await WeatherService.fetchWeather(city);
      final res = await APIs.getWeatherAnswer(weather);
      list.removeLast();
      list.add(Message(
        msg: res.text,
        msgType: MessageType.bot,
        aiProvider: res.provider,
      ));
    } on WeatherException catch (e) {
      list.removeLast();
      list.add(Message(
        msg: _weatherErrorMessage(e),
        msgType: MessageType.bot,
      ));
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção ao buscar o clima: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  String _weatherErrorMessage(WeatherException e) {
    switch (e.type) {
      case WeatherErrorType.missingKey:
        return 'A busca de clima ainda não está configurada (falta a chave da OpenWeatherMap).';
      case WeatherErrorType.cityNotFound:
        return 'Não encontrei essa cidade. Pode conferir o nome e tentar de novo?';
      case WeatherErrorType.invalidKey:
        return 'A chave da OpenWeatherMap parece inválida ou ainda não ativada.';
      case WeatherErrorType.rateLimited:
        return 'Muitas consultas de clima em pouco tempo. Tenta de novo daqui a pouco?';
      case WeatherErrorType.network:
        return 'Não consegui me conectar para buscar o clima agora. Confere sua internet?';
      case WeatherErrorType.timeout:
        return 'A busca do clima demorou demais e foi cancelada. Tenta de novo?';
      case WeatherErrorType.unknown:
        return 'Não consegui buscar o clima agora: ${e.message}';
    }
  }

  Future<void> _askTranslation(String text, String targetLanguage) async {
    list.add(Message(msg: '', msgType: MessageType.bot));
    _scrollDown();

    try {
      final translated = await APIs.translate(
        text: text,
        targetLanguageNameOrCode: targetLanguage,
      );
      list.removeLast();
      list.add(Message(
        msg: translated,
        msgType: MessageType.bot,
        aiProvider: 'Tradutor',
      ));
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção ao traduzir: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  Future<void> _askText(String question) async {
    list.add(Message(msg: '', msgType: MessageType.bot));
    _scrollDown();

    try {
      final res = await APIs.getAnswer(question);
      list.removeLast();
      list.add(Message(
        msg: res.text.isEmpty ? 'Resposta vazia — provider: ${res.provider}' : res.text,
        msgType: MessageType.bot,
        aiProvider: res.provider,
      ));
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção no controller: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  Future<void> _askVideo(String question) async {
    // Mensagem vazia sem texto marca o estado "gerando vídeo" para o
    // MessageCard mostrar o anel pulsando em vez do texto/typewriter.
    list.add(Message(msg: '', msgType: MessageType.bot, videoUrl: ''));
    _scrollDown();

    try {
      final res = await APIs.generateVideo(question);
      list.removeLast();
      if (res.success) {
        list.add(Message(
          msg: '',
          msgType: MessageType.bot,
          videoUrl: res.videoUrl,
          aiProvider: 'Magic Hour',
        ));
      } else {
        list.add(Message(
          msg: res.error ?? 'Não foi possível gerar o vídeo.',
          msgType: MessageType.bot,
        ));
      }
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção ao gerar vídeo: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  Future<void> _askImage(String question) async {
    // Mensagem vazia com imageBase64 = '' marca o estado "gerando imagem"
    // para o MessageCard mostrar o anel pulsando.
    list.add(Message(msg: '', msgType: MessageType.bot, imageBase64: ''));
    _scrollDown();

    try {
      final result = await APIs.generateImage(question);
      list.removeLast();
      if (result.isNotEmpty && !result.startsWith('❌')) {
        list.add(Message(
          msg: '',
          msgType: MessageType.bot,
          imageBase64: result,
          aiProvider: 'Cloudflare',
        ));
      } else {
        list.add(Message(
          msg: result.isNotEmpty ? result : 'Não foi possível gerar a imagem.',
          msgType: MessageType.bot,
        ));
      }
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção ao gerar imagem: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  void _scrollDown() {
    scrollC.animateTo(scrollC.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500), curve: Curves.ease);
  }
}
