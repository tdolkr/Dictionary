import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'services/database_helper.dart';
import 'package:just_audio/just_audio.dart';
import 'splash_screen.dart';



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
      home: const SplashScreen(), // Set SplashScreen as the home
    );
  }
}

class Definition {
  final String keyword;
  final String phonetic;
  final List<Map<String, String>> meanings;
  final String? audioUrl; // Add audioUrl property here

  Definition({
    required this.keyword,
    required this.phonetic,
    required this.meanings,
    this.audioUrl, // Make this optional
  });
}


class DictionaryHomePage extends StatefulWidget {
  const DictionaryHomePage({super.key});

  @override
  _DictionaryHomePageState createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> enDz = {}; // Updated to Map<String, dynamic>
  Map<String, dynamic> dzEn = {}; 
  List<String> searchHistory = [];
  List<String> favorites = [];
  List<String> suggestions = [];
  String searchQuery = '';
  Definition? localResult;
  Definition? apiResult;
  DatabaseHelper databaseHelper = DatabaseHelper();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    loadData();
    loadFromDatabase();
  }

  Future<void> loadData() async {
  final String enDzString = await rootBundle.loadString('assets/en-dz.json');
  final String dzEnString = await rootBundle.loadString('assets/dz-en.json');

  setState(() {
    enDz = Map<String, dynamic>.from(json.decode(enDzString));
    dzEn = Map<String, dynamic>.from(json.decode(dzEnString));
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

  void updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions = [];
      });
      return;
    }

    final allWords = enDz.keys.toList() + dzEn.keys.toList();
    final filteredSuggestions = allWords
        .where((word) => word.toLowerCase().startsWith(query.toLowerCase()))
        .take(5)
        .toList();

    setState(() {
      suggestions = filteredSuggestions;
    });
  }

  void searchForWord(String word) {
    _searchController.text = word;
    setState(() {
      searchQuery = word;
      _selectedIndex = 0;
      suggestions = [];
    });
    searchWord();
  }
Future<void> searchWord() async {
  if (searchQuery.isEmpty) return;

  String normalizedQuery = searchQuery.toLowerCase();

  // Check in local data first
  if (enDz.containsKey(normalizedQuery)) {
    localResult = extractDefinition(enDz[normalizedQuery]);
    await fetchApiDefinition(normalizedQuery); // Fetch from DictionaryAPI for English words
  } else if (dzEn.containsKey(normalizedQuery)) {
    localResult = extractDefinition(dzEn[normalizedQuery]);

    // Fetch from DictionaryAPI using only the English part of the Dzongkha definition, ignoring commas
    String? synonymToSearch = extractFirstSynonym(localResult?.meanings[0]['definition']);
    if (synonymToSearch != null) {
      await fetchApiDefinition(synonymToSearch);
    }
  } else {
    // If no local result, fetch from DictionaryAPI for both Dzongkha and English terms
    await fetchApiDefinition(normalizedQuery);
  }

  setState(() {});

  // Save to search history
  if (!searchHistory.contains(normalizedQuery)) {
    await databaseHelper.insertHistory(normalizedQuery);
    loadFromDatabase();
  }
}

String? extractFirstSynonym(String? definitionText) {
  if (definitionText == null) return null;

  // Use regex to capture text inside "Synonym:()"
  final synonymRegExp = RegExp(r'Synonym:\((.*?)\)');
  final match = synonymRegExp.firstMatch(definitionText);

  // Extract synonym or first word, then remove commas only for API query
  String rawSynonym = match != null && match.group(1) != null
      ? match.group(1)!.split(' ')[0]
      : definitionText.split(' ')[0];

  // Remove commas for API query only
  return rawSynonym.replaceAll(RegExp(r','), '');
}

