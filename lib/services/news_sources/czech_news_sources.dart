import 'news_rss_source.dart';

final czechNewsSources = [
  NewsRssSource(
    name: 'Google News Česko',
    uri: Uri.parse('https://news.google.com/rss?hl=cs&gl=CZ&ceid=CZ:cs'),
    categories: [
      NewsRssCategory(
        name: 'Moje město',
        uri: Uri.parse('https://news.google.com/'),
        isLocal: true,
      ),
      NewsRssCategory(
        name: 'Česko',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/NATION?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
      NewsRssCategory(
        name: 'Svět',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/WORLD?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
      NewsRssCategory(
        name: 'Byznys',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/BUSINESS?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
      NewsRssCategory(
        name: 'Věda a technologie',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
      NewsRssCategory(
        name: 'Zábava',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
      NewsRssCategory(
        name: 'Sport',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/SPORTS?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
      NewsRssCategory(
        name: 'Zdraví',
        uri: Uri.parse('https://news.google.com/news/rss/headlines/section/topic/HEALTH?hl=cs&gl=CZ&ceid=CZ:cs'),
      ),
    ],
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zpravodajství - TV Nova',
    uri: Uri.parse('https://tn.nova.cz/rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Novinky',
    uri: Uri.parse('https://www.novinky.cz/rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Praha a střední Čechy iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=prahah'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Brno a jižní Morava iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=brnoh'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: České Budějovice a jižní Čechy iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=budejovice'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Královehradecký kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=hradec'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Jihlava a Vysočina iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=jihlava'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Karlovy Vary a Karlovarský kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=vary'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Liberecký kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=liberec'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Olomoucký kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=olomouc'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ostrava a Moravskoslezský kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=ostrava'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Pardubice a Pardubický kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=pardubice'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Plzeňský kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=plzen'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ústí nad Labem a Ústecký kraj iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=usti'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zlínský kraj',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=zlin'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ekonom',
    uri: Uri.parse('http://ekonom.ihned.cz/?p=400000_rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=zpravodaj'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ekonomika iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=ekonomikah'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Kultura iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=kultura'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Finance iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=fincentrum'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Domácí zprávy Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/domaci/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zahraniční zprávy Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/zahranici/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy z regionů Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/regiony/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ekonomika Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/ekonomika/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Osobní finance Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/finance/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Počasí Aktuálně',
    uri: Uri.parse('https://zpravy.aktualne.cz/rss/pocasi/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Magazín Aktuálně',
    uri: Uri.parse('https://magazin.aktualne.cz/rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Kultura Aktuálně',
    uri: Uri.parse('https://magazin.aktualne.cz/rss/kultura/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Brněnský deník - Zprávy',
    uri: Uri.parse('https://brnensky.denik.cz/rss/z_regionu.html'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Aktuality Měšec',
    uri: Uri.parse('http://www.mesec.cz/rss/aktuality/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Blesk',
    uri: Uri.parse('http://www.blesk.cz/rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: České noviny - Hlavní události',
    uri: Uri.parse('http://www.ceskenoviny.cz/sluzby/rss/zpravy.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy z domova - Lidovky',
    uri: Uri.parse('http://servis.lidovky.cz/rss.aspx?r=ln_domov'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Eprávo - články',
    uri: Uri.parse('http://www.epravo.cz/rss.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Eprávo - zákony',
    uri: Uri.parse('http://www.epravo.cz/rss.php?zakony'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Patria',
    uri: Uri.parse('http://www.patria.cz/rss.html'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: První zprávy',
    uri: Uri.parse('http://www.prvnizpravy.cz/repository/rss/zpravy_all_cs.xml'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Týden',
    uri: Uri.parse('http://www.tyden.cz/rss/rss.php?all'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Lupa - články a aktuality',
    uri: Uri.parse('http://rss.lupa.cz/clanky/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Praha Aktuálně',
    uri: Uri.parse('http://aktualne.centrum.cz/feeds/rss/domaci/regiony/praha/?photo=1'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Super - nejnovější články',
    uri: Uri.parse('http://www.super.cz/rss2'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Aha online',
    uri: Uri.parse('http://www.ahaonline.cz/rss.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy z domova iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/zpravy-domov'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy ze světa iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/zpravy-svet'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ekonomika iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/ekonomika'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Kultura iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/kultura'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy z ČR České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/cr.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy ze světa České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/svet.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Ekonomika České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/ekonomika.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Kultura České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/kultura.php'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: ČT24',
    uri: Uri.parse('https://ct24.ceskatelevize.cz/rss/hlavni-zpravy'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zpravodajství Brno Česká televize',
    uri: Uri.parse('https://www.ceskatelevize.cz/zpravodajstvi-brno/rss/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zpravodajství Ostrava Česká televize',
    uri: Uri.parse('https://www.ceskatelevize.cz/zpravodajstvi-ostrava/rss/'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zprávy Deník',
    uri: Uri.parse('https://www.denik.cz/rss/zpravy.html'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Domácí Hospodářské noviny',
    uri: Uri.parse('https://domaci.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Zahraniční Hospodářské noviny',
    uri: Uri.parse('https://zahranicni.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Byznys Hospodářské noviny',
    uri: Uri.parse('https://byznys.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Hospodářské noviny',
    uri: Uri.parse('https://hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Hospodářské noviny - podcasty',
    uri: Uri.parse('https://podcasty.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Seznam Zprávy - nejnovější články',
    uri: Uri.parse('https://www.seznamzpravy.cz/rss'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Parlamentní listy',
    uri: Uri.parse('https://www.parlamentnilisty.cz/export/rss.aspx'),
  ),
  NewsRssSource(
    name: 'Zpravodajství: Hlavní události - Zprávy Google',
    uri: Uri.parse('https://news.google.com/rss?hl=cs&gl=CZ&ceid=CZ:cs'),
  ),
  NewsRssSource(
    name: 'Sport: Sport iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=sport'),
  ),
  NewsRssSource(
    name: 'Sport: Fotbal iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=fotbalh'),
  ),
  NewsRssSource(
    name: 'Sport: Hokej iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=hokejh'),
  ),
  NewsRssSource(
    name: 'Sport: Tenis iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?r=tenis'),
  ),
  NewsRssSource(
    name: 'Sport: Volejbal iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?r=volejbal'),
  ),
  NewsRssSource(
    name: 'Sport: Basket iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=basket'),
  ),
  NewsRssSource(
    name: 'Sport: Sport Aktuálně',
    uri: Uri.parse('https://sport.aktualne.cz/rss/'),
  ),
  NewsRssSource(
    name: 'Sport: Hokej Aktuálně',
    uri: Uri.parse('https://sport.aktualne.cz/rss/hokej/'),
  ),
  NewsRssSource(
    name: 'Sport: Fotbal Aktuálně',
    uri: Uri.parse('https://sport.aktualne.cz/rss/fotbal/'),
  ),
  NewsRssSource(
    name: 'Sport: Motorismus Aktuálně',
    uri: Uri.parse('https://sport.aktualne.cz/rss/motorismus/'),
  ),
  NewsRssSource(
    name: 'Sport: Ostatní sporty Aktuálně',
    uri: Uri.parse('https://sport.aktualne.cz/rss/ostatni-sporty/'),
  ),
  NewsRssSource(
    name: 'Sport: Sport.cz',
    uri: Uri.parse('https://www.sport.cz/rss2'),
  ),
  NewsRssSource(
    name: 'Sport: Brněnský deník - Sport',
    uri: Uri.parse('https://brnensky.denik.cz/rss/sport_region.html'),
  ),
  NewsRssSource(
    name: 'Sport: iSport - Blesk',
    uri: Uri.parse('http://isport.blesk.cz/rss'),
  ),
  NewsRssSource(
    name: 'Sport: F1sport',
    uri: Uri.parse('https://f1sport.auto.cz/rss'),
  ),
  NewsRssSource(
    name: 'Sport: Sport iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/sport'),
  ),
  NewsRssSource(
    name: 'Sport: Rychlé sportovní zprávy iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/sportovni-zpravy'),
  ),
  NewsRssSource(
    name: 'Sport: Sport České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/sport.php'),
  ),
  NewsRssSource(
    name: 'Sport: Fotbal České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/fotbal.php'),
  ),
  NewsRssSource(
    name: 'Sport: Hokej České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/hokej.php'),
  ),
  NewsRssSource(
    name: 'Sport: Tenis České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/tenis.php'),
  ),
  NewsRssSource(
    name: 'Sport: ČT sport',
    uri: Uri.parse('https://www.ceskatelevize.cz/sport/rss/vsechny-zpravy/'),
  ),
  NewsRssSource(
    name: 'Sport: Fotbal ČT sport',
    uri: Uri.parse('https://www.ceskatelevize.cz/sport/rss/fotbal/'),
  ),
  NewsRssSource(
    name: 'Sport: Hokej ČT sport',
    uri: Uri.parse('https://www.ceskatelevize.cz/sport/rss/hokej/'),
  ),
  NewsRssSource(
    name: 'Sport: Tenis ČT sport',
    uri: Uri.parse('https://www.ceskatelevize.cz/sport/rss/tenis/'),
  ),
  NewsRssSource(
    name: 'Sport: Sport Deník',
    uri: Uri.parse('https://www.denik.cz/rss/sport.html'),
  ),
  NewsRssSource(
    name: 'Sport: ČT sport - podcasty',
    uri: Uri.parse('https://www.ceskatelevize.cz/sport/rss/podcasty/'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Živě',
    uri: Uri.parse('https://www.zive.cz/rss/sc-47/default.aspx?rss=1'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Technet iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=technet'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Netzin, magazín o internetu a webu',
    uri: Uri.parse('http://feeds.feedburner.com/netzincz?format=xml'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: AvMania, novinky ze světa audio a videotechniky',
    uri: Uri.parse('https://avmania.e15.cz/rss'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Svět audia',
    uri: Uri.parse('http://www.svetaudia.cz/export.jsp?format=rss2'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Goliáš, váš rádce pro nákup spotřební elektroniky',
    uri: Uri.parse('http://www.golias.cz/rss.xml'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: TV Freak',
    uri: Uri.parse('http://www.tvfreak.cz/export.jsp?format=rss2'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Notebook',
    uri: Uri.parse('http://notebook.cz/aktuality/notebook_cz.xml'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Svět hardware',
    uri: Uri.parse('https://www.svethardware.cz/export.jsp?format=rss2'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Cdr',
    uri: Uri.parse('http://cdr.cz/rss.xml'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: PC tuning',
    uri: Uri.parse('http://pctuning.tyden.cz/feed/rss'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Root',
    uri: Uri.parse('http://www.root.cz/rss/clanky/'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Novinky pro Windows - Slunečnice',
    uri: Uri.parse('https://www.slunecnice.cz/rss/novinky-windows/'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Chip',
    uri: Uri.parse('https://chip.cz/rss.xml'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: 21stoleti',
    uri: Uri.parse('http://21stoleti.cz/feed/rss/'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Vesmír',
    uri: Uri.parse('http://www.vesmir.cz/feed/rss/kategorie/clanky-volne'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: VTM',
    uri: Uri.parse('https://vtm.zive.cz/rss.ashx'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Sciencemag',
    uri: Uri.parse('https://sciencemag.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Věda a technologie iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/veda-technologie'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Tech Hospodářské noviny',
    uri: Uri.parse('https://tech.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Technika a zajímavosti: Alza',
    uri: Uri.parse('https://www.alza.cz/Rss.xml'),
  ),
  NewsRssSource(
    name: 'Automobily: Auto iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=autokat'),
  ),
  NewsRssSource(
    name: 'Automobily: Autorevue',
    uri: Uri.parse('https://www.autorevue.cz/rss'),
  ),
  NewsRssSource(
    name: 'Automobily: Auto - Café time',
    uri: Uri.parse('http://auto.cafetime.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Automobily: Elektrické vozy',
    uri: Uri.parse('https://elektrickevozy.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Automobily: Hybrid',
    uri: Uri.parse('http://www.hybrid.cz/rss.xml'),
  ),
  NewsRssSource(
    name: 'Automobily: Auto Hospodářské noviny',
    uri: Uri.parse('https://auto.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Fotoaparáty a fotografování: Digiarena, o fotografování víme vše',
    uri: Uri.parse('http://digiarena.zive.cz/RSS/sc-34/default.aspx?rss=1'),
  ),
  NewsRssSource(
    name: 'Fotoaparáty a fotografování: Fotorádce',
    uri: Uri.parse('http://www.fotoradce.cz/soubory/rss/clanky.xml'),
  ),
  NewsRssSource(
    name: 'Fotoaparáty a fotografování: Digimanie',
    uri: Uri.parse('https://www.digimanie.cz/export.jsp?format=rss2'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Mobil iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=mobil'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Mobilmania',
    uri: Uri.parse('https://mobilmania.zive.cz/rss/sc-47'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Mobilenet',
    uri: Uri.parse('https://mobilenet.cz/rss/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Mobilizujeme, bez mobilu ani ránu',
    uri: Uri.parse('http://mobilizujeme.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: SmartMania',
    uri: Uri.parse('https://smartmania.cz/rss/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Palmserver',
    uri: Uri.parse('http://www.palmserver.cz/atom.xml'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Svět Androida',
    uri: Uri.parse('http://feeds.feedburner.com/SvetAndroida?format=xml'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Androidmarket',
    uri: Uri.parse('http://www.androidmarket.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Jablíčkář',
    uri: Uri.parse('http://jablickar.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Appliště',
    uri: Uri.parse('http://www.appliste.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Letem světem Applem - Magazín o společnosti Apple a produktech Apple',
    uri: Uri.parse('http://www.letemsvetemapplem.eu/feed.xml'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Apple novinky',
    uri: Uri.parse('http://applenovinky.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Mobilní telefony a tablety: Dotekomanie',
    uri: Uri.parse('http://dotekomanie.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Ostatní: Bydlení iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=reality'),
  ),
  NewsRssSource(
    name: 'Ostatní: Cestování iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=iglobe'),
  ),
  NewsRssSource(
    name: 'Ostatní: Kavárna iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?r=kavarna'),
  ),
  NewsRssSource(
    name: 'Ostatní: Xman iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=xman'),
  ),
  NewsRssSource(
    name: 'Ostatní: Ona iDnes',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=ona'),
  ),
  NewsRssSource(
    name: 'Ostatní: Vaření, nejnovější články',
    uri: Uri.parse('https://www.vareni.cz/rss/clanky.xml'),
  ),
  NewsRssSource(
    name: 'Ostatní: Vaření, nejnovější recepty',
    uri: Uri.parse('https://www.vareni.cz/rss/recepty.xml'),
  ),
  NewsRssSource(
    name: 'Ostatní: Labužník, svět na talíři',
    uri: Uri.parse('http://www.labuznik.cz/rss-recepty/'),
  ),
  NewsRssSource(
    name: 'Ostatní: Akční ceny',
    uri: Uri.parse('https://www.akcniceny.cz/rss/'),
  ),
  NewsRssSource(
    name: 'Ostatní: Hoby iDnes',
    uri: Uri.parse('http://servis.idnes.cz/rss.aspx?c=hobby'),
  ),
  NewsRssSource(
    name: 'Ostatní: National Geographic',
    uri: Uri.parse('http://www.national-geographic.cz/feed'),
  ),
  NewsRssSource(
    name: 'Ostatní: Potraviny na pranýři',
    uri: Uri.parse('http://www.potravinynapranyri.cz/Rss.aspx'),
  ),
  NewsRssSource(
    name: 'Ostatní: Extra',
    uri: Uri.parse('http://www.extra.cz/rss.xml'),
  ),
  NewsRssSource(
    name: 'Ostatní: Pražská integrovaná doprava - Výluky',
    uri: Uri.parse('https://pid.cz/feed/rss-vyluky/'),
  ),
  NewsRssSource(
    name: 'Ostatní: Životní styl iRozhlas',
    uri: Uri.parse('https://www.irozhlas.cz/rss/irozhlas/section/zivotni-styl'),
  ),
  NewsRssSource(
    name: 'Ostatní: Magazín České noviny',
    uri: Uri.parse('https://www.ceskenoviny.cz/sluzby/rss/magazin.php'),
  ),
  NewsRssSource(
    name: 'Ostatní: Magazín Deník',
    uri: Uri.parse('https://www.denik.cz/rss/magazin.html'),
  ),
  NewsRssSource(
    name: 'Ostatní: Podnikání Deník',
    uri: Uri.parse('https://www.denik.cz/rss/podnikani.html'),
  ),
  NewsRssSource(
    name: 'Ostatní: Reality Hospodářské noviny',
    uri: Uri.parse('https://byznys.hn.cz/?p=02R000_rss'),
  ),
  NewsRssSource(
    name: 'Ostatní: Investice Hospodářské noviny',
    uri: Uri.parse('https://investice.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Ostatní: Art Hospodářské noviny',
    uri: Uri.parse('https://art.hn.cz/?m=rss'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Nové tituly v katalogu knihovny KTN',
    uri: Uri.parse('https://biblio.oui.technology/biblio/catalog-feed/recent-items.cs.rss'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Poslepu, přístupnost webových stránek, asistivní technologie pro handicapované uživatele',
    uri: Uri.parse('https://poslepu.cz/feed'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Výcvik vodicích psů',
    uri: Uri.parse('http://www.vycvikvodicichpsu.cz/feed'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Tyflokabinet Praha',
    uri: Uri.parse('http://tyflokabinet.cz/index.php/rss'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Portál Pélion',
    uri: Uri.parse('https://www.portal-pelion.cz/feed/'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Blindrevue',
    uri: Uri.parse('https://blindrevue.sk/feed/'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Technológie bez zraku',
    uri: Uri.parse('https://www.technologiebezzraku.sk/rss'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: BLINDička aneb Život prakticky nevidomé ženy',
    uri: Uri.parse('http://www.blindicka.com/feeds/posts/default'),
  ),
  NewsRssSource(
    name: 'Informace pro zrakově postižené: Blind Friendly Web',
    uri: Uri.parse('http://blindfriendly.cz/rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: 100 příběhů z protektorátu - Co všechno lidé slyšeli z rozhlasu v letech druhé světové války? Připomeneme si každodennost protektorátu i velké dějinné události',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0b522f32-2ec6-3700-b14d-c1f757fb8cec.rss?_ga=2.156637435.1392023315.1730991522-1991797136.1730991522'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Archiv Plus - Přibližujeme to nejzajímavější, co nabízí zvukový archiv Českého rozhlasu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/69ba5aa0-c837-3db0-ba91-f1b2051d0bb3.rss?_ga=2.176998117.1706107375.1730991447-163277161.1730991447'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Babské rady - Osvědčené tipy a návody (nejen) našich babiček',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3caf0f88-3b94-3216-8dad-28416e4d9d1f.rss?_ga=2.158416050.967841318.1730990909-1456959436.1730990909'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Dokument - Interpretace, výklad a syntéza dění, událostí a jevů našeho života',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b8c2564a-1dac-3230-8949-1aad7fd7688a.rss?_ga=2.67244561.1451062683.1730991178-407843373.1730991178'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Domy s duší - Co se asi skrývá pod fasádou a za zdmi různých, někdy na první pohled nenápadných domů? Kdyby tak domy mohly promluvit, to bychom se mnohdy asi divili',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/efc2578e-610a-375c-ad4e-3d8961520f03.rss?_ga=2.59148909.1942520702.1730991309-1756392222.1730991309'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Historie Plus - Věnujeme se osobnostem a dějinným událostem nejen z českého prostředí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6f1d6fd8-db19-3fc8-8cfc-4b8aed97ee53.rss?_ga=2.123096075.1008852781.1730991360-302362434.1730991360'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Jak to bylo doopravdy - Odhalujeme mýty, polopravdy, dezinformace či lži z naší historie',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b742d96b-a56e-364b-9522-65dae3cf5352.rss?_ga=2.208260498.1843022939.1730991575-1666348290.1730991575'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Jihočeská vlastivěda - Historické zajímavosti a perličky z různých míst Jihočeského kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/30f4aa0b-7dcc-3f8b-b532-37cea52c1831.rss?_ga=2.101987009.1775843806.1730991643-1991903857.1730991643'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Kalendárium - Přehled výročí a významných i méně významných událostí pro každý den',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/be5620eb-2da9-3929-8b77-b43ed46d48c9.rss?_ga=2.239108547.1163739178.1730991683-1188425922.1730991683'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Na návštěvě u Karla Čapka - Reportážní dokument z vily bratří Čapků. O Karlovi Čapkovi a jeho době',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6f4bac51-f1ee-3829-b45c-b82221296f6e.rss?_ga=2.162521148.1246230716.1730991726-1486950806.1730991726'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Návraty do minulosti - Vojta Kotek připomíná významné osobnosti, události, objevy, vynálezy, technické novinky a stavby, které se pojí s naší historií',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/693656ad-3a08-3d90-8373-a254cac70f67.rss?_ga=2.102430529.1137669922.1730991781-603244640.1730991781'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Němí svědci historie - Pátrejte s námi po příbězích památek našeho kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ee0fc0fe-fcef-3020-a4a8-1f6fc0361d50.rss?_ga=2.227656861.1443054149.1730991821-2054846853.1730991821'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Od Pradědu na Hanou - Rozhlasová pohlednice s osobitým pohledem na přírodu, zajímavosti i historii našeho kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4b6fd8e5-8eaf-38f7-90ca-b7a605f942ea.rss?_ga=2.43798821.1816348997.1730991907-1658659350.1730991907'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Po sametu - Od listopadu 1989 uplyne už 30 let. Radio Wave připravilo k výročí takzvané sametové revoluce dokumentárně-reportážní sérii Po sametu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1a256752-8c43-33e0-8e39-51d55ba07891.rss?_ga=2.18966270.712266382.1730991939-2065611681.1730991939'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Proměny měst - Rozhlasový seriál z produkce regionálních stanic Českého rozhlasu dokumentuje proměny krajských měst za posledních 100 let',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/cabf0b5d-4185-3ee9-9468-5170d8674592.rss?_ga=2.162806204.1033496689.1730992030-776159361.1730992030'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Přežít: Utoya a Oslo - dokumentární podcastová série Lukáše Houdka o těch, kterým do životů 22. července 2011 zasáhly teroristické útoky v centru Osla a na ostrově Utoya',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/36ca473d-1bf6-39bb-a9f0-871f2bd0f491.rss?_ga=2.844849.1008527642.1730992105-2092468631.1730992105'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Příběhy 1. světové války - Minisérie dokumentů mapující 12 lidských osudů ve válečných letech 1914–1918 tak, jak je zachytily dopisy nebo deníky. Připraveno ke 100. výročí první světové války',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f3a95c98-aa1a-3259-9573-867170edccf9.rss?_ga=2.218491801.1264722277.1730992247-1684477629.1730992247'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Příběhy 20. století - Vyprávíme příběhy, na které se zapomnělo, nebo se na ně mělo zapomenout',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d200d0b5-78d5-3cca-9052-834f13135225.rss?_ga=2.55594091.1745915419.1730992278-1670914055.1730992278'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Reflexe: Historie / Filozofie! - Moderovaný pořad s důrazem na analytický přístup, kauzy. Souvislosti české a evropské a světové kultury',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b1009168-42d3-363a-9333-40ede94e52d0.rss?_ga=2.220903006.759352964.1730992316-547634767.1730992316'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Rozhovory Radiožurnálu - Každý den se snažíme kontaktovat politiky, specialisty a odborníky z nejrůznějších profesí, abychom vám nabídli jejich názory a pohledy na nejaktuálnější témata',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/739a46c7-35e3-336e-a7d5-08a20b7e7677.rss?_ga=2.191995242.1591288174.1730992434-1400683696.1730992434'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Technické památky a zajímavosti - Vydejte se s námi za technickými památkami a zajímavostmi v Olomouckém kraji',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a2aee981-12d4-34e4-a6fa-a45ae1bcbf25.rss?_ga=2.52764897.890574353.1730992475-1294941446.1730992475'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Téma Plus - Zajímavé události i osobnosti pohledem odborníků i dobových dokumentů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7764b133-76d8-38d5-983e-4dd80f1dbd04.rss?_ga=2.66688359.859042557.1730992514-2134270286.1730992514'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Toulky po Brdech - Redaktorka Kateřina Dobrovolná vás zavede na více i méně známá místa této chráněné krajinné oblasti a jejího okolí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c504c254-495f-3d7d-b9ec-8ee073a62549.rss?_ga=2.94984156.1599617161.1730992563-274594400.1730992563'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Vltavín - Co možná nevíte o kraji, kde jsme doma',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/37aac4cd-dbe6-37e3-82ba-9dfdfcd85151.rss?_ga=2.127739977.510129869.1730992658-347374456.1730992658'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Východočeské výlety - Navštěvujeme známá i zapomenutá místa východních Čech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/88b4f59e-c79b-3603-8175-78c2bfae0623.rss?_ga=2.160043582.2039277136.1730992673-2095472812.1730992673'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Vykopávky - V neobyčejném podcastu o historii obyčejných věcí rozplete historik Martin Franc dějiny řízku, party či nudy a komička Lucie Macháčková přispěchá s alternativním výkladem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0557e212-af95-3338-bcb6-e873e06ac57c.rss?_ga=2.180123558.305736026.1730992714-467012918.1730992714'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Vzduch je naše moře aneb 100 let českého a slovenského letectví - Seznamte se s historií od dob středověku až po rok 2018 v šesnáctidílném dokudramatickém seriálu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ac64156a-34f3-3e60-a6a5-ca491e1fe983.rss?_ga=2.262413257.433700203.1730992745-1305050236.1730992745'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Historie: Z rozhleden s rozhledem - Říká se, že nejkrásnější pohled na svět je ten z koňského hřbetu. Z rozhledny se nám ale naskýtá ještě docela jiný pohled',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e30d5f0e-ce5d-389a-8002-0a7bae1c0695.rss?_ga=2.56918186.1482070569.1730992808-973525425.1730992808'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Štěstí ASAP - Šestidílný podcastový seriál o tom, jak za každou cenu vydělat na depkách. Tomáš, Patrik a Andula chtějí dobýt svět s jejich AI aplikací pro duševní zdraví. Zvládnou to?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e93f7d19-af43-3c77-bfb9-2c74442c79f7.rss?_ga=2.154816497.832970752.1730993189-1750522059.1730993189'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Čtenářský deník - Knihy, které musíte znát, ale nemusíte číst. Poslechněte si klasická díla české literatury online',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6737157f-fd15-3c3c-bc45-cf11d0481d52.rss?_ga=2.253784973.467473979.1730993317-230338546.1730993317'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Hororové povídky - Edgar Allan Poe, Howard Phillips Lovecraft nebo Ladislav Klíma. Zapomeňte na klidný spánek, hororové povídky na Vltavě nabízí vrcholné světové i české texty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3d3a20e0-5129-3d41-a5a5-e3f55c6feef9.rss?_ga=2.252344193.961518777.1730993352-1467671014.1730993352'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Když vypráví nápověda - Spisovatelka, publicistka a nápověda pražského Činoherního klubu, Irena Fuchsová, čte své povídky a fejetony ze života a o životě',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9dbc9336-43ef-3a69-b94b-c314e915ec63.rss?_ga=2.17212665.1768570663.1730993391-284394301.1730993391'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Máme jasno - Hraný komediální podcast o světech v bublinách aneb V cizí bublině jsi vždycky za ufona. Na poli přistálo UFO',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/94dfcbfb-0aff-361f-b7c9-7e532bfd0863.rss?_ga=2.71159248.1944408232.1730993435-1423437065.1730993435'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Neklid - podcastový seriál o vztahu, který zašel příliš daleko. O podivných zvucích, které nejdou dostat z hlavy. A o noci, co všechno změní',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5bddb87a-d1e5-31ce-93e2-c04fc0e4e7cb.rss?_ga=2.241516288.345631861.1730993479-367209509.1730993479'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Odcizení - Pětidílný podcastový psychothriller o tom, když vám ukradnou celý život.  V hlavních rolích Josef Trojan, Petr Uhlík a Martina Jindrová. Režie Natália Deáková',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ba25d347-13ab-334c-9c2d-019ccb988b5e.rss?_ga=2.175642279.445856351.1730993532-1812658489.1730993532'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Povídky Báječného léta - Unikátní povídkový podcast Českého rozhlasu Dvojky. Oddychové příběhy od předních českých autorů na téma lásky, přátelství nebo partnerství',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d029199d-a6bf-3fdf-abee-4d31204a50f6.rss?_ga=2.230038684.129046918.1730993589-670430212.1730993589'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Rituál - Čas letošního rituálu se blíží a všichni začínají mít strach. Jedno je jisté. Někdo musí být potrestaný... Radio Wave uvádí podcastový thriller o vině, bolesti a svědomí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d7db90ea-0813-3410-a316-5b8135125f38.rss?_ga=2.219440785.920998484.1730993633-2123580612.1730993633'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Rozchod - šestidílný podcastový seriál o vztahu Denisy a Honzy a jejich pátrání, proč jim to nevyšlo a kde udělali chybu. V hlavních rolích Denisa Barešová a Jan Nedbal',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/994a2d12-8c37-3435-836e-0c850c884e5c.rss?_ga=2.208895249.201153054.1730993656-1518216224.1730993656'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Strašidelné povídky - Unikátní kolekce děsivých povídek od předních českých autorů! Český rozhlas Dvojka přináší příběhy inspirované tajemnými místy České republiky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6b31ee39-aca4-3c72-b91d-afca9517c427.rss?_ga=2.155643059.928608095.1730993707-918347233.1730993707'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hry a četba: Šikana - Hraná podcastová série se Zdeňkem Piškulou, Davidem Krausem a dalšími herci podává pomocnou ruku všem, kterým TO přerostlo přes hlavu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d276000c-908c-3af2-ae70-d9428b432814.rss?_ga=2.149331510.1894502298.1730993757-77119738.1730993757'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Brněnská jedenáctka - To hlavní z Brna a okolí do 11 minut',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/10d77591-c565-3800-8087-6c75542ffe11.rss?_ga=2.238448198.796680008.1730994488-596451514.1730994488'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Bruselské chlebíčky - S nadhledem každý týden rozebírají aktuální dění v Evropské unii a přehledně servírují ty nejdůležitější události i zajímavosti ze zákulisí evropské politiky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/63d91d32-e7cc-3e12-beb1-5378c4945ccb.rss?_ga=2.250604486.1300740087.1730994587-2093672647.1730994587'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Destinace Brusel - podcast o tom, jak blízko má GenZ k Evropské unii. Podcastem provází tým mladých redaktorek a redaktorů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/306aa0d7-12c9-356c-ad32-fee341bc1257.rss?_ga=2.2252601.881523186.1730994651-1501667808.1730994651'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Hlavní zprávy - rozhovory a komentáře - Komentáře, analýzy, rozhovory. Publicistický souhrn nejdůležitějších kauz dne',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1a8454bd-0751-39ff-b5e6-4bd8cd89c672.rss?_ga=2.261681550.2075290362.1730994703-1601567991.1730994703'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Narovinu - Probíráme aktuální zpravodajská a publicistická témata více do hloubky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4088fc71-02d6-3d14-bf43-cad9a37a4e73.rss?_ga=2.203923666.350681493.1730994743-160359022.1730994743'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: O čem se mluví pod Ještědem - Co hýbe Libereckým krajem? Jak dopadají rozhodnutí vlády na život v našem kraji? O čem a proč rozhodli zastupitelé? Odpovědi hledá diskuzní pořad Českého rozhlasu Liberec',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4fb51988-de01-3c99-b867-0fe2f6f849f5.rss?_ga=2.50069230.91179692.1730994799-562353355.1730994799'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: O čem se mluví v Olomouckém kraji - Zpravodajsko-publicistická diskuse na téma, které hýbe regionem. O tom bude každou středu odpoledne rubrika s názvem O čem se mluví',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/af51990f-f501-3492-b9d4-fd3f9d4da790.rss?_ga=2.183716132.322931310.1730994826-1081838449.1730994826'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Reportáže zahraničních zpravodajů - Reportáže zahraničních zpravodajů, to jsou světové události v souvislostech tak, jak je jinde neuslyšíte',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4eca4e4f-8aa7-3326-824e-05da13ace752.rss?_ga=2.190979178.1591859609.1730994880-1837631521.1730994880'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Svět ve 20 minutách - Na serverech celého světa hledáme témata, která unikají českému tisku',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a2f4ac01-eb95-3dc5-8c41-7b254a161bf3.rss?_ga=2.127762829.1204699567.1730994930-1560218071.1730994930'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Týden Plus - Editorský výběr zásadních a zajímavých událostí uplynulého týdne z domova i ze světa bez tematického omezení',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9bc556c8-1aab-3d2f-8810-eec38be3fb37.rss?_ga=2.200044968.707501078.1730994963-1529106900.1730994963'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy ČRo Střední Čechy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b2810c39-d658-3918-bb56-d33a4c4bd607.rss?_ga=2.182019815.1305960626.1730995002-544132876.1730995002'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy ČRo Olomouc',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4a3d891d-7a28-3809-ab5e-12995713cd6d.rss?_ga=2.38502314.883789955.1730995100-1226157748.1730995100'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy ČRo Ostrava',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/015f9358-4969-37a9-b8e9-48fc90b0be2f.rss?_ga=2.104210247.631242348.1730995148-1996116659.1730995148'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy pro Královéhradecký kraj',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/070993c4-1e9d-3fec-93ee-c7d61d289b67.rss?_ga=2.260917837.1326826009.1730995179-676891743.1730995179'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy pro Liberecký kraj',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/951343b3-7de8-3afd-acee-1a4e8ea632ea.rss?_ga=2.171298403.2122939513.1730995216-29104288.1730995216'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy pro Pardubický kraj',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/11dabec4-ba79-3767-a997-574b007fdfe2.rss?_ga=2.177599013.1816998333.1730995270-1235817070.1730995270'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy pro Plzeňský kraj',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ff289597-8782-3cc9-a495-f0bd79ea59a2.rss?_ga=2.44902500.1926376791.1730995297-470910313.1730995297'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy z jižních Čech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3af5f1c1-6c47-35cd-b3fd-0a1de596f23c.rss?_ga=2.29460415.1805697737.1730995329-340185779.1730995329'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy z Vysočiny',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/027eaf9d-c14d-3afb-90e5-8d16b1b4e2c7.rss?_ga=2.166842110.136387405.1730995360-1594741764.1730995360'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy ze Severu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a95fbe36-1878-36b8-a2c9-d5dd317b6a51.rss?_ga=2.73162064.257964176.1730995393-615824181.1730995393'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zprávy: Zprávy ze Zlínského kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/dfc4d8cd-3dee-3fa5-93b2-4c81ef1c0c61.rss?_ga=2.53283054.758347860.1730995478-55381835.1730995478'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Čistá hra Martina Procházky - Nejen o hokeji se svým hostem mluví bývalý hokejista, olympijský vítěz z Nagana a čtyřnásobný mistr světa Martin Procházka',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3c96cfb9-3c19-3e34-8224-89d760963321.rss?_ga=2.65915566.1482862738.1730996904-730757131.1730996904'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Desítka Pavla Horvátha - Každé pondělí od 11:06 uslyšíte ve vysílání Radiožurnálu Sport pětinásobného mistra české ligy Pavla Horvátha, který bude probírat aktuální dění v české nejvyšší soutěži',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0b91dc1a-621d-3815-9637-59a678b0a058.rss?_ga=2.257445707.1365683528.1730997086-809936999.1730997086'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Hokej speciál s HC Dynamo Pardubice - Zápasy, výsledky, analýzy, rozbory, pohled do zákulisí pardubického hokejového týmu.',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d1c14b5b-118a-34df-b0f2-86a6f9063343.rss?_ga=2.62068522.727526571.1730997136-1564666655.1730997136'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Host Radiožurnálu Sport - Dopolední rozhovory s hosty ze sportovního prostředí, které nikde jinde neuslyšíte',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ee9948d3-a358-3a22-b9d2-fba99b441e28.rss?_ga=2.190067433.335569166.1730997186-1320393820.1730997186'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Kilometry Jiřího Ježka - Každý čtvrtek od 13 hodin si ve studiu Radiožurnálu Sport bude povídat cyklista Jiří Ježek s našimi moderátory o aktuálním dění v běžeckém a cyklistickém světě',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b2b82381-216d-310e-aeef-d46cd919d15d.rss?_ga=2.185609131.302808770.1730997219-1297024813.1730997219'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Na place - S hosty hlavně ze sportovního prostředí si povídají čeští herci a nadšení sportovní fanoušci David Novotný, Ladislav Hampl a Pavel Nečas',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/db949397-410b-37aa-9e8f-0d41731058a9.rss?_ga=2.81463959.1229794405.1730997253-1963977791.1730997253'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Na síti s Andreou Hlaváčkovou - Svého hosta se ptá bývalá tenistka, stříbrná medailistka ve čtyřhře z LOH 2012 v Londýně a dvojnásobná grandslamová šampionka ve čtyřhře Andrea Sestini Hlaváčková',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/44e9d176-298d-36a4-abc3-3b405c9ae6fe.rss?_ga=2.238852160.1554418274.1730997281-1244412686.1730997281'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Odpolední interview - Rozhovory s osobnostmi známými i neznámými, které ale stojí za to poznat',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/df1584a6-625e-3b2f-aafc-708e1c5f4378.rss?_ga=2.162028604.123303324.1730997317-2138627413.1730997317'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Olympijský rok - Jak probíhá příprava na olympijské hry? Sportovní redaktoři od zimy sledují české sportovce, kteří budou v Paříži usilovat o medaile',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/aba1a33f-8706-3559-a222-52754426147c.rss?_ga=2.229681628.15856644.1730997345-1873601522.1730997345'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Olympijský souhrn - Nejčerstvější výsledky z olympijských sportovišť přímo z Paříže od reportérů Radiožurnálu v živých vstupech hned po zprávách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b2ee4ab0-c61b-3e07-bc42-804fbb7c34be.rss?_ga=2.78358484.1929592827.1730997367-1809578471.1730997367'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Osobák - Rozhlasová série Osobák představuje moderátora Martina Minhu v roli hobby sportovce, který pod dohledem těch největších profesionálů absolvuje na vlastní kůži tréninky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/fd8ea0e6-0127-36b3-910a-198f76c6d969.rss?_ga=2.74264407.418872547.1730997398-473841225.1730997398'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Páteční finiš Kateřiny Neumannové - Svého hosta zpovídá bývalá běžkyně na lyžích, olympijská vítězka ze ZOH v Turíně 2006, šestinásobná olympijská medailistka a dvojnásobná mistryně světa Kateřina Neumannová',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d3d235b3-6493-3c5d-ba56-6dfcf3440116.rss?_ga=2.187591464.1822176865.1730997422-1645491807.1730997422'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: První dotek Zdeňka Folprechta - Co je aktuálního ve světě fotbalu na domácí i zahraniční scéně uslyšíte díky Zdeňkovi Folprechtovi každý čtvrtek od 10:06 na Radiožurnálu Sport',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/67f0e9a5-afc2-3424-a70c-5a279f45da85.rss?_ga=2.144692726.297238991.1730997451-374141053.1730997451'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Příběhy sportovců - Série Příběhy sportovců nabízí krátké audio zpracování životopisů sportovních legend. Poznejte s námi významné životní a sportovní situace, které ovlivnily slavné kariéry',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5f5e98d2-2e93-3bf5-8d0d-0295409a837f.rss?_ga=2.133722318.1977471266.1730997477-1156000252.1730997477'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Rozehra - Podcastová série o vztazích sportu, rozhlasu a politiky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a1d973e6-5ce8-3110-9543-ced41882dee6.rss?_ga=2.66930344.70618243.1730997504-336674160.1730997504'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: S mikrofonem do Anglie - Každé pondělí vám nabízíme to nejzajímavější z anglického fotbalu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b609e5d6-6a98-3ed4-92a2-1d357cf37938.rss?_ga=2.165807356.394562671.1730997538-1074729521.1730997538'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Seriál Radiožurnálu Sport - Pravidelné seriály z vysílání Radiožurnálu Sport. Zajímavá témata, reportáže ze sportovních akcí i ohlédnutí do historie sportu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f6a9725f-c066-37ea-9ddf-02f0987b2824.rss?_ga=2.208086423.420093341.1730997567-1385267771.1730997567'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Sportovní ozvěny - Ohlédnutí za sportovními událostmi uplynulého víkendu v jižních Čechách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/71b82cb1-5ea2-3ad7-8520-fb1dd0690960.rss?_ga=2.40997474.1735207926.1730997595-892144950.1730997595'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Stadiony - Podcastová série Stadiony s Martinem Minhou přináší unikátní příběhy fotbalových stadionů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2c496ec4-cc41-3306-8d4e-ce2aed7d2261.rss?_ga=2.164168575.1725264568.1730997621-1711054893.1730997621'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Sport: Vybrali jsme pro vás - Naši redaktoři pro Vás každý den chystají zajímavé reportáže, navštěvují zajímavá místa, sledují důležité kauzy a zpovídají zajímavé osobnosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a8a880bb-5f7c-399a-8327-31a6e87a783b.rss?_ga=2.207551379.1830873097.1730997645-185953770.1730997645'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Historie českého zločinu - Dobrodružství české kriminalistiky na pomezí rozhlasové hry a dokumentu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c9395a54-f2db-3013-8d5b-94bbc38617ce.rss?_ga=2.56865514.1193070180.1730455200-1723513904.1730455200'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Chyba systému - Politický podcast o české společnosti a jejích problémech v kontextu i v detailu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/47833fff-1845-3b97-b263-54fe2c4026b7.rss?_ga=2.86789400.140837800.1730455279-1700980668.1730455279'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Vinohradská 12 - Zpravodajský podcast Českého rozhlasu. Každý všední den jedno aktuální téma v souvislostech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ee6095c0-33ac-3526-b8bf-df233af38211.rss?_ga=2.130840075.523126977.1730455447-1062730589.1730455447'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Akce: Výbuch - Příběh o teroristickém činu, který ovlivnil tisíce životů a na dlouho změnil vztahy s Ruskem. Vydejte se s námi po stopách ruských agentů ve Vrběticích',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bfe863c2-1df3-3755-b983-518db84cf423.rss?_ga=2.95390037.892002036.1730455615-1852089562.1730455615'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Bezpečný průvodce džunglí zločinu - S policejními preventisty si na příkladu reálného zločinu řekneme, jak se nestát jeho obětí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ff2ea7a4-834a-3649-a194-bb074f77cacb.rss?_ga=2.202162898.254804079.1731002825-1086615381.1731002825'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Co vás zajímá - Kontaktní, živě vysílaný pořad, do kterého se mohou zapojit i posluchači',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/98367cb9-4c6c-38f4-9042-c0e93573a254.rss?_ga=2.210711573.1252172895.1731002868-1176301553.1731002868'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Dataři - Rozhovory s lidmi, kteří v Česku podporují otevřená data',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e20ec382-fadb-35e6-b4c8-a9fcf2c8a1c7.rss?_ga=2.74026450.1905845373.1731002919-464751143.1731002919'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Debaty Plusu - Jezdíme za vámi se zajímavými hosty. Debaty o globálních tématech i problémech, které trápí váš region',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6b258fa3-a78f-378e-b2da-c2119fdb7dcf.rss?_ga=2.72710739.1936026454.1731002948-542944410.1731002948'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Den na Moravě - Zpravodajsko-publicistický podvečerní souhrn Českého rozhlasu Brno. Rozšířené informace o počasí, aktuální dění na Moravě i informace integrovaného záchranného systému',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6574a673-9165-3de4-ac70-25f29c322fd9.rss?_ga=2.263436363.671781478.1731002977-323291793.1731002977'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Dnešní Plus - Výběr nejdůležitějších rozhovorů, analýz a specializovaných pořadů z našeho vysílání',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8f249298-019c-3428-a282-d130c98e1e4d.rss?_ga=2.31055487.1171858407.1731003131-893986014.1731003131'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Doba složitá - Dnešní svět očima filozofie. Alice Koubová a Tomáš Koblížek v debatách s Annou Beatou Háblovou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/acbc9ad3-f90b-35c7-aa64-355cd89cb047.rss?_ga=2.220182107.333850649.1731003160-724366666.1731003160'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Dobré dopoledne - Známé osobnosti, zdravý životní styl, móda, cestování, regionální informace, poradna',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2d92aee0-ea37-3236-bc5b-b716b7b97d0c.rss?_ga=2.115720646.1104597131.1731003191-1232886300.1731003191'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Dobré odpoledne z Českých Budějovic - Odpolední proud plný hudby a informací ze světa, domova a regionu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/550d90d6-98fd-351d-8398-2dc9eca7fd54.rss?_ga=2.123690571.1792905757.1731003220-1743460253.1731003220'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Dokuseriál - Příběhy, vyprávění, realita',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/39caeb55-50cf-37e0-8d7a-c47d8bd250fe.rss?_ga=2.7590458.963158029.1731003272-849461075.1731003272'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Dvacet minut Radiožurnálu - Autorský rozhovor jeden na jednoho s aktéry klíčových událostí veřejného dění',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5734245c-946d-3b10-9bfb-d295580f3752.rss?_ga=2.211066705.591521193.1731003313-130730507.1731003313'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Eseje o stavu světa - Jak opravit kapitalismus a co všechno nám ukázala pandemie? Odpovídá šest esejí napsaných pro The New York Times World Review',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/de05655c-72fa-3b6d-b090-ad4b054b5029.rss?_ga=2.111461700.1508979910.1731003361-1558923746.1731003361'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Expedice Z101 - Reportáže z putování Expedice Z101, která jede ve stopách legendárních cestovatelů Jiřího Hanzelky a Miroslava Zikmunda',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/52538d7a-c8b9-358d-aca6-b5f51364005a.rss?_ga=2.36781924.531848234.1731003439-1467545866.1731003439'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Fouskův svět - Zábavný a zároveň poučný pohled na dění kolem nás očima Josefa Fouska',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/35c18f7b-ef7c-39ae-86a5-4bb4b1a1953d.rss?_ga=2.107742914.1583325681.1731003470-1579236156.1731003470'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Glosa dne aneb Co týden dal - Publicista Václav Souček glosuje současné společenské dění',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/57f402c6-1862-32a1-8867-2c5e9c69bf43.rss?_ga=2.195893100.1714264411.1731003543-1704937330.1731003543'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Glosa Plus - Známé osobnosti glosují současné dění',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9f676637-9f2d-3199-bc88-fd7722ea5a79.rss?_ga=2.126008909.1191096849.1731003646-1573547809.1731003646'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Host Dne na Moravě - Setkání se zajímavými hosty, aktuální dění na jižní Moravě očima odborníků i aktérů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/131421a9-74cd-3954-b7d1-659f41d5d5dd.rss?_ga=2.19748348.517087591.1731003700-823103342.1731003700'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Host ve středu - Ve středu týdne, ve středu pozornosti. Aktuální témata i cenné rady odborníků poslouchejte každou středu po 11. hodině v rozhovoru Českého rozhlasu Vysočina',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3ae7dd35-698f-3a76-9255-b3010cf63039.rss?_ga=2.160380477.1894249387.1731003801-239774315.1731003801'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Host ve studiu - Od pondělí do pátku vysíláme v 8:35 zajímavé povídání s atraktivním hostem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/336c5c7a-8756-310b-8810-52fc5f1ee8fa.rss?_ga=2.196789164.1283800646.1731003833-1416283458.1731003833'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Houpačky - magazín pro aktivní rodiče, který každý týden nabízí diskuse o dětech, mateřství, otcovství, rodině a životním stylu s lékaři, psychology, poradci i...',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/367636b7-b3af-39c0-80be-dd0f5c3b16d8.rss?_ga=2.120118984.1713741156.1731003864-1997707867.1731003864'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Hovory - Rozhovor s osobností, která má zajímavý osobní i profesní život a názory. Hosty pořadu jsou respektované, ne nutně mediálně známé tváře všech oblastí společnosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/49ed63aa-a811-3386-8b95-f9e5da4e42f5.rss?_ga=2.181630567.1391550795.1731003911-1413585121.1731003911'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Hranice násilí - Hranice násilí je dokumentární podcastová série Táni Zabloudilové o cestách ven z toxických vztahů a podobách sexuálního násilí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/648461a8-6105-3d0f-8d35-1c0b2a302591.rss?_ga=2.15329269.2107163709.1731003945-1867761527.1731003945'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Interview Plus - Rozhovor s významnou osobností o tématech, která rezonují doma i ve světě',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1235fcbc-baa9-3656-9488-857fca2eb987.rss?_ga=2.30680185.794581439.1731003976-1189906129.1731003976'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Jak to vidí... - Aktuální názory a komentáře nezávislých osobností na dění kolem nás',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/40320ba0-7431-3f00-ab27-d5e6480106a8.rss?_ga=2.6258803.1740639145.1731004054-772625071.1731004054'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: K věci - Rozhovory s lidmi, kteří ovlivňují veřejný život ve středních Čechách a v Praze',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6c18ec35-1a93-3f97-b45c-962026a94979.rss?_ga=2.122921995.1809547197.1731004081-1637921940.1731004081'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: K věci ČRo Ostrava - Rozhovory o aktuálním dění v Moravskoslezském kraji. Hosty jsou lidé, kteří ovlivňují veřejný život v kraji',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9cf91344-3b83-3843-93e4-0c65040aa6b7.rss?_ga=2.178529892.1169957957.1731004108-200186263.1731004108'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: K věci Štěpánky Duchkové - Co se děje v Praze? Rozhovor Štěpánky Duchkové na aktuální pražské téma',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b8676ab0-e0dc-3a4e-8dc0-ef5bf8d1c348.rss?_ga=2.108526594.1490349204.1731004135-1072693388.1731004135'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Káva o čtvrté - Vaše každodenní inspirace. Životní styl, rodina, zdraví, finance nebo volný čas! Vaše zkušenosti, nové trendy i odborný pohled! Povídáme si o všem, co vás zajímá',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/af394066-3b14-36b0-911b-f8d84119fe0e.rss?_ga=2.249266254.814732279.1731004159-307693951.1731004159'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Kdo umí, ten umí - Ne nadarmo se říká, že Češi mají zlaté české ručičky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ee2d884f-3f1b-3706-9e1b-bac929ca43a8.rss?_ga=2.43082477.954418190.1731004184-1522481496.1731004184'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Kdyby zdi mohly vyprávět - Redaktor Tomáš Mařas provází po stavbách, které mají příběh. A může to být příběh samotné budovy, nebo jejích obyvatel',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f682eeb6-abf7-3a30-8080-714e5df4994e.rss?_ga=2.231277919.1767217960.1731004214-98644857.1731004214'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Kriminálka - Podcast Mirka Vaňury, který vás zavede až na místo činu. Odhaluje známé české detektivní případy po roce 1989 ve zbrusu novém pojetí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a55b623e-80ba-3b9c-9b6d-fd2a5e245276.rss?_ga=2.50138406.1046935992.1731004320-2095570881.1731004320'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Máme hosty - Od pondělí do soboty zveme do ranního vysílání zajímavé hosty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ffe8e3d5-2101-32bd-8aa4-2d49a937e778.rss?_ga=2.181164519.175836904.1731004488-1679741139.1731004488'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Matematika zločinu - Podcastový krimiseriál o tom, jak se v Česku počítá spravedlnost',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ec9f2990-93eb-3e9f-bb56-c42b6b4fd9bd.rss?_ga=2.59289509.944668637.1731004526-1552922909.1731004526'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Mozaika - Živě moderovaný proud kulturního zpravodajství a publicistiky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1b82f36f-9863-3b61-a388-bb9332cb629b.rss?_ga=2.96761567.1518208302.1731004559-1407316459.1731004559'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Můj kraj - Seriál o osobnostech západních Čech, které něco dokázaly',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2b66e65f-1c3c-3e7c-b562-2b834e264c0a.rss?_ga=2.242905538.1575105908.1731004591-1992196499.1731004591'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Na pohovce Jožky Kubáníka - Povídání Jožky Kubáníka se zajímavými hosty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9f0d4061-7f08-3ea8-a9e5-bce4fed61e0b.rss?_ga=2.167996449.1422078682.1731004622-1426218744.1731004622'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Na Východ! - Podcast Českého rozhlasu Plus zaměřený na postsovětský prostor',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9f4944e0-8ba6-39bd-a841-53544da13a8a.rss?_ga=2.13478897.716394750.1731004693-243045155.1731004693'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Náš host - Představuje témata a osobnosti, které často překračují hranice regionů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d3d88658-50c5-3714-be0b-8aaa1917432c.rss?_ga=2.154045181.434433431.1731004734-1892196988.1731004734'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Naše nej... - Víte, kde v Pardubickém kraji roste NEJmohutnější strom a kde mají NEJvyšší komín? Chcete se projít po NEJdelších hradbách?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/efa1d04a-9374-35be-8c00-0fd28044d910.rss?_ga=2.245953293.841490624.1731004806-297492371.1731004806'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Názory a argumenty - Každý den pohled pod povrch událostí doma i ve světě. Komentáře, analýzy. Informace, rozhovory a debaty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f4133d64-ccb2-30e7-a70f-23e9c54d8e76.rss?_ga=2.174689250.196945822.1731004852-1996004450.1731004852'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Nedělní káva - Každou neděli dopoledne pro vás máme krátkou glosu ke kávě a k zamyšlení',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e3255097-d2d8-3c60-ab07-67d7309dcf05.rss?_ga=2.82462742.1089121664.1731004884-1907202123.1731004884'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: NEJ hradecké články týdne - Které reportáže vzbudily na sociálních sítích za posledních sedm dní největší pozornost? Tady jsou pro vás sežazeny pěkně pohromadě. To nejlepší na našem webu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/952cc708-4ea0-3599-981f-86c8cd595c4a.rss?_ga=2.10346293.1458337640.1731004918-2004699404.1731004918'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Nespavci - Nespavci je autorská podcastová série Magdaleny Hejzlarové o nespavosti a jejích paradoxech. Sama s ní má letitou zkušenost',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/09db9b37-d0f4-368c-986a-d3439f741f08.rss?_ga=2.132793101.2069645260.1731004944-827326824.1731004944'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Neviditelní - Seriál o profesích a místech, o kterých se příliš nemluví a prakticky nejsou vidět. Přesto by náš svět bez nich fungoval jen velmi těžko',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f6d221af-6eb7-31cd-95b4-030a513e2fc4.rss?_ga=2.114349895.1353748756.1731004983-1027044047.1731004983'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: O původu příjmení - Pátrejte s námi po původu svého jména v rubrice Odpoledne s Dvojkou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d8bf5dce-0420-3030-b683-c5949bc290ad.rss?_ga=2.202028113.1771636608.1731005029-1448014200.1731005029'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Okolo češtiny - Rozhlasové fejetony o záludnostech, zajímavostech a netušených možnostech českého jazyka',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/14b30dba-69dd-3f4e-bcb1-2d5871e3678a.rss?_ga=2.115420943.862594097.1731005124-1145299198.1731005124'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Osudové ženy - Populárně-naučný seriál připomíná výjimečné ženy našich zemí v dobových souvislostech a kontextu jejich života nebo tvorby. Součástí každého pořadu jsou i dobové zvuky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e69d38d3-5b96-3692-8bd9-cf42fa93a2a8.rss?_ga=2.165413430.88856835.1731005224-456983908.1731005224'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Peníze a vliv - Zásadní témata ze světa financí, obchodu a průmyslu představují v podcastu Českého rozhlasu Plus analytička Jana Klímová a editor Antonin Viktora',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bd869dcf-b97c-36ca-99b9-766714040cec.rss?_ga=2.182898278.1724562869.1731005256-822388758.1731005256'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Plzeňské zajímavosti - Putování po Plzni a okolí a kam MHD dovolí. Zajímavosti z historie i současnosti Plzeňska vyhledává Soňa Vaicenbacherová',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/71c3f9e2-de02-3eb3-9441-dc5f2fe6e6e6.rss?_ga=2.243068864.35083082.1731005315-396163172.1731005315'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Portréty - Portréty osobností známých i méně známých. Kronika dvacátého století viděná skrz osobní příběhy politiků střední Evropy, ale i lidí politikou zasažených',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/08e46ce0-9dd9-3132-8609-a668e7bf97aa.rss?_ga=2.182443108.231011375.1731005366-1998423838.1731005366'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Poslední zpráva - Podcast Poslední zpráva hledá v rozhlasových archivech zprávy, které se z posledních míst postupně dostaly do centra našeho zájmu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9c55f24a-931e-39ea-b6a4-c06172b59de2.rss?_ga=2.96619615.1749875919.1731005389-477662564.1731005389'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Pro a proti - Diskuse se dvěma hosty, kteří hájí opačný názor. Široký záběr témat. Věda, náboženství, kultura či politika. Pro a proti je zdánlivě jednoduchá záležitost',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0bc5da25-f081-33b6-94a3-3181435cc0a0.rss?_ga=2.191008938.1839345057.1731005467-1317497346.1731005467'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Příběhy Radiožurnálu - Tím nejlepším, co naši reportéři natočili pro seriálové řady Radiožurnálu, vás v bonusovém podcastu provede Jiří Chum',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d390683e-b259-326f-9cac-92dd9be66d79.rss?_ga=2.173391334.471089659.1731005498-809781582.1731005498'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Přímá řeč - Aktuální témata, která se dotýkají života v Jihočeském kraji, v rozhovorech Českého rozhlasu České Budějovice',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0e86d354-2d57-3eda-8cab-60cc519d3cf1.rss?_ga=2.8895221.1598380377.1731005578-2144440439.1731005578'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Putování za vodou - Seriál Českého rozhlasu Olomouc o řekách, potocích, jezerech, přehradách či pramenech naší krajiny. Těšit se na něj můžete každou sobotu v 11:30 od 4. ledna 2025',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f718dec9-f1d5-3ca4-bb46-d0862b8e1bd4.rss?_ga=2.251387334.1371196886.1731005619-927238022.1731005619'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Reparát - Podcast o inovativní praxi a pozitivních změnách ve školství a vzdělávání',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/36d1f907-7f85-353f-8ace-87209fee4503.rss?_ga=2.81693783.1346150449.1731005666-1488803907.1731005666'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Rok ve válce - Unikátní svědectví o konfliktu na Ukrajině. Čtyřdílné vyprávění, na jehož počátku byly telefonické rozhovory Jana Pokorného a Martina Dorazína',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ae782b41-453a-3d51-a852-935749361d0b.rss?_ga=2.43020387.753479590.1731005732-29559677.1731005732'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Řečí peněz - Přední čeští ekonomové glosují aktuální nejen ekonomické události, které hýbou naší i světovou společností',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/63761799-2285-3e98-87ad-b8195caee670.rss?_ga=2.49707366.1534744871.1731005766-1196171764.1731005766'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Seriál týdne pod Ještědem - Každý týden chystáme seriál na zajímavé téma, které se váže k ročnímu období, významnému výročí, aktuální situaci, tradicím a svátkům nebo místům v Libereckém kraji',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a6bfd369-442d-3eaf-b909-249e24346051.rss?_ga=2.268711153.1631850034.1731005829-1595442812.1731005829'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Slast - Sexuální svoboda očima mladých žen. Podcast Lindy Bartošové o touze, intimitě a nezávislosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4707c2e2-bf08-3c7a-a853-53edd3947898.rss?_ga=2.103887424.1593033528.1731005902-1525088147.1731005902'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Slovo nad zlato - Tipy na správné slovní typy. Nebo na problematické (z)jevy našeho jazyka. S Janem Rosákem a Lucií Jílkovou, Michaelou Liškovou a Martinem Šemelíkem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c7249655-8bd0-31dd-92e5-1acf6fda89b5.rss?_ga=2.1210353.1559611187.1731005940-1801492492.1731005940'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Sousedé - Česko-německý magazín pro německou menšinu v Čechách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d0453c21-982f-3e99-b09e-cc1e0352aaf9.rss?_ga=2.42885347.734870648.1731005977-1791777752.1731005977'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Speciál - Speciální vysílání věnované aktuálnímu dění v politice, byznysu i společnosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7d68aa2f-0df3-3000-918a-8e470609bcb3.rss?_ga=2.210515669.1951498821.1731006008-1407809742.1731006008'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Speciál Radiožurnálu - Speciální vysílání k různým událostem. Komplexní pohled na aktuální témata, politické debaty i přenos přímo z místa dění',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/37830b29-65e6-36f9-8fdf-4869d32ce617.rss?_ga=2.81117139.517896610.1731006045-499102200.1731006045'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Stoupenci - Do nitra kutnohorské sekty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9a531e89-2181-3eb1-a7b3-7040aebd39d4.rss?_ga=2.265263887.169203605.1731006123-1234603825.1731006123'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Strašidelné pověsti Plzeňského kraje - Strašidelné pověsti a legendy Plzeňského kraje přináší každou středu v 11:35 Kateřina Dobrovolná. Zaposlouchejte se do vyprávění, při kterých mnohdy tuhne krev v žilách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5f65140d-75c0-3373-b841-f578c43b2ba4.rss?_ga=2.150624947.489174299.1731006212-951965194.1731006212'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Střepy - Ruská invaze na Ukrajinu očima českých spisovatelů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0697325d-1a7e-3081-bac5-ef251e1a0330.rss?_ga=2.229975839.2064822203.1731006279-1747405571.1731006279'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Stříbrný vítr - Empatie, hloubka, poutavost i dojetí… Jitka Novotná zpovídá zajímavé ženy a zajímavé muže',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/304ab051-d1f8-3a2b-924d-b2f4ca38e70c.rss?_ga=2.264493702.863120891.1731006316-2138747594.1731006316'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Svět ve 20 minutách - Na serverech celého světa hledáme témata, která unikají českému tisku',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a2f4ac01-eb95-3dc5-8c41-7b254a161bf3.rss?_ga=2.222226395.258435427.1731006343-1103393535.1731006343'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Šarm - Magazín o životním stylu. Chcete být fit, vědět co se nosí a poznat osobnosti?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1c1778d5-eabb-34ed-ba59-226ed5ea81e8.rss?_ga=2.126321674.662443945.1731006378-1336448932.1731006378'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Škola základ života - Seriál Škola základ života přináší každý čtvrtek v 11:20 Jiří Trnka. Zavítejte společně s námi do základních, středních i vysokých škol západních Čech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/43bd31de-abf9-3eb7-8e02-e6679dbaa0fb.rss?_ga=2.17225529.1836912579.1731006429-1575681337.1731006429'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Téma dne - půlhodinové ranní vysílaní věnované tomu nejvíce aktuálnímu dění v politice, byznysu i společnosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b17da067-0229-3cf6-bf77-80e36f230fc5.rss?_ga=2.264254223.1078887293.1731006513-530467688.1731006513'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Téma Plus - Zajímavé události i osobnosti pohledem odborníků i dobových dokumentů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7764b133-76d8-38d5-983e-4dd80f1dbd04.rss?_ga=2.18826289.968271682.1731006572-144142806.1731006572'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Urgent - Podcast Českého rozhlasu Plus o současné urgentní medicíně',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b5a89b7e-9c83-3c8a-9daf-e295eb062a52.rss?_ga=2.8756593.558470222.1731006616-2135082890.1731006616'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Urny - Do roku 2030 nás až na jednu výjimku každý rok čekají volby. Jak volby fungují a podle čeho se v nich rozhodovat?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ae375e64-0ee2-3b50-a584-5993051e77da.rss?_ga=2.172458787.1668238404.1731006673-1457261477.1731006673'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Vertikála - Diskuse s hosty z různých oborů, které spojuje duchovní vnímání světa',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/470b51cf-50a7-3692-8c0c-fdaf38266998.rss?_ga=2.218915417.1924390905.1731006717-495957855.1731006717'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Větrník - Host ve studiu - Hodinová talk show, do které si zveme výjimečné osobnosti ze všech oblastí života',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8614208a-9226-35a1-abd9-944edaa2c893.rss?_ga=2.55378798.490697839.1731006747-377022199.1731006747'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Vlna - Vlna je publicistický podcast Radia Wave zaměřený na témata z kultury, popkultury, společnosti a lifestylu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/fe3e900a-c547-3a5d-bd80-0e503cd5f851.rss?_ga=2.70091730.392265418.1731007001-179413883.1731007001'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Vltavín - Co možná nevíte o kraji, kde jsme doma',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/37aac4cd-dbe6-37e3-82ba-9dfdfcd85151.rss?_ga=2.149424310.1082361559.1731007043-2085898481.1731007043'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Za obzorem - Konflikty, politika i kultura – pečlivé analýzy z opomíjených koutů světa',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/04456eea-6ab4-3c86-b08f-03f35ff3186e.rss?_ga=2.190076651.15705676.1731007135-711296702.1731007135'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Záhady a tajemství Zlínského kraje - Poodhalte záhady a tajemství Zlínského kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e5c6aeb1-ad5f-35ea-b22a-674bf9a9c81c.rss?_ga=2.237865029.458469660.1731007193-2084730161.1731007193'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Zaostřeno - Reportérský pořad, který jde do hloubky problému. Zaostří na vše podstatné, co se děje kolem nás, v Evropě i ve světě',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/800b7eeb-3312-3902-a1ac-7e8c17ea07d2.rss?_ga=2.38430115.1605482077.1731007230-377704362.1731007230'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Zápisník zahraničních zpravodajů - Autentické reportáže z celého světa od našich zcestovalých zpravodajců',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/68a55594-5d72-3a50-a20a-d5e904d684c9.rss?_ga=2.249122631.1361747334.1731007298-146624289.1731007298'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Zlaté dno - Řemeslo má zlaté dno – rčení, které platilo kdysi a platí dodnes. S tradičními řemesly a zaniklými profesemi z karlovarského regionu vás podrobně seznámíme',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/16e4206c-8f37-34a8-9934-6931349f80b5.rss?_ga=2.52765544.1982585639.1731007329-1803570391.1731007329'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Publicistika: Život k nezaplacení - Rozhovor Jana Pokorného se sociologem Danielem Prokopem nejen o ekonomických výzvách pro domácnosti v roce, který ovlivnila pandemie a válka na Ukrajině',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e9c2642e-2062-3cd1-92eb-9c178c714f6c.rss?_ga=2.7746170.931918297.1731007358-1221544805.1731007358'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Nejisté sezóny - Od založení Divadla Járy Cimrmana v 60. letech si Zdeněk Svěrák píše deník, nebo spíše kroniku událostí. Poslouchejte každou říjnovou neděli na Radiožurnálu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/af4364f1-9997-3497-aa9e-209b8aadd6ac.rss?_ga=2.207503891.1822293569.1730455326-835907924.1730455326'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Akcent - Podcast, ve kterém si na jedno kulturní téma posvítíme z více úhlů pohledu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b7de83f6-24ea-3767-a77f-e411dff7ed2b.rss?_ga=2.1608817.1321633513.1731047467-1400631449.1731047467'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Anatomie lovesongu - Jsou písně o lásce ještě živý formát? Jak se v Česku zpívá o milostném citu? Anatomie lovesongu je šestidílná série Karla Veselého o současných českých písních o lásce',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/686081c2-c6ab-3e88-90f2-56d9dc1fd03a.rss?_ga=2.93178974.234209852.1731048892-305167289.1731048892'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: ArtCafé - Objevujte témata a osobnosti mimo hlavní kulturní proud',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/20ead869-6f23-3412-bbb4-341b48c230ad.rss?_ga=2.166674615.804665444.1731048948-6960183.1731048948'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Až na dřeň - O radostech i trápeních se známými osobnostmi. Moderuje Kateřina Kubalová',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/92f5d426-1f07-3642-99a2-4a5465e8337e.rss?_ga=2.5467059.1603299444.1731002589-1952148954.1731002589'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Blog létajícího redaktora - Sabina Vosecká vám přinese kulturní události z Prahy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4f4b5abe-d260-3578-85dc-7b80b7e64e89.rss?_ga=2.203864336.1472266385.1731048977-583479116.1731048977'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Cobain - Pětidílný podcast Pavla Klusáka těží z bohatého trsu příběhů a témat, které se vážou ke Kurtovi Cobainovi, jeho ženě Courtney Love a Nirvaně',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3c03d3ac-147a-315f-a78e-8ef2f47593cd.rss?_ga=2.110476485.1370108512.1731049074-518007771.1731049074'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Čelisti - 60 minut dravého filmového lovu: horké novinky z filmového oceánu, hlavní filmová událost týdne i drobný plankton aktuálního filmového dění',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/26d334c4-0df0-3eaa-8360-1e0bb633d20c.rss?_ga=2.184513187.443692399.1731049128-164370877.1731049128'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Člověčiny aneb Svět lidských fenoménů - Námluvy, manželství, tanec, zdobení těla, používání peněz, pojmenování dětí... To jsou fenomény, které sdílejí všichni lidé napříč místem a časem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/73151404-e13e-32b3-86c9-3f9cf99953e9.rss?_ga=2.68151697.184604696.1731049150-322409459.1731049150'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Dan Bárta: Nevinnosti světa - Dan Bárta jako zapisovatel a předčítač. To je vltavský podcast Nevinnosti světa',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1a9044a7-18a2-32fe-870a-32ec9bf33c74.rss?_ga=2.56159849.352514469.1731049181-489936078.1731049181'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Digitální spisovatel - Sérii povídek uvedenou pod názvem Digitální spisovatel napsala pro Český rozhlas umělá inteligence založená na systému GPT2 a GPT3',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0389a437-025f-3251-ad73-b60f2c7883cc.rss?_ga=2.155520379.1300012577.1731049210-1660202504.1731049210'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Doba složitá - Dnešní svět očima filozofie. Alice Koubová a Tomáš Koblížek v debatách s Annou Beatou Háblovou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/acbc9ad3-f90b-35c7-aa64-355cd89cb047.rss?_ga=2.56299755.1753331934.1731049242-476929725.1731049242'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Dokumoment - Čeští dokumentaristé ve speciálním krátkém formátu pro Mozaiku Českého rozhlasu Vltava. K čemu je inspiruje jedno téma? Jeden fenomén?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6da05abf-cd26-3574-b4a9-2fe67d5a39b5.rss?_ga=2.257184136.2071054623.1731049270-1577943610.1731049270'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Dřevo a cín - Poznejte šestici varhan v pěti chrámech geniálního architekta postavených na Vysočině',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/73cf42a2-d994-3e56-873b-96c100012708.rss?_ga=2.215023121.76529839.1731049299-727418481.1731049299'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Ex libris - Seznamte se s knihami, které doporučují známé osobnosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/cfcec499-8ae5-3338-8ea8-216d32e24da8.rss?_ga=2.45303332.188950342.1731003411-1900018178.1731003411'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Filmové premiéry Pavla Sladkého - Filmový kritik Radiožurnálu představuje nejnovější snímky, které vstupují do českých kin',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/aaeb0f7c-371f-3114-aef7-9e07bd92ab08.rss?_ga=2.188171432.1888355914.1731049332-1196345374.1731049332'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Hmota - Architektonické expedice s Adamem Štěchem. Vydejte se s ním poslouchat stavby, prostory, formy, hmotu…',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/408dcc06-a225-367d-88a6-01873ba10318.rss?_ga=2.142601202.1344500931.1731049374-1021951696.1731049374'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Kavárna - Kulturní magazín z jižních Čech. Rozhovory s umělci, o akcích a různých zajímavostech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/63e62588-8426-314b-9bdb-40f2e772a02b.rss?_ga=2.97394719.1068229095.1731049516-982989313.1731049516'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Knížky Plus - Pořad je určen všem milovníkům knih pro lepší orientaci na knižním trhu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/243c005d-277f-365d-a8e6-4f0f9fb7b13e.rss?_ga=2.134201612.384844738.1731004283-1060096525.1731004283'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Křížem krajem - Magazín dobrých zpráv a zajímavostí Moravskoslezského kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5a18f626-7e27-3ff9-8a06-30842420f01d.rss?_ga=2.191598818.95138172.1731049598-1263033522.1731049598'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Kultura na severu - Pozvánky do divadla, za muzikou, na výstavy. Rozhovory se známými i méně známými umělci. Četba z povídek regionálních autorů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c68cc340-0c80-3a91-97fd-9e7b8e6d6816.rss?_ga=2.191592170.1979549028.1731049622-1305286811.1731049622'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Kultura Plus - Přehled kulturních událostí týdne. Reportáže z premiér, rozhovory s autory. Ale i reflexe z akcí, o kterých byla v daném týdnu řeč',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5a56a2ae-399f-32d9-ac90-902f6d0b8d6a.rss?_ga=2.16270582.1741393841.1731004388-1846209775.1731004388'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Kulturní vývar -  Tým redakce kulturního zpravodajství Českého rozhlasu nabízí všehochuť - od divadla, filmu i hudby po literaturu a výtvarné umění',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/921a65ab-2d95-3031-81d4-e8dc241bee2b.rss?_ga=2.246108484.1175115541.1731049662-469667095.1731049662'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Lit - Lit je zapálený podcast o literatuře a knihách. Zveme si hosty a hostky, se kterými si povídáme o tom, co čteme a proč. Chceme vědět víc a taky sebe i vás inspirovat',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1bd918c9-42f7-3504-bde9-f1ac781a1145.rss?_ga=2.168748001.134888800.1731049723-1362490953.1731049723'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Momenty - Výběr silných momentů ze setkání s osobnostmi českého kulturního života přináší reflexi jejich tvůrčího života i zamyšlení nad obecnějšími tématy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/60c3a92e-0efe-315e-93c7-3d2e0a2c4996.rss?_ga=2.92516126.2069420326.1731049755-2109282398.1731049755'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Normy - název cyklu autorských podcastových dokumentárních sérií Radia Wave. Zpracovávají mnohdy provokativní a pro řadu lidí neobvyklá témata v životě mladých lidí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4caeec74-c62d-362f-8a40-891cd3b488b0.rss?_ga=2.137898608.1386275377.1731049830-589629087.1731049830'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: O knihách s knihovnicí - Rubrika pro všechny čtenáře a knihomily o tom, co stojí za to číst',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/12be961f-6af2-30dd-a69b-f5fcc31c7925.rss?_ga=2.196056106.70906839.1731049862-1025498565.1731049862'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Ranní úvaha - Malé zamyšlení a inspirace pro všední den v autorské interpretaci',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f64ff9d7-1938-3f5d-98d3-91c611387e2e.rss?_ga=2.230105884.1022486712.1731049891-1407405973.1731049891'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Reflexe: Divadlo! - Komplexní názor i zpráva o aktuálním dění na českých a světových jevištích. Divadelní festivaly i premiéry reflektují odborníci z celé České republiky i ze zahraničí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/89c693a5-eb85-3d23-b004-902b04b67db9.rss?_ga=2.203032977.1881203101.1731050022-780801606.1731050022'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Reflexe: Film! - Recenze filmů a klíčová témata současné kinematografie v diskusi. Reflexe filmového dění přinášejí Pavel Sladký a Šárka Gmiterková',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/96976e3a-c5af-3b04-8fc8-6ea180471172.rss?_ga=2.173807971.1933040062.1731050052-1925648150.1731050052'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Reflexe: Literatura! - Debaty kritiků, autorů i čtenářů o současné české a světové literatuře',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/846f702c-93a9-3f11-9404-a6173381a775.rss?_ga=2.264743821.306488973.1731050081-216310331.1731050081'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Reflexe: Vizuální umění! - Moderovaný pořad s důrazem na analytický přístup, kauzy. Souvislosti české a evropské a světové kultury',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/54bac38d-5160-3c08-b87f-4ad811704310.rss?_ga=2.217279381.2027568457.1731050111-16331941.1731050111'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Stopař - Anna a Pavel spolu někam jedou. Do jejich životů vstoupí stopař... 1 výchozí situace, 11 příběhů, 11 žánrů. Hrají David Novotný, Tereza Císařová, Ondřej Rychlý a další',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/134bf065-33b5-31d6-bea9-ec700eb70045.rss?_ga=2.19835064.1026253234.1731050147-1654262969.1731050147'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Universum - To nejaktuálnější nejen z akademické půdy a studentského života',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/547a006f-5988-3ee0-b297-23853e5a91ee.rss?_ga=2.155678908.683676452.1731050221-2075605614.1731050221'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: Vizitka - Seznamte se s lidmi, kteří žijí (s) kulturou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5ac28d1f-74cf-3a78-b463-69a19594771d.rss?_ga=2.257337483.1468070013.1731050256-863751607.1731050256'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Kultura: VýVar - Podcast o tom nejzajímavějším na filmové přehlídce v Karlových Varech. Dozvíte se, jaké filmy si letos nechat ujít, koho kde můžete potkat, kam určitě zajít a co vyzkoušet',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/01883023-cf70-3469-ba1b-0f4a3ba5a224.rss?_ga=2.74988626.1956739041.1731050282-977190804.1731050282'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Antivirus - Pořad o technologiích a bezpečnosti na internetu. Jan Cibulka a Jana Magdoňová se zaměří na nástrahy on-line světa',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d88f0d67-6ba1-3ba5-8fea-01e41a614037.rss?_ga=2.156523259.1974345200.1731053334-1393787620.1731053334'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Děrné štítky - Vše ze světa internetu, sociálních sítí, streamovacích služeb. O tom, jak technologická komunita okolo Silicon Valley proměňuje náš svět',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9f4da255-854b-381e-bb0e-9b317a66f9e5.rss?_ga=2.151714105.1833305880.1731053345-1970244156.1731053345'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Jihočeské nebe - O hvězdách, planetách a vesmíru, který nás obklopuje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ffb19f77-db3a-3c32-8ede-b569dafcb53a.rss?_ga=2.120517832.1354900354.1731053371-1343950005.1731053371'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Laboratoř - Vědci vysvětlují, herci glosují novinky o přírodě a lidech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ba94266d-b2b7-3763-b53b-d9016dbc7d2f.rss?_ga=2.6253744.242671689.1731053429-18500495.1731053429'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Leonardo Plus - Setkání s významnými českými vědci a odborníky, kteří umí zaujmout',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0870e932-21d6-3b7e-b20f-4c282beabfdf.rss?_ga=2.81501022.875937142.1731053452-957730506.1731053452'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Magazín Experiment - Vědecko-technologický magazín. Rozhovory s vědeckými špičkami a reportáže ze zákulisí vědy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/907bf24f-9bcf-3ea9-af9e-d98533093dad.rss?_ga=2.45346276.1165174079.1731053475-2140571269.1731053475'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Magazín Leonardo - Magazín aktuálních informací a zajímavostí z různých oblastí vědeckého světa',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3235570a-912e-3444-a141-da0479f427b8.rss?_ga=2.76408597.1084129528.1731053499-1492880025.1731053499'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Meteor - Vědecko-populární reportáže, rozhovory a dokumenty pro všechny. K poslechu živě na Dvojce, Pohodě, na webu a v aplikaci mujRozhlas.cz',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/163bae84-57f0-3670-95b3-41cf5e2000cd.rss?_ga=2.226658461.1643854154.1731053531-1517811273.1731053531'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: O češtině od A do Z - O mně i mě, s i z i y. Praktická škola naší mateřštiny s Michalem Jagelkou a jazykovým expertem Alexem Röhrichem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/530cbf06-2c14-3f06-ac50-853b41117157.rss?_ga=2.252603840.852479175.1731053567-1539150238.1731053567'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Online Plus - Co se děje ve světě nových médií, vysvětlují odborníci ze světa IT, fanoušci internetu a pionýři mobilních aplikací',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1e6ac29e-b39d-3d0d-8db2-ce1c74cf75b0.rss?_ga=2.132516238.1468427098.1731053610-18147703.1731053610'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Ping - O technologiích a novinkách v digitálním světě. Srozumitelně, zábavně, pro všechny. Podcast Českého rozhlasu Ping nabídne témata od popkultury až k novomediální filosofii',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/17f73f1c-482b-3b5c-98c5-3d9217c3bfec.rss?_ga=2.72573333.768302740.1731005283-532553094.1731005283'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Planetárium - Magazín o věcech mezi nebem a zemí pro přátele opravdové vědy i fantazie',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e94167fd-acd5-3d6a-aa10-4be65990913f.rss?_ga=2.181525920.663598958.1731053637-1422152343.1731053637'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Quest - dal si za cíl provést vás světem počítačových her tou nejhravější formou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9f19fbeb-a3d2-3cfb-b04e-3e0a253b639a.rss?_ga=2.135630772.488801683.1731053706-1816751478.1731053706'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Studio Leonardo - Rozhovor s osobnostmi ze světa vědy. (Pořad se již nevysílá)',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/19f76a1e-d426-3c07-a07b-1e777691f5e3.rss?_ga=2.7117879.406332655.1731053756-1097867809.1731053756'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Superhrdinka - Jaké to je, probudit se každý den s jinou superschopností? Podcast Superhrdinka přináší audiopříběhy i zajímavý online obsah. Objevte neuvěřitelný svět fyzikálních jevů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/53cec214-1476-33ea-808d-d143b3f47c0e.rss?_ga=2.20869629.413201949.1731053831-1736695254.1731053831'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Technické památky a zajímavosti - Vydejte se s námi za technickými památkami a zajímavostmi v Olomouckém kraji',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a2aee981-12d4-34e4-a6fa-a45ae1bcbf25.rss?_ga=2.69237333.41749161.1731053865-751797001.1731053865'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Techno - Magazín informací, zajímavostí a novinek z oblasti vědy, techniky a informatiky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/435ca4b9-4566-3166-af3b-2b68dd67813a.rss?_ga=2.47519716.27187552.1731053892-792056142.1731053892'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Věda Plus - Každý den přináší nové vzrušující vědecké objevy. Vydejte se s námi na průzkum všech světů Země. A ještě dál',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/51821ebc-ee7a-32f3-adec-aa539dc3d2f5.rss?_ga=2.34298209.1151695927.1731053926-722029308.1731053926'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Věda a technika: Vědecká dobrodružství - Volná série představuje české vědce ve světě. Ponořte se do tajů věd i techniky!',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b12801eb-d6b2-326f-a7ea-c9aafe4905b6.rss?_ga=2.123667592.2006677527.1731053977-1714193966.1731053977'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: PoZOOR! - Rozverné básničky o zvířátkách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0278d4d2-7024-30de-aace-38ec95bc6f9a.rss?_ga=2.216631958.186139150.1730455362-910901192.1730455362'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Bludičky - Bludičky jsou podcastová série Radia Wave o cestování po krajině za neznámými příběhy, v pohorkách a s batohem na zádech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/798ff682-227a-34e6-91f6-409fe9dead1d.rss?_ga=2.39884577.2035764833.1731054153-739122855.1731054153'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Borci - Seriál s užitečnými radami, jak přežít v divočině',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2c6345d7-cb54-3199-8121-10ea98d91edf.rss?_ga=2.81819734.1797757083.1731054270-1742884265.1731054270'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Brdění - Podcast o bláznivé jízdě do Brd za Brďany s užvaněnou Šárkou a svérázným Matoušem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e27d523b-4e03-316e-9dbb-1fbf6c117ecc.rss?_ga=2.15521590.1652994683.1731054299-448531046.1731054299'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Casablanca - magazín o cestování, exotice, poznávání, outdoorových sportech a dobrodružství',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/dd89af6e-47c9-32e1-b112-2a317c0b904a.rss?_ga=2.239890304.264795183.1731054324-1691820661.1731054324'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Máme rádi zvířata - Magazín o zvířatech, domácích mazlíčcích a zajímavostech z živočišné říše',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bd559e11-47e6-320d-a2f4-92d53060eba8.rss?_ga=2.10478069.156036241.1731054385-1876808027.1731054385'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Podhoubí - magazín o přírodě, životním prostředí a všech cestách k šetrnému životu. Přinášíme v něm rozhovory s odborníky, ochranáři, zemědělci i dalšími',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d30e470a-a07f-389f-9761-1543d9e560fe.rss?_ga=2.196254372.967704830.1731054418-1205397676.1731054418'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Pojďte s námi do zoo - Každý týden vás vezmeme do Zoologické zahrady v Jihlavě a díky našim skvělým průvodcům se dozvíte o jednotlivých zvířatech nečekané zajímavosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/47ae1690-2479-3632-bc6d-2be0580b85e1.rss?_ga=2.255187144.1952104719.1731054458-1654086734.1731054458'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Putování za vodou - Seriál Českého rozhlasu Olomouc o řekách, potocích, jezerech, přehradách či pramenech naší krajiny. Těšit se na něj můžete každou sobotu v 11:30 od 4. ledna 2025',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f718dec9-f1d5-3ca4-bb46-d0862b8e1bd4.rss?_ga=2.207856592.374145296.1731054484-1288366448.1731054484'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Safari - Aneb ZOO jako na dlani! Nedělní odpolední reportáž ze zoologické zahrady',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5695db40-46b5-3eaf-baf9-e2bfbe92962b.rss?_ga=2.248697285.31939198.1731054521-1699659338.1731054521'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Udrž to! 7 výzev pro planetu - Projektem Udrž to! Sedm dní pro planetu se Český rozhlas připojuje k týdnu udržitelného rozvoje. Moderátory tří generací staví před výzvu, jak změnit své každodenní návyky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1de9abe8-b086-3f11-8a35-71ef7cad3de6.rss?_ga=2.100505757.2032653221.1731054551-1137568208.1731054551'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Výlety - Průvodce po nejzajímavějších místech Čech, Moravy a Slezska',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c276b22a-06b4-396b-8ab4-e16fc6fa4991.rss?_ga=2.7454322.1559546021.1731054587-674790487.1731054587'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Příroda: Svět zvířat - Žádné zvíře není tak malé, aby nám nemohlo být největším přítelem a žádné není tak velké, aby se nevešlo do našeho srdce',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4d8adf3a-4b74-3ceb-a559-991b20eccae0.rss?_ga=2.186375657.1555910940.1731058123-1972711891.1731058123'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Anatomie lovesongu - Jsou písně o lásce ještě živý formát? Jak se v Česku zpívá o milostném citu? Anatomie lovesongu je šestidílná série Karla Veselého o současných českých písních o lásce',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/686081c2-c6ab-3e88-90f2-56d9dc1fd03a.rss?_ga=2.18457073.936609485.1731055027-645600230.1731055027'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Brrrap - Rapová série Brrrap je podcast, který se zajímá o to, co se honí rapperům v hlavě, když nedrží mikrofon v ruce. Za jaké kariérní rozhodnutí by si rappeři nafackovali?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ba58fd0f-d214-325a-93d8-94f5dea27523.rss?_ga=2.137283064.978424665.1731055097-400527619.1731055097'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Czeching - Czeching je hudebně exportní projekt, jehož prostřednictvím stanice Českého rozhlasu Radio Wave podporuje progresivní kapely v jejich snaze prorazit na zahraniční pódia',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/16f5b8e8-8b6e-3ab8-85d1-0617f54ad177.rss?_ga=2.230641439.248241564.1731055131-415637898.1731055131'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Deska týdne - Každý týden vám zevrubně představujeme nejzajímavější desky, které v poslední době vycházejí a zaslouží si větší pozornost',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8c92d037-169b-3707-a08d-e9e662564487.rss?_ga=2.244394499.764274510.1731055162-342659447.1731055162'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Host Lenky Vahalové - Každý týden hodinový rozhovor s osobností',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/847611df-254b-3e42-8b49-660c03c7ae92.rss?_ga=2.41104674.107539120.1731055182-1200053.1731055182'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Jazz do kapsy - Matěj Belko přináší porci zaručených jazzových rad pro vaše ucho',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1779a87a-3d64-3874-8dbd-721122d588c9.rss?_ga=2.206051987.1694085331.1731049487-1731991567.1731049487'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Klasika zvenčí a zevnitř - Lukáš Hurník a Filharmonie Hradec Králové berou jednu slavnou skladbu po druhé, upozorní na nejzajímavější místa a pak ji zahrají vcelku',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/be059c10-6878-33d2-96f1-c938b0205073.rss?_ga=2.149777270.1506562668.1731055216-189161573.1731055216'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Láska za lásku - Cyklus vyprávění, příběhů, rozjímání a hudby českého malíře Jiřího Anderleho. Za asistence milovaného nevyzpytatelného papouška Žandy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bed93d83-1f1e-39a0-8024-3aefad0a8ba8.rss?_ga=2.185048299.317254894.1731055349-1121450502.1731055349'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Špína - Judita Císařová, Honza Šamánek a Petr Wagner každý čtvrtek provádí posluchače sklepeními lokální i zahraniční DIY scény',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/da745fb0-1ebb-314e-ac27-f85fe3d70d41.rss?_ga=2.142628405.183346508.1731055380-1255712564.1731055380'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Taktovka - Aktuální dění a nové nahrávky Symfonického orchestru Českého rozhlasu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7ec2dedd-4260-3218-93b1-83ebd8afe34e.rss?_ga=2.231747869.363627108.1731050194-747030950.1731050194'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Velký čísla - Vydejte se na vrcholy žebříčků s Radiem Wave. Čerstvý hudební pořad, ve kterém se počítadla světových i tuzemských hitparád nepřestávají točit',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e5939279-2906-3f98-a218-953a932e4c25.rss?_ga=2.107408258.1080763996.1731055404-922082871.1731055404'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Hudba: Východiska - Rubrika Východiska nadväzuje na vysielanie rubriky Kumšt a taktiež čerpá z projektu Easterndaze o novej hudbe vznikajúcej v regióne strednej a východnej Európy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/339fff34-6439-3bdf-96dd-834f926ba2ca.rss?_ga=2.158250111.415864681.1731055462-1051103512.1731055462'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Abeceda potravin - Přední gastromanažer a kuchař Karel Šimůnek poodkrývá známá i neznámá fakta o potravinách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6dfaa292-7a70-372c-bbba-83ff86ef9635.rss?_ga=2.94511068.1717898494.1730455577-441620786.1730455577'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Babiččiny recepty s Vladimírou Jakouběovou - Uvařte si staročeská jídla s Vladimírou Jakouběovou, regionální sběratelkou starých receptů. Inspirujte se',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ce561240-f82d-31ab-b738-73e9ea3d3eac.rss?_ga=2.146885301.324533023.1731055993-1067814754.1731055993'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Balanc - magazín o seberozvoji, prospěšném životním stylu a důležitosti dobrých mezilidských vztahů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/877020d3-adf7-346f-8303-a281aebbc3a8.rss?_ga=2.71582032.218959709.1731056030-533175349.1731056030'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Bourání - pořad o architektuře, urbanismu a designu. A o tom, jak nám zlepšují nebo zhoršují život',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d38fa311-2c45-39ab-9dac-f51d31edaf04.rss?_ga=2.162623356.1181044530.1731056108-798861962.1731056108'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Cestovatel - Jedno léto, devět zemí a tisíce zážitků. Prostřednictvím rozhlasových vln se s námi vydáte do zemí, kam Češi rádi jezdí na letní dovolenou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8ee3d924-5f35-3ab6-917a-857b93e90416.rss?_ga=2.16703282.569695602.1731056146-1428459532.1731056146'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Dámská jízda - Magazín pro moderní ženy o životním stylu, kariéře a péči o tělo i ducha',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3b1aebef-eca7-3694-a290-4bae22559bd5.rss?_ga=2.5073651.1504025065.1731056214-701875682.1731056214'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Doktorská rada - Užitečné rady, které se týkají vašeho zdraví, nabízí každou středu MUDr. Irena Kudrnovská. Pořad připravuje Markéta Vejvodová',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3406a0cc-13f3-3b9c-9286-00cd600af6c1.rss?_ga=2.114724674.470636100.1731056272-2101570673.1731056272'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Domácí štěstí Ivy Hüttnerové - Rady do domu i do života',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/98cb568d-4d8c-3456-ab33-290f81ef31cf.rss?_ga=2.219056857.1702307109.1730991232-196887231.1730991232'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Ektoplasma - Z vnějšího vesmíru až na Dno pytle a zase zpátky vás vezme pětiminutová seance věnovaná sci-fi, fantasy a hororu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/09a9887f-2774-3676-a47d-b5cfaf555982.rss?_ga=2.138917619.1394910546.1731056295-1770487886.1731056295'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Hobby magazín - Pořad pro všechny, kteří se neradi nudí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e59814ac-f4b0-3f19-b120-f57474ba24d7.rss?_ga=2.227298781.1704630628.1731056396-198469799.1731056396'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Hobby magazín speciál - Rady, tipy a nápady z různých oblastí hobby',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e00cfc5d-9e0f-3b17-90f5-6a29607c69cb.rss?_ga=2.198151722.426828670.1731056448-642763699.1731056448'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Host Dopoledne pod Ještědem - Každé všední dopoledne po 11. hodině si do studia zveme zajímavé hosty a povídáme si s nimi o různých tématech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b645db4d-fe9e-3b1f-92da-5e25a7bcd8b0.rss?_ga=2.196949615.2136417067.1731056532-1327885851.1731056532'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Host Dopoledního expresu - Každý všední den jsou u nás ve studiu zajímaví hosté. Přinášíme finanční, energetické, zdravotní či sociální poradenství. Stačí si vybrat téma, které vás zajímá',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/96068576-1cdc-3495-8943-4bb345ed9598.rss?_ga=2.133595854.1946210099.1731056581-1245203488.1731056581'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Hubněte zdravě s Kateřinou Cajthamlovou - Odbornice na hubnutí Kateřina Cajthamlová vám pomáhá shodit přebytečná kila',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/b8567439-afe3-35f8-b4ac-bc4f7b6bade8.rss?_ga=2.247328716.976373605.1731056641-733046638.1731056641'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Jezte, ať vám to sluší - O zdravém vztahu k jídlu a vyváženém stravování. Přinášíme zajímavé informace, inspiraci, nápady a praktické tipy, jak jíst vyváženě a cítit se dobře ve svém těle',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5a803429-9c0a-3ecc-89e9-b6ac26d13977.rss?_ga=2.78434516.1518355200.1731056678-70481007.1731056678'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Jihočeské kroniky - Setkání Petra Kroniky s kronikářkami a kronikáři vesnic a měst našeho kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8f6f6fc6-6488-3bca-bfc4-c57444b9e5ea.rss?_ga=2.98714780.362341204.1731056706-297872496.1731056706'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Jiné stavy - vzniká jako doprovodná série magazínu pro rodiče Houpačky. Zajímá se o porod a všechny jeho odstíny',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/545b9cbb-b74b-3b84-bf3b-494fe21f64a8.rss?_ga=2.265598671.1932617095.1731056731-1351109362.1731056731'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Kuchařské čarování - Pravidelná porce inspirace a receptů pro všední i sváteční vaření',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2b1063a3-9bf0-38da-991e-bb3168f4ea6c.rss?_ga=2.254943816.1789349717.1731056790-48645103.1731056790'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Lásky čas - Podcast pro lepší randění v Česku. O příjemných i rozpačitých momentech při hledání lásky a navazování vztahů napříč etniky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/aaeaa9e5-4a9f-31e6-b95a-fd6909c96e2c.rss?_ga=2.112121538.713836667.1731004450-1559430863.1731004450'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Lékárna - Magazín o zdraví a zdravém životním stylu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/47301f3d-a21a-395d-bf1c-f1e5a1d27225.rss?_ga=2.69664210.311213530.1731056826-1667576037.1731056826'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Makám z domu - Spasí home office naše životy? Pandemie koronaviru na jaře poslala obří množství lidí na home office. Co se dlouho jevilo jako vize budoucnosti, se rychle stalo realitou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c645aa4a-f480-3ef4-909d-1e6b1e143ebe.rss?_ga=2.181078119.1149541740.1731056895-996040771.1731056895'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Minuta pro zdraví - Rubrika Českého rozhlasu Vysočina o prevenci, kterou můžete předejít zdravotním problémům',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/095fa9b0-48e8-35de-b4cb-32000bec0eb9.rss?_ga=2.194059183.361948164.1731056939-592318034.1731056939'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Mizení - Praha – Holešovice, ulice Komunardů. Před bezpečnostní kamerou zdejší banky se naposledy mihnul ten kluk. Zjistí se, kam zmizel Mostbeautifulboy?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/18f4b14e-8e07-3eee-9bb8-ca2a6387d3e8.rss?_ga=2.163650231.989264985.1731056964-499046259.1731056964'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Moci bez nemoci - O zdravotních diagnózách a nových metodách léčby se Šárkou Volemanovou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/224eb099-340b-3624-9f2a-76ec6b8d510c.rss?_ga=2.25737789.1239444851.1731056991-889444156.1731056991'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Moje terapie - podcastový seriál, v němž si štafetu předávají vypravěčské dvojice tvořené terapeuty a jejich klienty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/cf16c9c0-3f52-3b7b-b287-5b9340de6e49.rss?_ga=2.63655082.442969576.1731057022-804385602.1731057022'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Na vidličce Romana Pauluse - Vše o surovinách a potravinách, ze kterých s chutí vaříme. Všechny vůně kuchyně servíruje šéfkuchař Roman Paulus',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c9d3f5bd-690d-34af-81bc-7244ecca5c52.rss?_ga=2.255998606.441994330.1731057081-197551093.1731057081'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Na vidličce Romana Vaňka - Rady a tipy Romana Vaňka, které se vám mohou hodit ve vaší kuchyni i na cestách za kulinářským zážitkem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3937340d-9021-315a-9ea2-3d858d67b2c5.rss?_ga=2.143641905.568298434.1731057121-347000513.1731057121'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Naplno s Věrou Hotařovou - Cyklus rozhovorů Věry Hotařové s lidmi, kteří si dokáží užívat života i ve zralém věku',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0050ae17-a83a-3f4d-b9cd-22a70b912629.rss?_ga=2.23892410.1474009653.1731057147-1648970217.1731057147'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Parabible - Jak by vypadal příběh Ježíše Krista, kdyby se odehrál v kulisách současného Česka? Je dva tisíce let stará látka vhodná pro aktualizaci, aniž by se ztratila hloubka?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/03751633-31aa-3103-8eb3-bacffee4b64c.rss?_ga=2.36118240.1332272180.1731057208-125592298.1731057208'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Pod kontrolou - podcastová série o antikoncepci, sexu a vztazích. Ve třech dokumentech sledujeme, jak otázka kontroly početí ovlivňuje životy a vztahy sedmi mladých lidí.',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2b518bf9-d0d1-35d5-84fb-0404cbf3c3d6.rss?_ga=2.20965627.256175636.1731057248-2063358364.1731057248'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Pochoutkový rok - Hlasování skončilo. Po kontrole a očištění dat od neplatných hlasů zveřejňujeme finální výsledky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e824d489-7858-3518-a9fc-d2895ffeab7e.rss?_ga=2.171805984.1666424128.1731057287-1979038300.1731057287'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Pochoutky na talíři - Rozhlasové vaření a talk-show s profesionálním kuchařem a slavnou osobností',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/f5e7b508-253f-329d-8e47-b2114d8b14ef.rss?_ga=2.262953676.1572847757.1731057328-1293122479.1731057328'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Postíže - Zuzana Kašparová a Jakub Strouhal v uvolněných rozhovorech zpovídají zdravotně postižené vrstevníky v podcastové sérii Postíže',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bf23d4c7-9024-39c5-91c1-eb847902b096.rss?_ga=2.247901063.1440327684.1731057351-758486653.1731057351'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Pot - podcast o lásce, sexu a intimitě, o motýlech v břiše, požáru v srdci a všem, co z nás teče.',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5587de2b-09b9-3a7f-b008-1c1e0722d6cb.rss?_ga=2.161980412.1750293660.1731057390-996290144.1731057390'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Pracanti - Pracanti jsou podcastová série Evy Svobodové o první pracovní zkušenosti mladé generace. Jak si mladí lidé práci vybírají? A co při ní prožívají?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/809da509-4705-32d6-a382-21b2bd645e5d.rss?_ga=2.154249848.1149274273.1731057436-1704000337.1731057436'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Proměny měst - Rozhlasový seriál z produkce regionálních stanic Českého rozhlasu dokumentuje proměny krajských měst za posledních 100 let',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/cabf0b5d-4185-3ee9-9468-5170d8674592.rss?_ga=2.157189500.696494711.1731057461-810074736.1731057461'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Přírodní lékárna - Rubrika o potravinách a plodinách, které se vyplatí zařadit do jídelníčku',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/05bf61f3-9728-3682-8532-c8b8019f86b3.rss?_ga=2.80891799.1487575378.1731057491-1184508555.1731057491'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Putování Libereckým krajem s Markem Řeháčkem - Cestovatel a spisovatel Marek Řeháček patří mezi největší znalce turisticky zajímavých míst Libereckého kraje, každou sobotu je s ním navštěvuje redaktor Jaroslav Hoření',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c2ee16c6-fc1b-3a82-8efb-4bd6858e13f2.rss?_ga=2.161598783.2045674268.1731057527-928541787.1731057527'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Radioporadna - Zajímavá osobnost je hostem rozhlasové radioporadny od pondělí do pátku',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9d878e9f-f096-3a83-91a1-34591a653268.rss?_ga=2.159436725.96602321.1731057588-643305007.1731057588'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Reakce - Reakce je podcastový seriál o přátelství a síle sdílení. Lera s Maxem rozplétají případ zneužívání a toxického chování na vysoké škole. Podaří se jim změnit systém?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/66e5e422-43ff-326a-acd3-e221f07bb3e7.rss?_ga=2.217740950.1437182886.1731057621-964732398.1731057621'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Regiodokument - Dokumentární série věnovaná aktuálním palčivým problémům jednotlivých krajů České republiky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/184eed5d-ad31-3a2b-8147-0218bf39c3bc.rss?_ga=2.222892507.1335816536.1731057669-587628835.1731057669'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Region expres - Pořad, který vám poskytne vše o veřejné dopravě ve středních Čechách a v Praze',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/838237b4-b8b1-394b-b0f9-b8c3decb493b.rss?_ga=2.49926502.1353790472.1731057707-733827946.1731057707'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: S Arenbergerem nejen o medicíně - Podcast připravuje MUDr. Petr Arenberger a vzniká ve spolupráci s Českou lékařskou společností a Českým rozhlasem. Přibližuje medicínská témata vědecko-populárním způsobem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9a00377e-54cd-3915-90dc-552b77880fb6.rss?_ga=2.153697400.1551714855.1731057795-1613291092.1731057795'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Samotka - prostor pro vaše zprávy, vzkazy a pocity v době pandemie. Řekněte nám, jak se máte a nebuďte v tom sami.',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/62eb189a-fd21-3d18-a38e-2494fa7cfc14.rss?_ga=2.72190035.1324393294.1731057820-1674902653.1731057820'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Seriál Radiožurnálu - Pravidelné seriály z vysílání Radiožurnálu. Zajímavá témata, reportáže z vašeho kraje, kulturních akcí i historie',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/816732b1-04cc-3f40-972a-ba16bf5a6eb1.rss?_ga=2.201794774.67280594.1731057876-2010742572.1731057876'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Středočeské dopoledne - Dopolední magazín o zdraví, módě, bydlení a cestování',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c5155ffc-8a86-3baf-a295-60c68e26a95a.rss?_ga=2.249553031.1468398624.1731058016-2004410150.1731058016'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Studovna - podcast o vzdělávání, studentském životě a všem, co k němu patří',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8fcdb779-a507-3dc1-b83e-ef999112a58e.rss?_ga=2.237084489.853803508.1731058058-1256470162.1731058058'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Trenduj - Podcast o tom, co vás baví a co zrovna (ne)trenduje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7a212d56-14d1-3444-9553-7721e2c37ef9.rss?_ga=2.157122107.1450845169.1731058091-1176636238.1731058091'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Vaření za hubičku s Romanem Paulusem - Dáváme jídlu druhou šanci. Poslechněte si rychlé recepty beze zbytků, které pro vás exkluzivně připravil Roman Paulus ve spolupráci s Potravinovou bankou',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/38adc76e-6c74-305d-a88b-5647252df6df.rss?_ga=2.188914990.461151.1731058217-759503023.1731058217'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Vaříme s Habadějem - Každou sobotu dopoledne vaříme v přímém přenosu. A přejeme dobrou chuť!',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/06b72bda-2881-3302-b620-b1c39fa47627.rss?_ga=2.257184075.1378273817.1731058249-1697228569.1731058249'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Velikonoce se Sestřičkami - pobaví vás rozhovory se známými herci a ocení práci skutečných zdravotních sestřiček',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ded084d4-e583-3afc-b17e-3c4d4c123299.rss?_ga=2.257018125.782554597.1731058278-1575714148.1731058278'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Vesele a zdravě s Kateřinou Cajthamlovou - Pořad o zdraví a zdravém životním stylu, kde se veselou formou dozvíte více o svém zdraví a jak funguje lidské tělo',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4c6ebdd8-a71b-387d-9269-55fb100a4b69.rss?_ga=2.93582237.1299476450.1731058341-897446572.1731058341'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Vlakem Libereckým krajem - Parní i historické naftové lokomotivy, staré vlakové soupravy, železniční depa, muzea i malebná nádraží. Procestujte s Pavlem Petrem zajímavá místa spojená s železnicí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2c33a099-b1a2-3e7a-8b0f-bba9e9553458.rss?_ga=2.63104751.1741448337.1731058373-473885011.1731058373'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Zahrádkářské tipy - Tipy, které předávají zahrádkáři zahrádkářům',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c0ac3c6d-ada7-3e2c-a82d-f91bc2086ea9.rss?_ga=2.10078709.1561184250.1731058451-750440058.1731058451'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Zdravíčko - S lékaři a dalšími odborníky o zdraví, nemocech, léčbě i prevenci',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/cf3a7dfd-ad2d-31ee-b5ee-b08d92693338.rss?_ga=2.212762578.777837870.1731058488-1432076083.1731058488'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Zelené světy - Kouzelný svět rostlin, zahradní architektury i zahradnických novinek',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e9159914-1e84-3342-8989-c6bdb41b9d13.rss?_ga=2.149856894.934894418.1731058516-972212377.1731058516'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Zlatá láska - Nejromantičtější pořad v éteru plný dojemných příběhů zlatých manželských párů. Tedy párů, které spolu v manželství žijí 50 a více let. Poslechněte si jejich příběhy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c3ca5d02-b3f5-3183-9aea-7ad7de48e522.rss?_ga=2.110914119.390765917.1731058542-790221291.1731058542'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Zlehýnka Mariana Jelínka - Nevšední inspirace pro osobní rozvoj. Uvádí uznávaný kouč a mentor Marian Jelínek',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/db881cbe-90ad-3f4f-8084-ec6c659a9049.rss?_ga=2.103696260.522278568.1731058568-873579228.1731058568'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Životní styl: Život k nezaplacení - Rozhovor Jana Pokorného se sociologem Danielem Prokopem nejen o ekonomických výzvách pro domácnosti v roce, který ovlivnila pandemie a válka na Ukrajině',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e9c2642e-2062-3cd1-92eb-9c178c714f6c.rss?_ga=2.75884181.1466160312.1731058597-136255414.1731058597'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Blízká setkání - Tereza Kostková a Adéla Gondíková vedou rozhovory s hosty, které znáte, anebo které stojí za to poznat',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/94810db5-cd5a-3198-bdfc-95a12fcfa3b9.rss?_ga=2.56493163.176813315.1730455057-1500354991.1730455057'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Host Lucie Výborné - Rozhovory Lucie Výborné. Zajímavé osobnosti mluví o věcech, jimž rozumějí. Své dotazy pokládejte přes formulář níže',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c0e403a9-9dea-365b-96ff-545320a69b4e.rss?_ga=2.222696723.941131627.1731002494-2122111368.1731002494'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Alex a host - Rozhovory s osobnostmi',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6941b521-fb49-3f31-b659-cf4399211d07.rss?_ga=2.19167100.557351351.1731055584-168511123.1731055584'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Automatky - Internet a přehršel informací bezstarostnému mateřství moc nepřispívá. Protichůdné názory na vás skáčou každý den. I proto vznikl pořad Automatky',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e7fcc66f-0230-3f6a-8245-f32acadfe37f.rss?_ga=2.115817798.1716930792.1731058781-35707370.1731058781'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Blog létajícího redaktora - Sabina Vosecká vám přinese kulturní události z Prahy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4f4b5abe-d260-3578-85dc-7b80b7e64e89.rss?_ga=2.207397461.716517560.1731059000-1784854969.1731059000'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Bohoslužba - Záznamy bohoslužeb z různých míst Čech, Moravy a Slezska',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/388c2578-c76a-34cb-8f2e-590c2a353cc7.rss?_ga=2.235754753.1294051014.1731059139-88681270.1731059139'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Děti se ptají - Speciální podcast Dismanova rozhlasového dětského souboru Českého rozhlasu odpovídá na to, co děti doopravdy zajímá',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/772701e9-bef2-38bf-9709-1ad69b227d59.rss?_ga=2.209506577.229219292.1731059168-1232436317.1731059168'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Diagnóza F - Nejen o duševních nemocech s psychology, psychiatry a psychoterapeuty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7a97e0e3-6051-3c93-8b9a-250a9ac2a489.rss?_ga=2.32895867.43564835.1731059217-321966925.1731059217'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Dopolední host - Zajímavá témata z různých oborů, moderátor a hosté, kteří musí dát odpověď',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/912668aa-ff34-382d-80d1-77bb9f8c870f.rss?_ga=2.161601214.367946576.1731059250-1356579274.1731059250'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Hergot! - Neortodoxní pohled na duchovní záležitosti',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/96f517e9-9486-3f22-aa7a-2c7fc0294dc5.rss?_ga=2.134652913.1420661665.1731059324-540271976.1731059324'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Host Českého rozhlasu Ostrava - Kdo si občas rád nesedne s někým, s kým si dobře popovídá?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ed4a7917-c69b-3bd4-842e-829026c01a3d.rss?_ga=2.30122239.1901489097.1731056493-1570664146.1731056493'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Host do domu - Rozhovory o životě se zajímavými lidmi kolem nás',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d87ce97f-6438-3e14-9c71-dd02d4f9a1aa.rss?_ga=2.157054905.361156235.1731059350-503445441.1731059350'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Host Radiožurnálu - Pravidelné dopolední a večerní rozhovory s hosty, které nikde jinde neuslyšíte. Své dotazy pokládejte přes formulář níže',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d152812c-5997-3cbb-8729-205c164bd789.rss?_ga=2.74776530.1374148230.1731059429-1483387824.1731059429'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Host ve středu - Ve středu týdne, ve středu pozornosti. Aktuální témata i cenné rady odborníků poslouchejte každou středu po 11. hodině v rozhovoru Českého rozhlasu Vysočina',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/3ae7dd35-698f-3a76-9255-b3010cf63039.rss?_ga=2.21639739.1451546641.1731059536-685123823.1731059536'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Hrana - dokumentární podcastová série Lukáše Houdka o mužské body imagi. Zprostředkuje příběhy lidí, kteří kvůli touze po vysněné postavě vedou souboj s vlastním tělem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/dfde8eb7-f14f-34b2-86c0-9e7b4f5ea846.rss?_ga=2.48316655.876019327.1731059582-666456476.1731059582'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Jihočeši - Setkání s lidmi, kteří jsou rodem, nebo srdcem spojeni s jihočeským krajem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6b85a3a2-a72d-37ae-bad9-7317ef407e1d.rss?_ga=2.69423255.623384826.1731059635-2035981675.1731059635'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Kořeny - Příběhy a tradice spjaté se Zlínským krajem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/df2ace96-2fd0-3a48-ac66-2d0164353124.rss?_ga=2.75123344.34695605.1731059998-943569163.1731059998'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Kvér - Hodinová rozhlasová výprava do oblasti intimity, sexuality, vztahů a jejich proměn. Pokoušíme normy, odchylky i úchylky, je-li třeba, pálíme do zažitých stereotypů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4154c498-637a-3a50-9afd-c945df0e35fe.rss?_ga=2.69717778.326462174.1731060083-2124731551.1731060083'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Láska hory přenáší - Největší sonda do partnerských vztahů u nás! Příběhy známých i neznámých dvojic, které věří na lásku a zažily velkou krizi',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/300dae80-754b-3b86-a523-d80ba8ce4550.rss?_ga=2.257376331.1100233840.1731060107-179623114.1731060107'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Mezi námi - Magazín o národnostních menšinách v Česku, ve kterém seznamujeme nejenom s výjimečnými osobnostmi, ale i s jejich kulturními tradicemi a činností jejich spolků',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/7b3b0d47-bc85-3b9d-8147-9707f2c86fc9.rss?_ga=2.54621547.1535102.1731060148-217451697.1731060148'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Místa v srdci - Osobnosti nejen z Jihočeského kraje vás nechají nahlédnout na svá oblíbená místa',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d2a9356d-c3a9-352b-93c8-6ac7fa142507.rss?_ga=2.98380191.1248013359.1731060195-691549375.1731060195'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Mistrovský kurz - Učte se od nejlepších. Mistři svých oborů vám v necelé půlhodince předají to nejdůležitější',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ede6a5ca-56a3-3574-bc00-bf759770f628.rss?_ga=2.168989349.501998775.1731060224-263928867.1731060224'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Modeschau - Modeschau sleduje současnou českou návrhářskou scénu a módní průmysl',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1b202f66-f8ce-30fd-bbfc-48d2a0c9f473.rss?_ga=2.58912942.2095426949.1731060247-1406079458.1731060247'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Na cestách s Petrem Voldánem - Talkshow Petra Voldána a jeho hostů',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/46a5e581-9293-34ef-84d6-05b6e06ced52.rss?_ga=2.4124080.1466028851.1731060273-2009488626.1731060273'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: On Air - Reportáže, recenze, rozhovory i názorová publicistika z proudového vysílání',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0f57803e-42ed-3b83-ae87-bd7fcb4156d6.rss?_ga=2.109013186.192812284.1731060317-394215962.1731060317'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Osobnost Plus - Interview s významnými osobnostmi české společnosti. Barbora Tachecí a v pátek Michael Rozsypal hledají nepovrchní odpovědi',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ad21758a-b517-328e-9bb0-2a2e2819f0b5.rss?_ga=2.9568117.1791997989.1731005152-130144252.1731005152'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Osudy - Autentické vzpomínky významných osobností kultury a umění. Vyprávění o vlastním životě i o životech blízkých lidí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/18b21d43-2f83-344b-befc-d0ef9922d40a.rss?_ga=2.113788039.1265949.1731060353-317180344.1731060353'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Otevřené hlavy - série exkluzivních rozhovorů se zahraničními intelektuály a intelektuálkami o zásadních problémech a naléhavých tématech dneška',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ffc83d3d-6d43-3e8c-8a01-efdbf701942e.rss?_ga=2.260060429.1630076127.1731060431-1981999718.1731060431'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Pochlap se - Někdy hodně mlčíme, jindy moc řečníme, ale často se bojíme opravdu otevřeně mluvit, říká autor podcastu Pochlap se Václav Rouček',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2131a10c-c4ca-3293-afb3-8b9af9b31ec3.rss?_ga=2.81652055.1926909376.1731060470-1506931071.1731060470'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Poradna - Odborníci vám poradí, jak v konkrétních situacích postupovat',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1c2c50b2-1960-3d80-a541-5e94d3e618b1.rss?_ga=2.147145079.1360359706.1731060548-644750740.1731060548'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Portréty - Portréty osobností známých i méně známých. Kronika dvacátého století viděná skrz osobní příběhy politiků střední Evropy, ale i lidí politikou zasažených',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/08e46ce0-9dd9-3132-8609-a668e7bf97aa.rss?_ga=2.200705389.2146933251.1730991978-1637164625.1730991978'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Prolomit vlny - Glosář Radia Wave. Osobní komentáře k čemukoli, co nás praští přes nos',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1830c088-61da-381d-b423-8806b162acc5.rss?_ga=2.48861027.416792436.1731060622-447198174.1731060622'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Příběh Ukrajinky Julie Dančenkové - Šestadvacetiletá Julie Dančenková, která z Kyjeva uprchla před válkou i s částí rodiny do Holešova, nám poskytla unikátní příležitost nahlédnout do svého života',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/896a81fa-1b31-310e-9973-32f8d7c9e8dd.rss?_ga=2.185207593.1607944487.1731060694-151076020.1731060694'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Příběhy z kalendáře - Netradičně o významných osobnostech, objevech, stavbách a dějinných událostech. Nečekejte lekci z dějepisu, ale zábavný příběh, který chcete slyšet',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/03f669b2-150c-31f0-bba2-9f08d46995da.rss?_ga=2.58759972.84982921.1731060766-1914594586.1731060766'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Příběhy z Vysočiny - Každý týden vám přinášíme kolekci pěti zajímavých reportáží z našeho kraje. V centru naší pozornosti jsou příběhy lidí, neotřelá místa, historie, úspěchy apod',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a5715a4b-4509-33cb-bb64-584ab7b196ea.rss?_ga=2.164971583.1002054976.1731060792-742919312.1731060792'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Ranní host Dvojky - Rozhovor s výjimečnými osobnostmi',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/da10ce14-8ec8-3abc-b1d9-977ae45672ae.rss?_ga=2.77800861.880318734.1731060817-129569322.1731060817'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Rozhlasový sloupek - Krátké glosy, které píší a poté i čtou zajímavé osobnosti našeho kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6ba7f960-b37a-3da2-8ea3-e3f2609cc6c3.rss?_ga=2.114923335.1319524888.1731060849-573063757.1731060849'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: S vámi v Praze - Každý týden hodinový rozhovor s osobností',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/635431bc-84b3-3d63-9e42-29ce0e4fd6f5.rss?_ga=2.139378292.6316568.1731060907-1866489344.1731060907'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Sádlo - Sádlo je autorská podcastová série Ridiny Ahmedové o společenském tlaku na ženský vzhled a o tom, jak pestré a spletité jsou cesty k přijetí vlastního těla',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/501e3b97-6d0a-312a-b9d9-ca717cc8bffe.rss?_ga=2.1724214.646949528.1731060935-1075894111.1731060935'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Setkání u mikrofonu - V moderátorském křesle střídají zkušení rozhlasoví matadoři s nováčky z řad významných regionálních osobností. Podle toho jsou i různí hosté a témata, která se probírají',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2f483841-dd50-3ce6-b474-946f04b270b6.rss?_ga=2.258536909.63568976.1731060964-457898325.1731060964'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Slavné dvojice - Rozhovory s osobnostmi, které pojí rodinné, přátelské nebo pracovní vazby',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a755c305-f8af-3091-8b1b-75e0f9918a16.rss?_ga=2.222758235.1720914783.1731057943-1508114971.1731057943'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Slejvák - podcast o novinkách z digitálního světa a popkultury. Rychlá popkulturní sprcha na Radiu Wave s Vilmou Svobodovou a Miroslavem Harantem',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/32f305bc-6745-3e5a-9e22-0a0ae783fd88.rss?_ga=2.123327177.391513062.1731061017-209501393.1731061017'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Spirituála - Duchovní Evropa. S Martinem C. Putnou procházíme spletitými duchovními dějinami Evropy napříč národy i náboženskými konfesemi',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/6d24d8d4-5742-3cd8-92db-537c6444b2ee.rss?_ga=2.24766707.894871380.1731061099-1708648180.1731061099'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Spot - magazín Radia Wave o urbanismu, veřejném prostoru a životě ve městech.',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d792bf90-78a7-3aaa-bebf-2409922baac6.rss?_ga=2.141515573.685229542.1731061125-1206704739.1731061125'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Středočeská setkání - Pojďte spolu s námi poznat zajímavé Středočechy. Jejich příběhy, profese, zážitky i splněné sny',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/058d21f1-479d-3803-b32f-654867e745b5.rss?_ga=2.110934981.1352749551.1731061185-957637496.1731061185'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Středočeské příběhy - Zajímavé osobnosti, netradiční povolání, rekordy a úspěchy ze středních Čech a Prahy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/11059c2f-f886-3966-9b8f-c8da37f0974e.rss?_ga=2.51792041.1400314182.1731061217-1517290391.1731061217'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Tady to znám - Pojďte s námi poznat krásná místa, o kterých naši hosté říkají: Tady to znám',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e4ced81f-0f6a-3594-9fe4-fc531bb2b28d.rss?_ga=2.38960867.1915676308.1731061272-1380727996.1731061272'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Talkshow Radia Wave - Razie na bránice slušných lidí, pohřeb historie a znovuzrození dadaismu v osmdesáti minutách',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/cc39830d-1f7a-3ecf-90c2-f98f922e28e3.rss?_ga=2.59384043.738540431.1731061303-454477557.1731061303'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Umění padělat - Originální umělecké dílo, nebo bezcenný padělek? Odhalte falza ve výtvarném umění s Terezou Hofovou v nové vltavské podcastové sérii',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c64b9287-d9b3-37eb-baa6-afe9f4c675d1.rss?_ga=2.251771785.1459744545.1731061359-1742237705.1731061359'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Úžasné životy - Výrazné české osobnosti vzpomínají na lidi, kteří je svým dílem a životem inspirovali',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4a4870f3-aa5c-3c81-a28a-4996b895aeb3.rss?_ga=2.56309869.777591282.1731061383-324734117.1731061383'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Vize z krize - Podcastová série Českého rozhlasu Plus a serveru iROZHLAS o tom, jak otočit těžkou dobu ve výzvu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bee9f47d-e1ef-3923-be68-38fd794c108c.rss?_ga=2.180317796.1702365354.1731061523-1627897811.1731061523'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Xaver a host - Rozhovory, které mají šťávu',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/63c342cf-3d42-36d1-9725-ebc70859c510.rss?_ga=2.7036274.1391537164.1731058413-447003811.1731058413'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Zálety Aleny Zárybnické - To si nemůžete nechat ujít. Vypravte se s oblíbenou televizní moderátorkou každý týden na zálety!',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c38a50f4-502f-373b-b813-4f748f6a5b6d.rss?_ga=2.182530606.967430372.1731061559-554794280.1731061559'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Zhasni! - audio projekt o sexu a intimitě mladých lidí. První původní podcast z produkce Českého rozhlasu odkrývá jejich city, vztahy, vášně a touhy.',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d78bc94c-7f50-3a61-8116-985682b05055.rss?_ga=2.141469237.66241607.1731061641-416827389.1731061641'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Osobnosti a společnost: Zrcadlo - Dokumentární série o inspirativních ženách a mužích dnešního Česka',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c7334f7d-ed81-3c3a-8508-aadf81aa29f4.rss?_ga=2.23269626.1719193917.1731061683-166853898.1731061683'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Buchty - Buchty jsou sofistikovaně neseriózní zábavný girl talk Ivany Veselkové a Zuzany Fuksové. Těšte se na hodinu se dvěma moderátorkami, které...',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e3542ad9-f33b-39ee-b601-504593e8f6cc.rss?_ga=2.212180180.1338341181.1730455158-255936263.1730455158'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Brambora s vejcem - Lehce chaotická rubrika Ivany Veselkové a Aleše Stuchlého. Živé telefonáty celebritám všech kategorií - těch provařených, ale i těch, které neznáte, nebo vás nezajímají',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/bee8fcf8-f812-3d27-8348-c675641849ff.rss?_ga=2.259938506.1734834018.1731062486-1758956442.1731062486'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Fejetony Evy Kadlčákové - Nejen ženský svět a nejen pro ženy',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/c0ebb4af-fc60-3b7c-a41d-bec5c3bfa032.rss?_ga=2.218887513.1153158210.1731062783-852042436.1731062783'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Get Down - Rozjíždíš to naplno v klubu nebo tancuješ jen doma před zrcadlem? Podcastová série Gabi Heclové Get Down tě vezme za lidmi, kteří bez pohybu a hudby nemohou žít',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2524f552-1c22-362a-a21c-de6739a267cc.rss?_ga=2.93331805.1166015667.1731062849-1687430648.1731062849'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Jardo, řekni fór - Rubriku Jardo, řekni fór vysíláme každý všední den v časech 6:50, 8:50 a 15:40 hodin. Jarda Hypochondr vypráví anekdoty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/4c0d48dc-eda1-3b17-a153-5e0618df63a9.rss?_ga=2.193970349.1028071163.1731062876-663046845.1731062876'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Karanténa Zuzany Fuksové - Zápisky nepsané na oprátce, ale v bytě, na chatě a na zahradě běhěm koronakrize. Vysoká škola života v izolaci. Jak být na mateřské a mít zaracha',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/194c6055-c160-3663-b29c-bec6c077b8fd.rss?_ga=2.226273434.1220671155.1731062906-1292351.1731062906'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Karaoke - Karaoke je ujetá podcastová série, ve které hvězdy současného tuzemského popu čelí nečekaným výzvám Hany Řičicové a Vítka Svobody',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d9fbf19d-1dfd-3584-b407-eef82b961e18.rss?_ga=2.83352918.1510306141.1731062934-583442575.1731062934'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Krimipříběhy z kraje pod Ještědem - Každý všední den nahlížíme do policejních hlášení, a informujeme humornou formou, ale s vážným podtextem, o velkých zločinech i drobných přestupcích z Libereckého kraje',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/2e67b81e-62c8-3877-88ed-cb7fed6b96d5.rss?_ga=2.66362278.967349372.1731062961-1593649834.1731062961'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Makovičky - Nevíme-li si v životě rady, jdeme se zeptat zkušenějších. Malé děti sice životní zkušenosti nemají, mají ale vždy pohotovou radu nebo odpověď na otázku a to bez ohl..',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/ef6f2943-7e59-3b69-9152-6a19a8b0fc55.rss?_ga=2.129133772.176103766.1731062986-160083258.1731062986'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Mikrovlnky - týdenní výběr toho nejlepšího ze zpráv Radia Wave podle Ivany Veselkové a Zuzany Fuksové. Zprávy, které nezpůsobí žádnou informační tsunami, ale příjemně...',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8628d73e-1432-3288-9cff-21055c3350df.rss?_ga=2.112923652.1291383758.1731063058-2106595843.1731063058'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Omeletky - Víkendová popolední show s Halinou Pawlowskou. Pořad, který chutná',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e4b7ee0e-d97f-3e33-a754-e461369c18af.rss?_ga=2.220900304.958335859.1731063104-1921044997.1731063104'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Plk na nedělo - Jak to vypadá, když se bodrý hanácký světák dostane k mikrofonu?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/072f2540-529f-3e36-91f6-7d09dc6d016d.rss?_ga=2.153121976.1079029229.1731063133-845278148.1731063133'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Přímo z místa - Vyrážíme s mikrofonem do terénu a přinášíme vám reportáže ze zajímavých míst Olomouckého kraje. Památky, příroda, lidé a zážitky. To vše viděné rozhlasovýma očima',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/e55133a3-fbf0-38a7-97aa-9a66363d5518.rss?_ga=2.261712013.102549074.1731063172-1319246739.1731063172'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Svatebky - Série Svatebky sleduje 5 dívek, které se připravují na svou první svatbu. Zachycuje, jak dnes mladé české nevěsty přemýšlí o svých svatebních šatech',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/9c13acb0-a913-3773-b890-14ebf7cd6316.rss?_ga=2.261223054.2077482194.1731063220-1399558824.1731063220'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Šatníky - přináší příběhy módy z českých skříní a ulic. Poslechněte si, co se skutečně nosí a proč. Nahlížíme do skříní a šaten, analyzujeme osobní styl a přístup k oblékání',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/68963956-66bd-3c1a-9538-198631827240.rss?_ga=2.13590975.926615145.1731063243-353197470.1731063243'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Tlučhořovi - Nekonečný improvizovaný rozhlasový sitcom Oldřicha Kaisera a Jiřího Lábuse',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/54f20b77-d08f-34bc-99dc-52dc315df4b3.rss?_ga=2.261814987.739569052.1731063293-1942626315.1731063293'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Virtuální světy Jamese Colea - James Cole hrál počítačové hry, dřív než dokázal chodit',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0966802f-7a7b-3e08-b2d0-57a8788288ef.rss?_ga=2.237828806.771964840.1731063323-581060546.1731063323'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Zábava: Zkouškový - první český hraný podcastový seriál pro mladé posluchače. Šest hrdinů a hrdinek v seriálu řeší to, co asi všichni známe',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/d0800f3d-eab7-3c69-9077-47334f40bf5d.rss?_ga=2.152727803.333338937.1731063349-1847851367.1731063349'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Alchymisti - Objevte svůj kámen mudrců. Vydejte se na výpravu s císařem Rudolfem II',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/70b74b37-79b2-3c65-812d-b4e32249c33f.rss?_ga=2.110182597.1105558196.1731063509-1635052496.1731063509'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Děti se ptají - Speciální podcast Dismanova rozhlasového dětského souboru Českého rozhlasu odpovídá na to, co děti doopravdy zajímá',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/772701e9-bef2-38bf-9709-1ad69b227d59.rss?_ga=2.133778894.156726998.1731003055-1477741815.1731003055'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Filtr - Umíte se pohybovat ve světě medií? Youtuber Lukáš „Lukefry“ Fritscher má pro Tebe 10 dílnou podcastovou sérii Filtr, která se může hodit nováčkům i mediálním znalcům',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/5e2d6c2b-d9fe-3d70-8e3b-074e9bc928cd.rss?_ga=2.230384284.1243039889.1731063551-774470166.1731063551'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Klub Rádia Junior - Odpolední jízda se zajímavými moderátory, tématy, soutěžemi a hosty. Kdo přijde do studia tentokrát?',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/490894de-7bca-3959-9db2-69394e0baee6.rss?_ga=2.64844591.1456477957.1731004248-339056570.1731004248'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Lyžák - Na horách číhá zlo. Strašidelný podcast není vhodný pro posluchače mladší 10 let',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/0eb5df66-77a4-31bc-8485-1d0b619ba70e.rss?_ga=2.211558613.1901204446.1731063609-1864973362.1731063609'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Síťovka - Tereza Rašová pro vás loví ty nejzajímavější perličky z moře sociálních sítí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/1955dc56-d9ec-30c5-85ca-4ad5d8df5a98.rss?_ga=2.115792131.427871518.1731063660-1372093785.1731063660'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Starparáda - Které písničky rády poslouchají hvězdy naší hitparády? Rozhovory se známými zpěváky o jejich oblíbené muzice moderuje Klára Nováková',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/a3ecca1c-bd32-3491-8dce-f8179d8f92c6.rss?_ga=2.74710098.155119818.1731063700-1504483278.1731063700'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Totál talkshow - Rozhovory na aktuální téma s Denisou Kimlovou, nejzkušenějšími dětskými moderátory a jejich hosty',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/33be5645-a2e1-37d4-87d7-d4207b761382.rss?_ga=2.4631731.166025351.1731063731-1936028684.1731063731'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Pro děti: Zvídavec Evy Sinkovičové - Každodenní dávka neuvěřitelných zajímavostí ze světa lidí, zvířat, rostlin i věcí',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/590a0a50-7f99-3cd8-98e4-4240c79f8090.rss?_ga=2.55952811.1604584456.1731067211-1561819733.1731067211'),
  ),
  NewsRssSource(
    name: 'Podcasty > Pořady Českého rozhlasu > Různé: 100 let české státnosti ve Středočeském kraji',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/podcast/8ba0fa70-92d0-3623-b9e1-f0083cb1c1a6.rss?_ga=2.33534526.145220300.1730455493-1724476052.1730455493'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Radiožurnál',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/radiozurnal.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Dvojka',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/dvojka.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Vltava',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/vltava.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Plus',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/plus.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Radiožurnál sport',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/station/93eabdcd-ccc5-311d-825b-6f5d6509db53.rss?_ga=2.200362670.1229800799.1729844379-863974027.1729844379'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Radio Wave',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/radiowave.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Rádio Junior',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/radiojunior.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Brno',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/brno.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: České budějovice',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/cb.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Hradec králové',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/station/a831a457-9b80-3271-b153-ddf0ee63a18c.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Karlovy Vary',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/kv.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Liberec',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/station/ad541211-198e-30b7-995c-10bf08c3aea0.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Olomouc',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/olomouc.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Ostrava',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/ostrava.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Pardubice',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/pardubice.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Plzeň',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/plzen.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Rádio Praha',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/regina.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Střední Čechy',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/strednicechy.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Sever',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/sever.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Vysočina',
    uri: Uri.parse('https://api.rozhlas.cz/data/v2/podcast/station/vysocina.rss'),
  ),
  NewsRssSource(
    name: 'Podcasty > Stanice Českého rozhlasu: Zlín',
    uri: Uri.parse('https://api.mujrozhlas.cz/rss/station/b0f03203-0809-3363-bb3d-ccda436d6760.rss?_ga=2.218535131.391016407.1729844954-1508863862.1729844954'),
  ),
  NewsRssSource(
    name: 'Podcasty > Ostatní: Téčko plus',
    uri: Uri.parse('https://pinecast.com/feed/t-ko-plus'),
  ),
  NewsRssSource(
    name: 'Počítačové hry a herní konzole: Bonus web',
    uri: Uri.parse('https://servis.idnes.cz/rss.aspx?c=bonusweb'),
  ),
  NewsRssSource(
    name: 'Počítačové hry a herní konzole: Doupě',
    uri: Uri.parse('http://www.doupe.cz/RSS/sc-164/default.aspx'),
  ),
  NewsRssSource(
    name: 'Počítačové hry a herní konzole: Indian',
    uri: Uri.parse('https://indian-tv.cz/atom.xml'),
  ),
  NewsRssSource(
    name: 'Film a televize: TV tip',
    uri: Uri.parse('http://www.golias.cz/tvtip.xml'),
  ),
  NewsRssSource(
    name: 'Film a televize: Film Aktuálně',
    uri: Uri.parse('https://magazin.aktualne.cz/rss/kultura/film/'),
  ),
  NewsRssSource(
    name: 'Film a televize: DigiZone',
    uri: Uri.parse('https://www.lupa.cz/rss/n/digizone/'),
  ),
  NewsRssSource(
    name: 'Film a televize: Parabola',
    uri: Uri.parse('http://rss.parabola.cz'),
  ),
  NewsRssSource(
    name: 'Film a televize: RadioTV',
    uri: Uri.parse('http://www.radiotv.cz/feed/'),
  ),
];
