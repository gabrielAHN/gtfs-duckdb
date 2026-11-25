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
CREATE OR REPLACE MACRO gtfs_vc_ws() AS (array_to_string(list_transform(range(0, 33), lambda i: chr(i::INTEGER)), ''));

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
-- Bytes -> text as CsvFile decodes them (CodingErrorAction.REPLACE with U+FFFD). The slow branch only runs on
-- invalid UTF-8.
CREATE OR REPLACE MACRO gtfs_vc_decode(content) AS (
  coalesce(TRY(decode(content)),
           decode(unhex(array_to_string(list_transform(
             regexp_extract_all(hex(content), gtfs_vc_utf8_token_re()),
             lambda t: CASE WHEN regexp_full_match(t, gtfs_vc_utf8_valid_re()) THEN t ELSE 'EFBFBD' END), ''))))
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
         WHEN trim(line, gtfs_vc_ws()) = '' THEN 'ws' ELSE 'row' END AS kind,
    list_transform(string_split(line, ','), lambda f: nullif(trim(f, gtfs_vc_ws()), '')) AS fields
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
    ltrim(body, gtfs_vc_ws()) AS lb
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
         WHEN NOT quoted THEN nullif(trim(body, gtfs_vc_ws()), '')
         -- unclosed quote: the rest of the file
         WHEN NOT regexp_matches(lb, '^"(?:[^"]|"")*"[^,\n]*$') THEN nullif(replace(lb[2:], '""', '"'), '')
         WHEN trim(q.r, gtfs_vc_ws()) = '' THEN nullif(replace(q.c, '""', '"'), '')
         -- text after the closing quote: univocity keeps the quotes and that text
         ELSE '"' || replace(q.c, '""', '"') || '"' || rtrim(q.r, gtfs_vc_ws())
    END AS value
  FROM tok3
),
slow AS (
  SELECT rec_no, max(line_end) AS csv_row_number,
    CASE WHEN bool_or(is_comment) THEN 'comment'
         WHEN count(*) = 1 AND NOT bool_or(quoted) AND max(body) = '' THEN 'empty'
         WHEN count(*) = 1 AND NOT bool_or(quoted) AND trim(max(body), gtfs_vc_ws()) = '' THEN 'ws'
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
  CASE WHEN kind = 'ws' THEN [''] ELSE list_transform(fields, lambda f: coalesce(trim(f, gtfs_vc_ws()), '')) END AS names
FROM gtfs_vc_records WHERE kind IN ('ws', 'row') ORDER BY rec_no LIMIT 1;

-- univocity TextParsingException (csv_parsing_failed): the first record with a value longer than maxCharsPerColumn
-- (4096) or more than maxColumns (512) values. Positions are recomputed from the text with offsets (only when such a
-- record exists): charIndex is the offset after the first char past 4096 (or after the terminator of the 513th value),
-- lineIndex the line feeds before it, record the data records before it.
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
         THEN rt.body_start + (length(rt.tok) - 1 - length(ltrim(rt.tok[2:], gtfs_vc_ws())))
              + starts_with(ltrim(rt.tok[2:], gtfs_vc_ws()), '"')::INTEGER + 4096 + 1
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
  CASE WHEN regexp_full_match(trim(s, gtfs_vc_ws()),
              '[+-]?(?:NaN|Infinity|(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?[fFdD]?)')
       THEN TRY_CAST(regexp_replace(trim(s, gtfs_vc_ws()), '[fFdD]$', '') AS DOUBLE) END
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
-- UrlValidator.getInstance().isValid (commons-validator): schemes http, https, ftp.
CREATE OR REPLACE MACRO gtfs_vc_url_ok(s) AS (true);

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
trimmed AS (SELECT *, trim(raw, gtfs_vc_ws()) AS v FROM raw)
SELECT csv_row_number, col_ord, column_name, kind, java_type, level, bounds, raw, v,
  CASE WHEN kind IN ('integer', 'enum') THEN gtfs_vc_int(v)
       WHEN kind = 'time' THEN gtfs_vc_time(v)
       WHEN kind = 'color' THEN gtfs_vc_color(v) END AS vi,
  CASE WHEN kind IN ('float', 'latitude', 'longitude') THEN gtfs_vc_double(v) END AS vd,
  CASE WHEN kind = 'date' THEN gtfs_vc_date(v) END AS vdt
FROM trimmed;

-- RowParser / DefaultFieldValidator notices of the cells (fieldValue: raw for the value checks, trimmed after).
CREATE OR REPLACE MACRO gtfs_vc_cell_notices(p_file) AS TABLE
WITH c AS (SELECT * FROM gtfs_vc_cells),
n AS (
  SELECT csv_row_number,
    CASE level WHEN 'REQUIRED' THEN 'missing_required_field' ELSE 'missing_recommended_field' END AS code,
    json_object('filename', p_file, 'csvRowNumber', csv_row_number, 'fieldName', column_name) AS notice
  FROM c WHERE raw IS NULL AND level IN ('REQUIRED', 'RECOMMENDED')
  UNION ALL
  SELECT csv_row_number, 'invalid_character', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', raw)
  FROM c WHERE contains(raw, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', raw)
  FROM c WHERE contains(raw, chr(10)) OR contains(raw, chr(13))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces', json_object('filename', p_file,
    'csvRowNumber', csv_row_number, 'fieldName', column_name, 'fieldValue', raw)
  FROM c WHERE v <> raw
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char', json_object('filename', p_file,
    'csvRowNumber', csv_row_number, 'fieldName', column_name, 'fieldValue', v)
  FROM c WHERE kind = 'id' AND regexp_matches(v, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_url', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', v)
  FROM c WHERE kind = 'url' AND v IS NOT NULL AND NOT gtfs_vc_url_ok(v)
  UNION ALL
  SELECT csv_row_number,
    CASE kind WHEN 'integer' THEN 'invalid_integer' WHEN 'enum' THEN 'invalid_integer' WHEN 'time' THEN 'invalid_time'
      WHEN 'color' THEN 'invalid_color' WHEN 'date' THEN 'invalid_date' WHEN 'timezone' THEN 'invalid_timezone'
      ELSE 'invalid_float' END,
    json_object('filename', p_file, 'csvRowNumber', csv_row_number, 'fieldName', column_name, 'fieldValue', v)
  FROM c WHERE v IS NOT NULL AND CASE
      WHEN kind IN ('integer', 'enum', 'time', 'color') THEN vi IS NULL
      WHEN kind IN ('float', 'latitude', 'longitude') THEN vd IS NULL
      WHEN kind = 'date' THEN vdt IS NULL
      WHEN kind = 'timezone' THEN NOT gtfs_vc_timezone_ok(v)
      ELSE false END
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldValue', vi::INTEGER)
  FROM c WHERE kind = 'enum' AND vi IS NOT NULL AND gtfs_validation_enum_name(java_type, vi) = 'UNRECOGNIZED'
  UNION ALL
  -- checkBounds: Integer/Double.compareTo(0) (-0.0 is below 0.0, NaN above), asLatitude / asLongitude ranges
  SELECT csv_row_number, 'number_out_of_range', json_object('filename', p_file, 'csvRowNumber', csv_row_number,
    'fieldName', column_name, 'fieldType', bounds_text, 'fieldValue', fv)
  FROM (
    SELECT csv_row_number, column_name, kind, bounds, vd,
      CASE kind WHEN 'latitude' THEN 'latitude within [-90, 90]' WHEN 'longitude' THEN 'longitude within [-180, 180]'
        ELSE CASE bounds WHEN 'POSITIVE' THEN 'positive ' WHEN 'NON_NEGATIVE' THEN 'non-negative ' ELSE 'non-zero ' END
             || CASE kind WHEN 'integer' THEN 'integer' ELSE 'float' END END AS bounds_text,
      CASE WHEN kind = 'integer' THEN to_json(vi::INTEGER) ELSE to_json(vd) END AS fv,
      CASE WHEN kind = 'integer' THEN sign(vi)
           WHEN isnan(vd) THEN 1 WHEN vd = 0 AND signbit(vd) THEN -1 ELSE sign(vd) END AS cmp
    FROM c WHERE (kind = 'integer' AND vi IS NOT NULL AND bounds IS NOT NULL)
      OR (kind = 'float' AND vd IS NOT NULL AND bounds IS NOT NULL)
      OR (kind IN ('latitude', 'longitude') AND vd IS NOT NULL)
  ) WHERE CASE WHEN kind = 'latitude' THEN NOT (-90 <= vd AND vd <= 90) AND NOT isnan(vd)
               WHEN kind = 'longitude' THEN NOT (-180 <= vd AND vd <= 180) AND NOT isnan(vd)
               WHEN bounds = 'POSITIVE' THEN cmp <= 0 WHEN bounds = 'NON_NEGATIVE' THEN cmp < 0 ELSE cmp = 0 END
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
