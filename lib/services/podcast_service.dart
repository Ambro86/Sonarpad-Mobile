import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/podcast.dart';
import 'raiplay_sound_service.dart';

class PodcastService {
  String _getPlayedEpisodesKey(String feedUrl) => 'sonarpad_played_episodes_$feedUrl';

  Future<List<PodcastEpisode>> getPlayedEpisodes(String feedUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getStringList(_getPlayedEpisodesKey(feedUrl)) ?? [];
    final list = <PodcastEpisode>[];
    for (final str in listStr) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        list.add(PodcastEpisode(
          title: decoded['title'] ?? '',
          description: decoded['description'] ?? '',
          audioUrl: decoded['audioUrl'] ?? '',
          publishedAt: decoded['publishedAt'] != null ? DateTime.parse(decoded['publishedAt']) : null,
        ));
      } catch (_) {}
    }
    return list;
  }

  Future<void> markEpisodeAsPlayed(String feedUrl, PodcastEpisode episode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getPlayedEpisodesKey(feedUrl);
    var current = await getPlayedEpisodes(feedUrl);
    
    // Rimuovi se c'è già
    current.removeWhere((e) => e.audioUrl == episode.audioUrl);
    
    // Aggiungi in cima
    current.insert(0, episode);
    
    // Tieni massimo 100
    if (current.length > 100) {
      current = current.sublist(0, 100);
    }
    
    final encoded = current.map((e) => jsonEncode({
      'title': e.title,
      'description': e.description,
      'audioUrl': e.audioUrl,
      'publishedAt': e.publishedAt?.toIso8601String(),
    })).toList();
    
    await prefs.setStringList(key, encoded);
  }

  Future<void> clearPlayedEpisodes(String feedUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getPlayedEpisodesKey(feedUrl));
  }

  static const _prefsKey = 'sonarpad_podcast_subscriptions';
  static const countries = [
    PodcastCountry('ae', 'Emirati Arabi Uniti'),
    PodcastCountry('al', 'Albania'),
    PodcastCountry('am', 'Armenia'),
    PodcastCountry('at', 'Austria'),
    PodcastCountry('au', 'Australia'),
    PodcastCountry('az', 'Azerbaigian'),
    PodcastCountry('bd', 'Bangladesh'),
    PodcastCountry('be', 'Belgio'),
    PodcastCountry('bg', 'Bulgaria'),
    PodcastCountry('bo', 'Bolivia'),
    PodcastCountry('bn', 'Brunei'),
    PodcastCountry('br', 'Brasile'),
    PodcastCountry('bt', 'Bhutan'),
    PodcastCountry('bw', 'Botswana'),
    PodcastCountry('ca', 'Canada'),
    PodcastCountry('ch', 'Svizzera'),
    PodcastCountry('ci', 'Costa d\'Avorio'),
    PodcastCountry('cl', 'Cile'),
    PodcastCountry('cm', 'Camerun'),
    PodcastCountry('cn', 'Cina'),
    PodcastCountry('co', 'Colombia'),
    PodcastCountry('cr', 'Costa Rica'),
    PodcastCountry('cy', 'Cipro'),
    PodcastCountry('cz', 'Repubblica Ceca'),
    PodcastCountry('dk', 'Danimarca'),
    PodcastCountry('do', 'Repubblica Dominicana'),
    PodcastCountry('dz', 'Algeria'),
    PodcastCountry('ee', 'Estonia'),
    PodcastCountry('ec', 'Ecuador'),
    PodcastCountry('eg', 'Egitto'),
    PodcastCountry('et', 'Etiopia'),
    PodcastCountry('fi', 'Finlandia'),
    PodcastCountry('fr', 'Francia'),
    PodcastCountry('de', 'Germania'),
    PodcastCountry('ge', 'Georgia'),
    PodcastCountry('gh', 'Ghana'),
    PodcastCountry('gr', 'Grecia'),
    PodcastCountry('gt', 'Guatemala'),
    PodcastCountry('hr', 'Croazia'),
    PodcastCountry('hk', 'Hong Kong'),
    PodcastCountry('hn', 'Honduras'),
    PodcastCountry('hu', 'Ungheria'),
    PodcastCountry('id', 'Indonesia'),
    PodcastCountry('in', 'India'),
    PodcastCountry('ie', 'Irlanda'),
    PodcastCountry('is', 'Islanda'),
    PodcastCountry('il', 'Israele'),
    PodcastCountry('it', 'Italia'),
    PodcastCountry('jp', 'Giappone'),
    PodcastCountry('jm', 'Giamaica'),
    PodcastCountry('jo', 'Giordania'),
    PodcastCountry('ke', 'Kenya'),
    PodcastCountry('kh', 'Cambogia'),
    PodcastCountry('kg', 'Kirghizistan'),
    PodcastCountry('kr', 'Corea del Sud'),
    PodcastCountry('kz', 'Kazakistan'),
    PodcastCountry('kw', 'Kuwait'),
    PodcastCountry('la', 'Laos'),
    PodcastCountry('lk', 'Sri Lanka'),
    PodcastCountry('lt', 'Lituania'),
    PodcastCountry('lb', 'Libano'),
    PodcastCountry('lu', 'Lussemburgo'),
    PodcastCountry('lv', 'Lettonia'),
    PodcastCountry('ma', 'Marocco'),
    PodcastCountry('mg', 'Madagascar'),
    PodcastCountry('ml', 'Mali'),
    PodcastCountry('mk', 'Macedonia del Nord'),
    PodcastCountry('mn', 'Mongolia'),
    PodcastCountry('mt', 'Malta'),
    PodcastCountry('mv', 'Maldive'),
    PodcastCountry('mx', 'Messico'),
    PodcastCountry('mu', 'Mauritius'),
    PodcastCountry('my', 'Malesia'),
    PodcastCountry('na', 'Namibia'),
    PodcastCountry('ng', 'Nigeria'),
    PodcastCountry('ni', 'Nicaragua'),
    PodcastCountry('nl', 'Paesi Bassi'),
    PodcastCountry('np', 'Nepal'),
    PodcastCountry('nz', 'Nuova Zelanda'),
    PodcastCountry('no', 'Norvegia'),
    PodcastCountry('pe', 'Peru'),
    PodcastCountry('pa', 'Panama'),
    PodcastCountry('ph', 'Filippine'),
    PodcastCountry('pk', 'Pakistan'),
    PodcastCountry('pl', 'Polonia'),
    PodcastCountry('pt', 'Portogallo'),
    PodcastCountry('py', 'Paraguay'),
    PodcastCountry('qa', 'Qatar'),
    PodcastCountry('ro', 'Romania'),
    PodcastCountry('rs', 'Serbia'),
    PodcastCountry('sa', 'Arabia Saudita'),
    PodcastCountry('sg', 'Singapore'),
    PodcastCountry('si', 'Slovenia'),
    PodcastCountry('sk', 'Slovacchia'),
    PodcastCountry('es', 'Spagna'),
    PodcastCountry('se', 'Svezia'),
    PodcastCountry('sn', 'Senegal'),
    PodcastCountry('sv', 'El Salvador'),
    PodcastCountry('th', 'Thailandia'),
    PodcastCountry('tn', 'Tunisia'),
    PodcastCountry('tr', 'Turchia'),
    PodcastCountry('tz', 'Tanzania'),
    PodcastCountry('tw', 'Taiwan'),
    PodcastCountry('ua', 'Ucraina'),
    PodcastCountry('ug', 'Uganda'),
    PodcastCountry('uz', 'Uzbekistan'),
    PodcastCountry('gb', 'Regno Unito'),
    PodcastCountry('us', 'Stati Uniti'),
    PodcastCountry('uy', 'Uruguay'),
    PodcastCountry('ve', 'Venezuela'),
    PodcastCountry('vn', 'Vietnam'),
    PodcastCountry('zm', 'Zambia'),
    PodcastCountry('zw', 'Zimbabwe'),
    PodcastCountry('ar', 'Argentina'),
  ];
  static const categories = [
    PodcastCategory(null, 'Tutte le categorie',
        englishName: 'All categories',
        frenchName: 'Toutes les catégories',
        spanishName: 'Todas las categorías',
        portugueseName: 'Todas as categorias',
        polishName: 'Wszystkie kategorie',
        czechName: 'Všechny kategorie'),
    PodcastCategory(1301, 'Arti',
        englishName: 'Arts', frenchName: 'Arts', spanishName: 'Arte',
        portugueseName: 'Artes',
        polishName: 'Sztuka',
        czechName: 'Umění'),
    PodcastCategory(1321, 'Affari',
        englishName: 'Business',
        frenchName: 'Affaires',
        spanishName: 'Negocios',
        portugueseName: 'Negócios',
        polishName: 'Biznes',
        czechName: 'Obchod'),
    PodcastCategory(1303, 'Commedia',
        englishName: 'Comedy', frenchName: 'Comédie', spanishName: 'Comedia',
        portugueseName: 'Comédia',
        polishName: 'Komedia',
        czechName: 'Komedie'),
    PodcastCategory(1304, 'Istruzione',
        englishName: 'Education',
        frenchName: 'Éducation',
        spanishName: 'Educación',
        portugueseName: 'Educação',
        polishName: 'Edukacja',
        czechName: 'Vzdělávání'),
    PodcastCategory(1483, 'Narrativa',
        englishName: 'Fiction', frenchName: 'Fiction', spanishName: 'Ficción',
        portugueseName: 'Ficção',
        polishName: 'Fikcja',
        czechName: 'Fikce'),
    PodcastCategory(1511, 'Governo',
        englishName: 'Government',
        frenchName: 'Gouvernement',
        spanishName: 'Gobierno',
        portugueseName: 'Governo',
        polishName: 'Rząd',
        czechName: 'Vláda'),
    PodcastCategory(1512, 'Salute e fitness',
        englishName: 'Health & Fitness',
        frenchName: 'Santé et fitness',
        spanishName: 'Salud y fitness',
        portugueseName: 'Saúde e fitness',
        polishName: 'Zdrowie i fitness',
        czechName: 'Zdraví a fitness'),
    PodcastCategory(1487, 'Storia',
        englishName: 'History',
        frenchName: 'Histoire',
        spanishName: 'Historia',
        portugueseName: 'História',
        polishName: 'Historia',
        czechName: 'Historie'),
    PodcastCategory(1305, 'Bambini e famiglia',
        englishName: 'Kids & Family',
        frenchName: 'Enfants et famille',
        spanishName: 'Niños y familia',
        portugueseName: 'Crianças e família',
        polishName: 'Dzieci i rodzina',
        czechName: 'Děti a rodina'),
    PodcastCategory(1502, 'Tempo libero',
        englishName: 'Leisure', frenchName: 'Loisirs', spanishName: 'Ocio',
        portugueseName: 'Lazer',
        polishName: 'Czas wolny',
        czechName: 'Volný čas'),
    PodcastCategory(1310, 'Musica',
        englishName: 'Music', frenchName: 'Musique', spanishName: 'Música',
        portugueseName: 'Música',
        polishName: 'Muzyka',
        czechName: 'Hudba'),
    PodcastCategory(1489, 'Notizie',
        englishName: 'News', frenchName: 'Actualités', spanishName: 'Noticias',
        portugueseName: 'Notícias',
        polishName: 'Wiadomości',
        czechName: 'Zprávy'),
    PodcastCategory(1314, 'Religione e spiritualità',
        englishName: 'Religion & Spirituality',
        frenchName: 'Religion et spiritualité',
        spanishName: 'Religión y espiritualidad',
        portugueseName: 'Religião e espiritualidade',
        polishName: 'Religia i duchowość',
        czechName: 'Náboženství a spiritualita'),
    PodcastCategory(1533, 'Scienza',
        englishName: 'Science', frenchName: 'Science', spanishName: 'Ciencia',
        portugueseName: 'Ciência',
        polishName: 'Nauka',
        czechName: 'Věda'),
    PodcastCategory(1324, 'Società e cultura',
        englishName: 'Society & Culture',
        frenchName: 'Société et culture',
        spanishName: 'Sociedad y cultura',
        portugueseName: 'Sociedade e cultura',
        polishName: 'Społeczeństwo i kultura',
        czechName: 'Společnost a kultura'),
    PodcastCategory(1545, 'Sport',
        englishName: 'Sports', frenchName: 'Sports', spanishName: 'Deportes',
        portugueseName: 'Desporto',
        polishName: 'Sport',
        czechName: 'Sport'),
    PodcastCategory(1318, 'Tecnologia',
        englishName: 'Technology',
        frenchName: 'Technologie',
        spanishName: 'Tecnología',
        portugueseName: 'Tecnologia',
        polishName: 'Technologia',
        czechName: 'Technologie'),
    PodcastCategory(1488, 'True crime',
        englishName: 'True Crime',
        frenchName: 'True crime',
        spanishName: 'True crime',
        portugueseName: 'Crime real',
        polishName: 'True crime',
        czechName: 'Skutečné zločiny'),
    PodcastCategory(1309, 'TV e film',
        englishName: 'TV & Film',
        frenchName: 'TV et cinéma',
        spanishName: 'TV y cine',
        portugueseName: 'TV e cinema',
        polishName: 'TV i film',
        czechName: 'TV a film'),
    PodcastCategory(1482, 'Libri',
        englishName: 'Books', frenchName: 'Livres', spanishName: 'Libros',
        portugueseName: 'Livros',
        polishName: 'Książki',
        czechName: 'Knihy'),
    PodcastCategory(1402, 'Design',
        englishName: 'Design', frenchName: 'Design', spanishName: 'Diseño',
        portugueseName: 'Design',
        polishName: 'Design',
        czechName: 'Design'),
    PodcastCategory(1459, 'Moda e bellezza',
        englishName: 'Fashion & Beauty',
        frenchName: 'Mode et beauté',
        spanishName: 'Moda y belleza',
        portugueseName: 'Moda e beleza',
        polishName: 'Moda i uroda',
        czechName: 'Móda a krása'),
    PodcastCategory(1306, 'Cibo',
        englishName: 'Food', frenchName: 'Cuisine', spanishName: 'Comida',
        portugueseName: 'Comida',
        polishName: 'Jedzenie',
        czechName: 'Jídlo'),
    PodcastCategory(1405, 'Arti performative',
        englishName: 'Performing Arts',
        frenchName: 'Arts du spectacle',
        spanishName: 'Artes escénicas',
        portugueseName: 'Artes performativas',
        polishName: 'Sztuki performatywne',
        czechName: 'Performativní umění'),
    PodcastCategory(1406, 'Arti visive',
        englishName: 'Visual Arts',
        frenchName: 'Arts visuels',
        spanishName: 'Artes visuales',
        portugueseName: 'Artes visuais',
        polishName: 'Sztuki wizualne',
        czechName: 'Výtvarné umění'),
    PodcastCategory(1410, 'Carriere',
        englishName: 'Careers',
        frenchName: 'Carrières',
        spanishName: 'Carreras',
        portugueseName: 'Carreiras',
        polishName: 'Kariera',
        czechName: 'Kariéra'),
    PodcastCategory(1493, 'Imprenditoria',
        englishName: 'Entrepreneurship',
        frenchName: 'Entrepreneuriat',
        spanishName: 'Emprendimiento',
        portugueseName: 'Empreendedorismo',
        polishName: 'Przedsiębiorczość',
        czechName: 'Podnikání'),
    PodcastCategory(1412, 'Investimenti',
        englishName: 'Investing',
        frenchName: 'Investissement',
        spanishName: 'Inversión',
        portugueseName: 'Investimentos',
        polishName: 'Inwestowanie',
        czechName: 'Investice'),
    PodcastCategory(1491, 'Management',
        englishName: 'Management',
        frenchName: 'Gestion',
        spanishName: 'Gestión',
        portugueseName: 'Gestão',
        polishName: 'Zarządzanie',
        czechName: 'Management'),
    PodcastCategory(1492, 'Marketing',
        englishName: 'Marketing',
        frenchName: 'Marketing',
        spanishName: 'Marketing',
        portugueseName: 'Marketing',
        polishName: 'Marketing',
        czechName: 'Marketing'),
    PodcastCategory(1494, 'Non profit',
        englishName: 'Non-Profit',
        frenchName: 'Sans but lucratif',
        spanishName: 'Sin fines de lucro',
        portugueseName: 'Sem fins lucrativos',
        polishName: 'Non profit',
        czechName: 'Neziskové organizace'),
    PodcastCategory(1496, 'Interviste comiche',
        englishName: 'Comedy Interviews',
        frenchName: 'Interviews humoristiques',
        spanishName: 'Entrevistas de comedia',
        portugueseName: 'Entrevistas de comédia',
        polishName: 'Wywiady komediowe',
        czechName: 'Komediální rozhovory'),
    PodcastCategory(1495, 'Improvvisazione',
        englishName: 'Improv',
        frenchName: 'Improvisation',
        spanishName: 'Improvisación',
        portugueseName: 'Improvisação',
        polishName: 'Improwizacja',
        czechName: 'Improvizace'),
    PodcastCategory(1497, 'Stand-up',
        englishName: 'Stand-Up',
        frenchName: 'Stand-up',
        spanishName: 'Stand-up',
        portugueseName: 'Stand-up',
        polishName: 'Stand-up',
        czechName: 'Stand-up'),
    PodcastCategory(1501, 'Corsi',
        englishName: 'Courses', frenchName: 'Cours', spanishName: 'Cursos',
        portugueseName: 'Cursos',
        polishName: 'Kursy',
        czechName: 'Kurzy'),
    PodcastCategory(1499, 'Come fare',
        englishName: 'How To',
        frenchName: 'Comment faire',
        spanishName: 'Cómo hacer',
        portugueseName: 'Tutoriais',
        polishName: 'Poradniki',
        czechName: 'Návody'),
    PodcastCategory(1498, 'Apprendimento lingue',
        englishName: 'Language Learning',
        frenchName: 'Apprentissage des langues',
        spanishName: 'Aprendizaje de idiomas',
        portugueseName: 'Aprendizagem de línguas',
        polishName: 'Nauka języków',
        czechName: 'Učení jazyků'),
    PodcastCategory(1500, 'Crescita personale',
        englishName: 'Self-Improvement',
        frenchName: 'Développement personnel',
        spanishName: 'Desarrollo personal',
        portugueseName: 'Desenvolvimento pessoal',
        polishName: 'Rozwój osobisty',
        czechName: 'Osobní růst'),
    PodcastCategory(1486, 'Narrativa comica',
        englishName: 'Comedy Fiction',
        frenchName: 'Fiction comique',
        spanishName: 'Ficción cómica',
        portugueseName: 'Ficção cómica',
        polishName: 'Fikcja komediowa',
        czechName: 'Komediální fikce'),
    PodcastCategory(1484, 'Dramma',
        englishName: 'Drama', frenchName: 'Drame', spanishName: 'Drama',
        portugueseName: 'Drama',
        polishName: 'Dramat',
        czechName: 'Drama'),
    PodcastCategory(1485, 'Fantascienza',
        englishName: 'Science Fiction',
        frenchName: 'Science-fiction',
        spanishName: 'Ciencia ficción',
        portugueseName: 'Ficção científica',
        polishName: 'Fantastyka naukowa',
        czechName: 'Sci-fi'),
    PodcastCategory(1513, 'Salute alternativa',
        englishName: 'Alternative Health',
        frenchName: 'Santé alternative',
        spanishName: 'Salud alternativa',
        portugueseName: 'Saúde alternativa',
        polishName: 'Zdrowie alternatywne',
        czechName: 'Alternativní zdraví'),
    PodcastCategory(1514, 'Fitness',
        englishName: 'Fitness', frenchName: 'Fitness', spanishName: 'Fitness',
        portugueseName: 'Fitness',
        polishName: 'Fitness',
        czechName: 'Fitness'),
    PodcastCategory(1518, 'Medicina',
        englishName: 'Medicine',
        frenchName: 'Médecine',
        spanishName: 'Medicina',
        portugueseName: 'Medicina',
        polishName: 'Medycyna',
        czechName: 'Medicína'),
    PodcastCategory(1517, 'Salute mentale',
        englishName: 'Mental Health',
        frenchName: 'Santé mentale',
        spanishName: 'Salud mental',
        portugueseName: 'Saúde mental',
        polishName: 'Zdrowie psychiczne',
        czechName: 'Duševní zdraví'),
    PodcastCategory(1515, 'Nutrizione',
        englishName: 'Nutrition',
        frenchName: 'Nutrition',
        spanishName: 'Nutrición',
        portugueseName: 'Nutrição',
        polishName: 'Żywienie',
        czechName: 'Výživa'),
    PodcastCategory(1516, 'Sessualità',
        englishName: 'Sexuality',
        frenchName: 'Sexualité',
        spanishName: 'Sexualidad',
        portugueseName: 'Sexualidade',
        polishName: 'Seksualność',
        czechName: 'Sexualita'),
    PodcastCategory(1519, 'Educazione per bambini',
        englishName: 'Education for Kids',
        frenchName: 'Éducation pour enfants',
        spanishName: 'Educación para niños',
        portugueseName: 'Educação para crianças',
        polishName: 'Edukacja dla dzieci',
        czechName: 'Vzdělávání dětí'),
    PodcastCategory(1521, 'Genitorialità',
        englishName: 'Parenting',
        frenchName: 'Parentalité',
        spanishName: 'Crianza',
        portugueseName: 'Parentalidade',
        polishName: 'Rodzicielstwo',
        czechName: 'Rodičovství'),
    PodcastCategory(1522, 'Animali domestici',
        englishName: 'Pets & Animals',
        frenchName: 'Animaux de compagnie',
        spanishName: 'Mascotas y animales',
        portugueseName: 'Animais de estimação',
        polishName: 'Zwierzęta domowe',
        czechName: 'Domácí mazlíčci'),
    PodcastCategory(1520, 'Storie per bambini',
        englishName: 'Stories for Kids',
        frenchName: 'Histoires pour enfants',
        spanishName: 'Cuentos para niños',
        portugueseName: 'Histórias para crianças',
        polishName: 'Historie dla dzieci',
        czechName: 'Příběhy pro děti'),
    PodcastCategory(1510, 'Animazione e manga',
        englishName: 'Animation & Manga',
        frenchName: 'Animation et manga',
        spanishName: 'Animación y manga',
        portugueseName: 'Animação e manga',
        polishName: 'Animacja i manga',
        czechName: 'Animace a manga'),
    PodcastCategory(1503, 'Automobili',
        englishName: 'Automotive',
        frenchName: 'Automobile',
        spanishName: 'Automoción',
        portugueseName: 'Automóveis',
        polishName: 'Motoryzacja',
        czechName: 'Automobily'),
    PodcastCategory(1504, 'Aviazione',
        englishName: 'Aviation',
        frenchName: 'Aviation',
        spanishName: 'Aviación',
        portugueseName: 'Aviação',
        polishName: 'Lotnictwo',
        czechName: 'Letectví'),
    PodcastCategory(1506, 'Artigianato',
        englishName: 'Crafts',
        frenchName: 'Artisanat',
        spanishName: 'Manualidades',
        portugueseName: 'Artesanato',
        polishName: 'Rękodzieło',
        czechName: 'Řemesla'),
    PodcastCategory(1507, 'Giochi',
        englishName: 'Games', frenchName: 'Jeux', spanishName: 'Juegos',
        portugueseName: 'Jogos',
        polishName: 'Gry',
        czechName: 'Hry'),
    PodcastCategory(1505, 'Hobby',
        englishName: 'Hobbies',
        frenchName: 'Loisirs',
        spanishName: 'Pasatiempos',
        portugueseName: 'Passatempos',
        polishName: 'Hobby',
        czechName: 'Koníčky'),
    PodcastCategory(1508, 'Casa e giardino',
        englishName: 'Home & Garden',
        frenchName: 'Maison et jardin',
        spanishName: 'Hogar y jardín',
        portugueseName: 'Casa e jardim',
        polishName: 'Dom i ogród',
        czechName: 'Dům a zahrada'),
    PodcastCategory(1509, 'Videogiochi',
        englishName: 'Video Games',
        frenchName: 'Jeux vidéo',
        spanishName: 'Videojuegos',
        portugueseName: 'Videojogos',
        polishName: 'Gry wideo',
        czechName: 'Videohry'),
    PodcastCategory(1523, 'Commenti musicali',
        englishName: 'Music Commentary',
        frenchName: 'Commentaires musicaux',
        spanishName: 'Comentarios musicales',
        portugueseName: 'Comentários musicais',
        polishName: 'Komentarze muzyczne',
        czechName: 'Hudební komentáře'),
    PodcastCategory(1524, 'Storia della musica',
        englishName: 'Music History',
        frenchName: 'Histoire de la musique',
        spanishName: 'Historia de la música',
        portugueseName: 'História da música',
        polishName: 'Historia muzyki',
        czechName: 'Historie hudby'),
    PodcastCategory(1525, 'Interviste musicali',
        englishName: 'Music Interviews',
        frenchName: 'Interviews musicales',
        spanishName: 'Entrevistas musicales',
        portugueseName: 'Entrevistas musicais',
        polishName: 'Wywiady muzyczne',
        czechName: 'Hudební rozhovory'),
    PodcastCategory(1490, 'Notizie di economia',
        englishName: 'Business News',
        frenchName: 'Actualités business',
        spanishName: 'Noticias de negocios',
        portugueseName: 'Notícias de economia',
        polishName: 'Wiadomości biznesowe',
        czechName: 'Ekonomické zprávy'),
    PodcastCategory(1526, 'Notizie quotidiane',
        englishName: 'Daily News',
        frenchName: 'Actualités quotidiennes',
        spanishName: 'Noticias diarias',
        portugueseName: 'Notícias diárias',
        polishName: 'Wiadomości dnia',
        czechName: 'Denní zprávy'),
    PodcastCategory(1531, 'Notizie di spettacolo',
        englishName: 'Entertainment News',
        frenchName: 'Actualités divertissement',
        spanishName: 'Noticias de entretenimiento',
        portugueseName: 'Notícias de entretenimento',
        polishName: 'Wiadomości rozrywkowe',
        czechName: 'Zprávy ze zábavy'),
    PodcastCategory(1530, 'Commenti alle notizie',
        englishName: 'News Commentary',
        frenchName: 'Commentaires sur l\'actualité',
        spanishName: 'Comentario de noticias',
        portugueseName: 'Comentários às notícias',
        polishName: 'Komentarze do wiadomości',
        czechName: 'Komentáře ke zprávám'),
    PodcastCategory(1527, 'Politica',
        englishName: 'Politics',
        frenchName: 'Politique',
        spanishName: 'Política',
        portugueseName: 'Política',
        polishName: 'Polityka',
        czechName: 'Politika'),
    PodcastCategory(1529, 'Notizie sportive',
        englishName: 'Sports News',
        frenchName: 'Actualités sportives',
        spanishName: 'Noticias deportivas',
        portugueseName: 'Notícias de desporto',
        polishName: 'Wiadomości sportowe',
        czechName: 'Sportovní zprávy'),
    PodcastCategory(1528, 'Notizie tecnologiche',
        englishName: 'Tech News',
        frenchName: 'Actualités tech',
        spanishName: 'Noticias de tecnología',
        portugueseName: 'Notícias de tecnologia',
        polishName: 'Wiadomości technologiczne',
        czechName: 'Technologické zprávy'),
    PodcastCategory(1438, 'Buddismo',
        englishName: 'Buddhism',
        frenchName: 'Bouddhisme',
        spanishName: 'Budismo',
        portugueseName: 'Budismo',
        polishName: 'Buddyzm',
        czechName: 'Buddhismus'),
    PodcastCategory(1439, 'Cristianesimo',
        englishName: 'Christianity',
        frenchName: 'Christianisme',
        spanishName: 'Cristianismo',
        portugueseName: 'Cristianismo',
        polishName: 'Chrześcijaństwo',
        czechName: 'Křesťanství'),
    PodcastCategory(1463, 'Induismo',
        englishName: 'Hinduism',
        frenchName: 'Hindouisme',
        spanishName: 'Hinduismo',
        portugueseName: 'Hinduísmo',
        polishName: 'Hinduizm',
        czechName: 'Hinduismus'),
    PodcastCategory(1440, 'Islam',
        englishName: 'Islam', frenchName: 'Islam', spanishName: 'Islam',
        portugueseName: 'Islão',
        polishName: 'Islam',
        czechName: 'Islám'),
    PodcastCategory(1441, 'Ebraismo',
        englishName: 'Judaism',
        frenchName: 'Judaïsme',
        spanishName: 'Judaísmo',
        portugueseName: 'Judaísmo',
        polishName: 'Judaizm',
        czechName: 'Judaismus'),
    PodcastCategory(1532, 'Religione',
        englishName: 'Religion',
        frenchName: 'Religion',
        spanishName: 'Religión',
        portugueseName: 'Religião',
        polishName: 'Religia',
        czechName: 'Náboženství'),
    PodcastCategory(1444, 'Spiritualità',
        englishName: 'Spirituality',
        frenchName: 'Spiritualité',
        spanishName: 'Espiritualidad',
        portugueseName: 'Espiritualidade',
        polishName: 'Duchowość',
        czechName: 'Spiritualita'),
    PodcastCategory(1538, 'Astronomia',
        englishName: 'Astronomy',
        frenchName: 'Astronomie',
        spanishName: 'Astronomía',
        portugueseName: 'Astronomia',
        polishName: 'Astronomia',
        czechName: 'Astronomie'),
    PodcastCategory(1539, 'Chimica',
        englishName: 'Chemistry', frenchName: 'Chimie', spanishName: 'Química',
        portugueseName: 'Química',
        polishName: 'Chemia',
        czechName: 'Chemie'),
    PodcastCategory(1540, 'Scienze della terra',
        englishName: 'Earth Sciences',
        frenchName: 'Sciences de la Terre',
        spanishName: 'Ciencias de la tierra',
        portugueseName: 'Ciências da Terra',
        polishName: 'Nauki o Ziemi',
        czechName: 'Vědy o Zemi'),
    PodcastCategory(1541, 'Scienze della vita',
        englishName: 'Life Sciences',
        frenchName: 'Sciences de la vie',
        spanishName: 'Ciencias de la vida',
        portugueseName: 'Ciências da vida',
        polishName: 'Nauki o życiu',
        czechName: 'Vědy o životě'),
    PodcastCategory(1536, 'Matematica',
        englishName: 'Mathematics',
        frenchName: 'Mathématiques',
        spanishName: 'Matemáticas',
        portugueseName: 'Matemática',
        polishName: 'Matematyka',
        czechName: 'Matematika'),
    PodcastCategory(1534, 'Scienze naturali',
        englishName: 'Natural Sciences',
        frenchName: 'Sciences naturelles',
        spanishName: 'Ciencias naturales',
        portugueseName: 'Ciências naturais',
        polishName: 'Nauki przyrodnicze',
        czechName: 'Přírodní vědy'),
    PodcastCategory(1537, 'Natura',
        englishName: 'Nature', frenchName: 'Nature', spanishName: 'Naturaleza',
        portugueseName: 'Natureza',
        polishName: 'Natura',
        czechName: 'Příroda'),
    PodcastCategory(1542, 'Fisica',
        englishName: 'Physics', frenchName: 'Physique', spanishName: 'Física',
        portugueseName: 'Física',
        polishName: 'Fizyka',
        czechName: 'Fyzika'),
    PodcastCategory(1535, 'Scienze sociali',
        englishName: 'Social Sciences',
        frenchName: 'Sciences sociales',
        spanishName: 'Ciencias sociales',
        portugueseName: 'Ciências sociais',
        polishName: 'Nauki społeczne',
        czechName: 'Sociální vědy'),
    PodcastCategory(1543, 'Documentari',
        englishName: 'Documentary',
        frenchName: 'Documentaire',
        spanishName: 'Documentales',
        portugueseName: 'Documentários',
        polishName: 'Dokument',
        czechName: 'Dokumenty'),
    PodcastCategory(1302, 'Diari personali',
        englishName: 'Personal Journals',
        frenchName: 'Journaux personnels',
        spanishName: 'Diarios personales',
        portugueseName: 'Diários pessoais',
        polishName: 'Dzienniki osobiste',
        czechName: 'Osobní deníky'),
    PodcastCategory(1443, 'Filosofia',
        englishName: 'Philosophy',
        frenchName: 'Philosophie',
        spanishName: 'Filosofía',
        portugueseName: 'Filosofia',
        polishName: 'Filozofia',
        czechName: 'Filozofie'),
    PodcastCategory(1320, 'Luoghi e viaggi',
        englishName: 'Places & Travel',
        frenchName: 'Lieux et voyages',
        spanishName: 'Lugares y viajes',
        portugueseName: 'Lugares e viagens',
        polishName: 'Miejsca i podróże',
        czechName: 'Místa a cestování'),
    PodcastCategory(1544, 'Relazioni',
        englishName: 'Relationships',
        frenchName: 'Relations',
        spanishName: 'Relaciones',
        portugueseName: 'Relações',
        polishName: 'Relacje',
        czechName: 'Vztahy'),
    PodcastCategory(1549, 'Baseball',
        englishName: 'Baseball',
        frenchName: 'Baseball',
        spanishName: 'Béisbol',
        portugueseName: 'Basebol',
        polishName: 'Baseball',
        czechName: 'Baseball'),
    PodcastCategory(1548, 'Pallacanestro',
        englishName: 'Basketball',
        frenchName: 'Basket-ball',
        spanishName: 'Baloncesto',
        portugueseName: 'Basquetebol',
        polishName: 'Koszykówka',
        czechName: 'Basketbal'),
    PodcastCategory(1554, 'Cricket',
        englishName: 'Cricket', frenchName: 'Cricket', spanishName: 'Cricket',
        portugueseName: 'Críquete',
        polishName: 'Krykiet',
        czechName: 'Kriket'),
    PodcastCategory(1560, 'Fantasy sport',
        englishName: 'Fantasy Sports',
        frenchName: 'Sports fantasy',
        spanishName: 'Deportes fantasy',
        portugueseName: 'Desporto fantasy',
        polishName: 'Sport fantasy',
        czechName: 'Fantasy sporty'),
    PodcastCategory(1547, 'Football americano',
        englishName: 'Football',
        frenchName: 'Football américain',
        spanishName: 'Fútbol americano',
        portugueseName: 'Futebol americano',
        polishName: 'Futbol amerykański',
        czechName: 'Americký fotbal'),
    PodcastCategory(1553, 'Golf',
        englishName: 'Golf', frenchName: 'Golf', spanishName: 'Golf',
        portugueseName: 'Golfe',
        polishName: 'Golf',
        czechName: 'Golf'),
    PodcastCategory(1550, 'Hockey',
        englishName: 'Hockey', frenchName: 'Hockey', spanishName: 'Hockey',
        portugueseName: 'Hóquei',
        polishName: 'Hokej',
        czechName: 'Hokej'),
    PodcastCategory(1552, 'Rugby',
        englishName: 'Rugby', frenchName: 'Rugby', spanishName: 'Rugby',
        portugueseName: 'Râguebi',
        polishName: 'Rugby',
        czechName: 'Ragby'),
    PodcastCategory(1551, 'Corsa',
        englishName: 'Running',
        frenchName: 'Course à pied',
        spanishName: 'Correr',
        portugueseName: 'Corrida',
        polishName: 'Bieganie',
        czechName: 'Běh'),
    PodcastCategory(1546, 'Calcio',
        englishName: 'Soccer', frenchName: 'Football', spanishName: 'Fútbol',
        portugueseName: 'Futebol',
        polishName: 'Piłka nożna',
        czechName: 'Fotbal'),
    PodcastCategory(1558, 'Nuoto',
        englishName: 'Swimming',
        frenchName: 'Natation',
        spanishName: 'Natación',
        portugueseName: 'Natação',
        polishName: 'Pływanie',
        czechName: 'Plavání'),
    PodcastCategory(1556, 'Tennis',
        englishName: 'Tennis', frenchName: 'Tennis', spanishName: 'Tenis',
        portugueseName: 'Ténis',
        polishName: 'Tenis',
        czechName: 'Tenis'),
    PodcastCategory(1557, 'Pallavolo',
        englishName: 'Volleyball',
        frenchName: 'Volleyball',
        spanishName: 'Voleibol',
        portugueseName: 'Voleibol',
        polishName: 'Siatkówka',
        czechName: 'Volejbal'),
    PodcastCategory(1559, 'Natura selvaggia',
        englishName: 'Wilderness',
        frenchName: 'Nature sauvage',
        spanishName: 'Naturaleza salvaje',
        portugueseName: 'Vida selvagem',
        polishName: 'Dzika przyroda',
        czechName: 'Divoká příroda'),
    PodcastCategory(1555, 'Lotta',
        englishName: 'Wrestling', frenchName: 'Lutte', spanishName: 'Lucha',
        portugueseName: 'Luta',
        polishName: 'Zapasy',
        czechName: 'Zápas'),
    PodcastCategory(1562, 'Dopo show',
        englishName: 'After Shows',
        frenchName: 'After show',
        spanishName: 'After show',
        portugueseName: 'Depois do programa',
        polishName: 'After show',
        czechName: 'Aftershow'),
    PodcastCategory(1564, 'Storia del cinema',
        englishName: 'Film History',
        frenchName: 'Histoire du cinéma',
        spanishName: 'Historia del cine',
        portugueseName: 'História do cinema',
        polishName: 'Historia kina',
        czechName: 'Historie filmu'),
    PodcastCategory(1565, 'Interviste sul cinema',
        englishName: 'Film Interviews',
        frenchName: 'Interviews de cinéma',
        spanishName: 'Entrevistas de cine',
        portugueseName: 'Entrevistas sobre cinema',
        polishName: 'Wywiady filmowe',
        czechName: 'Filmové rozhovory'),
    PodcastCategory(1563, 'Recensioni di film',
        englishName: 'Film Reviews',
        frenchName: 'Critiques de films',
        spanishName: 'Críticas de cine',
        portugueseName: 'Críticas de filmes',
        polishName: 'Recenzje filmów',
        czechName: 'Filmové recenze'),
    PodcastCategory(1561, 'Recensioni TV',
        englishName: 'TV Reviews',
        frenchName: 'Critiques TV',
        spanishName: 'Críticas de TV',
        portugueseName: 'Críticas de TV',
        polishName: 'Recenzje TV',
        czechName: 'TV recenze'),
  ];
  final http.Client _client;
  PodcastService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PodcastSubscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return raw.map((e) => PodcastSubscription.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveSubscriptions(
      List<PodcastSubscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, subscriptions.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<int> importSubscriptionsFromOpml(File file) async {
    final text = await file.readAsString();
    final document = XmlDocument.parse(text);
    final imported = <PodcastSubscription>[];

    for (final outline in document.findAllElements('outline')) {
      final feedUrl = _opmlAttribute(outline, 'xmlUrl')?.trim();
      if (feedUrl == null || feedUrl.isEmpty) continue;
      final titleAttr = _opmlAttribute(outline, 'title')?.trim();
      final textAttr = _opmlAttribute(outline, 'text')?.trim();
      final title = titleAttr?.isNotEmpty == true ? titleAttr : textAttr;
      imported.add(PodcastSubscription(
        title: title == null || title.isEmpty ? feedUrl : title,
        feedUrl: feedUrl,
      ));
    }

    if (imported.isEmpty) return 0;

    final current = await loadSubscriptions();
    final seen = current.map((e) => e.feedUrl.trim().toLowerCase()).toSet();
    final toAdd = <PodcastSubscription>[];
    for (final subscription in imported) {
      final key = subscription.feedUrl.trim().toLowerCase();
      if (seen.add(key)) {
        toAdd.add(subscription);
      }
    }

    if (toAdd.isEmpty) return 0;
    await saveSubscriptions([...current, ...toAdd]);
    return toAdd.length;
  }

  Future<String> exportSubscriptionsToOpml() async {
    final subscriptions = await loadSubscriptions();
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<opml version="1.0">')
      ..writeln('<head>')
      ..writeln('<title>Sonarpad Podcasts</title>')
      ..writeln('</head>')
      ..writeln('<body>');

    for (final subscription in subscriptions) {
      final title = _escapeOpmlAttribute(subscription.title);
      final url = _escapeOpmlAttribute(subscription.feedUrl);
      buffer.writeln(
        '  <outline text="$title" title="$title" type="rss" xmlUrl="$url" />',
      );
    }

    buffer
      ..writeln('</body>')
      ..writeln('</opml>');
    return buffer.toString();
  }

  String? _opmlAttribute(XmlElement element, String name) {
    for (final attribute in element.attributes) {
      if (attribute.name.local.toLowerCase() == name.toLowerCase()) {
        return attribute.value;
      }
    }
    return null;
  }

  String _escapeOpmlAttribute(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll("'", '&apos;');
  }

  Future<List<PodcastSearchResult>> searchPodcasts(String query,
      {String? country = 'it', PodcastCategory? category}) async {
    final q = query.trim();
    final genreId = category?.genreId;
    final topCountry = country ?? 'us';
    final appleParams = {
      'media': 'podcast',
      'entity': 'podcast',
      if (country != null) 'country': country,
      'limit': '25',
      if (q.isNotEmpty) 'term': q,
      if (genreId != null) 'genreId': '$genreId',
    };
    final results = <PodcastSearchResult>[];
    final errors = <Object>[];
    Object? topByGenreError;
    if (q.isEmpty) {
      try {
        results.addAll(genreId == null
            ? await _searchAppleTopByCountry(topCountry)
            : await _searchAppleTopByGenre(genreId, topCountry));
      } catch (e) {
        topByGenreError = e;
      }
    }
    if (q.isNotEmpty || genreId != null) {
      try {
        results.addAll(await _searchApple(appleParams));
      } catch (e) {
        if (topByGenreError != null) errors.add(topByGenreError);
        errors.add(e);
      }
    } else if (topByGenreError != null) {
      errors.add(topByGenreError);
    }
    if (q.isNotEmpty) {
      try {
        results.addAll(await _searchSpreaker(q));
      } catch (e) {
        errors.add(e);
      }
    }
    if (results.isEmpty && errors.isNotEmpty) {
      throw Exception(errors.join(' | '));
    }
    return _dedupResults(results);
  }

  Future<List<PodcastSearchResult>> _searchApple(
      Map<String, String> params) async {
    final uri = Uri.https('itunes.apple.com', '/search', params);
    final results = await _fetchAppleItems(uri, 'Ricerca podcast non riuscita');
    return _appleItemsToResults(results);
  }

  Future<List<Map<String, dynamic>>> _fetchAppleItems(
      Uri uri, String errorMessage) async {
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$errorMessage: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>? ?? const []);
    return results.cast<Map<String, dynamic>>();
  }

  List<PodcastSearchResult> _appleItemsToResults(
      List<Map<String, dynamic>> results) {
    return results
        .map((item) {
          final feedUrl = (item['feedUrl'] ?? '').toString();
          if (feedUrl.isEmpty) return null;
          return PodcastSearchResult(
            title:
                (item['collectionName'] ?? 'Podcast senza titolo').toString(),
            author: (item['artistName'] ?? '').toString(),
            feedUrl: feedUrl,
            artworkUrl: item['artworkUrl100']?.toString(),
          );
        })
        .whereType<PodcastSearchResult>()
        .toList();
  }

  Future<List<PodcastSearchResult>> _searchAppleTopByCountry(
      String country) async {
    final uri = Uri.parse('https://itunes.apple.com/$country/rss/toppodcasts/'
        'limit=50/json');
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Podcast per nazione non raggiungibili: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final feed = decoded['feed'] as Map<String, dynamic>? ?? const {};
    final rawEntries = feed['entry'];
    final entries = rawEntries is List
        ? rawEntries
        : rawEntries == null
            ? const []
            : [rawEntries];
    final ids = entries
        .map((raw) {
          final entry = raw as Map<String, dynamic>;
          final id = entry['id'] as Map<String, dynamic>? ?? const {};
          final attributes =
              id['attributes'] as Map<String, dynamic>? ?? const {};
          return attributes['im:id']?.toString();
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];
    final lookupUri = Uri.https('itunes.apple.com', '/lookup', {
      'id': ids.join(','),
      'country': country,
    });
    final lookup =
        await _fetchAppleItems(lookupUri, 'Lookup podcast non riuscito');
    return _appleItemsToResults(lookup);
  }

  Future<List<PodcastSearchResult>> _searchAppleTopByGenre(
      int genreId, String country) async {
    final uri = Uri.parse('https://itunes.apple.com/$country/rss/toppodcasts/'
        'limit=50/genre=$genreId/json');
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Categorie podcast non raggiungibili: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final feed = decoded['feed'] as Map<String, dynamic>? ?? const {};
    final rawEntries = feed['entry'];
    final entries = rawEntries is List
        ? rawEntries
        : rawEntries == null
            ? const []
            : [rawEntries];
    final ids = entries
        .map((raw) {
          final entry = raw as Map<String, dynamic>;
          final id = entry['id'] as Map<String, dynamic>? ?? const {};
          final attributes =
              id['attributes'] as Map<String, dynamic>? ?? const {};
          return attributes['im:id']?.toString();
        })
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];
    final lookupUri = Uri.https('itunes.apple.com', '/lookup', {
      'id': ids.join(','),
      'country': country,
    });
    final lookup =
        await _fetchAppleItems(lookupUri, 'Lookup podcast non riuscito');
    final filtered =
        lookup.where((item) => _appleItemMatchesGenre(item, genreId)).toList();
    return _appleItemsToResults(filtered.isEmpty ? lookup : filtered);
  }

  bool _appleItemMatchesGenre(Map<String, dynamic> item, int genreId) {
    if (item['primaryGenreId']?.toString() == '$genreId') return true;
    final genreIds = item['genreIds'];
    if (genreIds is List) {
      return genreIds.any((id) => id.toString() == '$genreId');
    }
    return false;
  }

  Future<List<PodcastSearchResult>> _searchSpreaker(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('api.spreaker.com', '/v2/search', {
      'q': q,
      'type': 'shows',
      'limit': '20',
    });
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'SonarpadMobile/0.1',
      'Accept': 'application/json',
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ricerca Spreaker non riuscita: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = decoded['response'] as Map<String, dynamic>? ?? const {};
    final results = payload['items'] as List<dynamic>? ?? const [];
    return results
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          final showId = item['show_id']?.toString() ?? '';
          final title = (item['title'] ?? '').toString();
          if (showId.isEmpty || title.trim().isEmpty) return null;
          final image = item['image_url'] ?? item['site_url'];
          return PodcastSearchResult(
            title: title,
            author: (item['author_name'] ?? '').toString(),
            feedUrl: 'https://www.spreaker.com/show/$showId/episodes/feed',
            artworkUrl: image?.toString(),
          );
        })
        .whereType<PodcastSearchResult>()
        .toList();
  }

  List<PodcastSearchResult> _dedupResults(List<PodcastSearchResult> results) {
    final seenFeedUrls = <String>{};
    final seenTitles = <String>{};
    return results.where((result) {
      final feedKey = result.feedUrl.trim().toLowerCase();
      final titleKey =
          '${result.title.trim().toLowerCase()}|${result.author.trim().toLowerCase()}';
      if (seenFeedUrls.contains(feedKey) || seenTitles.contains(titleKey)) {
        return false;
      }
      seenFeedUrls.add(feedKey);
      seenTitles.add(titleKey);
      return true;
    }).toList();
  }

  Future<PodcastSubscription> addSearchResult(
      PodcastSearchResult result) async {
    final sub = PodcastSubscription(
      title: result.title,
      feedUrl: result.feedUrl,
      artworkUrl: result.artworkUrl,
    );
    final list = await loadSubscriptions();
    if (!list.any((e) => e.feedUrl == result.feedUrl)) {
      await saveSubscriptions([...list, sub]);
    }
    return sub;
  }

  Future<PodcastDetails> fetchPodcastDetails(PodcastSearchResult result) async {
    final response = await _client.get(Uri.parse(result.feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed non raggiungibile: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    final channel = doc.findAllElements('channel').firstOrNull;
    if (channel == null) {
      return PodcastDetails(
        title: result.title,
        author: result.author,
        description: '',
        feedUrl: result.feedUrl,
        artworkUrl: result.artworkUrl,
      );
    }

    final title = channel.findElements('title').firstOrNull?.innerText.trim();
    final description = _cleanHtml(
      channel.findElements('description').firstOrNull?.innerText ??
          channel
              .findAllElements('summary', namespace: '*')
              .firstOrNull
              ?.innerText ??
          '',
    );
    final author = channel
            .findAllElements('author', namespace: '*')
            .firstOrNull
            ?.innerText
            .trim() ??
        result.author;
    final artworkUrl = channel
            .findAllElements('image', namespace: '*')
            .firstOrNull
            ?.getAttribute('href') ??
        channel
            .findElements('image')
            .firstOrNull
            ?.findElements('url')
            .firstOrNull
            ?.innerText
            .trim() ??
        result.artworkUrl;

    return PodcastDetails(
      title: title?.isEmpty ?? true ? result.title : title!,
      author: author,
      description: description,
      feedUrl: result.feedUrl,
      artworkUrl: artworkUrl,
    );
  }

  Future<PodcastSubscription> addSubscription(String feedUrl) async {
    if (_isRaiPlaySoundUrl(feedUrl)) {
      final page = await RaiPlaySoundService().loadPage(feedUrl);
      final sub = PodcastSubscription(title: page.title, feedUrl: feedUrl);
      final list = await loadSubscriptions();
      if (!list.any((e) => e.feedUrl == feedUrl)) {
        await saveSubscriptions([...list, sub]);
      }
      return sub;
    }

    final response = await _client.get(Uri.parse(feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed non raggiungibile: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    final channel = doc.findAllElements('channel').isNotEmpty
        ? doc.findAllElements('channel').first
        : null;
    final title =
        channel?.findElements('title').firstOrNull?.innerText.trim() ?? feedUrl;
    final sub = PodcastSubscription(title: title, feedUrl: feedUrl);
    final list = await loadSubscriptions();
    if (!list.any((e) => e.feedUrl == feedUrl)) {
      await saveSubscriptions([...list, sub]);
    }
    return sub;
  }

  Future<void> removeSubscription(PodcastSubscription subscription) async {
    final list = await loadSubscriptions();
    list.removeWhere((e) => e.feedUrl == subscription.feedUrl);
    await saveSubscriptions(list);
  }

  Future<List<PodcastEpisode>> fetchEpisodes(
      PodcastSubscription subscription) async {
    if (_isRaiPlaySoundUrl(subscription.feedUrl)) {
      return _fetchRaiPlaySoundEpisodes(subscription.feedUrl);
    }

    final response = await _client.get(Uri.parse(subscription.feedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore feed podcast: ${response.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(response.bodyBytes));
    return doc
        .findAllElements('item')
        .map((item) {
          final enclosure = item.findElements('enclosure').firstOrNull;
          final mediaContent =
              item.findAllElements('content', namespace: '*').firstOrNull;
          final audioUrl = enclosure?.getAttribute('url') ??
              mediaContent?.getAttribute('url') ??
              '';
          return PodcastEpisode(
            title: item.findElements('title').firstOrNull?.innerText.trim() ??
                'Episodio senza titolo',
            description: _cleanHtml(
                item.findElements('description').firstOrNull?.innerText ?? ''),
            audioUrl: audioUrl,
            publishedAt: null,
          );
        })
        .where((e) => e.audioUrl.isNotEmpty)
        .toList();
  }

  Future<List<PodcastEpisode>> _fetchRaiPlaySoundEpisodes(String url) async {
    final page = await RaiPlaySoundService().loadPage(url);
    return page.items
        .where((item) => item.kind == RaiPlaySoundItemKind.audio)
        .map((item) {
          var audioUrl = item.audioUrl;
          if (!audioUrl.startsWith('http')) {
            final baseUri = Uri.parse(url);
            audioUrl = baseUri.resolve(audioUrl).toString();
          }
          return PodcastEpisode(
            title: item.title,
            description: item.description,
            audioUrl: audioUrl,
            id: 'raiplaysound:${item.id}',
            publishedAt: null,
          );
        })
        .where((episode) => episode.audioUrl.trim().isNotEmpty)
        .toList();
  }

  bool _isRaiPlaySoundUrl(String url) {
    return url.trim().toLowerCase().contains('raiplaysound.it');
  }

  Future<File> downloadEpisode(PodcastEpisode episode) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle =
        episode.title.replaceAll(RegExp(r'[^a-zA-Z0-9àèéìòùÀÈÉÌÒÙ _.-]'), '_');
    final ext = p.extension(Uri.parse(episode.audioUrl).path).isEmpty
        ? '.mp3'
        : p.extension(Uri.parse(episode.audioUrl).path);
    final file = File(p.join(dir.path, '$safeTitle$ext'));
    final request = http.Request('GET', Uri.parse(episode.audioUrl));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download non riuscito: ${response.statusCode}');
    }
    final sink = file.openWrite();
    await response.stream.pipe(sink);
    return file;
  }

  String _cleanHtml(String value) {
    final text = html_parser.parse(value).body?.text ?? value;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

extension FirstOrNullXml on Iterable<XmlElement> {
  XmlElement? get firstOrNull => isEmpty ? null : first;
}
