import 'package:flutter/material.dart';

class HelpButton extends StatefulWidget {
  const HelpButton({super.key});

  @override
  State<HelpButton> createState() => _HelpButtonState();
}

class _HelpButtonState extends State<HelpButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  void _toggleHelp() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  // Получение инструкции для текущей страницы
  String _getInstruction(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '';
    final currentPage = route.toLowerCase();

    if (currentPage.contains('knowledge') ||
        currentPage.isEmpty && ModalRoute.of(context)?.settings.name == null) {
      // Определяем по типу страницы через контекст
      if (context.widget.runtimeType.toString().contains('KnowledgePage')) {
        return '📖 База знаний:\n\n• Нажмите на любой вопрос, чтобы увидеть ответ\n• Используйте поиск для быстрого нахождения нужной темы\n• Часто задаваемые вопросы помогут решить большинство проблем';
      }
      if (context.widget.runtimeType.toString().contains('AiChatPage')) {
        return '🤖 ИИ Консультант:\n\n• Задайте вопрос в чате — ИИ ответит автоматически\n• Если ИИ не справляется, нажмите "Позвать оператора"\n• Оператор подключится в течение 1-2 минут';
      }
      if (context.widget.runtimeType.toString().contains('QrScannerPage')) {
        return '📷 Сканер QR кода:\n\n• Наведите камеру на QR-код\n• Держите телефон неподвижно\n• Результат появится автоматически\n• Включите вспышку для темных помещений';
      }
      if (context.widget.runtimeType.toString().contains('SupportPage')) {
        return '🆘 Техподдержка:\n\n• Напишите свой вопрос в чате\n• Оператор ответит в течение 5 минут\n• Для срочных вопросов звоните по номеру +7 (800) 123-45-67\n• Поддержка работает 24/7';
      }
      return '🏠 Главный экран:\n\n• Нажмите на любую карточку, чтобы перейти в раздел\n• Справа есть кнопка помощи — инструкция для каждого раздела';
    }

    return '📱 Управление приложением:\n\n• Свайпните вверх/вниз для прокрутки\n• Нажмите на кнопки для взаимодействия\n• Для возврата используйте стрелку назад';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Получаем инструкцию для текущей страницы
    final instruction = _getInstruction(context);

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Выезжающая панель с инструкцией
        if (_isExpanded)
          Positioned(
            right: 0,
            bottom: 70,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Инструкция',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _toggleHelp,
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        instruction,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _toggleHelp,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Понятно'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Кнопка-вопросик
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: _toggleHelp,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.help_outline,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