// Function to fetch definition from DictionaryAPI
Future<void> fetchApiDefinition(String query) async {
  final String url = 'https://api.dictionaryapi.dev/api/v2/entries/en/$query';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    if (data.isNotEmpty) {
      final String keyword = data[0]['word'];
      final String phoneticText = data[0]['phonetic'] ?? '';
      final String? audioUrl = data[0]['phonetics']?.isNotEmpty == true
          ? data[0]['phonetics'][0]['audio']
          : null;

      final List<Map<String, String>> meanings = [];
      for (var meaning in data[0]['meanings']) {
        for (var definition in meaning['definitions']) {
          meanings.add({
            'partOfSpeech': meaning['partOfSpeech'] ?? '',
            'definition': definition['definition'] ?? 'No definition available.',
          });
        }
      }

      apiResult = Definition(
        keyword: keyword,
        phonetic: phoneticText,
        meanings: meanings.isNotEmpty ? meanings : [{'definition': 'No definitions found'}],
        audioUrl: audioUrl,
      );
    }
  } else {
    apiResult = Definition(
      keyword: query,
      phonetic: '',
      meanings: [{'definition': 'Definition not found in DictionaryAPI.'}],
      audioUrl: null,
    );
  }
}

Definition extractDefinition(Map<String, dynamic> entry) {
  // Keep commas in the definition for display
  String definitionText = entry['definition'] ?? 'No definition available';

  return Definition(
    keyword: entry['keyword'] ?? '',
    phonetic: '', // Add phonetic if available in your JSON
    meanings: [
      {
        'partOfSpeech': entry['partOfSpeech'] ?? '',
        'definition': definitionText, // Keep commas here
      }
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
              ? HistoryPage(
                  searchHistory: searchHistory,
                  databaseHelper: databaseHelper,
                  reloadHistory: loadFromDatabase,
                  onWordTap: searchForWord,
                )
              : FavoritesPage(
                  favorites: favorites,
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
          home: const SplashScreen();// Updated to show SplashScreen first

  }

 Widget _buildSearchPage() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                enableInteractiveSelection: true,
                focusNode: FocusNode(), // Ensures focus control for text selection
                textInputAction: TextInputAction.done, // Adds done button on mobile keyboards
                keyboardType: TextInputType.text,
                textDirection: TextDirection.ltr,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    updateSuggestions(value);
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
        const SizedBox(height: 10),
        if (suggestions.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(suggestions[index]),
                  onTap: () {
                    searchForWord(suggestions[index]);
                  },
                );
              },
            ),
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
  final audioPlayer = AudioPlayer();

  return Container(
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(16.0),
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            const Spacer(),
            if (definition.audioUrl != null && definition.audioUrl!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () async {
                  try {
                    await audioPlayer.setUrl(definition.audioUrl!);
                    audioPlayer.play();
                  } catch (e) {
                    // Handle audio playback errors here if needed
                    print("Audio playback failed: $e");
                  }
                },
              ),
            if (isLocal)
              IconButton(
                icon: favorites.contains(definition.keyword)
                    ? const Icon(Icons.star, color: Colors.amber)
                    : const Icon(Icons.star_border),
                onPressed: () => toggleFavorite(definition.keyword),
              ),
          ],
        ),
        
        // Phonetic text placed right below the keyword
        if (definition.phonetic.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              definition.phonetic,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        const SizedBox(height: 8),
        
        // Display each meaning with part of speech, without additional audio icons
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
class HistoryPage extends StatelessWidget {
  final List<String> searchHistory;
  final DatabaseHelper databaseHelper;
  final Function reloadHistory;
  final Function(String) onWordTap;

  const HistoryPage({
    super.key,
    required this.searchHistory,
    required this.databaseHelper,
    required this.reloadHistory,
    required this.onWordTap,
  });

  Future<void> deleteHistoryItem(String word) async {
    await databaseHelper.deleteHistory(word);
    reloadHistory();
  }

  Future<void> clearAllHistory() async {
    await databaseHelper.clearHistory();
    reloadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextButton(
            onPressed: () => clearAllHistory(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Clear All History'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchHistory.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(searchHistory[index]),
                onTap: () {
                  onWordTap(searchHistory[index]);
                },
                trailing: IconButton(
                  icon: Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () {
                    deleteHistoryItem(searchHistory[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final List<String> favorites;
  final Function(String) onWordTap;
  final Function(String) onDeleteFavorite;
  final Function onClearAllFavorites;

  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.onWordTap,
    required this.onDeleteFavorite,
    required this.onClearAllFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextButton(
            onPressed: () => onClearAllFavorites(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Clear All Favorites'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(favorites[index]),
                onTap: () {
                  onWordTap(favorites[index]);
                },
                trailing: IconButton(
                  icon: Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () {
                    onDeleteFavorite(favorites[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
