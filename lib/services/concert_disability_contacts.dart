/// Contacts checked against TicketOne and organisers' official sites, 2026-10-31.
/// A profile is guidance, never an accreditation or availability guarantee.
class ConcertDisabilityContact {
  const ConcertDisabilityContact(
    this.id,
    this.name,
    this.aliases,
    this.source,
    this.emails,
    this.instructions, {
    this.phones = const [],
    this.cities = const [],
    this.guidanceKey,
  });
  final String id, name, source, instructions;
  final List<String> aliases, emails;
  final List<String> phones, cities;
  final String? guidanceKey;

  /// Official contacts checked 2026-10-31. Matching is scoped to venue AND city.
  /// A general box-office contact is not a confirmed disability entitlement.
  static const international = <String, List<ConcertDisabilityContact>>{
    "CH": [
      ConcertDisabilityContact(
        "ch-hallenstadion",
        "Hallenstadion",
        ["Hallenstadion"],
        "https://hallenstadion.ch/besucherinfo/guests/",
        [],
        "https://hallenstadion.ch/besucherinfo/guests/",
        cities: ["Zürich", "Zurich"],
        phones: ["+41443167788"],
        guidanceKey: "disabilityIntlHallenstadion",
      ),
      ConcertDisabilityContact(
        "ch-lac",
        "LAC Lugano Arte e Cultura",
        ["LAC Lugano Arte e Cultura"],
        "https://www.luganolac.ch/lac/info/ticket-info.html",
        [],
        "https://www.luganolac.ch/lac/info/ticket-info.html",
        cities: ["Lugano"],
        phones: ["+41588664238"],
        guidanceKey: "disabilityIntlBoxOffice",
      ),
      ConcertDisabilityContact(
        "ch-beaulieu",
        "Théâtre de Beaulieu",
        ["Théâtre de Beaulieu"],
        "https://beaulieu-lausanne.com/en/useful-links/help-and-faq/",
        ["theatre@beaulieu-lausanne.com"],
        "https://beaulieu-lausanne.com/en/useful-links/help-and-faq/",
        cities: ["Lausanne"],
        phones: [],
        guidanceKey: "disabilityIntlEventSeller",
      ),
    ],
    "NL": [
      ConcertDisabilityContact(
        "nl-afas",
        "AFAS Live",
        ["AFAS Live"],
        "https://www.afaslive.nl/faq",
        [],
        "https://www.afaslive.nl/faq",
        cities: ["Amsterdam"],
        phones: [],
        guidanceKey: "disabilityIntlEventSeller",
      ),
      ConcertDisabilityContact(
        "nl-ziggo",
        "Ziggo Dome",
        ["Ziggo Dome"],
        "https://ziggodome.nl/belangrijk/veelgestelde-vragen/",
        ["info@ziggodome.nl"],
        "https://ziggodome.nl/belangrijk/veelgestelde-vragen/",
        cities: ["Amsterdam"],
        phones: [],
        guidanceKey: "disabilityIntlEventSeller",
      ),
      ConcertDisabilityContact(
        "nl-delamar",
        "DeLaMar",
        ["DeLaMar"],
        "https://delamar.nl/rolstoeltoegankelijkheid/",
        [],
        "https://delamar.nl/rolstoeltoegankelijkheid/",
        cities: ["Amsterdam"],
        phones: ["+31202200110"],
        guidanceKey: "disabilityIntlDeLaMar",
      ),
      ConcertDisabilityContact(
        "nl-rai",
        "RAI Theater",
        ["RAI Theater"],
        "https://www.rai.nl/theater-bezoeken",
        [],
        "https://www.rai.nl/theater-bezoeken",
        cities: ["Amsterdam"],
        phones: [],
        guidanceKey: "disabilityIntlRai",
      ),
      ConcertDisabilityContact(
        "nl-ahoy",
        "Rotterdam Ahoy",
        ["Rotterdam Ahoy"],
        "https://www.ahoy.nl/bezoek-ahoy/faq",
        [],
        "https://www.ahoy.nl/bezoek-ahoy/faq",
        cities: ["Rotterdam"],
        phones: [],
        guidanceKey: "disabilityIntlAhoy",
      ),
    ],
    "PL": [
      ConcertDisabilityContact(
        "pl-tauron",
        "TAURON Arena Kraków",
        ["TAURON Arena Kraków"],
        "https://www.tauronarenakrakow.pl/arena-dla-osob-niepelnosprawnych/",
        [],
        "https://www.tauronarenakrakow.pl/arena-dla-osob-niepelnosprawnych/",
        cities: ["Kraków", "Krakow"],
        phones: ["+48123491102"],
        guidanceKey: "disabilityIntlVenueInfo",
      ),
      ConcertDisabilityContact(
        "pl-spodek",
        "Spodek",
        ["Spodek"],
        "https://www.spodekkatowice.pl/pl/spodek-dla-niepelnosprawnych/215/",
        [],
        "https://www.spodekkatowice.pl/pl/spodek-dla-niepelnosprawnych/215/",
        cities: ["Katowice"],
        phones: [],
        guidanceKey: "disabilityIntlVenueInfo",
      ),
      ConcertDisabilityContact(
        "pl-ergo",
        "ERGO ARENA",
        ["ERGO ARENA"],
        "https://ergoarena.pl/dla-odwiedzajacych/osoby-z-niepelnosprawnosciami/",
        ["info@ergoarena.pl"],
        "https://ergoarena.pl/dla-odwiedzajacych/osoby-z-niepelnosprawnosciami/",
        cities: ["Gdańsk", "Gdansk"],
        phones: ["+48587672101"],
        guidanceKey: "disabilityIntlVenueInfo",
      ),
    ],
    "SE": [
      ConcertDisabilityContact(
        "se-fallan",
        "Fållan",
        ["Fållan"],
        "https://www.fallan.nu/faq",
        ["hello@fallan.nu"],
        "https://www.fallan.nu/faq",
        cities: ["Stockholm"],
        phones: [],
        guidanceKey: "disabilityIntlEventSeller",
      ),
      ConcertDisabilityContact(
        "se-filmstudion",
        "Filmstudion",
        ["Filmstudion"],
        "https://www.gothenburgfilmstudios.com/filmstudion/faq",
        ["filmstudion@gothenburgstudios.se"],
        "https://www.gothenburgfilmstudios.com/filmstudion/faq",
        cities: ["Göteborg"],
        phones: [],
        guidanceKey: "disabilityIntlFilmstudion",
      ),
      ConcertDisabilityContact(
        "se-monument",
        "Monument 031",
        ["Monument 031"],
        "https://www.monument031.com/faq/",
        [],
        "https://www.monument031.com/faq/",
        cities: ["Göteborg"],
        phones: [],
        guidanceKey: "disabilityIntlMonument",
      ),
      ConcertDisabilityContact(
        "se-fryshuset",
        "Arenan (Fryshuset)",
        ["Arenan (Fryshuset)"],
        "https://fryshuset.se/konserter/info",
        [],
        "https://fryshuset.se/konserter/info",
        cities: ["Stockholm"],
        phones: [],
        guidanceKey: "disabilityIntlEventSeller",
      ),
      ConcertDisabilityContact(
        "se-rival",
        "Rival",
        ["Rival"],
        "https://www.rival.se/biljettfragor/",
        [],
        "https://www.rival.se/biljettfragor/",
        cities: ["Stockholm"],
        phones: [],
        guidanceKey: "disabilityIntlEventSeller",
      ),
      ConcertDisabilityContact(
        "se-waterfront",
        "Waterfront Congress Centre",
        ["Waterfront Congress Centre"],
        "https://stockholmwaterfront.com/en/getting-here/",
        [],
        "https://stockholmwaterfront.com/en/getting-here/",
        cities: ["Stockholm"],
        phones: ["+46850506540"],
        guidanceKey: "disabilityIntlVenueInfo",
      ),
    ],
    "NO": [
      ConcertDisabilityContact(
        "no-cosmopolite",
        "Cosmopolite Scene",
        ["Cosmopolite Scene"],
        "https://cosmopolite.no/info/praktisk-informasjon",
        ["info@cosmopolite.no"],
        "https://cosmopolite.no/info/praktisk-informasjon",
        cities: ["Oslo", "Oslo, Akershus, Buskerud, Østfold<br> Og Innlandet"],
        phones: [],
        guidanceKey: "disabilityIntlCosmopolite",
      ),
      ConcertDisabilityContact(
        "no-byscenen",
        "Byscenen",
        ["Byscenen"],
        "https://www.byscenen.no/info/praktisk-info",
        ["post@byscenen.no"],
        "https://www.byscenen.no/info/praktisk-info",
        cities: ["Trondheim", "Trondheim Og Trøndelag"],
        phones: [],
        guidanceKey: "disabilityIntlByscenen",
      ),
      ConcertDisabilityContact(
        "no-olavshallen",
        "Olavshallen",
        ["Olavshallen"],
        "https://www.olavshallen.no/kontakt/ofte-stilte-sp%C3%B8rsm%C3%A5l",
        ["billett@olavshallen.no"],
        "https://www.olavshallen.no/kontakt/ofte-stilte-sp%C3%B8rsm%C3%A5l",
        cities: ["Trondheim", "Trondheim Og Trøndelag"],
        phones: [],
        guidanceKey: "disabilityIntlOlavshallen",
      ),
    ],
    "RO": [
      ConcertDisabilityContact(
        "ro-tony",
        "Teatrul Municipal Tony Bulandra",
        ["Teatrul Municipal Tony Bulandra"],
        "https://www.tonybulandra.ro/ro/agentia-de-bilete/",
        ["rezervari@tonybulandra.ro"],
        "https://www.tonybulandra.ro/ro/agentia-de-bilete/",
        cities: ["Târgoviște"],
        phones: ["+40374871834"],
        guidanceKey: "disabilityIntlEnquire",
      ),
      ConcertDisabilityContact(
        "ro-arad",
        "Teatrul Clasic Ioan Slavici",
        ["Teatrul Clasic Ioan Slavici"],
        "https://teatrulclasic.ro/contact/",
        [],
        "https://teatrulclasic.ro/contact/",
        cities: ["Arad"],
        phones: ["+40744475147"],
        guidanceKey: "disabilityIntlEnquire",
      ),
      ConcertDisabilityContact(
        "ro-toma",
        "Teatrul Bulandra - Sala Toma Caragiu",
        ["Teatrul Bulandra - Sala Toma Caragiu"],
        "https://www.bulandra.ro/contact/",
        [],
        "https://www.bulandra.ro/contact/",
        cities: ["București", "Bucuresti"],
        phones: ["+40735835681"],
        guidanceKey: "disabilityIntlEnquire",
      ),
      ConcertDisabilityContact(
        "ro-liviu",
        "Teatrul Bulandra - Sala Liviu Ciulei",
        ["Teatrul Bulandra - Sala Liviu Ciulei"],
        "https://www.bulandra.ro/contact/",
        [],
        "https://www.bulandra.ro/contact/",
        cities: ["București", "Bucuresti"],
        phones: ["+40735835675"],
        guidanceKey: "disabilityIntlEnquire",
      ),
    ],
    "BR": [
      ConcertDisabilityContact(
        "br-bluenote",
        "Blue Note São Paulo",
        ["Blue Note São Paulo"],
        "https://bluenotesp.com/contato/",
        ["bilheteria@bluenotesp.com"],
        "https://bluenotesp.com/contato/",
        cities: ["São Paulo"],
        phones: ["+5511930004555"],
        guidanceKey: "disabilityIntlEnquire",
      ),
      ConcertDisabilityContact(
        "br-cine",
        "Cine Theatro Brasil",
        ["Cine Theatro Brasil"],
        "https://www.cinetheatrobrasil.com.br/contato/",
        ["contato@cinetheatrobrasil.com.br"],
        "https://www.cinetheatrobrasil.com.br/contato/",
        cities: ["Belo Horizonte"],
        phones: ["+553132015211"],
        guidanceKey: "disabilityIntlEnquire",
      ),
    ],
  };

