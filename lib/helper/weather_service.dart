// lib/helper/weather_service.dart
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'global.dart';

/// Tipos de erro que o WeatherService pode lançar, para que quem
/// consome o serviço (ex: apis.dart) possa decidir a mensagem certa
/// para o usuário sem precisar fazer parsing de string.
enum WeatherErrorType {
  missingKey,
  cityNotFound,
  invalidKey,
  rateLimited,
  network,
  timeout,
  unknown,
}

class WeatherException implements Exception {
  final WeatherErrorType type;
  final String message;
  WeatherException(this.type, this.message);

  @override
  String toString() => message;
}

/// Dado meteorológico já processado (sem o "ruído" do JSON bruto da API).
class WeatherResult {
  final String city;
  final String country;
  final double tempC;
  final double feelsLikeC;
  final String description;
  final int humidity;
  final double windSpeedMs;

  WeatherResult({
    required this.city,
    required this.country,
    required this.tempC,
    required this.feelsLikeC,
    required this.description,
    required this.humidity,
    required this.windSpeedMs,
  });

  factory WeatherResult.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>? ?? {};
    final weatherList = json['weather'] as List?;
    final weather = (weatherList != null && weatherList.isNotEmpty)
        ? weatherList[0] as Map<String, dynamic>
        : <String, dynamic>{};
    final wind = json['wind'] as Map<String, dynamic>? ?? {};

    return WeatherResult(
      city: json['name']?.toString() ?? '',
      country: json['sys']?['country']?.toString() ?? '',
      tempC: (main['temp'] as num?)?.toDouble() ?? 0,
      feelsLikeC: (main['feels_like'] as num?)?.toDouble() ?? 0,
      description: weather['description']?.toString() ?? '',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeedMs: (wind['speed'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Versão enxuta em português, pronta para ser injetada no prompt
  /// de uma IA que vai só "traduzir" isso para uma resposta amigável.
  Map<String, dynamic> toPromptJson() => {
        'cidade': city,
        'pais': country,
        'temperatura_celsius': tempC,
        'sensacao_termica_celsius': feelsLikeC,
        'condicao': description,
        'umidade_percentual': humidity,
        'vento_metros_por_segundo': windSpeedMs,
      };
}

class WeatherService {
  static const Duration _timeout = Duration(seconds: 8);
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  /// Busca o clima atual de [city]. Lança [WeatherException] em qualquer
  /// cenário de falha (chave ausente/inválida, cidade não encontrada,
  /// limite de requisições, rede/timeout, resposta inesperada).
  static Future<WeatherResult> fetchWeather(String city) async {
    if (openWeatherKey.isEmpty) {
      throw WeatherException(
        WeatherErrorType.missingKey,
        'OpenWeatherMap: chave não configurada (openWeatherKey em lib/helper/global.dart).',
      );
    }

    final cityTrimmed = city.trim();
    if (cityTrimmed.isEmpty) {
      throw WeatherException(
        WeatherErrorType.cityNotFound,
        'Nenhuma cidade foi informada para a consulta de clima.',
      );
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': cityTrimmed,
      'appid': openWeatherKey,
      'units': 'metric', // Celsius direto, sem conversão manual.
      'lang': 'pt_br', // descrição ("céu limpo", "chuva leve"...) já em pt-BR.
    });

    http.Response res;
    try {
      res = await http.get(uri).timeout(_timeout);
    } on Exception catch (e) {
      final isTimeout = e.toString().toLowerCase().contains('timeout');
      log('WeatherService: erro de rede - $e');
      throw WeatherException(
        isTimeout ? WeatherErrorType.timeout : WeatherErrorType.network,
        isTimeout
            ? 'A consulta de clima demorou demais e foi cancelada.'
            : 'Não foi possível conectar à OpenWeatherMap: $e',
      );
    }

    switch (res.statusCode) {
      case 200:
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          return WeatherResult.fromJson(data);
        } catch (e) {
          throw WeatherException(
            WeatherErrorType.unknown,
            'Erro ao processar a resposta da OpenWeatherMap: $e',
          );
        }
      case 404:
        throw WeatherException(
          WeatherErrorType.cityNotFound,
          'Cidade "$cityTrimmed" não encontrada.',
        );
      case 401:
        throw WeatherException(
          WeatherErrorType.invalidKey,
          'Chave da OpenWeatherMap inválida, expirada ou ainda não ativada.',
        );
      case 429:
        throw WeatherException(
          WeatherErrorType.rateLimited,
          'Limite de requisições da OpenWeatherMap atingido. Tente novamente em instantes.',
        );
      default:
        final body = utf8.decode(res.bodyBytes);
        throw WeatherException(
          WeatherErrorType.unknown,
          'OpenWeatherMap (${res.statusCode}): $body',
        );
    }
  }
}
