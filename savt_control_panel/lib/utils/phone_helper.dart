// lib/utils/phone_helper.dart
import 'package:flutter/services.dart';

class PhoneCountry {
  final String code;
  final String name;
  final String flag;
  final int nationalLength;
  final String hint;

  const PhoneCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.nationalLength,
    required this.hint,
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'flag': flag,
        'length': nationalLength,
        'hint': hint,
      };
}

class PhoneHelper {
  static const List<PhoneCountry> countries = [
    PhoneCountry(
      code: '+375',
      name: '🇧🇾 Беларусь',
      flag: '🇧🇾',
      nationalLength: 9,
      hint: '(XX) XXX-XX-XX',
    ),
    PhoneCountry(
      code: '+7',
      name: '🇷🇺 Россия',
      flag: '🇷🇺',
      nationalLength: 10,
      hint: '(9XX) XXX-XX-XX',
    ),
  ];

  static const String defaultCountryCode = '+375';

  static PhoneCountry getCountry(String? code) {
    return countries.firstWhere(
      (c) => c.code == code,
      orElse: () => countries.first,
    );
  }

  /// Извлекает чистые цифры абонентского номера для указанной страны
  /// с умным удалением ведущих 8, 7 (для РФ) и 375, 80 (для РБ).
  static String extractNationalDigits(String rawInput, String countryCode) {
    var digits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');

    if (countryCode == '+7') {
      // Россия: абонентский номер строго 10 цифр.
      // Если вводят 11 цифр, начинающихся с 8 или 7 (8916..., 7916...) — убираем первую цифру:
      if (digits.length == 11 &&
          (digits.startsWith('8') || digits.startsWith('7'))) {
        digits = digits.substring(1);
      } else if (digits.length > 1 &&
          (digits.startsWith('8') || digits.startsWith('7'))) {
        // Если пользователь начал вводить с 8 или 7 (например 89...), отсекаем префикс
        digits = digits.substring(1);
      } else if (digits == '8' || digits == '7') {
        // Одиночная 8 или 7 при префиксе +7 избыточна
        digits = '';
      }
      if (digits.length > 10) {
        digits = digits.substring(0, 10);
      }
    } else if (countryCode == '+375') {
      // Беларусь: абонентский номер 9 цифр.
      if (digits.startsWith('375') && digits.length >= 10) {
        digits = digits.substring(3);
      } else if (digits.startsWith('80') && digits.length >= 10) {
        digits = digits.substring(2);
      } else if (digits == '8' || digits == '80') {
        digits = '';
      }
      if (digits.length > 9) {
        digits = digits.substring(0, 9);
      }
    }

    return digits;
  }

  /// Форматирует номер в маску
  static String format(String rawInput, String countryCode) {
    final digits = extractNationalDigits(rawInput, countryCode);

    if (countryCode == '+375') {
      // Беларусь: (XX) XXX-XX-XX
      final buffer = StringBuffer();
      if (digits.isNotEmpty) buffer.write('(');
      for (int i = 0; i < digits.length; i++) {
        if (i == 2) buffer.write(') ');
        if (i == 5) buffer.write('-');
        if (i == 7) buffer.write('-');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    } else {
      // Россия: (XXX) XXX-XX-XX
      final buffer = StringBuffer();
      if (digits.isNotEmpty) buffer.write('(');
      for (int i = 0; i < digits.length; i++) {
        if (i == 3) buffer.write(') ');
        if (i == 6) buffer.write('-');
        if (i == 8) buffer.write('-');
        buffer.write(digits[i]);
      }
      return buffer.toString();
    }
  }

  /// Нормализует номер в международный формат E.164 (+79161234567 или +375291234567)
  static String normalizeToE164(String rawInput, String countryCode) {
    final digits = extractNationalDigits(rawInput, countryCode);
    return '$countryCode$digits';
  }

  /// Проверяет корректность введённого номера
  static String? validate(String? value, String countryCode) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    final digits = extractNationalDigits(value, countryCode);
    final country = getCountry(countryCode);
    if (digits.length != country.nationalLength) {
      return 'Номер телефона должен содержать ${country.nationalLength} цифр';
    }
    return null;
  }
}

/// Умный форматтер для текстовых полей ввода телефона
class PhoneInputFormatter extends TextInputFormatter {
  final String countryCode;
  final ValueChanged<String>? onCountryDetected;

  PhoneInputFormatter(this.countryCode, {this.onCountryDetected});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    if (text.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Автоопределение страны при вставке полного номера
    if (onCountryDetected != null) {
      final cleanDigits = text.replaceAll(RegExp(r'[^0-9]'), '');
      if ((cleanDigits.startsWith('375') && cleanDigits.length >= 11 ||
              cleanDigits.startsWith('80') && cleanDigits.length == 11) &&
          countryCode != '+375') {
        onCountryDetected!('+375');
      } else if ((cleanDigits.startsWith('7') ||
              (cleanDigits.startsWith('8') &&
                  !cleanDigits.startsWith('80'))) &&
          cleanDigits.length == 11 &&
          countryCode != '+7') {
        onCountryDetected!('+7');
      }
    }

    // Если происходит удаление символа
    if (oldValue.text.length > newValue.text.length) {
      final oldDigits =
          PhoneHelper.extractNationalDigits(oldValue.text, countryCode);
      final newDigits =
          PhoneHelper.extractNationalDigits(newValue.text, countryCode);

      String digitsToFormat = newDigits;
      // Если удалили не цифру (скобку, дефис, пробел), удаляем предшествующую цифру
      if (oldDigits == newDigits && newDigits.isNotEmpty) {
        digitsToFormat = newDigits.substring(0, newDigits.length - 1);
      }

      final formatted = PhoneHelper.format(digitsToFormat, countryCode);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final formatted = PhoneHelper.format(text, countryCode);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
