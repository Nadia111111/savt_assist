import 'package:flutter/material.dart';

class IosEmojiPicker extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;

  const IosEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  @override
  State<IosEmojiPicker> createState() => _IosEmojiPickerState();
}

class _IosEmojiPickerState extends State<IosEmojiPicker> {
  int _selectedCategoryIndex = 0;
  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.access_time_rounded,
      'name': 'Недавние',
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
        '💟', '💌', '😭', '🥺', '💀', '😢', '🥳', '💋', '😘', '👍',
        '😇', '😊', '☺️', '🙈', '🙏', '😍', '😔', '😡', '😂', '😜',
      ],
    },
    {
      'icon': Icons.sentiment_satisfied_alt_outlined,
      'name': 'Смайлы и люди',
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
        '💟', '🫀', '💌', '😀', '😃', '😄', '😁', '😆', '😅', '🤣',
        '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘',
        '😗', '😚', '😙', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗',
        '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒',
        '🙄', '😬', '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒',
        '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠',
        '🥳', '🥸', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😯',
        '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭',
        '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡',
        '😠', '🤬', '😈', '👿', '💀', '☠️', '💩', '🤡', '👹', '👺',
        '👻', '👽', '👾', '🤖', '😺', '😸', '😹', '😻', '😼', '😽',
        '🙀', '😿', '😾', '🙈', '🙉', '🙊', '💋', '💯', '💢', '💥',
        '💫', '💦', '💨', '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌',
        '🤏', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕',
        '👇', '☝️', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌',
        '👐', '🤲', '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦵', '🦶',
      ],
    },
    {
      'icon': Icons.pets_rounded,
      'name': 'Животные и природа',
      'emojis': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
        '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤',
        '🐣', '🐥', '🦆', '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄',
        '🐝', '🐛', '🦋', '🐌', '🐞', '🐜', '🦟', '🕷️', '🕸️', '🦂',
        '🐢', '🐍', '🦎', '🦖', '🦕', '🐙', '🦑', '🦐', '🦞', '🦀',
        '🐡', '🐠', '🐟', '🐬', '🐳', '🐋', '🦈', '🐊', '🐅', '🐆',
        '🦓', '🦍', '🦧', '🐘', '🦛', '🦏', '🐪', '🐫', '🦒', '🦘',
        '🐃', '🐂', '🐄', '🐎', '🐖', '🐏', '🐑', '🐐', '🦌', '🐕',
        '🐩', '🐈', '🐓', '🦃', '🦚', '🦜', '🦢', '🦩', '🕊️', '🐇',
        '🌲', '🌳', '🌴', '🌵', '🌾', '🌿', '☘️', '🍀', '🍁', '🍂',
        '🍃', '🍄', '🌰', '💐', '🌸', '💮', '🌹', '🥀', '🌺', '🌻',
        '🌼', '🌷', '🌱', '🪴', '☀️', '🌤️', '⛅', '🌥️', '☁️', '🌧️',
        '⛈️', '🌩️', '🌨️', '❄️', '☃️', '⛄', '🌬️', '💨', '🌪️', '🌫️',
        '🌈', '⭐', '🌟', '✨', '⚡', '🌙', '🌛', '🌜', '🌚', '🌕',
      ],
    },
    {
      'icon': Icons.restaurant_rounded,
      'name': 'Еда и напитки',
      'emojis': [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
        '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
        '🥦', '🥬', '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅',
        '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳',
        '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🦴', '🌭', '🍔',
        '🍟', '🍕', '🫓', '🥪', '🥙', '🧆', '🌮', '🌯', '🫔', '🥗',
        '🥘', '🫕', '🥫', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟',
        '🦪', '🍤', '🍙', '🍚', '🍘', '🍥', '🥠', '🥮', '🍢', '🍡',
        '🍧', '🍨', '🍦', '🥧', '🧁', '🍰', '🎂', '🍮', '🍭', '🍬',
        '🍫', '🍿', '🍩', '🍪', '🌰', '🥜', '🍯', '🥛', '🍼', '☕',
        '🫖', '🍵', '🍶', '🍾', '🍷', '🍸', '🍹', '🍺', '🍻', '🥂',
        '🥃', '🥤', '🧋', '🧃', '🧉', '🧊',
      ],
    },
    {
      'icon': Icons.sports_soccer_rounded,
      'name': 'Активность и спорт',
      'emojis': [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
        '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳',
        '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛼', '🛷',
        '⛸️', '🥌', '🎿', '🏂', '🪂', '🏋️', '🤼', '🤸', '⛹️', '🤺',
        '🤾', '🏌️', '🏇', '🧘', '🏄', '🏊', '🤽', '🚣', '🧗', '🚵',
        '🚴', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️', '🏵️', '🎗️', '🎫',
        '🎟️', '🎪', '🤹', '🎭', '🩰', '🎨', '🎬', '🎤', '🎧', '🎼',
        '🎹', '🥁', '🪘', '🎷', '🎺', '🪗', '🎸', '🪕', '🎻', '🎲',
        '♟️', '🎯', '🎳', '🎮', '🎰', '🧩',
      ],
    },
    {
      'icon': Icons.directions_car_rounded,
      'name': 'Путешествия и транспорт',
      'emojis': [
        '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
        '🛻', '🚚', '🚛', '🚜', '🦯', '🛴', '🚲', '🛵', '🏍️', '🛺',
        '🚨', '🚔', '🚍', '🚘', '🚖', '🚡', '🚠', '🚟', '🚃', '🚋',
        '🚞', '🚝', '🚄', '🚅', '🚈', '🚂', '🚆', '🚇', '🚊', '🚉',
        '✈️', '🛫', '🛬', '🛩️', '💺', '🛰️', '🚀', '🛸', '🚁', '🛶',
        '⛵', '🚤', '🛥️', '🛳️', '⛴️', '🚢', '⚓', '🛟', '⛽', '🚧',
        '🛑', '🚥', '🚦', '🗿', '🗽', '🗼', '🏰', '🏯', '🏟️', '🎡',
        '🎢', '🎠', '⛲', '⛱️', '🏖️', '🏝️', '🏜️', '🌋', '⛰️', '🏔️',
        '🏕️', '⛺', '🛖', '🏠', '🏡', '🏘️', '🏚️', '🏗️', '🏭', '🏢',
      ],
    },
    {
      'icon': Icons.lightbulb_outline_rounded,
      'name': 'Предметы и символы',
      'emojis': [
        '⌚', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '💽', '💾',
        '💿', '📀', '📷', '📸', '📹', '🎥', '📽️', '📞', '☎️', '📟',
        '📠', '📺', '📻', '🎙️', '⏱️', '⏲️', '⏰', '🕰️', '⌛', '⏳',
        '📡', '🔋', '🪫', '🔌', '💡', '🔦', '🕯️', '🧯', '💸', '💵',
        '💴', '💶', '💷', '🪙', '💰', '💳', '💎', '⚖️', '🧰', '🔧',
        '🔨', '⚒️', '🛠️', '⛏️', '🪚', '🔩', '⚙️', '🧱', '⛓️', '🧲',
        '🔫', '💣', '🧨', '🪓', '🔪', '🗡️', '⚔️', '🛡️', '🚬', '⚰️',
        '🪦', '🔮', '🧿', '🪬', '💈', '🔭', '🔬', '🩹', '🩺', '💊',
        '💉', '🩸', '🧬', '🧹', '🧺', '🧻', '🚽', '🚰', '🚿', '🛁',
        '🧼', '🪥', '🪒', '🧽', '🔑', '🗝️', '🚪', '🪑', '🛋️', '🛏️',
        '🛍️', '🛒', '🎁', '🎈', '🎏', '🎀', '🎉', '🎊', '🏮', '✉️',
        '📩', '📨', '📧', '💌', '📦', '🏷️', '📫', '📪', '📬', '📭',
      ],
    },
  ];

  @override
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _currentEmojis {
    return _categories[_selectedCategoryIndex]['emojis'] as List<String>;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F7);

    return Container(
      height: 290,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // 1. Categories bar (like screenshot 4)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_categories.length, (idx) {
                final cat = _categories[idx];
                final isSelected = _selectedCategoryIndex == idx;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = idx;
                    });
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(
                      cat['icon'] as IconData,
                      size: 20,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 2. Emoji grid
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: _currentEmojis.length,
              itemBuilder: (context, index) {
                final emoji = _currentEmojis[index];
                return InkWell(
                  onTap: () => widget.onEmojiSelected(emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. Bottom bar (Эмодзи, ✕)
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161A) : const Color(0xFFE5E5EA),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C34) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Эмодзи',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
