-- Core validation macros (core workstream). Macro section: only CREATE OR REPLACE MACRO statements, which the
-- extension registers as functions at LOAD. Tables they reference must be created in validate_schema.sql.
--
-- The loader is a port of MobilityData's CsvFileLoader, CsvFile (univocity CsvParser), RowParser,
-- DefaultTableHeaderValidator and DefaultFieldValidator. validate_load.sql runs it per file:
--   gtfs_vc_text     decoded text (gtfs_vc_decode) and the invalid_line_ending row
--   gtfs_vc_records  CSV records (gtfs_vc_parse_records), univocity semantics as the oracle's settings give them:
--                    ',' delimiter, '"' quote and escape, LF line separator, '#' comments, empty and whitespace-only
--                    lines skipped, values trimmed of chars <= ' ' outside quotes
--   gtfs_vc_header / gtfs_vc_state   header and header notices
--   gtfs_vc_rows / gtfs_vc_cells     row length checks, then one cell per row and loaded column with its typed value
--   gtfs_vc_notices  row notices, a row with an ERROR notice is not an entity
--   gtfs_v_<table>   entities (gtfs_vc_entities_<table>)

-- One row per notice code: severity, code and how many notices the last PRAGMA gtfs_validate produced.
CREATE OR REPLACE MACRO gtfs_validation_summary() AS TABLE
SELECT severity, code, count(*) AS total_notices
FROM gtfs_validation_notices
GROUP BY severity, code
ORDER BY CASE severity WHEN 'ERROR' THEN 0 WHEN 'WARNING' THEN 1 ELSE 2 END, code;

