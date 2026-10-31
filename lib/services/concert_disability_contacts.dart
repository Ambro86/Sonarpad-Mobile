/// Contacts checked against TicketOne's official directory, 2026-10-31.
/// A profile is guidance, never an accreditation or availability guarantee.
class ConcertDisabilityContact {
  const ConcertDisabilityContact(
    this.id,
    this.name,
    this.aliases,
    this.source,
    this.emails,
    this.instructions,
  );
  final String id, name, source, instructions;
  final List<String> aliases, emails;
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
      ["Best Eventi"],
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
      ["D’Alessandro e Galli"],
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
      ["Live Nation", "Live Nation 6"],
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
  ];
}
