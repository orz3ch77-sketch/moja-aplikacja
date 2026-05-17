import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChakraTestPage extends StatefulWidget {
  const ChakraTestPage({super.key});

  @override
  State<ChakraTestPage> createState() => _ChakraTestPageState();
}

class _ChakraTestPageState extends State<ChakraTestPage> {
  late final Future<ChakraTest> _testFuture;
  final Set<String> _selectedProblems = {};
  int _selectedChakra = 0;

  @override
  void initState() {
    super.initState();
    _testFuture = ChakraTest.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/pg.webp', fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          SafeArea(
            child: FutureBuilder<ChakraTest>(
              future: _testFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(message: snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final test = snapshot.data!;
                final chakras = test.chakras;
                final chakra = chakras[_selectedChakra];

                return Column(
                  children: [
                    _Header(
                      title: test.title,
                      selectedCount: _selectedProblems.length,
                      onBack: () => Navigator.pop(context),
                      onClear: _selectedProblems.isEmpty
                          ? null
                          : () => setState(_selectedProblems.clear),
                    ),
                    _ChakraTabs(
                      chakras: chakras,
                      selectedIndex: _selectedChakra,
                      selectedProblems: _selectedProblems,
                      onChanged: (index) {
                        setState(() => _selectedChakra = index);
                      },
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                        children: [
                          _ChakraIntro(chakra: chakra),
                          const SizedBox(height: 12),
                          ...List.generate(chakra.problems.length, (index) {
                            final key = chakra.problemKey(index);
                            final selected = _selectedProblems.contains(key);

                            return _ProblemTile(
                              text: chakra.problems[index],
                              selected: selected,
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedProblems.remove(key);
                                  } else {
                                    _selectedProblems.add(key);
                                  }
                                });
                              },
                            );
                          }),
                          const SizedBox(height: 12),
                          _Disclaimer(text: test.disclaimer),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: FutureBuilder<ChakraTest>(
              future: _testFuture,
              builder: (context, snapshot) {
                final test = snapshot.data;

                return _ResultButton(
                  enabled: test != null,
                  selectedCount: _selectedProblems.length,
                  onPressed: test == null ? null : () => _showResults(test),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showResults(ChakraTest test) {
    final results = test.chakras
        .map((chakra) => ChakraResult.from(chakra, _selectedProblems))
        .where((result) => result.score > 0)
        .toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wynik testu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  results.isEmpty
                      ? 'Nie zaznaczono problemów. Test jest gotowy do wypełnienia.'
                      : 'Najwyżej są czakry, przy których zaznaczono najwięcej problemów.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (results.isEmpty)
                  const _EmptyResult()
                else
                  ...results.take(4).map((result) {
                    return _ResultCard(result: result);
                  }),
              ],
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.selectedCount,
    required this.onBack,
    required this.onClear,
  });

  final String title;
  final int selectedCount;
  final VoidCallback onBack;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Wróć',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Zaznaczone problemy: $selectedCount',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Wyczyść',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _ChakraTabs extends StatelessWidget {
  const _ChakraTabs({
    required this.chakras,
    required this.selectedIndex,
    required this.selectedProblems,
    required this.onChanged,
  });

  final List<ChakraInfo> chakras;
  final int selectedIndex;
  final Set<String> selectedProblems;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: chakras.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chakra = chakras[index];
          final count = chakra.selectedCount(selectedProblems);
          final selected = index == selectedIndex;

          return ChoiceChip(
            selected: selected,
            label: Text(
                count == 0 ? chakra.shortName : '${chakra.shortName} $count'),
            avatar: count == 0
                ? null
                : CircleAvatar(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF512DA8),
                    child: Text('$count'),
                  ),
            onSelected: (_) => onChanged(index),
            selectedColor: const Color(0xFF7C4DFF),
            backgroundColor: Colors.black.withValues(alpha: 0.45),
            side: BorderSide(
              color: selected ? Colors.white70 : Colors.white24,
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}

class _ChakraIntro extends StatelessWidget {
  const _ChakraIntro({required this.chakra});

  final ChakraInfo chakra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chakra.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${chakra.sanskrit} • ${chakra.color} • mantra ${chakra.mantra}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chakra.areas.map((area) {
              return _SoftChip(text: area);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? const Color(0xFF3E2A78).withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: const Color(0xFFB388FF),
                  checkColor: Colors.black,
                  side: const BorderSide(color: Colors.white70, width: 1.4),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.enabled,
    required this.selectedCount,
    required this.onPressed,
  });

  final bool enabled;
  final int selectedCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.insights),
      label: Text(
        selectedCount == 0 ? 'Pokaż wynik' : 'Pokaż wynik ($selectedCount)',
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ChakraResult result;

  @override
  Widget build(BuildContext context) {
    final chakra = result.chakra;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chakra.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${result.score}/${result.total}',
                style: const TextStyle(
                  color: Color(0xFFB388FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${chakra.sanskrit} • możliwe osłabienie: ${result.percentText}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: result.percent,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFB388FF)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Propozycje wsparcia',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chakra.support.take(7).map((item) {
              return _SoftChip(text: item);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        'Zaznacz problemy przy wybranych czakrach, a program pokaże, które obszary wymagają największej uwagi.',
        style: TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nie udało się wczytać testu czakr',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class ChakraTest {
  const ChakraTest({
    required this.title,
    required this.disclaimer,
    required this.chakras,
  });

  final String title;
  final String disclaimer;
  final List<ChakraInfo> chakras;

  static Future<ChakraTest> load() async {
    final raw = await rootBundle.loadString(
      'assets/chakra_tests/chakra_test.json',
    );
    final data = jsonDecode(raw) as Map<String, dynamic>;

    return ChakraTest(
      title: data['title'] as String? ?? 'Test przepływu czakr',
      disclaimer: data['disclaimer'] as String? ?? '',
      chakras: (data['chakras'] as List<dynamic>? ?? [])
          .map((item) => ChakraInfo.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChakraInfo {
  const ChakraInfo({
    required this.id,
    required this.name,
    required this.sanskrit,
    required this.color,
    required this.mantra,
    required this.areas,
    required this.problems,
    required this.support,
  });

  final String id;
  final String name;
  final String sanskrit;
  final String color;
  final String mantra;
  final List<String> areas;
  final List<String> problems;
  final List<String> support;

  String get shortName {
    return name.replaceFirst('Czakra ', '');
  }

  String problemKey(int index) {
    return '$id::$index';
  }

  int selectedCount(Set<String> selectedProblems) {
    var count = 0;
    for (var i = 0; i < problems.length; i++) {
      if (selectedProblems.contains(problemKey(i))) {
        count++;
      }
    }
    return count;
  }

  factory ChakraInfo.fromJson(Map<String, dynamic> data) {
    return ChakraInfo(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      sanskrit: data['sanskrit'] as String? ?? '',
      color: data['color'] as String? ?? '',
      mantra: data['mantra'] as String? ?? '',
      areas: _stringList(data['areas']),
      problems: _stringList(data['problems']),
      support: _stringList(data['support']),
    );
  }

  static List<String> _stringList(Object? value) {
    return (value as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}

class ChakraResult {
  const ChakraResult({
    required this.chakra,
    required this.score,
    required this.total,
  });

  final ChakraInfo chakra;
  final int score;
  final int total;

  double get percent => total == 0 ? 0 : score / total;

  String get percentText => '${(percent * 100).round()}%';

  factory ChakraResult.from(
    ChakraInfo chakra,
    Set<String> selectedProblems,
  ) {
    return ChakraResult(
      chakra: chakra,
      score: chakra.selectedCount(selectedProblems),
      total: chakra.problems.length,
    );
  }
}
