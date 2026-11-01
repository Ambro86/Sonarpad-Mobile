import 'concert_disability_international_strings.dart';

/// Like travel strings, use English as fallback outside the Italian catalogue UI.
class TicketOneStrings {
  TicketOneStrings(this.locale);
  final String locale;
  String t(String key) {
    final language = locale.split(RegExp('[-_]')).first;
    final international =
        concertDisabilityInternationalStrings[language]?[key] ??
        concertDisabilityInternationalStrings['en']?[key];
    if (international != null) return international;
    return (language == 'it'
        ? _it[key]
        : language == 'fr'
        ? _fr[key] ?? _en[key]
        : language == 'de'
        ? _de[key] ?? _en[key]
        : language == 'es'
        ? _es[key] ?? _en[key]
        : _en[key])!;
  }

  static int? otpDigitIndex(String label) {
    const digits = ['first', 'second', 'third', 'fourth', 'fifth', 'sixth'];
    final match = RegExp(
      r'^(first|second|third|fourth|fifth|sixth) digit$',
      caseSensitive: false,
    ).firstMatch(label.trim());
    if (match == null) return null;
    return digits.indexOf(match[1]!.toLowerCase());
  }

  String fieldLabel(String label) {
    final index = otpDigitIndex(label);
    if (index == null) return label;
    final number = index + 1;
    return locale.split(RegExp('[-_]')).first == 'it'
        ? 'Cifra $number'
        : 'Digit $number';
  }