-- GENERATED-BEGIN (evidence/scratch-core3/gen.py from typed_schema.json and the oracle's Java classes)
-- java.time.ZoneId.getAvailableZoneIds() of the oracle's Java 17 (604 ids), sorted.
CREATE OR REPLACE MACRO gtfs_vc_zone_ids() AS ([
  'Africa/Abidjan', 'Africa/Accra', 'Africa/Addis_Ababa', 'Africa/Algiers', 'Africa/Asmara', 'Africa/Asmera',
  'Africa/Bamako', 'Africa/Bangui', 'Africa/Banjul', 'Africa/Bissau', 'Africa/Blantyre', 'Africa/Brazzaville',
  'Africa/Bujumbura', 'Africa/Cairo', 'Africa/Casablanca', 'Africa/Ceuta', 'Africa/Conakry', 'Africa/Dakar',
  'Africa/Dar_es_Salaam', 'Africa/Djibouti', 'Africa/Douala', 'Africa/El_Aaiun', 'Africa/Freetown', 'Africa/Gaborone',
  'Africa/Harare', 'Africa/Johannesburg', 'Africa/Juba', 'Africa/Kampala', 'Africa/Khartoum', 'Africa/Kigali',
  'Africa/Kinshasa', 'Africa/Lagos', 'Africa/Libreville', 'Africa/Lome', 'Africa/Luanda', 'Africa/Lubumbashi',
  'Africa/Lusaka', 'Africa/Malabo', 'Africa/Maputo', 'Africa/Maseru', 'Africa/Mbabane', 'Africa/Mogadishu',
  'Africa/Monrovia', 'Africa/Nairobi', 'Africa/Ndjamena', 'Africa/Niamey', 'Africa/Nouakchott', 'Africa/Ouagadougou',
  'Africa/Porto-Novo', 'Africa/Sao_Tome', 'Africa/Timbuktu', 'Africa/Tripoli', 'Africa/Tunis', 'Africa/Windhoek',
  'America/Adak', 'America/Anchorage', 'America/Anguilla', 'America/Antigua', 'America/Araguaina', 'America/Argentina/Buenos_Aires',
  'America/Argentina/Catamarca', 'America/Argentina/ComodRivadavia', 'America/Argentina/Cordoba', 'America/Argentina/Jujuy', 'America/Argentina/La_Rioja', 'America/Argentina/Mendoza',
  'America/Argentina/Rio_Gallegos', 'America/Argentina/Salta', 'America/Argentina/San_Juan', 'America/Argentina/San_Luis', 'America/Argentina/Tucuman', 'America/Argentina/Ushuaia',
  'America/Aruba', 'America/Asuncion', 'America/Atikokan', 'America/Atka', 'America/Bahia', 'America/Bahia_Banderas',
  'America/Barbados', 'America/Belem', 'America/Belize', 'America/Blanc-Sablon', 'America/Boa_Vista', 'America/Bogota',
  'America/Boise', 'America/Buenos_Aires', 'America/Cambridge_Bay', 'America/Campo_Grande', 'America/Cancun', 'America/Caracas',
  'America/Catamarca', 'America/Cayenne', 'America/Cayman', 'America/Chicago', 'America/Chihuahua', 'America/Ciudad_Juarez',
  'America/Coral_Harbour', 'America/Cordoba', 'America/Costa_Rica', 'America/Coyhaique', 'America/Creston', 'America/Cuiaba',
  'America/Curacao', 'America/Danmarkshavn', 'America/Dawson', 'America/Dawson_Creek', 'America/Denver', 'America/Detroit',
  'America/Dominica', 'America/Edmonton', 'America/Eirunepe', 'America/El_Salvador', 'America/Ensenada', 'America/Fort_Nelson',
  'America/Fort_Wayne', 'America/Fortaleza', 'America/Glace_Bay', 'America/Godthab', 'America/Goose_Bay', 'America/Grand_Turk',
  'America/Grenada', 'America/Guadeloupe', 'America/Guatemala', 'America/Guayaquil', 'America/Guyana', 'America/Halifax',
  'America/Havana', 'America/Hermosillo', 'America/Indiana/Indianapolis', 'America/Indiana/Knox', 'America/Indiana/Marengo', 'America/Indiana/Petersburg',
  'America/Indiana/Tell_City', 'America/Indiana/Vevay', 'America/Indiana/Vincennes', 'America/Indiana/Winamac', 'America/Indianapolis', 'America/Inuvik',
  'America/Iqaluit', 'America/Jamaica', 'America/Jujuy', 'America/Juneau', 'America/Kentucky/Louisville', 'America/Kentucky/Monticello',
  'America/Knox_IN', 'America/Kralendijk', 'America/La_Paz', 'America/Lima', 'America/Los_Angeles', 'America/Louisville',
  'America/Lower_Princes', 'America/Maceio', 'America/Managua', 'America/Manaus', 'America/Marigot', 'America/Martinique',
  'America/Matamoros', 'America/Mazatlan', 'America/Mendoza', 'America/Menominee', 'America/Merida', 'America/Metlakatla',
  'America/Mexico_City', 'America/Miquelon', 'America/Moncton', 'America/Monterrey', 'America/Montevideo', 'America/Montreal',
  'America/Montserrat', 'America/Nassau', 'America/New_York', 'America/Nipigon', 'America/Nome', 'America/Noronha',
  'America/North_Dakota/Beulah', 'America/North_Dakota/Center', 'America/North_Dakota/New_Salem', 'America/Nuuk', 'America/Ojinaga', 'America/Panama',
  'America/Pangnirtung', 'America/Paramaribo', 'America/Phoenix', 'America/Port-au-Prince', 'America/Port_of_Spain', 'America/Porto_Acre',
  'America/Porto_Velho', 'America/Puerto_Rico', 'America/Punta_Arenas', 'America/Rainy_River', 'America/Rankin_Inlet', 'America/Recife',
  'America/Regina', 'America/Resolute', 'America/Rio_Branco', 'America/Rosario', 'America/Santa_Isabel', 'America/Santarem',
  'America/Santiago', 'America/Santo_Domingo', 'America/Sao_Paulo', 'America/Scoresbysund', 'America/Shiprock', 'America/Sitka',
  'America/St_Barthelemy', 'America/St_Johns', 'America/St_Kitts', 'America/St_Lucia', 'America/St_Thomas', 'America/St_Vincent',
  'America/Swift_Current', 'America/Tegucigalpa', 'America/Thule', 'America/Thunder_Bay', 'America/Tijuana', 'America/Toronto',
  'America/Tortola', 'America/Vancouver', 'America/Virgin', 'America/Whitehorse', 'America/Winnipeg', 'America/Yakutat',
  'America/Yellowknife', 'Antarctica/Casey', 'Antarctica/Davis', 'Antarctica/DumontDUrville', 'Antarctica/Macquarie', 'Antarctica/Mawson',
  'Antarctica/McMurdo', 'Antarctica/Palmer', 'Antarctica/Rothera', 'Antarctica/South_Pole', 'Antarctica/Syowa', 'Antarctica/Troll',
  'Antarctica/Vostok', 'Arctic/Longyearbyen', 'Asia/Aden', 'Asia/Almaty', 'Asia/Amman', 'Asia/Anadyr',
  'Asia/Aqtau', 'Asia/Aqtobe', 'Asia/Ashgabat', 'Asia/Ashkhabad', 'Asia/Atyrau', 'Asia/Baghdad',
  'Asia/Bahrain', 'Asia/Baku', 'Asia/Bangkok', 'Asia/Barnaul', 'Asia/Beirut', 'Asia/Bishkek',
  'Asia/Brunei', 'Asia/Calcutta', 'Asia/Chita', 'Asia/Choibalsan', 'Asia/Chongqing', 'Asia/Chungking',
  'Asia/Colombo', 'Asia/Dacca', 'Asia/Damascus', 'Asia/Dhaka', 'Asia/Dili', 'Asia/Dubai',
  'Asia/Dushanbe', 'Asia/Famagusta', 'Asia/Gaza', 'Asia/Harbin', 'Asia/Hebron', 'Asia/Ho_Chi_Minh',
  'Asia/Hong_Kong', 'Asia/Hovd', 'Asia/Irkutsk', 'Asia/Istanbul', 'Asia/Jakarta', 'Asia/Jayapura',
  'Asia/Jerusalem', 'Asia/Kabul', 'Asia/Kamchatka', 'Asia/Karachi', 'Asia/Kashgar', 'Asia/Kathmandu',
  'Asia/Katmandu', 'Asia/Khandyga', 'Asia/Kolkata', 'Asia/Krasnoyarsk', 'Asia/Kuala_Lumpur', 'Asia/Kuching',
  'Asia/Kuwait', 'Asia/Macao', 'Asia/Macau', 'Asia/Magadan', 'Asia/Makassar', 'Asia/Manila',
  'Asia/Muscat', 'Asia/Nicosia', 'Asia/Novokuznetsk', 'Asia/Novosibirsk', 'Asia/Omsk', 'Asia/Oral',
  'Asia/Phnom_Penh', 'Asia/Pontianak', 'Asia/Pyongyang', 'Asia/Qatar', 'Asia/Qostanay', 'Asia/Qyzylorda',
  'Asia/Rangoon', 'Asia/Riyadh', 'Asia/Saigon', 'Asia/Sakhalin', 'Asia/Samarkand', 'Asia/Seoul',
  'Asia/Shanghai', 'Asia/Singapore', 'Asia/Srednekolymsk', 'Asia/Taipei', 'Asia/Tashkent', 'Asia/Tbilisi',
  'Asia/Tehran', 'Asia/Tel_Aviv', 'Asia/Thimbu', 'Asia/Thimphu', 'Asia/Tokyo', 'Asia/Tomsk',
  'Asia/Ujung_Pandang', 'Asia/Ulaanbaatar', 'Asia/Ulan_Bator', 'Asia/Urumqi', 'Asia/Ust-Nera', 'Asia/Vientiane',
  'Asia/Vladivostok', 'Asia/Yakutsk', 'Asia/Yangon', 'Asia/Yekaterinburg', 'Asia/Yerevan', 'Atlantic/Azores',
  'Atlantic/Bermuda', 'Atlantic/Canary', 'Atlantic/Cape_Verde', 'Atlantic/Faeroe', 'Atlantic/Faroe', 'Atlantic/Jan_Mayen',
  'Atlantic/Madeira', 'Atlantic/Reykjavik', 'Atlantic/South_Georgia', 'Atlantic/St_Helena', 'Atlantic/Stanley', 'Australia/ACT',
  'Australia/Adelaide', 'Australia/Brisbane', 'Australia/Broken_Hill', 'Australia/Canberra', 'Australia/Currie', 'Australia/Darwin',
  'Australia/Eucla', 'Australia/Hobart', 'Australia/LHI', 'Australia/Lindeman', 'Australia/Lord_Howe', 'Australia/Melbourne',
  'Australia/NSW', 'Australia/North', 'Australia/Perth', 'Australia/Queensland', 'Australia/South', 'Australia/Sydney',
  'Australia/Tasmania', 'Australia/Victoria', 'Australia/West', 'Australia/Yancowinna', 'Brazil/Acre', 'Brazil/DeNoronha',
  'Brazil/East', 'Brazil/West', 'CET', 'CST6CDT', 'Canada/Atlantic', 'Canada/Central',
  'Canada/Eastern', 'Canada/Mountain', 'Canada/Newfoundland', 'Canada/Pacific', 'Canada/Saskatchewan', 'Canada/Yukon',
  'Chile/Continental', 'Chile/EasterIsland', 'Cuba', 'EET', 'EST5EDT', 'Egypt',
  'Eire', 'Etc/GMT', 'Etc/GMT+0', 'Etc/GMT+1', 'Etc/GMT+10', 'Etc/GMT+11',
  'Etc/GMT+12', 'Etc/GMT+2', 'Etc/GMT+3', 'Etc/GMT+4', 'Etc/GMT+5', 'Etc/GMT+6',
  'Etc/GMT+7', 'Etc/GMT+8', 'Etc/GMT+9', 'Etc/GMT-0', 'Etc/GMT-1', 'Etc/GMT-10',
  'Etc/GMT-11', 'Etc/GMT-12', 'Etc/GMT-13', 'Etc/GMT-14', 'Etc/GMT-2', 'Etc/GMT-3',
  'Etc/GMT-4', 'Etc/GMT-5', 'Etc/GMT-6', 'Etc/GMT-7', 'Etc/GMT-8', 'Etc/GMT-9',
  'Etc/GMT0', 'Etc/Greenwich', 'Etc/UCT', 'Etc/UTC', 'Etc/Universal', 'Etc/Zulu',
  'Europe/Amsterdam', 'Europe/Andorra', 'Europe/Astrakhan', 'Europe/Athens', 'Europe/Belfast', 'Europe/Belgrade',
  'Europe/Berlin', 'Europe/Bratislava', 'Europe/Brussels', 'Europe/Bucharest', 'Europe/Budapest', 'Europe/Busingen',
  'Europe/Chisinau', 'Europe/Copenhagen', 'Europe/Dublin', 'Europe/Gibraltar', 'Europe/Guernsey', 'Europe/Helsinki',
  'Europe/Isle_of_Man', 'Europe/Istanbul', 'Europe/Jersey', 'Europe/Kaliningrad', 'Europe/Kiev', 'Europe/Kirov',
  'Europe/Kyiv', 'Europe/Lisbon', 'Europe/Ljubljana', 'Europe/London', 'Europe/Luxembourg', 'Europe/Madrid',
  'Europe/Malta', 'Europe/Mariehamn', 'Europe/Minsk', 'Europe/Monaco', 'Europe/Moscow', 'Europe/Nicosia',
  'Europe/Oslo', 'Europe/Paris', 'Europe/Podgorica', 'Europe/Prague', 'Europe/Riga', 'Europe/Rome',
  'Europe/Samara', 'Europe/San_Marino', 'Europe/Sarajevo', 'Europe/Saratov', 'Europe/Simferopol', 'Europe/Skopje',
  'Europe/Sofia', 'Europe/Stockholm', 'Europe/Tallinn', 'Europe/Tirane', 'Europe/Tiraspol', 'Europe/Ulyanovsk',
  'Europe/Uzhgorod', 'Europe/Vaduz', 'Europe/Vatican', 'Europe/Vienna', 'Europe/Vilnius', 'Europe/Volgograd',
  'Europe/Warsaw', 'Europe/Zagreb', 'Europe/Zaporozhye', 'Europe/Zurich', 'GB', 'GB-Eire',
  'GMT', 'GMT0', 'Greenwich', 'Hongkong', 'Iceland', 'Indian/Antananarivo',
  'Indian/Chagos', 'Indian/Christmas', 'Indian/Cocos', 'Indian/Comoro', 'Indian/Kerguelen', 'Indian/Mahe',
  'Indian/Maldives', 'Indian/Mauritius', 'Indian/Mayotte', 'Indian/Reunion', 'Iran', 'Israel',
  'Jamaica', 'Japan', 'Kwajalein', 'Libya', 'MET', 'MST7MDT',
  'Mexico/BajaNorte', 'Mexico/BajaSur', 'Mexico/General', 'NZ', 'NZ-CHAT', 'Navajo',
  'PRC', 'PST8PDT', 'Pacific/Apia', 'Pacific/Auckland', 'Pacific/Bougainville', 'Pacific/Chatham',
  'Pacific/Chuuk', 'Pacific/Easter', 'Pacific/Efate', 'Pacific/Enderbury', 'Pacific/Fakaofo', 'Pacific/Fiji',
  'Pacific/Funafuti', 'Pacific/Galapagos', 'Pacific/Gambier', 'Pacific/Guadalcanal', 'Pacific/Guam', 'Pacific/Honolulu',
  'Pacific/Johnston', 'Pacific/Kanton', 'Pacific/Kiritimati', 'Pacific/Kosrae', 'Pacific/Kwajalein', 'Pacific/Majuro',
  'Pacific/Marquesas', 'Pacific/Midway', 'Pacific/Nauru', 'Pacific/Niue', 'Pacific/Norfolk', 'Pacific/Noumea',
  'Pacific/Pago_Pago', 'Pacific/Palau', 'Pacific/Pitcairn', 'Pacific/Pohnpei', 'Pacific/Ponape', 'Pacific/Port_Moresby',
  'Pacific/Rarotonga', 'Pacific/Saipan', 'Pacific/Samoa', 'Pacific/Tahiti', 'Pacific/Tarawa', 'Pacific/Tongatapu',
  'Pacific/Truk', 'Pacific/Wake', 'Pacific/Wallis', 'Pacific/Yap', 'Poland', 'Portugal',
  'ROK', 'Singapore', 'SystemV/AST4', 'SystemV/AST4ADT', 'SystemV/CST6', 'SystemV/CST6CDT',
  'SystemV/EST5', 'SystemV/EST5EDT', 'SystemV/HST10', 'SystemV/MST7', 'SystemV/MST7MDT', 'SystemV/PST8',
  'SystemV/PST8PDT', 'SystemV/YST9', 'SystemV/YST9YDT', 'Turkey', 'UCT', 'US/Alaska',
  'US/Aleutian', 'US/Arizona', 'US/Central', 'US/East-Indiana', 'US/Eastern', 'US/Hawaii',
  'US/Indiana-Starke', 'US/Michigan', 'US/Mountain', 'US/Pacific', 'US/Samoa', 'UTC',
  'Universal', 'W-SU', 'WET', 'Zulu'
]::VARCHAR[]);
-- commons-validator DomainValidator INFRASTRUCTURE_TLDS + GENERIC_TLDS + COUNTRY_CODE_TLDS (1528).
CREATE OR REPLACE MACRO gtfs_vc_tlds() AS ([
  'aaa', 'aarp', 'abarth', 'abb', 'abbott', 'abbvie', 'abc', 'able', 'abogado', 'abudhabi', 'ac', 'academy',
  'accenture', 'accountant', 'accountants', 'aco', 'active', 'actor', 'ad', 'adac', 'ads', 'adult', 'ae', 'aeg',
  'aero', 'aetna', 'af', 'afamilycompany', 'afl', 'ag', 'agakhan', 'agency', 'ai', 'aig', 'aigo', 'airbus',
  'airforce', 'airtel', 'akdn', 'al', 'alfaromeo', 'alibaba', 'alipay', 'allfinanz', 'allstate', 'ally', 'alsace', 'alstom',
  'am', 'americanexpress', 'americanfamily', 'amex', 'amfam', 'amica', 'amsterdam', 'analytics', 'android', 'anquan', 'anz', 'ao',
  'aol', 'apartments', 'app', 'apple', 'aq', 'aquarelle', 'ar', 'aramco', 'archi', 'army', 'arpa', 'art',
  'arte', 'as', 'asda', 'asia', 'associates', 'at', 'athleta', 'attorney', 'au', 'auction', 'audi', 'audible',
  'audio', 'auspost', 'author', 'auto', 'autos', 'avianca', 'aw', 'aws', 'ax', 'axa', 'az', 'azure',
  'ba', 'baby', 'baidu', 'banamex', 'bananarepublic', 'band', 'bank', 'bar', 'barcelona', 'barclaycard', 'barclays', 'barefoot',
  'bargains', 'baseball', 'basketball', 'bauhaus', 'bayern', 'bb', 'bbc', 'bbt', 'bbva', 'bcg', 'bcn', 'bd',
  'be', 'beats', 'beauty', 'beer', 'bentley', 'berlin', 'best', 'bestbuy', 'bet', 'bf', 'bg', 'bh',
  'bharti', 'bi', 'bible', 'bid', 'bike', 'bing', 'bingo', 'bio', 'biz', 'bj', 'black', 'blackfriday',
  'blanco', 'blockbuster', 'blog', 'bloomberg', 'blue', 'bm', 'bms', 'bmw', 'bn', 'bnl', 'bnpparibas', 'bo',
  'boats', 'boehringer', 'bofa', 'bom', 'bond', 'boo', 'book', 'booking', 'boots', 'bosch', 'bostik', 'boston',
  'bot', 'boutique', 'box', 'br', 'bradesco', 'bridgestone', 'broadway', 'broker', 'brother', 'brussels', 'bs', 'bt',
  'budapest', 'bugatti', 'build', 'builders', 'business', 'buy', 'buzz', 'bv', 'bw', 'by', 'bz', 'bzh',
  'ca', 'cab', 'cafe', 'cal', 'call', 'calvinklein', 'cam', 'camera', 'camp', 'cancerresearch', 'canon', 'capetown',
  'capital', 'capitalone', 'car', 'caravan', 'cards', 'care', 'career', 'careers', 'cars', 'cartier', 'casa', 'case',
  'caseih', 'cash', 'casino', 'cat', 'catering', 'catholic', 'cba', 'cbn', 'cbre', 'cbs', 'cc', 'cd',
  'ceb', 'center', 'ceo', 'cern', 'cf', 'cfa', 'cfd', 'cg', 'ch', 'chanel', 'channel', 'chase',
  'chat', 'cheap', 'chintai', 'chloe', 'christmas', 'chrome', 'chrysler', 'church', 'ci', 'cipriani', 'circle', 'cisco',
  'citadel', 'citi', 'citic', 'city', 'cityeats', 'ck', 'cl', 'claims', 'cleaning', 'click', 'clinic', 'clinique',
  'clothing', 'cloud', 'club', 'clubmed', 'cm', 'cn', 'co', 'coach', 'codes', 'coffee', 'college', 'cologne',
  'com', 'comcast', 'commbank', 'community', 'company', 'compare', 'computer', 'comsec', 'condos', 'construction', 'consulting', 'contact',
  'contractors', 'cooking', 'cookingchannel', 'cool', 'coop', 'corsica', 'country', 'coupon', 'coupons', 'courses', 'cr', 'credit',
  'creditcard', 'creditunion', 'cricket', 'crown', 'crs', 'cruise', 'cruises', 'csc', 'cu', 'cuisinella', 'cv', 'cw',
  'cx', 'cy', 'cymru', 'cyou', 'cz', 'dabur', 'dad', 'dance', 'data', 'date', 'dating', 'datsun',
  'day', 'dclk', 'dds', 'de', 'deal', 'dealer', 'deals', 'degree', 'delivery', 'dell', 'deloitte', 'delta',
  'democrat', 'dental', 'dentist', 'desi', 'design', 'dev', 'dhl', 'diamonds', 'diet', 'digital', 'direct', 'directory',
  'discount', 'discover', 'dish', 'diy', 'dj', 'dk', 'dm', 'dnp', 'do', 'docs', 'doctor', 'dodge',
  'dog', 'doha', 'domains', 'dot', 'download', 'drive', 'dtv', 'dubai', 'duck', 'dunlop', 'duns', 'dupont',
  'durban', 'dvag', 'dvr', 'dz', 'earth', 'eat', 'ec', 'eco', 'edeka', 'edu', 'education', 'ee',
  'eg', 'email', 'emerck', 'energy', 'engineer', 'engineering', 'enterprises', 'epost', 'epson', 'equipment', 'er', 'ericsson',
  'erni', 'es', 'esq', 'estate', 'esurance', 'et', 'eu', 'eurovision', 'eus', 'events', 'everbank', 'exchange',
  'expert', 'exposed', 'express', 'extraspace', 'fage', 'fail', 'fairwinds', 'faith', 'family', 'fan', 'fans', 'farm',
  'farmers', 'fashion', 'fast', 'fedex', 'feedback', 'ferrari', 'ferrero', 'fi', 'fiat', 'fidelity', 'fido', 'film',
  'final', 'finance', 'financial', 'fire', 'firestone', 'firmdale', 'fish', 'fishing', 'fit', 'fitness', 'fj', 'fk',
  'flickr', 'flights', 'flir', 'florist', 'flowers', 'fly', 'fm', 'fo', 'foo', 'food', 'foodnetwork', 'football',
  'ford', 'forex', 'forsale', 'forum', 'foundation', 'fox', 'fr', 'free', 'fresenius', 'frl', 'frogans', 'frontdoor',
  'frontier', 'ftr', 'fujitsu', 'fujixerox', 'fun', 'fund', 'furniture', 'futbol', 'fyi', 'ga', 'gal', 'gallery',
  'gallo', 'gallup', 'game', 'games', 'gap', 'garden', 'gb', 'gbiz', 'gd', 'gdn', 'ge', 'gea',
  'gent', 'genting', 'george', 'gf', 'gg', 'ggee', 'gh', 'gi', 'gift', 'gifts', 'gives', 'giving',
  'gl', 'glade', 'glass', 'gle', 'global', 'globo', 'gm', 'gmail', 'gmbh', 'gmo', 'gmx', 'gn',
  'godaddy', 'gold', 'goldpoint', 'golf', 'goo', 'goodhands', 'goodyear', 'goog', 'google', 'gop', 'got', 'gov',
  'gp', 'gq', 'gr', 'grainger', 'graphics', 'gratis', 'green', 'gripe', 'group', 'gs', 'gt', 'gu',
  'guardian', 'gucci', 'guge', 'guide', 'guitars', 'guru', 'gw', 'gy', 'hair', 'hamburg', 'hangout', 'haus',
  'hbo', 'hdfc', 'hdfcbank', 'health', 'healthcare', 'help', 'helsinki', 'here', 'hermes', 'hgtv', 'hiphop', 'hisamitsu',
  'hitachi', 'hiv', 'hk', 'hkt', 'hm', 'hn', 'hockey', 'holdings', 'holiday', 'homedepot', 'homegoods', 'homes',
  'homesense', 'honda', 'honeywell', 'horse', 'hospital', 'host', 'hosting', 'hot', 'hoteles', 'hotmail', 'house', 'how',
  'hr', 'hsbc', 'ht', 'htc', 'hu', 'hughes', 'hyatt', 'hyundai', 'ibm', 'icbc', 'ice', 'icu',
  'id', 'ie', 'ieee', 'ifm', 'ikano', 'il', 'im', 'imamat', 'imdb', 'immo', 'immobilien', 'in',
  'industries', 'infiniti', 'info', 'ing', 'ink', 'institute', 'insurance', 'insure', 'int', 'intel', 'international', 'intuit',
  'investments', 'io', 'ipiranga', 'iq', 'ir', 'irish', 'is', 'iselect', 'ismaili', 'ist', 'istanbul', 'it',
  'itau', 'itv', 'iveco', 'iwc', 'jaguar', 'java', 'jcb', 'jcp', 'je', 'jeep', 'jetzt', 'jewelry',
  'jio', 'jlc', 'jll', 'jm', 'jmp', 'jnj', 'jo', 'jobs', 'joburg', 'jot', 'joy', 'jp',
  'jpmorgan', 'jprs', 'juegos', 'juniper', 'kaufen', 'kddi', 'ke', 'kerryhotels', 'kerrylogistics', 'kerryproperties', 'kfh', 'kg',
  'kh', 'ki', 'kia', 'kim', 'kinder', 'kindle', 'kitchen', 'kiwi', 'km', 'kn', 'koeln', 'komatsu',
  'kosher', 'kp', 'kpmg', 'kpn', 'kr', 'krd', 'kred', 'kuokgroup', 'kw', 'ky', 'kyoto', 'kz',
  'la', 'lacaixa', 'ladbrokes', 'lamborghini', 'lamer', 'lancaster', 'lancia', 'lancome', 'land', 'landrover', 'lanxess', 'lasalle',
  'lat', 'latino', 'latrobe', 'law', 'lawyer', 'lb', 'lc', 'lds', 'lease', 'leclerc', 'lefrak', 'legal',
  'lego', 'lexus', 'lgbt', 'li', 'liaison', 'lidl', 'life', 'lifeinsurance', 'lifestyle', 'lighting', 'like', 'lilly',
  'limited', 'limo', 'lincoln', 'linde', 'link', 'lipsy', 'live', 'living', 'lixil', 'lk', 'loan', 'loans',
  'locker', 'locus', 'loft', 'lol', 'london', 'lotte', 'lotto', 'love', 'lpl', 'lplfinancial', 'lr', 'ls',
  'lt', 'ltd', 'ltda', 'lu', 'lundbeck', 'lupin', 'luxe', 'luxury', 'lv', 'ly', 'ma', 'macys',
  'madrid', 'maif', 'maison', 'makeup', 'man', 'management', 'mango', 'market', 'marketing', 'markets', 'marriott', 'marshalls',
  'maserati', 'mattel', 'mba', 'mc', 'mcd', 'mcdonalds', 'mckinsey', 'md', 'me', 'med', 'media', 'meet',
  'melbourne', 'meme', 'memorial', 'men', 'menu', 'meo', 'metlife', 'mg', 'mh', 'miami', 'microsoft', 'mil',
  'mini', 'mint', 'mit', 'mitsubishi', 'mk', 'ml', 'mlb', 'mls', 'mm', 'mma', 'mn', 'mo',
  'mobi', 'mobile', 'mobily', 'moda', 'moe', 'moi', 'mom', 'monash', 'money', 'monster', 'montblanc', 'mopar',
  'mormon', 'mortgage', 'moscow', 'moto', 'motorcycles', 'mov', 'movie', 'movistar', 'mp', 'mq', 'mr', 'ms',
  'msd', 'mt', 'mtn', 'mtpc', 'mtr', 'mu', 'museum', 'mutual', 'mv', 'mw', 'mx', 'my',
  'mz', 'na', 'nab', 'nadex', 'nagoya', 'name', 'nationwide', 'natura', 'navy', 'nba', 'nc', 'ne',
  'nec', 'net', 'netbank', 'netflix', 'network', 'neustar', 'new', 'newholland', 'news', 'next', 'nextdirect', 'nexus',
  'nf', 'nfl', 'ng', 'ngo', 'nhk', 'ni', 'nico', 'nike', 'nikon', 'ninja', 'nissan', 'nissay',
  'nl', 'no', 'nokia', 'northwesternmutual', 'norton', 'now', 'nowruz', 'nowtv', 'np', 'nr', 'nra', 'nrw',
  'ntt', 'nu', 'nyc', 'nz', 'obi', 'observer', 'off', 'office', 'okinawa', 'olayan', 'olayangroup', 'oldnavy',
  'ollo', 'om', 'omega', 'one', 'ong', 'onl', 'online', 'onyourside', 'ooo', 'open', 'oracle', 'orange',
  'org', 'organic', 'orientexpress', 'origins', 'osaka', 'otsuka', 'ott', 'ovh', 'pa', 'page', 'pamperedchef', 'panasonic',
  'panerai', 'paris', 'pars', 'partners', 'parts', 'party', 'passagens', 'pay', 'pccw', 'pe', 'pet', 'pf',
  'pfizer', 'pg', 'ph', 'pharmacy', 'philips', 'phone', 'photo', 'photography', 'photos', 'physio', 'piaget', 'pics',
  'pictet', 'pictures', 'pid', 'pin', 'ping', 'pink', 'pioneer', 'pizza', 'pk', 'pl', 'place', 'play',
  'playstation', 'plumbing', 'plus', 'pm', 'pn', 'pnc', 'pohl', 'poker', 'politie', 'porn', 'post', 'pr',
  'pramerica', 'praxi', 'press', 'prime', 'pro', 'prod', 'productions', 'prof', 'progressive', 'promo', 'properties', 'property',
  'protection', 'pru', 'prudential', 'ps', 'pt', 'pub', 'pw', 'pwc', 'py', 'qa', 'qpon', 'quebec',
  'quest', 'qvc', 'racing', 'radio', 'raid', 're', 'read', 'realestate', 'realtor', 'realty', 'recipes', 'red',
  'redstone', 'redumbrella', 'rehab', 'reise', 'reisen', 'reit', 'reliance', 'ren', 'rent', 'rentals', 'repair', 'report',
  'republican', 'rest', 'restaurant', 'review', 'reviews', 'rexroth', 'rich', 'richardli', 'ricoh', 'rightathome', 'ril', 'rio',
  'rip', 'rmit', 'ro', 'rocher', 'rocks', 'rodeo', 'rogers', 'room', 'rs', 'rsvp', 'ru', 'ruhr',
  'run', 'rw', 'rwe', 'ryukyu', 'sa', 'saarland', 'safe', 'safety', 'sakura', 'sale', 'salon', 'samsclub',
  'samsung', 'sandvik', 'sandvikcoromant', 'sanofi', 'sap', 'sapo', 'sarl', 'sas', 'save', 'saxo', 'sb', 'sbi',
  'sbs', 'sc', 'sca', 'scb', 'schaeffler', 'schmidt', 'scholarships', 'school', 'schule', 'schwarz', 'science', 'scjohnson',
  'scor', 'scot', 'sd', 'se', 'seat', 'secure', 'security', 'seek', 'select', 'sener', 'services', 'ses',
  'seven', 'sew', 'sex', 'sexy', 'sfr', 'sg', 'sh', 'shangrila', 'sharp', 'shaw', 'shell', 'shia',
  'shiksha', 'shoes', 'shop', 'shopping', 'shouji', 'show', 'showtime', 'shriram', 'si', 'silk', 'sina', 'singles',
  'site', 'sj', 'sk', 'ski', 'skin', 'sky', 'skype', 'sl', 'sling', 'sm', 'smart', 'smile',
  'sn', 'sncf', 'so', 'soccer', 'social', 'softbank', 'software', 'sohu', 'solar', 'solutions', 'song', 'sony',
  'soy', 'space', 'spiegel', 'spot', 'spreadbetting', 'sr', 'srl', 'srt', 'st', 'stada', 'staples', 'star',
  'starhub', 'statebank', 'statefarm', 'statoil', 'stc', 'stcgroup', 'stockholm', 'storage', 'store', 'stream', 'studio', 'study',
  'style', 'su', 'sucks', 'supplies', 'supply', 'support', 'surf', 'surgery', 'suzuki', 'sv', 'swatch', 'swiftcover',
  'swiss', 'sx', 'sy', 'sydney', 'symantec', 'systems', 'sz', 'tab', 'taipei', 'talk', 'taobao', 'target',
  'tatamotors', 'tatar', 'tattoo', 'tax', 'taxi', 'tc', 'tci', 'td', 'tdk', 'team', 'tech', 'technology',
  'tel', 'telecity', 'telefonica', 'temasek', 'tennis', 'teva', 'tf', 'tg', 'th', 'thd', 'theater', 'theatre',
  'tiaa', 'tickets', 'tienda', 'tiffany', 'tips', 'tires', 'tirol', 'tj', 'tjmaxx', 'tjx', 'tk', 'tkmaxx',
  'tl', 'tm', 'tmall', 'tn', 'to', 'today', 'tokyo', 'tools', 'top', 'toray', 'toshiba', 'total',
  'tours', 'town', 'toyota', 'toys', 'tr', 'trade', 'trading', 'training', 'travel', 'travelchannel', 'travelers', 'travelersinsurance',
  'trust', 'trv', 'tt', 'tube', 'tui', 'tunes', 'tushu', 'tv', 'tvs', 'tw', 'tz', 'ua',
  'ubank', 'ubs', 'uconnect', 'ug', 'uk', 'unicom', 'university', 'uno', 'uol', 'ups', 'us', 'uy',
  'uz', 'va', 'vacations', 'vana', 'vanguard', 'vc', 've', 'vegas', 'ventures', 'verisign', 'versicherung', 'vet',
  'vg', 'vi', 'viajes', 'video', 'vig', 'viking', 'villas', 'vin', 'vip', 'virgin', 'visa', 'vision',
  'vista', 'vistaprint', 'viva', 'vivo', 'vlaanderen', 'vn', 'vodka', 'volkswagen', 'volvo', 'vote', 'voting', 'voto',
  'voyage', 'vu', 'vuelos', 'wales', 'walmart', 'walter', 'wang', 'wanggou', 'warman', 'watch', 'watches', 'weather',
  'weatherchannel', 'webcam', 'weber', 'website', 'wed', 'wedding', 'weibo', 'weir', 'wf', 'whoswho', 'wien', 'wiki',
  'williamhill', 'win', 'windows', 'wine', 'winners', 'wme', 'wolterskluwer', 'woodside', 'work', 'works', 'world', 'wow',
  'ws', 'wtc', 'wtf', 'xbox', 'xerox', 'xfinity', 'xihuan', 'xin', 'xn--11b4c3d', 'xn--1ck2e1b', 'xn--1qqw23a', 'xn--30rr7y',
  'xn--3bst00m', 'xn--3ds443g', 'xn--3e0b707e', 'xn--3oq18vl8pn36a', 'xn--3pxu8k', 'xn--42c2d9a', 'xn--45brj9c', 'xn--45q11c', 'xn--4gbrim', 'xn--54b7fta0cc', 'xn--55qw42g', 'xn--55qx5d',
  'xn--5su34j936bgsg', 'xn--5tzm5g', 'xn--6frz82g', 'xn--6qq986b3xl', 'xn--80adxhks', 'xn--80ao21a', 'xn--80aqecdr1a', 'xn--80asehdb', 'xn--80aswg', 'xn--8y0a063a', 'xn--90a3ac', 'xn--90ae',
  'xn--90ais', 'xn--9dbq2a', 'xn--9et52u', 'xn--9krt00a', 'xn--b4w605ferd', 'xn--bck1b9a5dre4c', 'xn--c1avg', 'xn--c2br7g', 'xn--cck2b3b', 'xn--cg4bki', 'xn--clchc0ea0b2g2a9gcd', 'xn--czr694b',
  'xn--czrs0t', 'xn--czru2d', 'xn--d1acj3b', 'xn--d1alf', 'xn--e1a4c', 'xn--eckvdtc9d', 'xn--efvy88h', 'xn--estv75g', 'xn--fct429k', 'xn--fhbei', 'xn--fiq228c5hs', 'xn--fiq64b',
  'xn--fiqs8s', 'xn--fiqz9s', 'xn--fjq720a', 'xn--flw351e', 'xn--fpcrj9c3d', 'xn--fzc2c9e2c', 'xn--fzys8d69uvgm', 'xn--g2xx48c', 'xn--gckr3f0f', 'xn--gecrj9c', 'xn--gk3at1e', 'xn--h2brj9c',
  'xn--hxt814e', 'xn--i1b6b1a6a2e', 'xn--imr513n', 'xn--io0a7i', 'xn--j1aef', 'xn--j1amh', 'xn--j6w193g', 'xn--jlq61u9w7b', 'xn--jvr189m', 'xn--kcrx77d1x4a', 'xn--kprw13d', 'xn--kpry57d',
  'xn--kpu716f', 'xn--kput3i', 'xn--l1acc', 'xn--lgbbat1ad8j', 'xn--mgb9awbf', 'xn--mgba3a3ejt', 'xn--mgba3a4f16a', 'xn--mgba7c0bbn0a', 'xn--mgbaam7a8h', 'xn--mgbab2bd', 'xn--mgbayh7gpa', 'xn--mgbb9fbpob',
  'xn--mgbbh1a71e', 'xn--mgbc0a9azcg', 'xn--mgbca7dzdo', 'xn--mgberp4a5d4ar', 'xn--mgbi4ecexp', 'xn--mgbpl2fh', 'xn--mgbt3dhd', 'xn--mgbtx2b', 'xn--mgbx4cd0ab', 'xn--mix891f', 'xn--mk1bu44c', 'xn--mxtq1m',
  'xn--ngbc5azd', 'xn--ngbe9e0a', 'xn--node', 'xn--nqv7f', 'xn--nqv7fs00ema', 'xn--nyqy26a', 'xn--o3cw4h', 'xn--ogbpf8fl', 'xn--p1acf', 'xn--p1ai', 'xn--pbt977c', 'xn--pgbs0dh',
  'xn--pssy2u', 'xn--q9jyb4c', 'xn--qcka1pmc', 'xn--qxam', 'xn--rhqv96g', 'xn--rovu88b', 'xn--s9brj9c', 'xn--ses554g', 'xn--t60b56a', 'xn--tckwe', 'xn--tiq49xqyj', 'xn--unup4y',
  'xn--vermgensberater-ctb', 'xn--vermgensberatung-pwb', 'xn--vhquv', 'xn--vuq861b', 'xn--w4r85el8fhu5dnra', 'xn--w4rs40l', 'xn--wgbh1c', 'xn--wgbl6a', 'xn--xhq521b', 'xn--xkc2al3hye2a', 'xn--xkc2dl3a5ee0h', 'xn--y9a3aq',
  'xn--yfro4i67o', 'xn--ygbi2ammx', 'xn--zfr164b', 'xperia', 'xxx', 'xyz', 'yachts', 'yahoo', 'yamaxun', 'yandex', 'ye', 'yodobashi',
  'yoga', 'yokohama', 'you', 'youtube', 'yt', 'yun', 'za', 'zappos', 'zara', 'zero', 'zip', 'zippo',
  'zm', 'zone', 'zuerich', 'zw'
]::VARCHAR[]);
-- Loader facts per column (Gtfs*Schema.java via typed_schema.json): schema order, kind, Java type,
-- FieldLevelEnum (REQUIRED = @Required, which also makes the header column required; RECOMMENDED =
-- @Recommended) and RowParser.NumberBounds.
CREATE OR REPLACE MACRO gtfs_vc_schema() AS TABLE
SELECT * FROM (VALUES
  ('stops.txt', 1, 'stop_id', 'id', 'String', 'REQUIRED', NULL),
  ('stops.txt', 2, 'stop_code', 'text', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 3, 'stop_name', 'text', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 4, 'tts_stop_name', 'text', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 5, 'stop_desc', 'text', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 6, 'stop_lat', 'latitude', 'double', 'OPTIONAL', NULL),
  ('stops.txt', 7, 'stop_lon', 'longitude', 'double', 'OPTIONAL', NULL),
  ('stops.txt', 8, 'zone_id', 'id', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 9, 'stop_url', 'url', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 10, 'location_type', 'enum', 'GtfsLocationType', 'OPTIONAL', NULL),
  ('stops.txt', 11, 'parent_station', 'id', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 12, 'stop_timezone', 'timezone', 'ZoneId', 'OPTIONAL', NULL),
  ('stops.txt', 13, 'wheelchair_boarding', 'enum', 'GtfsWheelchairBoarding', 'OPTIONAL', NULL),
  ('stops.txt', 14, 'level_id', 'id', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 15, 'platform_code', 'text', 'String', 'OPTIONAL', NULL),
  ('stops.txt', 16, 'stop_access', 'enum', 'GtfsStopAccess', 'OPTIONAL', NULL),
  ('pathways.txt', 1, 'pathway_id', 'id', 'String', 'REQUIRED', NULL),
  ('pathways.txt', 2, 'from_stop_id', 'id', 'String', 'REQUIRED', NULL),
  ('pathways.txt', 3, 'to_stop_id', 'id', 'String', 'REQUIRED', NULL),
  ('pathways.txt', 4, 'pathway_mode', 'enum', 'GtfsPathwayMode', 'REQUIRED', NULL),
  ('pathways.txt', 5, 'is_bidirectional', 'enum', 'GtfsPathwayIsBidirectional', 'REQUIRED', NULL),
  ('pathways.txt', 6, 'length', 'float', 'double', 'OPTIONAL', 'NON_NEGATIVE'),
  ('pathways.txt', 7, 'traversal_time', 'integer', 'int', 'OPTIONAL', 'POSITIVE'),
  ('pathways.txt', 8, 'stair_count', 'integer', 'int', 'OPTIONAL', 'NON_ZERO'),
  ('pathways.txt', 9, 'max_slope', 'float', 'double', 'OPTIONAL', NULL),
  ('pathways.txt', 10, 'min_width', 'float', 'double', 'OPTIONAL', 'POSITIVE'),
  ('pathways.txt', 11, 'signposted_as', 'text', 'String', 'OPTIONAL', NULL),
  ('pathways.txt', 12, 'reversed_signposted_as', 'text', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 1, 'route_id', 'id', 'String', 'REQUIRED', NULL),
  ('routes.txt', 2, 'agency_id', 'id', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 3, 'route_short_name', 'text', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 4, 'route_long_name', 'text', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 5, 'route_desc', 'text', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 6, 'route_type', 'enum', 'GtfsRouteType', 'REQUIRED', NULL),
  ('routes.txt', 7, 'route_url', 'url', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 8, 'route_color', 'color', 'GtfsColor', 'OPTIONAL', NULL),
  ('routes.txt', 9, 'route_text_color', 'color', 'GtfsColor', 'OPTIONAL', NULL),
  ('routes.txt', 10, 'route_sort_order', 'integer', 'int', 'OPTIONAL', 'NON_NEGATIVE'),
  ('routes.txt', 11, 'continuous_pickup', 'enum', 'GtfsContinuousPickupDropOff', 'OPTIONAL', NULL),
  ('routes.txt', 12, 'continuous_drop_off', 'enum', 'GtfsContinuousPickupDropOff', 'OPTIONAL', NULL),
  ('routes.txt', 13, 'network_id', 'id', 'String', 'OPTIONAL', NULL),
  ('routes.txt', 14, 'cemv_support', 'enum', 'GtfsContactlessEmvSupport', 'OPTIONAL', NULL),
  ('trips.txt', 1, 'trip_id', 'id', 'String', 'REQUIRED', NULL),
  ('trips.txt', 2, 'route_id', 'id', 'String', 'REQUIRED', NULL),
  ('trips.txt', 3, 'service_id', 'id', 'String', 'REQUIRED', NULL),
  ('trips.txt', 4, 'trip_headsign', 'text', 'String', 'RECOMMENDED', NULL),
  ('trips.txt', 5, 'trip_short_name', 'text', 'String', 'OPTIONAL', NULL),
  ('trips.txt', 6, 'direction_id', 'enum', 'GtfsTripDirectionId', 'OPTIONAL', NULL),
  ('trips.txt', 7, 'block_id', 'id', 'String', 'OPTIONAL', NULL),
  ('trips.txt', 8, 'shape_id', 'id', 'String', 'OPTIONAL', NULL),
  ('trips.txt', 9, 'wheelchair_accessible', 'enum', 'GtfsWheelchairBoarding', 'OPTIONAL', NULL),
  ('trips.txt', 10, 'bikes_allowed', 'enum', 'GtfsBikesAllowed', 'OPTIONAL', NULL),
  ('trips.txt', 11, 'cars_allowed', 'enum', 'GtfsCarsAllowed', 'OPTIONAL', NULL),
  ('trips.txt', 12, 'safe_duration_factor', 'float', 'double', 'OPTIONAL', NULL),
  ('trips.txt', 13, 'safe_duration_offset', 'float', 'double', 'OPTIONAL', NULL),
  ('stop_times.txt', 1, 'trip_id', 'id', 'String', 'REQUIRED', NULL),
  ('stop_times.txt', 2, 'arrival_time', 'time', 'GtfsTime', 'OPTIONAL', NULL),
  ('stop_times.txt', 3, 'departure_time', 'time', 'GtfsTime', 'OPTIONAL', NULL),
  ('stop_times.txt', 4, 'stop_id', 'id', 'String', 'OPTIONAL', NULL),
  ('stop_times.txt', 5, 'location_group_id', 'id', 'String', 'OPTIONAL', NULL),
  ('stop_times.txt', 6, 'location_id', 'id', 'String', 'OPTIONAL', NULL),
  ('stop_times.txt', 7, 'stop_sequence', 'integer', 'int', 'REQUIRED', 'NON_NEGATIVE'),
  ('stop_times.txt', 8, 'stop_headsign', 'text', 'String', 'OPTIONAL', NULL),
  ('stop_times.txt', 9, 'start_pickup_drop_off_window', 'time', 'GtfsTime', 'OPTIONAL', NULL),
  ('stop_times.txt', 10, 'end_pickup_drop_off_window', 'time', 'GtfsTime', 'OPTIONAL', NULL),
  ('stop_times.txt', 11, 'pickup_type', 'enum', 'GtfsPickupDropOff', 'OPTIONAL', NULL),
  ('stop_times.txt', 12, 'drop_off_type', 'enum', 'GtfsPickupDropOff', 'OPTIONAL', NULL),
  ('stop_times.txt', 13, 'continuous_pickup', 'enum', 'GtfsContinuousPickupDropOff', 'OPTIONAL', NULL),
  ('stop_times.txt', 14, 'continuous_drop_off', 'enum', 'GtfsContinuousPickupDropOff', 'OPTIONAL', NULL),
  ('stop_times.txt', 15, 'shape_dist_traveled', 'float', 'double', 'OPTIONAL', 'NON_NEGATIVE'),
  ('stop_times.txt', 16, 'timepoint', 'enum', 'GtfsStopTimeTimepoint', 'OPTIONAL', NULL),
  ('stop_times.txt', 17, 'pickup_booking_rule_id', 'id', 'String', 'OPTIONAL', NULL),
  ('stop_times.txt', 18, 'drop_off_booking_rule_id', 'id', 'String', 'OPTIONAL', NULL),
  ('shapes.txt', 1, 'shape_id', 'id', 'String', 'REQUIRED', NULL),
  ('shapes.txt', 2, 'shape_pt_lat', 'latitude', 'double', 'REQUIRED', NULL),
  ('shapes.txt', 3, 'shape_pt_lon', 'longitude', 'double', 'REQUIRED', NULL),
  ('shapes.txt', 4, 'shape_pt_sequence', 'integer', 'int', 'REQUIRED', 'NON_NEGATIVE'),
  ('shapes.txt', 5, 'shape_dist_traveled', 'float', 'double', 'OPTIONAL', 'NON_NEGATIVE'),
  ('calendar.txt', 1, 'service_id', 'id', 'String', 'REQUIRED', NULL),
  ('calendar.txt', 2, 'monday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 3, 'tuesday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 4, 'wednesday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 5, 'thursday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 6, 'friday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 7, 'saturday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 8, 'sunday', 'enum', 'GtfsCalendarService', 'REQUIRED', NULL),
  ('calendar.txt', 9, 'start_date', 'date', 'GtfsDate', 'REQUIRED', NULL),
  ('calendar.txt', 10, 'end_date', 'date', 'GtfsDate', 'REQUIRED', NULL),
  ('calendar_dates.txt', 1, 'service_id', 'id', 'String', 'REQUIRED', NULL),
  ('calendar_dates.txt', 2, 'date', 'date', 'GtfsDate', 'REQUIRED', NULL),
  ('calendar_dates.txt', 3, 'exception_type', 'enum', 'GtfsCalendarDateExceptionType', 'REQUIRED', NULL)
) s(filename, col_ord, column_name, kind, java_type, level, bounds);
-- Entities of stops.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_stops() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS stop_id,
  max(c.v) FILTER (WHERE c.col_ord = 2)::VARCHAR AS stop_code,
  max(c.v) FILTER (WHERE c.col_ord = 3)::VARCHAR AS stop_name,
  max(c.v) FILTER (WHERE c.col_ord = 4)::VARCHAR AS tts_stop_name,
  max(c.v) FILTER (WHERE c.col_ord = 5)::VARCHAR AS stop_desc,
  max(c.vd) FILTER (WHERE c.col_ord = 6)::DOUBLE AS stop_lat,
  max(c.vd) FILTER (WHERE c.col_ord = 7)::DOUBLE AS stop_lon,
  max(c.v) FILTER (WHERE c.col_ord = 8)::VARCHAR AS zone_id,
  max(c.v) FILTER (WHERE c.col_ord = 9)::VARCHAR AS stop_url,
  max(c.vi) FILTER (WHERE c.col_ord = 10)::INTEGER AS location_type,
  max(c.v) FILTER (WHERE c.col_ord = 11)::VARCHAR AS parent_station,
  max(c.v) FILTER (WHERE c.col_ord = 12)::VARCHAR AS stop_timezone,
  max(c.vi) FILTER (WHERE c.col_ord = 13)::INTEGER AS wheelchair_boarding,
  max(c.v) FILTER (WHERE c.col_ord = 14)::VARCHAR AS level_id,
  max(c.v) FILTER (WHERE c.col_ord = 15)::VARCHAR AS platform_code,
  max(c.vi) FILTER (WHERE c.col_ord = 16)::INTEGER AS stop_access
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of pathways.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_pathways() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS pathway_id,
  max(c.v) FILTER (WHERE c.col_ord = 2)::VARCHAR AS from_stop_id,
  max(c.v) FILTER (WHERE c.col_ord = 3)::VARCHAR AS to_stop_id,
  max(c.vi) FILTER (WHERE c.col_ord = 4)::INTEGER AS pathway_mode,
  max(c.vi) FILTER (WHERE c.col_ord = 5)::INTEGER AS is_bidirectional,
  max(c.vd) FILTER (WHERE c.col_ord = 6)::DOUBLE AS length,
  max(c.vi) FILTER (WHERE c.col_ord = 7)::INTEGER AS traversal_time,
  max(c.vi) FILTER (WHERE c.col_ord = 8)::INTEGER AS stair_count,
  max(c.vd) FILTER (WHERE c.col_ord = 9)::DOUBLE AS max_slope,
  max(c.vd) FILTER (WHERE c.col_ord = 10)::DOUBLE AS min_width,
  max(c.v) FILTER (WHERE c.col_ord = 11)::VARCHAR AS signposted_as,
  max(c.v) FILTER (WHERE c.col_ord = 12)::VARCHAR AS reversed_signposted_as
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of routes.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_routes() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS route_id,
  max(c.v) FILTER (WHERE c.col_ord = 2)::VARCHAR AS agency_id,
  max(c.v) FILTER (WHERE c.col_ord = 3)::VARCHAR AS route_short_name,
  max(c.v) FILTER (WHERE c.col_ord = 4)::VARCHAR AS route_long_name,
  max(c.v) FILTER (WHERE c.col_ord = 5)::VARCHAR AS route_desc,
  max(c.vi) FILTER (WHERE c.col_ord = 6)::INTEGER AS route_type,
  max(c.v) FILTER (WHERE c.col_ord = 7)::VARCHAR AS route_url,
  max(c.vi) FILTER (WHERE c.col_ord = 8)::INTEGER AS route_color,
  max(c.vi) FILTER (WHERE c.col_ord = 9)::INTEGER AS route_text_color,
  max(c.vi) FILTER (WHERE c.col_ord = 10)::INTEGER AS route_sort_order,
  max(c.vi) FILTER (WHERE c.col_ord = 11)::INTEGER AS continuous_pickup,
  max(c.vi) FILTER (WHERE c.col_ord = 12)::INTEGER AS continuous_drop_off,
  max(c.v) FILTER (WHERE c.col_ord = 13)::VARCHAR AS network_id,
  max(c.vi) FILTER (WHERE c.col_ord = 14)::INTEGER AS cemv_support
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of trips.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_trips() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS trip_id,
  max(c.v) FILTER (WHERE c.col_ord = 2)::VARCHAR AS route_id,
  max(c.v) FILTER (WHERE c.col_ord = 3)::VARCHAR AS service_id,
  max(c.v) FILTER (WHERE c.col_ord = 4)::VARCHAR AS trip_headsign,
  max(c.v) FILTER (WHERE c.col_ord = 5)::VARCHAR AS trip_short_name,
  max(c.vi) FILTER (WHERE c.col_ord = 6)::INTEGER AS direction_id,
  max(c.v) FILTER (WHERE c.col_ord = 7)::VARCHAR AS block_id,
  max(c.v) FILTER (WHERE c.col_ord = 8)::VARCHAR AS shape_id,
  max(c.vi) FILTER (WHERE c.col_ord = 9)::INTEGER AS wheelchair_accessible,
  max(c.vi) FILTER (WHERE c.col_ord = 10)::INTEGER AS bikes_allowed,
  max(c.vi) FILTER (WHERE c.col_ord = 11)::INTEGER AS cars_allowed,
  max(c.vd) FILTER (WHERE c.col_ord = 12)::DOUBLE AS safe_duration_factor,
  max(c.vd) FILTER (WHERE c.col_ord = 13)::DOUBLE AS safe_duration_offset
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of stop_times.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_stop_times() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS trip_id,
  max(c.vi) FILTER (WHERE c.col_ord = 2)::INTEGER AS arrival_time,
  max(c.vi) FILTER (WHERE c.col_ord = 3)::INTEGER AS departure_time,
  max(c.v) FILTER (WHERE c.col_ord = 4)::VARCHAR AS stop_id,
  max(c.v) FILTER (WHERE c.col_ord = 5)::VARCHAR AS location_group_id,
  max(c.v) FILTER (WHERE c.col_ord = 6)::VARCHAR AS location_id,
  max(c.vi) FILTER (WHERE c.col_ord = 7)::INTEGER AS stop_sequence,
  max(c.v) FILTER (WHERE c.col_ord = 8)::VARCHAR AS stop_headsign,
  max(c.vi) FILTER (WHERE c.col_ord = 9)::INTEGER AS start_pickup_drop_off_window,
  max(c.vi) FILTER (WHERE c.col_ord = 10)::INTEGER AS end_pickup_drop_off_window,
  max(c.vi) FILTER (WHERE c.col_ord = 11)::INTEGER AS pickup_type,
  max(c.vi) FILTER (WHERE c.col_ord = 12)::INTEGER AS drop_off_type,
  max(c.vi) FILTER (WHERE c.col_ord = 13)::INTEGER AS continuous_pickup,
  max(c.vi) FILTER (WHERE c.col_ord = 14)::INTEGER AS continuous_drop_off,
  max(c.vd) FILTER (WHERE c.col_ord = 15)::DOUBLE AS shape_dist_traveled,
  max(c.vi) FILTER (WHERE c.col_ord = 16)::INTEGER AS timepoint,
  max(c.v) FILTER (WHERE c.col_ord = 17)::VARCHAR AS pickup_booking_rule_id,
  max(c.v) FILTER (WHERE c.col_ord = 18)::VARCHAR AS drop_off_booking_rule_id
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of shapes.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_shapes() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS shape_id,
  max(c.vd) FILTER (WHERE c.col_ord = 2)::DOUBLE AS shape_pt_lat,
  max(c.vd) FILTER (WHERE c.col_ord = 3)::DOUBLE AS shape_pt_lon,
  max(c.vi) FILTER (WHERE c.col_ord = 4)::INTEGER AS shape_pt_sequence,
  max(c.vd) FILTER (WHERE c.col_ord = 5)::DOUBLE AS shape_dist_traveled
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of calendar.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_calendar() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS service_id,
  max(c.vi) FILTER (WHERE c.col_ord = 2)::INTEGER AS monday,
  max(c.vi) FILTER (WHERE c.col_ord = 3)::INTEGER AS tuesday,
  max(c.vi) FILTER (WHERE c.col_ord = 4)::INTEGER AS wednesday,
  max(c.vi) FILTER (WHERE c.col_ord = 5)::INTEGER AS thursday,
  max(c.vi) FILTER (WHERE c.col_ord = 6)::INTEGER AS friday,
  max(c.vi) FILTER (WHERE c.col_ord = 7)::INTEGER AS saturday,
  max(c.vi) FILTER (WHERE c.col_ord = 8)::INTEGER AS sunday,
  max(c.vdt) FILTER (WHERE c.col_ord = 9)::DATE AS start_date,
  max(c.vdt) FILTER (WHERE c.col_ord = 10)::DATE AS end_date
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- Entities of calendar_dates.txt: rows of the right length whose own parse produced no ERROR (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_calendar_dates() AS TABLE
SELECT r.csv_row_number,
  max(c.v) FILTER (WHERE c.col_ord = 1)::VARCHAR AS service_id,
  max(c.vdt) FILTER (WHERE c.col_ord = 2)::DATE AS date,
  max(c.vi) FILTER (WHERE c.col_ord = 3)::INTEGER AS exception_type
FROM gtfs_vc_rows r LEFT JOIN gtfs_vc_cells c USING (csv_row_number)
WHERE r.entity
GROUP BY r.csv_row_number;
-- The univocity CsvParserSettings dump the oracle's TextParsingException messages carry (CsvFile settings).
CREATE OR REPLACE MACRO gtfs_vc_parser_settings() AS (
  'Parser Configuration: CsvParserSettings:'
  || chr(10)
  || chr(9)
  || 'Auto configuration enabled=true'
  || chr(10)
  || chr(9)
  || 'Auto-closing enabled=true'
  || chr(10)
  || chr(9)
  || 'Autodetect column delimiter=false'
  || chr(10)
  || chr(9)
  || 'Autodetect quotes=false'
  || chr(10)
  || chr(9)
  || 'Column reordering enabled=true'
  || chr(10)
  || chr(9)
  || 'Delimiters for detection=null'
  || chr(10)
  || chr(9)
  || 'Empty value=null'
  || chr(10)
  || chr(9)
  || 'Escape unquoted values=false'
  || chr(10)
  || chr(9)
  || 'Header extraction enabled=true'
  || chr(10)
  || chr(9)
  || 'Headers=null'
  || chr(10)
  || chr(9)
  || 'Ignore leading whitespaces=true'
  || chr(10)
  || chr(9)
  || 'Ignore leading whitespaces in quotes=false'
  || chr(10)
  || chr(9)
  || 'Ignore trailing whitespaces=true'
  || chr(10)
  || chr(9)
  || 'Ignore trailing whitespaces in quotes=false'
  || chr(10)
  || chr(9)
  || 'Input buffer size=1048576'
  || chr(10)
  || chr(9)
  || 'Input reading on separate thread=false'
  || chr(10)
  || chr(9)
  || 'Keep escape sequences=false'
  || chr(10)
  || chr(9)
  || 'Keep quotes=false'
  || chr(10)
  || chr(9)
  || 'Length of content displayed on error=-1'
  || chr(10)
  || chr(9)
  || 'Line separator detection enabled=false'
  || chr(10)
  || chr(9)
  || 'Maximum number of characters per column=4096'
  || chr(10)
  || chr(9)
  || 'Maximum number of columns=512'
  || chr(10)
  || chr(9)
  || 'Normalize escaped line separators=true'
  || chr(10)
  || chr(9)
  || 'Null value=null'
  || chr(10)
  || chr(9)
  || 'Number of records to read=all'
  || chr(10)
  || chr(9)
  || 'Processor=none'
  || chr(10)
  || chr(9)
  || 'Restricting data in exceptions=false'
  || chr(10)
  || chr(9)
  || 'RowProcessor error handler=null'
  || chr(10)
  || chr(9)
  || 'Selected fields=none'
  || chr(10)
  || chr(9)
  || 'Skip bits as whitespace=true'
  || chr(10)
  || chr(9)
  || 'Skip empty lines=true'
  || chr(10)
  || chr(9)
  || 'Unescaped quote handling=nullFormat configuration:'
  || chr(10)
  || chr(9)
  || 'CsvFormat:'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Comment character=#'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Field delimiter=,'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Line separator (normalized)=\n'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Line separator sequence=\n'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Quote character="'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Quote escape character="'
  || chr(10)
  || chr(9)
  || chr(9)
  || 'Quote escape escape character=null'
  || chr(10)
);
-- GENERATED-END

-- Whitespace for univocity (skip bits as whitespace) and String.trim(): every char <= ' '.
CREATE OR REPLACE MACRO gtfs_vc_ws() AS (
  chr(0) || chr(1) || chr(2) || chr(3) || chr(4) || chr(5) || chr(6) || chr(7) || chr(8) || chr(9) || chr(10)
  || chr(11) || chr(12) || chr(13) || chr(14) || chr(15) || chr(16) || chr(17) || chr(18) || chr(19) || chr(20) || chr(21) || chr(22) || chr(23) || chr(24) || chr(25) || chr(26) || chr(27) || chr(28) || chr(29) || chr(30) || chr(31) || chr(32)
);

-- String.trim() and univocity's whitespace trimming: chars <= ' ' at both ends (cheap when there are none).
CREATE OR REPLACE MACRO gtfs_vc_trim(x) AS (
  CASE WHEN regexp_matches(x, '^[\x00-\x20]|[\x00-\x20]$') THEN regexp_replace(x, '^[\x00-\x20]+|[\x00-\x20]+$', '', 'g')
       ELSE x END
);
CREATE OR REPLACE MACRO gtfs_vc_ltrim(x) AS (regexp_replace(x, '^[\x00-\x20]+', ''));
CREATE OR REPLACE MACRO gtfs_vc_rtrim(x) AS (regexp_replace(x, '[\x00-\x20]+$', ''));

-- ---------------------------------------------------------------- decoding

-- One UTF-8 sequence (hex of hex()), valid or as Java's UTF-8 decoder groups a malformed one (one U+FFFD each):
-- valid sequences, a UTF-16 surrogate (3 bytes), a truncated 4-byte or 3-byte sequence, else one byte.
CREATE OR REPLACE MACRO gtfs_vc_utf8_valid_re() AS (
  '[0-7][0-9A-F]|(?:C[2-9A-F]|D[0-9A-F])[89AB][0-9A-F]|E0[AB][0-9A-F][89AB][0-9A-F]'
  || '|E[1-9A-CEF][89AB][0-9A-F][89AB][0-9A-F]|ED[89][0-9A-F][89AB][0-9A-F]'
  || '|F0[9AB][0-9A-F][89AB][0-9A-F][89AB][0-9A-F]|F[1-3][89AB][0-9A-F][89AB][0-9A-F][89AB][0-9A-F]'
  || '|F48[0-9A-F][89AB][0-9A-F][89AB][0-9A-F]'
);
CREATE OR REPLACE MACRO gtfs_vc_utf8_token_re() AS (
  gtfs_vc_utf8_valid_re()
  || '|ED[AB][0-9A-F][89AB][0-9A-F]'
  || '|(?:F0[9AB][0-9A-F]|F[1-3][89AB][0-9A-F]|F48[0-9A-F])(?:[89AB][0-9A-F])?'
  || '|E0[AB][0-9A-F]|E[1-9A-F][89AB][0-9A-F]'
  || '|..'
);
-- Bytes that are not valid UTF-8 -> text as CsvFile decodes them (CodingErrorAction.REPLACE with U+FFFD).
-- validate_load.sql only calls it when decode() fails.
CREATE OR REPLACE MACRO gtfs_vc_decode_invalid(content) AS (
  array_to_string(list_transform(
    -- byte-aligned lines of the hex text: invalid sequences never contain an LF byte
    regexp_extract_all(hex(content), '(?:[0-9A-F]{2})*?0A|(?:[0-9A-F]{2})+$'),
    lambda h: CASE WHEN TRY(decode(unhex(h))) IS NOT NULL THEN TRY(decode(unhex(h)))
                   ELSE decode(unhex(array_to_string(list_transform(
                          regexp_extract_all(h, gtfs_vc_utf8_token_re()),
                          lambda t: CASE WHEN regexp_full_match(t, gtfs_vc_utf8_valid_re()) THEN t ELSE 'EFBFBD' END),
                          ''))) END), '')
);
-- LineEndingCheckingInputStream: line (1 + LFs before it) of the first CR not followed by LF, NULL if none.
CREATE OR REPLACE MACRO gtfs_vc_invalid_line_ending_row(content_text) AS (
  CASE WHEN contains(content_text, chr(13))
        AND regexp_matches(content_text, '^[^\r]*(?:\r\n[^\r]*)*\r(?:[^\n]|$)')
       THEN 1 + length(regexp_extract(content_text, '^([^\r]*(?:\r\n[^\r]*)*)\r(?:[^\n]|$)', 1))
              - length(replace(regexp_extract(content_text, '^([^\r]*(?:\r\n[^\r]*)*)\r(?:[^\n]|$)', 1), chr(10), ''))
  END
);

-- ---------------------------------------------------------------- CSV records

-- One token per value, separator first (LF starts a record, the text gets a leading LF): a comment line, an
-- unclosed quoted value (runs to the end of the file), a quoted value with what follows its closing quote, or an
-- unquoted value.
CREATE OR REPLACE MACRO gtfs_vc_token_re() AS (
  '\n#[^\n]*|[,\n][\x00-\x09\x0B-\x20]*"(?:[^"]|"")*$|[,\n][\x00-\x09\x0B-\x20]*"(?:[^"]|"")*"[^,\n]*|[,\n][^,\n]*'
);

-- Records of gtfs_vc_text. Files without a quote take the fast path (one record per line).
CREATE OR REPLACE MACRO gtfs_vc_parse_records() AS TABLE
WITH fast_lines AS (
  SELECT unnest(l) AS line, unnest(range(1, len(l) + 1)) AS line_no
  FROM (SELECT string_split(t.text, chr(10)) AS l FROM gtfs_vc_text t WHERE NOT contains(t.text, '"'))
),
fast AS (
  SELECT line_no AS rec_no, line_no AS csv_row_number,
    CASE WHEN line = '' THEN 'empty' WHEN starts_with(line, '#') THEN 'comment'
         WHEN gtfs_vc_trim(line) = '' THEN 'ws' ELSE 'row' END AS kind,
    CASE WHEN regexp_matches(line, '[\x00-\x20]')
         THEN list_transform(string_split(line, ','), lambda f: nullif(gtfs_vc_trim(f), ''))
         ELSE list_transform(string_split(line, ','), lambda f: nullif(f, '')) END AS fields
  FROM fast_lines
),
tokens AS (
  SELECT unnest(tk) AS tok, unnest(range(1, len(tk) + 1)) AS tok_no
  FROM (SELECT regexp_extract_all(chr(10) || t.text, gtfs_vc_token_re()) AS tk FROM gtfs_vc_text t
        WHERE contains(t.text, '"'))
),
tok1 AS (
  SELECT tok_no, left(tok, 1) = chr(10) AS starts_record, tok[2:] AS body,
    length(tok) - length(replace(tok, chr(10), '')) AS nl
  FROM tokens
),
tok2 AS (
  SELECT *, sum(starts_record::INTEGER) OVER w AS rec_no, sum(nl) OVER w AS line_end,
    starts_record AND starts_with(body, '#') AS is_comment,
    gtfs_vc_ltrim(body) AS lb
  FROM tok1 WINDOW w AS (ORDER BY tok_no ROWS UNBOUNDED PRECEDING)
),
tok3 AS (
  SELECT *, starts_with(lb, '"') AND NOT is_comment AS quoted,
    CASE WHEN starts_with(lb, '"') AND NOT is_comment
         THEN regexp_extract(lb, '^"((?:[^"]|"")*)"([^,\n]*)$', ['c', 'r']) END AS q
  FROM tok2
),
tok4 AS (
  SELECT rec_no, tok_no, line_end, is_comment, quoted, body,
    CASE WHEN is_comment THEN NULL
         WHEN NOT quoted THEN nullif(gtfs_vc_trim(body), '')
         -- unclosed quote: the rest of the file
         WHEN NOT regexp_matches(lb, '^"(?:[^"]|"")*"[^,\n]*$') THEN nullif(replace(lb[2:], '""', '"'), '')
         WHEN gtfs_vc_trim(q.r) = '' THEN nullif(replace(q.c, '""', '"'), '')
         -- text after the closing quote: univocity keeps the quotes and that text
         ELSE '"' || replace(q.c, '""', '"') || '"' || gtfs_vc_rtrim(q.r)
    END AS value
  FROM tok3
),
slow AS (
  SELECT rec_no, max(line_end) AS csv_row_number,
    CASE WHEN bool_or(is_comment) THEN 'comment'
         WHEN count(*) = 1 AND NOT bool_or(quoted) AND max(body) = '' THEN 'empty'
         WHEN count(*) = 1 AND NOT bool_or(quoted) AND gtfs_vc_trim(max(body)) = '' THEN 'ws'
         ELSE 'row' END AS kind,
    list(value ORDER BY tok_no) AS fields
  FROM tok4 GROUP BY rec_no
)
SELECT rec_no, csv_row_number, kind, fields, list_max(list_transform(fields, lambda f: length(f))) AS max_len FROM fast
UNION ALL
SELECT rec_no, csv_row_number, kind, fields, list_max(list_transform(fields, lambda f: length(f))) FROM slow;

-- The header record: the first record that is not empty or a comment (a whitespace-only one gives one empty name).
CREATE OR REPLACE MACRO gtfs_vc_header_record() AS TABLE
SELECT rec_no, csv_row_number,
  CASE WHEN kind = 'ws' THEN [''] ELSE list_transform(fields, lambda f: coalesce(gtfs_vc_trim(f), '')) END AS names
FROM gtfs_vc_records WHERE kind IN ('ws', 'row') ORDER BY rec_no LIMIT 1;

-- univocity TextParsingException (csv_parsing_failed): the first record with a value longer than maxCharsPerColumn
-- (4096) or more than maxColumns (512) values. Positions are recomputed from the text with offsets (only when such a
-- record exists): charIndex is the offset after the first char past 4096 (or after the terminator of the 513th value),
-- lineIndex the line feeds before it, record the data records before it.

-- ArgumentUtils.displayLineSeparators(text, true): each CR or LF becomes [cr] or [lf] followed by the character itself;
-- a CR LF or LF CR pair becomes [crlf] or [lfcr] followed by the pair.
CREATE OR REPLACE MACRO gtfs_vc_display_line_separators(s) AS (
  replace(replace(replace(replace(regexp_replace(s, '(\r\n|\n\r|\r|\n)', '[\1]\1', 'g'),
    '[' || chr(13) || chr(10) || ']', '[crlf]'), '[' || chr(10) || chr(13) || ']', '[lfcr]'),
    '[' || chr(13) || ']', '[cr]'), '[' || chr(10) || ']', '[lf]')
);
CREATE OR REPLACE MACRO gtfs_vc_failure() AS TABLE
WITH f AS (
  SELECT rec_no, fields,
    list_position(list_transform(fields, lambda x: coalesce(length(x), 0) > 4096), true) AS long_pos
  FROM gtfs_vc_records WHERE kind = 'row' AND (max_len > 4096 OR len(fields) > 512)
  ORDER BY rec_no LIMIT 1
),
e AS (
  SELECT rec_no, fields, long_pos, long_pos IS NOT NULL AND long_pos <= 512 AS is_long,
    CASE WHEN long_pos IS NOT NULL AND long_pos <= 512 THEN long_pos ELSE 513 END AS tok_col
  FROM f
),
tokens AS (
  SELECT unnest(tk) AS tok, unnest(range(1, len(tk) + 1)) AS tok_no
  FROM (SELECT regexp_extract_all(chr(10) || t.text, gtfs_vc_token_re()) AS tk FROM gtfs_vc_text t
        WHERE EXISTS (SELECT 1 FROM f))
),
pos AS (
  SELECT tok, tok_no, (sum(length(tok)) OVER w - length(tok))::BIGINT AS body_start,
    sum((left(tok, 1) = chr(10))::INTEGER) OVER w AS rec_no
  FROM tokens WINDOW w AS (ORDER BY tok_no ROWS UNBOUNDED PRECEDING)
),
rt AS (
  SELECT p.*, row_number() OVER (ORDER BY tok_no) AS col_no FROM pos p WHERE p.rec_no = (SELECT rec_no FROM f)
),
hr AS (SELECT rec_no, names FROM gtfs_vc_header_record()),
c AS (
  SELECT e.rec_no, e.is_long, e.fields, e.long_pos,
    CASE WHEN e.is_long
         THEN rt.body_start + (length(rt.tok) - 1 - length(gtfs_vc_ltrim(rt.tok[2:])))
              + starts_with(gtfs_vc_ltrim(rt.tok[2:]), '"')::INTEGER + 4096 + 1
         ELSE rt.body_start + length(rt.tok) END AS char_index,
    (SELECT count(*) FROM gtfs_vc_records r, hr
     WHERE r.kind = 'row' AND r.rec_no > hr.rec_no AND r.rec_no < e.rec_no) AS record,
    e.rec_no = (SELECT rec_no FROM hr) AS at_header
  FROM e JOIN rt ON rt.col_no = e.tok_col
),
d AS (
  SELECT c.*,
    CASE WHEN is_long THEN long_pos - 1 ELSE 513 END AS column_index,
    (SELECT length(x) - length(replace(x, chr(10), ''))
     FROM (SELECT substr(t.text, 1, (CASE WHEN c.is_long THEN c.char_index - 1 ELSE c.char_index END)::BIGINT) AS x
           FROM gtfs_vc_text t)) AS line_index,
    CASE WHEN is_long THEN left(fields[long_pos], 4096) ELSE '' END AS parsed
  FROM c
)
SELECT rec_no, at_header,
  gtfs_validation_notice(json_object('filename', (SELECT filename FROM gtfs_vc_text), 'charIndex', char_index,
    'columnIndex', column_index, 'lineIndex', line_index, 'parsedContent', parsed,
    'message', CASE WHEN is_long
        THEN 'Length of parsed input (4097) exceeds the maximum number of characters defined in your parser settings (4096). '
        ELSE 'java.lang.ArrayIndexOutOfBoundsException - Index 512 out of bounds for length 512' END
      || CASE WHEN is_long AND (contains(parsed, chr(10)) OR contains(parsed, chr(13)))
              THEN chr(10) || 'Identified line separator characters in the parsed content. This may be the cause of '
                || 'the error. The line separator in your parser settings is set to ''[lf]''. Parsed content: '
                || gtfs_vc_display_line_separators(parsed)
              ELSE '' END
      || CASE WHEN is_long AND contains(parsed, chr(0))
              THEN chr(10) || 'Identified ' || (length(parsed) - length(replace(parsed, chr(0), ''))) || ' null characters ('''
                || chr(0) || ''') on parsed content. This may indicate the data is corrupt or its encoding is invalid. '
                || 'Parsed content:' || chr(10) || chr(9) || 'Parsed content: ' || replace(parsed, chr(0), '\0')
              ELSE '' END
      || chr(10) || gtfs_vc_parser_settings()
      || 'Internal state when error was thrown: line=' || line_index || ', column=' || column_index
      || ', record=' || record || ', charIndex=' || char_index
      || CASE WHEN at_header THEN '' ELSE ', headers=[' || array_to_string((SELECT names FROM hr), ', ') || ']' END
      || CASE WHEN parsed = '' THEN '' ELSE ', content parsed=' || parsed END)) AS notice
FROM d;

-- DefaultTableHeaderValidator notices of the current header.
CREATE OR REPLACE MACRO gtfs_vc_header_notices(p_file) AS TABLE
WITH h AS (SELECT column_name, column_index FROM gtfs_vc_header),
known AS (SELECT column_name, level FROM gtfs_vc_schema() WHERE filename = p_file)
SELECT 'empty_column_name' AS code,
  gtfs_validation_notice(json_object('filename', p_file, 'index', column_index + 1)) AS notice
FROM h WHERE column_name = ''
UNION ALL
SELECT 'duplicated_column', gtfs_validation_notice(json_object('filename', p_file, 'fieldName', h.column_name,
  'firstIndex', (SELECT min(h2.column_index) FROM h h2 WHERE h2.column_name = h.column_name) + 1,
  'secondIndex', h.column_index + 1))
FROM h WHERE h.column_name <> ''
  AND EXISTS (SELECT 1 FROM h h2 WHERE h2.column_name = h.column_name AND h2.column_index < h.column_index)
UNION ALL
SELECT 'unknown_column',
  gtfs_validation_notice(json_object('filename', p_file, 'fieldName', column_name, 'index', column_index + 1))
FROM h WHERE column_name <> '' AND column_name NOT IN (SELECT column_name FROM known)
UNION ALL
SELECT 'missing_required_column', gtfs_validation_notice(json_object('filename', p_file, 'fieldName', column_name))
FROM known WHERE level = 'REQUIRED' AND column_name NOT IN (SELECT column_name FROM h)
  AND EXISTS (SELECT 1 FROM h);

-- Data rows after the header (CsvFile iterator): whitespace-only lines are skipped except a last one without a line
-- break, which univocity returns as one empty value. Rows from a csv_parsing_failed row on are never read.
CREATE OR REPLACE MACRO gtfs_vc_data_rows() AS TABLE
SELECT r.csv_row_number, CASE WHEN r.kind = 'ws' THEN [NULL]::VARCHAR[] ELSE r.fields END AS fields,
  CASE WHEN r.kind = 'ws' OR (len(r.fields) = 1 AND r.fields[1] IS NULL) THEN false
       ELSE len(r.fields) = s.header_n END AS length_ok,
  false AS entity
FROM gtfs_vc_records r, gtfs_vc_state s
WHERE s.header_ok AND r.rec_no > (SELECT min(rec_no) FROM gtfs_vc_records WHERE kind IN ('ws', 'row'))
  AND (r.kind = 'row' OR (r.kind = 'ws' AND r.rec_no = (SELECT max(rec_no) FROM gtfs_vc_records)))
  AND (s.fail_rec IS NULL OR r.rec_no < s.fail_rec);

-- ---------------------------------------------------------------- field parsers (RowParser, Gtfs* types)

-- Integer.parseInt: optional sign, ASCII digits, within int range.
CREATE OR REPLACE MACRO gtfs_vc_int(s) AS (
  CASE WHEN regexp_full_match(s, '[+-]?[0-9]+') THEN TRY_CAST(s AS INTEGER) END
);
-- Double.parseDouble: trims chars <= ' ', decimal with optional exponent and f/F/d/D suffix, NaN, Infinity.
CREATE OR REPLACE MACRO gtfs_vc_double(s) AS (
  CASE WHEN regexp_full_match(gtfs_vc_trim(s),
              '[+-]?(?:NaN|Infinity|(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?[fFdD]?)')
       THEN TRY_CAST(regexp_replace(gtfs_vc_trim(s), '[fFdD]$', '') AS DOUBLE) END
);
-- GtfsTime.fromString: (\d{1,3}):(\d\d):(\d\d), minutes and seconds below 60 -> seconds since midnight.
CREATE OR REPLACE MACRO gtfs_vc_time(s) AS (
  CASE WHEN regexp_full_match(s, '[0-9]{1,3}:[0-5][0-9]:[0-5][0-9]')
       THEN split_part(s, ':', 1)::INTEGER * 3600 + split_part(s, ':', 2)::INTEGER * 60
            + split_part(s, ':', 3)::INTEGER END
);
-- GtfsColor.fromString: 6 chars, Integer.parseInt(s, 16) (a sign is allowed).
CREATE OR REPLACE MACRO gtfs_vc_color(s) AS (
  CASE WHEN length(s) = 6 AND regexp_full_match(s, '[+-]?[0-9A-Fa-f]+')
       THEN (CASE WHEN starts_with(s, '-') THEN -1 ELSE 1 END) * ('0x' || upper(ltrim(s, '+-')))::INTEGER END
);
-- GtfsDate.fromString: 8 chars, Integer.parseInt of yyyy, mm and dd, then a real date (LocalDate.of).
CREATE OR REPLACE MACRO gtfs_vc_date(s) AS (
  CASE WHEN length(s) = 8 AND gtfs_vc_int(s[1:4]) IS NOT NULL
         AND gtfs_vc_int(s[5:6]) BETWEEN 1 AND 12 AND gtfs_vc_int(s[7:8]) BETWEEN 1 AND 31
       THEN TRY(make_date(gtfs_vc_int(s[1:4]), gtfs_vc_int(s[5:6]), gtfs_vc_int(s[7:8]))) END
);
-- ZoneOffset.of(text): +h, +hh, +hh:mm, +hhmm, +hh:mm:ss, +hhmmss, at most 18:00:00.
CREATE OR REPLACE MACRO gtfs_vc_offset_ok(s) AS (
  regexp_full_match(s, '[+-](?:[0-9]|[0-9]{2}|[0-9]{2}:?[0-5][0-9]|[0-9]{2}:[0-5][0-9]:[0-5][0-9]|[0-9]{2}[0-5][0-9][0-5][0-9])')
  AND (CASE WHEN length(s) = 2 THEN TRY_CAST(s[2:2] AS INTEGER) ELSE TRY_CAST(s[2:3] AS INTEGER) END) <= 18
  AND (length(s) <= 3 OR (CASE WHEN length(s) = 2 THEN TRY_CAST(s[2:2] AS INTEGER) ELSE TRY_CAST(s[2:3] AS INTEGER) END) < 18
       OR regexp_full_match(s[4:], ':?00(?::?00)?'))
);
-- ZoneId.of: Z, an offset, UTC/GMT/UT with or without an offset, or a region id of the oracle's Java 17.
CREATE OR REPLACE MACRO gtfs_vc_timezone_ok(s) AS (
  s = 'Z' OR ((starts_with(s, '+') OR starts_with(s, '-')) AND gtfs_vc_offset_ok(s))
  OR s IN ('UTC', 'GMT', 'UT')
  OR (regexp_matches(s, '^(?:UTC|GMT)[+-]') AND gtfs_vc_offset_ok(s[4:]))
  OR (regexp_matches(s, '^UT[+-]') AND gtfs_vc_offset_ok(s[3:]))
  OR list_contains(gtfs_vc_zone_ids(), s)
);
-- BEGIN GENERATED by test/validation/idn/GenIdn.java; do not edit
-- RFC 3491 nameprep data of java.net.IDN on Java 17.0.20.1 (StringPrep, Unicode 3.2 tables).
-- gtfs_vc_idn_entries(): [code point, mapped code points...] for the code points whose B.1/B.2 map
-- plus NFKC differs from the code point and from its NFC; gtfs_vc_idn_runs(): [first, count, offset]
-- runs of such one-to-one mappings. The other code points are left to nfc_normalize().
CREATE OR REPLACE MACRO gtfs_vc_idn_entries() AS ([
  [160,32],[168,32,776],[170,97],[173],[175,32,772],[180,32,769],[181,956],[184,32,807],[185,49],[186,111],
  [188,49,8260,52],[189,49,8260,50],[190,51,8260,52],[223,115,115],[256,257],[258,259],[260,261],[262,263],[264,265],
  [266,267],[268,269],[270,271],[272,273],[274,275],[276,277],[278,279],[280,281],[282,283],[284,285],[286,287],
  [288,289],[290,291],[292,293],[294,295],[296,297],[298,299],[300,301],[302,303],[304,105,775],[306,105,106],
  [307,105,106],[308,309],[310,311],[313,314],[315,316],[317,318],[319,108,183],[320,108,183],[321,322],[323,324],
  [325,326],[327,328],[329,700,110],[330,331],[332,333],[334,335],[336,337],[338,339],[340,341],[342,343],[344,345],
  [346,347],[348,349],[350,351],[352,353],[354,355],[356,357],[358,359],[360,361],[362,363],[364,365],[366,367],
  [368,369],[370,371],[372,373],[374,375],[376,255],[377,378],[379,380],[381,382],[383,115],[385,595],[386,387],
  [388,389],[390,596],[391,392],[395,396],[398,477],[399,601],[400,603],[401,402],[403,608],[404,611],[406,617],
  [407,616],[408,409],[412,623],[413,626],[415,629],[416,417],[418,419],[420,421],[422,640],[423,424],[425,643],
  [428,429],[430,648],[431,432],[435,436],[437,438],[439,658],[440,441],[444,445],[452,100,382],[453,100,382],
  [454,100,382],[455,108,106],[456,108,106],[457,108,106],[458,110,106],[459,110,106],[460,110,106],[461,462],
  [463,464],[465,466],[467,468],[469,470],[471,472],[473,474],[475,476],[478,479],[480,481],[482,483],[484,485],
  [486,487],[488,489],[490,491],[492,493],[494,495],[497,100,122],[498,100,122],[499,100,122],[500,501],[502,405],
  [503,447],[504,505],[506,507],[508,509],[510,511],[512,513],[514,515],[516,517],[518,519],[520,521],[522,523],
  [524,525],[526,527],[528,529],[530,531],[532,533],[534,535],[536,537],[538,539],[540,541],[542,543],[544,414],
  [546,547],[548,549],[550,551],[552,553],[554,555],[556,557],[558,559],[560,561],[562,563],[688,104],[689,614],
  [690,106],[691,114],[692,633],[693,635],[694,641],[695,119],[696,121],[728,32,774],[729,32,775],[730,32,778],
  [731,32,808],[732,32,771],[733,32,779],[736,611],[737,108],[738,115],[739,120],[740,661],[837,953],[847],
  [890,32,953],[900,32,769],[901,32,776,769],[902,940],[908,972],[962,963],[976,946],[977,952],[978,965],[979,973],
  [980,971],[981,966],[982,960],[984,985],[986,987],[988,989],[990,991],[992,993],[994,995],[996,997],[998,999],
  [1000,1001],[1002,1003],[1004,1005],[1006,1007],[1008,954],[1009,961],[1010,963],[1012,952],[1013,949],[1120,1121],
  [1122,1123],[1124,1125],[1126,1127],[1128,1129],[1130,1131],[1132,1133],[1134,1135],[1136,1137],[1138,1139],
  [1140,1141],[1142,1143],[1144,1145],[1146,1147],[1148,1149],[1150,1151],[1152,1153],[1162,1163],[1164,1165],
  [1166,1167],[1168,1169],[1170,1171],[1172,1173],[1174,1175],[1176,1177],[1178,1179],[1180,1181],[1182,1183],
  [1184,1185],[1186,1187],[1188,1189],[1190,1191],[1192,1193],[1194,1195],[1196,1197],[1198,1199],[1200,1201],
  [1202,1203],[1204,1205],[1206,1207],[1208,1209],[1210,1211],[1212,1213],[1214,1215],[1217,1218],[1219,1220],
  [1221,1222],[1223,1224],[1225,1226],[1227,1228],[1229,1230],[1232,1233],[1234,1235],[1236,1237],[1238,1239],
  [1240,1241],[1242,1243],[1244,1245],[1246,1247],[1248,1249],[1250,1251],[1252,1253],[1254,1255],[1256,1257],
  [1258,1259],[1260,1261],[1262,1263],[1264,1265],[1266,1267],[1268,1269],[1272,1273],[1280,1281],[1282,1283],
  [1284,1285],[1286,1287],[1288,1289],[1290,1291],[1292,1293],[1294,1295],[1415,1381,1410],[1653,1575,1652],
  [1654,1608,1652],[1655,1735,1652],[1656,1610,1652],[3635,3661,3634],[3763,3789,3762],[3804,3755,3737],
  [3805,3755,3745],[3852,3851],[3959,4018,3953,3968],[3961,4019,3953,3968],[6150],[6155],[6156],[6157],[7680,7681],
  [7682,7683],[7684,7685],[7686,7687],[7688,7689],[7690,7691],[7692,7693],[7694,7695],[7696,7697],[7698,7699],
  [7700,7701],[7702,7703],[7704,7705],[7706,7707],[7708,7709],[7710,7711],[7712,7713],[7714,7715],[7716,7717],
  [7718,7719],[7720,7721],[7722,7723],[7724,7725],[7726,7727],[7728,7729],[7730,7731],[7732,7733],[7734,7735],
  [7736,7737],[7738,7739],[7740,7741],[7742,7743],[7744,7745],[7746,7747],[7748,7749],[7750,7751],[7752,7753],
  [7754,7755],[7756,7757],[7758,7759],[7760,7761],[7762,7763],[7764,7765],[7766,7767],[7768,7769],[7770,7771],
  [7772,7773],[7774,7775],[7776,7777],[7778,7779],[7780,7781],[7782,7783],[7784,7785],[7786,7787],[7788,7789],
  [7790,7791],[7792,7793],[7794,7795],[7796,7797],[7798,7799],[7800,7801],[7802,7803],[7804,7805],[7806,7807],
  [7808,7809],[7810,7811],[7812,7813],[7814,7815],[7816,7817],[7818,7819],[7820,7821],[7822,7823],[7824,7825],
  [7826,7827],[7828,7829],[7834,97,702],[7835,7777],[7840,7841],[7842,7843],[7844,7845],[7846,7847],[7848,7849],
  [7850,7851],[7852,7853],[7854,7855],[7856,7857],[7858,7859],[7860,7861],[7862,7863],[7864,7865],[7866,7867],
  [7868,7869],[7870,7871],[7872,7873],[7874,7875],[7876,7877],[7878,7879],[7880,7881],[7882,7883],[7884,7885],
  [7886,7887],[7888,7889],[7890,7891],[7892,7893],[7894,7895],[7896,7897],[7898,7899],[7900,7901],[7902,7903],
  [7904,7905],[7906,7907],[7908,7909],[7910,7911],[7912,7913],[7914,7915],[7916,7917],[7918,7919],[7920,7921],
  [7922,7923],[7924,7925],[7926,7927],[7928,7929],[8025,8017],[8027,8019],[8029,8021],[8031,8023],[8064,7936,953],
  [8065,7937,953],[8066,7938,953],[8067,7939,953],[8068,7940,953],[8069,7941,953],[8070,7942,953],[8071,7943,953],
  [8072,7936,953],[8073,7937,953],[8074,7938,953],[8075,7939,953],[8076,7940,953],[8077,7941,953],[8078,7942,953],
  [8079,7943,953],[8080,7968,953],[8081,7969,953],[8082,7970,953],[8083,7971,953],[8084,7972,953],[8085,7973,953],
  [8086,7974,953],[8087,7975,953],[8088,7968,953],[8089,7969,953],[8090,7970,953],[8091,7971,953],[8092,7972,953],
  [8093,7973,953],[8094,7974,953],[8095,7975,953],[8096,8032,953],[8097,8033,953],[8098,8034,953],[8099,8035,953],
  [8100,8036,953],[8101,8037,953],[8102,8038,953],[8103,8039,953],[8104,8032,953],[8105,8033,953],[8106,8034,953],
  [8107,8035,953],[8108,8036,953],[8109,8037,953],[8110,8038,953],[8111,8039,953],[8114,8048,953],[8115,945,953],
  [8116,940,953],[8119,8118,953],[8122,8048],[8123,940],[8124,945,953],[8125,32,787],[8127,32,787],[8128,32,834],
  [8129,32,776,834],[8130,8052,953],[8131,951,953],[8132,942,953],[8135,8134,953],[8136,8050],[8137,941],[8138,8052],
  [8139,942],[8140,951,953],[8141,32,787,768],[8142,32,787,769],[8143,32,787,834],[8154,8054],[8155,943],
  [8157,32,788,768],[8158,32,788,769],[8159,32,788,834],[8170,8058],[8171,973],[8172,8165],[8173,32,776,768],
  [8174,32,776,769],[8178,8060,953],[8179,969,953],[8180,974,953],[8183,8182,953],[8184,8056],[8185,972],[8186,8060],
  [8187,974],[8188,969,953],[8189,32,769],[8190,32,788],[8192,32],[8193,32],[8194,32],[8195,32],[8196,32],[8197,32],
  [8198,32],[8199,32],[8200,32],[8201,32],[8202,32],[8203],[8204],[8205],[8209,8208],[8215,32,819],[8228,46],
  [8229,46,46],[8230,46,46,46],[8239,32],[8243,8242,8242],[8244,8242,8242,8242],[8246,8245,8245],
  [8247,8245,8245,8245],[8252,33,33],[8254,32,773],[8263,63,63],[8264,63,33],[8265,33,63],[8279,8242,8242,8242,8242],
  [8287,32],[8288],[8304,48],[8305,105],[8314,43],[8315,8722],[8316,61],[8319,110],[8330,43],[8331,8722],[8332,61],
  [8360,114,115],[8448,97,47,99],[8449,97,47,115],[8450,99],[8451,176,99],[8453,99,47,111],[8454,99,47,117],
  [8455,603],[8457,176,102],[8460,104],[8461,104],[8462,104],[8463,295],[8464,105],[8465,105],[8466,108],[8467,108],
  [8469,110],[8470,110,111],[8476,114],[8477,114],[8480,115,109],[8481,116,101,108],[8482,116,109],[8484,122],
  [8486,969],[8488,122],[8490,107],[8491,229],[8495,101],[8499,109],[8500,111],[8505,105],[8509,947],[8510,947],
  [8511,960],[8512,8721],[8517,100],[8531,49,8260,51],[8532,50,8260,51],[8533,49,8260,53],[8534,50,8260,53],
  [8535,51,8260,53],[8536,52,8260,53],[8537,49,8260,54],[8538,53,8260,54],[8539,49,8260,56],[8540,51,8260,56],
  [8541,53,8260,56],[8542,55,8260,56],[8543,49,8260],[8544,105],[8545,105,105],[8546,105,105,105],[8547,105,118],
  [8548,118],[8549,118,105],[8550,118,105,105],[8551,118,105,105,105],[8552,105,120],[8553,120],[8554,120,105],
  [8555,120,105,105],[8556,108],[8559,109],[8560,105],[8561,105,105],[8562,105,105,105],[8563,105,118],[8564,118],
  [8565,118,105],[8566,118,105,105],[8567,118,105,105,105],[8568,105,120],[8569,120],[8570,120,105],
  [8571,120,105,105],[8572,108],[8575,109],[8748,8747,8747],[8749,8747,8747,8747],[8751,8750,8750],
  [8752,8750,8750,8750],[9321,49,48],[9322,49,49],[9323,49,50],[9324,49,51],[9325,49,52],[9326,49,53],[9327,49,54],
  [9328,49,55],[9329,49,56],[9330,49,57],[9331,50,48],[9332,40,49,41],[9333,40,50,41],[9334,40,51,41],[9335,40,52,41],
  [9336,40,53,41],[9337,40,54,41],[9338,40,55,41],[9339,40,56,41],[9340,40,57,41],[9341,40,49,48,41],
  [9342,40,49,49,41],[9343,40,49,50,41],[9344,40,49,51,41],[9345,40,49,52,41],[9346,40,49,53,41],[9347,40,49,54,41],
  [9348,40,49,55,41],[9349,40,49,56,41],[9350,40,49,57,41],[9351,40,50,48,41],[9352,49,46],[9353,50,46],[9354,51,46],
  [9355,52,46],[9356,53,46],[9357,54,46],[9358,55,46],[9359,56,46],[9360,57,46],[9361,49,48,46],[9362,49,49,46],
  [9363,49,50,46],[9364,49,51,46],[9365,49,52,46],[9366,49,53,46],[9367,49,54,46],[9368,49,55,46],[9369,49,56,46],
  [9370,49,57,46],[9371,50,48,46],[9372,40,97,41],[9373,40,98,41],[9374,40,99,41],[9375,40,100,41],[9376,40,101,41],
  [9377,40,102,41],[9378,40,103,41],[9379,40,104,41],[9380,40,105,41],[9381,40,106,41],[9382,40,107,41],
  [9383,40,108,41],[9384,40,109,41],[9385,40,110,41],[9386,40,111,41],[9387,40,112,41],[9388,40,113,41],
  [9389,40,114,41],[9390,40,115,41],[9391,40,116,41],[9392,40,117,41],[9393,40,118,41],[9394,40,119,41],
  [9395,40,120,41],[9396,40,121,41],[9397,40,122,41],[9450,48],[10764,8747,8747,8747,8747],[10868,58,58,61],
  [10869,61,61],[10870,61,61,61],[11935,27597],[12019,40863],[12032,19968],[12033,20008],[12034,20022],[12035,20031],
  [12036,20057],[12037,20101],[12038,20108],[12039,20128],[12040,20154],[12041,20799],[12042,20837],[12043,20843],
  [12044,20866],[12045,20886],[12046,20907],[12047,20960],[12048,20981],[12049,20992],[12050,21147],[12051,21241],
  [12052,21269],[12053,21274],[12054,21304],[12055,21313],[12056,21340],[12057,21353],[12058,21378],[12059,21430],
  [12060,21448],[12061,21475],[12062,22231],[12063,22303],[12064,22763],[12065,22786],[12066,22794],[12067,22805],
  [12068,22823],[12069,22899],[12070,23376],[12071,23424],[12072,23544],[12073,23567],[12074,23586],[12075,23608],
  [12076,23662],[12077,23665],[12078,24027],[12079,24037],[12080,24049],[12081,24062],[12082,24178],[12083,24186],
  [12084,24191],[12085,24308],[12086,24318],[12087,24331],[12088,24339],[12089,24400],[12090,24417],[12091,24435],
  [12092,24515],[12093,25096],[12094,25142],[12095,25163],[12096,25903],[12097,25908],[12098,25991],[12099,26007],
  [12100,26020],[12101,26041],[12102,26080],[12103,26085],[12104,26352],[12105,26376],[12106,26408],[12107,27424],
  [12108,27490],[12109,27513],[12110,27571],[12111,27595],[12112,27604],[12113,27611],[12114,27663],[12115,27668],
  [12116,27700],[12117,28779],[12118,29226],[12119,29238],[12120,29243],[12121,29247],[12122,29255],[12123,29273],
  [12124,29275],[12125,29356],[12126,29572],[12127,29577],[12128,29916],[12129,29926],[12130,29976],[12131,29983],
  [12132,29992],[12133,30000],[12134,30091],[12135,30098],[12136,30326],[12137,30333],[12138,30382],[12139,30399],
  [12140,30446],[12141,30683],[12142,30690],[12143,30707],[12144,31034],[12145,31160],[12146,31166],[12147,31348],
  [12148,31435],[12149,31481],[12150,31859],[12151,31992],[12152,32566],[12153,32593],[12154,32650],[12155,32701],
  [12156,32769],[12157,32780],[12158,32786],[12159,32819],[12160,32895],[12161,32905],[12162,33251],[12163,33258],
  [12164,33267],[12165,33276],[12166,33292],[12167,33307],[12168,33311],[12169,33390],[12170,33394],[12171,33400],
  [12172,34381],[12173,34411],[12174,34880],[12175,34892],[12176,34915],[12177,35198],[12178,35211],[12179,35282],
  [12180,35328],[12181,35895],[12182,35910],[12183,35925],[12184,35960],[12185,35997],[12186,36196],[12187,36208],
  [12188,36275],[12189,36523],[12190,36554],[12191,36763],[12192,36784],[12193,36789],[12194,37009],[12195,37193],
  [12196,37318],[12197,37324],[12198,37329],[12199,38263],[12200,38272],[12201,38428],[12202,38582],[12203,38585],
  [12204,38632],[12205,38737],[12206,38750],[12207,38754],[12208,38761],[12209,38859],[12210,38893],[12211,38899],
  [12212,38913],[12213,39080],[12214,39131],[12215,39135],[12216,39318],[12217,39321],[12218,39340],[12219,39592],
  [12220,39640],[12221,39647],[12222,39717],[12223,39727],[12224,39730],[12225,39740],[12226,39770],[12227,40165],
  [12228,40565],[12229,40575],[12230,40613],[12231,40635],[12232,40643],[12233,40653],[12234,40657],[12235,40697],
  [12236,40701],[12237,40718],[12238,40723],[12239,40736],[12240,40763],[12241,40778],[12242,40786],[12243,40845],
  [12244,40860],[12245,40864],[12288,32],[12342,12306],[12344,21313],[12443,32,12441],[12444,32,12442],
  [12447,12424,12426],[12543,12467,12488],[12595,4522],[12596,4354],[12608,4378],[12612,4385],[12644,4448],
  [12649,4556],[12650,4558],[12651,4563],[12652,4567],[12653,4569],[12654,4380],[12655,4573],[12656,4575],
  [12659,4384],[12662,4391],[12663,4393],[12669,4402],[12670,4406],[12671,4416],[12672,4423],[12673,4428],
  [12681,4488],[12684,4500],[12685,4510],[12686,4513],[12690,19968],[12691,20108],[12692,19977],[12693,22235],
  [12694,19978],[12695,20013],[12696,19979],[12697,30002],[12698,20057],[12699,19993],[12700,19969],[12701,22825],
  [12702,22320],[12703,20154],[12800,40,4352,41],[12801,40,4354,41],[12802,40,4355,41],[12803,40,4357,41],
  [12804,40,4358,41],[12805,40,4359,41],[12806,40,4361,41],[12807,40,4363,41],[12808,40,4364,41],[12809,40,4366,41],
  [12810,40,4367,41],[12811,40,4368,41],[12812,40,4369,41],[12813,40,4370,41],[12814,40,44032,41],[12815,40,45208,41],
  [12816,40,45796,41],[12817,40,46972,41],[12818,40,47560,41],[12819,40,48148,41],[12820,40,49324,41],
  [12821,40,50500,41],[12822,40,51088,41],[12823,40,52264,41],[12824,40,52852,41],[12825,40,53440,41],
  [12826,40,54028,41],[12827,40,54616,41],[12828,40,51452,41],[12832,40,19968,41],[12833,40,20108,41],
  [12834,40,19977,41],[12835,40,22235,41],[12836,40,20116,41],[12837,40,20845,41],[12838,40,19971,41],
  [12839,40,20843,41],[12840,40,20061,41],[12841,40,21313,41],[12842,40,26376,41],[12843,40,28779,41],
  [12844,40,27700,41],[12845,40,26408,41],[12846,40,37329,41],[12847,40,22303,41],[12848,40,26085,41],
  [12849,40,26666,41],[12850,40,26377,41],[12851,40,31038,41],[12852,40,21517,41],[12853,40,29305,41],
  [12854,40,36001,41],[12855,40,31069,41],[12856,40,21172,41],[12857,40,20195,41],[12858,40,21628,41],
  [12859,40,23398,41],[12860,40,30435,41],[12861,40,20225,41],[12862,40,36039,41],[12863,40,21332,41],
  [12864,40,31085,41],[12865,40,20241,41],[12866,40,33258,41],[12867,40,33267,41],[12881,50,49],[12882,50,50],
  [12883,50,51],[12884,50,52],[12885,50,53],[12886,50,54],[12887,50,55],[12888,50,56],[12889,50,57],[12890,51,48],
  [12891,51,49],[12892,51,50],[12893,51,51],[12894,51,52],[12895,51,53],[12896,4352],[12902,4361],[12910,44032],
  [12911,45208],[12912,45796],[12913,46972],[12914,47560],[12915,48148],[12916,49324],[12917,50500],[12918,51088],
  [12919,52264],[12920,52852],[12921,53440],[12922,54028],[12923,54616],[12928,19968],[12929,20108],[12930,19977],
  [12931,22235],[12932,20116],[12933,20845],[12934,19971],[12935,20843],[12936,20061],[12937,21313],[12938,26376],
  [12939,28779],[12940,27700],[12941,26408],[12942,37329],[12943,22303],[12944,26085],[12945,26666],[12946,26377],
  [12947,31038],[12948,21517],[12949,29305],[12950,36001],[12951,31069],[12952,21172],[12953,31192],[12954,30007],
  [12955,22899],[12956,36969],[12957,20778],[12958,21360],[12959,27880],[12960,38917],[12961,20241],[12962,20889],
  [12963,27491],[12964,19978],[12965,20013],[12966,19979],[12967,24038],[12968,21491],[12969,21307],[12970,23447],
  [12971,23398],[12972,30435],[12973,20225],[12974,36039],[12975,21332],[12976,22812],[12977,51,54],[12978,51,55],
  [12979,51,56],[12980,51,57],[12981,52,48],[12982,52,49],[12983,52,50],[12984,52,51],[12985,52,52],[12986,52,53],
  [12987,52,54],[12988,52,55],[12989,52,56],[12990,52,57],[12991,53,48],[12992,49,26376],[12993,50,26376],
  [12994,51,26376],[12995,52,26376],[12996,53,26376],[12997,54,26376],[12998,55,26376],[12999,56,26376],
  [13000,57,26376],[13001,49,48,26376],[13002,49,49,26376],[13003,49,50,26376],[13008,12450],[13009,12452],
  [13010,12454],[13011,12456],[13014,12461],[13015,12463],[13016,12465],[13017,12467],[13018,12469],[13019,12471],
  [13020,12473],[13021,12475],[13022,12477],[13023,12479],[13024,12481],[13025,12484],[13026,12486],[13027,12488],
  [13034,12498],[13035,12501],[13036,12504],[13037,12507],[13043,12516],[13044,12518],[13056,12450,12497,12540,12488],
  [13057,12450,12523,12501,12449],[13058,12450,12531,12506,12450],[13059,12450,12540,12523],
  [13060,12452,12491,12531,12464],[13061,12452,12531,12481],[13062,12454,12457,12531],
  [13063,12456,12473,12463,12540,12489],[13064,12456,12540,12459,12540],[13065,12458,12531,12473],
  [13066,12458,12540,12512],[13067,12459,12452,12522],[13068,12459,12521,12483,12488],[13069,12459,12525,12522,12540],
  [13070,12460,12525,12531],[13071,12460,12531,12510],[13072,12462,12460],[13073,12462,12491,12540],
  [13074,12461,12517,12522,12540],[13075,12462,12523,12480,12540],[13076,12461,12525],
  [13077,12461,12525,12464,12521,12512],[13078,12461,12525,12513,12540,12488,12523],
  [13079,12461,12525,12527,12483,12488],[13080,12464,12521,12512],[13081,12464,12521,12512,12488,12531],
  [13082,12463,12523,12476,12452,12525],[13083,12463,12525,12540,12493],[13084,12465,12540,12473],
  [13085,12467,12523,12490],[13086,12467,12540,12509],[13087,12469,12452,12463,12523],
  [13088,12469,12531,12481,12540,12512],[13089,12471,12522,12531,12464],[13090,12475,12531,12481],
  [13091,12475,12531,12488],[13092,12480,12540,12473],[13093,12487,12471],[13094,12489,12523],[13095,12488,12531],
  [13096,12490,12494],[13097,12494,12483,12488],[13098,12495,12452,12484],[13099,12497,12540,12475,12531,12488],
  [13100,12497,12540,12484],[13101,12496,12540,12524,12523],[13102,12500,12450,12473,12488,12523],
  [13103,12500,12463,12523],[13104,12500,12467],[13105,12499,12523],[13106,12501,12449,12521,12483,12489],
  [13107,12501,12451,12540,12488],[13108,12502,12483,12471,12455,12523],[13109,12501,12521,12531],
  [13110,12504,12463,12479,12540,12523],[13111,12506,12477],[13112,12506,12491,12498],[13113,12504,12523,12484],
  [13114,12506,12531,12473],[13115,12506,12540,12472],[13116,12505,12540,12479],[13117,12509,12452,12531,12488],
  [13118,12508,12523,12488],[13119,12507,12531],[13120,12509,12531,12489],[13121,12507,12540,12523],
  [13122,12507,12540,12531],[13123,12510,12452,12463,12525],[13124,12510,12452,12523],[13125,12510,12483,12495],
  [13126,12510,12523,12463],[13127,12510,12531,12471,12519,12531],[13128,12511,12463,12525,12531],[13129,12511,12522],
  [13130,12511,12522,12496,12540,12523],[13131,12513,12460],[13132,12513,12460,12488,12531],
  [13133,12513,12540,12488,12523],[13134,12516,12540,12489],[13135,12516,12540,12523],[13136,12518,12450,12531],
  [13137,12522,12483,12488,12523],[13138,12522,12521],[13139,12523,12500,12540],[13140,12523,12540,12502,12523],
  [13141,12524,12512],[13142,12524,12531,12488,12466,12531],[13143,12527,12483,12488],[13144,48,28857],
  [13145,49,28857],[13146,50,28857],[13147,51,28857],[13148,52,28857],[13149,53,28857],[13150,54,28857],
  [13151,55,28857],[13152,56,28857],[13153,57,28857],[13154,49,48,28857],[13155,49,49,28857],[13156,49,50,28857],
  [13157,49,51,28857],[13158,49,52,28857],[13159,49,53,28857],[13160,49,54,28857],[13161,49,55,28857],
  [13162,49,56,28857],[13163,49,57,28857],[13164,50,48,28857],[13165,50,49,28857],[13166,50,50,28857],
  [13167,50,51,28857],[13168,50,52,28857],[13169,104,112,97],[13170,100,97],[13171,97,117],[13172,98,97,114],
  [13173,111,118],[13174,112,99],[13179,24179,25104],[13180,26157,21644],[13181,22823,27491],[13182,26126,27835],
  [13183,26666,24335,20250,31038],[13184,112,97],[13185,110,97],[13186,956,97],[13187,109,97],[13188,107,97],
  [13189,107,98],[13190,109,98],[13191,103,98],[13192,99,97,108],[13193,107,99,97,108],[13194,112,102],
  [13195,110,102],[13196,956,102],[13197,956,103],[13198,109,103],[13199,107,103],[13200,104,122],[13201,107,104,122],
  [13202,109,104,122],[13203,103,104,122],[13204,116,104,122],[13205,956,108],[13206,109,108],[13207,100,108],
  [13208,107,108],[13209,102,109],[13210,110,109],[13211,956,109],[13212,109,109],[13213,99,109],[13214,107,109],
  [13215,109,109,50],[13216,99,109,50],[13217,109,50],[13218,107,109,50],[13219,109,109,51],[13220,99,109,51],
  [13221,109,51],[13222,107,109,51],[13223,109,8725,115],[13224,109,8725,115,50],[13225,112,97],[13226,107,112,97],
  [13227,109,112,97],[13228,103,112,97],[13229,114,97,100],[13230,114,97,100,8725,115],[13231,114,97,100,8725,115,50],
  [13232,112,115],[13233,110,115],[13234,956,115],[13235,109,115],[13236,112,118],[13237,110,118],[13238,956,118],
  [13239,109,118],[13240,107,118],[13241,109,118],[13242,112,119],[13243,110,119],[13244,956,119],[13245,109,119],
  [13246,107,119],[13247,109,119],[13248,107,969],[13249,109,969],[13250,97,46,109,46],[13251,98,113],[13252,99,99],
  [13253,99,100],[13254,99,8725,107,103],[13255,99,111,46],[13256,100,98],[13257,103,121],[13258,104,97],
  [13259,104,112],[13260,105,110],[13261,107,107],[13262,107,109],[13263,107,116],[13264,108,109],[13265,108,110],
  [13266,108,111,103],[13267,108,120],[13268,109,98],[13269,109,105,108],[13270,109,111,108],[13271,112,104],
  [13272,112,46,109,46],[13273,112,112,109],[13274,112,114],[13275,115,114],[13276,115,118],[13277,119,98],
  [13280,49,26085],[13281,50,26085],[13282,51,26085],[13283,52,26085],[13284,53,26085],[13285,54,26085],
  [13286,55,26085],[13287,56,26085],[13288,57,26085],[13289,49,48,26085],[13290,49,49,26085],[13291,49,50,26085],
  [13292,49,51,26085],[13293,49,52,26085],[13294,49,53,26085],[13295,49,54,26085],[13296,49,55,26085],
  [13297,49,56,26085],[13298,49,57,26085],[13299,50,48,26085],[13300,50,49,26085],[13301,50,50,26085],
  [13302,50,51,26085],[13303,50,52,26085],[13304,50,53,26085],[13305,50,54,26085],[13306,50,55,26085],
  [13307,50,56,26085],[13308,50,57,26085],[13309,51,48,26085],[13310,51,49,26085],[64256,102,102],[64257,102,105],
  [64258,102,108],[64259,102,102,105],[64260,102,102,108],[64261,115,116],[64262,115,116],[64275,1396,1398],
  [64276,1396,1381],[64277,1396,1387],[64278,1406,1398],[64279,1396,1389],[64288,1506],[64289,1488],[64295,1512],
  [64296,1514],[64297,43],[64335,1488,1500],[64336,1649],[64337,1649],[64338,1659],[64339,1659],[64340,1659],
  [64341,1659],[64342,1662],[64343,1662],[64344,1662],[64345,1662],[64346,1664],[64347,1664],[64348,1664],
  [64349,1664],[64350,1658],[64351,1658],[64352,1658],[64353,1658],[64354,1663],[64355,1663],[64356,1663],
  [64357,1663],[64358,1657],[64359,1657],[64360,1657],[64361,1657],[64362,1700],[64363,1700],[64364,1700],
  [64365,1700],[64366,1702],[64367,1702],[64368,1702],[64369,1702],[64370,1668],[64371,1668],[64372,1668],
  [64373,1668],[64374,1667],[64375,1667],[64376,1667],[64377,1667],[64378,1670],[64379,1670],[64380,1670],
  [64383,1671],[64384,1671],[64385,1671],[64386,1677],[64387,1677],[64388,1676],[64389,1676],[64390,1678],
  [64391,1678],[64392,1672],[64393,1672],[64394,1688],[64395,1688],[64396,1681],[64397,1681],[64398,1705],
  [64399,1705],[64400,1705],[64401,1705],[64402,1711],[64403,1711],[64404,1711],[64405,1711],[64406,1715],
  [64407,1715],[64408,1715],[64409,1715],[64410,1713],[64411,1713],[64412,1713],[64413,1713],[64414,1722],
  [64417,1723],[64418,1723],[64419,1723],[64420,1728],[64423,1729],[64424,1729],[64425,1729],[64426,1726],
  [64427,1726],[64428,1726],[64429,1726],[64430,1746],[64433,1747],[64467,1709],[64468,1709],[64469,1709],
  [64470,1709],[64471,1735],[64472,1735],[64473,1734],[64474,1734],[64475,1736],[64476,1736],[64477,1735,1652],
  [64478,1739],[64479,1739],[64480,1733],[64481,1733],[64482,1737],[64483,1737],[64484,1744],[64485,1744],
  [64486,1744],[64487,1744],[64488,1609],[64489,1609],[64490,1574,1575],[64491,1574,1575],[64492,1574,1749],
  [64493,1574,1749],[64494,1574,1608],[64495,1574,1608],[64496,1574,1735],[64497,1574,1735],[64498,1574,1734],
  [64499,1574,1734],[64500,1574,1736],[64501,1574,1736],[64502,1574,1744],[64503,1574,1744],[64504,1574,1744],
  [64505,1574,1609],[64506,1574,1609],[64507,1574,1609],[64508,1740],[64509,1740],[64510,1740],[64511,1740],
  [64512,1574,1580],[64513,1574,1581],[64514,1574,1605],[64515,1574,1609],[64516,1574,1610],[64517,1576,1580],
  [64518,1576,1581],[64519,1576,1582],[64520,1576,1605],[64521,1576,1609],[64522,1576,1610],[64523,1578,1580],
  [64524,1578,1581],[64525,1578,1582],[64526,1578,1605],[64527,1578,1609],[64528,1578,1610],[64529,1579,1580],
  [64530,1579,1605],[64531,1579,1609],[64532,1579,1610],[64533,1580,1581],[64534,1580,1605],[64535,1581,1580],
  [64536,1581,1605],[64537,1582,1580],[64538,1582,1581],[64539,1582,1605],[64540,1587,1580],[64541,1587,1581],
  [64542,1587,1582],[64543,1587,1605],[64544,1589,1581],[64545,1589,1605],[64546,1590,1580],[64547,1590,1581],
  [64548,1590,1582],[64549,1590,1605],[64550,1591,1581],[64551,1591,1605],[64552,1592,1605],[64553,1593,1580],
  [64554,1593,1605],[64555,1594,1580],[64556,1594,1605],[64557,1601,1580],[64558,1601,1581],[64559,1601,1582],
  [64560,1601,1605],[64561,1601,1609],[64562,1601,1610],[64563,1602,1581],[64564,1602,1605],[64565,1602,1609],
  [64566,1602,1610],[64567,1603,1575],[64568,1603,1580],[64569,1603,1581],[64570,1603,1582],[64571,1603,1604],
  [64572,1603,1605],[64573,1603,1609],[64574,1603,1610],[64575,1604,1580],[64576,1604,1581],[64577,1604,1582],
  [64578,1604,1605],[64579,1604,1609],[64580,1604,1610],[64581,1605,1580],[64582,1605,1581],[64583,1605,1582],
  [64584,1605,1605],[64585,1605,1609],[64586,1605,1610],[64587,1606,1580],[64588,1606,1581],[64589,1606,1582],
  [64590,1606,1605],[64591,1606,1609],[64592,1606,1610],[64593,1607,1580],[64594,1607,1605],[64595,1607,1609],
  [64596,1607,1610],[64597,1610,1580],[64598,1610,1581],[64599,1610,1582],[64600,1610,1605],[64601,1610,1609],
  [64602,1610,1610],[64603,1584,1648],[64604,1585,1648],[64605,1609,1648],[64606,32,1612,1617],[64607,32,1613,1617],
  [64608,32,1614,1617],[64609,32,1615,1617],[64610,32,1616,1617],[64611,32,1617,1648],[64612,1574,1585],
  [64613,1574,1586],[64614,1574,1605],[64615,1574,1606],[64616,1574,1609],[64617,1574,1610],[64618,1576,1585],
  [64619,1576,1586],[64620,1576,1605],[64621,1576,1606],[64622,1576,1609],[64623,1576,1610],[64624,1578,1585],
  [64625,1578,1586],[64626,1578,1605],[64627,1578,1606],[64628,1578,1609],[64629,1578,1610],[64630,1579,1585],
  [64631,1579,1586],[64632,1579,1605],[64633,1579,1606],[64634,1579,1609],[64635,1579,1610],[64636,1601,1609],
  [64637,1601,1610],[64638,1602,1609],[64639,1602,1610],[64640,1603,1575],[64641,1603,1604],[64642,1603,1605],
  [64643,1603,1609],[64644,1603,1610],[64645,1604,1605],[64646,1604,1609],[64647,1604,1610],[64648,1605,1575],
  [64649,1605,1605],[64650,1606,1585],[64651,1606,1586],[64652,1606,1605],[64653,1606,1606],[64654,1606,1609],
  [64655,1606,1610],[64656,1609,1648],[64657,1610,1585],[64658,1610,1586],[64659,1610,1605],[64660,1610,1606],
  [64661,1610,1609],[64662,1610,1610],[64663,1574,1580],[64664,1574,1581],[64665,1574,1582],[64666,1574,1605],
  [64667,1574,1607],[64668,1576,1580],[64669,1576,1581],[64670,1576,1582],[64671,1576,1605],[64672,1576,1607],
  [64673,1578,1580],[64674,1578,1581],[64675,1578,1582],[64676,1578,1605],[64677,1578,1607],[64678,1579,1605],
  [64679,1580,1581],[64680,1580,1605],[64681,1581,1580],[64682,1581,1605],[64683,1582,1580],[64684,1582,1605],
  [64685,1587,1580],[64686,1587,1581],[64687,1587,1582],[64688,1587,1605],[64689,1589,1581],[64690,1589,1582],
  [64691,1589,1605],[64692,1590,1580],[64693,1590,1581],[64694,1590,1582],[64695,1590,1605],[64696,1591,1581],
  [64697,1592,1605],[64698,1593,1580],[64699,1593,1605],[64700,1594,1580],[64701,1594,1605],[64702,1601,1580],
  [64703,1601,1581],[64704,1601,1582],[64705,1601,1605],[64706,1602,1581],[64707,1602,1605],[64708,1603,1580],
  [64709,1603,1581],[64710,1603,1582],[64711,1603,1604],[64712,1603,1605],[64713,1604,1580],[64714,1604,1581],
  [64715,1604,1582],[64716,1604,1605],[64717,1604,1607],[64718,1605,1580],[64719,1605,1581],[64720,1605,1582],
  [64721,1605,1605],[64722,1606,1580],[64723,1606,1581],[64724,1606,1582],[64725,1606,1605],[64726,1606,1607],
  [64727,1607,1580],[64728,1607,1605],[64729,1607,1648],[64730,1610,1580],[64731,1610,1581],[64732,1610,1582],
  [64733,1610,1605],[64734,1610,1607],[64735,1574,1605],[64736,1574,1607],[64737,1576,1605],[64738,1576,1607],
  [64739,1578,1605],[64740,1578,1607],[64741,1579,1605],[64742,1579,1607],[64743,1587,1605],[64744,1587,1607],
  [64745,1588,1605],[64746,1588,1607],[64747,1603,1604],[64748,1603,1605],[64749,1604,1605],[64750,1606,1605],
  [64751,1606,1607],[64752,1610,1605],[64753,1610,1607],[64754,1600,1614,1617],[64755,1600,1615,1617],
  [64756,1600,1616,1617],[64757,1591,1609],[64758,1591,1610],[64759,1593,1609],[64760,1593,1610],[64761,1594,1609],
  [64762,1594,1610],[64763,1587,1609],[64764,1587,1610],[64765,1588,1609],[64766,1588,1610],[64767,1581,1609],
  [64768,1581,1610],[64769,1580,1609],[64770,1580,1610],[64771,1582,1609],[64772,1582,1610],[64773,1589,1609],
  [64774,1589,1610],[64775,1590,1609],[64776,1590,1610],[64777,1588,1580],[64778,1588,1581],[64779,1588,1582],
  [64780,1588,1605],[64781,1588,1585],[64782,1587,1585],[64783,1589,1585],[64784,1590,1585],[64785,1591,1609],
  [64786,1591,1610],[64787,1593,1609],[64788,1593,1610],[64789,1594,1609],[64790,1594,1610],[64791,1587,1609],
  [64792,1587,1610],[64793,1588,1609],[64794,1588,1610],[64795,1581,1609],[64796,1581,1610],[64797,1580,1609],
  [64798,1580,1610],[64799,1582,1609],[64800,1582,1610],[64801,1589,1609],[64802,1589,1610],[64803,1590,1609],
  [64804,1590,1610],[64805,1588,1580],[64806,1588,1581],[64807,1588,1582],[64808,1588,1605],[64809,1588,1585],
  [64810,1587,1585],[64811,1589,1585],[64812,1590,1585],[64813,1588,1580],[64814,1588,1581],[64815,1588,1582],
  [64816,1588,1605],[64817,1587,1607],[64818,1588,1607],[64819,1591,1605],[64820,1587,1580],[64821,1587,1581],
  [64822,1587,1582],[64823,1588,1580],[64824,1588,1581],[64825,1588,1582],[64826,1591,1605],[64827,1592,1605],
  [64828,1575,1611],[64829,1575,1611],[64848,1578,1580,1605],[64849,1578,1581,1580],[64850,1578,1581,1580],
  [64851,1578,1581,1605],[64852,1578,1582,1605],[64853,1578,1605,1580],[64854,1578,1605,1581],[64855,1578,1605,1582],
  [64856,1580,1605,1581],[64857,1580,1605,1581],[64858,1581,1605,1610],[64859,1581,1605,1609],[64860,1587,1581,1580],
  [64861,1587,1580,1581],[64862,1587,1580,1609],[64863,1587,1605,1581],[64864,1587,1605,1581],[64865,1587,1605,1580],
  [64866,1587,1605,1605],[64867,1587,1605,1605],[64868,1589,1581,1581],[64869,1589,1581,1581],[64870,1589,1605,1605],
  [64871,1588,1581,1605],[64872,1588,1581,1605],[64873,1588,1580,1610],[64874,1588,1605,1582],[64875,1588,1605,1582],
  [64876,1588,1605,1605],[64877,1588,1605,1605],[64878,1590,1581,1609],[64879,1590,1582,1605],[64880,1590,1582,1605],
  [64881,1591,1605,1581],[64882,1591,1605,1581],[64883,1591,1605,1605],[64884,1591,1605,1610],[64885,1593,1580,1605],
  [64886,1593,1605,1605],[64887,1593,1605,1605],[64888,1593,1605,1609],[64889,1594,1605,1605],[64890,1594,1605,1610],
  [64891,1594,1605,1609],[64892,1601,1582,1605],[64893,1601,1582,1605],[64894,1602,1605,1581],[64895,1602,1605,1605],
  [64896,1604,1581,1605],[64897,1604,1581,1610],[64898,1604,1581,1609],[64899,1604,1580,1580],[64900,1604,1580,1580],
  [64901,1604,1582,1605],[64902,1604,1582,1605],[64903,1604,1605,1581],[64904,1604,1605,1581],[64905,1605,1581,1580],
  [64906,1605,1581,1605],[64907,1605,1581,1610],[64908,1605,1580,1581],[64909,1605,1580,1605],[64910,1605,1582,1580],
  [64911,1605,1582,1605],[64914,1605,1580,1582],[64915,1607,1605,1580],[64916,1607,1605,1605],[64917,1606,1581,1605],
  [64918,1606,1581,1609],[64919,1606,1580,1605],[64920,1606,1580,1605],[64921,1606,1580,1609],[64922,1606,1605,1610],
  [64923,1606,1605,1609],[64924,1610,1605,1605],[64925,1610,1605,1605],[64926,1576,1582,1610],[64927,1578,1580,1610],
  [64928,1578,1580,1609],[64929,1578,1582,1610],[64930,1578,1582,1609],[64931,1578,1605,1610],[64932,1578,1605,1609],
  [64933,1580,1605,1610],[64934,1580,1581,1609],[64935,1580,1605,1609],[64936,1587,1582,1609],[64937,1589,1581,1610],
  [64938,1588,1581,1610],[64939,1590,1581,1610],[64940,1604,1580,1610],[64941,1604,1605,1610],[64942,1610,1581,1610],
  [64943,1610,1580,1610],[64944,1610,1605,1610],[64945,1605,1605,1610],[64946,1602,1605,1610],[64947,1606,1581,1610],
  [64948,1602,1605,1581],[64949,1604,1581,1605],[64950,1593,1605,1610],[64951,1603,1605,1610],[64952,1606,1580,1581],
  [64953,1605,1582,1610],[64954,1604,1580,1605],[64955,1603,1605,1605],[64956,1604,1580,1605],[64957,1606,1580,1581],
  [64958,1580,1581,1610],[64959,1581,1580,1610],[64960,1605,1580,1610],[64961,1601,1605,1610],[64962,1576,1581,1610],
  [64963,1603,1605,1605],[64964,1593,1580,1605],[64965,1589,1605,1605],[64966,1587,1582,1610],[64967,1606,1580,1610],
  [65008,1589,1604,1746],[65009,1602,1604,1746],[65010,1575,1604,1604,1607],[65011,1575,1603,1576,1585],
  [65012,1605,1581,1605,1583],[65013,1589,1604,1593,1605],[65014,1585,1587,1608,1604],[65015,1593,1604,1610,1607],
  [65016,1608,1587,1604,1605],[65017,1589,1604,1609],
  [65018,1589,1604,1609,32,1575,1604,1604,1607,32,1593,1604,1610,1607,32,1608,1587,1604,1605],
  [65019,1580,1604,32,1580,1604,1575,1604,1607],[65020,1585,1740,1575,1604],[65024],[65025],[65026],[65027],[65028],
  [65029],[65030],[65031],[65032],[65033],[65034],[65035],[65036],[65037],[65038],[65039],[65072,46,46],[65073,8212],
  [65074,8211],[65075,95],[65076,95],[65079,123],[65080,125],[65097,32,773],[65098,32,773],[65099,32,773],
  [65100,32,773],[65101,95],[65102,95],[65103,95],[65104,44],[65105,12289],[65106,46],[65108,59],[65109,58],
  [65110,63],[65111,33],[65112,8212],[65115,123],[65116,125],[65119,35],[65120,38],[65123,45],[65124,60],[65125,62],
  [65126,61],[65128,92],[65131,64],[65136,32,1611],[65137,1600,1611],[65138,32,1612],[65140,32,1613],[65142,32,1614],
  [65143,1600,1614],[65144,32,1615],[65145,1600,1615],[65146,32,1616],[65147,1600,1616],[65148,32,1617],
  [65149,1600,1617],[65150,32,1618],[65151,1600,1618],[65162,1574],[65163,1574],[65168,1576],[65169,1576],
  [65174,1578],[65175,1578],[65178,1579],[65179,1579],[65182,1580],[65183,1580],[65186,1581],[65187,1581],
  [65190,1582],[65191,1582],[65202,1587],[65203,1587],[65206,1588],[65207,1588],[65210,1589],[65211,1589],
  [65214,1590],[65215,1590],[65218,1591],[65219,1591],[65222,1592],[65223,1592],[65226,1593],[65227,1593],
  [65230,1594],[65231,1594],[65232,1594],[65233,1601],[65234,1601],[65235,1601],[65238,1602],[65239,1602],
  [65242,1603],[65243,1603],[65246,1604],[65247,1604],[65250,1605],[65251,1605],[65254,1606],[65255,1606],
  [65258,1607],[65259,1607],[65266,1610],[65267,1610],[65268,1610],[65269,1604,1570],[65270,1604,1570],
  [65271,1604,1571],[65272,1604,1571],[65273,1604,1573],[65274,1604,1573],[65275,1604,1575],[65276,1604,1575],[65279],
  [65377,12290],[65380,12289],[65381,12539],[65382,12530],[65383,12449],[65384,12451],[65385,12453],[65386,12455],
  [65387,12457],[65388,12515],[65389,12517],[65390,12519],[65391,12483],[65392,12540],[65393,12450],[65394,12452],
  [65395,12454],[65396,12456],[65399,12461],[65400,12463],[65401,12465],[65402,12467],[65403,12469],[65404,12471],
  [65405,12473],[65406,12475],[65407,12477],[65408,12479],[65409,12481],[65410,12484],[65411,12486],[65412,12488],
  [65419,12498],[65420,12501],[65421,12504],[65422,12507],[65428,12516],[65429,12518],[65436,12527],[65437,12531],
  [65440,4448],[65443,4522],[65444,4354],[65456,4378],[65460,4385],[65506,172],[65507,32,772],[65508,166],[65509,165],
  [65510,8361],[65512,9474],[65517,9632],[65518,9675],[119964,97],[119970,103],[119995,102],[120134,111],[120505,952],
  [120513,8711],[120531,963],[120539,8706],[120540,949],[120541,952],[120542,954],[120543,966],[120544,961],
  [120545,960],[120563,952],[120571,8711],[120589,963],[120597,8706],[120598,949],[120599,952],[120600,954],
  [120601,966],[120602,961],[120603,960],[120621,952],[120629,8711],[120647,963],[120655,8706],[120656,949],
  [120657,952],[120658,954],[120659,966],[120660,961],[120661,960],[120679,952],[120687,8711],[120705,963],
  [120713,8706],[120714,949],[120715,952],[120716,954],[120717,966],[120718,961],[120719,960],[120737,952],
  [120745,8711],[120763,963],[120771,8706],[120772,949],[120773,952],[120774,954],[120775,966],[120776,961],
  [120777,960],[194664,136042],[194676,24371],[194847,17323],[194911,31406],[195007,19799]
]);
CREATE OR REPLACE MACRO gtfs_vc_idn_runs() AS ([
  [65,26,32],[178,2,-128],[192,23,32],[216,7,32],[393,2,205],[433,2,217],[904,3,37],[910,2,63],[913,17,32],[931,9,32],
  [1024,16,80],[1040,32,32],[1329,38,48],[7944,8,-8],[7960,6,-8],[7976,8,-8],[7992,8,-8],[8008,6,-8],[8040,8,-8],
  [8120,2,-8],[8152,2,-8],[8168,2,-8],[8308,6,-8256],[8317,2,-8277],[8320,10,-8272],[8333,2,-8293],[8458,2,-8355],
  [8473,3,-8361],[8492,2,-8394],[8496,2,-8395],[8501,4,-7013],[8518,2,-8418],[8520,2,-8415],[8557,2,-8458],
  [8573,2,-8474],[9312,9,-9263],[9398,26,-9301],[9424,26,-9327],[12345,2,8971],[12593,2,-8241],[12597,2,-8073],
  [12599,3,-8244],[12602,6,-8074],[12609,3,-8251],[12613,10,-8252],[12623,21,-8174],[12645,2,-8273],[12647,2,-8096],
  [12657,2,-8276],[12660,2,-8274],[12664,5,-8269],[12674,2,-8081],[12676,3,-8237],[12679,2,-8195],[12682,2,-8185],
  [12897,2,-8543],[12899,3,-8542],[12903,2,-8540],[12905,5,-8539],[13012,2,-554],[13028,6,-538],[13038,5,-528],
  [13045,6,-525],[13051,4,-524],[64290,2,-62799],[64292,3,-62793],[64381,2,-62711],[64415,2,-62693],[64421,2,-62693],
  [64431,2,-62685],[65077,2,-65037],[65081,2,-52773],[65083,2,-52779],[65085,2,-52787],[65087,2,-52791],
  [65089,4,-52789],[65113,2,-65073],[65117,2,-52809],[65121,2,-65079],[65129,2,-65093],[65152,2,-63583],
  [65154,2,-63584],[65156,2,-63585],[65158,2,-63586],[65160,2,-63587],[65164,2,-63590],[65166,2,-63591],
  [65170,2,-63594],[65172,2,-63595],[65176,2,-63598],[65180,2,-63601],[65184,2,-63604],[65188,2,-63607],
  [65192,2,-63610],[65194,2,-63611],[65196,2,-63612],[65198,2,-63613],[65200,2,-63614],[65204,2,-63617],
  [65208,2,-63620],[65212,2,-63623],[65216,2,-63626],[65220,2,-63629],[65224,2,-63632],[65228,2,-63635],
  [65236,2,-63635],[65240,2,-63638],[65244,2,-63641],[65248,2,-63644],[65252,2,-63647],[65256,2,-63650],
  [65260,2,-63653],[65262,2,-63654],[65264,2,-63655],[65281,32,-65248],[65313,26,-65216],[65339,36,-65248],
  [65375,2,-54746],[65378,2,-53078],[65397,2,-52939],[65413,6,-52923],[65423,5,-52913],[65430,6,-52910],
  [65438,2,-52997],[65441,2,-61089],[65445,2,-60921],[65447,3,-61092],[65450,6,-60922],[65457,3,-61099],
  [65461,10,-61100],[65474,6,-61025],[65482,6,-61027],[65490,6,-61029],[65498,3,-61031],[65504,2,-65342],
  [65513,4,-56921],[66560,38,40],[119808,26,-119711],[119834,26,-119737],[119860,26,-119763],[119886,7,-119789],
  [119894,18,-119789],[119912,26,-119815],[119938,26,-119841],[119966,2,-119867],[119973,2,-119867],
  [119977,4,-119867],[119982,8,-119867],[119990,4,-119893],[119997,4,-119893],[120002,2,-119893],[120005,11,-119893],
  [120016,26,-119919],[120042,26,-119945],[120068,2,-119971],[120071,4,-119971],[120077,8,-119971],[120086,7,-119971],
  [120094,26,-119997],[120120,2,-120023],[120123,4,-120023],[120128,5,-120023],[120138,7,-120023],[120146,26,-120049],
  [120172,26,-120075],[120198,26,-120101],[120224,26,-120127],[120250,26,-120153],[120276,26,-120179],
  [120302,26,-120205],[120328,26,-120231],[120354,26,-120257],[120380,26,-120283],[120406,26,-120309],
  [120432,26,-120335],[120458,26,-120361],[120488,17,-119543],[120506,7,-119543],[120514,17,-119569],
  [120532,7,-119569],[120546,17,-119601],[120564,7,-119601],[120572,17,-119627],[120590,7,-119627],
  [120604,17,-119659],[120622,7,-119659],[120630,17,-119685],[120648,7,-119685],[120662,17,-119717],
  [120680,7,-119717],[120688,17,-119743],[120706,7,-119743],[120720,17,-119775],[120738,7,-119775],
  [120746,17,-119801],[120764,7,-119801],[120782,10,-120734],[120792,10,-120744],[120802,10,-120754],
  [120812,10,-120764],[120822,10,-120774]
]);
-- Input code points StringPrep refuses as unassigned in Unicode 3.2 (A.1).
CREATE OR REPLACE MACRO gtfs_vc_idn_unassigned_re() AS (
  '[\x{221}\x{234}-\x{24F}\x{2AE}-\x{2AF}\x{2EF}-\x{2FF}\x{350}-\x{35F}\x{370}-\x{373}\x{376}-\x{379}\x{37B}-\x{37D}'
  || '\x{37F}-\x{383}\x{38B}\x{38D}\x{3A2}\x{3CF}\x{3F7}-\x{3FF}\x{487}\x{4CF}\x{4F6}-\x{4F7}\x{4FA}-\x{4FF}'
  || '\x{510}-\x{530}\x{557}-\x{558}\x{560}\x{588}\x{58B}-\x{590}\x{5A2}\x{5BA}\x{5C5}-\x{5CF}\x{5EB}-\x{5EF}'
  || '\x{5F5}-\x{60B}\x{60D}-\x{61A}\x{61C}-\x{61E}\x{620}\x{63B}-\x{63F}\x{656}-\x{65F}\x{6EE}-\x{6EF}\x{6FF}'
  || '\x{70E}\x{72D}-\x{72F}\x{74B}-\x{77F}\x{7B2}-\x{900}\x{904}\x{93A}-\x{93B}\x{94E}-\x{94F}\x{955}-\x{957}'
  || '\x{971}-\x{980}\x{984}\x{98D}-\x{98E}\x{991}-\x{992}\x{9A9}\x{9B1}\x{9B3}-\x{9B5}\x{9BA}-\x{9BB}\x{9BD}'
  || '\x{9C5}-\x{9C6}\x{9C9}-\x{9CA}\x{9CE}-\x{9D6}\x{9D8}-\x{9DB}\x{9DE}\x{9E4}-\x{9E5}\x{9FB}-\x{A01}'
  || '\x{A03}-\x{A04}\x{A0B}-\x{A0E}\x{A11}-\x{A12}\x{A29}\x{A31}\x{A34}\x{A37}\x{A3A}-\x{A3B}\x{A3D}\x{A43}-\x{A46}'
  || '\x{A49}-\x{A4A}\x{A4E}-\x{A58}\x{A5D}\x{A5F}-\x{A65}\x{A75}-\x{A80}\x{A84}\x{A8C}\x{A8E}\x{A92}\x{AA9}\x{AB1}'
  || '\x{AB4}\x{ABA}-\x{ABB}\x{AC6}\x{ACA}\x{ACE}-\x{ACF}\x{AD1}-\x{ADF}\x{AE1}-\x{AE5}\x{AF0}-\x{B00}\x{B04}'
  || '\x{B0D}-\x{B0E}\x{B11}-\x{B12}\x{B29}\x{B31}\x{B34}-\x{B35}\x{B3A}-\x{B3B}\x{B44}-\x{B46}\x{B49}-\x{B4A}'
  || '\x{B4E}-\x{B55}\x{B58}-\x{B5B}\x{B5E}\x{B62}-\x{B65}\x{B71}-\x{B81}\x{B84}\x{B8B}-\x{B8D}\x{B91}'
  || '\x{B96}-\x{B98}\x{B9B}\x{B9D}\x{BA0}-\x{BA2}\x{BA5}-\x{BA7}\x{BAB}-\x{BAD}\x{BB6}\x{BBA}-\x{BBD}'
  || '\x{BC3}-\x{BC5}\x{BC9}\x{BCE}-\x{BD6}\x{BD8}-\x{BE6}\x{BF3}-\x{C00}\x{C04}\x{C0D}\x{C11}\x{C29}\x{C34}'
  || '\x{C3A}-\x{C3D}\x{C45}\x{C49}\x{C4E}-\x{C54}\x{C57}-\x{C5F}\x{C62}-\x{C65}\x{C70}-\x{C81}\x{C84}\x{C8D}\x{C91}'
  || '\x{CA9}\x{CB4}\x{CBA}-\x{CBD}\x{CC5}\x{CC9}\x{CCE}-\x{CD4}\x{CD7}-\x{CDD}\x{CDF}\x{CE2}-\x{CE5}\x{CF0}-\x{D01}'
  || '\x{D04}\x{D0D}\x{D11}\x{D29}\x{D3A}-\x{D3D}\x{D44}-\x{D45}\x{D49}\x{D4E}-\x{D56}\x{D58}-\x{D5F}\x{D62}-\x{D65}'
  || '\x{D70}-\x{D81}\x{D84}\x{D97}-\x{D99}\x{DB2}\x{DBC}\x{DBE}-\x{DBF}\x{DC7}-\x{DC9}\x{DCB}-\x{DCE}\x{DD5}\x{DD7}'
  || '\x{DE0}-\x{DF1}\x{DF5}-\x{E00}\x{E3B}-\x{E3E}\x{E5C}-\x{E80}\x{E83}\x{E85}-\x{E86}\x{E89}\x{E8B}-\x{E8C}'
  || '\x{E8E}-\x{E93}\x{E98}\x{EA0}\x{EA4}\x{EA6}\x{EA8}-\x{EA9}\x{EAC}\x{EBA}\x{EBE}-\x{EBF}\x{EC5}\x{EC7}'
  || '\x{ECE}-\x{ECF}\x{EDA}-\x{EDB}\x{EDE}-\x{EFF}\x{F48}\x{F6B}-\x{F70}\x{F8C}-\x{F8F}\x{F98}\x{FBD}'
  || '\x{FCD}-\x{FCE}\x{FD0}-\x{FFF}\x{1022}\x{1028}\x{102B}\x{1033}-\x{1035}\x{103A}-\x{103F}\x{105A}-\x{109F}'
  || '\x{10C6}-\x{10CF}\x{10F9}-\x{10FA}\x{10FC}-\x{10FF}\x{115A}-\x{115E}\x{11A3}-\x{11A7}\x{11FA}-\x{11FF}\x{1207}'
  || '\x{1247}\x{1249}\x{124E}-\x{124F}\x{1257}\x{1259}\x{125E}-\x{125F}\x{1287}\x{1289}\x{128E}-\x{128F}\x{12AF}'
  || '\x{12B1}\x{12B6}-\x{12B7}\x{12BF}\x{12C1}\x{12C6}-\x{12C7}\x{12CF}\x{12D7}\x{12EF}\x{130F}\x{1311}'
  || '\x{1316}-\x{1317}\x{131F}\x{1347}\x{135B}-\x{1360}\x{137D}-\x{139F}\x{13F5}-\x{1400}\x{1677}-\x{167F}'
  || '\x{169D}-\x{169F}\x{16F1}-\x{16FF}\x{170D}\x{1715}-\x{171F}\x{1737}-\x{173F}\x{1754}-\x{175F}\x{176D}\x{1771}'
  || '\x{1774}-\x{177F}\x{17DD}-\x{17DF}\x{17EA}-\x{17FF}\x{180F}\x{181A}-\x{181F}\x{1878}-\x{187F}\x{18AA}-\x{1DFF}'
  || '\x{1E9C}-\x{1E9F}\x{1EFA}-\x{1EFF}\x{1F16}-\x{1F17}\x{1F1E}-\x{1F1F}\x{1F46}-\x{1F47}\x{1F4E}-\x{1F4F}\x{1F58}'
  || '\x{1F5A}\x{1F5C}\x{1F5E}\x{1F7E}-\x{1F7F}\x{1FB5}\x{1FC5}\x{1FD4}-\x{1FD5}\x{1FDC}\x{1FF0}-\x{1FF1}\x{1FF5}'
  || '\x{1FFF}\x{2053}-\x{2056}\x{2058}-\x{205E}\x{2064}-\x{2069}\x{2072}-\x{2073}\x{208F}-\x{209F}\x{20B2}-\x{20CF}'
  || '\x{20EB}-\x{20FF}\x{213B}-\x{213C}\x{214C}-\x{2152}\x{2184}-\x{218F}\x{23CF}-\x{23FF}\x{2427}-\x{243F}'
  || '\x{244B}-\x{245F}\x{24FF}\x{2614}-\x{2615}\x{2618}\x{267E}-\x{267F}\x{268A}-\x{2700}\x{2705}\x{270A}-\x{270B}'
  || '\x{2728}\x{274C}\x{274E}\x{2753}-\x{2755}\x{2757}\x{275F}-\x{2760}\x{2795}-\x{2797}\x{27B0}\x{27BF}-\x{27CF}'
  || '\x{27EC}-\x{27EF}\x{2B00}-\x{2E7F}\x{2E9A}\x{2EF4}-\x{2EFF}\x{2FD6}-\x{2FEF}\x{2FFC}-\x{2FFF}\x{3040}'
  || '\x{3097}-\x{3098}\x{3100}-\x{3104}\x{312D}-\x{3130}\x{318F}\x{31B8}-\x{31EF}\x{321D}-\x{321F}\x{3244}-\x{3250}'
  || '\x{327C}-\x{327E}\x{32CC}-\x{32CF}\x{32FF}\x{3377}-\x{337A}\x{33DE}-\x{33DF}\x{33FF}\x{4DB6}-\x{4DFF}'
  || '\x{9FA6}-\x{9FFF}\x{A48D}-\x{A48F}\x{A4C7}-\x{ABFF}\x{D7A4}-\x{D7FF}\x{FA2E}-\x{FA2F}\x{FA6B}-\x{FAFF}'
  || '\x{FB07}-\x{FB12}\x{FB18}-\x{FB1C}\x{FB37}\x{FB3D}\x{FB3F}\x{FB42}\x{FB45}\x{FBB2}-\x{FBD2}\x{FD40}-\x{FD4F}'
  || '\x{FD90}-\x{FD91}\x{FDC8}-\x{FDCF}\x{FDFD}-\x{FDFF}\x{FE10}-\x{FE1F}\x{FE24}-\x{FE2F}\x{FE47}-\x{FE48}\x{FE53}'
  || '\x{FE67}\x{FE6C}-\x{FE6F}\x{FE75}\x{FEFD}-\x{FEFE}\x{FF00}\x{FFBF}-\x{FFC1}\x{FFC8}-\x{FFC9}\x{FFD0}-\x{FFD1}'
  || '\x{FFD8}-\x{FFD9}\x{FFDD}-\x{FFDF}\x{FFE7}\x{FFEF}-\x{FFF8}\x{10000}-\x{102FF}\x{1031F}\x{10324}-\x{1032F}'
  || '\x{1034B}-\x{103FF}\x{10426}-\x{10427}\x{1044E}-\x{1CFFF}\x{1D0F6}-\x{1D0FF}\x{1D127}-\x{1D129}'
  || '\x{1D1DE}-\x{1D3FF}\x{1D455}\x{1D49D}\x{1D4A0}-\x{1D4A1}\x{1D4A3}-\x{1D4A4}\x{1D4A7}-\x{1D4A8}\x{1D4AD}'
  || '\x{1D4BA}\x{1D4BC}\x{1D4C1}\x{1D4C4}\x{1D506}\x{1D50B}-\x{1D50C}\x{1D515}\x{1D51D}\x{1D53A}\x{1D53F}\x{1D545}'
  || '\x{1D547}-\x{1D549}\x{1D551}\x{1D6A4}-\x{1D6A7}\x{1D7CA}-\x{1D7CD}\x{1D800}-\x{1FFFD}\x{2A6D7}-\x{2F7FF}'
  || '\x{2FA1E}-\x{2FFFD}\x{30000}-\x{3FFFD}\x{40000}-\x{4FFFD}\x{50000}-\x{5FFFD}\x{60000}-\x{6FFFD}'
  || '\x{70000}-\x{7FFFD}\x{80000}-\x{8FFFD}\x{90000}-\x{9FFFD}\x{A0000}-\x{AFFFD}\x{B0000}-\x{BFFFD}'
  || '\x{C0000}-\x{CFFFD}\x{D0000}-\x{DFFFD}\x{E0000}\x{E0002}-\x{E001F}\x{E0080}-\x{EFFFD}]'
);
-- Prepared code points StringPrep refuses as prohibited (C.1.2 to C.9).
CREATE OR REPLACE MACRO gtfs_vc_idn_prohibited_re() AS (
  '[\x{80}-\x{A0}\x{340}-\x{341}\x{6DD}\x{70F}\x{1680}\x{180E}\x{2000}-\x{200A}\x{200E}-\x{200F}\x{2028}-\x{202F}'
  || '\x{205F}\x{2061}-\x{206F}\x{2FF0}-\x{3000}\x{E000}-\x{F8FF}\x{FDD0}-\x{FDEF}\x{FFF9}-\x{FFFF}'
  || '\x{1D173}-\x{1D17A}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{10FFFF}]'
);
-- Prepared code points of bidi class R or AL, and of class L (jdk.internal.icu UCharacter.getDirection).
CREATE OR REPLACE MACRO gtfs_vc_idn_r_re() AS (
  '[\x{5BE}\x{5C0}\x{5C3}\x{5D0}-\x{5F4}\x{61B}-\x{64A}\x{66D}-\x{66F}\x{671}-\x{6D5}\x{6E5}-\x{6E6}\x{6FA}-\x{710}'
  || '\x{712}-\x{72C}\x{780}-\x{7A5}\x{7B1}\x{FB1D}\x{FB1F}-\x{FB28}\x{FB2A}-\x{FD3D}\x{FD50}-\x{FDFC}'
  || '\x{FE70}-\x{FEFC}]'
);
CREATE OR REPLACE MACRO gtfs_vc_idn_r_ends_re() AS (
  '(?s)[\x{5BE}\x{5C0}\x{5C3}\x{5D0}-\x{5F4}\x{61B}-\x{64A}\x{66D}-\x{66F}\x{671}-\x{6D5}\x{6E5}-\x{6E6}'
  || '\x{6FA}-\x{710}\x{712}-\x{72C}\x{780}-\x{7A5}\x{7B1}\x{FB1D}\x{FB1F}-\x{FB28}\x{FB2A}-\x{FD3D}'
  || '\x{FD50}-\x{FDFC}\x{FE70}-\x{FEFC}]'
  || '(?:.*'
  '[\x{5BE}\x{5C0}\x{5C3}\x{5D0}-\x{5F4}\x{61B}-\x{64A}\x{66D}-\x{66F}\x{671}-\x{6D5}\x{6E5}-\x{6E6}\x{6FA}-\x{710}'
  || '\x{712}-\x{72C}\x{780}-\x{7A5}\x{7B1}\x{FB1D}\x{FB1F}-\x{FB28}\x{FB2A}-\x{FD3D}\x{FD50}-\x{FDFC}'
  || '\x{FE70}-\x{FEFC}])?'
);
CREATE OR REPLACE MACRO gtfs_vc_idn_l_re() AS (
  '[\x{41}-\x{5A}\x{61}-\x{7A}\x{AA}\x{B5}\x{BA}\x{C0}-\x{D6}\x{D8}-\x{F6}\x{F8}-\x{2B8}\x{2BB}-\x{2C1}'
  || '\x{2D0}-\x{2D1}\x{2E0}-\x{2E4}\x{2EE}\x{37A}\x{386}\x{388}-\x{3F5}\x{400}-\x{482}\x{48A}-\x{589}'
  || '\x{903}-\x{939}\x{93D}-\x{940}\x{949}-\x{94C}\x{950}\x{958}-\x{961}\x{964}-\x{970}\x{982}-\x{9B9}'
  || '\x{9BE}-\x{9C0}\x{9C7}-\x{9CC}\x{9D7}-\x{9E1}\x{9E6}-\x{9F1}\x{9F4}-\x{9FA}\x{A05}-\x{A39}\x{A3E}-\x{A40}'
  || '\x{A59}-\x{A6F}\x{A72}-\x{A74}\x{A83}-\x{AB9}\x{ABD}-\x{AC0}\x{AC9}-\x{ACC}\x{AD0}-\x{AEF}\x{B02}-\x{B39}'
  || '\x{B3D}-\x{B3E}\x{B40}\x{B47}-\x{B4C}\x{B57}-\x{B70}\x{B83}-\x{BBF}\x{BC1}-\x{BCC}\x{BD7}-\x{C39}'
  || '\x{C41}-\x{C44}\x{C60}-\x{CCB}\x{CD5}-\x{D40}\x{D46}-\x{D4C}\x{D57}-\x{DC6}\x{DCF}-\x{DD1}\x{DD8}-\x{E30}'
  || '\x{E32}-\x{E33}\x{E40}-\x{E46}\x{E4F}-\x{EB0}\x{EB2}-\x{EB3}\x{EBD}-\x{EC6}\x{ED0}-\x{F17}\x{F1A}-\x{F34}'
  || '\x{F36}\x{F38}\x{F3E}-\x{F6A}\x{F7F}\x{F85}\x{F88}-\x{F8B}\x{FBE}-\x{FC5}\x{FC7}-\x{102C}\x{1031}\x{1038}'
  || '\x{1040}-\x{1057}\x{10A0}-\x{169A}\x{16A0}-\x{1711}\x{1720}-\x{1731}\x{1735}-\x{1751}\x{1760}-\x{1770}'
  || '\x{1780}-\x{17B3}\x{17B6}\x{17BE}-\x{17C5}\x{17C7}-\x{17C8}\x{17D4}-\x{17DA}\x{17DC}-\x{17E9}\x{1810}-\x{1884}'
  || '\x{1887}-\x{18A8}\x{1E00}-\x{1FBC}\x{1FBE}\x{1FC2}-\x{1FCC}\x{1FD0}-\x{1FDB}\x{1FE0}-\x{1FEC}\x{1FF2}-\x{1FFC}'
  || '\x{2071}\x{207F}\x{2102}\x{2107}\x{210A}-\x{2113}\x{2115}\x{2119}-\x{211D}\x{2124}\x{2126}\x{2128}'
  || '\x{212A}-\x{212D}\x{212F}-\x{2139}\x{213D}-\x{213F}\x{2145}-\x{2149}\x{2160}-\x{2183}\x{2336}-\x{237A}\x{2395}'
  || '\x{249C}-\x{24E9}\x{2800}-\x{28FF}\x{3005}-\x{3007}\x{3021}-\x{3029}\x{302E}-\x{302F}\x{3031}-\x{3035}'
  || '\x{3038}-\x{303C}\x{3041}-\x{3096}\x{309D}-\x{309F}\x{30A1}-\x{30FA}\x{30FC}-\x{3243}\x{3260}-\x{32B0}'
  || '\x{32C0}-\x{A48C}\x{AC00}-\x{FB17}\x{FF21}-\x{FF3A}\x{FF41}-\x{FF5A}\x{FF66}-\x{FFDC}\x{10300}-\x{1D166}'
  || '\x{1D16A}-\x{1D172}\x{1D183}-\x{1D184}\x{1D18C}-\x{1D1A9}\x{1D1AE}-\x{1D6DA}\x{1D6DC}-\x{1D714}'
  || '\x{1D716}-\x{1D74E}\x{1D750}-\x{1D788}\x{1D78A}-\x{1D7C2}\x{1D7C4}-\x{1D7C9}\x{20000}-\x{2FA1D}]'
);
-- END GENERATED
-- The generated map as two strings, built once per query (constant folding): ks holds every mapped code point, and
-- field i of vs (separated by chr(1)) is what the i-th code point of ks maps to.
CREATE OR REPLACE MACRO gtfs_vc_idn_table() AS ({
  'ks': array_to_string(list_transform(list_concat(
          list_transform(gtfs_vc_idn_entries(), lambda e: e[1]),
          flatten(list_transform(gtfs_vc_idn_runs(), lambda r: range(r[1], r[1] + r[2])))), lambda c: chr(c::INTEGER)), ''),
  'vs': array_to_string(list_concat(
          list_transform(gtfs_vc_idn_entries(),
            lambda e: coalesce(array_to_string(list_transform(e[2:], lambda c: chr(c)), ''), '')),
          flatten(list_transform(gtfs_vc_idn_runs(),
            lambda r: list_transform(range(r[1], r[1] + r[2]), lambda c: chr((c + r[3])::INTEGER))))), chr(1))
});
-- Punycode digit d (0..35) as a lowercase letter or a digit.
CREATE OR REPLACE MACRO gtfs_vc_idn_digit(d) AS (chr((CASE WHEN d < 26 THEN 97 + d ELSE 22 + d END)::INTEGER));
-- 35^n for n in 0..6.
CREATE OR REPLACE MACRO gtfs_vc_idn_pow35(n) AS (
  CASE n WHEN 0 THEN 1 WHEN 1 THEN 35 WHEN 2 THEN 1225 WHEN 3 THEN 42875 WHEN 4 THEN 1500625 WHEN 5 THEN 52521875
         ELSE 1838265625 END::BIGINT
);
-- Punycode adapt(): e1 is e0 + e0 / numpoints with e0 = delta / 700 (first) or delta / 2; the number t of
-- divisions by 35 is the number of thresholds 456 * 35^j that e1 reaches; the bias is 36 * t + 36 * e2 / (e2 + 38)
-- with e2 = e1 / 35^t.
CREATE OR REPLACE MACRO gtfs_vc_idn_adapt_t(e1) AS (
  (e1 >= 456)::INTEGER + (e1 >= 15960)::INTEGER + (e1 >= 558600)::INTEGER + (e1 >= 19551000)::INTEGER
  + (e1 >= 684285000)::INTEGER
);
CREATE OR REPLACE MACRO gtfs_vc_idn_adapt1(e1) AS (
  list_transform([e1 // gtfs_vc_idn_pow35(gtfs_vc_idn_adapt_t(e1))], lambda e2:
    36 * gtfs_vc_idn_adapt_t(e1) + (36 * e2) // (e2 + 38))[1]
);
CREATE OR REPLACE MACRO gtfs_vc_idn_adapt(delta, numpoints, first) AS (
  list_transform([CASE WHEN first THEN delta // 700 ELSE delta // 2 END], lambda e0:
    gtfs_vc_idn_adapt1(e0 + e0 // numpoints))[1]
);
-- Threshold of digit i for a bias: tmin 1 before digit bias / 36, min(26, 36 - bias mod 36) at it, tmax 26 after.
CREATE OR REPLACE MACRO gtfs_vc_idn_t(i, bias) AS (
  CASE WHEN i < bias // 36 THEN 1 WHEN i = bias // 36 THEN least(26, 36 - bias % 36) ELSE 26 END::BIGINT
);
-- The generalized variable-length integer of a delta q for a bias, as Punycode.encode's digit loop: list_reduce over
-- states {q, out, done, i} (the first element is the initial state; no initial value, for DuckDB 1.4). A delta of a
-- label under 60 code points needs at most 8 digits.
CREATE OR REPLACE MACRO gtfs_vc_idn_digits(q, bias) AS (
  list_reduce(list_concat([{'q': q::BIGINT, 'out': ''::VARCHAR, 'done': false, 'i': -1::BIGINT}],
                          list_transform(range(0, 9), lambda di: {'q': 0::BIGINT, 'out': ''::VARCHAR, 'done': false,
                                                                 'i': di::BIGINT})),
    lambda st, dg: CASE
      WHEN st.done THEN st
      WHEN st.q < gtfs_vc_idn_t(dg.i, bias)
        THEN {'q': st.q, 'out': st.out || gtfs_vc_idn_digit(st.q), 'done': true, 'i': dg.i}
      ELSE {'q': (st.q - gtfs_vc_idn_t(dg.i, bias)) // (36 - gtfs_vc_idn_t(dg.i, bias)),
            'out': st.out || gtfs_vc_idn_digit(gtfs_vc_idn_t(dg.i, bias)
                                                + (st.q - gtfs_vc_idn_t(dg.i, bias)) % (36 - gtfs_vc_idn_t(dg.i, bias))),
            'done': false, 'i': dg.i}
    END).out
);
-- Delta k of the non-basic code points ins (sorted {v, i}) after b basic ones.
CREATE OR REPLACE MACRO gtfs_vc_idn_delta(ins, b, k) AS (
  CASE WHEN k = 1 THEN (ins[1].v - 128) * (b + 1) + ins[1].i
       ELSE (ins[k].v - ins[k - 1].v) * (b + k) + ins[k].i - ins[k - 1].i - 1 END
);
-- RFC 3492 Punycode encoding of the code points x (jdk.internal.icu.impl.Punycode.encode) with the deltas in closed
-- form: inserting the k-th non-basic code point (by value, then position) of value v at index i (the code points
-- before it whose value is at most v) after b basic ones gives delta (v - v') * (b + k) + i - i' - 1 from the previous
-- insertion (v', i'), and (v - 128) * (b + 1) + i for the first. Then a list_reduce over the deltas carries the bias
-- (72, then adapt(delta, b + k, k = 1)) and the output. A label of 60 or more code points is too long before
-- encoding, so the deltas fit a BIGINT.
CREATE OR REPLACE MACRO gtfs_vc_idn_punycode(x) AS (
  list_transform([{'y': x, 'b': len(list_filter(x, lambda c: c < 128))::BIGINT,
                   'ins': list_sort(list_transform(list_filter(range(1, len(x) + 1), lambda j: x[j] >= 128),
                            lambda j: {'v': x[j]::BIGINT, 'i': len(list_filter(x[1:j - 1], lambda c: c <= x[j]))::BIGINT}))}],
    lambda p: coalesce(array_to_string(list_transform(list_filter(p.y, lambda c: c < 128), lambda c: chr(c)), ''), '')
      || CASE WHEN p.b > 0 THEN '-' ELSE '' END
      || list_reduce(list_concat([{'d': 0::BIGINT, 'bias': 72::BIGINT, 'out': ''::VARCHAR, 'k': 0::BIGINT}],
                                 list_transform(range(1, len(p.ins) + 1), lambda k: {'d': gtfs_vc_idn_delta(p.ins, p.b, k)::BIGINT,
                                   'bias': 0::BIGINT, 'out': ''::VARCHAR, 'k': k::BIGINT})),
           lambda acc, e: {'d': e.d, 'bias': gtfs_vc_idn_adapt(e.d, p.b + e.k, e.k = 1)::BIGINT,
                           'out': acc.out || gtfs_vc_idn_digits(e.d, acc.bias), 'k': e.k}).out)[1]
);
-- IDN.toASCIIInternal after StringPrep's map and NFKC (p): the prohibited and RFC 3454 bidi checks, the empty label,
-- an ASCII result as is, else no ACE prefix and Punycode; at most 63 characters.
CREATE OR REPLACE MACRO gtfs_vc_idn_prepared(p) AS (
  list_transform([p], lambda q:
    CASE WHEN regexp_matches(q, gtfs_vc_idn_prohibited_re()) THEN NULL
         WHEN regexp_matches(q, gtfs_vc_idn_r_re())
              AND (regexp_matches(q, gtfs_vc_idn_l_re()) OR NOT regexp_full_match(q, gtfs_vc_idn_r_ends_re())) THEN NULL
         WHEN q = '' THEN NULL
         WHEN NOT regexp_matches(q, '[^\x00-\x7F]') THEN (CASE WHEN length(q) <= 63 THEN q END)
         WHEN regexp_matches(q, '^[xX][nN]--') OR length(q) >= 60 THEN NULL
         ELSE list_transform(['xn--' || lower(gtfs_vc_idn_punycode(list_transform(string_split(q, ''), lambda c: unicode(c))))],
                lambda o: CASE WHEN length(o) <= 63 THEN o END)[1]
    END)[1]
);
-- One label: an ASCII one as is (1 to 63 characters); otherwise no unassigned code point, then nameprep: the
-- generated map of each code point (B.1, B.2 and NFKC), and nfc_normalize to compose across code points.
CREATE OR REPLACE MACRO gtfs_vc_idn_label(l, t) AS (
  CASE WHEN NOT regexp_matches(l, '[^\x00-\x7F]') THEN (CASE WHEN length(l) BETWEEN 1 AND 63 THEN l END)
       WHEN regexp_matches(l, gtfs_vc_idn_unassigned_re()) THEN NULL
       ELSE gtfs_vc_idn_prepared(nfc_normalize(coalesce(array_to_string(list_transform(string_split(l, ''),
              lambda c: CASE WHEN contains(t.ks, c) THEN split_part(t.vs, chr(1), instr(t.ks, c)) ELSE c END), ''), '')))
  END
);
-- java.net.IDN.toASCII(a) on Java 17, NULL where it throws: a lone dot is the root label, labels end at the four
-- dots (. U+3002 U+FF0E U+FF61), a final dot is kept, every label goes through gtfs_vc_idn_label.
CREATE OR REPLACE MACRO gtfs_vc_idn_to_ascii(a) AS (
  list_transform([{'a': a, 't': gtfs_vc_idn_table()}], lambda z:
    CASE WHEN z.a = '' THEN ''
         WHEN length(z.a) = 1 AND regexp_full_match(z.a, '[.\x{3002}\x{FF0E}\x{FF61}]') THEN '.'
         ELSE list_transform([list_transform(CASE WHEN regexp_matches(z.a, '[.\x{3002}\x{FF0E}\x{FF61}]$')
                                                  THEN regexp_split_to_array(z.a, '[.\x{3002}\x{FF0E}\x{FF61}]')[:-2]
                                                  ELSE regexp_split_to_array(z.a, '[.\x{3002}\x{FF0E}\x{FF61}]') END,
                                             lambda l: gtfs_vc_idn_label(l, z.t))],
                lambda cs: CASE WHEN len(list_filter(cs, lambda c: c IS NULL)) = 0
                                THEN array_to_string(cs, '.')
                                     || CASE WHEN regexp_matches(z.a, '[.\x{3002}\x{FF0E}\x{FF61}]$') THEN '.' ELSE '' END
                           END)[1]
    END)[1]
);
-- commons-validator 1.6 UrlValidator.getInstance().isValid: URL_REGEX parts, scheme http/https/ftp, an authority
-- (AUTHORITY_REGEX: [IPv6] or userinfo@host, port, nothing else), PATH_REGEX without '//' and without '..' above the
-- root (URI.normalize), a query without whitespace. Hosts: DomainValidator (labels, a known TLD) or an IPv4 address.
-- Java's '.' excludes the line terminators \n \r U+0085 U+2028 U+2029; RE2's '.' only excludes \n, so it is spelled out.
CREATE OR REPLACE MACRO gtfs_vc_url_re() AS (
  '^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#([^\n\r\x{85}\x{2028}\x{2029}]*))?$'
);
CREATE OR REPLACE MACRO gtfs_vc_authority_re() AS (
  '^(?:\[([0-9a-fA-F:]+)\]|(?:(?:[a-zA-Z0-9%-._~!$&''()*+,;=]+(?::[a-zA-Z0-9%-._~!$&''()*+,;=]*)?@)?([A-Za-z0-9.-]*)))'
  || '(?::([0-9]*))?([^\n\r\x{85}\x{2028}\x{2029}]*)$'
);
CREATE OR REPLACE MACRO gtfs_vc_domain_re() AS (
  '^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+([A-Za-z](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)\.?$'
);
-- InetAddressValidator.isValidInet4Address
CREATE OR REPLACE MACRO gtfs_vc_ipv4_ok(h) AS (
  regexp_full_match(h, '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
  AND list_bool_and(list_transform(string_split(h, '.'),
        lambda o: TRY_CAST(o AS INTEGER) <= 255 AND (length(o) = 1 OR NOT starts_with(o, '0'))))
);
-- InetAddressValidator.isValidInet6Address (h holds only hex digits and ':')
CREATE OR REPLACE MACRO gtfs_vc_ipv6_ok(h) AS (
  (NOT contains(h, '::') OR strpos(h, '::') = length(h) - strpos(reverse(h), '::'))
  AND NOT (starts_with(h, ':') AND NOT starts_with(h, '::'))
  AND NOT (ends_with(h, ':') AND NOT ends_with(h, '::'))
  AND list_bool_and(list_transform(string_split(h, ':'), lambda o: length(o) <= 4))
  AND NOT contains(h, ':::')
  AND CASE WHEN contains(h, '::')
           THEN len(list_filter(string_split(h, ':'), lambda o: o <> '')) <= 7
           ELSE len(string_split(h, ':')) = 8 END
);
CREATE OR REPLACE MACRO gtfs_vc_host_ok(h) AS (
  (length(h) <= 253 AND regexp_full_match(h, gtfs_vc_domain_re())
   AND list_contains(gtfs_vc_tlds(), lower(regexp_extract(h, gtfs_vc_domain_re(), 1))))
  OR gtfs_vc_ipv4_ok(h)
);
CREATE OR REPLACE MACRO gtfs_vc_authority_ok(a) AS (
  CASE WHEN NOT regexp_full_match(a, gtfs_vc_authority_re()) THEN false
       ELSE (CASE WHEN regexp_extract(a, gtfs_vc_authority_re(), 1) <> ''
                  THEN gtfs_vc_ipv6_ok(regexp_extract(a, gtfs_vc_authority_re(), 1))
                  ELSE gtfs_vc_host_ok(regexp_extract(a, gtfs_vc_authority_re(), 2))
                       AND (regexp_extract(a, gtfs_vc_authority_re(), 3) = ''
                            OR TRY_CAST(regexp_extract(a, gtfs_vc_authority_re(), 3) AS INTEGER) BETWEEN 0 AND 65535) END)
            AND trim(regexp_extract(a, gtfs_vc_authority_re(), 4), gtfs_vc_ws()) = '' END
);
-- isValidAuthority of an authority with a char above U+007F: DomainValidator.unicodeToASCII (IDN.toASCII, or the
-- authority itself when it throws), then the ASCII checks.
CREATE OR REPLACE MACRO gtfs_vc_idn_authority_ok(a) AS (
  list_transform([a], lambda r: list_transform([coalesce(gtfs_vc_idn_to_ascii(r), r)],
    lambda x: gtfs_vc_authority_ok(x))[1])[1]
);
-- isValidPath: PATH_REGEX, no '//', and URI.normalize() does not start with '/..': no '..' segment while no segment
-- is left to remove.
CREATE OR REPLACE MACRO gtfs_vc_path_ok(p) AS (
  regexp_full_match(p, '(/[-A-Za-z0-9_:@&?=+,.!/~*''%$;()]*)?') AND NOT contains(p, '//')
  AND coalesce(list_min(list_transform(range(1, len(string_split(p, '/')) + 1), lambda i: list_sum(list_transform(
        string_split(p, '/')[1:i],
        lambda g: CASE WHEN g = '..' THEN -1 WHEN g IN ('', '.') THEN 0 ELSE 1 END)))), 0) >= 0
);
CREATE OR REPLACE MACRO gtfs_vc_url_ok(s) AS (
  CASE WHEN NOT regexp_full_match(s, gtfs_vc_url_re()) THEN false
       ELSE regexp_full_match(regexp_extract(s, gtfs_vc_url_re(), 2), '[A-Za-z][A-Za-z0-9+.-]*')
            AND lower(regexp_extract(s, gtfs_vc_url_re(), 2)) IN ('http', 'https', 'ftp')
            AND regexp_extract(s, gtfs_vc_url_re(), 3) <> ''
            AND (CASE WHEN regexp_matches(regexp_extract(s, gtfs_vc_url_re(), 4), '[^\x00-\x7F]')
                      THEN gtfs_vc_idn_authority_ok(regexp_extract(s, gtfs_vc_url_re(), 4))
                      ELSE gtfs_vc_authority_ok(regexp_extract(s, gtfs_vc_url_re(), 4)) END)
            AND gtfs_vc_path_ok(regexp_extract(s, gtfs_vc_url_re(), 5))
            AND NOT regexp_matches(regexp_extract(s, gtfs_vc_url_re(), 7), '[ \t\n\x0B\f\r]') END
);

-- ---------------------------------------------------------------- cells and row notices

-- One cell per data row of the right length and per schema column the loader reads: columns of the header, and the
-- required or recommended ones (asString(-1) is null: missing_*_field on every row).
CREATE OR REPLACE MACRO gtfs_vc_build_cells(p_file) AS TABLE
WITH cols AS (
  SELECT s.col_ord, s.column_name, s.kind, s.java_type, s.level, s.bounds, h.column_index
  FROM gtfs_vc_schema() s
  LEFT JOIN (SELECT column_name, min(column_index) AS column_index FROM gtfs_vc_header GROUP BY column_name) h
    USING (column_name)
  WHERE s.filename = p_file AND (h.column_index IS NOT NULL OR s.level <> 'OPTIONAL')
),
raw AS (
  SELECT r.csv_row_number, c.col_ord, c.column_name, c.kind, c.java_type, c.level, c.bounds,
    CASE WHEN c.column_index IS NOT NULL THEN r.fields[c.column_index + 1] END AS raw
  FROM gtfs_vc_rows r CROSS JOIN cols c WHERE r.length_ok
),
trimmed AS (SELECT *, gtfs_vc_trim(raw) AS v FROM raw)
SELECT csv_row_number, col_ord, column_name, kind, java_type, level, bounds, raw, v,
  CASE WHEN kind IN ('integer', 'enum') THEN gtfs_vc_int(v)
       WHEN kind = 'time' THEN gtfs_vc_time(v)
       WHEN kind = 'color' THEN gtfs_vc_color(v) END AS vi,
  CASE WHEN kind IN ('float', 'latitude', 'longitude') THEN gtfs_vc_double(v) END AS vd,
  CASE WHEN kind = 'date' THEN gtfs_vc_date(v) END AS vdt
FROM trimmed;

-- Integer/Double.compareTo(0) as a sign: -0.0 is below 0.0 and NaN above everything.
CREATE OR REPLACE MACRO gtfs_vc_cmp0(p_kind, p_vi, p_vd) AS (
  CASE WHEN p_kind = 'integer' THEN sign(p_vi)
       WHEN isnan(p_vd) THEN 1 WHEN p_vd = 0 AND signbit(p_vd) THEN -1 ELSE sign(p_vd) END
);

-- RowParser / DefaultFieldValidator notices of the cells (fieldValue: raw for the value checks, trimmed after).
-- Each branch scans gtfs_vc_cells with its own cheap filter first: a shared CTE lets DuckDB OR every branch's
-- condition into one filter and run the URL and timezone checks on every cell.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices(p_file) AS TABLE
WITH n AS (
  SELECT csv_row_number,
    CASE level WHEN 'REQUIRED' THEN 'missing_required_field' ELSE 'missing_recommended_field' END AS code,
    json_object('filename', p_file, 'csvRowNumber', csv_row_number, 'fieldName', column_name) AS notice
  FROM gtfs_vc_cells WHERE raw IS NULL AND level IN ('REQUIRED', 'RECOMMENDED')
  UNION ALL
  SELECT csv_row_number, 'invalid_character', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', raw)
  FROM gtfs_vc_cells WHERE contains(raw, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', raw)
  FROM gtfs_vc_cells WHERE contains(raw, chr(10)) OR contains(raw, chr(13))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces', json_object('filename', p_file,
    'csvRowNumber', csv_row_number, 'fieldName', column_name, 'fieldValue', raw)
  FROM gtfs_vc_cells WHERE v <> raw
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char', json_object('filename', p_file,
    'csvRowNumber', csv_row_number, 'fieldName', column_name, 'fieldValue', v)
  FROM gtfs_vc_cells WHERE kind = 'id' AND regexp_matches(v, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_url', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', v)
  FROM (SELECT * FROM gtfs_vc_cells WHERE kind = 'url' AND v IS NOT NULL) WHERE NOT gtfs_vc_url_ok(v)
  UNION ALL
  SELECT csv_row_number, 'invalid_timezone', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', v)
  FROM (SELECT * FROM gtfs_vc_cells WHERE kind = 'timezone' AND v IS NOT NULL) WHERE NOT gtfs_vc_timezone_ok(v)
  UNION ALL
  SELECT csv_row_number,
    CASE kind WHEN 'time' THEN 'invalid_time' WHEN 'color' THEN 'invalid_color' WHEN 'date' THEN 'invalid_date'
      WHEN 'integer' THEN 'invalid_integer' WHEN 'enum' THEN 'invalid_integer' ELSE 'invalid_float' END,
    json_object('filename', p_file, 'csvRowNumber', csv_row_number, 'fieldName', column_name, 'fieldValue', v)
  FROM gtfs_vc_cells
  WHERE v IS NOT NULL AND vi IS NULL AND vd IS NULL AND vdt IS NULL
    AND kind IN ('integer', 'enum', 'time', 'color', 'float', 'latitude', 'longitude', 'date')
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', vi::INTEGER)
  FROM (SELECT * FROM gtfs_vc_cells WHERE kind = 'enum' AND vi IS NOT NULL)
  WHERE gtfs_validation_enum_name(java_type, vi) = 'UNRECOGNIZED'
  UNION ALL
  -- checkBounds: Integer/Double.compareTo(0) (-0.0 is below 0.0, NaN above), asLatitude / asLongitude ranges
  SELECT csv_row_number, 'number_out_of_range', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name,
    'fieldType', CASE kind WHEN 'latitude' THEN 'latitude within [-90, 90]'
                           WHEN 'longitude' THEN 'longitude within [-180, 180]'
                           ELSE CASE bounds WHEN 'POSITIVE' THEN 'positive ' WHEN 'NON_NEGATIVE' THEN 'non-negative '
                                            ELSE 'non-zero ' END
                                || CASE kind WHEN 'integer' THEN 'integer' ELSE 'float' END END,
    'fieldValue', CASE WHEN kind = 'integer' THEN to_json(vi::INTEGER) ELSE to_json(vd) END)
  FROM gtfs_vc_cells
  WHERE (vi IS NOT NULL OR vd IS NOT NULL) AND kind IN ('integer', 'float', 'latitude', 'longitude')
    AND CASE WHEN kind = 'latitude' THEN isnan(vd) OR NOT (-90 <= vd AND vd <= 90)
             WHEN kind = 'longitude' THEN isnan(vd) OR NOT (-180 <= vd AND vd <= 180)
             WHEN bounds = 'POSITIVE' THEN gtfs_vc_cmp0(kind, vi, vd) <= 0
             WHEN bounds = 'NON_NEGATIVE' THEN gtfs_vc_cmp0(kind, vi, vd) < 0
             WHEN bounds = 'NON_ZERO' THEN gtfs_vc_cmp0(kind, vi, vd) = 0
             ELSE false
        END
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);

-- RowParser.checkRowLength notices of the data rows.
CREATE OR REPLACE MACRO gtfs_vc_row_length_notices(p_file) AS TABLE
SELECT r.csv_row_number,
  CASE WHEN len(r.fields) = 1 AND r.fields[1] IS NULL THEN 'empty_row' ELSE 'invalid_row_length' END AS code,
  gtfs_validation_notice(CASE WHEN len(r.fields) = 1 AND r.fields[1] IS NULL
    THEN json_object('filename', p_file, 'csvRowNumber', r.csv_row_number)
    ELSE json_object('filename', p_file, 'csvRowNumber', r.csv_row_number, 'rowLength', len(r.fields),
                     'headerCount', s.header_n) END) AS notice,
  NOT (len(r.fields) = 1 AND r.fields[1] IS NULL) AS err
FROM gtfs_vc_rows r, gtfs_vc_state s WHERE NOT r.length_ok;

-- CsvFileLoader's TableStatus of the current file.
CREATE OR REPLACE MACRO gtfs_vc_status() AS (
  SELECT CASE WHEN NOT s.has_header THEN 'EMPTY_FILE'
              WHEN NOT s.header_ok THEN 'INVALID_HEADERS'
              WHEN s.fail_rec IS NOT NULL OR EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err) THEN 'UNPARSABLE_ROWS'
              ELSE 'PARSABLE_HEADERS_AND_ROWS' END
  FROM gtfs_vc_state s
);
