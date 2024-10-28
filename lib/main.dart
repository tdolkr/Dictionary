import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'services/database_helper.dart';

void main() {
  runApp(const DictionaryApp());
}

class DictionaryApp extends StatelessWidget {
  const DictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dzongkha-English Dictionary',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const DictionaryHomePage(),
    );
  }
}

class Definition {
  final String keyword;
  final String phonetic;
  final List<Map<String, String>> meanings;

  Definition({
    required this.keyword,
    required this.phonetic,
    required this.meanings,
  });
}

class DictionaryHomePage extends StatefulWidget {
  const DictionaryHomePage({super.key});

  @override
  _DictionaryHomePageState createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> enDz = {};
  Map<String, String> dzEn = {};
  List<String> searchHistory = [];
  List<String> favorites = [];
  String searchQuery = '';
  Definition? localResult;
  Definition? apiResult;
  Definition? wordOfTheDay;
  DatabaseHelper databaseHelper = DatabaseHelper();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    loadData();
    loadFromDatabase();
    setWordOfTheDay();
  }

  Future<void> loadData() async {
    final String enDzString = await rootBundle.loadString('assets/en-dz.json');
    final String dzEnString = await rootBundle.loadString('assets/dz-en.json');

    setState(() {
      enDz = Map<String, String>.from(json.decode(enDzString));
      dzEn = Map<String, String>.from(json.decode(dzEnString));
    });
  }

  Future<void> loadFromDatabase() async {
    List<String> favs = await databaseHelper.getFavorites();
    List<String> history = await databaseHelper.getHistory();

    setState(() {
      favorites = favs;
      searchHistory = history;
    });
  }

  void setWordOfTheDay() {
    // Choose a random word from either enDz or dzEn
    final allWords = {...enDz, ...dzEn};
    final randomKey = allWords.keys.elementAt(Random().nextInt(allWords.length));
    wordOfTheDay = extractDefinition(allWords[randomKey]!);

    setState(() {});
  }

  void searchForWord(String word) {
    _searchController.text = word;
    setState(() {
      searchQuery = word;
      _selectedIndex = 0;
    });
    searchWord();
  }

  Future<void> searchWord() async {
    if (searchQuery.isEmpty) return;

    localResult = enDz[searchQuery] != null
        ? extractDefinition(enDz[searchQuery]!)
        : dzEn[searchQuery] != null
            ? extractDefinition(dzEn[searchQuery]!)
            : null;

    String? localPos = localResult?.meanings.isNotEmpty ?? false
        ? localResult!.meanings[0]['partOfSpeech']
        : null;

    final String url = 'https://api.dictionaryapi.dev/api/v2/entries/en/$searchQuery';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      final String keyword = data[0]['word'];
      final String phoneticText = data[0]['phonetic'] ?? '';
      final List<Map<String, String>> meanings = [];

      for (var meaning in data[0]['meanings']) {
        if (localPos == null || localPos == meaning['partOfSpeech']) {
          for (var definition in meaning['definitions']) {
            meanings.add({
              'partOfSpeech': meaning['partOfSpeech'],
              'definition': definition['definition'],
            });
          }
        }
      }

      apiResult = Definition(
        keyword: keyword,
        phonetic: phoneticText,
        meanings: meanings.isNotEmpty
            ? meanings
            : [
                {
                  'partOfSpeech': '',
                  'definition': 'No matching definitions found in API',
                },
              ],
      );
    } else {
      apiResult = Definition(
        keyword: searchQuery,
        phonetic: '',
        meanings: [
          {'partOfSpeech': '', 'definition': 'No API definition found'},
        ],
      );
    }

    setState(() {});

    if (!searchHistory.contains(searchQuery)) {
      await databaseHelper.insertHistory(searchQuery);
      loadFromDatabase();
    }
  }

  Definition extractDefinition(String markupText) {
    final italicRegExp = RegExp(r'<i>(.*?)<\/i>');
    final otherTagsRegExp = RegExp(r'<[^>]+>');

    String cleanedText = markupText.replaceAll(otherTagsRegExp, '').trim();
    String italicized = italicRegExp.firstMatch(markupText)?.group(1) ?? '';

    return Definition(
      keyword: searchQuery,
      phonetic: '',
      meanings: [
        {'partOfSpeech': italicized, 'definition': cleanedText},
      ],
    );
  }

  void toggleFavorite(String word) async {
    if (favorites.contains(word)) {
      await databaseHelper.deleteFavorite(word);
    } else {
      await databaseHelper.insertFavorite(word);
    }

    await loadFromDatabase();
    setState(() {});
  }

  Future<void> clearAllFavorites() async {
    await databaseHelper.clearFavorites();
    await loadFromDatabase();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dzongkha-English Dictionary',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _selectedIndex == 0
          ? _buildSearchPage()
          : _selectedIndex == 1
              ? HistoryPage(searchHistory, databaseHelper, loadFromDatabase, onWordTap: searchForWord)
              : FavoritesPage(
                  favorites,
                  onWordTap: searchForWord,
                  onDeleteFavorite: toggleFavorite,
                  onClearAllFavorites: clearAllFavorites,
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Favorites',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          if (wordOfTheDay != null)
            _buildDefinitionCard(wordOfTheDay!, isLocal: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: searchWord,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: Colors.indigo,
                ),
                child: const Text(
                  'Search',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              children: [
                if (localResult != null) _buildDefinitionCard(localResult!, isLocal: true),
                if (apiResult != null) _buildDefinitionCard(apiResult!, isLocal: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionCard(Definition definition, {required bool isLocal}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLocal && wordOfTheDay == definition)
            Text(
              "Word of the Day",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blueAccent,
              ),
            ),
          Row(
            children: [
              Text(
                definition.keyword,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                definition.phonetic,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Spacer(),
              if (isLocal)
                IconButton(
                  icon: favorites.contains(definition.keyword)
                      ? const Icon(Icons.star, color: Colors.amber)
                      : const Icon(Icons.star_border),
                  onPressed: () => toggleFavorite(definition.keyword),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var meaning in definition.meanings) ...[
            Text(
              '(${meaning['partOfSpeech']}) ${meaning['definition']}',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// HistoryPage and FavoritesPage classes remain the same.