  static const _es = {
    'disabilityTitle': 'Acceso para personas con discapacidad',
    'disabilityHelp':
        'Las localidades adaptadas y las condiciones para acompañantes dependen del recinto y del organizador. Consulta los canales oficiales antes de comprar.',
    'disabilityVenue': 'Recinto y ciudad',
    'disabilityConditions':
        'Explica tus necesidades, también si eres una persona ciega o con baja visión. Las entradas PMR pueden estar reservadas para movilidad reducida y no corresponden automáticamente a cualquier discapacidad. Confirma documentación, acompañante, perro de asistencia, precio y disponibilidad. Sonarpad no decide la elegibilidad.',
    'disabilityContactInstructions': 'Consultar las instrucciones oficiales',
    'disabilityContactEmail': 'Escribir un correo electrónico',
    'disabilityPhone': 'Llamar a la taquilla',
    'disabilityCallContact': 'Llamar al servicio indicado',
    'disabilityOpenEvent': 'Abrir la página original del evento',
    'disabilityChooseOrganiser': 'Elegir organizador o recinto',
    'disabilityChooseHelp':
        'Selecciona únicamente el recinto o el organizador de tu evento. Comprueba espectáculo, ciudad y fecha antes de contactar.',
    'disabilityRequestNotice':
        'Una consulta no es una reserva confirmada. Sonarpad no envía solicitudes ni documentos automáticamente.',
    'disabilityEsUnknown':
        'Todavía no tenemos un contacto verificado para este recinto. Abre la página del evento y busca accesibilidad o contacta con su organizador. No utilices los contactos de otro recinto.',
    'disabilityEsMovistar':
        'Para discapacidad visual o auditiva, el recinto ofrece ayuda para llegar al asiento: consulta al servicio indicado. Las entradas PMR tienen requisitos de movilidad y el acompañante debe tener su entrada específica. No selecciones PMR solo por tener discapacidad visual.',
    'disabilityEsPalau':
        'Consulta las condiciones oficiales de asistencia y acceso. Las puertas y servicios PMR tienen criterios propios; para otras necesidades, confirma la ayuda con el recinto. Para localidades adaptadas y acompañantes consulta al organizador o vendedor de tu evento: esta página no confirma una reserva.',
    'disabilityEsRoig':
        'El correo es atención general del recinto. Confirma la categoría adecuada y las condiciones para tu evento. La FAQ exige una entrada específica y acreditación para movilidad reducida; no equivale automáticamente a discapacidad visual. Consulta también la entrada del acompañante, sin asumir que sea gratuita.',
    'disabilityEsBec':
        'Bizkaia Arena BEC! no es Bilbao Arena Miribilla. La FAQ indica consultar al canal de venta si el evento tiene localidades reservadas para movilidad reducida o admite entrada general. Los contactos del recinto son informativos; confirma tus necesidades y acompañamiento antes de comprar.',
    'disabilityEsBilbao':
        'Este contacto corresponde a Bilbao Arena Miribilla, no a Bizkaia Arena BEC!. Las condiciones cambian según el montaje y el organizador. La información sobre acompañantes en partidos de Bilbao Basket no se aplica automáticamente a conciertos; confirma las condiciones de tu evento.',
    'disabilityEsCartuja':
        'La FAQ recomienda contactar con la taquilla para elegir localidades y consultar accesibilidad. Pregunta por tus necesidades concretas y por posibles descuentos según el espectáculo. El contacto es el departamento de entradas, no una garantía de plazas disponibles.',
  };
  static const _de = {
    "disabilityAtUnknown":
        "Für diese österreichische Spielstätte liegt noch kein verifizierter Kontakt vor. Öffnen Sie die Originalveranstaltung und prüfen Sie die Hinweise zur Barrierefreiheit. Verwenden Sie keine Kontakte anderer Spielstätten.",
    "disabilityAtStadthalle":
        "Wenden Sie sich für geeignete Plätze, auch bei Sehbeeinträchtigungen, an die Halle. Rollstuhlplätze werden direkt über die Wiener Stadthalle verkauft. Bestuhlung, Ermäßigungen und Begleitplätze hängen von der Veranstaltung ab.",
    "disabilityAtKonzerthaus":
        "Das Ticket- & Service-Center vermittelt Rollstuhl- und Begleitplätze. Sonderpreise für Eigenveranstaltungen gelten nicht automatisch für Gastveranstaltungen. Der Publikumsdienst hilft bei Sehbeeinträchtigungen bis zum Sitzplatz. Assistenzhunde bitte voranmelden.",
    "disabilityAtBruckner":
        "Das Haus bietet Rollstuhl- und Begleitplätze sowie Hörunterstützung. Der allgemeine Kontakt berät zu Ihren Bedürfnissen und verweist an den zuständigen Kartenservice. Ermäßigungen und Begleitbedingungen bitte vor dem Kauf für Ihre Veranstaltung klären.",
    "disabilityAtMusikverein":
        "Die Konzertkassa betreut barrierefreie Buchungen für Eigenveranstaltungen. Bei Gastveranstaltungen gelten möglicherweise andere Bedingungen: Anbieter und Begleitung vorab klären. Assistenzhunde benötigen Voranmeldung und Nachweis. Rollstuhlermäßigungen gelten nicht automatisch bei Sehbeeinträchtigungen.",
    "disabilityAtInnsbruck":
        "Das Haus bietet taktile Orientierung, sprechende Aufzüge und Zugangsinformationen. Der allgemeine Kontakt ist keine zentrale Konzertkasse: Nutzen Sie den Anbieter Ihrer Veranstaltung. Ermäßigungen für CMI-Eigenveranstaltungen gelten nicht automatisch für Gastkonzerte.",
    "disabilityAtGraz":
        "Der offizielle Grazer Tourismusführer nennt diesen Kontakt. Plätze und Ermäßigungen hängen vom Veranstalter ab. Ein taktiles Leitsystem fehlt: Hilfe und Assistenzhund vorab absprechen. Der Kontakt dient der Information, nicht als Reservierungsbestätigung.",

    'disabilityTitle': 'Zugang für Menschen mit Behinderung',
    'disabilityHelp':
        'Barrierefreie Plätze und Regelungen für Begleitpersonen hängen von der Spielstätte und dem Veranstalter ab. Bitte informieren Sie sich vor dem Kauf bei der zuständigen Stelle.',
    'disabilityVenue': 'Spielstätte und Stadt',
    'disabilityConditions':
        'Beschreiben Sie Ihre Bedürfnisse, auch bei Blindheit oder Sehbehinderung. Rollstuhlplätze sind nicht für jede Behinderung die passende Kategorie. Klären Sie Nachweise, Begleitpersonen, Assistenzhunde, Preise und Verfügbarkeit vor dem Kauf. Sonarpad entscheidet nicht über eine Berechtigung.',
    'disabilityContactInstructions': 'Offizielle Hinweise lesen',
    'disabilityContactEmail': 'E-Mail schreiben',
    'disabilityPhone': 'Ticketservice anrufen',
    'disabilityCallContact': 'Kontaktstelle anrufen',
    'disabilityOpenEvent': 'Originalseite der Veranstaltung öffnen',
    'disabilityChooseOrganiser': 'Veranstalter oder Spielstätte auswählen',
    'disabilityChooseHelp':
        'Wählen Sie nur die tatsächliche Spielstätte oder den Veranstalter Ihrer Veranstaltung. Prüfen Sie Ort, Datum und Veranstaltung vor einer Anfrage.',
    'disabilityRequestNotice':
        'Eine Anfrage ist keine bestätigte Buchung. Sonarpad sendet keine Anfragen oder Nachweise automatisch.',
    'disabilityDeUnknown':
        'Für diese Spielstätte haben wir noch keine verifizierte Kontaktstelle. Öffnen Sie die Veranstaltungsseite und suchen Sie nach Barrierefreiheit, Schwerbehindertentickets oder Begleitpersonen. Verwenden Sie keine Kontakte einer anderen Spielstätte.',
    'disabilityDeUber':
        'Die zuständige Ticketstelle ist je nach Veranstaltung unterschiedlich. Öffnen Sie die offizielle Übersicht und suchen Sie Ihr Event mit Datum. Für ALBA BERLIN und Eisbären Berlin gelten eigene Buchungswege. Der Gästeservice für Hilfe bei der Ankunft ist keine allgemeine Ticketbuchungsstelle.',
    'disabilityDeLanxess':
        'Die Arena nennt ihren Ticket-Shop für Rollstuhltickets mit Begleitung. Bei Sehbehinderung oder anderen Bedürfnissen fragen Sie nach der passenden Kategorie und den Bedingungen für Ihr Event; eine kostenlose Begleitung wird nicht pauschal zugesichert.',
    'disabilityDeSeller':
        'Die Arena verweist beim Kartenkauf auf den jeweiligen Ticketanbieter. Klären Sie dort Ihren Platzbedarf und die Begleitung. Die offiziellen Hinweise beschreiben den Zugang zur Halle; sie bestätigen keine verfügbaren barrierefreien Tickets.',
    'disabilityDeFesthalle':
        'Eintritt und Platzkontingente legt der jeweilige Veranstalter fest, dessen Kontakt im Veranstaltungskalender steht. Die angezeigte E-Mail und Telefonnummer sind eine Info-Hotline für Barrierefreiheit, keine Zusage zur Ticketbuchung. Die Regeln für Messeveranstaltungen gelten nicht automatisch für Konzerte.',
    'disabilityDeWestfalen':
        'Die Platzierung wird für jede Veranstaltung individuell geplant. Nutzen Sie den Ticketshop oder das Ticket-Kontaktformular auf der offiziellen Seite für persönliche Beratung. Die Ränge sind nur über Treppen erreichbar.',
    'disabilityDeSap':
        'Kontaktieren Sie die Service- und Tickethotline. Für manche Konzerte verkauft ausschließlich der Veranstalter die Rollstuhlplätze; der Service nennt dann den Buchungskontakt. Klären Sie andere Bedürfnisse und Begleitplätze ebenfalls vor dem Kauf.',
    'disabilityDeMunich':
        'München Ticket berät auch Menschen mit Seh- oder Hörbehinderung. Fragen Sie zunächst, ob Ihr Event und die benötigte Kategorie dort buchbar sind. Der Barrierefrei-Shop umfasst nur eine Auswahl von Veranstaltungen und kann Registrierung mit Nachweis verlangen. Nicht jedes Event der Olympiahalle ist darüber buchbar.',
    'disabilityDeLeipzig':
        'ARENA TICKET nimmt Anfragen zu Rollstuhl- und Schwerbehindertentickets mit möglicher Begleitung entgegen. Laut FAQ ist für Begleitertickets ein Behindertenausweis mit Merkzeichen B erforderlich. Klären Sie bei anderen Nachweisen oder Bedürfnissen die Bedingungen direkt mit dem Service.',
  };
  static const _fr = {
    'disabilityTitle': 'Accès pour les personnes en situation de handicap',
    'disabilityHelp':
        'Les places adaptées et les conditions pour les accompagnateurs dépendent de la salle et de l’organisateur. Consultez leurs informations officielles avant d’acheter.',
    'disabilityVenue': 'Salle et ville',
    'disabilityConditions':
        'Précisez vos besoins, notamment en cas de handicap visuel. Les dispositifs ne concernent pas uniquement les fauteuils roulants. Vérifiez les justificatifs, les conditions et les disponibilités auprès de la billetterie.',
    'disabilityContactInstructions': 'Consulter les instructions officielles',
    'disabilityContactEmail': 'Envoyer un e-mail',
    'disabilityPhone': 'Appeler la billetterie',
    'disabilityOpenEvent': 'Ouvrir la page originale de l’événement',
    'disabilityChooseOrganiser': 'Choisir l’organisateur ou la salle',
    'disabilityChooseHelp':
        'Choisissez uniquement la salle ou l’organisateur de votre événement. Vérifiez le spectacle, la ville et la date avant de contacter la billetterie.',
    'disabilityRequestNotice':
        'Une demande ne constitue pas une réservation confirmée. Sonarpad ne transmet automatiquement aucun document ni aucune demande.',
    'disabilityFrUnknown':
        'Nous n’avons pas encore de contact vérifié pour cette salle française. Ouvrez la page originale et recherchez les informations PSH/PMR, ou choisissez la bonne salle dans la liste. N’utilisez pas les coordonnées d’une autre salle.',
    'disabilityFrPhone':
        'Accor Arena propose un service téléphonique dédié pour réserver les places adaptées et celle de l’accompagnateur. Vérifiez les conditions et les disponibilités auprès de ce service.',
    'disabilityFrStade':
        'Pour les concerts, choisissez votre événement sur le site officiel, puis « Réservation PSH ». Les réservations ne sont pas acceptées par e-mail ou téléphone. Pour le rugby, les circuits diffèrent : consultez les instructions officielles de votre événement.',
    'disabilityFrZenith':
        'Sur le site de la salle, choisissez votre spectacle, « Réserver », puis « PSH » : le contact dépend de l’événement. Les instructions distinguent les personnes en fauteuil, les personnes malentendantes et les autres besoins. Vérifiez la procédure adaptée avant d’acheter.',
  };
  static const _it = {
    "disabilityAtUnknown":
        "Non abbiamo ancora un contatto verificato per questa struttura austriaca. Apri l’evento originale e consulta le informazioni di accessibilità. Non usare contatti di altre strutture.",
    "disabilityAtStadthalle":
        "Contatta la struttura per posti adatti, anche per esigenze visive. I biglietti per carrozzina sono venduti direttamente dalla Wiener Stadthalle. Posti, sconti e accompagnatore dipendono dall’evento.",
    "disabilityAtKonzerthaus":
        "Il Ticket & Service Center gestisce posti per carrozzina e accompagnatore. Le tariffe per eventi propri non valgono automaticamente per eventi ospiti. Il personale aiuta le persone cieche a raggiungere il posto. Segnala il cane guida in anticipo.",
    "disabilityAtBruckner":
        "La struttura offre posti per carrozzina e accompagnatore e supporto uditivo. Il contatto generale indicato può consigliare e indirizzare alla biglietteria dell’evento. Conferma sconti e condizioni accompagnatore prima di acquistare.",
    "disabilityAtMusikverein":
        "La biglietteria gestisce le prenotazioni accessibili per eventi propri. Gli eventi ospiti possono avere condizioni diverse: conferma venditore e accompagnatore. Per il cane guida servono preavviso e documentazione. Gli sconti carrozzina non valgono automaticamente per disabilità visive.",
    "disabilityAtInnsbruck":
        "La struttura offre percorsi tattili, ascensori con annunci vocali e informazioni di accesso. Il contatto generale non è una biglietteria universale: usa il venditore indicato nell’evento. Gli sconti per eventi propri CMI non coprono automaticamente concerti ospiti.",
    "disabilityAtGraz":
        "La guida ufficiale del turismo di Graz indica questo contatto. Posti e sconti dipendono dall’organizzatore. Non è presente un percorso tattile per persone cieche: concorda assistenza e cane guida in anticipo. Il contatto informa, non conferma una prenotazione.",

    "disabilityGbUnknown":
        "Non abbiamo ancora un contatto verificato per questa struttura. Apri la pagina originale e consulta le istruzioni di accessibilità. Non usare contatti di un’altra struttura.",
    "disabilityGbApollo":
        "Scrivi alla struttura indicando evento, data, telefono ed esigenze. Concorda accompagnatore e posti prima di acquistare; possono essere richiesti documenti. Access Card accettata ma non obbligatoria.",
    "disabilityGbAo":
        "Biglietti accessibili tramite Ticketmaster. Contatta la struttura se le opzioni online non rispondono alle tue esigenze. Accompagnatore da concordare durante la prenotazione, con eventuali documenti: non presumere di poterlo aggiungere dopo.",
    "disabilityGbBirmingham":
        "Usa Accessible Tickets nella pagina AXS del tuo evento indicata dalla struttura. La registrazione Nimbus permette di accedere ai posti adatti. Concorda cane guida e altre esigenze prima di prenotare; disponibilità e accompagnatore dipendono dall’evento.",
    "disabilityGbLeeds":
        "Prenota tramite AXS o il servizio telefonico accessibilità. Per eventi messi in vendita da luglio 2026 serve Access Card oppure Digital Access Pass gratuito. Le vendite precedenti hanno regole documentali diverse: consulta le istruzioni per il tuo evento.",
    "disabilityGbHydro":
        "Usa Ticketmaster o il numero per prenotazioni accessibili. Chiama per esigenze visive, audiodescrizione o cane guida. Posti per carrozzina e posti ambulant rispondono a esigenze diverse. Accompagnatore e documenti seguono le condizioni della struttura.",
    "disabilityGbNottingham":
        "Usa il numero per prenotazioni accessibili o il modulo nelle istruzioni ufficiali. Sono accettati documenti alternativi ad Access Card. Le regole accompagnatore variano: le partite Nottingham Panthers non hanno la stessa gratuità della maggior parte degli eventi.",
    "disabilityGbNewcastle":
        "AXS usa Digital Access Pass gratuito o Access Card per le nuove vendite. La struttura offre anche consulenza e prenotazione telefonica, inclusa assistenza se non hai ancora il pass. Consulta i requisiti aggiornati prima di acquistare.",

    'disabilityEsUnknown':
        'Non abbiamo ancora un contatto verificato per questa struttura. Apri la pagina dell’evento e cerca accessibilità o contatta l’organizzatore. Non usare i contatti di un’altra sede.',
    'disabilityEsMovistar':
        'Per disabilità visive o uditive la struttura offre aiuto per raggiungere il posto: contatta il servizio indicato. I biglietti PMR richiedono condizioni motorie specifiche e l’accompagnatore deve avere il proprio biglietto. Non scegliere PMR solo perché sei non vedente.',
    'disabilityEsPalau':
        'Consulta le condizioni ufficiali di assistenza e accesso. Porte e servizi PMR hanno requisiti propri; per altre esigenze concorda l’aiuto con la struttura. Per posti adattati e accompagnatori rivolgiti all’organizzatore o venditore del tuo evento: la pagina non conferma una prenotazione.',
    'disabilityEsRoig':
        'L’email è il servizio generale della struttura. Verifica categoria e condizioni del tuo evento. La FAQ richiede biglietto e documentazione specifici per mobilità ridotta, che non coincide automaticamente con disabilità visiva. Verifica anche il biglietto dell’accompagnatore, senza presumere la gratuità.',
    'disabilityEsBec':
        'Bizkaia Arena BEC! è diversa da Bilbao Arena Miribilla. La FAQ invita a chiedere al venditore se l’evento prevede posti PMR o ingresso generale. I contatti della struttura sono informativi: concorda esigenze e accompagnamento prima dell’acquisto.',
    'disabilityEsBilbao':
        'Questo contatto è di Bilbao Arena Miribilla, non di Bizkaia Arena BEC!. Condizioni e servizi dipendono dall’allestimento e dall’organizzatore. Le indicazioni sugli accompagnatori alle partite del Bilbao Basket non valgono automaticamente per i concerti.',
    'disabilityEsCartuja':
        'La FAQ consiglia di contattare la biglietteria per scegliere i posti e concordare l’accessibilità. Specifica le tue esigenze e chiedi eventuali sconti per lo spettacolo. È il contatto del servizio biglietti, non una garanzia di disponibilità.',
    'disabilityCallContact': 'Chiama il servizio indicato',
    'disabilityDeUnknown':
        'Non abbiamo ancora un contatto verificato per questa struttura. Apri la pagina dell’evento e cerca Barrierefreiheit, Schwerbehindertentickets o Begleitpersonen. Non usare i contatti di un’altra sede.',
    'disabilityDeUber':
        'Il referente dei biglietti cambia secondo l’evento. Apri l’elenco ufficiale e cerca spettacolo e data. ALBA BERLIN ed Eisbären Berlin seguono canali propri. Il servizio di assistenza all’arrivo non è una biglietteria generale.',
    'disabilityDeLanxess':
        'L’arena indica la propria biglietteria per i posti in carrozzina con accompagnatore. Per non vedenti, ipovedenti o altre esigenze chiedi la categoria e le condizioni del tuo evento: la gratuità dell’accompagnatore non è garantita in generale.',
    'disabilityDeSeller':
        'L’arena invita a concordare posti e accompagnamento con il venditore del singolo evento. Le istruzioni ufficiali descrivono l’accesso alla struttura, ma non confermano la disponibilità di biglietti accessibili.',
    'disabilityDeFesthalle':
        'Ingresso e contingenti dipendono dall’organizzatore, indicato nel calendario della struttura. Email e telefono qui presenti sono un servizio informativo sull’accessibilità, non una conferma di prenotazione. Le regole delle fiere non valgono automaticamente per i concerti.',
    'disabilityDeWestfalen':
        'I posti vengono organizzati per ogni evento. Usa la biglietteria o il modulo di contatto per i biglietti dalla pagina ufficiale, per ricevere assistenza personale. Le gradinate sono raggiungibili solo tramite scale.',
    'disabilityDeSap':
        'Contatta il servizio biglietti. Per alcuni concerti i posti in carrozzina sono venduti solo dall’organizzatore: il servizio ti indica il referente. Concorda prima dell’acquisto anche altre esigenze e accompagnamento.',
    'disabilityDeMunich':
        'München Ticket assiste anche persone con disabilità visive o uditive. Verifica che il tuo evento e la categoria richiesta siano acquistabili tramite questo servizio. Il negozio accessibile copre solo alcuni eventi e può richiedere registrazione con documentazione. Non copre automaticamente ogni evento dell’Olympiahalle.',
    'disabilityDeLeipzig':
        'ARENA TICKET riceve richieste per posti in carrozzina e biglietti per persone con disabilità con eventuale accompagnatore. La FAQ richiede il contrassegno B sul documento tedesco per il biglietto dell’accompagnatore. Per documenti diversi o altre esigenze chiedi conferma al servizio.',
    'disabilityVenue': 'Struttura e città',
    'disabilityPhone': 'Chiama la biglietteria',
    'disabilityOpenEvent': 'Apri la pagina originale dell’evento',
    'disabilityFrUnknown':
        'Non abbiamo ancora un contatto verificato per questa struttura francese. Apri la pagina originale e cerca le indicazioni PSH/PMR, oppure scegli la struttura corretta nell’elenco. Non usare i contatti di un’altra sede.',
    'disabilityFrPhone':
        'Accor Arena indica un servizio telefonico dedicato per prenotare posti adatti alle proprie esigenze e per l’accompagnatore. Verifica con il servizio requisiti e disponibilità.',
    'disabilityFrStade':
        'Per i concerti, dal sito ufficiale scegli l’evento e poi «Réservation PSH». Non si prenota per email o telefono. Per il rugby il canale cambia: leggi le istruzioni ufficiali relative al tuo evento.',
    'disabilityFrZenith':
        'Sul sito della struttura scegli il tuo spettacolo, «Réserver» e poi «PSH»: il contatto dipende dall’evento. Le istruzioni distinguono persone in carrozzina, persone con disabilità uditive e altre esigenze; verifica il percorso adatto prima di acquistare.',
    'disabilityContactInstructions': 'Leggi le istruzioni ufficiali',
    'disabilityContactEmail': 'Scrivi un’email',
    'disabilityChooseOrganiser': 'Scegli organizzatore o struttura',
    'disabilityChooseHelp':
        'Scegli soltanto l’organizzatore indicato per il concerto o la struttura che lo ospita. Non tutti gli eventi seguono la stessa procedura. Le istruzioni ufficiali indicano requisiti e contatti: verifica artista, luogo e data prima di inviare una richiesta.',
    'disabilityTitle': 'Accesso per persone con disabilità',
    'disabilityHelp':
        'Le richieste di posti riservati e di accesso con accompagnatore sono gestite dall’organizzatore dell’evento. Consulta le istruzioni prima di acquistare un biglietto ordinario.',
    'disabilityOrganiser': 'Organizzatore indicato da TicketOne',
    'disabilityUnknownOrganiser':
        'L’organizzatore non è ancora stato letto. Lo trovi nelle informazioni della pagina del concerto.',
    'disabilityConditions':
        'Le condizioni dipendono dall’evento e dalle esigenze di accesso, anche per persone cieche o ipovedenti. Non tutte le richieste riguardano la carrozzina. Verifica direttamente requisiti, documenti, accompagnatore, prezzi e disponibilità: Sonarpad non determina il diritto all’agevolazione.',
    'disabilityVivoHelp':
        'Vivo Concerti indica info@vivoconcerti.com per informazioni sull’accesso. Il pulsante email apre una bozza: sarai tu a scriverla e inviarla.',
    'disabilityOfficialInstructions':
        'Leggi le istruzioni ufficiali di Vivo Concerti',
    'disabilityWriteOrganiser': 'Scrivi a Vivo Concerti',
    'disabilityCalendarHelp':
        'Mani Amiche pubblica un calendario di accrediti che comprende eventi di Vivo Concerti. Cerca lo stesso artista, città e data: il collegamento non conferma che il tuo evento sia presente o che vi siano posti. Il modulo ufficiale può richiedere certificato, dati dell’accompagnatore e verifica CAPTCHA.',
    'disabilityCalendar': 'Apri il calendario accrediti di Mani Amiche',
    'disabilityDirectory': 'Apri informazioni e contatti ufficiali TicketOne',
    'disabilityReadOrganiser':
        'Leggi l’organizzatore sulla pagina del concerto',
    'disabilityRequestNotice':
        'Una richiesta di accredito non equivale a una prenotazione confermata. Attendi la risposta del servizio competente. Sonarpad non invia richieste o documenti automaticamente.',

    'concertWelcomeTitle': 'Benvenuti nella ricerca concerti ed eventi',
    'concertWelcome1':
        'Benvenuti nella ricerca concerti ed eventi di Sonarpad. Con questa funzione potete cercare concerti, sport e altri eventi e proseguire con l’acquisto dei biglietti tramite TicketOne o il servizio indicato per l’evento.',
    'concertWelcome2':
        'L’autore, coerentemente con lo spirito di servizio di Sonarpad, non percepisce commissioni sui vostri acquisti e non utilizza codici di affiliazione.',
    'concertWelcome3':
        'Sonarpad mostra i prezzi restituiti dal servizio, senza aggiungere maggiorazioni. Prezzi e disponibilità possono cambiare: prima di pagare, controllate su TicketOne o sul servizio di vendita il totale definitivo, comprese eventuali commissioni e servizi aggiuntivi.',
    'concertWelcome4':
        'Sonarpad è un facilitatore: presenta la ricerca e la compilazione dei dati nel modo più semplice e accessibile possibile. Non vende i biglietti e non gestisce gli acquisti. Per assistenza dopo l’acquisto, modifiche, cancellazioni o rimborsi, rivolgetevi a TicketOne, al venditore o all’organizzatore indicato nella conferma dell’acquisto, secondo le condizioni del biglietto.',
    'concertWelcome5':
        'Premendo Accetta confermate di aver letto queste informazioni. La scelta sarà ricordata su questo dispositivo. Premendo Rifiuta uscirete dalla ricerca concerti ed eventi.',
    'accept': 'Accetta',
    'decline': 'Rifiuta',
    'welcomeSaveError':
        'Non è stato possibile salvare la scelta. Riprova con Accetta.',
    'otpHeading': 'Codice monouso',
    'otpComplete': 'Codice completo: tutte le sei cifre sono inserite.',
    'ticketsUnavailable': 'Biglietti attualmente non disponibili',
    'websiteTitle': 'Pagina TicketOne',
    'accessDenied':
        'Il server TicketOne ha rifiutato questa richiesta. Non posso confermare che l’operazione sia riuscita. Non invio nuovamente i dati: puoi aprire la pagina TicketOne per verificare.',
    'securityCheck':
        'TicketOne sta effettuando un controllo di sicurezza. Apri la pagina TicketOne per seguirlo o completarlo, poi torna alla modalità accessibile. L’aggiunta al carrello non è ancora confermata; non viene ripetuta automaticamente.',
    'bestSeatHelp':
        'Assegnazione automatica: scegli categoria e quantità. Per i posti numerati, TicketOne assegna i posti disponibili e mostra settore, fila e posto nel carrello, prima del pagamento.',
    'actionUncertain':
        'TicketOne non ha confermato l’esito. Non reinvio i dati: aggiorna la lettura della pagina o apri TicketOne per verificare cosa è successo.',
    'paypalContinue': 'Apri il pulsante PayPal per completare il pagamento',
    'nativeMode': 'Modalità accessibile Sonarpad',
    'nativeUnavailable':
        'Questa parte della pagina non è ancora disponibile in modalità accessibile. Puoi aggiornare la lettura o aprire la pagina TicketOne.',
    'invalidField': 'Controlla il campo:',
    'cookiesFailed':
        'Non è stato possibile chiudere il banner dei cookie. Nessun modulo inviato. Puoi riprovare o aprire TicketOne.',
    'cookieConsent':
        'Premendo un pulsante di invio o continua, Sonarpad accetta tutti i cookie della pagina e invia i dati a TicketOne.',
    'check': 'Verifica accesso TicketOne',
    'signedIn': 'Accesso a TicketOne confermato',
    'signedOut': 'Accedi o completa la registrazione sul sito TicketOne.',
    'continue': 'Continua con il concerto selezionato',
    'cart': 'Carrello TicketOne',
    'tickets': 'Biglietti',
    'total': 'Totale attuale',
    'checkout': 'Continua sul sito TicketOne con questo carrello',
    'site': 'Torna alla pagina TicketOne',
    'unavailable':
        'Non riesco a verificare la sessione. Puoi riprovare o continuare sul sito TicketOne.',
    'help':
        'La sessione rimane nel browser di Sonarpad. I controlli riconosciuti vengono presentati in modalità accessibile; per mappe dei posti e pagamenti può servire la pagina TicketOne. Nessun pagamento automatico.',
    'empty': 'Il carrello è vuoto.',
  };
  static const _en = {
    "disabilityAtUnknown":
        "No verified contact for this Austrian venue yet. Open the original event and check its accessibility information. Do not use contacts for another venue.",
    "disabilityAtStadthalle":
        "Contact the venue for suitable seats, including visual access needs. Wheelchair tickets are sold directly by Wiener Stadthalle. Seating, discounts and companion arrangements depend on the event.",
    "disabilityAtKonzerthaus":
        "The Ticket & Service Center arranges wheelchair and companion seats. Special prices for in-house events do not automatically apply to guest events. Staff can assist blind visitors to their seat. Register assistance dogs in advance.",
    "disabilityAtBruckner":
        "The venue provides wheelchair and companion places and hearing support. The listed general contact can advise on your needs and direct you to the event ticket service. Confirm discounts and companion conditions for your event before buying.",
    "disabilityAtMusikverein":
        "The box office handles accessible bookings for in-house events. Guest events may have different conditions: confirm the seller and companion arrangements first. Assistance dogs require advance registration and documentation. Wheelchair discounts do not automatically apply to visual disabilities.",
    "disabilityAtInnsbruck":
        "The venue provides tactile guidance, lifts with spoken announcements and access information. Its general contact is not a universal ticket office: use the seller listed for your event. Discounts for CMI’s own events do not automatically cover guest concerts.",
    "disabilityAtGraz":
        "The official Graz tourism accessibility guide lists this venue contact. Seating and disability discounts depend on the organiser. There is no tactile guidance system for blind visitors; discuss assistance and guide dogs in advance. The contact provides information, not a confirmed reservation.",

    "disabilityGbUnknown":
        "We do not yet have a verified contact for this venue. Open the original event page and check its accessibility instructions. Do not use another venue’s contacts.",
    "disabilityGbApollo":
        "Email the venue with event name, date, telephone number and access needs. Discuss companion tickets and suitable seating before buying; supporting evidence may be requested. An Access Card is accepted but not compulsory.",
    "disabilityGbAo":
        "Accessible tickets are sold through Ticketmaster. Ask the venue if the online options do not meet your needs. Companion tickets must be arranged when booking and may require evidence; do not buy a regular ticket assuming a companion can be added later.",
    "disabilityGbBirmingham":
        "Use the Accessible Tickets option for your event through the venue’s AXS booking page. Nimbus registration can unlock suitable seats. Discuss assistance dogs and other requirements before booking; availability and companion arrangements depend on the event.",
    "disabilityGbLeeds":
        "Book through AXS or its accessibility telephone service. Events put on sale from July 2026 require an Access Card or the free Digital Access Pass. Earlier sales have different documentation rules: follow the official instructions for your event.",
    "disabilityGbHydro":
        "Use Ticketmaster or the accessible booking line. Call for visual access needs, audio description or assistance dogs. Wheelchair and ambulant seats serve different needs. Companion tickets and supporting evidence are subject to the venue’s conditions.",
    "disabilityGbNottingham":
        "Use the accessible booking telephone line or the form linked in the official instructions. Alternative evidence is accepted without an Access Card. Companion rules vary: Nottingham Panthers games do not have the same free-companion policy as most events.",
    "disabilityGbNewcastle":
        "AXS uses the free Digital Access Pass or Access Card for new event sales. The venue also provides telephone advice and bookings, including assistance when you do not yet have a pass. Read the current event requirements before buying.",

    'disabilityEsUnknown':
        'We do not yet have a verified contact for this venue. Open the event page and look for accessibility information or contact its organiser. Do not use contacts for a different venue.',
    'disabilityEsMovistar':
        'For visual or hearing disabilities, the venue offers help reaching your seat: contact the listed service. PMR tickets have specific mobility requirements and companions need their own ticket. Do not choose PMR solely because of a visual disability.',
    'disabilityEsPalau':
        'Read the official assistance and access conditions. PMR entrances and services have specific criteria; arrange help for other needs with the venue. Ask the event organiser or seller about adapted seats and companions: this page does not confirm a reservation.',
    'disabilityEsRoig':
        'The email is the venue’s general customer service. Confirm the appropriate category and event conditions. Its FAQ requires specific tickets and documentation for reduced mobility, which is not automatically equivalent to visual disability. Check companion tickets too; do not assume free admission.',
    'disabilityEsBec':
        'Bizkaia Arena BEC! is separate from Bilbao Arena Miribilla. Its FAQ asks you to check with the seller whether the event uses reserved mobility places or general admission. Venue contacts provide information; discuss your needs and companion arrangements before buying.',
    'disabilityEsBilbao':
        'This contact is for Bilbao Arena Miribilla, not Bizkaia Arena BEC!. Conditions depend on the layout and organiser. Companion information for Bilbao Basket games does not automatically apply to concerts; confirm your event’s conditions.',
    'disabilityEsCartuja':
        'The FAQ recommends contacting the box office to choose seats and discuss accessibility. Explain your specific needs and ask about any event discounts. This is a ticket service contact, not guaranteed availability.',
    'disabilityCallContact': 'Call the listed service',
    'disabilityDeUnknown':
        'We do not yet have a verified contact for this venue. Open the event page and look for Barrierefreiheit, Schwerbehindertentickets or Begleitpersonen. Do not use contacts for a different venue.',
    'disabilityDeUber':
        'The ticket contact varies by event. Open the official directory and find your event and date. ALBA BERLIN and Eisbären Berlin have their own booking channels. The arrival assistance service is not a general ticket office.',
    'disabilityDeLanxess':
        'The arena lists its ticket office for wheelchair tickets with a companion. For visual disabilities or other needs, ask about the appropriate category and event conditions. Free companion admission is not guaranteed for everyone.',
    'disabilityDeSeller':
        'The arena asks you to discuss seating and companions with the seller for your event. The official instructions describe venue access, but do not confirm accessible ticket availability.',
    'disabilityDeFesthalle':
        'Admission and allocations are set by the event organiser, listed in the venue calendar. The email and phone shown here provide accessibility information, not confirmed ticket bookings. Trade fair rules do not automatically apply to concerts.',
    'disabilityDeWestfalen':
        'Seating is planned individually for each event. Use the ticket shop or ticket contact form on the official page for personal advice. Upper tiers are only accessible via stairs.',
    'disabilityDeSap':
        'Contact the service and ticket hotline. For some concerts only the organiser sells wheelchair places; the service will provide the booking contact. Discuss other needs and companion seats before buying.',
    'disabilityDeMunich':
        'München Ticket also assists people with visual or hearing disabilities. First confirm that your event and required category can be booked through the service. Its accessible shop covers selected events and may require registration with supporting documents. It does not cover every Olympiahalle event.',
    'disabilityDeLeipzig':
        'ARENA TICKET handles wheelchair and disability ticket enquiries, including companions where applicable. Its FAQ requires a German disability card marked B for companion tickets. Ask the service about other documents or needs.',
    'disabilityVenue': 'Venue and city',
    'disabilityPhone': 'Call the ticket office',
    'disabilityOpenEvent': 'Open the original event page',
    'disabilityFrUnknown':
        'We do not yet have a verified contact for this French venue. Open the original event page and look for PSH/PMR information, or choose the correct venue from the list. Do not use contacts for a different venue.',
    'disabilityFrPhone':
        'Accor Arena provides a dedicated telephone service to book suitable seats and a companion’s seat. Check eligibility and availability with the service.',
    'disabilityFrStade':
        'For concerts, choose your event on the official site, then “Réservation PSH”. Reservations are not accepted by email or phone. Rugby uses different channels: read the official instructions for your event.',
    'disabilityFrZenith':
        'On the venue website, choose your event, “Réserver”, then “PSH”: the contact depends on the event. Instructions distinguish wheelchair users, hearing disabilities and other needs; check the appropriate procedure before buying.',
    'disabilityContactInstructions': 'Read official instructions',
    'disabilityContactEmail': 'Write an email',
    'disabilityChooseOrganiser': 'Choose organiser or venue',
    'disabilityChooseHelp':
        'Choose only the organiser listed for your concert or the venue hosting it. Procedures vary by event. Official instructions explain requirements and contacts: check artist, venue and date before sending a request.',
    'disabilityTitle': 'Access for people with disabilities',
    'disabilityHelp':
        'Requests for reserved places and companion access are handled by the event organiser. Read the instructions before purchasing a regular ticket.',
    'disabilityOrganiser': 'Organiser listed by TicketOne',
    'disabilityUnknownOrganiser':
        'The organiser has not been read yet. You can find it in the concert page information.',
    'disabilityConditions':
        'Conditions depend on the event and access needs, including those of blind or partially sighted people. Not all requests concern wheelchairs. Check eligibility, documents, companion arrangements, prices and availability directly: Sonarpad does not decide eligibility.',
    'disabilityVivoHelp':
        'Vivo Concerti lists info@vivoconcerti.com for access enquiries. The email button opens a draft for you to write and send.',
    'disabilityOfficialInstructions':
        'Read the official Vivo Concerti instructions',
    'disabilityWriteOrganiser': 'Write to Vivo Concerti',
    'disabilityCalendarHelp':
        'Mani Amiche publishes an accreditation calendar including Vivo Concerti events. Find the same artist, city and date: this link does not confirm that your event is listed or places are available. The official form may require a certificate, companion details and a CAPTCHA.',
    'disabilityCalendar': 'Open the Mani Amiche accreditation calendar',
    'disabilityDirectory': 'Open official TicketOne information and contacts',
    'disabilityReadOrganiser': 'Read the organiser on the concert page',
    'disabilityRequestNotice':
        'An accreditation request is not a confirmed reservation. Wait for a reply from the responsible service. Sonarpad does not automatically send requests or documents.',

    'concertWelcomeTitle': 'Welcome to concert and event search',
    'concertWelcome1':
        'Welcome to Sonarpad concert and event search. You can find concerts and continue purchasing tickets through TicketOne or the service listed for the event.',
    'concertWelcome2':
        'In keeping with Sonarpad’s spirit of service, its author receives no commission on your purchases and uses no affiliate codes.',
    'concertWelcome3':
        'Sonarpad displays the prices returned by the service without adding markups. Prices and availability can change: before paying, check the final total on TicketOne or the ticket seller’s service, including any fees and optional extras.',
    'concertWelcome4':
        'Sonarpad is a facilitator: it makes searching and entering information as simple and accessible as possible. It does not sell tickets or manage purchases. For assistance, changes, cancellations or refunds after purchasing, contact TicketOne, the seller or the organiser named in your purchase confirmation, according to the ticket conditions.',
    'concertWelcome5':
        'By selecting Accept, you confirm that you have read this information. Your choice will be remembered on this device. Decline exits concert and event search.',
    'accept': 'Accept',
    'decline': 'Decline',
    'welcomeSaveError': 'Unable to save your choice. Please try Accept again.',
    'otpHeading': 'One-time code',
    'otpComplete': 'Code complete: all six digits have been entered.',
    'ticketsUnavailable': 'Tickets currently unavailable',
    'websiteTitle': 'TicketOne page',
    'accessDenied':
        'The TicketOne server denied this request. The operation cannot be confirmed. Your data will not be sent again: open the TicketOne page to check.',
    'securityCheck':
        'TicketOne is performing a security check. Open the TicketOne page to follow or complete it, then return to accessible mode. Adding tickets to the cart is not confirmed yet and will not be retried automatically.',
    'bestSeatHelp':
        'Automatic allocation: choose a category and quantity. For numbered seating, TicketOne assigns available seats and shows the section, row and seat in the cart before payment.',
    'actionUncertain':
        'TicketOne has not confirmed the result. The data will not be resent: refresh the page controls or open TicketOne to check what happened.',
    'paypalContinue': 'Open the PayPal button to complete payment',
    'nativeMode': 'Sonarpad accessible mode',
    'nativeUnavailable':
        'This part of the page is not yet available in accessible mode. Refresh the controls or open the TicketOne page.',
    'invalidField': 'Check this field:',
    'cookiesFailed':
        'Unable to close the cookie banner. No form was submitted. Retry or open TicketOne.',
    'cookieConsent':
        'Pressing a submit or continue button accepts all cookies on the page and sends the data to TicketOne.',
    'check': 'Check TicketOne sign-in',
    'signedIn': 'Signed in to TicketOne',
    'signedOut': 'Sign in or complete registration on the TicketOne website.',
    'continue': 'Continue with the selected concert',
    'cart': 'TicketOne cart',
    'tickets': 'Tickets',
    'total': 'Current total',
    'checkout': 'Continue on TicketOne with this cart',
    'site': 'Return to the TicketOne page',
    'unavailable':
        'Unable to verify the session. Retry or continue on TicketOne.',
    'help':
        'Your session stays in Sonarpad’s browser. Recognized controls are shown in accessible mode; seat maps and payment may require the TicketOne page. No automatic payment.',
    'empty': 'Your cart is empty.',
  };
}
