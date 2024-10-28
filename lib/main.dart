import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'services/database_helper.dart';

void main() {
  runApp(DictionaryApp());
}

class DictionaryApp extends StatelessWidget {
  const DictionaryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dzongkha-English Dictionary',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: DictionaryHomePage(),
    );
  }
}

// Definition class to hold keyword, definition, and italicized portions separately
class Definition {
  final String keyword;
  final String definition;
  final String italicized;

  Definition({required this.keyword, required this.definition, required this.italicized});
}

class DictionaryHomePage extends StatefulWidget {
  @override
  _DictionaryHomePageState createState() => _DictionaryHomePageState();
}

class _DictionaryHomePageState extends State<DictionaryHomePage> {
  Map<String, String> enDz = {};
  Map<String, String> dzEn = {};
  List<String> searchHistory = [];
  List<String> favorites = [];
  String searchQuery = '';
  Definition resultEnDz = Definition(keyword: '', definition: '', italicized: '');
  Definition resultDzEn = Definition(keyword: '', definition: '', italicized: '');
  DatabaseHelper databaseHelper = DatabaseHelper();

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

  void searchWord() async {
    if (searchQuery.isEmpty) return;

    String normalizedQuery = searchQuery.trim();
    print("Searching for: $normalizedQuery");

    resultEnDz = enDz[normalizedQuery] != null
        ? extractDefinition(enDz[normalizedQuery]!)
        : Definition(keyword: '', definition: 'No translation found', italicized: '');
    resultDzEn = dzEn[normalizedQuery] != null
        ? extractDefinition(dzEn[normalizedQuery]!)
        : Definition(keyword: '', definition: 'No translation found', italicized: '');

    setState(() {});

    await databaseHelper.insertHistory(normalizedQuery);
    loadFromDatabase();
  }

  Definition extractDefinition(String markupText) {
    // Regular expressions to match <k>, <i>, and remove other HTML-like tags
    final keyWordRegExp = RegExp(r'<k>(.*?)<\/k>');  // Matches content within <k> tags
    final italicRegExp = RegExp(r'<i>(.*?)<\/i>');   // Matches content within <i> tags
    final otherTagsRegExp = RegExp(r'<[^>]+>');      // Matches any other tags

    // Extract word within <k></k> tags
    String keyword = keyWordRegExp.firstMatch(markupText)?.group(1) ?? '';
    // Extract word within <i></i> tags
    String italicized = italicRegExp.firstMatch(markupText)?.group(1) ?? '';

    // Remove all other tags from the definition
    String cleanedText = markupText.replaceAll(otherTagsRegExp, '').trim();

    // Remove the keyword and italicized from the definition text if they exist
    cleanedText = cleanedText.replaceFirst(keyword, '').replaceFirst(italicized, '').trim();

    return Definition(
      keyword: keyword,
      definition: cleanedText,
      italicized: italicized,
    );
  }

  void toggleFavorite(String word) async {
    if (favorites.contains(word)) {
      await databaseHelper.deleteFavorite(word);
      print("Removed $word from favorites");
    } else {
      await databaseHelper.insertFavorite(word);
      print("Added $word to favorites");
    }

    await loadFromDatabase();
    setState(() {}); // Ensure UI updates after toggling favorite
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dzongkha-English Dictionary'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryPage(searchHistory)),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesPage(favorites)),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Search English or Dzongkha',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8), // Add some space between the TextField and the button
                ElevatedButton(
                  onPressed: searchWord,
                  child: Icon(Icons.search),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16), // Adjust padding if needed
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (resultEnDz.keyword.isNotEmpty)
              _buildDefinitionCard(resultEnDz, 'English -> Dzongkha'),
            SizedBox(height: 10),
            if (resultDzEn.keyword.isNotEmpty)
              _buildDefinitionCard(resultDzEn, 'Dzongkha -> English'),
            if (resultEnDz.keyword.isNotEmpty || resultDzEn.keyword.isNotEmpty)
              IconButton(
                icon: favorites.contains(searchQuery)
                    ? Icon(Icons.favorite, color: Colors.red)
                    : Icon(Icons.favorite_border),
                onPressed: () => toggleFavorite(searchQuery),
              ),
          ],
        ),
      ),
    );
  }

  // Widget for displaying a definition with static border outline
  Widget _buildDefinitionCard(Definition definition, String title) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey, width: 1.5), // Static outline border
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: definition.keyword,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22, // Larger font for keyword
                    color: Colors.black87,
                  ),
                ),
                TextSpan(
                  text: '\n${definition.definition} ',
                  style: TextStyle(
                    fontSize: 16, // Regular font for definition
                    color: Colors.black54,
                  ),
                ),
                TextSpan(
                  text: definition.italicized.isNotEmpty ? '\n(${definition.italicized})' : '',
                  style: TextStyle(
                    fontWeight: FontWeight.w500, // Medium bold for italicized text
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: Colors.blueGrey,
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

class HistoryPage extends StatelessWidget {
  final List<String> searchHistory;

  HistoryPage(this.searchHistory);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search History')),
      body: ListView.builder(
        itemCount: searchHistory.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(searchHistory[index]),
          );
        },
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final List<String> favorites;

  FavoritesPage(this.favorites);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Favorites')),
      body: ListView.builder(
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(favorites[index]),
          );
        },
      ),
    );
  }
}