  static String _internationalName(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  static ConcertDisabilityContact? matchInternationalVenue(
    String country,
    String venue,
    String city,
  ) {
    if (venue.trim().isEmpty || city.trim().isEmpty) return null;
    for (final profile
        in international[country] ?? const <ConcertDisabilityContact>[]) {
      if (profile.aliases.any(
            (a) => _internationalName(a) == _internationalName(venue),
          ) &&
          profile.cities.any(
            (c) => _internationalName(c) == _internationalName(city),
          )) {
        return profile;
      }
    }
    return null;
  }

  static ConcertDisabilityContact? matchAustrianVenue(
    String venue,
    String city,
  ) {
    if (venue.trim().isEmpty || city.trim().isEmpty) return null;
    for (final profile in austria) {
      if (profile.aliases.any((a) => _germanName(a) == _germanName(venue)) &&
          profile.cities.any((c) => _germanName(c) == _germanName(city))) {
        return profile;
      }
    }
    return null;
  }

  // Official venue/tourism procedures checked 2026-10-31, not seat availability.
  static const austria = <ConcertDisabilityContact>[
    ConcertDisabilityContact(
      "at-stadthalle",
      "Wiener Stadthalle",
      [
        "Wiener Stadthalle",
        "Wiener Stadthalle - Halle D",
        "Wiener Stadthalle - Halle E",
        "Wiener Stadthalle - Halle F",
      ],
      "https://www.stadthalle.com/en-us/information/faq/accessibility",
      [],
      "https://www.stadthalle.com/en-us/information/faq/accessibility",
      phones: ["+43198100480"],
      cities: ["Wien", "Vienna"],
      guidanceKey: "disabilityAtStadthalle",
    ),
    ConcertDisabilityContact(
      "at-konzerthaus",
      "Wiener Konzerthaus",
      ["Wiener Konzerthaus"],
      "https://konzerthaus.at/de/barrierefreiheit",
      ["ticket@konzerthaus.at"],
      "https://konzerthaus.at/de/barrierefreiheit",
      phones: ["+431242002"],
      cities: ["Wien", "Vienna"],
      guidanceKey: "disabilityAtKonzerthaus",
    ),
    ConcertDisabilityContact(
      "at-bruckner",
      "Brucknerhaus",
      ["Brucknerhaus"],
      "https://www.brucknerhaus.at/das-haus/raeumlichkeiten",
      ["brucknerhaus@liva.linz.at"],
      "https://www.brucknerhaus.at/das-haus/raeumlichkeiten",
      phones: ["+4373276120"],
      cities: ["Linz"],
      guidanceKey: "disabilityAtBruckner",
    ),
    ConcertDisabilityContact(
      "at-musikverein",
      "Musikverein Wien",
      ["Musikverein Wien"],
      "https://musikverein.at/de/konzertbesuch/",
      ["tickets@musikverein.at"],
      "https://musikverein.at/de/konzertbesuch/",
      phones: ["+4315058190"],
      cities: ["Wien", "Vienna"],
      guidanceKey: "disabilityAtMusikverein",
    ),
    ConcertDisabilityContact(
      "at-innsbruck",
      "Congress Innsbruck",
      ["Congress Innsbruck"],
      "https://www.cmi.at/de/unternehmen/barrierefreiheit",
      ["info@cmi.at"],
      "https://www.cmi.at/de/unternehmen/barrierefreiheit",
      phones: ["+4351259360"],
      cities: ["Innsbruck"],
      guidanceKey: "disabilityAtInnsbruck",
    ),
    ConcertDisabilityContact(
      "at-graz",
      "Stadthalle Graz",
      ["Stadthalle Graz"],
      "https://www.graztourismus.at/Barrierefrei/PDFs/va-orte/stadthalle-und-messecongress-graz_barrierefrei_2025.pdf",
      ["office@mcg.at"],
      "https://www.graztourismus.at/Barrierefrei/PDFs/va-orte/stadthalle-und-messecongress-graz_barrierefrei_2025.pdf",
      phones: ["+4331680880"],
      cities: ["Graz"],
      guidanceKey: "disabilityAtGraz",
    ),
  ];

  static ConcertDisabilityContact? matchBritishVenue(
    String venue,
    String city,
  ) {
    if (venue.trim().isEmpty || city.trim().isEmpty) return null;
    for (final profile in unitedKingdom) {
      if (profile.aliases.any((a) => _normalise(a) == _normalise(venue)) &&
          profile.cities.any((c) => _normalise(c) == _normalise(city))) {
        return profile;
      }
    }
    return null;
  }

  // Official accessibility procedures checked 2026-10-31; not availability.
  static const unitedKingdom = <ConcertDisabilityContact>[
    ConcertDisabilityContact(
      "gb-apollo",
      "Eventim Apollo — London",
      ["Eventim Apollo"],
      "https://www.eventimapollo.com/venue-info/access-requirements/",
      ["info@eventimapollo.com"],
      "https://www.eventimapollo.com/venue-info/access-requirements/",
      phones: ["+442085633800"],
      cities: ["London"],
      guidanceKey: "disabilityGbApollo",
    ),
    ConcertDisabilityContact(
      "gb-ao",
      "AO Arena Manchester — Manchester",
      ["AO Arena Manchester", "AO Arena"],
      "https://www.ao-arena.com/venue-information/accessibility",
      ["contactus@ao-arena.com"],
      "https://www.ao-arena.com/venue-information/accessibility",
      phones: [],
      cities: ["Manchester"],
      guidanceKey: "disabilityGbAo",
    ),
    ConcertDisabilityContact(
      "gb-birmingham",
      "Utilita Arena Birmingham — Birmingham",
      ["Utilita Arena Birmingham"],
      "https://www.utilitaarenabham.co.uk/accessibility",
      [],
      "https://www.utilitaarenabham.co.uk/accessibility",
      phones: [],
      cities: ["Birmingham"],
      guidanceKey: "disabilityGbBirmingham",
    ),
    ConcertDisabilityContact(
      "gb-leeds",
      "first direct arena — Leeds",
      ["first direct arena", "first direct bank arena"],
      "https://www.firstdirectbankarena.com/your-visit/accessibility",
      ["accessibility@firstdirectbankarena.com"],
      "https://www.firstdirectbankarena.com/your-visit/accessibility",
      phones: ["+441138778297"],
      cities: ["Leeds"],
      guidanceKey: "disabilityGbLeeds",
    ),
    ConcertDisabilityContact(
      "gb-hydro",
      "OVO Hydro — Glasgow",
      ["OVO Hydro"],
      "https://www.ovohydro.com/visitor-info/accessibility-information",
      ["booking.enquiries@sec.co.uk"],
      "https://www.ovohydro.com/visitor-info/accessibility-information",
      phones: ["+441415763230"],
      cities: ["Glasgow"],
      guidanceKey: "disabilityGbHydro",
    ),
    ConcertDisabilityContact(
      "gb-nottingham",
      "Motorpoint Arena Nottingham — Nottingham",
      ["Motorpoint Arena Nottingham"],
      "https://www.motorpointarenanottingham.com/accessibility/",
      [],
      "https://www.motorpointarenanottingham.com/accessibility/",
      phones: ["+448081644616"],
      cities: ["Nottingham"],
      guidanceKey: "disabilityGbNottingham",
    ),
    ConcertDisabilityContact(
      "gb-newcastle",
      "Newcastle Utilita Arena — Newcastle",
      ["Newcastle Utilita Arena", "Utilita Arena Newcastle"],
      "https://www.utilitaarena.co.uk/venue-information/accessibility",
      ["Newcastle.Accessibility@legendsglobal.com"],
      "https://www.utilitaarena.co.uk/venue-information/accessibility",
      phones: ["+441916181697"],
      cities: ["Newcastle"],
      guidanceKey: "disabilityGbNewcastle",
    ),
  ];

  static String _frenchName(String value) => _normalise(
    value
        .toLowerCase()
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[àâä]'), 'a')
        .replaceAll(RegExp('[ôö]'), 'o')
        .replaceAll('ç', 'c'),
  );

  /// Match the actual venue and city, never the promoter or event title.
  static ConcertDisabilityContact? matchFrenchVenue(String venue, String city) {
    if (venue.trim().isEmpty || city.trim().isEmpty) return null;
    for (final profile in france) {
      if (profile.aliases.any((a) => _frenchName(a) == _frenchName(venue)) &&
          profile.cities.any((c) => _frenchName(c) == _frenchName(city))) {
        return profile;
      }
    }
    return null;
  }

  static String _germanName(String value) => _normalise(
    value
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss'),
  );

  static String _spanishName(String value) => _normalise(
    value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n'),
  );

  static ConcertDisabilityContact? matchSpanishVenue(
    String venue,
    String city,
  ) {
    if (venue.trim().isEmpty || city.trim().isEmpty) return null;
    for (final profile in spain) {
      if (profile.aliases.any((a) => _spanishName(a) == _spanishName(venue)) &&
          profile.cities.any((c) => _spanishName(c) == _spanishName(city))) {
        return profile;
      }
    }
    return null;
  }

  // Official venue/tourism accessibility information checked 2026-10-31.
  // PMR eligibility must not be inferred from a visual disability.
  static const spain = <ConcertDisabilityContact>[
    ConcertDisabilityContact(
      'es-movistar',
      'Movistar Arena — Madrid',
      ['Movistar Arena', 'Movistar Arena Madrid', 'WiZink Center'],
      'https://www.movistararena.es/ayuda/',
      [],
      'https://www.movistararena.es/ayuda/',
      phones: ['+34914449949'],
      cities: ['Madrid'],
      guidanceKey: 'disabilityEsMovistar',
    ),
    ConcertDisabilityContact(
      'es-palau',
      'Palau Sant Jordi — Barcelona',
      ['Palau Sant Jordi'],
      'https://palausantjordi.barcelona/es/informacion/accesible',
      [],
      'https://palausantjordi.barcelona/es/informacion/accesible',
      cities: ['Barcelona'],
      guidanceKey: 'disabilityEsPalau',
    ),
    ConcertDisabilityContact(
      'es-roig',
      'Roig Arena — Valencia',
      ['Roig Arena'],
      'https://www.roigarena.com/es/preguntas-frecuentes/',
      ['info@roigarena.es'],
      'https://www.roigarena.com/es/preguntas-frecuentes/',
      cities: ['Valencia', 'València'],
      guidanceKey: 'disabilityEsRoig',
    ),
    ConcertDisabilityContact(
      'es-bec',
      'Bizkaia Arena BEC! — Barakaldo',
      ['Bizkaia Arena BEC!', 'Bizkaia Arena'],
      'https://bizkaiaarena.bilbaoexhibitioncentre.com/faq/',
      ['bizkaiaarena@bec.eu'],
      'https://bizkaiaarena.bilbaoexhibitioncentre.com/faq/',
      phones: ['+34944040000'],
      cities: ['Bilbao', 'Barakaldo'],
      guidanceKey: 'disabilityEsBec',
    ),
    ConcertDisabilityContact(
      'es-bilbao',
      'Bilbao Arena Miribilla — Bilbao',
      ['Bilbao Arena Miribilla', 'Bilbao Arena'],
      'https://www.visitbiscay.eus/es/accesible/bilbao-arena',
      ['bilbaoarena@bilbaoekintza.bilbao.eus'],
      'https://www.visitbiscay.eus/es/accesible/bilbao-arena',
      phones: ['+34946010411'],
      cities: ['Bilbao'],
      guidanceKey: 'disabilityEsBilbao',
    ),
    ConcertDisabilityContact(
      'es-cartuja',
      'Cartuja Center CITE — Sevilla',
      ['Cartuja Center', 'Cartuja Center CITE'],
      'https://cartujacenter.com/contacto/',
      ['info.cite@eulen.com'],
      'https://cartujacenter.com/preguntas-frecuentes/',
      phones: ['+34955519125'],
      cities: ['Sevilla', 'Seville'],
      guidanceKey: 'disabilityEsCartuja',
    ),
  ];

  static ConcertDisabilityContact? matchGermanVenue(String venue, String city) {
    if (venue.trim().isEmpty || city.trim().isEmpty) return null;
    for (final profile in germany) {
      if (profile.aliases.any((a) => _germanName(a) == _germanName(venue)) &&
          profile.cities.any((c) => _germanName(c) == _germanName(city))) {
        return profile;
      }
    }
    return null;
  }

  // Official venue/service accessibility instructions checked 2026-10-31.
  // Contacts are deliberately NOT inferred from another event at the venue.
  static const germany = <ConcertDisabilityContact>[
    ConcertDisabilityContact(
      'de-uber',
      'Uber Arena — Berlin',
      ['Uber Arena', 'Uber Arena Berlin'],
      'https://www.uber-arena.de/27',
      [],
      'https://www.uber-arena.de/ihr-besuch/barrierefreiheit/kontakt-barrierefreietickets/',
      cities: ['Berlin'],
      guidanceKey: 'disabilityDeUber',
    ),
    ConcertDisabilityContact(
      'de-lanxess',
      'LANXESS arena — Köln',
      ['LANXESS arena'],
      'https://www.lanxess-arena.de/besucherinfos/barrierefreiheit',
      [],
      'https://www.lanxess-arena.de/besucherinfos/barrierefreiheit',
      phones: ['+492218020'],
      cities: ['Köln', 'Cologne'],
      guidanceKey: 'disabilityDeLanxess',
    ),
    ConcertDisabilityContact(
      'de-barclays',
      'Barclays Arena — Hamburg',
      ['Barclays Arena'],
      'https://www.barclays-arena.de/besuch-planen/barrierefreiheit',
      [],
      'https://www.barclays-arena.de/besuch-planen/barrierefreiheit',
      cities: ['Hamburg'],
      guidanceKey: 'disabilityDeSeller',
    ),
    ConcertDisabilityContact(
      'de-festhalle',
      'Festhalle — Frankfurt',
      ['Festhalle', 'Festhalle Frankfurt'],
      'https://festhalle.messefrankfurt.com/frankfurt/de/besucher.html',
      ['barrierefrei@messefrankfurt.com'],
      'https://festhalle.messefrankfurt.com/frankfurt/de/besucher.html',
      phones: ['+496975756999'],
      cities: ['Frankfurt', 'Frankfurt am Main'],
      guidanceKey: 'disabilityDeFesthalle',
    ),
    ConcertDisabilityContact(
      'de-westfalen',
      'Westfalenhalle — Dortmund',
      ['Westfalenhalle', 'Westfalenhalle Dortmund'],
      'https://www.westfalenhalle.de/besucherservices/barrierefrei/',
      [],
      'https://www.westfalenhalle.de/besucherservices/barrierefrei/',
      cities: ['Dortmund'],
      guidanceKey: 'disabilityDeWestfalen',
    ),
    ConcertDisabilityContact(
      'de-sap',
      'SAP Arena — Mannheim',
      ['SAP Arena'],
      'https://saparena.de/besucherservice/barrierefreiheit/',
      [],
      'https://saparena.de/besucherservice/barrierefreiheit/',
      phones: ['+4962118190333'],
      cities: ['Mannheim'],
      guidanceKey: 'disabilityDeSap',
    ),
    ConcertDisabilityContact(
      'de-olympia',
      'Olympiahalle — München',
      ['Olympiahalle', 'Olympiahalle München'],
      'https://www.muenchenticket.de/barrierefrei/',
      ['barrierefrei@muenchenticket.de'],
      'https://www.muenchenticket.de/barrierefrei/',
      phones: ['+498954818182'],
      cities: ['München', 'Munich'],
      guidanceKey: 'disabilityDeMunich',
    ),
    ConcertDisabilityContact(
      'de-quarterback',
      'QUARTERBACK Immobilien ARENA — Leipzig',
      ['QUARTERBACK Immobilien ARENA', 'QUARTERBACK Immobilien ARENA Leipzig'],
      'https://www.quarterback-immobilien-arena.de/faq',
      ['ticketkauf@arena-ticket.com'],
      'https://www.quarterback-immobilien-arena.de/faq',
      phones: ['+493412341100'],
      cities: ['Leipzig'],
      guidanceKey: 'disabilityDeLeipzig',
    ),
  ];

  // Official accessibility pages checked 2026-10-31. A venue's procedure can
  // depend on the event and disability; these are hand-offs, not reservations.
  static const france = <ConcertDisabilityContact>[
    ConcertDisabilityContact(
      'fr-accor',
      'Accor Arena — Paris',
      ['Accor Arena'],
      'https://www.accorarena.com/fr/infos-pratiques/pmr',
      [],
      'https://www.accorarena.com/fr/infos-pratiques/pmr',
      phones: ['+33146915754'],
      cities: ['Paris'],
      guidanceKey: 'disabilityFrPhone',
    ),
    ConcertDisabilityContact(
      'fr-olympia',
      'L’Olympia — Paris',
      ['Olympia', 'L’Olympia'],
      'https://www.olympiahall.com/accessibilite/',
      ['billetterie@olympiahall.com'],
      'https://www.olympiahall.com/accessibilite/',
      phones: ['+33147429488'],
      cities: ['Paris'],
    ),
    ConcertDisabilityContact(
      'fr-palais-paris',
      'Palais des Congrès — Paris',
      ['Palais des Congrès', 'Palais des Congrès de Paris'],
      'https://billetterie.palaisdescongresdeparis.com/fr/pmr-psh',
      ['ticket@viparis.com'],
      'https://billetterie.palaisdescongresdeparis.com/fr/pmr-psh',
      phones: ['+33140682991'],
      cities: ['Paris'],
    ),
    ConcertDisabilityContact(
      'fr-stade-france',
      'Stade de France — Saint-Denis',
      ['Stade de France'],
      'https://www.stadefrance.com/fr/handicaps/comment-reserver-vos-billets',
      [],
      'https://www.stadefrance.com/fr/handicaps/comment-reserver-vos-billets',
      cities: ['Saint-Denis', 'Saint Denis', 'La Plaine Saint Denis', 'Paris'],
      guidanceKey: 'disabilityFrStade',
    ),
    ConcertDisabilityContact(
      'fr-zenith-nantes',
      'Zénith Nantes Métropole — Saint-Herblain',
      [
        'Zénith Nantes Métropole',
        'Zénith de Nantes Métropole',
        'Zénith de Nantes',
        'Zénith Nantes',
      ],
      'https://www.zenith-nantesmetropole.com/pages/bienvenue-au-zenith-achat-billets',
      [],
      'https://www.zenith-nantesmetropole.com/pages/bienvenue-au-zenith-achat-billets',
      cities: ['Nantes', 'Saint-Herblain'],
      guidanceKey: 'disabilityFrZenith',
    ),
  ];
  static String _normalise(String value) => value
      .toLowerCase()
      .replaceAll('&', ' e ')
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  static ConcertDisabilityContact? match(String organiser) {
    final name = _normalise(organiser.split(',').first.trim());
    if (name.isEmpty) return null;
    for (final contact in all) {
      for (final alias in contact.aliases) {
        final base = _normalise(alias);
        if ([
          '',
          'srl',
          'spa',
          'srls',
        ].any((suffix) => name == '$base$suffix')) {
          return contact;
        }
      }
    }
    return null;
  }

  static const all = <ConcertDisabilityContact>[
    ConcertDisabilityContact(
      "organiser-1",
      "Aurora Eventi",
      ["Aurora Eventi"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse1276442",
      ["disabili@auroraeventi.net"],
      "https://auroraeventi.net/contatti/",
    ),
    ConcertDisabilityContact(
      "organiser-2",
      "Best Eventi",
      ["Best Eventi", "Best Eventi 2", "New Events"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse330718",
      ["servizioclienti@besteventi.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse330718",
    ),
    ConcertDisabilityContact(
      "organiser-3",
      "ChorusLife Arena",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse940895",
      [],
      "https://www.datocms-assets.com/143646/1766049808-infoaccessopersonecondisabilita-ext.pdf",
    ),
    ConcertDisabilityContact(
      "organiser-4",
      "D’Alessandro e Galli",
      ["D’Alessandro e Galli", "Di and Gi"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse316665",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse316665",
    ),
    ConcertDisabilityContact(
      "organiser-5",
      "Fondazione INDA",
      ["Fondazione INDA"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse1150900",
      [],
      "https://www.indafondazione.org/biglietteria/#Disabili",
    ),
    ConcertDisabilityContact(
      "organiser-6",
      "Eclissi Eventi",
      ["Eclissi Eventi"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse350520",
      ["info-areadisabili@eclissieventi.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse350520",
    ),
    ConcertDisabilityContact(
      "organiser-7",
      "Elite Agency",
      ["Elite Agency"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse350820",
      ["elite@eliteagency.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse350820",
    ),
    ConcertDisabilityContact(
      "organiser-8",
      "Friends & Partners",
      ["Friends e Partners", "Friends and Partners", "Friends & Partners"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse317223",
      ["servizioclienti@friendsandpartners.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse317223",
    ),
    ConcertDisabilityContact(
      "organiser-9",
      "Fondazione Musica per Roma",
      ["Fondazione Musica per Roma"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323144",
      ["info@musicaperroma.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323144",
    ),
    ConcertDisabilityContact(
      "organiser-10",
      "Live Nation",
      ["Live Nation", "Live Nation 6", "Live Nation Italia"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse330679",
      [],
      "https://www.livenation.it/faq",
    ),
    ConcertDisabilityContact(
      "organiser-11",
      "Nexo / Ferrara Summer Festival",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse350496",
      [],
      "https://www.ferrarasummerfestival.it/accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-12",
      "Pulp",
      ["Pulp", "Pulp Concerti"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse343299",
      ["info@pulpconcerti.eu"],
      "https://www.pulpliveonstage.it/politica-di-accesso/",
    ),
    ConcertDisabilityContact(
      "organiser-13",
      "Shining Production / Live Club",
      ["Shining Production", "Live Club"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse330739",
      ["laura@shiningproduction.com", "laura@liveclub.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse330739",
    ),
    ConcertDisabilityContact(
      "organiser-14",
      "Show Bees / Teatro Arcimboldi",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse317247",
      [],
      "https://www.teatroarcimboldi.it/accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-15",
      "Stage Entertainment",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse327295",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse327295",
    ),
    ConcertDisabilityContact(
      "organiser-16",
      "Teatro Brancaccio",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse400996",
      [],
      "https://www.teatrobrancaccio.it/accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-17",
      "Teatro dell’Opera di Roma",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323168",
      ["ufficio.biglietteria@operaroma.it"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323168",
    ),
    ConcertDisabilityContact(
      "organiser-18",
      "Teatro Repower",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse327271",
      [],
      "https://www.teatrorepower.com/it/diversamenteabili",
    ),
    ConcertDisabilityContact(
      "organiser-19",
      "Sala Umberto",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse401020",
      [],
      "https://www.salaumberto.com/accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-20",
      "The Base",
      ["The Base"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323192",
      [],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323192",
    ),
    ConcertDisabilityContact(
      "organiser-21",
      "Vertigo",
      ["Vertigo"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse330763",
      [],
      "https://www.vertigo.co.it/faq/#collapse-1-5108",
    ),
    ConcertDisabilityContact(
      "organiser-22",
      "Vivo Concerti",
      ["Vivo Concerti"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323072",
      ["info@vivoconcerti.com"],
      "https://www.ticketone.it/campaign/diversamente-abili/#collapse323072",
    ),
    ConcertDisabilityContact(
      "organiser-23",
      "Ventidieci",
      ["Ventidieci"],
      "https://ventidieci.it/contatti/",
      ["info@ventidieci.it"],
      "https://ventidieci.it/contatti/",
    ),
    ConcertDisabilityContact(
      "organiser-24",
      "Live Emotion Group",
      ["Live Emotion Group"],
      "https://www.legsrl.net/accesso-disabili/",
      [],
      "https://www.legsrl.net/accesso-disabili/",
    ),
    ConcertDisabilityContact(
      "organiser-25",
      "PRG / BitConcerti",
      ["PRG", "PRG - Pubblic Relations Group"],
      "https://www.bitconcerti.it/da-sapere.html",
      [],
      "https://www.bitconcerti.it/da-sapere.html",
    ),
    ConcertDisabilityContact(
      "organiser-26",
      "Associazione Jazzmi",
      ["Associazione Jazzmi"],
      "https://jazzmi.it/contact/",
      ["info@jazzmi.it"],
      "https://jazzmi.it/contact/",
    ),
    ConcertDisabilityContact(
      "organiser-27",
      "Blue Note",
      ["Blue Note"],
      "https://bluenotemilano.com/domande-frequenti/",
      [],
      "https://bluenotemilano.com/domande-frequenti/",
    ),
    ConcertDisabilityContact(
      "organiser-28",
      "Circolo Magnolia",
      ["ASSOCIAZIONE ARCI MAGNOLIA"],
      "https://www.circolomagnolia.it/accessibilita/",
      ["info@circolomagnolia.it"],
      "https://www.circolomagnolia.it/accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-29",
      "Fondazione Romaeuropa",
      ["Fondazione RomaEuropa Arte e Cultura"],
      "https://romaeuropa.net/box-office/accessibilita/",
      [],
      "https://romaeuropa.net/box-office/accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-30",
      "Teatro Comunale di Vicenza",
      ["Fondazione Teatro Comunale Citta' di Vicenza"],
      "https://www.tcvi.it/it/informazioni/accoglienza-e-accessibilita/",
      ["biglietteria@tcvi.it"],
      "https://www.tcvi.it/it/informazioni/accoglienza-e-accessibilita/",
    ),
    ConcertDisabilityContact(
      "organiser-31",
      "Casa del Jazz",
      ["Musica per Roma - Casa del Jazz"],
      "https://www.casadeljazz.com/frequently-asked-question/",
      [],
      "https://www.casadeljazz.com/frequently-asked-question/",
    ),
    ConcertDisabilityContact(
      "organiser-32",
      "Prisma Show",
      ["Prisma Show"],
      "https://www.prismashow.com/contact",
      ["info@prismashow.com"],
      "https://www.prismashow.com/contact",
    ),
    ConcertDisabilityContact(
      "organiser-33",
      "We4Show",
      ["WE4SHOW di Fabiana Palama'", "We4Show"],
      "https://we4show.com/contatti/",
      ["info@we4show.com"],
      "https://we4show.com/contatti/",
    ),
    ConcertDisabilityContact(
      "organiser-34",
      "International Music and Arts",
      ["International Music and Arts"],
      "https://internationalmusic.it/team/",
      ["info@internationalmusic.it"],
      "https://internationalmusic.it/team/",
    ),
    ConcertDisabilityContact(
      "organiser-35",
      "Viola Produzioni",
      ["Viola Produzioni"],
      "https://violaproduzioni.it/contatti/",
      [],
      "https://violaproduzioni.it/contatti/",
    ),
  ];
}
