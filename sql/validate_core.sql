-- Core validation macros (core workstream). Macro section: only CREATE OR REPLACE MACRO statements, which the
-- extension registers as functions at LOAD. Tables they reference must be created in validate_schema.sql.
--
-- The loader is a port of MobilityData's CsvFileLoader, CsvFile (univocity CsvParser), RowParser,
-- DefaultTableHeaderValidator and DefaultFieldValidator. validate_load.sql runs it per file:
--   gtfs_vc_text     decoded text, the invalid_line_ending row and whether a quoted value spans lines
--   gtfs_vc_lines    its lines: one split of the text; everything after runs per line, in parallel
--   gtfs_vc_records  CSV records (gtfs_vc_line_records, or gtfs_vc_parse_records over the whole text when a quoted
--                    value spans lines), univocity semantics as the oracle's settings give them:
--                    ',' delimiter, '"' quote and escape, LF line separator, '#' comments, empty and whitespace-only
--                    lines skipped, values trimmed of chars <= ' ' outside quotes
--   gtfs_vc_header / gtfs_vc_state   header and header notices; gtfs_vc_pos   each schema column's header position
--   gtfs_vc_wide_<table>  one row per data row of the header's length: raw and typed value of each schema column
--                    (generated per table by test/validation/gen_loader.py, like gtfs_vc_cell_notices_<table> and
--                    gtfs_vc_entities_<table>)
--   gtfs_vc_notices  row notices (gtfs_vc_row_length_notices, gtfs_vc_cell_notices_<table>), a row with an ERROR
--                    notice is not an entity
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
-- LineEndingCheckingInputStream: line (1 + LFs before it) of the first CR not followed by LF, NULL if none. Per line
-- of gtfs_vc_lines: a CR before its last char, or any CR on the last line (no LF follows it).
CREATE OR REPLACE MACRO gtfs_vc_invalid_line_ending_row() AS ((
  SELECT min(line_no) FROM gtfs_vc_lines
  WHERE contains(line, chr(13))
    AND (strpos(line, chr(13)) < length(line) OR line_no = (SELECT max(line_no) FROM gtfs_vc_lines))
));

-- ---------------------------------------------------------------- CSV records

-- One token per value, separator first (LF starts a record, the text gets a leading LF): a comment line, an
-- unclosed quoted value (runs to the end of the file), a quoted value with what follows its closing quote, or an
-- unquoted value.
CREATE OR REPLACE MACRO gtfs_vc_token_re() AS (
  '\n#[^\n]*|[,\n][\x00-\x09\x0B-\x20]*"(?:[^"]|"")*$|[,\n][\x00-\x09\x0B-\x20]*"(?:[^"]|"")*"[^,\n]*|[,\n][^,\n]*'
);

-- The value of one token: body is the token without its separator, lb the body without leading chars <= ' '.
CREATE OR REPLACE MACRO gtfs_vc_token_value(body, lb, is_comment) AS (
  CASE WHEN is_comment THEN NULL
       WHEN NOT starts_with(lb, '"') THEN nullif(gtfs_vc_trim(body), '')
       -- unclosed quote: the rest of the file
       WHEN NOT regexp_matches(lb, '^"(?:[^"]|"")*"[^,\n]*$') THEN nullif(replace(lb[2:], '""', '"'), '')
       WHEN gtfs_vc_trim(regexp_extract(lb, '^"((?:[^"]|"")*)"([^,\n]*)$', 2)) = ''
         THEN nullif(replace(regexp_extract(lb, '^"((?:[^"]|"")*)"([^,\n]*)$', 1), '""', '"'), '')
       -- text after the closing quote: univocity keeps the quotes and that text
       ELSE '"' || replace(regexp_extract(lb, '^"((?:[^"]|"")*)"([^,\n]*)$', 1), '""', '"') || '"'
            || gtfs_vc_rtrim(regexp_extract(lb, '^"((?:[^"]|"")*)"([^,\n]*)$', 2))
  END
);

-- Records of gtfs_vc_lines, one per line, run in parallel over the lines. A line without a quote splits on commas; a
-- line with one is tokenized with gtfs_vc_token_re as the whole text would be. Both give gtfs_vc_parse_records'
-- records unless a quoted value runs past the end of its line: kind 'open' marks such a line, and validate_load.sql
-- then parses the whole text instead. plain: the line has only chars from '!' to '~' (and CRs at its end), so no
-- value needs trimming or can have a character notice.
CREATE OR REPLACE MACRO gtfs_vc_line_records() AS TABLE
WITH l AS (
  SELECT line_no, line, NOT regexp_matches(line, '[^\x21-\x7E\r]|\r[^\r]') AS plain,
    CASE WHEN contains(line, '"') THEN regexp_extract_all(chr(10) || line, gtfs_vc_token_re()) END AS tk
  FROM gtfs_vc_lines
),
r AS (
  SELECT line_no, line, plain,
    CASE WHEN line = '' THEN 'empty' WHEN starts_with(line, '#') THEN 'comment'
         WHEN NOT regexp_matches(line, '[^\x00-\x20]') THEN 'ws'
         WHEN regexp_full_match(gtfs_vc_ltrim(tk[-1][2:]), '"(?:[^"]|"")*') THEN 'open'
         ELSE 'row' END AS kind,
    CASE WHEN tk IS NOT NULL
         THEN list_transform(
                list_transform(tk, lambda t: {'b': t[2:], 'lb': gtfs_vc_ltrim(t[2:]), 'c': starts_with(t, chr(10) || '#')}),
                lambda x: gtfs_vc_token_value(x.b, x.lb, x.c))
         WHEN plain THEN list_transform(string_split(rtrim(line, chr(13)), ','), lambda f: nullif(f, ''))
         ELSE list_transform(string_split(line, ','), lambda f: nullif(gtfs_vc_trim(f), '')) END AS fields
  FROM l
)
SELECT line_no AS rec_no, line_no AS csv_row_number, kind, fields,
  -- only a line longer than 4096 bytes can hold a value longer than 4096 chars (gtfs_vc_failure)
  CASE WHEN strlen(line) > 4096 THEN list_max(list_transform(fields, lambda f: length(f))) END AS max_len,
  plain
FROM r;

-- Records of the whole text (gtfs_vc_text.text), for a file where a quoted value runs past the end of its line
-- (gtfs_vc_text.multiline): one token stream over the whole text, values grouped by record.
CREATE OR REPLACE MACRO gtfs_vc_parse_records() AS TABLE
WITH tokens AS (
  SELECT unnest(tk) AS tok, unnest(range(1, len(tk) + 1)) AS tok_no
  FROM (SELECT regexp_extract_all(chr(10) || t.text, gtfs_vc_token_re()) AS tk FROM gtfs_vc_text t WHERE t.multiline)
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
  SELECT rec_no, tok_no, line_end, is_comment, body, starts_with(lb, '"') AND NOT is_comment AS quoted,
    gtfs_vc_token_value(body, lb, is_comment) AS value
  FROM tok2
),
slow AS (
  SELECT rec_no, max(line_end) AS csv_row_number,
    CASE WHEN bool_or(is_comment) THEN 'comment'
         WHEN count(*) = 1 AND NOT bool_or(quoted) AND max(body) = '' THEN 'empty'
         WHEN count(*) = 1 AND NOT bool_or(quoted) AND gtfs_vc_trim(max(body)) = '' THEN 'ws'
         ELSE 'row' END AS kind,
    list(value ORDER BY tok_no) AS fields
  FROM tok3 GROUP BY rec_no
)
SELECT rec_no, csv_row_number, kind, fields, list_max(list_transform(fields, lambda f: length(f))) AS max_len,
  false AS plain
FROM slow;

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
  r.plain
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
-- Refused input code points: unassigned in Unicode 3.2 (A.1) or mapped to a prohibited one (C.1.2 to
-- C.9). Runs of 32 or more are in gtfs_vc_idn_refused_re(), the others in the map.
-- gtfs_vc_idn_keys(): those and the code points whose B.1/B.2 map plus NFKC differs from the code point
-- and from its NFC; field i (separated by U+0001) of gtfs_vc_idn_values() is what the i-th one maps to
-- (empty for B.1, U+E000 for a refused one). The other code points are left to nfc_normalize(). UTF-8 in
-- base64, so the SQL stays ASCII; adjacent literals, which the parser joins.
CREATE OR REPLACE MACRO gtfs_vc_idn_keys() AS (decode(from_base64(
  'QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVrCoMKowqrCrcKvwrLCs8K0wrXCuMK5wrrCvMK9wr7DgMOBw4LDg8OEw4XDhsOHw4jDicOKw4vDjMON'
  'w47Dj8OQw5HDksOTw5TDlcOWw5jDmcOaw5vDnMOdw57Dn8SAxILEhMSGxIjEisSMxI7EkMSSxJTElsSYxJrEnMSexKDEosSkxKbEqMSqxKzErsSw'
  'xLLEs8S0xLbEucS7xL3Ev8WAxYHFg8WFxYfFicWKxYzFjsWQxZLFlMWWxZjFmsWcxZ7FoMWixaTFpsWoxarFrMWuxbDFssW0xbbFuMW5xbvFvcW/'
  'xoHGgsaExobGh8aJxorGi8aOxo/GkMaRxpPGlMaWxpfGmMacxp3Gn8agxqLGpMamxqfGqcasxq7Gr8axxrLGs8a1xrfGuMa8x4THhceGx4fHiMeJ'
  'x4rHi8eMx43Hj8eRx5PHlceXx5nHm8eex6DHosekx6bHqMeqx6zHrsexx7LHs8e0x7bHt8e4x7rHvMe+yIDIgsiEyIbIiMiKyIzIjsiQyJLIlMiW'
  'yJjImsicyJ7IoMihyKLIpMimyKjIqsisyK7IsMiyyLTItci2yLfIuMi5yLrIu8i8yL3Ivsi/yYDJgcmCyYPJhMmFyYbJh8mIyYnJismLyYzJjcmO'
  'yY/KrsqvyrDKscqyyrPKtMq1yrbKt8q4y5jLmcuay5vLnMudy6DLocuiy6PLpMuvy7DLscuyy7PLtMu1y7bLt8u4y7nLusu7y7zLvcu+y7/Nhc2P'
  'zZDNkc2SzZPNlM2VzZbNl82YzZnNms2bzZzNnc2ezZ/NsM2xzbLNs822zbfNuM25zbrNu828zb3Nv86AzoHOgs6DzoTOhc6GzojOic6KzovOjM6N'
  'zo7Oj86RzpLOk86UzpXOls6XzpjOmc6azpvOnM6dzp7On86gzqHOos6jzqTOpc6mzqfOqM6pzqrOq8+Cz4/PkM+Rz5LPk8+Uz5XPls+Yz5rPnM+e'
  'z6DPos+kz6bPqM+qz6zPrs+wz7HPss+0z7XPt8+4z7nPus+7z7zPvc++z7/QgNCB0ILQg9CE0IXQhtCH0IjQidCK0IvQjNCN0I7Qj9CQ0JHQktCT'
  '0JTQldCW0JfQmNCZ0JrQm9Cc0J3QntCf0KDQodCi0KPQpNCl0KbQp9Co0KnQqtCr0KzQrdCu0K/RoNGi0aTRptGo0arRrNGu0bDRstG00bbRuNG6'
  '0bzRvtKA0ofSitKM0o7SkNKS0pTSltKY0prSnNKe0qDSotKk0qbSqNKq0qzSrtKw0rLStNK20rjSutK80r7TgdOD04XTh9OJ04vTjdOP05DTktOU'
  '05bTmNOa05zTntOg06LTpNOm06jTqtOs067TsNOy07TTttO307jTutO707zTvdO+07/UgNSC1ITUhtSI1IrUjNSO1LHUstSz1LTUtdS21LfUuNS5'
  '1LrUu9S81L3UvtS/1YDVgdWC1YPVhNWF1YbVh9WI1YnVitWL1YzVjdWO1Y/VkNWR1ZLVk9WU1ZXVltWX1ZjVoNaH1ojWi9aM1o3WjtaP1pDWota6'
  '14XXhteH14jXideK14vXjNeN147Xj9er16zXrdeu16/Xtde217fXuNe517rXu9e8173Xvte/2IDYgdiC2IPYhNiF2IbYh9iI2InYitiL2I3YjtiP'
  '2JDYkdiS2JPYlNiV2JbYl9iY2JnYmtic2J3Yntig2LvYvNi92L7Yv9mW2ZfZmNmZ2ZrZm9mc2Z3Zntmf2bXZttm32bjbnduu26/bv9yO3I/crdyu'
  '3K/gpITgpLrgpLvgpY7gpY/gpZXgpZbgpZfgpbHgpbLgpbPgpbTgpbXgpbbgpbfgpbjgpbngpbrgpbvgpbzgpb3gpb7gpb/gpoDgpoTgpo3gpo7g'
  'ppHgppLgpqngprHgprPgprTgprXgprrgprvgpr3gp4Xgp4bgp4ngp4rgp47gp4/gp5Dgp5Hgp5Lgp5Pgp5Tgp5Xgp5bgp5jgp5ngp5rgp5vgp57g'
  'p6Tgp6Xgp7vgp7zgp73gp77gp7/gqIDgqIHgqIPgqITgqIvgqIzgqI3gqI7gqJHgqJLgqKngqLHgqLTgqLfgqLrgqLvgqL3gqYPgqYTgqYXgqYbg'
  'qYngqYrgqY7gqY/gqZDgqZHgqZLgqZPgqZTgqZXgqZbgqZfgqZjgqZ3gqZ/gqaDgqaHgqaLgqaPgqaTgqaXgqbXgqbbgqbfgqbjgqbngqbrgqbvg'
  'qbzgqb3gqb7gqb/gqoDgqoTgqozgqo7gqpLgqqngqrHgqrTgqrrgqrvgq4bgq4rgq47gq4/gq5Hgq5Lgq5Pgq5Tgq5Xgq5bgq5fgq5jgq5ngq5rg'
  'q5vgq5zgq53gq57gq5/gq6Hgq6Lgq6Pgq6Tgq6Xgq7Dgq7Hgq7Lgq7Pgq7Tgq7Xgq7bgq7fgq7jgq7ngq7rgq7vgq7zgq73gq77gq7/grIDgrITg'
  'rI3grI7grJHgrJLgrKngrLHgrLTgrLXgrLrgrLvgrYTgrYXgrYbgrYngrYrgrY7grY/grZDgrZHgrZLgrZPgrZTgrZXgrZjgrZngrZrgrZvgrZ7g'
  'raLgraPgraTgraXgrbHgrbLgrbPgrbTgrbXgrbbgrbfgrbjgrbngrbrgrbvgrbzgrb3grb7grb/groDgroHgroTgrovgrozgro3grpHgrpbgrpfg'
  'rpjgrpvgrp3grqDgrqHgrqLgrqXgrqbgrqfgrqvgrqzgrq3grrbgrrrgrrvgrrzgrr3gr4Pgr4Tgr4Xgr4ngr47gr4/gr5Dgr5Hgr5Lgr5Pgr5Tg'
  'r5Xgr5bgr5jgr5ngr5rgr5vgr5zgr53gr57gr5/gr6Dgr6Hgr6Lgr6Pgr6Tgr6Xgr6bgr7Pgr7Tgr7Xgr7bgr7fgr7jgr7ngr7rgr7vgr7zgr73g'
  'r77gr7/gsIDgsITgsI3gsJHgsKngsLTgsLrgsLvgsLzgsL3gsYXgsYngsY7gsY/gsZDgsZHgsZLgsZPgsZTgsZfgsZjgsZngsZrgsZvgsZzgsZ3g'
  'sZ7gsZ/gsaLgsaPgsaTgsaXgsbDgsbHgsbLgsbPgsbTgsbXgsbbgsbfgsbjgsbngsbrgsbvgsbzgsb3gsb7gsb/gsoDgsoHgsoTgso3gspHgsqng'
  'srTgsrrgsrvgsrzgsr3gs4Xgs4ngs47gs4/gs5Dgs5Hgs5Lgs5Pgs5Tgs5fgs5jgs5ngs5rgs5vgs5zgs53gs5/gs6Lgs6Pgs6Tgs6Xgs7Dgs7Hg'
  's7Lgs7Pgs7Tgs7Xgs7bgs7fgs7jgs7ngs7rgs7vgs7zgs73gs77gs7/gtIDgtIHgtITgtI3gtJHgtKngtLrgtLvgtLzgtL3gtYTgtYXgtYngtY7g'
  'tY/gtZDgtZHgtZLgtZPgtZTgtZXgtZbgtZjgtZngtZrgtZvgtZzgtZ3gtZ7gtZ/gtaLgtaPgtaTgtaXgtbDgtbHgtbLgtbPgtbTgtbXgtbbgtbfg'
  'tbjgtbngtbrgtbvgtbzgtb3gtb7gtb/gtoDgtoHgtoTgtpfgtpjgtpngtrLgtrzgtr7gtr/gt4fgt4jgt4ngt4vgt4zgt43gt47gt5Xgt5fgt6Dg'
  't6Hgt6Lgt6Pgt6Tgt6Xgt6bgt6fgt6jgt6ngt6rgt6vgt6zgt63gt67gt6/gt7Dgt7Hgt7Xgt7bgt7fgt7jgt7ngt7rgt7vgt7zgt73gt77gt7/g'
  'uIDguLPguLvguLzguL3guL7guoPguoXguobguonguovguozguo7guo/gupDgupHgupLgupPgupjguqDguqTguqbguqjguqnguqzgurPgurrgur7g'
  'ur/gu4Xgu4fgu47gu4/gu5rgu5vgu5zgu53gvIzgvYjgvavgvazgva3gva7gva/gvbDgvbfgvbngvozgvo3gvo7gvo/gvpjgvr3gv43gv47hgKLh'
  'gKjhgKvhgLPhgLThgLXhgLrhgLvhgLzhgL3hgL7hgL/hg4bhg4fhg4jhg4nhg4rhg4vhg4zhg43hg47hg4/hg7nhg7rhg7zhg73hg77hg7/hhZrh'
  'hZvhhZzhhZ3hhZ7hhqPhhqThhqXhhqbhhqfhh7rhh7vhh7zhh73hh77hh7/hiIfhiYfhiYnhiY7hiY/hiZfhiZnhiZ7hiZ/hiofhionhio7hio/h'
  'iq/hirHhirbhirfhir/hi4Hhi4bhi4fhi4/hi5fhi6/hjI/hjJHhjJbhjJfhjJ/hjYfhjZvhjZzhjZ3hjZ7hjZ/hjaDhj7Xhj7bhj7fhj7jhj7nh'
  'j7rhj7vhj7zhj73hj77hj7/hkIDhmbfhmbjhmbnhmbrhmbvhmbzhmb3hmb7hmb/hmoDhmp3hmp7hmp/hm7Hhm7Lhm7Phm7Thm7Xhm7bhm7fhm7jh'
  'm7nhm7rhm7vhm7zhm73hm77hm7/hnI3hnJXhnJbhnJfhnJjhnJnhnJrhnJvhnJzhnJ3hnJ7hnJ/hnLfhnLjhnLnhnLrhnLvhnLzhnL3hnL7hnL/h'
  'nZThnZXhnZbhnZfhnZjhnZnhnZrhnZvhnZzhnZ3hnZ7hnZ/hna3hnbHhnbThnbXhnbbhnbfhnbjhnbnhnbrhnbvhnbzhnb3hnb7hnb/hn53hn57h'
  'n5/hn6rhn6vhn6zhn63hn67hn6/hn7Dhn7Hhn7Lhn7Phn7Thn7Xhn7bhn7fhn7jhn7nhn7rhn7vhn7zhn73hn77hn7/hoIbhoIvhoIzhoI3hoI7h'
  'oI/hoJrhoJvhoJzhoJ3hoJ7hoJ/hobjhobnhobrhobvhobzhob3hob7hob/huIDhuILhuIThuIbhuIjhuIrhuIzhuI7huJDhuJLhuJThuJbhuJjh'
  'uJrhuJzhuJ7huKDhuKLhuKThuKbhuKjhuKrhuKzhuK7huLDhuLLhuLThuLbhuLjhuLrhuLzhuL7huYDhuYLhuYThuYbhuYjhuYrhuYzhuY7huZDh'
  'uZLhuZThuZbhuZjhuZrhuZzhuZ7huaDhuaLhuaThuabhuajhuarhuazhua7hubDhubLhubThubbhubjhubrhubzhub7huoDhuoLhuoThuobhuojh'
  'uorhuozhuo7hupDhupLhupThuprhupvhupzhup3hup7hup/huqDhuqLhuqThuqbhuqjhuqrhuqzhuq7hurDhurLhurThurbhurjhurrhurzhur7h'
  'u4Dhu4Lhu4Thu4bhu4jhu4rhu4zhu47hu5Dhu5Lhu5Thu5bhu5jhu5rhu5zhu57hu6Dhu6Lhu6Thu6bhu6jhu6rhu6zhu67hu7Dhu7Lhu7Thu7bh'
  'u7jhu7rhu7vhu7zhu73hu77hu7/hvIjhvInhvIrhvIvhvIzhvI3hvI7hvI/hvJbhvJfhvJjhvJnhvJrhvJvhvJzhvJ3hvJ7hvJ/hvKjhvKnhvKrh'
  'vKvhvKzhvK3hvK7hvK/hvLjhvLnhvLrhvLvhvLzhvL3hvL7hvL/hvYbhvYfhvYjhvYnhvYrhvYvhvYzhvY3hvY7hvY/hvZjhvZnhvZrhvZvhvZzh'
  'vZ3hvZ7hvZ/hvajhvanhvarhvavhvazhva3hva7hva/hvb7hvb/hvoDhvoHhvoLhvoPhvoThvoXhvobhvofhvojhvonhvorhvovhvozhvo3hvo7h'
  'vo/hvpDhvpHhvpLhvpPhvpThvpXhvpbhvpfhvpjhvpnhvprhvpvhvpzhvp3hvp7hvp/hvqDhvqHhvqLhvqPhvqThvqXhvqbhvqfhvqjhvqnhvqrh'
  'vqvhvqzhvq3hvq7hvq/hvrLhvrPhvrThvrXhvrfhvrjhvrnhvrrhvrvhvrzhvr3hvr/hv4Dhv4Hhv4Lhv4Phv4Thv4Xhv4fhv4jhv4nhv4rhv4vh'
  'v4zhv43hv47hv4/hv5Thv5Xhv5jhv5nhv5rhv5vhv5zhv53hv57hv5/hv6jhv6nhv6rhv6vhv6zhv63hv67hv7Dhv7Hhv7Lhv7Phv7Thv7Xhv7fh'
  'v7jhv7nhv7rhv7vhv7zhv73hv77hv7/igIDigIHigILigIPigITigIXigIbigIfigIjigInigIrigIvigIzigI3igI7igI/igJHigJfigKTigKXi'
  'gKbigKjigKnigKrigKvigKzigK3igK7igK/igLPigLTigLbigLfigLzigL7igYfigYjigYnigZPigZTigZXigZbigZfigZjigZnigZrigZvigZzi'
  'gZ3igZ7igZ/igaDigaHigaLigaPigaTigaXigabigafigajiganigarigavigaziga3iga7iga/igbDigbHigbLigbPigbTigbXigbbigbfigbji'
  'gbnigbrigbvigbzigb3igb7igb/igoDigoHigoLigoPigoTigoXigobigofigojigonigorigovigozigo3igo7igo/igpDigpHigpLigpPigpTi'
  'gpXigpbigpfigpjigpnigprigpvigpzigp3igp7igp/igqjigrLigrPigrTigrXigrbigrfigrjigrnigrrigrvigrzigr3igr7igr/ig4Dig4Hi'
  'g4Lig4Pig4Tig4Xig4big4fig4jig4nig4rig4vig4zig43ig47ig4/ig6vig6zig63ig67ig6/ig7Dig7Hig7Lig7Pig7Tig7Xig7big7fig7ji'
  'g7nig7rig7vig7zig73ig77ig7/ihIDihIHihILihIPihIXihIbihIfihInihIrihIvihIzihI3ihI7ihI/ihJDihJHihJLihJPihJXihJbihJni'
  'hJrihJvihJzihJ3ihKDihKHihKLihKTihKbihKjihKrihKvihKzihK3ihK/ihLDihLHihLPihLTihLXihLbihLfihLjihLnihLvihLzihL3ihL7i'
  'hL/ihYDihYXihYbihYfihYjihYnihYzihY3ihY7ihY/ihZDihZHihZLihZPihZTihZXihZbihZfihZjihZnihZrihZvihZzihZ3ihZ7ihZ/ihaDi'
  'haHihaLihaPihaTihaXihabihafihajihaniharihavihaziha3iha7iha/ihbDihbHihbLihbPihbTihbXihbbihbfihbjihbnihbrihbvihbzi'
  'hb3ihb7ihb/ihoTihoXihobihofihojihonihorihovihoziho3iho7iho/iiKziiK3iiK/iiLDikKfikKjikKnikKrikKvikKzikK3ikK7ikK/i'
  'kLDikLHikLLikLPikLTikLXikLbikLfikLjikLnikLrikLvikLzikL3ikL7ikL/ikYvikYzikY3ikY7ikY/ikZDikZHikZLikZPikZTikZXikZbi'
  'kZfikZjikZnikZrikZvikZzikZ3ikZ7ikZ/ikaDikaHikaLikaPikaTikaXikabikafikajikanikarikavikazika3ika7ika/ikbDikbHikbLi'
  'kbPikbTikbXikbbikbfikbjikbnikbrikbvikbzikb3ikb7ikb/ikoDikoHikoLikoPikoTikoXikobikofikojikonikorikovikoziko3iko7i'
  'ko/ikpDikpHikpLikpPikpTikpXikpbikpfikpjikpnikprikpvikpzikp3ikp7ikp/ikqDikqHikqLikqPikqTikqXikqbikqfikqjikqnikqri'
  'kqvikqzikq3ikq7ikq/ikrDikrHikrLikrPikrTikrXikrbikrfikrjikrnikrrikrvikrzikr3ikr7ikr/ik4Dik4Hik4Lik4Pik4Tik4Xik4bi'
  'k4fik4jik4nik4rik4vik4zik43ik47ik4/ik5Dik5Hik5Lik5Pik5Tik5Xik5bik5fik5jik5nik5rik5vik5zik53ik57ik5/ik6Dik6Hik6Li'
  'k6Pik6Tik6Xik6bik6fik6jik6nik6rik7/imJTimJXimJjimb7imb/inIXinIrinIvinKjinYzinY7inZPinZTinZXinZfinZ/inaDinpXinpbi'
  'npfinrDinr/in4Din4Hin4Lin4Pin4Tin4Xin4bin4fin4jin4nin4rin4vin4zin43in47in4/in6zin63in67in6/iqIziqbTiqbXiqbbiupri'
  'up/iu7Piu7Tiu7Xiu7biu7fiu7jiu7niu7riu7viu7ziu73iu77iu7/ivIDivIHivILivIPivITivIXivIbivIfivIjivInivIrivIvivIzivI3i'
  'vI7ivI/ivJDivJHivJLivJPivJTivJXivJbivJfivJjivJnivJrivJvivJzivJ3ivJ7ivJ/ivKDivKHivKLivKPivKTivKXivKbivKfivKjivKni'
  'vKrivKvivKzivK3ivK7ivK/ivLDivLHivLLivLPivLTivLXivLbivLfivLjivLnivLrivLvivLzivL3ivL7ivL/ivYDivYHivYLivYPivYTivYXi'
  'vYbivYfivYjivYnivYrivYvivYzivY3ivY7ivY/ivZDivZHivZLivZPivZTivZXivZbivZfivZjivZnivZrivZvivZzivZ3ivZ7ivZ/ivaDivaHi'
  'vaLivaPivaTivaXivabivafivajivanivarivavivaziva3iva7iva/ivbDivbHivbLivbPivbTivbXivbbivbfivbjivbnivbrivbvivbzivb3i'
  'vb7ivb/ivoDivoHivoLivoPivoTivoXivobivofivojivonivorivovivozivo3ivo7ivo/ivpDivpHivpLivpPivpTivpXivpbivpfivpjivpni'
  'vprivpvivpzivp3ivp7ivp/ivqDivqHivqLivqPivqTivqXivqbivqfivqjivqnivqrivqvivqzivq3ivq7ivq/ivrDivrHivrLivrPivrTivrXi'
  'vrbivrfivrjivrnivrrivrvivrzivr3ivr7ivr/iv4Div4Hiv4Liv4Piv4Tiv4Xiv4biv4fiv4jiv4niv4riv4viv4ziv43iv47iv4/iv5Div5Hi'
  'v5Liv5Piv5Tiv5XjgIDjgLbjgLjjgLnjgLrjgYDjgpfjgpjjgpvjgpzjgp/jg7/jhIDjhIHjhILjhIPjhITjhK3jhK7jhK/jhLDjhLHjhLLjhLPj'
  'hLTjhLXjhLbjhLfjhLjjhLnjhLrjhLvjhLzjhL3jhL7jhL/jhYDjhYHjhYLjhYPjhYTjhYXjhYbjhYfjhYjjhYnjhYrjhYvjhYzjhY3jhY7jhY/j'
  'hZDjhZHjhZLjhZPjhZTjhZXjhZbjhZfjhZjjhZnjhZrjhZvjhZzjhZ3jhZ7jhZ/jhaDjhaHjhaLjhaPjhaTjhaXjhabjhafjhajjhanjharjhavj'
  'hazjha3jha7jha/jhbDjhbHjhbLjhbPjhbTjhbXjhbbjhbfjhbjjhbnjhbrjhbvjhbzjhb3jhb7jhb/jhoDjhoHjhoLjhoPjhoTjhoXjhobjhofj'
  'hojjhonjhorjhovjhozjho3jho7jho/jhpLjhpPjhpTjhpXjhpbjhpfjhpjjhpnjhprjhpvjhpzjhp3jhp7jhp/jiIDjiIHjiILjiIPjiITjiIXj'
  'iIbjiIfjiIjjiInjiIrjiIvjiIzjiI3jiI7jiI/jiJDjiJHjiJLjiJPjiJTjiJXjiJbjiJfjiJjjiJnjiJrjiJvjiJzjiJ3jiJ7jiJ/jiKDjiKHj'
  'iKLjiKPjiKTjiKXjiKbjiKfjiKjjiKnjiKrjiKvjiKzjiK3jiK7jiK/jiLDjiLHjiLLjiLPjiLTjiLXjiLbjiLfjiLjjiLnjiLrjiLvjiLzjiL3j'
  'iL7jiL/jiYDjiYHjiYLjiYPjiYTjiYXjiYbjiYfjiYjjiYnjiYrjiYvjiYzjiY3jiY7jiY/jiZDjiZHjiZLjiZPjiZTjiZXjiZbjiZfjiZjjiZnj'
  'iZrjiZvjiZzjiZ3jiZ7jiZ/jiaDjiaHjiaLjiaPjiaTjiaXjiabjiafjiajjianjiarjiavjiazjia3jia7jia/jibDjibHjibLjibPjibTjibXj'
  'ibbjibfjibjjibnjibrjibvjibzjib3jib7jioDjioHjioLjioPjioTjioXjiobjiofjiojjionjiorjiovjiozjio3jio7jio/jipDjipHjipLj'
  'ipPjipTjipXjipbjipfjipjjipnjiprjipvjipzjip3jip7jip/jiqDjiqHjiqLjiqPjiqTjiqXjiqbjiqfjiqjjiqnjiqrjiqvjiqzjiq3jiq7j'
  'iq/jirDjirHjirLjirPjirTjirXjirbjirfjirjjirnjirrjirvjirzjir3jir7jir/ji4Dji4Hji4Lji4Pji4Tji4Xji4bji4fji4jji4nji4rj'
  'i4vji4zji43ji47ji4/ji5Dji5Hji5Lji5Pji5Tji5Xji5bji5fji5jji5nji5rji5vji5zji53ji57ji5/ji6Dji6Hji6Lji6Pji6Tji6Xji6bj'
  'i6fji6jji6nji6rji6vji6zji63ji67ji6/ji7Dji7Hji7Lji7Pji7Tji7Xji7bji7fji7jji7nji7rji7vji7zji73ji77ji7/jjIDjjIHjjILj'
  'jIPjjITjjIXjjIbjjIfjjIjjjInjjIrjjIvjjIzjjI3jjI7jjI/jjJDjjJHjjJLjjJPjjJTjjJXjjJbjjJfjjJjjjJnjjJrjjJvjjJzjjJ3jjJ7j'
  'jJ/jjKDjjKHjjKLjjKPjjKTjjKXjjKbjjKfjjKjjjKnjjKrjjKvjjKzjjK3jjK7jjK/jjLDjjLHjjLLjjLPjjLTjjLXjjLbjjLfjjLjjjLnjjLrj'
  'jLvjjLzjjL3jjL7jjL/jjYDjjYHjjYLjjYPjjYTjjYXjjYbjjYfjjYjjjYnjjYrjjYvjjYzjjY3jjY7jjY/jjZDjjZHjjZLjjZPjjZTjjZXjjZbj'
  'jZfjjZjjjZnjjZrjjZvjjZzjjZ3jjZ7jjZ/jjaDjjaHjjaLjjaPjjaTjjaXjjabjjafjjajjjanjjarjjavjjazjja3jja7jja/jjbDjjbHjjbLj'
  'jbPjjbTjjbXjjbbjjbfjjbjjjbnjjbrjjbvjjbzjjb3jjb7jjb/jjoDjjoHjjoLjjoPjjoTjjoXjjobjjofjjojjjonjjorjjovjjozjjo3jjo7j'
  'jo/jjpDjjpHjjpLjjpPjjpTjjpXjjpbjjpfjjpjjjpnjjprjjpvjjpzjjp3jjp7jjp/jjqDjjqHjjqLjjqPjjqTjjqXjjqbjjqfjjqjjjqnjjqrj'
  'jqvjjqzjjq3jjq7jjq/jjrDjjrHjjrLjjrPjjrTjjrXjjrbjjrfjjrjjjrnjjrrjjrvjjrzjjr3jjr7jjr/jj4Djj4Hjj4Ljj4Pjj4Tjj4Xjj4bj'
  'j4fjj4jjj4njj4rjj4vjj4zjj43jj47jj4/jj5Djj5Hjj5Ljj5Pjj5Tjj5Xjj5bjj5fjj5jjj5njj5rjj5vjj5zjj53jj57jj5/jj6Djj6Hjj6Lj'
  'j6Pjj6Tjj6Xjj6bjj6fjj6jjj6njj6rjj6vjj6zjj63jj67jj6/jj7Djj7Hjj7Ljj7Pjj7Tjj7Xjj7bjj7fjj7jjj7njj7rjj7vjj7zjj73jj77j'
  'j7/qko3qko7qko/vqK7vqK/vrIDvrIHvrILvrIPvrITvrIXvrIbvrIfvrIjvrInvrIrvrIvvrIzvrI3vrI7vrI/vrJDvrJHvrJLvrJPvrJTvrJXv'
  'rJbvrJfvrJjvrJnvrJrvrJvvrJzvrKDvrKHvrKLvrKPvrKTvrKXvrKbvrKfvrKjvrKnvrLfvrL3vrL/vrYLvrYXvrY/vrZDvrZHvrZLvrZPvrZTv'
  'rZXvrZbvrZfvrZjvrZnvrZrvrZvvrZzvrZ3vrZ7vrZ/vraDvraHvraLvraPvraTvraXvrabvrafvrajvranvrarvravvrazvra3vra7vra/vrbDv'
  'rbHvrbLvrbPvrbTvrbXvrbbvrbfvrbjvrbnvrbrvrbvvrbzvrb3vrb7vrb/vroDvroHvroLvroPvroTvroXvrobvrofvrojvronvrorvrovvrozv'
  'ro3vro7vro/vrpDvrpHvrpLvrpPvrpTvrpXvrpbvrpfvrpjvrpnvrprvrpvvrpzvrp3vrp7vrp/vrqDvrqHvrqLvrqPvrqTvrqXvrqbvrqfvrqjv'
  'rqnvrqrvrqvvrqzvrq3vrq7vrq/vrrDvrrHvr5Pvr5Tvr5Xvr5bvr5fvr5jvr5nvr5rvr5vvr5zvr53vr57vr5/vr6Dvr6Hvr6Lvr6Pvr6Tvr6Xv'
  'r6bvr6fvr6jvr6nvr6rvr6vvr6zvr63vr67vr6/vr7Dvr7Hvr7Lvr7Pvr7Tvr7Xvr7bvr7fvr7jvr7nvr7rvr7vvr7zvr73vr77vr7/vsIDvsIHv'
  'sILvsIPvsITvsIXvsIbvsIfvsIjvsInvsIrvsIvvsIzvsI3vsI7vsI/vsJDvsJHvsJLvsJPvsJTvsJXvsJbvsJfvsJjvsJnvsJrvsJvvsJzvsJ3v'
  'sJ7vsJ/vsKDvsKHvsKLvsKPvsKTvsKXvsKbvsKfvsKjvsKnvsKrvsKvvsKzvsK3vsK7vsK/vsLDvsLHvsLLvsLPvsLTvsLXvsLbvsLfvsLjvsLnv'
  'sLrvsLvvsLzvsL3vsL7vsL/vsYDvsYHvsYLvsYPvsYTvsYXvsYbvsYfvsYjvsYnvsYrvsYvvsYzvsY3vsY7vsY/vsZDvsZHvsZLvsZPvsZTvsZXv'
  'sZbvsZfvsZjvsZnvsZrvsZvvsZzvsZ3vsZ7vsZ/vsaDvsaHvsaLvsaPvsaTvsaXvsabvsafvsajvsanvsarvsavvsazvsa3vsa7vsa/vsbDvsbHv'
  'sbLvsbPvsbTvsbXvsbbvsbfvsbjvsbnvsbrvsbvvsbzvsb3vsb7vsb/vsoDvsoHvsoLvsoPvsoTvsoXvsobvsofvsojvsonvsorvsovvsozvso3v'
  'so7vso/vspDvspHvspLvspPvspTvspXvspbvspfvspjvspnvsprvspvvspzvsp3vsp7vsp/vsqDvsqHvsqLvsqPvsqTvsqXvsqbvsqfvsqjvsqnv'
  'sqrvsqvvsqzvsq3vsq7vsq/vsrDvsrHvsrLvsrPvsrTvsrXvsrbvsrfvsrjvsrnvsrrvsrvvsrzvsr3vsr7vsr/vs4Dvs4Hvs4Lvs4Pvs4Tvs4Xv'
  's4bvs4fvs4jvs4nvs4rvs4vvs4zvs43vs47vs4/vs5Dvs5Hvs5Lvs5Pvs5Tvs5Xvs5bvs5fvs5jvs5nvs5rvs5vvs5zvs53vs57vs5/vs6Dvs6Hv'
  's6Lvs6Pvs6Tvs6Xvs6bvs6fvs6jvs6nvs6rvs6vvs6zvs63vs67vs6/vs7Dvs7Hvs7Lvs7Pvs7Tvs7Xvs7bvs7fvs7jvs7nvs7rvs7vvs7zvs73v'
  's77vs7/vtIDvtIHvtILvtIPvtITvtIXvtIbvtIfvtIjvtInvtIrvtIvvtIzvtI3vtI7vtI/vtJDvtJHvtJLvtJPvtJTvtJXvtJbvtJfvtJjvtJnv'
  'tJrvtJvvtJzvtJ3vtJ7vtJ/vtKDvtKHvtKLvtKPvtKTvtKXvtKbvtKfvtKjvtKnvtKrvtKvvtKzvtK3vtK7vtK/vtLDvtLHvtLLvtLPvtLTvtLXv'
  'tLbvtLfvtLjvtLnvtLrvtLvvtLzvtL3vtYDvtYHvtYLvtYPvtYTvtYXvtYbvtYfvtYjvtYnvtYrvtYvvtYzvtY3vtY7vtY/vtZDvtZHvtZLvtZPv'
  'tZTvtZXvtZbvtZfvtZjvtZnvtZrvtZvvtZzvtZ3vtZ7vtZ/vtaDvtaHvtaLvtaPvtaTvtaXvtabvtafvtajvtanvtarvtavvtazvta3vta7vta/v'
  'tbDvtbHvtbLvtbPvtbTvtbXvtbbvtbfvtbjvtbnvtbrvtbvvtbzvtb3vtb7vtb/vtoDvtoHvtoLvtoPvtoTvtoXvtobvtofvtojvtonvtorvtovv'
  'tozvto3vto7vto/vtpDvtpHvtpLvtpPvtpTvtpXvtpbvtpfvtpjvtpnvtprvtpvvtpzvtp3vtp7vtp/vtqDvtqHvtqLvtqPvtqTvtqXvtqbvtqfv'
  'tqjvtqnvtqrvtqvvtqzvtq3vtq7vtq/vtrDvtrHvtrLvtrPvtrTvtrXvtrbvtrfvtrjvtrnvtrrvtrvvtrzvtr3vtr7vtr/vt4Dvt4Hvt4Lvt4Pv'
  't4Tvt4Xvt4bvt4fvt7Dvt7Hvt7Lvt7Pvt7Tvt7Xvt7bvt7fvt7jvt7nvt7rvt7vvt7zvt73vt77vt7/vuIDvuIHvuILvuIPvuITvuIXvuIbvuIfv'
  'uIjvuInvuIrvuIvvuIzvuI3vuI7vuI/vuJDvuJHvuJLvuJPvuJTvuJXvuJbvuJfvuJjvuJnvuJrvuJvvuJzvuJ3vuJ7vuJ/vuKTvuKXvuKbvuKfv'
  'uKjvuKnvuKrvuKvvuKzvuK3vuK7vuK/vuLDvuLHvuLLvuLPvuLTvuLXvuLbvuLfvuLjvuLnvuLrvuLvvuLzvuL3vuL7vuL/vuYDvuYHvuYLvuYPv'
  'uYTvuYfvuYjvuYnvuYrvuYvvuYzvuY3vuY7vuY/vuZDvuZHvuZLvuZPvuZTvuZXvuZbvuZfvuZjvuZnvuZrvuZvvuZzvuZ3vuZ7vuZ/vuaDvuaHv'
  'uaLvuaPvuaTvuaXvuabvuafvuajvuanvuarvuavvuazvua3vua7vua/vubDvubHvubLvubTvubXvubbvubfvubjvubnvubrvubvvubzvub3vub7v'
  'ub/vuoDvuoHvuoLvuoPvuoTvuoXvuobvuofvuojvuonvuorvuovvuozvuo3vuo7vuo/vupDvupHvupLvupPvupTvupXvupbvupfvupjvupnvuprv'
  'upvvupzvup3vup7vup/vuqDvuqHvuqLvuqPvuqTvuqXvuqbvuqfvuqjvuqnvuqrvuqvvuqzvuq3vuq7vuq/vurDvurHvurLvurPvurTvurXvurbv'
  'urfvurjvurnvurrvurvvurzvur3vur7vur/vu4Dvu4Hvu4Lvu4Pvu4Tvu4Xvu4bvu4fvu4jvu4nvu4rvu4vvu4zvu43vu47vu4/vu5Dvu5Hvu5Lv'
  'u5Pvu5Tvu5Xvu5bvu5fvu5jvu5nvu5rvu5vvu5zvu53vu57vu5/vu6Dvu6Hvu6Lvu6Pvu6Tvu6Xvu6bvu6fvu6jvu6nvu6rvu6vvu6zvu63vu67v'
  'u6/vu7Dvu7Hvu7Lvu7Pvu7Tvu7Xvu7bvu7fvu7jvu7nvu7rvu7vvu7zvu73vu77vu7/vvIDvvIHvvILvvIPvvITvvIXvvIbvvIfvvIjvvInvvIrv'
  'vIvvvIzvvI3vvI7vvI/vvJDvvJHvvJLvvJPvvJTvvJXvvJbvvJfvvJjvvJnvvJrvvJvvvJzvvJ3vvJ7vvJ/vvKDvvKHvvKLvvKPvvKTvvKXvvKbv'
  'vKfvvKjvvKnvvKrvvKvvvKzvvK3vvK7vvK/vvLDvvLHvvLLvvLPvvLTvvLXvvLbvvLfvvLjvvLnvvLrvvLvvvLzvvL3vvL7vvL/vvYDvvYHvvYLv'
  'vYPvvYTvvYXvvYbvvYfvvYjvvYnvvYrvvYvvvYzvvY3vvY7vvY/vvZDvvZHvvZLvvZPvvZTvvZXvvZbvvZfvvZjvvZnvvZrvvZvvvZzvvZ3vvZ7v'
  'vZ/vvaDvvaHvvaLvvaPvvaTvvaXvvabvvafvvajvvanvvarvvavvvazvva3vva7vva/vvbDvvbHvvbLvvbPvvbTvvbXvvbbvvbfvvbjvvbnvvbrv'
  'vbvvvbzvvb3vvb7vvb/vvoDvvoHvvoLvvoPvvoTvvoXvvobvvofvvojvvonvvorvvovvvozvvo3vvo7vvo/vvpDvvpHvvpLvvpPvvpTvvpXvvpbv'
  'vpfvvpjvvpnvvprvvpvvvpzvvp3vvp7vvp/vvqDvvqHvvqLvvqPvvqTvvqXvvqbvvqfvvqjvvqnvvqrvvqvvvqzvvq3vvq7vvq/vvrDvvrHvvrLv'
  'vrPvvrTvvrXvvrbvvrfvvrjvvrnvvrrvvrvvvrzvvr3vvr7vvr/vv4Dvv4Hvv4Lvv4Pvv4Tvv4Xvv4bvv4fvv4jvv4nvv4rvv4vvv4zvv43vv47v'
  'v4/vv5Dvv5Hvv5Lvv5Pvv5Tvv5Xvv5bvv5fvv5jvv5nvv5rvv5vvv5zvv53vv57vv5/vv6Dvv6Hvv6Lvv6Pvv6Tvv6Xvv6bvv6fvv6jvv6nvv6rv'
  'v6vvv6zvv63vv67wkIyf8JCMpPCQjKXwkIym8JCMp/CQjKjwkIyp8JCMqvCQjKvwkIys8JCMrfCQjK7wkIyv8JCQgPCQkIHwkJCC8JCQg/CQkITw'
  'kJCF8JCQhvCQkIfwkJCI8JCQifCQkIrwkJCL8JCQjPCQkI3wkJCO8JCQj/CQkJDwkJCR8JCQkvCQkJPwkJCU8JCQlfCQkJbwkJCX8JCQmPCQkJnw'
  'kJCa8JCQm/CQkJzwkJCd8JCQnvCQkJ/wkJCg8JCQofCQkKLwkJCj8JCQpPCQkKXwkJCm8JCQp/Cdg7bwnYO38J2DuPCdg7nwnYO68J2Du/Cdg7zw'
  'nYO98J2DvvCdg7/wnYSn8J2EqPCdhKnwnYWz8J2FtPCdhbXwnYW28J2Ft/CdhbjwnYW58J2FuvCdkIDwnZCB8J2QgvCdkIPwnZCE8J2QhfCdkIbw'
  'nZCH8J2QiPCdkInwnZCK8J2Qi/CdkIzwnZCN8J2QjvCdkI/wnZCQ8J2QkfCdkJLwnZCT8J2QlPCdkJXwnZCW8J2Ql/CdkJjwnZCZ8J2QmvCdkJvw'
  'nZCc8J2QnfCdkJ7wnZCf8J2QoPCdkKHwnZCi8J2Qo/CdkKTwnZCl8J2QpvCdkKfwnZCo8J2QqfCdkKrwnZCr8J2QrPCdkK3wnZCu8J2Qr/CdkLDw'
  'nZCx8J2QsvCdkLPwnZC08J2QtfCdkLbwnZC38J2QuPCdkLnwnZC68J2Qu/CdkLzwnZC98J2QvvCdkL/wnZGA8J2RgfCdkYLwnZGD8J2RhPCdkYXw'
  'nZGG8J2Rh/CdkYjwnZGJ8J2RivCdkYvwnZGM8J2RjfCdkY7wnZGP8J2RkPCdkZHwnZGS8J2Rk/CdkZTwnZGV8J2RlvCdkZfwnZGY8J2RmfCdkZrw'
  'nZGb8J2RnPCdkZ3wnZGe8J2Rn/CdkaDwnZGh8J2RovCdkaPwnZGk8J2RpfCdkabwnZGn8J2RqPCdkanwnZGq8J2Rq/CdkazwnZGt8J2RrvCdka/w'
  'nZGw8J2RsfCdkbLwnZGz8J2RtPCdkbXwnZG28J2Rt/CdkbjwnZG58J2RuvCdkbvwnZG88J2RvfCdkb7wnZG/8J2SgPCdkoHwnZKC8J2Sg/CdkoTw'
  'nZKF8J2ShvCdkofwnZKI8J2SifCdkorwnZKL8J2SjPCdko3wnZKO8J2Sj/CdkpDwnZKR8J2SkvCdkpPwnZKU8J2SlfCdkpbwnZKX8J2SmPCdkpnw'
  'nZKa8J2Sm/CdkpzwnZKd8J2SnvCdkp/wnZKg8J2SofCdkqLwnZKj8J2SpPCdkqXwnZKm8J2Sp/CdkqjwnZKp8J2SqvCdkqvwnZKs8J2SrfCdkq7w'
  'nZKv8J2SsPCdkrHwnZKy8J2Ss/CdkrTwnZK18J2StvCdkrfwnZK48J2SufCdkrrwnZK78J2SvPCdkr3wnZK+8J2Sv/Cdk4DwnZOB8J2TgvCdk4Pw'
  'nZOE8J2ThfCdk4bwnZOH8J2TiPCdk4nwnZOK8J2Ti/Cdk4zwnZON8J2TjvCdk4/wnZOQ8J2TkfCdk5LwnZOT8J2TlPCdk5XwnZOW8J2Tl/Cdk5jw'
  'nZOZ8J2TmvCdk5vwnZOc8J2TnfCdk57wnZOf8J2ToPCdk6HwnZOi8J2To/Cdk6TwnZOl8J2TpvCdk6fwnZOo8J2TqfCdk6rwnZOr8J2TrPCdk63w'
  'nZOu8J2Tr/Cdk7DwnZOx8J2TsvCdk7PwnZO08J2TtfCdk7bwnZO38J2TuPCdk7nwnZO68J2Tu/Cdk7zwnZO98J2TvvCdk7/wnZSA8J2UgfCdlILw'
  'nZSD8J2UhPCdlIXwnZSG8J2Uh/CdlIjwnZSJ8J2UivCdlIvwnZSM8J2UjfCdlI7wnZSP8J2UkPCdlJHwnZSS8J2Uk/CdlJTwnZSV8J2UlvCdlJfw'
  'nZSY8J2UmfCdlJrwnZSb8J2UnPCdlJ3wnZSe8J2Un/CdlKDwnZSh8J2UovCdlKPwnZSk8J2UpfCdlKbwnZSn8J2UqPCdlKnwnZSq8J2Uq/CdlKzw'
  'nZSt8J2UrvCdlK/wnZSw8J2UsfCdlLLwnZSz8J2UtPCdlLXwnZS28J2Ut/CdlLjwnZS58J2UuvCdlLvwnZS88J2UvfCdlL7wnZS/8J2VgPCdlYHw'
  'nZWC8J2Vg/CdlYTwnZWF8J2VhvCdlYfwnZWI8J2VifCdlYrwnZWL8J2VjPCdlY3wnZWO8J2Vj/CdlZDwnZWR8J2VkvCdlZPwnZWU8J2VlfCdlZbw'
  'nZWX8J2VmPCdlZnwnZWa8J2Vm/CdlZzwnZWd8J2VnvCdlZ/wnZWg8J2VofCdlaLwnZWj8J2VpPCdlaXwnZWm8J2Vp/CdlajwnZWp8J2VqvCdlavw'
  'nZWs8J2VrfCdla7wnZWv8J2VsPCdlbHwnZWy8J2Vs/CdlbTwnZW18J2VtvCdlbfwnZW48J2VufCdlbrwnZW78J2VvPCdlb3wnZW+8J2Vv/CdloDw'
  'nZaB8J2WgvCdloPwnZaE8J2WhfCdlobwnZaH8J2WiPCdlonwnZaK8J2Wi/CdlozwnZaN8J2WjvCdlo/wnZaQ8J2WkfCdlpLwnZaT8J2WlPCdlpXw'
  'nZaW8J2Wl/CdlpjwnZaZ8J2WmvCdlpvwnZac8J2WnfCdlp7wnZaf8J2WoPCdlqHwnZai8J2Wo/CdlqTwnZal8J2WpvCdlqfwnZao8J2WqfCdlqrw'
  'nZar8J2WrPCdlq3wnZau8J2Wr/CdlrDwnZax8J2WsvCdlrPwnZa08J2WtfCdlrbwnZa38J2WuPCdlrnwnZa68J2Wu/CdlrzwnZa98J2WvvCdlr/w'
  'nZeA8J2XgfCdl4LwnZeD8J2XhPCdl4XwnZeG8J2Xh/Cdl4jwnZeJ8J2XivCdl4vwnZeM8J2XjfCdl47wnZeP8J2XkPCdl5HwnZeS8J2Xk/Cdl5Tw'
  'nZeV8J2XlvCdl5fwnZeY8J2XmfCdl5rwnZeb8J2XnPCdl53wnZee8J2Xn/Cdl6DwnZeh8J2XovCdl6PwnZek8J2XpfCdl6bwnZen8J2XqPCdl6nw'
  'nZeq8J2Xq/Cdl6zwnZet8J2XrvCdl6/wnZew8J2XsfCdl7LwnZez8J2XtPCdl7XwnZe28J2Xt/Cdl7jwnZe58J2XuvCdl7vwnZe88J2XvfCdl77w'
  'nZe/8J2YgPCdmIHwnZiC8J2Yg/CdmITwnZiF8J2YhvCdmIfwnZiI8J2YifCdmIrwnZiL8J2YjPCdmI3wnZiO8J2Yj/CdmJDwnZiR8J2YkvCdmJPw'
  'nZiU8J2YlfCdmJbwnZiX8J2YmPCdmJnwnZia8J2Ym/CdmJzwnZid8J2YnvCdmJ/wnZig8J2YofCdmKLwnZij8J2YpPCdmKXwnZim8J2Yp/CdmKjw'
  'nZip8J2YqvCdmKvwnZis8J2YrfCdmK7wnZiv8J2YsPCdmLHwnZiy8J2Ys/CdmLTwnZi18J2YtvCdmLfwnZi48J2YufCdmLrwnZi78J2YvPCdmL3w'
  'nZi+8J2Yv/CdmYDwnZmB8J2ZgvCdmYPwnZmE8J2ZhfCdmYbwnZmH8J2ZiPCdmYnwnZmK8J2Zi/CdmYzwnZmN8J2ZjvCdmY/wnZmQ8J2ZkfCdmZLw'
  'nZmT8J2ZlPCdmZXwnZmW8J2Zl/CdmZjwnZmZ8J2ZmvCdmZvwnZmc8J2ZnfCdmZ7wnZmf8J2ZoPCdmaHwnZmi8J2Zo/CdmaTwnZml8J2ZpvCdmafw'
  'nZmo8J2ZqfCdmarwnZmr8J2ZrPCdma3wnZmu8J2Zr/CdmbDwnZmx8J2ZsvCdmbPwnZm08J2ZtfCdmbbwnZm38J2ZuPCdmbnwnZm68J2Zu/Cdmbzw'
  'nZm98J2ZvvCdmb/wnZqA8J2agfCdmoLwnZqD8J2ahPCdmoXwnZqG8J2ah/CdmojwnZqJ8J2aivCdmovwnZqM8J2ajfCdmo7wnZqP8J2akPCdmpHw'
  'nZqS8J2ak/CdmpTwnZqV8J2alvCdmpfwnZqY8J2amfCdmprwnZqb8J2anPCdmp3wnZqe8J2an/CdmqDwnZqh8J2aovCdmqPwnZqk8J2apfCdmqbw'
  'nZqn8J2aqPCdmqnwnZqq8J2aq/CdmqzwnZqt8J2arvCdmq/wnZqw8J2asfCdmrLwnZqz8J2atPCdmrXwnZq28J2at/CdmrjwnZq58J2auvCdmrvw'
  'nZq88J2avfCdmr7wnZq/8J2bgPCdm4HwnZuC8J2bg/Cdm4TwnZuF8J2bhvCdm4fwnZuI8J2bifCdm4rwnZuL8J2bjPCdm43wnZuO8J2bj/Cdm5Dw'
  'nZuR8J2bkvCdm5PwnZuU8J2blfCdm5bwnZuX8J2bmPCdm5nwnZua8J2bm/Cdm5zwnZud8J2bnvCdm5/wnZug8J2bofCdm6LwnZuj8J2bpPCdm6Xw'
  'nZum8J2bp/Cdm6jwnZup8J2bqvCdm6vwnZus8J2brfCdm67wnZuv8J2bsPCdm7HwnZuy8J2bs/Cdm7TwnZu18J2btvCdm7fwnZu48J2bufCdm7rw'
  'nZu78J2bvPCdm73wnZu+8J2bv/CdnIDwnZyB8J2cgvCdnIPwnZyE8J2chfCdnIbwnZyH8J2ciPCdnInwnZyK8J2ci/CdnIzwnZyN8J2cjvCdnI/w'
  'nZyQ8J2ckfCdnJLwnZyT8J2clPCdnJXwnZyW8J2cl/CdnJjwnZyZ8J2cmvCdnJvwnZyc8J2cnfCdnJ7wnZyf8J2coPCdnKHwnZyi8J2co/CdnKTw'
  'nZyl8J2cpvCdnKfwnZyo8J2cqfCdnKrwnZyr8J2crPCdnK3wnZyu8J2cr/CdnLDwnZyx8J2csvCdnLPwnZy08J2ctfCdnLbwnZy38J2cuPCdnLnw'
  'nZy68J2cu/CdnLzwnZy98J2cvvCdnL/wnZ2A8J2dgfCdnYLwnZ2D8J2dhPCdnYXwnZ2G8J2dh/CdnYjwnZ2J8J2divCdnYvwnZ2M8J2djfCdnY7w'
  'nZ2P8J2dkPCdnZHwnZ2S8J2dk/CdnZTwnZ2V8J2dlvCdnZfwnZ2Y8J2dmfCdnZrwnZ2b8J2dnPCdnZ3wnZ2e8J2dn/CdnaDwnZ2h8J2dovCdnaPw'
  'nZ2k8J2dpfCdnabwnZ2n8J2dqPCdnanwnZ2q8J2dq/CdnazwnZ2t8J2drvCdna/wnZ2w8J2dsfCdnbLwnZ2z8J2dtPCdnbXwnZ228J2dt/Cdnbjw'
  'nZ258J2duvCdnbvwnZ288J2dvfCdnb7wnZ2/8J2egPCdnoHwnZ6C8J2eg/CdnoTwnZ6F8J2ehvCdnofwnZ6I8J2eifCdnorwnZ6L8J2ejPCdno3w'
  'nZ6O8J2ej/CdnpDwnZ6R8J2ekvCdnpPwnZ6U8J2elfCdnpbwnZ6X8J2emPCdnpnwnZ6a8J2em/CdnpzwnZ6d8J2envCdnp/wnZ6g8J2eofCdnqLw'
  'nZ6j8J2epPCdnqXwnZ6m8J2ep/CdnqjwnZ6p8J2eqvCdnqvwnZ6s8J2erfCdnq7wnZ6v8J2esPCdnrHwnZ6y8J2es/CdnrTwnZ618J2etvCdnrfw'
  'nZ648J2eufCdnrrwnZ678J2evPCdnr3wnZ6+8J2ev/Cdn4DwnZ+B8J2fgvCdn4PwnZ+E8J2fhfCdn4bwnZ+H8J2fiPCdn4nwnZ+K8J2fi/Cdn4zw'
  'nZ+N8J2fjvCdn4/wnZ+Q8J2fkfCdn5LwnZ+T8J2flPCdn5XwnZ+W8J2fl/Cdn5jwnZ+Z8J2fmvCdn5vwnZ+c8J2fnfCdn57wnZ+f8J2foPCdn6Hw'
  'nZ+i8J2fo/Cdn6TwnZ+l8J2fpvCdn6fwnZ+o8J2fqfCdn6rwnZ+r8J2frPCdn63wnZ+u8J2fr/Cdn7DwnZ+x8J2fsvCdn7PwnZ+08J2ftfCdn7bw'
  'nZ+38J2fuPCdn7nwnZ+68J2fu/Cdn7zwnZ+98J2fvvCdn7/wr6Go8K+htPCvpJ/wr6Wf8K+mvw=='
)));
CREATE OR REPLACE MACRO gtfs_vc_idn_values() AS (decode(from_base64(
  'YQFiAWMBZAFlAWYBZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6ASABIMyIAWEBASDMhAEyATMBIMyBAc68ASDMpwExAW8B'
  'MeKBhDQBMeKBhDIBM+KBhDQBw6ABw6EBw6IBw6MBw6QBw6UBw6YBw6cBw6gBw6kBw6oBw6sBw6wBw60Bw64Bw68Bw7ABw7EBw7IBw7MBw7QBw7UB'
  'w7YBw7gBw7kBw7oBw7sBw7wBw70Bw74Bc3MBxIEBxIMBxIUBxIcBxIkBxIsBxI0BxI8BxJEBxJMBxJUBxJcBxJkBxJsBxJ0BxJ8BxKEBxKMBxKUB'
  'xKcBxKkBxKsBxK0BxK8BacyHAWlqAWlqAcS1AcS3AcS6AcS8AcS+AWzCtwFswrcBxYIBxYQBxYYBxYgByrxuAcWLAcWNAcWPAcWRAcWTAcWVAcWX'
  'AcWZAcWbAcWdAcWfAcWhAcWjAcWlAcWnAcWpAcWrAcWtAcWvAcWxAcWzAcW1AcW3AcO/AcW6AcW8AcW+AXMByZMBxoMBxoUByZQBxogByZYByZcB'
  'xowBx50ByZkByZsBxpIByaAByaMByakByagBxpkBya8BybIBybUBxqEBxqMBxqUByoABxqgByoMBxq0ByogBxrAByooByosBxrQBxrYBypIBxrkB'
  'xr0BZMW+AWTFvgFkxb4BbGoBbGoBbGoBbmoBbmoBbmoBx44Bx5ABx5IBx5QBx5YBx5gBx5oBx5wBx58Bx6EBx6MBx6UBx6cBx6kBx6sBx60Bx68B'
  'ZHoBZHoBZHoBx7UBxpUBxr8Bx7kBx7sBx70Bx78ByIEByIMByIUByIcByIkByIsByI0ByI8ByJEByJMByJUByJcByJkByJsByJ0ByJ8Bxp4B7oCA'
  'AcijAcilAcinAcipAcirAcitAcivAcixAcizAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB'
  '7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAWgByaYBagFyAcm5Acm7AcqBAXcB'
  'eQEgzIYBIMyHASDMigEgzKgBIMyDASDMiwHJowFsAXMBeAHKlQHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAc65AQHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAEgzrkB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAEgzIEBIMyIzIEB'
  'zqwBzq0Bzq4Bzq8B7oCAAc+MAe6AgAHPjQHPjgHOsQHOsgHOswHOtAHOtQHOtgHOtwHOuAHOuQHOugHOuwHOvAHOvQHOvgHOvwHPgAHPgQHugIAB'
  'z4MBz4QBz4UBz4YBz4cBz4gBz4kBz4oBz4sBz4MB7oCAAc6yAc64Ac+FAc+NAc+LAc+GAc+AAc+ZAc+bAc+dAc+fAc+hAc+jAc+lAc+nAc+pAc+r'
  'Ac+tAc+vAc66Ac+BAc+DAc64Ac61Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAdGQAdGRAdGSAdGTAdGUAdGVAdGWAdGXAdGY'
  'AdGZAdGaAdGbAdGcAdGdAdGeAdGfAdCwAdCxAdCyAdCzAdC0AdC1AdC2AdC3AdC4AdC5AdC6AdC7AdC8AdC9AdC+AdC/AdGAAdGBAdGCAdGDAdGE'
  'AdGFAdGGAdGHAdGIAdGJAdGKAdGLAdGMAdGNAdGOAdGPAdGhAdGjAdGlAdGnAdGpAdGrAdGtAdGvAdGxAdGzAdG1AdG3AdG5AdG7AdG9AdG/AdKB'
  'Ae6AgAHSiwHSjQHSjwHSkQHSkwHSlQHSlwHSmQHSmwHSnQHSnwHSoQHSowHSpQHSpwHSqQHSqwHSrQHSrwHSsQHSswHStQHStwHSuQHSuwHSvQHS'
  'vwHTggHThAHThgHTiAHTigHTjAHTjgHugIAB05EB05MB05UB05cB05kB05sB050B058B06EB06MB06UB06cB06kB06sB060B068B07EB07MB07UB'
  '7oCAAe6AgAHTuQHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHUgQHUgwHUhQHUhwHUiQHUiwHUjQHUjwHVoQHVogHVowHVpAHVpQHVpgHVpwHVqAHV'
  'qQHVqgHVqwHVrAHVrQHVrgHVrwHVsAHVsQHVsgHVswHVtAHVtQHVtgHVtwHVuAHVuQHVugHVuwHVvAHVvQHVvgHVvwHWgAHWgQHWggHWgwHWhAHW'
  'hQHWhgHugIAB7oCAAe6AgAHVpdaCAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAdin2bQB2YjZtAHbh9m0AdmK2bQB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHguY3guLIB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHgu43gurIB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB'
  '7oCAAe6AgAHugIAB4Lqr4LqZAeC6q+C6oQHgvIsB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAeC+suC9seC+gAHgvrPgvbHgvoAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAEBAQEB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAeG4gQHhuIMB4biFAeG4hwHhuIkB4biLAeG4jQHhuI8B4biRAeG4kwHhuJUB4biXAeG4mQHhuJsB4bidAeG4'
  'nwHhuKEB4bijAeG4pQHhuKcB4bipAeG4qwHhuK0B4bivAeG4sQHhuLMB4bi1AeG4twHhuLkB4bi7AeG4vQHhuL8B4bmBAeG5gwHhuYUB4bmHAeG5'
  'iQHhuYsB4bmNAeG5jwHhuZEB4bmTAeG5lQHhuZcB4bmZAeG5mwHhuZ0B4bmfAeG5oQHhuaMB4bmlAeG5pwHhuakB4bmrAeG5rQHhua8B4bmxAeG5'
  'swHhubUB4bm3AeG5uQHhubsB4bm9AeG5vwHhuoEB4bqDAeG6hQHhuocB4bqJAeG6iwHhuo0B4bqPAeG6kQHhupMB4bqVAWHKvgHhuaEB7oCAAe6A'
  'gAHugIAB7oCAAeG6oQHhuqMB4bqlAeG6pwHhuqkB4bqrAeG6rQHhuq8B4bqxAeG6swHhurUB4bq3AeG6uQHhursB4bq9AeG6vwHhu4EB4buDAeG7'
  'hQHhu4cB4buJAeG7iwHhu40B4buPAeG7kQHhu5MB4buVAeG7lwHhu5kB4bubAeG7nQHhu58B4buhAeG7owHhu6UB4bunAeG7qQHhu6sB4butAeG7'
  'rwHhu7EB4buzAeG7tQHhu7cB4bu5Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAeG8gAHhvIEB4byCAeG8gwHhvIQB4byFAeG8hgHhvIcB7oCAAe6A'
  'gAHhvJAB4byRAeG8kgHhvJMB4byUAeG8lQHugIAB7oCAAeG8oAHhvKEB4byiAeG8owHhvKQB4bylAeG8pgHhvKcB4bywAeG8sQHhvLIB4byzAeG8'
  'tAHhvLUB4by2AeG8twHugIAB7oCAAeG9gAHhvYEB4b2CAeG9gwHhvYQB4b2FAe6AgAHugIAB7oCAAeG9kQHugIAB4b2TAe6AgAHhvZUB7oCAAeG9'
  'lwHhvaAB4b2hAeG9ogHhvaMB4b2kAeG9pQHhvaYB4b2nAe6AgAHugIAB4byAzrkB4byBzrkB4byCzrkB4byDzrkB4byEzrkB4byFzrkB4byGzrkB'
  '4byHzrkB4byAzrkB4byBzrkB4byCzrkB4byDzrkB4byEzrkB4byFzrkB4byGzrkB4byHzrkB4bygzrkB4byhzrkB4byizrkB4byjzrkB4bykzrkB'
  '4bylzrkB4bymzrkB4bynzrkB4bygzrkB4byhzrkB4byizrkB4byjzrkB4bykzrkB4bylzrkB4bymzrkB4bynzrkB4b2gzrkB4b2hzrkB4b2izrkB'
  '4b2jzrkB4b2kzrkB4b2lzrkB4b2mzrkB4b2nzrkB4b2gzrkB4b2hzrkB4b2izrkB4b2jzrkB4b2kzrkB4b2lzrkB4b2mzrkB4b2nzrkB4b2wzrkB'
  'zrHOuQHOrM65Ae6AgAHhvrbOuQHhvrAB4b6xAeG9sAHOrAHOsc65ASDMkwEgzJMBIM2CASDMiM2CAeG9tM65Ac63zrkBzq7OuQHugIAB4b+GzrkB'
  '4b2yAc6tAeG9tAHOrgHOt865ASDMk8yAASDMk8yBASDMk82CAe6AgAHugIAB4b+QAeG/kQHhvbYBzq8B7oCAASDMlMyAASDMlMyBASDMlM2CAeG/'
  'oAHhv6EB4b26Ac+NAeG/pQEgzIjMgAEgzIjMgQHugIAB7oCAAeG9vM65Ac+JzrkBz47OuQHugIAB4b+2zrkB4b24Ac+MAeG9vAHPjgHPic65ASDM'
  'gQEgzJQB7oCAASABIAEgASABIAEgASABIAEgASABIAEBAQHugIAB7oCAAeKAkAEgzLMBLgEuLgEuLi4B7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB'
  '7oCAASAB4oCy4oCyAeKAsuKAsuKAsgHigLXigLUB4oC14oC14oC1ASEhASDMhQE/PwE/IQEhPwHugIAB7oCAAe6AgAHugIAB4oCy4oCy4oCy4oCy'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAEgAQHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB'
  '7oCAAe6AgAEwAWkB7oCAAe6AgAE0ATUBNgE3ATgBOQErAeKIkgE9ASgBKQFuATABMQEyATMBNAE1ATYBNwE4ATkBKwHiiJIBPQEoASkB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAFycwHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAFhL2MBYS9zAWMBwrBjAWMvbwFjL3UByZsBwrBmAWcBaAFoAWgBaAHEpwFpAWkBbAFsAW4Bbm8BcAFxAXIBcgFyAXNt'
  'AXRlbAF0bQF6Ac+JAXoBawHDpQFiAWMBZQFlAWYBbQFvAdeQAdeRAdeSAdeTAWkB7oCAAe6AgAHOswHOswHPgAHiiJEBZAFkAWUBaQFqAe6AgAHu'
  'gIAB7oCAAe6AgAHugIAB7oCAAe6AgAEx4oGEMwEy4oGEMwEx4oGENQEy4oGENQEz4oGENQE04oGENQEx4oGENgE14oGENgEx4oGEOAEz4oGEOAE1'
  '4oGEOAE34oGEOAEx4oGEAWkBaWkBaWlpAWl2AXYBdmkBdmlpAXZpaWkBaXgBeAF4aQF4aWkBbAFjAWQBbQFpAWlpAWlpaQFpdgF2AXZpAXZpaQF2'
  'aWlpAWl4AXgBeGkBeGlpAWwBYwFkAW0B7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB4oir4oirAeKIq+KI'
  'q+KIqwHiiK7iiK4B4oiu4oiu4oiuAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAExATIBMwE0ATUBNgE3ATgBOQExMAExMQExMgExMwExNAExNQExNgExNwExOAEx'
  'OQEyMAEoMSkBKDIpASgzKQEoNCkBKDUpASg2KQEoNykBKDgpASg5KQEoMTApASgxMSkBKDEyKQEoMTMpASgxNCkBKDE1KQEoMTYpASgxNykBKDE4'
  'KQEoMTkpASgyMCkBMS4BMi4BMy4BNC4BNS4BNi4BNy4BOC4BOS4BMTAuATExLgExMi4BMTMuATE0LgExNS4BMTYuATE3LgExOC4BMTkuATIwLgEo'
  'YSkBKGIpAShjKQEoZCkBKGUpAShmKQEoZykBKGgpAShpKQEoaikBKGspAShsKQEobSkBKG4pAShvKQEocCkBKHEpAShyKQEocykBKHQpASh1KQEo'
  'dikBKHcpASh4KQEoeSkBKHopAWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYBdwF4AXkBegFhAWIBYwFkAWUBZgFn'
  'AWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBMAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB4oir4oir4oir4oirATo6PQE9PQE9PT0B7oCAAeavjQHpvp8B7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB5LiAAeS4qAHkuLYB5Li/AeS5mQHkuoUB5LqMAeS6oAHkuroB5YS/'
  'AeWFpQHlhasB5YaCAeWGlgHlhqsB5YegAeWHtQHliIAB5YqbAeWLuQHljJUB5YyaAeWMuAHljYEB5Y2cAeWNqQHljoIB5Y62AeWPiAHlj6MB5ZuX'
  'AeWcnwHlo6sB5aSCAeWkigHlpJUB5aSnAeWlswHlrZAB5a6AAeWvuAHlsI8B5bCiAeWwuAHlsa4B5bGxAeW3mwHlt6UB5bexAeW3vgHlubIB5bm6'
  'AeW5vwHlu7QB5bu+AeW8iwHlvJMB5b2QAeW9oQHlvbMB5b+DAeaIiAHmiLYB5omLAeaUrwHmlLQB5paHAeaWlwHmlqQB5pa5AeaXoAHml6UB5puw'
  'AeaciAHmnKgB5qygAeatogHmrbkB5q6zAeaviwHmr5QB5q+bAeawjwHmsJQB5rC0AeeBqwHniKoB54i2AeeIuwHniL8B54mHAeeJmQHniZsB54qs'
  'AeeOhAHnjokB55OcAeeTpgHnlJgB55SfAeeUqAHnlLAB55aLAeeWkgHnmbYB55m9AeeargHnmr8B55uuAeefmwHnn6IB55+zAeekugHnprgB56a+'
  'AeeptAHnq4sB56u5AeexswHns7gB57y2Aee9kQHnvooB5769AeiAgQHogIwB6ICSAeiAswHogb8B6IKJAeiHowHoh6oB6IezAeiHvAHoiIwB6Iib'
  'AeiInwHoia4B6ImyAeiJuAHomY0B6JmrAeihgAHooYwB6KGjAeilvgHoposB6KeSAeiogAHosLcB6LGGAeixlQHosbgB6LKdAei1pAHotbAB6Laz'
  'Aei6qwHou4oB6L6bAei+sAHovrUB6YKRAemFiQHph4YB6YeMAemHkQHplbcB6ZaAAemYnAHpmrYB6Zq5AembqAHpnZEB6Z2eAemdogHpnakB6Z+L'
  'AemfrQHpn7MB6aCBAemiqAHpo5sB6aOfAemmlgHpppkB6aasAemqqAHpq5gB6aufAemspQHprK8B6ayyAemsvAHprZoB6bOlAem5tQHpub8B6bql'
  'Aem6uwHpu4MB6buNAem7kQHpu7kB6bu9Aem8jgHpvJMB6bygAem8uwHpvYoB6b2SAem+jQHpvpwB6b6gASAB44CSAeWNgQHljYQB5Y2FAe6AgAHu'
  'gIAB7oCAASDjgpkBIOOCmgHjgojjgooB44Kz44OIAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAeGEgAHhhIEB4YaqAeGEggHh'
  'hqwB4YatAeGEgwHhhIQB4YSFAeGGsAHhhrEB4YayAeGGswHhhrQB4Ya1AeGEmgHhhIYB4YSHAeGEiAHhhKEB4YSJAeGEigHhhIsB4YSMAeGEjQHh'
  'hI4B4YSPAeGEkAHhhJEB4YSSAeGFoQHhhaIB4YWjAeGFpAHhhaUB4YWmAeGFpwHhhagB4YWpAeGFqgHhhasB4YWsAeGFrQHhha4B4YWvAeGFsAHh'
  'hbEB4YWyAeGFswHhhbQB4YW1AeGFoAHhhJQB4YSVAeGHhwHhh4gB4YeMAeGHjgHhh5MB4YeXAeGHmQHhhJwB4YedAeGHnwHhhJ0B4YSeAeGEoAHh'
  'hKIB4YSjAeGEpwHhhKkB4YSrAeGErAHhhK0B4YSuAeGErwHhhLIB4YS2AeGFgAHhhYcB4YWMAeGHsQHhh7IB4YWXAeGFmAHhhZkB4YaEAeGGhQHh'
  'hogB4YaRAeGGkgHhhpQB4YaeAeGGoQHugIAB5LiAAeS6jAHkuIkB5ZubAeS4igHkuK0B5LiLAeeUsgHkuZkB5LiZAeS4gQHlpKkB5ZywAeS6ugEo'
  '4YSAKQEo4YSCKQEo4YSDKQEo4YSFKQEo4YSGKQEo4YSHKQEo4YSJKQEo4YSLKQEo4YSMKQEo4YSOKQEo4YSPKQEo4YSQKQEo4YSRKQEo4YSSKQEo'
  '6rCAKQEo64KYKQEo64ukKQEo6528KQEo66eIKQEo67CUKQEo7IKsKQEo7JWEKQEo7J6QKQEo7LCoKQEo7Lm0KQEo7YOAKQEo7YyMKQEo7ZWYKQEo'
  '7KO8KQHugIAB7oCAAe6AgAEo5LiAKQEo5LqMKQEo5LiJKQEo5ZubKQEo5LqUKQEo5YWtKQEo5LiDKQEo5YWrKQEo5LmdKQEo5Y2BKQEo5pyIKQEo'
  '54GrKQEo5rC0KQEo5pyoKQEo6YeRKQEo5ZyfKQEo5pelKQEo5qCqKQEo5pyJKQEo56S+KQEo5ZCNKQEo54m5KQEo6LKhKQEo56WdKQEo5Yq0KQEo'
  '5LujKQEo5ZG8KQEo5a2mKQEo55ujKQEo5LyBKQEo6LOHKQEo5Y2UKQEo56WtKQEo5LyRKQEo6IeqKQEo6IezKQHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIABMjEBMjIBMjMBMjQBMjUBMjYBMjcBMjgBMjkBMzABMzEBMzIBMzMBMzQBMzUB4YSAAeGE'
  'ggHhhIMB4YSFAeGEhgHhhIcB4YSJAeGEiwHhhIwB4YSOAeGEjwHhhJAB4YSRAeGEkgHqsIAB64KYAeuLpAHrnbwB66eIAeuwlAHsgqwB7JWEAeye'
  'kAHssKgB7Lm0Ae2DgAHtjIwB7ZWYAe6AgAHugIAB7oCAAeS4gAHkuowB5LiJAeWbmwHkupQB5YWtAeS4gwHlhasB5LmdAeWNgQHmnIgB54GrAeaw'
  'tAHmnKgB6YeRAeWcnwHml6UB5qCqAeaciQHnpL4B5ZCNAeeJuQHosqEB56WdAeWKtAHnp5gB55S3AeWlswHpgakB5YSqAeWNsAHms6gB6aCFAeS8'
  'kQHlhpkB5q2jAeS4igHkuK0B5LiLAeW3pgHlj7MB5Yy7AeWulwHlraYB55ujAeS8gQHos4cB5Y2UAeWknAEzNgEzNwEzOAEzOQE0MAE0MQE0MgE0'
  'MwE0NAE0NQE0NgE0NwE0OAE0OQE1MAEx5pyIATLmnIgBM+aciAE05pyIATXmnIgBNuaciAE35pyIATjmnIgBOeaciAExMOaciAExMeaciAExMuac'
  'iAHugIAB7oCAAe6AgAHugIAB44KiAeOCpAHjgqYB44KoAeOCqgHjgqsB44KtAeOCrwHjgrEB44KzAeOCtQHjgrcB44K5AeOCuwHjgr0B44K/AeOD'
  'gQHjg4QB44OGAeODiAHjg4oB44OLAeODjAHjg40B44OOAeODjwHjg5IB44OVAeODmAHjg5sB44OeAeODnwHjg6AB44OhAeODogHjg6QB44OmAeOD'
  'qAHjg6kB44OqAeODqwHjg6wB44OtAeODrwHjg7AB44OxAeODsgHugIAB44Ki44OR44O844OIAeOCouODq+ODleOCoQHjgqLjg7Pjg5rjgqIB44Ki'
  '44O844OrAeOCpOODi+ODs+OCsAHjgqTjg7Pjg4EB44Km44Kp44OzAeOCqOOCueOCr+ODvOODiQHjgqjjg7zjgqvjg7wB44Kq44Oz44K5AeOCquOD'
  'vOODoAHjgqvjgqTjg6oB44Kr44Op44OD44OIAeOCq+ODreODquODvAHjgqzjg63jg7MB44Ks44Oz44OeAeOCruOCrAHjgq7jg4vjg7wB44Kt44Ol'
  '44Oq44O8AeOCruODq+ODgOODvAHjgq3jg60B44Kt44Ot44Kw44Op44OgAeOCreODreODoeODvOODiOODqwHjgq3jg63jg6/jg4Pjg4gB44Kw44Op'
  '44OgAeOCsOODqeODoOODiOODswHjgq/jg6vjgrzjgqTjg60B44Kv44Ot44O844ONAeOCseODvOOCuQHjgrPjg6vjg4oB44Kz44O844OdAeOCteOC'
  'pOOCr+ODqwHjgrXjg7Pjg4Hjg7zjg6AB44K344Oq44Oz44KwAeOCu+ODs+ODgQHjgrvjg7Pjg4gB44OA44O844K5AeODh+OCtwHjg4njg6sB44OI'
  '44OzAeODiuODjgHjg47jg4Pjg4gB44OP44Kk44OEAeODkeODvOOCu+ODs+ODiAHjg5Hjg7zjg4QB44OQ44O844Os44OrAeODlOOCouOCueODiOOD'
  'qwHjg5Tjgq/jg6sB44OU44KzAeODk+ODqwHjg5XjgqHjg6njg4Pjg4kB44OV44Kj44O844OIAeODluODg+OCt+OCp+ODqwHjg5Xjg6njg7MB44OY'
  '44Kv44K/44O844OrAeODmuOCvQHjg5rjg4vjg5IB44OY44Or44OEAeODmuODs+OCuQHjg5rjg7zjgrgB44OZ44O844K/AeODneOCpOODs+ODiAHj'
  'g5zjg6vjg4gB44Ob44OzAeODneODs+ODiQHjg5vjg7zjg6sB44Ob44O844OzAeODnuOCpOOCr+ODrQHjg57jgqTjg6sB44Oe44OD44OPAeODnuOD'
  'q+OCrwHjg57jg7Pjgrfjg6fjg7MB44Of44Kv44Ot44OzAeODn+ODqgHjg5/jg6rjg5Djg7zjg6sB44Oh44KsAeODoeOCrOODiOODswHjg6Hjg7zj'
  'g4jjg6sB44Ok44O844OJAeODpOODvOODqwHjg6bjgqLjg7MB44Oq44OD44OI44OrAeODquODqQHjg6vjg5Tjg7wB44Or44O844OW44OrAeODrOOD'
  'oAHjg6zjg7Pjg4jjgrLjg7MB44Ov44OD44OIATDngrkBMeeCuQEy54K5ATPngrkBNOeCuQE154K5ATbngrkBN+eCuQE454K5ATnngrkBMTDngrkB'
  'MTHngrkBMTLngrkBMTPngrkBMTTngrkBMTXngrkBMTbngrkBMTfngrkBMTjngrkBMTnngrkBMjDngrkBMjHngrkBMjLngrkBMjPngrkBMjTngrkB'
  'aHBhAWRhAWF1AWJhcgFvdgFwYwHugIAB7oCAAe6AgAHugIAB5bmz5oiQAeaYreWSjAHlpKfmraMB5piO5rK7AeagquW8j+S8muekvgFwYQFuYQHO'
  'vGEBbWEBa2EBa2IBbWIBZ2IBY2FsAWtjYWwBcGYBbmYBzrxmAc68ZwFtZwFrZwFoegFraHoBbWh6AWdoegF0aHoBzrxsAW1sAWRsAWtsAWZtAW5t'
  'Ac68bQFtbQFjbQFrbQFtbTIBY20yAW0yAWttMgFtbTMBY20zAW0zAWttMwFt4oiVcwFt4oiVczIBcGEBa3BhAW1wYQFncGEBcmFkAXJhZOKIlXMB'
  'cmFk4oiVczIBcHMBbnMBzrxzAW1zAXB2AW52Ac68dgFtdgFrdgFtdgFwdwFudwHOvHcBbXcBa3cBbXcBa8+JAW3PiQFhLm0uAWJxAWNjAWNkAWPi'
  'iJVrZwFjby4BZGIBZ3kBaGEBaHABaW4Ba2sBa20Ba3QBbG0BbG4BbG9nAWx4AW1iAW1pbAFtb2wBcGgBcC5tLgFwcG0BcHIBc3IBc3YBd2IB7oCA'
  'Ae6AgAEx5pelATLml6UBM+aXpQE05pelATXml6UBNuaXpQE35pelATjml6UBOeaXpQExMOaXpQExMeaXpQExMuaXpQExM+aXpQExNOaXpQExNeaX'
  'pQExNuaXpQExN+aXpQExOOaXpQExOeaXpQEyMOaXpQEyMeaXpQEyMuaXpQEyM+aXpQEyNOaXpQEyNeaXpQEyNuaXpQEyN+aXpQEyOOaXpQEyOeaX'
  'pQEzMOaXpQEzMeaXpQHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAFmZgFmaQFmbAFmZmkBZmZsAXN0AXN0Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCA'
  'Ae6AgAHugIAB7oCAAe6AgAHugIAB7oCAAdW01bYB1bTVpQHVtNWrAdW+1bYB1bTVrQHugIAB7oCAAe6AgAHugIAB7oCAAdeiAdeQAdeTAdeUAdeb'
  'AdecAdedAdeoAdeqASsB7oCAAe6AgAHugIAB7oCAAe6AgAHXkNecAdmxAdmxAdm7Adm7Adm7Adm7Adm+Adm+Adm+Adm+AdqAAdqAAdqAAdqAAdm6'
  'Adm6Adm6Adm6Adm/Adm/Adm/Adm/Adm5Adm5Adm5Adm5AdqkAdqkAdqkAdqkAdqmAdqmAdqmAdqmAdqEAdqEAdqEAdqEAdqDAdqDAdqDAdqDAdqG'
  'AdqGAdqGAdqGAdqHAdqHAdqHAdqHAdqNAdqNAdqMAdqMAdqOAdqOAdqIAdqIAdqYAdqYAdqRAdqRAdqpAdqpAdqpAdqpAdqvAdqvAdqvAdqvAdqz'
  'AdqzAdqzAdqzAdqxAdqxAdqxAdqxAdq6Adq6Adq7Adq7Adq7Adq7AduAAduAAduBAduBAduBAduBAdq+Adq+Adq+Adq+AduSAduSAduTAduTAdqt'
  'AdqtAdqtAdqtAduHAduHAduGAduGAduIAduIAduH2bQB24sB24sB24UB24UB24kB24kB25AB25AB25AB25AB2YkB2YkB2KbYpwHYptinAdim25UB'
  '2KbblQHYptmIAdim2YgB2KbbhwHYptuHAdim24YB2KbbhgHYptuIAdim24gB2KbbkAHYptuQAdim25AB2KbZiQHYptmJAdim2YkB24wB24wB24wB'
  '24wB2KbYrAHYptitAdim2YUB2KbZiQHYptmKAdio2KwB2KjYrQHYqNiuAdio2YUB2KjZiQHYqNmKAdiq2KwB2KrYrQHYqtiuAdiq2YUB2KrZiQHY'
  'qtmKAdir2KwB2KvZhQHYq9mJAdir2YoB2KzYrQHYrNmFAdit2KwB2K3ZhQHYrtisAdiu2K0B2K7ZhQHYs9isAdiz2K0B2LPYrgHYs9mFAdi12K0B'
  '2LXZhQHYttisAdi22K0B2LbYrgHYttmFAdi32K0B2LfZhQHYuNmFAdi52KwB2LnZhQHYutisAdi62YUB2YHYrAHZgditAdmB2K4B2YHZhQHZgdmJ'
  'AdmB2YoB2YLYrQHZgtmFAdmC2YkB2YLZigHZg9inAdmD2KwB2YPYrQHZg9iuAdmD2YQB2YPZhQHZg9mJAdmD2YoB2YTYrAHZhNitAdmE2K4B2YTZ'
  'hQHZhNmJAdmE2YoB2YXYrAHZhditAdmF2K4B2YXZhQHZhdmJAdmF2YoB2YbYrAHZhtitAdmG2K4B2YbZhQHZhtmJAdmG2YoB2YfYrAHZh9mFAdmH'
  '2YkB2YfZigHZitisAdmK2K0B2YrYrgHZitmFAdmK2YkB2YrZigHYsNmwAdix2bAB2YnZsAEg2YzZkQEg2Y3ZkQEg2Y7ZkQEg2Y/ZkQEg2ZDZkQEg'
  '2ZHZsAHYptixAdim2LIB2KbZhQHYptmGAdim2YkB2KbZigHYqNixAdio2LIB2KjZhQHYqNmGAdio2YkB2KjZigHYqtixAdiq2LIB2KrZhQHYqtmG'
  'Adiq2YkB2KrZigHYq9ixAdir2LIB2KvZhQHYq9mGAdir2YkB2KvZigHZgdmJAdmB2YoB2YLZiQHZgtmKAdmD2KcB2YPZhAHZg9mFAdmD2YkB2YPZ'
  'igHZhNmFAdmE2YkB2YTZigHZhdinAdmF2YUB2YbYsQHZhtiyAdmG2YUB2YbZhgHZhtmJAdmG2YoB2YnZsAHZitixAdmK2LIB2YrZhQHZitmGAdmK'
  '2YkB2YrZigHYptisAdim2K0B2KbYrgHYptmFAdim2YcB2KjYrAHYqNitAdio2K4B2KjZhQHYqNmHAdiq2KwB2KrYrQHYqtiuAdiq2YUB2KrZhwHY'
  'q9mFAdis2K0B2KzZhQHYrdisAdit2YUB2K7YrAHYrtmFAdiz2KwB2LPYrQHYs9iuAdiz2YUB2LXYrQHYtdiuAdi12YUB2LbYrAHYttitAdi22K4B'
  '2LbZhQHYt9itAdi42YUB2LnYrAHYudmFAdi62KwB2LrZhQHZgdisAdmB2K0B2YHYrgHZgdmFAdmC2K0B2YLZhQHZg9isAdmD2K0B2YPYrgHZg9mE'
  'AdmD2YUB2YTYrAHZhNitAdmE2K4B2YTZhQHZhNmHAdmF2KwB2YXYrQHZhdiuAdmF2YUB2YbYrAHZhtitAdmG2K4B2YbZhQHZhtmHAdmH2KwB2YfZ'
  'hQHZh9mwAdmK2KwB2YrYrQHZitiuAdmK2YUB2YrZhwHYptmFAdim2YcB2KjZhQHYqNmHAdiq2YUB2KrZhwHYq9mFAdir2YcB2LPZhQHYs9mHAdi0'
  '2YUB2LTZhwHZg9mEAdmD2YUB2YTZhQHZhtmFAdmG2YcB2YrZhQHZitmHAdmA2Y7ZkQHZgNmP2ZEB2YDZkNmRAdi32YkB2LfZigHYudmJAdi52YoB'
  '2LrZiQHYutmKAdiz2YkB2LPZigHYtNmJAdi02YoB2K3ZiQHYrdmKAdis2YkB2KzZigHYrtmJAdiu2YoB2LXZiQHYtdmKAdi22YkB2LbZigHYtNis'
  'Adi02K0B2LTYrgHYtNmFAdi02LEB2LPYsQHYtdixAdi22LEB2LfZiQHYt9mKAdi52YkB2LnZigHYutmJAdi62YoB2LPZiQHYs9mKAdi02YkB2LTZ'
  'igHYrdmJAdit2YoB2KzZiQHYrNmKAdiu2YkB2K7ZigHYtdmJAdi12YoB2LbZiQHYttmKAdi02KwB2LTYrQHYtNiuAdi02YUB2LTYsQHYs9ixAdi1'
  '2LEB2LbYsQHYtNisAdi02K0B2LTYrgHYtNmFAdiz2YcB2LTZhwHYt9mFAdiz2KwB2LPYrQHYs9iuAdi02KwB2LTYrQHYtNiuAdi32YUB2LjZhQHY'
  'p9mLAdin2YsB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAdiq2KzZhQHYqtit'
  '2KwB2KrYrdisAdiq2K3ZhQHYqtiu2YUB2KrZhdisAdiq2YXYrQHYqtmF2K4B2KzZhditAdis2YXYrQHYrdmF2YoB2K3ZhdmJAdiz2K3YrAHYs9is'
  '2K0B2LPYrNmJAdiz2YXYrQHYs9mF2K0B2LPZhdisAdiz2YXZhQHYs9mF2YUB2LXYrditAdi12K3YrQHYtdmF2YUB2LTYrdmFAdi02K3ZhQHYtNis'
  '2YoB2LTZhdiuAdi02YXYrgHYtNmF2YUB2LTZhdmFAdi22K3ZiQHYttiu2YUB2LbYrtmFAdi32YXYrQHYt9mF2K0B2LfZhdmFAdi32YXZigHYudis'
  '2YUB2LnZhdmFAdi52YXZhQHYudmF2YkB2LrZhdmFAdi62YXZigHYutmF2YkB2YHYrtmFAdmB2K7ZhQHZgtmF2K0B2YLZhdmFAdmE2K3ZhQHZhNit'
  '2YoB2YTYrdmJAdmE2KzYrAHZhNis2KwB2YTYrtmFAdmE2K7ZhQHZhNmF2K0B2YTZhditAdmF2K3YrAHZhdit2YUB2YXYrdmKAdmF2KzYrQHZhdis'
  '2YUB2YXYrtisAdmF2K7ZhQHugIAB7oCAAdmF2KzYrgHZh9mF2KwB2YfZhdmFAdmG2K3ZhQHZhtit2YkB2YbYrNmFAdmG2KzZhQHZhtis2YkB2YbZ'
  'hdmKAdmG2YXZiQHZitmF2YUB2YrZhdmFAdio2K7ZigHYqtis2YoB2KrYrNmJAdiq2K7ZigHYqtiu2YkB2KrZhdmKAdiq2YXZiQHYrNmF2YoB2KzY'
  'rdmJAdis2YXZiQHYs9iu2YkB2LXYrdmKAdi02K3ZigHYttit2YoB2YTYrNmKAdmE2YXZigHZitit2YoB2YrYrNmKAdmK2YXZigHZhdmF2YoB2YLZ'
  'hdmKAdmG2K3ZigHZgtmF2K0B2YTYrdmFAdi52YXZigHZg9mF2YoB2YbYrNitAdmF2K7ZigHZhNis2YUB2YPZhdmFAdmE2KzZhQHZhtis2K0B2KzY'
  'rdmKAdit2KzZigHZhdis2YoB2YHZhdmKAdio2K3ZigHZg9mF2YUB2LnYrNmFAdi12YXZhQHYs9iu2YoB2YbYrNmKAdi12YTbkgHZgtmE25IB2KfZ'
  'hNmE2YcB2KfZg9io2LEB2YXYrdmF2K8B2LXZhNi52YUB2LHYs9mI2YQB2LnZhNmK2YcB2YjYs9mE2YUB2LXZhNmJAdi12YTZiSDYp9mE2YTZhyDY'
  'udmE2YrZhyDZiNiz2YTZhQHYrNmEINis2YTYp9mE2YcB2LHbjNin2YQB7oCAAe6AgAHugIABAQEBAQEBAQEBAQEBAQEBAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAEuLgHigJQB4oCTAV8BXwEoASkBewF9AeOAlAHjgJUB44CQAeOAkQHjgIoB44CLAeOAiAHjgIkB44CMAeOAjQHjgI4B44CP'
  'Ae6AgAHugIABIMyFASDMhQEgzIUBIMyFAV8BXwFfASwB44CBAS4B7oCAATsBOgE/ASEB4oCUASgBKQF7AX0B44CUAeOAlQEjASYBKgErAS0BPAE+'
  'AT0B7oCAAVwBJAElAUAB7oCAAe6AgAHugIAB7oCAASDZiwHZgNmLASDZjAEg2Y0B7oCAASDZjgHZgNmOASDZjwHZgNmPASDZkAHZgNmQASDZkQHZ'
  'gNmRASDZkgHZgNmSAdihAdiiAdiiAdijAdijAdikAdikAdilAdilAdimAdimAdimAdimAdinAdinAdioAdioAdioAdioAdipAdipAdiqAdiqAdiq'
  'AdiqAdirAdirAdirAdirAdisAdisAdisAdisAditAditAditAditAdiuAdiuAdiuAdiuAdivAdivAdiwAdiwAdixAdixAdiyAdiyAdizAdizAdiz'
  'AdizAdi0Adi0Adi0Adi0Adi1Adi1Adi1Adi1Adi2Adi2Adi2Adi2Adi3Adi3Adi3Adi3Adi4Adi4Adi4Adi4Adi5Adi5Adi5Adi5Adi6Adi6Adi6'
  'Adi6AdmBAdmBAdmBAdmBAdmCAdmCAdmCAdmCAdmDAdmDAdmDAdmDAdmEAdmEAdmEAdmEAdmFAdmFAdmFAdmFAdmGAdmGAdmGAdmGAdmHAdmHAdmH'
  'AdmHAdmIAdmIAdmJAdmJAdmKAdmKAdmKAdmKAdmE2KIB2YTYogHZhNijAdmE2KMB2YTYpQHZhNilAdmE2KcB2YTYpwHugIAB7oCAAQHugIABIQEi'
  'ASMBJAElASYBJwEoASkBKgErASwBLQEuAS8BMAExATIBMwE0ATUBNgE3ATgBOQE6ATsBPAE9AT4BPwFAAWEBYgFjAWQBZQFmAWcBaAFpAWoBawFs'
  'AW0BbgFvAXABcQFyAXMBdAF1AXYBdwF4AXkBegFbAVwBXQFeAV8BYAFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2'
  'AXcBeAF5AXoBewF8AX0BfgHipoUB4qaGAeOAggHjgIwB44CNAeOAgQHjg7sB44OyAeOCoQHjgqMB44KlAeOCpwHjgqkB44OjAeODpQHjg6cB44OD'
  'AeODvAHjgqIB44KkAeOCpgHjgqgB44KqAeOCqwHjgq0B44KvAeOCsQHjgrMB44K1AeOCtwHjgrkB44K7AeOCvQHjgr8B44OBAeODhAHjg4YB44OI'
  'AeODigHjg4sB44OMAeODjQHjg44B44OPAeODkgHjg5UB44OYAeODmwHjg54B44OfAeODoAHjg6EB44OiAeODpAHjg6YB44OoAeODqQHjg6oB44Or'
  'AeODrAHjg60B44OvAeODswHjgpkB44KaAeGFoAHhhIAB4YSBAeGGqgHhhIIB4YasAeGGrQHhhIMB4YSEAeGEhQHhhrAB4YaxAeGGsgHhhrMB4Ya0'
  'AeGGtQHhhJoB4YSGAeGEhwHhhIgB4YShAeGEiQHhhIoB4YSLAeGEjAHhhI0B4YSOAeGEjwHhhJAB4YSRAeGEkgHugIAB7oCAAe6AgAHhhaEB4YWi'
  'AeGFowHhhaQB4YWlAeGFpgHugIAB7oCAAeGFpwHhhagB4YWpAeGFqgHhhasB4YWsAe6AgAHugIAB4YWtAeGFrgHhha8B4YWwAeGFsQHhhbIB7oCA'
  'Ae6AgAHhhbMB4YW0AeGFtQHugIAB7oCAAe6AgAHCogHCowHCrAEgzIQBwqYBwqUB4oKpAe6AgAHilIIB4oaQAeKGkQHihpIB4oaTAeKWoAHil4sB'
  '7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAfCQkKgB8JCQqQHwkJCqAfCQkKsB8JCQrAHwkJCtAfCQ'
  'kK4B8JCQrwHwkJCwAfCQkLEB8JCQsgHwkJCzAfCQkLQB8JCQtQHwkJC2AfCQkLcB8JCQuAHwkJC5AfCQkLoB8JCQuwHwkJC8AfCQkL0B8JCQvgHw'
  'kJC/AfCQkYAB8JCRgQHwkJGCAfCQkYMB8JCRhAHwkJGFAfCQkYYB8JCRhwHwkJGIAfCQkYkB8JCRigHwkJGLAfCQkYwB8JCRjQHugIAB7oCAAe6A'
  'gAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAe6AgAHugIAB7oCAAWEB'
  'YgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYBdwF4AXkBegFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEB'
  'cgFzAXQBdQF2AXcBeAF5AXoBYQFiAWMBZAFlAWYBZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6AWEBYgFjAWQBZQFmAWcB'
  '7oCAAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6AWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYB'
  'dwF4AXkBegFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBYQHugIABYwFkAe6AgAHugIABZwHugIAB'
  '7oCAAWoBawHugIAB7oCAAW4BbwFwAXEB7oCAAXMBdAF1AXYBdwF4AXkBegFhAWIBYwFkAe6AgAFmAe6AgAFoAWkBagFrAe6AgAFtAW4B7oCAAXAB'
  'cQFyAXMBdAF1AXYBdwF4AXkBegFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBYQFiAWMBZAFlAWYB'
  'ZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6AWEBYgHugIABZAFlAWYBZwHugIAB7oCAAWoBawFsAW0BbgFvAXABcQHugIAB'
  'cwF0AXUBdgF3AXgBeQHugIABYQFiAWMBZAFlAWYBZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6AWEBYgHugIABZAFlAWYB'
  'ZwHugIABaQFqAWsBbAFtAe6AgAFvAe6AgAHugIAB7oCAAXMBdAF1AXYBdwF4AXkB7oCAAWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXAB'
  'cQFyAXMBdAF1AXYBdwF4AXkBegFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBYQFiAWMBZAFlAWYB'
  'ZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6AWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYB'
  'dwF4AXkBegFhAWIBYwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBYQFiAWMBZAFlAWYBZwFoAWkBagFrAWwB'
  'bQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgBeQF6AWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYBdwF4AXkBegFhAWIB'
  'YwFkAWUBZgFnAWgBaQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBYQFiAWMBZAFlAWYBZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIB'
  'cwF0AXUBdgF3AXgBeQF6AWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYBdwF4AXkBegFhAWIBYwFkAWUBZgFnAWgB'
  'aQFqAWsBbAFtAW4BbwFwAXEBcgFzAXQBdQF2AXcBeAF5AXoBYQFiAWMBZAFlAWYBZwFoAWkBagFrAWwBbQFuAW8BcAFxAXIBcwF0AXUBdgF3AXgB'
  'eQF6AWEBYgFjAWQBZQFmAWcBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1AXYBdwF4AXkBegHugIAB7oCAAe6AgAHugIABzrEBzrIBzrMBzrQB'
  'zrUBzrYBzrcBzrgBzrkBzroBzrsBzrwBzr0Bzr4Bzr8Bz4ABz4EBzrgBz4MBz4QBz4UBz4YBz4cBz4gBz4kB4oiHAc6xAc6yAc6zAc60Ac61Ac62'
  'Ac63Ac64Ac65Ac66Ac67Ac68Ac69Ac6+Ac6/Ac+AAc+BAc+DAc+DAc+EAc+FAc+GAc+HAc+IAc+JAeKIggHOtQHOuAHOugHPhgHPgQHPgAHOsQHO'
  'sgHOswHOtAHOtQHOtgHOtwHOuAHOuQHOugHOuwHOvAHOvQHOvgHOvwHPgAHPgQHOuAHPgwHPhAHPhQHPhgHPhwHPiAHPiQHiiIcBzrEBzrIBzrMB'
  'zrQBzrUBzrYBzrcBzrgBzrkBzroBzrsBzrwBzr0Bzr4Bzr8Bz4ABz4EBz4MBz4MBz4QBz4UBz4YBz4cBz4gBz4kB4oiCAc61Ac64Ac66Ac+GAc+B'
  'Ac+AAc6xAc6yAc6zAc60Ac61Ac62Ac63Ac64Ac65Ac66Ac67Ac68Ac69Ac6+Ac6/Ac+AAc+BAc64Ac+DAc+EAc+FAc+GAc+HAc+IAc+JAeKIhwHO'
  'sQHOsgHOswHOtAHOtQHOtgHOtwHOuAHOuQHOugHOuwHOvAHOvQHOvgHOvwHPgAHPgQHPgwHPgwHPhAHPhQHPhgHPhwHPiAHPiQHiiIIBzrUBzrgB'
  'zroBz4YBz4EBz4ABzrEBzrIBzrMBzrQBzrUBzrYBzrcBzrgBzrkBzroBzrsBzrwBzr0Bzr4Bzr8Bz4ABz4EBzrgBz4MBz4QBz4UBz4YBz4cBz4gB'
  'z4kB4oiHAc6xAc6yAc6zAc60Ac61Ac62Ac63Ac64Ac65Ac66Ac67Ac68Ac69Ac6+Ac6/Ac+AAc+BAc+DAc+DAc+EAc+FAc+GAc+HAc+IAc+JAeKI'
  'ggHOtQHOuAHOugHPhgHPgQHPgAHOsQHOsgHOswHOtAHOtQHOtgHOtwHOuAHOuQHOugHOuwHOvAHOvQHOvgHOvwHPgAHPgQHOuAHPgwHPhAHPhQHP'
  'hgHPhwHPiAHPiQHiiIcBzrEBzrIBzrMBzrQBzrUBzrYBzrcBzrgBzrkBzroBzrsBzrwBzr0Bzr4Bzr8Bz4ABz4EBz4MBz4MBz4QBz4UBz4YBz4cB'
  'z4gBz4kB4oiCAc61Ac64Ac66Ac+GAc+BAc+AAe6AgAHugIAB7oCAAe6AgAEwATEBMgEzATQBNQE2ATcBOAE5ATABMQEyATMBNAE1ATYBNwE4ATkB'
  'MAExATIBMwE0ATUBNgE3ATgBOQEwATEBMgEzATQBNQE2ATcBOAE5ATABMQEyATMBNAE1ATYBNwE4ATkB8KGNqgHlvLMB5I6rAeeqrgHktZc='
)));
CREATE OR REPLACE MACRO gtfs_vc_idn_refused_re() AS (
  '[\x{80}-\x{9F}\x{510}-\x{530}\x{74B}-\x{77F}\x{7B2}-\x{900}\x{E5C}-\x{E80}\x{EDE}-\x{EFF}\x{FD0}-\x{FFF}'
  '\x{105A}-\x{109F}\x{137D}-\x{139F}\x{18AA}-\x{1DFF}\x{23CF}-\x{23FF}\x{268A}-\x{2700}\x{2B00}-\x{2E7F}'
  '\x{2FD6}-\x{2FFF}\x{31B8}-\x{31EF}\x{4DB6}-\x{4DFF}\x{9FA6}-\x{9FFF}\x{A4C7}-\x{ABFF}\x{D7A4}-\x{F8FF}'
  '\x{FA6B}-\x{FAFF}\x{FBB2}-\x{FBD2}\x{FDC8}-\x{FDEF}\x{FFEF}-\x{102FF}\x{1034B}-\x{103FF}\x{1044E}-\x{1CFFF}'
  '\x{1D1DE}-\x{1D3FF}\x{1D800}-\x{1FFFF}\x{2A6D7}-\x{2F7FF}\x{2FA1E}-\x{10FFFF}]'
);
-- Prepared code points of bidi class R or AL, and of class L (jdk.internal.icu UCharacter.getDirection).
CREATE OR REPLACE MACRO gtfs_vc_idn_r_re() AS (
  '[\x{5BE}\x{5C0}\x{5C3}\x{5D0}-\x{5F4}\x{61B}-\x{64A}\x{66D}-\x{66F}\x{671}-\x{6D5}\x{6E5}-\x{6E6}\x{6FA}-\x{710}'
  '\x{712}-\x{72C}\x{780}-\x{7A5}\x{7B1}\x{FB1D}\x{FB1F}-\x{FB28}\x{FB2A}-\x{FD3D}\x{FD50}-\x{FDFC}\x{FE70}-\x{FEFC}]'
);
CREATE OR REPLACE MACRO gtfs_vc_idn_l_re() AS (
  '[\x{41}-\x{5A}\x{61}-\x{7A}\x{AA}\x{B5}\x{BA}\x{C0}-\x{D6}\x{D8}-\x{F6}\x{F8}-\x{2B8}\x{2BB}-\x{2C1}'
  '\x{2D0}-\x{2D1}\x{2E0}-\x{2E4}\x{2EE}\x{37A}\x{386}\x{388}-\x{3F5}\x{400}-\x{482}\x{48A}-\x{589}\x{903}-\x{939}'
  '\x{93D}-\x{940}\x{949}-\x{94C}\x{950}\x{958}-\x{961}\x{964}-\x{970}\x{982}-\x{9B9}\x{9BE}-\x{9C0}\x{9C7}-\x{9CC}'
  '\x{9D7}-\x{9E1}\x{9E6}-\x{9F1}\x{9F4}-\x{9FA}\x{A05}-\x{A39}\x{A3E}-\x{A40}\x{A59}-\x{A6F}\x{A72}-\x{A74}'
  '\x{A83}-\x{AB9}\x{ABD}-\x{AC0}\x{AC9}-\x{ACC}\x{AD0}-\x{AEF}\x{B02}-\x{B39}\x{B3D}-\x{B3E}\x{B40}\x{B47}-\x{B4C}'
  '\x{B57}-\x{B70}\x{B83}-\x{BBF}\x{BC1}-\x{BCC}\x{BD7}-\x{C39}\x{C41}-\x{C44}\x{C60}-\x{CCB}\x{CD5}-\x{D40}'
  '\x{D46}-\x{D4C}\x{D57}-\x{DC6}\x{DCF}-\x{DD1}\x{DD8}-\x{E30}\x{E32}-\x{E33}\x{E40}-\x{E46}\x{E4F}-\x{EB0}'
  '\x{EB2}-\x{EB3}\x{EBD}-\x{EC6}\x{ED0}-\x{F17}\x{F1A}-\x{F34}\x{F36}\x{F38}\x{F3E}-\x{F6A}\x{F7F}\x{F85}'
  '\x{F88}-\x{F8B}\x{FBE}-\x{FC5}\x{FC7}-\x{102C}\x{1031}\x{1038}\x{1040}-\x{1057}\x{10A0}-\x{169A}\x{16A0}-\x{1711}'
  '\x{1720}-\x{1731}\x{1735}-\x{1751}\x{1760}-\x{1770}\x{1780}-\x{17B3}\x{17B6}\x{17BE}-\x{17C5}\x{17C7}-\x{17C8}'
  '\x{17D4}-\x{17DA}\x{17DC}-\x{17E9}\x{1810}-\x{1884}\x{1887}-\x{18A8}\x{1E00}-\x{1FBC}\x{1FBE}\x{1FC2}-\x{1FCC}'
  '\x{1FD0}-\x{1FDB}\x{1FE0}-\x{1FEC}\x{1FF2}-\x{1FFC}\x{2071}\x{207F}\x{2102}\x{2107}\x{210A}-\x{2113}\x{2115}'
  '\x{2119}-\x{211D}\x{2124}\x{2126}\x{2128}\x{212A}-\x{212D}\x{212F}-\x{2139}\x{213D}-\x{213F}\x{2145}-\x{2149}'
  '\x{2160}-\x{2183}\x{2336}-\x{237A}\x{2395}\x{249C}-\x{24E9}\x{2800}-\x{28FF}\x{3005}-\x{3007}\x{3021}-\x{3029}'
  '\x{302E}-\x{302F}\x{3031}-\x{3035}\x{3038}-\x{303C}\x{3041}-\x{3096}\x{309D}-\x{309F}\x{30A1}-\x{30FA}'
  '\x{30FC}-\x{3243}\x{3260}-\x{32B0}\x{32C0}-\x{A48C}\x{AC00}-\x{FB17}\x{FF21}-\x{FF3A}\x{FF41}-\x{FF5A}'
  '\x{FF66}-\x{FFDC}\x{10300}-\x{1D166}\x{1D16A}-\x{1D172}\x{1D183}-\x{1D184}\x{1D18C}-\x{1D1A9}\x{1D1AE}-\x{1D6DA}'
  '\x{1D6DC}-\x{1D714}\x{1D716}-\x{1D74E}\x{1D750}-\x{1D788}\x{1D78A}-\x{1D7C2}\x{1D7C4}-\x{1D7C9}'
  '\x{20000}-\x{2FA1D}]'
);
-- END GENERATED
-- java.net.IDN.toASCII(input, 0) of Java 17 (RFC 3490 with RFC 3491 nameprep and RFC 3492 Punycode), NULL where it
-- throws. DuckDB 2.0 binds every lambda body more than once, so the cost of binding grows fast with lambda depth:
-- the steps below are chained through macro arguments (list_transform([x], lambda v: ...)[1] binds x once without
-- nesting the next step inside it) and keep their lambdas shallow.
-- Punycode digit d (0..35) as a lowercase letter or a digit.
CREATE OR REPLACE MACRO gtfs_vc_idn_digit(d) AS (chr((CASE WHEN d < 26 THEN 97 + d ELSE 22 + d END)::INTEGER));
-- Punycode adapt(delta, numpoints, first) from e1 = e0 + e0 / numpoints, e0 = delta / 700 (first) or delta / 2
-- (gtfs_vc_idn_e1): the number t of divisions by 35 is the number of thresholds 456 * 35^j that e1 reaches, and the
-- bias is 36 * t + 36 * e2 / (e2 + 38) with e2 = e1 / 35^t. No lambda: e1 must be a cheap expression.
CREATE OR REPLACE MACRO gtfs_vc_idn_e1(delta, numpoints, first) AS (
  CASE WHEN first THEN delta // 700 + delta // 700 // numpoints ELSE delta // 2 + delta // 2 // numpoints END
);
CREATE OR REPLACE MACRO gtfs_vc_idn_adapt_t(e1) AS (
  (e1 >= 456)::INTEGER + (e1 >= 15960)::INTEGER + (e1 >= 558600)::INTEGER + (e1 >= 19551000)::INTEGER
  + (e1 >= 684285000)::INTEGER
);
CREATE OR REPLACE MACRO gtfs_vc_idn_adapt(e1) AS (
  36 * gtfs_vc_idn_adapt_t(e1)
  + (36 * (e1 // (35 ^ gtfs_vc_idn_adapt_t(e1))::BIGINT)) // (e1 // (35 ^ gtfs_vc_idn_adapt_t(e1))::BIGINT + 38)
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
-- StringPrep's map and NFKC of a label: every code point through the generated map, then nfc_normalize to compose
-- across them.
CREATE OR REPLACE MACRO gtfs_vc_idn_map(l) AS (
  nfc_normalize(coalesce(array_to_string(list_transform(string_split(l, ''), lambda c:
    CASE WHEN contains(gtfs_vc_idn_keys(), c) THEN split_part(gtfs_vc_idn_values(), chr(1), instr(gtfs_vc_idn_keys(), c))
         ELSE c END), ''), ''))
);
-- toASCIIInternal after the map and NFKC (p): NULL for a refused code point (U+E000 from the map), the RFC 3454 bidi
-- rules (a label with an R or AL code point has no L one and starts and ends with R or AL; m marks R and AL with
-- U+E000, which a prepared label never holds) and the empty label; an ACE prefix (any case) on a non-ASCII label or 60
-- code points or more (too long once encoded) are NULL too.
CREATE OR REPLACE MACRO gtfs_vc_idn_prepared(p) AS (
  list_transform([p], lambda q:
    CASE WHEN contains(q, chr(57344)) THEN NULL
         WHEN list_transform([regexp_replace(q, gtfs_vc_idn_r_re(), chr(57344), 'g')], lambda m:
                contains(m, chr(57344)) AND (NOT starts_with(m, chr(57344)) OR NOT ends_with(m, chr(57344))
                                             OR regexp_matches(q, gtfs_vc_idn_l_re())))[1] THEN NULL
         WHEN q = '' THEN NULL
         WHEN NOT regexp_matches(q, '[^\x00-\x7F]') THEN q
         WHEN regexp_matches(q, '^[xX][nN]--') OR length(q) >= 60 THEN NULL
         ELSE q
    END)[1]
);
-- The labels of an input go through the steps below as one list of structs, each step a list_transform of the
-- previous one's result (so the steps never nest). Step 1, per label l: q is l for an ASCII label (NULL if empty),
-- NULL for a refused code point of a long run, else the prepared label.
CREATE OR REPLACE MACRO gtfs_vc_idn_step1(ls) AS (
  list_transform(ls, lambda l: {'q': CASE WHEN NOT regexp_matches(l, '[^\x00-\x7F]') THEN (CASE WHEN l <> '' THEN l END)
                                          WHEN regexp_matches(l, gtfs_vc_idn_refused_re()) THEN NULL
                                          ELSE gtfs_vc_idn_prepared(gtfs_vc_idn_map(l)) END})
);
-- RFC 3492 Punycode (jdk.internal.icu.impl.Punycode.encode) of q, with the deltas in closed form. Step 2: its code
-- points y. Step 3: the basic code points and their count b, and the insertions: the non-basic code points sorted by
-- value then position, each with i = the code points before it whose value is at most its own.
CREATE OR REPLACE MACRO gtfs_vc_idn_step2(xs) AS (
  list_transform(xs, lambda r: {'q': r.q, 'y': list_transform(string_split(r.q, ''), lambda c: unicode(c))})
);
CREATE OR REPLACE MACRO gtfs_vc_idn_step3(xs) AS (
  list_transform(xs, lambda r: {'q': r.q,
    'basic': coalesce(array_to_string(list_transform(list_filter(r.y, lambda c: c < 128), lambda c: chr(c)), ''), ''),
    'b': len(list_filter(r.y, lambda c: c < 128))::BIGINT,
    'ins': list_sort(list_transform(list_filter(range(1, len(r.y) + 1), lambda j: r.y[j] >= 128),
             lambda j: {'v': r.y[j]::BIGINT, 'i': len(list_filter(r.y[1:j - 1], lambda c: c <= r.y[j]))::BIGINT}))})
);
-- Step 4: delta k is (v - v') * (b + k) + i - i' - 1 after the insertion (v', i'), (v - 128) * (b + 1) + i for the
-- first.
CREATE OR REPLACE MACRO gtfs_vc_idn_step4(xs) AS (
  list_transform(xs, lambda r: {'q': r.q, 'basic': r.basic, 'b': r.b,
    'd': list_transform(range(1, len(r.ins) + 1), lambda k: CASE WHEN k = 1 THEN (r.ins[1].v - 128) * (r.b + 1) + r.ins[1].i
           ELSE (r.ins[k].v - r.ins[k - 1].v) * (r.b + k) + r.ins[k].i - r.ins[k - 1].i - 1 END)})
);
-- Steps 5 and 6: the bias of delta k is 72 for the first, else adapt(delta k-1, b + k - 1, k = 2).
CREATE OR REPLACE MACRO gtfs_vc_idn_step5(xs) AS (
  list_transform(xs, lambda r: {'q': r.q, 'basic': r.basic, 'b': r.b, 'd': r.d,
    'e1': list_transform(range(1, len(r.d) + 1), lambda k: CASE WHEN k > 1 THEN gtfs_vc_idn_e1(r.d[k - 1], r.b + k - 1, k = 2) END)})
);
CREATE OR REPLACE MACRO gtfs_vc_idn_step6(xs) AS (
  list_transform(xs, lambda r: {'q': r.q, 'basic': r.basic, 'b': r.b, 'd': r.d,
    'bias': list_transform(range(1, len(r.d) + 1), lambda k: CASE WHEN k = 1 THEN 72 ELSE gtfs_vc_idn_adapt(r.e1[k]) END::BIGINT)})
);
-- Step 7: one flat list for all labels: per label n an entry k = 0 with its q, basic code points and b, then an entry
-- per delta k with the delta and its bias (flat, so the digit loop below is not nested in a per-label lambda).
CREATE OR REPLACE MACRO gtfs_vc_idn_step7(xs) AS (
  list_transform([xs], lambda ys: flatten(list_transform(range(1, len(ys) + 1), lambda n: list_concat(
    [{'n': n, 'k': 0, 'q': ys[n].q, 'basic': ys[n].basic, 'b': ys[n].b, 'd': NULL::BIGINT, 'bias': NULL::BIGINT}],
    list_transform(range(1, len(ys[n].d) + 1), lambda k: {'n': n, 'k': k, 'q': NULL::VARCHAR, 'basic': NULL::VARCHAR,
                                                          'b': NULL::BIGINT, 'd': ys[n].d[k], 'bias': ys[n].bias[k]})))))[1]
);
-- Step 8: the digits of every delta.
CREATE OR REPLACE MACRO gtfs_vc_idn_step8(fs) AS (
  list_transform(fs, lambda z: {'n': z.n, 'k': z.k, 'q': z.q, 'basic': z.basic, 'b': z.b,
                                'out': CASE WHEN z.k > 0 THEN gtfs_vc_idn_digits(z.d, z.bias) END})
);
-- Step 9: per label, ASCII as is (at most 63 characters), else 'xn--' and the lowercased basic code points, a '-' if
-- any and the digits of its deltas in order (at most 59 characters).
CREATE OR REPLACE MACRO gtfs_vc_idn_step9(gs) AS (
  list_transform([gs], lambda g: list_transform(list_filter(g, lambda h: h.k = 0), lambda h: CASE
    WHEN h.q IS NULL THEN NULL
    WHEN NOT regexp_matches(h.q, '[^\x00-\x7F]') THEN (CASE WHEN length(h.q) <= 63 THEN h.q END)
    ELSE list_transform([h.basic || CASE WHEN h.b > 0 THEN '-' ELSE '' END
                         || array_to_string(list_transform(list_filter(g, lambda z: z.n = h.n AND z.k > 0), lambda z: z.out), '')],
           lambda pc: CASE WHEN length(pc) <= 59 THEN 'xn--' || lower(pc) END)[1]
  END))[1]
);
-- The labels: a lone dot is the root label, labels end at the four dots (. U+3002 U+FF0E U+FF61), a final dot is kept
-- as '.', and one failing label fails the whole input.
CREATE OR REPLACE MACRO gtfs_vc_idn_join(cs, a) AS (
  list_transform([cs], lambda ls: CASE WHEN len(list_filter(ls, lambda c: c IS NULL)) = 0
    THEN array_to_string(ls, '.') || CASE WHEN regexp_matches(a, '[.\x{3002}\x{FF0E}\x{FF61}]$') THEN '.' ELSE '' END END)[1]
);
CREATE OR REPLACE MACRO gtfs_vc_idn_to_ascii(a) AS (
  CASE WHEN a = '' THEN ''
       WHEN length(a) = 1 AND regexp_full_match(a, '[.\x{3002}\x{FF0E}\x{FF61}]') THEN '.'
       ELSE gtfs_vc_idn_join(gtfs_vc_idn_step9(gtfs_vc_idn_step8(gtfs_vc_idn_step7(gtfs_vc_idn_step6(gtfs_vc_idn_step5(
              gtfs_vc_idn_step4(gtfs_vc_idn_step3(gtfs_vc_idn_step2(gtfs_vc_idn_step1(regexp_split_to_array(
                regexp_replace(a, '[.\x{3002}\x{FF0E}\x{FF61}]$', ''), '[.\x{3002}\x{FF0E}\x{FF61}]')))))))))), a)
  END
);
-- isValidAuthority: DomainValidator.unicodeToASCII of the authority, then the ASCII checks. An authority with a char
-- above U+007F becomes IDN.toASCII of it, or stays as is when that throws; only those authorities reach the IDN code
-- (inside the CASE). The result is bound once, as gtfs_vc_authority_ok uses its argument many times.
CREATE OR REPLACE MACRO gtfs_vc_idn_authority_ok(a) AS (
  list_transform([CASE WHEN regexp_matches(a, '[^\x00-\x7F]') THEN coalesce(gtfs_vc_idn_to_ascii(a), a) ELSE a END],
    lambda au: gtfs_vc_authority_ok(au))[1]
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
-- A port past the int range is false, never NULL: Integer.parseInt throws and isValidAuthority returns false (a NULL
-- would make the rule's WHERE NOT drop the row). An IPv6 authority's port is not checked, as in commons-validator 1.6.
CREATE OR REPLACE MACRO gtfs_vc_authority_ok(a) AS (
  CASE WHEN NOT regexp_full_match(a, gtfs_vc_authority_re()) THEN false
       ELSE (CASE WHEN regexp_extract(a, gtfs_vc_authority_re(), 1) <> ''
                  THEN gtfs_vc_ipv6_ok(regexp_extract(a, gtfs_vc_authority_re(), 1))
                  ELSE gtfs_vc_host_ok(regexp_extract(a, gtfs_vc_authority_re(), 2))
                       AND (regexp_extract(a, gtfs_vc_authority_re(), 3) = ''
                            OR coalesce(TRY_CAST(regexp_extract(a, gtfs_vc_authority_re(), 3) AS INTEGER)
                                        BETWEEN 0 AND 65535, false)) END)
            AND trim(regexp_extract(a, gtfs_vc_authority_re(), 4), gtfs_vc_ws()) = '' END
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
            AND gtfs_vc_idn_authority_ok(regexp_extract(s, gtfs_vc_url_re(), 4))
            AND gtfs_vc_path_ok(regexp_extract(s, gtfs_vc_url_re(), 5))
            AND NOT regexp_matches(regexp_extract(s, gtfs_vc_url_re(), 7), '[ \t\n\x0B\f\r]') END
);

-- ---------------------------------------------------------------- values and row notices
-- Per loaded table (macros generated by test/validation/gen_loader.py, at the end of this file):
--   gtfs_vc_wide_build_<table>()    the data rows of the header's length, one column per schema column: raw value
--                                   r_<column> (NULL when the header lacks the column) and parsed value p_<column>
--   gtfs_vc_cell_notices_<table>()  RowParser / DefaultFieldValidator notices of those values
--   gtfs_vc_entities_<table>()      the rows without an ERROR notice of their own, as gtfs_v_<table> stores them

-- Integer/Double.compareTo(0) as a sign: -0.0 is below 0.0 and NaN above everything.
CREATE OR REPLACE MACRO gtfs_vc_cmp0(p_kind, p_vi, p_vd) AS (
  CASE WHEN p_kind = 'integer' THEN sign(p_vi)
       WHEN isnan(p_vd) THEN 1 WHEN p_vd = 0 AND signbit(p_vd) THEN -1 ELSE sign(p_vd) END
);

-- RowParser.checkRowLength notices of the data rows.
CREATE OR REPLACE MACRO gtfs_vc_row_length_notices(p_file) AS TABLE
SELECT r.csv_row_number,
  CASE WHEN len(r.fields) = 1 AND r.fields[1] IS NULL THEN 'empty_row' ELSE 'invalid_row_length' END AS code,
  gtfs_validation_notice(CASE WHEN len(r.fields) = 1 AND r.fields[1] IS NULL
    THEN json_object('filename', p_file, 'csvRowNumber', r.csv_row_number)
    ELSE json_object('filename', p_file, 'csvRowNumber', r.csv_row_number, 'rowLength', len(r.fields),
                     'headerCount', s.header_n) END) AS notice,
  NOT (len(r.fields) = 1 AND r.fields[1] IS NULL) AS err
FROM gtfs_vc_data_rows() r, gtfs_vc_state s WHERE NOT r.length_ok;

-- CsvFileLoader's TableStatus of the current file.
CREATE OR REPLACE MACRO gtfs_vc_status() AS (
  SELECT CASE WHEN NOT s.has_header THEN 'EMPTY_FILE'
              WHEN NOT s.header_ok THEN 'INVALID_HEADERS'
              WHEN s.fail_rec IS NOT NULL OR EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err) THEN 'UNPARSABLE_ROWS'
              ELSE 'PARSABLE_HEADERS_AND_ROWS' END
  FROM gtfs_vc_state s
);

-- LOADER-GENERATED-BEGIN (test/validation/gen_loader.py; do not edit)
-- Data rows of stops.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_stops() AS TABLE
SELECT csv_row_number,
  plain,
  r_stop_id,
  r_stop_code,
  r_stop_name,
  r_tts_stop_name,
  r_stop_desc,
  r_stop_lat,
  gtfs_vc_double(CASE WHEN plain THEN r_stop_lat ELSE gtfs_vc_trim(r_stop_lat) END) AS p_stop_lat,
  r_stop_lon,
  gtfs_vc_double(CASE WHEN plain THEN r_stop_lon ELSE gtfs_vc_trim(r_stop_lon) END) AS p_stop_lon,
  r_zone_id,
  r_stop_url,
  r_location_type,
  gtfs_vc_int(CASE WHEN plain THEN r_location_type ELSE gtfs_vc_trim(r_location_type) END) AS p_location_type,
  r_parent_station,
  r_stop_timezone,
  r_wheelchair_boarding,
  gtfs_vc_int(CASE WHEN plain THEN r_wheelchair_boarding ELSE gtfs_vc_trim(r_wheelchair_boarding) END) AS p_wheelchair_boarding,
  r_level_id,
  r_platform_code,
  r_stop_access,
  gtfs_vc_int(CASE WHEN plain THEN r_stop_access ELSE gtfs_vc_trim(r_stop_access) END) AS p_stop_access
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_stop_id,
    d.fields[p.pos[2]] AS r_stop_code,
    d.fields[p.pos[3]] AS r_stop_name,
    d.fields[p.pos[4]] AS r_tts_stop_name,
    d.fields[p.pos[5]] AS r_stop_desc,
    d.fields[p.pos[6]] AS r_stop_lat,
    d.fields[p.pos[7]] AS r_stop_lon,
    d.fields[p.pos[8]] AS r_zone_id,
    d.fields[p.pos[9]] AS r_stop_url,
    d.fields[p.pos[10]] AS r_location_type,
    d.fields[p.pos[11]] AS r_parent_station,
    d.fields[p.pos[12]] AS r_stop_timezone,
    d.fields[p.pos[13]] AS r_wheelchair_boarding,
    d.fields[p.pos[14]] AS r_level_id,
    d.fields[p.pos[15]] AS r_platform_code,
    d.fields[p.pos[16]] AS r_stop_access
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of stops.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_stops() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_stops
  WHERE (r_stop_id IS NULL)
    OR (NOT plain AND contains(r_stop_id, chr(65533)))
    OR (NOT plain AND (contains(r_stop_id, chr(10)) OR contains(r_stop_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_id) <> r_stop_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_stop_code, chr(65533)))
    OR (NOT plain AND (contains(r_stop_code, chr(10)) OR contains(r_stop_code, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_code) <> r_stop_code)
    OR (NOT plain AND contains(r_stop_name, chr(65533)))
    OR (NOT plain AND (contains(r_stop_name, chr(10)) OR contains(r_stop_name, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_name) <> r_stop_name)
    OR (NOT plain AND contains(r_tts_stop_name, chr(65533)))
    OR (NOT plain AND (contains(r_tts_stop_name, chr(10)) OR contains(r_tts_stop_name, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_tts_stop_name) <> r_tts_stop_name)
    OR (NOT plain AND contains(r_stop_desc, chr(65533)))
    OR (NOT plain AND (contains(r_stop_desc, chr(10)) OR contains(r_stop_desc, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_desc) <> r_stop_desc)
    OR (NOT plain AND contains(r_stop_lat, chr(65533)))
    OR (NOT plain AND (contains(r_stop_lat, chr(10)) OR contains(r_stop_lat, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_lat) <> r_stop_lat)
    OR (r_stop_lat IS NOT NULL AND p_stop_lat IS NULL)
    OR (isnan(p_stop_lat) OR NOT (-90 <= p_stop_lat AND p_stop_lat <= 90))
    OR (NOT plain AND contains(r_stop_lon, chr(65533)))
    OR (NOT plain AND (contains(r_stop_lon, chr(10)) OR contains(r_stop_lon, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_lon) <> r_stop_lon)
    OR (r_stop_lon IS NOT NULL AND p_stop_lon IS NULL)
    OR (isnan(p_stop_lon) OR NOT (-180 <= p_stop_lon AND p_stop_lon <= 180))
    OR (NOT plain AND contains(r_zone_id, chr(65533)))
    OR (NOT plain AND (contains(r_zone_id, chr(10)) OR contains(r_zone_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_zone_id) <> r_zone_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_zone_id ELSE gtfs_vc_trim(r_zone_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_stop_url, chr(65533)))
    OR (NOT plain AND (contains(r_stop_url, chr(10)) OR contains(r_stop_url, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_url) <> r_stop_url)
    OR (r_stop_url IS NOT NULL AND NOT gtfs_vc_url_ok(CASE WHEN plain THEN r_stop_url ELSE gtfs_vc_trim(r_stop_url) END))
    OR (NOT plain AND contains(r_location_type, chr(65533)))
    OR (NOT plain AND (contains(r_location_type, chr(10)) OR contains(r_location_type, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_location_type) <> r_location_type)
    OR (r_location_type IS NOT NULL AND p_location_type IS NULL)
    OR (gtfs_validation_enum_name('GtfsLocationType', p_location_type) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_parent_station, chr(65533)))
    OR (NOT plain AND (contains(r_parent_station, chr(10)) OR contains(r_parent_station, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_parent_station) <> r_parent_station)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_parent_station ELSE gtfs_vc_trim(r_parent_station) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_stop_timezone, chr(65533)))
    OR (NOT plain AND (contains(r_stop_timezone, chr(10)) OR contains(r_stop_timezone, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_timezone) <> r_stop_timezone)
    OR (r_stop_timezone IS NOT NULL AND NOT gtfs_vc_timezone_ok(CASE WHEN plain THEN r_stop_timezone ELSE gtfs_vc_trim(r_stop_timezone) END))
    OR (NOT plain AND contains(r_wheelchair_boarding, chr(65533)))
    OR (NOT plain AND (contains(r_wheelchair_boarding, chr(10)) OR contains(r_wheelchair_boarding, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_wheelchair_boarding) <> r_wheelchair_boarding)
    OR (r_wheelchair_boarding IS NOT NULL AND p_wheelchair_boarding IS NULL)
    OR (gtfs_validation_enum_name('GtfsWheelchairBoarding', p_wheelchair_boarding) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_level_id, chr(65533)))
    OR (NOT plain AND (contains(r_level_id, chr(10)) OR contains(r_level_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_level_id) <> r_level_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_level_id ELSE gtfs_vc_trim(r_level_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_platform_code, chr(65533)))
    OR (NOT plain AND (contains(r_platform_code, chr(10)) OR contains(r_platform_code, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_platform_code) <> r_platform_code)
    OR (NOT plain AND contains(r_stop_access, chr(65533)))
    OR (NOT plain AND (contains(r_stop_access, chr(10)) OR contains(r_stop_access, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_access) <> r_stop_access)
    OR (r_stop_access IS NOT NULL AND p_stop_access IS NULL)
    OR (gtfs_validation_enum_name('GtfsStopAccess', p_stop_access) = 'UNRECOGNIZED')
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id') AS notice
  FROM w WHERE r_stop_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', r_stop_id) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', r_stop_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_id, chr(10)) OR contains(r_stop_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', r_stop_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_id) <> r_stop_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_code', 'fieldValue', r_stop_code) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_code, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_code', 'fieldValue', r_stop_code) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_code, chr(10)) OR contains(r_stop_code, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_code', 'fieldValue', r_stop_code) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_code) <> r_stop_code
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_name', 'fieldValue', r_stop_name) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_name, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_name', 'fieldValue', r_stop_name) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_name, chr(10)) OR contains(r_stop_name, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_name', 'fieldValue', r_stop_name) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_name) <> r_stop_name
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tts_stop_name', 'fieldValue', r_tts_stop_name) AS notice
  FROM w WHERE NOT plain AND contains(r_tts_stop_name, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tts_stop_name', 'fieldValue', r_tts_stop_name) AS notice
  FROM w WHERE NOT plain AND (contains(r_tts_stop_name, chr(10)) OR contains(r_tts_stop_name, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tts_stop_name', 'fieldValue', r_tts_stop_name) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_tts_stop_name) <> r_tts_stop_name
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_desc', 'fieldValue', r_stop_desc) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_desc, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_desc', 'fieldValue', r_stop_desc) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_desc, chr(10)) OR contains(r_stop_desc, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_desc', 'fieldValue', r_stop_desc) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_desc) <> r_stop_desc
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lat', 'fieldValue', r_stop_lat) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_lat, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lat', 'fieldValue', r_stop_lat) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_lat, chr(10)) OR contains(r_stop_lat, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lat', 'fieldValue', r_stop_lat) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_lat) <> r_stop_lat
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lat', 'fieldValue', CASE WHEN plain THEN r_stop_lat ELSE gtfs_vc_trim(r_stop_lat) END) AS notice
  FROM w WHERE r_stop_lat IS NOT NULL AND p_stop_lat IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lat', 'fieldType', 'latitude within [-90, 90]', 'fieldValue', to_json(p_stop_lat)) AS notice
  FROM w WHERE isnan(p_stop_lat) OR NOT (-90 <= p_stop_lat AND p_stop_lat <= 90)
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lon', 'fieldValue', r_stop_lon) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_lon, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lon', 'fieldValue', r_stop_lon) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_lon, chr(10)) OR contains(r_stop_lon, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lon', 'fieldValue', r_stop_lon) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_lon) <> r_stop_lon
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lon', 'fieldValue', CASE WHEN plain THEN r_stop_lon ELSE gtfs_vc_trim(r_stop_lon) END) AS notice
  FROM w WHERE r_stop_lon IS NOT NULL AND p_stop_lon IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_lon', 'fieldType', 'longitude within [-180, 180]', 'fieldValue', to_json(p_stop_lon)) AS notice
  FROM w WHERE isnan(p_stop_lon) OR NOT (-180 <= p_stop_lon AND p_stop_lon <= 180)
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'zone_id', 'fieldValue', r_zone_id) AS notice
  FROM w WHERE NOT plain AND contains(r_zone_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'zone_id', 'fieldValue', r_zone_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_zone_id, chr(10)) OR contains(r_zone_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'zone_id', 'fieldValue', r_zone_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_zone_id) <> r_zone_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'zone_id', 'fieldValue', CASE WHEN plain THEN r_zone_id ELSE gtfs_vc_trim(r_zone_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_zone_id ELSE gtfs_vc_trim(r_zone_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_url', 'fieldValue', r_stop_url) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_url, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_url', 'fieldValue', r_stop_url) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_url, chr(10)) OR contains(r_stop_url, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_url', 'fieldValue', r_stop_url) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_url) <> r_stop_url
  UNION ALL
  SELECT csv_row_number, 'invalid_url' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_url', 'fieldValue', CASE WHEN plain THEN r_stop_url ELSE gtfs_vc_trim(r_stop_url) END) AS notice
  FROM w WHERE r_stop_url IS NOT NULL AND NOT gtfs_vc_url_ok(CASE WHEN plain THEN r_stop_url ELSE gtfs_vc_trim(r_stop_url) END)
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_type', 'fieldValue', r_location_type) AS notice
  FROM w WHERE NOT plain AND contains(r_location_type, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_type', 'fieldValue', r_location_type) AS notice
  FROM w WHERE NOT plain AND (contains(r_location_type, chr(10)) OR contains(r_location_type, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_type', 'fieldValue', r_location_type) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_location_type) <> r_location_type
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_type', 'fieldValue', CASE WHEN plain THEN r_location_type ELSE gtfs_vc_trim(r_location_type) END) AS notice
  FROM w WHERE r_location_type IS NOT NULL AND p_location_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_type', 'fieldValue', p_location_type::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsLocationType', p_location_type) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'parent_station', 'fieldValue', r_parent_station) AS notice
  FROM w WHERE NOT plain AND contains(r_parent_station, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'parent_station', 'fieldValue', r_parent_station) AS notice
  FROM w WHERE NOT plain AND (contains(r_parent_station, chr(10)) OR contains(r_parent_station, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'parent_station', 'fieldValue', r_parent_station) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_parent_station) <> r_parent_station
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'parent_station', 'fieldValue', CASE WHEN plain THEN r_parent_station ELSE gtfs_vc_trim(r_parent_station) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_parent_station ELSE gtfs_vc_trim(r_parent_station) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_timezone', 'fieldValue', r_stop_timezone) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_timezone, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_timezone', 'fieldValue', r_stop_timezone) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_timezone, chr(10)) OR contains(r_stop_timezone, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_timezone', 'fieldValue', r_stop_timezone) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_timezone) <> r_stop_timezone
  UNION ALL
  SELECT csv_row_number, 'invalid_timezone' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_timezone', 'fieldValue', CASE WHEN plain THEN r_stop_timezone ELSE gtfs_vc_trim(r_stop_timezone) END) AS notice
  FROM w WHERE r_stop_timezone IS NOT NULL AND NOT gtfs_vc_timezone_ok(CASE WHEN plain THEN r_stop_timezone ELSE gtfs_vc_trim(r_stop_timezone) END)
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_boarding', 'fieldValue', r_wheelchair_boarding) AS notice
  FROM w WHERE NOT plain AND contains(r_wheelchair_boarding, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_boarding', 'fieldValue', r_wheelchair_boarding) AS notice
  FROM w WHERE NOT plain AND (contains(r_wheelchair_boarding, chr(10)) OR contains(r_wheelchair_boarding, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_boarding', 'fieldValue', r_wheelchair_boarding) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_wheelchair_boarding) <> r_wheelchair_boarding
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_boarding', 'fieldValue', CASE WHEN plain THEN r_wheelchair_boarding ELSE gtfs_vc_trim(r_wheelchair_boarding) END) AS notice
  FROM w WHERE r_wheelchair_boarding IS NOT NULL AND p_wheelchair_boarding IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_boarding', 'fieldValue', p_wheelchair_boarding::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsWheelchairBoarding', p_wheelchair_boarding) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'level_id', 'fieldValue', r_level_id) AS notice
  FROM w WHERE NOT plain AND contains(r_level_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'level_id', 'fieldValue', r_level_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_level_id, chr(10)) OR contains(r_level_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'level_id', 'fieldValue', r_level_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_level_id) <> r_level_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'level_id', 'fieldValue', CASE WHEN plain THEN r_level_id ELSE gtfs_vc_trim(r_level_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_level_id ELSE gtfs_vc_trim(r_level_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'platform_code', 'fieldValue', r_platform_code) AS notice
  FROM w WHERE NOT plain AND contains(r_platform_code, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'platform_code', 'fieldValue', r_platform_code) AS notice
  FROM w WHERE NOT plain AND (contains(r_platform_code, chr(10)) OR contains(r_platform_code, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'platform_code', 'fieldValue', r_platform_code) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_platform_code) <> r_platform_code
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_access', 'fieldValue', r_stop_access) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_access, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_access', 'fieldValue', r_stop_access) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_access, chr(10)) OR contains(r_stop_access, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_access', 'fieldValue', r_stop_access) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_access) <> r_stop_access
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_access', 'fieldValue', CASE WHEN plain THEN r_stop_access ELSE gtfs_vc_trim(r_stop_access) END) AS notice
  FROM w WHERE r_stop_access IS NOT NULL AND p_stop_access IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stops.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_access', 'fieldValue', p_stop_access::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsStopAccess', p_stop_access) = 'UNRECOGNIZED'
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of stops.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_stops() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END)::VARCHAR AS stop_id,
  (CASE WHEN plain THEN r_stop_code ELSE gtfs_vc_trim(r_stop_code) END)::VARCHAR AS stop_code,
  (CASE WHEN plain THEN r_stop_name ELSE gtfs_vc_trim(r_stop_name) END)::VARCHAR AS stop_name,
  (CASE WHEN plain THEN r_tts_stop_name ELSE gtfs_vc_trim(r_tts_stop_name) END)::VARCHAR AS tts_stop_name,
  (CASE WHEN plain THEN r_stop_desc ELSE gtfs_vc_trim(r_stop_desc) END)::VARCHAR AS stop_desc,
  p_stop_lat AS stop_lat,
  p_stop_lon AS stop_lon,
  (CASE WHEN plain THEN r_zone_id ELSE gtfs_vc_trim(r_zone_id) END)::VARCHAR AS zone_id,
  (CASE WHEN plain THEN r_stop_url ELSE gtfs_vc_trim(r_stop_url) END)::VARCHAR AS stop_url,
  p_location_type AS location_type,
  (CASE WHEN plain THEN r_parent_station ELSE gtfs_vc_trim(r_parent_station) END)::VARCHAR AS parent_station,
  (CASE WHEN plain THEN r_stop_timezone ELSE gtfs_vc_trim(r_stop_timezone) END)::VARCHAR AS stop_timezone,
  p_wheelchair_boarding AS wheelchair_boarding,
  (CASE WHEN plain THEN r_level_id ELSE gtfs_vc_trim(r_level_id) END)::VARCHAR AS level_id,
  (CASE WHEN plain THEN r_platform_code ELSE gtfs_vc_trim(r_platform_code) END)::VARCHAR AS platform_code,
  p_stop_access AS stop_access
FROM gtfs_vc_wide_stops w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of pathways.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_pathways() AS TABLE
SELECT csv_row_number,
  plain,
  r_pathway_id,
  r_from_stop_id,
  r_to_stop_id,
  r_pathway_mode,
  gtfs_vc_int(CASE WHEN plain THEN r_pathway_mode ELSE gtfs_vc_trim(r_pathway_mode) END) AS p_pathway_mode,
  r_is_bidirectional,
  gtfs_vc_int(CASE WHEN plain THEN r_is_bidirectional ELSE gtfs_vc_trim(r_is_bidirectional) END) AS p_is_bidirectional,
  r_length,
  gtfs_vc_double(CASE WHEN plain THEN r_length ELSE gtfs_vc_trim(r_length) END) AS p_length,
  r_traversal_time,
  gtfs_vc_int(CASE WHEN plain THEN r_traversal_time ELSE gtfs_vc_trim(r_traversal_time) END) AS p_traversal_time,
  r_stair_count,
  gtfs_vc_int(CASE WHEN plain THEN r_stair_count ELSE gtfs_vc_trim(r_stair_count) END) AS p_stair_count,
  r_max_slope,
  gtfs_vc_double(CASE WHEN plain THEN r_max_slope ELSE gtfs_vc_trim(r_max_slope) END) AS p_max_slope,
  r_min_width,
  gtfs_vc_double(CASE WHEN plain THEN r_min_width ELSE gtfs_vc_trim(r_min_width) END) AS p_min_width,
  r_signposted_as,
  r_reversed_signposted_as
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_pathway_id,
    d.fields[p.pos[2]] AS r_from_stop_id,
    d.fields[p.pos[3]] AS r_to_stop_id,
    d.fields[p.pos[4]] AS r_pathway_mode,
    d.fields[p.pos[5]] AS r_is_bidirectional,
    d.fields[p.pos[6]] AS r_length,
    d.fields[p.pos[7]] AS r_traversal_time,
    d.fields[p.pos[8]] AS r_stair_count,
    d.fields[p.pos[9]] AS r_max_slope,
    d.fields[p.pos[10]] AS r_min_width,
    d.fields[p.pos[11]] AS r_signposted_as,
    d.fields[p.pos[12]] AS r_reversed_signposted_as
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of pathways.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_pathways() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_pathways
  WHERE (r_pathway_id IS NULL)
    OR (NOT plain AND contains(r_pathway_id, chr(65533)))
    OR (NOT plain AND (contains(r_pathway_id, chr(10)) OR contains(r_pathway_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_pathway_id) <> r_pathway_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_pathway_id ELSE gtfs_vc_trim(r_pathway_id) END, '[^\x20-\x7E]'))
    OR (r_from_stop_id IS NULL)
    OR (NOT plain AND contains(r_from_stop_id, chr(65533)))
    OR (NOT plain AND (contains(r_from_stop_id, chr(10)) OR contains(r_from_stop_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_from_stop_id) <> r_from_stop_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_from_stop_id ELSE gtfs_vc_trim(r_from_stop_id) END, '[^\x20-\x7E]'))
    OR (r_to_stop_id IS NULL)
    OR (NOT plain AND contains(r_to_stop_id, chr(65533)))
    OR (NOT plain AND (contains(r_to_stop_id, chr(10)) OR contains(r_to_stop_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_to_stop_id) <> r_to_stop_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_to_stop_id ELSE gtfs_vc_trim(r_to_stop_id) END, '[^\x20-\x7E]'))
    OR (r_pathway_mode IS NULL)
    OR (NOT plain AND contains(r_pathway_mode, chr(65533)))
    OR (NOT plain AND (contains(r_pathway_mode, chr(10)) OR contains(r_pathway_mode, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_pathway_mode) <> r_pathway_mode)
    OR (r_pathway_mode IS NOT NULL AND p_pathway_mode IS NULL)
    OR (gtfs_validation_enum_name('GtfsPathwayMode', p_pathway_mode) = 'UNRECOGNIZED')
    OR (r_is_bidirectional IS NULL)
    OR (NOT plain AND contains(r_is_bidirectional, chr(65533)))
    OR (NOT plain AND (contains(r_is_bidirectional, chr(10)) OR contains(r_is_bidirectional, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_is_bidirectional) <> r_is_bidirectional)
    OR (r_is_bidirectional IS NOT NULL AND p_is_bidirectional IS NULL)
    OR (gtfs_validation_enum_name('GtfsPathwayIsBidirectional', p_is_bidirectional) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_length, chr(65533)))
    OR (NOT plain AND (contains(r_length, chr(10)) OR contains(r_length, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_length) <> r_length)
    OR (r_length IS NOT NULL AND p_length IS NULL)
    OR (gtfs_vc_cmp0('float', NULL::INTEGER, p_length) < 0)
    OR (NOT plain AND contains(r_traversal_time, chr(65533)))
    OR (NOT plain AND (contains(r_traversal_time, chr(10)) OR contains(r_traversal_time, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_traversal_time) <> r_traversal_time)
    OR (r_traversal_time IS NOT NULL AND p_traversal_time IS NULL)
    OR (p_traversal_time <= 0)
    OR (NOT plain AND contains(r_stair_count, chr(65533)))
    OR (NOT plain AND (contains(r_stair_count, chr(10)) OR contains(r_stair_count, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stair_count) <> r_stair_count)
    OR (r_stair_count IS NOT NULL AND p_stair_count IS NULL)
    OR (p_stair_count = 0)
    OR (NOT plain AND contains(r_max_slope, chr(65533)))
    OR (NOT plain AND (contains(r_max_slope, chr(10)) OR contains(r_max_slope, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_max_slope) <> r_max_slope)
    OR (r_max_slope IS NOT NULL AND p_max_slope IS NULL)
    OR (NOT plain AND contains(r_min_width, chr(65533)))
    OR (NOT plain AND (contains(r_min_width, chr(10)) OR contains(r_min_width, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_min_width) <> r_min_width)
    OR (r_min_width IS NOT NULL AND p_min_width IS NULL)
    OR (gtfs_vc_cmp0('float', NULL::INTEGER, p_min_width) <= 0)
    OR (NOT plain AND contains(r_signposted_as, chr(65533)))
    OR (NOT plain AND (contains(r_signposted_as, chr(10)) OR contains(r_signposted_as, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_signposted_as) <> r_signposted_as)
    OR (NOT plain AND contains(r_reversed_signposted_as, chr(65533)))
    OR (NOT plain AND (contains(r_reversed_signposted_as, chr(10)) OR contains(r_reversed_signposted_as, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_reversed_signposted_as) <> r_reversed_signposted_as)
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_id') AS notice
  FROM w WHERE r_pathway_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_id', 'fieldValue', r_pathway_id) AS notice
  FROM w WHERE NOT plain AND contains(r_pathway_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_id', 'fieldValue', r_pathway_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_pathway_id, chr(10)) OR contains(r_pathway_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_id', 'fieldValue', r_pathway_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_pathway_id) <> r_pathway_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_id', 'fieldValue', CASE WHEN plain THEN r_pathway_id ELSE gtfs_vc_trim(r_pathway_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_pathway_id ELSE gtfs_vc_trim(r_pathway_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'from_stop_id') AS notice
  FROM w WHERE r_from_stop_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'from_stop_id', 'fieldValue', r_from_stop_id) AS notice
  FROM w WHERE NOT plain AND contains(r_from_stop_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'from_stop_id', 'fieldValue', r_from_stop_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_from_stop_id, chr(10)) OR contains(r_from_stop_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'from_stop_id', 'fieldValue', r_from_stop_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_from_stop_id) <> r_from_stop_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'from_stop_id', 'fieldValue', CASE WHEN plain THEN r_from_stop_id ELSE gtfs_vc_trim(r_from_stop_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_from_stop_id ELSE gtfs_vc_trim(r_from_stop_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'to_stop_id') AS notice
  FROM w WHERE r_to_stop_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'to_stop_id', 'fieldValue', r_to_stop_id) AS notice
  FROM w WHERE NOT plain AND contains(r_to_stop_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'to_stop_id', 'fieldValue', r_to_stop_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_to_stop_id, chr(10)) OR contains(r_to_stop_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'to_stop_id', 'fieldValue', r_to_stop_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_to_stop_id) <> r_to_stop_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'to_stop_id', 'fieldValue', CASE WHEN plain THEN r_to_stop_id ELSE gtfs_vc_trim(r_to_stop_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_to_stop_id ELSE gtfs_vc_trim(r_to_stop_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_mode') AS notice
  FROM w WHERE r_pathway_mode IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_mode', 'fieldValue', r_pathway_mode) AS notice
  FROM w WHERE NOT plain AND contains(r_pathway_mode, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_mode', 'fieldValue', r_pathway_mode) AS notice
  FROM w WHERE NOT plain AND (contains(r_pathway_mode, chr(10)) OR contains(r_pathway_mode, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_mode', 'fieldValue', r_pathway_mode) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_pathway_mode) <> r_pathway_mode
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_mode', 'fieldValue', CASE WHEN plain THEN r_pathway_mode ELSE gtfs_vc_trim(r_pathway_mode) END) AS notice
  FROM w WHERE r_pathway_mode IS NOT NULL AND p_pathway_mode IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pathway_mode', 'fieldValue', p_pathway_mode::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsPathwayMode', p_pathway_mode) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'is_bidirectional') AS notice
  FROM w WHERE r_is_bidirectional IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'is_bidirectional', 'fieldValue', r_is_bidirectional) AS notice
  FROM w WHERE NOT plain AND contains(r_is_bidirectional, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'is_bidirectional', 'fieldValue', r_is_bidirectional) AS notice
  FROM w WHERE NOT plain AND (contains(r_is_bidirectional, chr(10)) OR contains(r_is_bidirectional, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'is_bidirectional', 'fieldValue', r_is_bidirectional) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_is_bidirectional) <> r_is_bidirectional
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'is_bidirectional', 'fieldValue', CASE WHEN plain THEN r_is_bidirectional ELSE gtfs_vc_trim(r_is_bidirectional) END) AS notice
  FROM w WHERE r_is_bidirectional IS NOT NULL AND p_is_bidirectional IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'is_bidirectional', 'fieldValue', p_is_bidirectional::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsPathwayIsBidirectional', p_is_bidirectional) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'length', 'fieldValue', r_length) AS notice
  FROM w WHERE NOT plain AND contains(r_length, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'length', 'fieldValue', r_length) AS notice
  FROM w WHERE NOT plain AND (contains(r_length, chr(10)) OR contains(r_length, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'length', 'fieldValue', r_length) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_length) <> r_length
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'length', 'fieldValue', CASE WHEN plain THEN r_length ELSE gtfs_vc_trim(r_length) END) AS notice
  FROM w WHERE r_length IS NOT NULL AND p_length IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'length', 'fieldType', 'non-negative float', 'fieldValue', to_json(p_length)) AS notice
  FROM w WHERE gtfs_vc_cmp0('float', NULL::INTEGER, p_length) < 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'traversal_time', 'fieldValue', r_traversal_time) AS notice
  FROM w WHERE NOT plain AND contains(r_traversal_time, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'traversal_time', 'fieldValue', r_traversal_time) AS notice
  FROM w WHERE NOT plain AND (contains(r_traversal_time, chr(10)) OR contains(r_traversal_time, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'traversal_time', 'fieldValue', r_traversal_time) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_traversal_time) <> r_traversal_time
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'traversal_time', 'fieldValue', CASE WHEN plain THEN r_traversal_time ELSE gtfs_vc_trim(r_traversal_time) END) AS notice
  FROM w WHERE r_traversal_time IS NOT NULL AND p_traversal_time IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'traversal_time', 'fieldType', 'positive integer', 'fieldValue', to_json(p_traversal_time::INTEGER)) AS notice
  FROM w WHERE p_traversal_time <= 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stair_count', 'fieldValue', r_stair_count) AS notice
  FROM w WHERE NOT plain AND contains(r_stair_count, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stair_count', 'fieldValue', r_stair_count) AS notice
  FROM w WHERE NOT plain AND (contains(r_stair_count, chr(10)) OR contains(r_stair_count, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stair_count', 'fieldValue', r_stair_count) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stair_count) <> r_stair_count
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stair_count', 'fieldValue', CASE WHEN plain THEN r_stair_count ELSE gtfs_vc_trim(r_stair_count) END) AS notice
  FROM w WHERE r_stair_count IS NOT NULL AND p_stair_count IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stair_count', 'fieldType', 'non-zero integer', 'fieldValue', to_json(p_stair_count::INTEGER)) AS notice
  FROM w WHERE p_stair_count = 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'max_slope', 'fieldValue', r_max_slope) AS notice
  FROM w WHERE NOT plain AND contains(r_max_slope, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'max_slope', 'fieldValue', r_max_slope) AS notice
  FROM w WHERE NOT plain AND (contains(r_max_slope, chr(10)) OR contains(r_max_slope, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'max_slope', 'fieldValue', r_max_slope) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_max_slope) <> r_max_slope
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'max_slope', 'fieldValue', CASE WHEN plain THEN r_max_slope ELSE gtfs_vc_trim(r_max_slope) END) AS notice
  FROM w WHERE r_max_slope IS NOT NULL AND p_max_slope IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'min_width', 'fieldValue', r_min_width) AS notice
  FROM w WHERE NOT plain AND contains(r_min_width, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'min_width', 'fieldValue', r_min_width) AS notice
  FROM w WHERE NOT plain AND (contains(r_min_width, chr(10)) OR contains(r_min_width, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'min_width', 'fieldValue', r_min_width) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_min_width) <> r_min_width
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'min_width', 'fieldValue', CASE WHEN plain THEN r_min_width ELSE gtfs_vc_trim(r_min_width) END) AS notice
  FROM w WHERE r_min_width IS NOT NULL AND p_min_width IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'min_width', 'fieldType', 'positive float', 'fieldValue', to_json(p_min_width)) AS notice
  FROM w WHERE gtfs_vc_cmp0('float', NULL::INTEGER, p_min_width) <= 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'signposted_as', 'fieldValue', r_signposted_as) AS notice
  FROM w WHERE NOT plain AND contains(r_signposted_as, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'signposted_as', 'fieldValue', r_signposted_as) AS notice
  FROM w WHERE NOT plain AND (contains(r_signposted_as, chr(10)) OR contains(r_signposted_as, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'signposted_as', 'fieldValue', r_signposted_as) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_signposted_as) <> r_signposted_as
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'reversed_signposted_as', 'fieldValue', r_reversed_signposted_as) AS notice
  FROM w WHERE NOT plain AND contains(r_reversed_signposted_as, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'reversed_signposted_as', 'fieldValue', r_reversed_signposted_as) AS notice
  FROM w WHERE NOT plain AND (contains(r_reversed_signposted_as, chr(10)) OR contains(r_reversed_signposted_as, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'pathways.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'reversed_signposted_as', 'fieldValue', r_reversed_signposted_as) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_reversed_signposted_as) <> r_reversed_signposted_as
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of pathways.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_pathways() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_pathway_id ELSE gtfs_vc_trim(r_pathway_id) END)::VARCHAR AS pathway_id,
  (CASE WHEN plain THEN r_from_stop_id ELSE gtfs_vc_trim(r_from_stop_id) END)::VARCHAR AS from_stop_id,
  (CASE WHEN plain THEN r_to_stop_id ELSE gtfs_vc_trim(r_to_stop_id) END)::VARCHAR AS to_stop_id,
  p_pathway_mode AS pathway_mode,
  p_is_bidirectional AS is_bidirectional,
  p_length AS length,
  p_traversal_time AS traversal_time,
  p_stair_count AS stair_count,
  p_max_slope AS max_slope,
  p_min_width AS min_width,
  (CASE WHEN plain THEN r_signposted_as ELSE gtfs_vc_trim(r_signposted_as) END)::VARCHAR AS signposted_as,
  (CASE WHEN plain THEN r_reversed_signposted_as ELSE gtfs_vc_trim(r_reversed_signposted_as) END)::VARCHAR AS reversed_signposted_as
FROM gtfs_vc_wide_pathways w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of routes.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_routes() AS TABLE
SELECT csv_row_number,
  plain,
  r_route_id,
  r_agency_id,
  r_route_short_name,
  r_route_long_name,
  r_route_desc,
  r_route_type,
  gtfs_vc_int(CASE WHEN plain THEN r_route_type ELSE gtfs_vc_trim(r_route_type) END) AS p_route_type,
  r_route_url,
  r_route_color,
  gtfs_vc_color(CASE WHEN plain THEN r_route_color ELSE gtfs_vc_trim(r_route_color) END) AS p_route_color,
  r_route_text_color,
  gtfs_vc_color(CASE WHEN plain THEN r_route_text_color ELSE gtfs_vc_trim(r_route_text_color) END) AS p_route_text_color,
  r_route_sort_order,
  gtfs_vc_int(CASE WHEN plain THEN r_route_sort_order ELSE gtfs_vc_trim(r_route_sort_order) END) AS p_route_sort_order,
  r_continuous_pickup,
  gtfs_vc_int(CASE WHEN plain THEN r_continuous_pickup ELSE gtfs_vc_trim(r_continuous_pickup) END) AS p_continuous_pickup,
  r_continuous_drop_off,
  gtfs_vc_int(CASE WHEN plain THEN r_continuous_drop_off ELSE gtfs_vc_trim(r_continuous_drop_off) END) AS p_continuous_drop_off,
  r_network_id,
  r_cemv_support,
  gtfs_vc_int(CASE WHEN plain THEN r_cemv_support ELSE gtfs_vc_trim(r_cemv_support) END) AS p_cemv_support
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_route_id,
    d.fields[p.pos[2]] AS r_agency_id,
    d.fields[p.pos[3]] AS r_route_short_name,
    d.fields[p.pos[4]] AS r_route_long_name,
    d.fields[p.pos[5]] AS r_route_desc,
    d.fields[p.pos[6]] AS r_route_type,
    d.fields[p.pos[7]] AS r_route_url,
    d.fields[p.pos[8]] AS r_route_color,
    d.fields[p.pos[9]] AS r_route_text_color,
    d.fields[p.pos[10]] AS r_route_sort_order,
    d.fields[p.pos[11]] AS r_continuous_pickup,
    d.fields[p.pos[12]] AS r_continuous_drop_off,
    d.fields[p.pos[13]] AS r_network_id,
    d.fields[p.pos[14]] AS r_cemv_support
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of routes.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_routes() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_routes
  WHERE (r_route_id IS NULL)
    OR (NOT plain AND contains(r_route_id, chr(65533)))
    OR (NOT plain AND (contains(r_route_id, chr(10)) OR contains(r_route_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_id) <> r_route_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_agency_id, chr(65533)))
    OR (NOT plain AND (contains(r_agency_id, chr(10)) OR contains(r_agency_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_agency_id) <> r_agency_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_agency_id ELSE gtfs_vc_trim(r_agency_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_route_short_name, chr(65533)))
    OR (NOT plain AND (contains(r_route_short_name, chr(10)) OR contains(r_route_short_name, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_short_name) <> r_route_short_name)
    OR (NOT plain AND contains(r_route_long_name, chr(65533)))
    OR (NOT plain AND (contains(r_route_long_name, chr(10)) OR contains(r_route_long_name, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_long_name) <> r_route_long_name)
    OR (NOT plain AND contains(r_route_desc, chr(65533)))
    OR (NOT plain AND (contains(r_route_desc, chr(10)) OR contains(r_route_desc, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_desc) <> r_route_desc)
    OR (r_route_type IS NULL)
    OR (NOT plain AND contains(r_route_type, chr(65533)))
    OR (NOT plain AND (contains(r_route_type, chr(10)) OR contains(r_route_type, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_type) <> r_route_type)
    OR (r_route_type IS NOT NULL AND p_route_type IS NULL)
    OR (gtfs_validation_enum_name('GtfsRouteType', p_route_type) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_route_url, chr(65533)))
    OR (NOT plain AND (contains(r_route_url, chr(10)) OR contains(r_route_url, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_url) <> r_route_url)
    OR (r_route_url IS NOT NULL AND NOT gtfs_vc_url_ok(CASE WHEN plain THEN r_route_url ELSE gtfs_vc_trim(r_route_url) END))
    OR (NOT plain AND contains(r_route_color, chr(65533)))
    OR (NOT plain AND (contains(r_route_color, chr(10)) OR contains(r_route_color, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_color) <> r_route_color)
    OR (r_route_color IS NOT NULL AND p_route_color IS NULL)
    OR (NOT plain AND contains(r_route_text_color, chr(65533)))
    OR (NOT plain AND (contains(r_route_text_color, chr(10)) OR contains(r_route_text_color, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_text_color) <> r_route_text_color)
    OR (r_route_text_color IS NOT NULL AND p_route_text_color IS NULL)
    OR (NOT plain AND contains(r_route_sort_order, chr(65533)))
    OR (NOT plain AND (contains(r_route_sort_order, chr(10)) OR contains(r_route_sort_order, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_sort_order) <> r_route_sort_order)
    OR (r_route_sort_order IS NOT NULL AND p_route_sort_order IS NULL)
    OR (p_route_sort_order < 0)
    OR (NOT plain AND contains(r_continuous_pickup, chr(65533)))
    OR (NOT plain AND (contains(r_continuous_pickup, chr(10)) OR contains(r_continuous_pickup, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_continuous_pickup) <> r_continuous_pickup)
    OR (r_continuous_pickup IS NOT NULL AND p_continuous_pickup IS NULL)
    OR (gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_pickup) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_continuous_drop_off, chr(65533)))
    OR (NOT plain AND (contains(r_continuous_drop_off, chr(10)) OR contains(r_continuous_drop_off, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_continuous_drop_off) <> r_continuous_drop_off)
    OR (r_continuous_drop_off IS NOT NULL AND p_continuous_drop_off IS NULL)
    OR (gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_drop_off) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_network_id, chr(65533)))
    OR (NOT plain AND (contains(r_network_id, chr(10)) OR contains(r_network_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_network_id) <> r_network_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_network_id ELSE gtfs_vc_trim(r_network_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_cemv_support, chr(65533)))
    OR (NOT plain AND (contains(r_cemv_support, chr(10)) OR contains(r_cemv_support, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_cemv_support) <> r_cemv_support)
    OR (r_cemv_support IS NOT NULL AND p_cemv_support IS NULL)
    OR (gtfs_validation_enum_name('GtfsContactlessEmvSupport', p_cemv_support) = 'UNRECOGNIZED')
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id') AS notice
  FROM w WHERE r_route_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', r_route_id) AS notice
  FROM w WHERE NOT plain AND contains(r_route_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', r_route_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_id, chr(10)) OR contains(r_route_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', r_route_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_id) <> r_route_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'agency_id', 'fieldValue', r_agency_id) AS notice
  FROM w WHERE NOT plain AND contains(r_agency_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'agency_id', 'fieldValue', r_agency_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_agency_id, chr(10)) OR contains(r_agency_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'agency_id', 'fieldValue', r_agency_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_agency_id) <> r_agency_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'agency_id', 'fieldValue', CASE WHEN plain THEN r_agency_id ELSE gtfs_vc_trim(r_agency_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_agency_id ELSE gtfs_vc_trim(r_agency_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_short_name', 'fieldValue', r_route_short_name) AS notice
  FROM w WHERE NOT plain AND contains(r_route_short_name, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_short_name', 'fieldValue', r_route_short_name) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_short_name, chr(10)) OR contains(r_route_short_name, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_short_name', 'fieldValue', r_route_short_name) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_short_name) <> r_route_short_name
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_long_name', 'fieldValue', r_route_long_name) AS notice
  FROM w WHERE NOT plain AND contains(r_route_long_name, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_long_name', 'fieldValue', r_route_long_name) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_long_name, chr(10)) OR contains(r_route_long_name, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_long_name', 'fieldValue', r_route_long_name) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_long_name) <> r_route_long_name
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_desc', 'fieldValue', r_route_desc) AS notice
  FROM w WHERE NOT plain AND contains(r_route_desc, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_desc', 'fieldValue', r_route_desc) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_desc, chr(10)) OR contains(r_route_desc, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_desc', 'fieldValue', r_route_desc) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_desc) <> r_route_desc
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_type') AS notice
  FROM w WHERE r_route_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_type', 'fieldValue', r_route_type) AS notice
  FROM w WHERE NOT plain AND contains(r_route_type, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_type', 'fieldValue', r_route_type) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_type, chr(10)) OR contains(r_route_type, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_type', 'fieldValue', r_route_type) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_type) <> r_route_type
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_type', 'fieldValue', CASE WHEN plain THEN r_route_type ELSE gtfs_vc_trim(r_route_type) END) AS notice
  FROM w WHERE r_route_type IS NOT NULL AND p_route_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_type', 'fieldValue', p_route_type::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsRouteType', p_route_type) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_url', 'fieldValue', r_route_url) AS notice
  FROM w WHERE NOT plain AND contains(r_route_url, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_url', 'fieldValue', r_route_url) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_url, chr(10)) OR contains(r_route_url, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_url', 'fieldValue', r_route_url) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_url) <> r_route_url
  UNION ALL
  SELECT csv_row_number, 'invalid_url' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_url', 'fieldValue', CASE WHEN plain THEN r_route_url ELSE gtfs_vc_trim(r_route_url) END) AS notice
  FROM w WHERE r_route_url IS NOT NULL AND NOT gtfs_vc_url_ok(CASE WHEN plain THEN r_route_url ELSE gtfs_vc_trim(r_route_url) END)
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_color', 'fieldValue', r_route_color) AS notice
  FROM w WHERE NOT plain AND contains(r_route_color, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_color', 'fieldValue', r_route_color) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_color, chr(10)) OR contains(r_route_color, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_color', 'fieldValue', r_route_color) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_color) <> r_route_color
  UNION ALL
  SELECT csv_row_number, 'invalid_color' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_color', 'fieldValue', CASE WHEN plain THEN r_route_color ELSE gtfs_vc_trim(r_route_color) END) AS notice
  FROM w WHERE r_route_color IS NOT NULL AND p_route_color IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_text_color', 'fieldValue', r_route_text_color) AS notice
  FROM w WHERE NOT plain AND contains(r_route_text_color, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_text_color', 'fieldValue', r_route_text_color) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_text_color, chr(10)) OR contains(r_route_text_color, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_text_color', 'fieldValue', r_route_text_color) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_text_color) <> r_route_text_color
  UNION ALL
  SELECT csv_row_number, 'invalid_color' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_text_color', 'fieldValue', CASE WHEN plain THEN r_route_text_color ELSE gtfs_vc_trim(r_route_text_color) END) AS notice
  FROM w WHERE r_route_text_color IS NOT NULL AND p_route_text_color IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_sort_order', 'fieldValue', r_route_sort_order) AS notice
  FROM w WHERE NOT plain AND contains(r_route_sort_order, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_sort_order', 'fieldValue', r_route_sort_order) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_sort_order, chr(10)) OR contains(r_route_sort_order, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_sort_order', 'fieldValue', r_route_sort_order) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_sort_order) <> r_route_sort_order
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_sort_order', 'fieldValue', CASE WHEN plain THEN r_route_sort_order ELSE gtfs_vc_trim(r_route_sort_order) END) AS notice
  FROM w WHERE r_route_sort_order IS NOT NULL AND p_route_sort_order IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_sort_order', 'fieldType', 'non-negative integer', 'fieldValue', to_json(p_route_sort_order::INTEGER)) AS notice
  FROM w WHERE p_route_sort_order < 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', r_continuous_pickup) AS notice
  FROM w WHERE NOT plain AND contains(r_continuous_pickup, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', r_continuous_pickup) AS notice
  FROM w WHERE NOT plain AND (contains(r_continuous_pickup, chr(10)) OR contains(r_continuous_pickup, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', r_continuous_pickup) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_continuous_pickup) <> r_continuous_pickup
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', CASE WHEN plain THEN r_continuous_pickup ELSE gtfs_vc_trim(r_continuous_pickup) END) AS notice
  FROM w WHERE r_continuous_pickup IS NOT NULL AND p_continuous_pickup IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', p_continuous_pickup::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_pickup) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', r_continuous_drop_off) AS notice
  FROM w WHERE NOT plain AND contains(r_continuous_drop_off, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', r_continuous_drop_off) AS notice
  FROM w WHERE NOT plain AND (contains(r_continuous_drop_off, chr(10)) OR contains(r_continuous_drop_off, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', r_continuous_drop_off) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_continuous_drop_off) <> r_continuous_drop_off
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', CASE WHEN plain THEN r_continuous_drop_off ELSE gtfs_vc_trim(r_continuous_drop_off) END) AS notice
  FROM w WHERE r_continuous_drop_off IS NOT NULL AND p_continuous_drop_off IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', p_continuous_drop_off::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_drop_off) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'network_id', 'fieldValue', r_network_id) AS notice
  FROM w WHERE NOT plain AND contains(r_network_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'network_id', 'fieldValue', r_network_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_network_id, chr(10)) OR contains(r_network_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'network_id', 'fieldValue', r_network_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_network_id) <> r_network_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'network_id', 'fieldValue', CASE WHEN plain THEN r_network_id ELSE gtfs_vc_trim(r_network_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_network_id ELSE gtfs_vc_trim(r_network_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cemv_support', 'fieldValue', r_cemv_support) AS notice
  FROM w WHERE NOT plain AND contains(r_cemv_support, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cemv_support', 'fieldValue', r_cemv_support) AS notice
  FROM w WHERE NOT plain AND (contains(r_cemv_support, chr(10)) OR contains(r_cemv_support, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cemv_support', 'fieldValue', r_cemv_support) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_cemv_support) <> r_cemv_support
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cemv_support', 'fieldValue', CASE WHEN plain THEN r_cemv_support ELSE gtfs_vc_trim(r_cemv_support) END) AS notice
  FROM w WHERE r_cemv_support IS NOT NULL AND p_cemv_support IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'routes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cemv_support', 'fieldValue', p_cemv_support::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsContactlessEmvSupport', p_cemv_support) = 'UNRECOGNIZED'
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of routes.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_routes() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END)::VARCHAR AS route_id,
  (CASE WHEN plain THEN r_agency_id ELSE gtfs_vc_trim(r_agency_id) END)::VARCHAR AS agency_id,
  (CASE WHEN plain THEN r_route_short_name ELSE gtfs_vc_trim(r_route_short_name) END)::VARCHAR AS route_short_name,
  (CASE WHEN plain THEN r_route_long_name ELSE gtfs_vc_trim(r_route_long_name) END)::VARCHAR AS route_long_name,
  (CASE WHEN plain THEN r_route_desc ELSE gtfs_vc_trim(r_route_desc) END)::VARCHAR AS route_desc,
  p_route_type AS route_type,
  (CASE WHEN plain THEN r_route_url ELSE gtfs_vc_trim(r_route_url) END)::VARCHAR AS route_url,
  p_route_color AS route_color,
  p_route_text_color AS route_text_color,
  p_route_sort_order AS route_sort_order,
  p_continuous_pickup AS continuous_pickup,
  p_continuous_drop_off AS continuous_drop_off,
  (CASE WHEN plain THEN r_network_id ELSE gtfs_vc_trim(r_network_id) END)::VARCHAR AS network_id,
  p_cemv_support AS cemv_support
FROM gtfs_vc_wide_routes w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of trips.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_trips() AS TABLE
SELECT csv_row_number,
  plain,
  r_trip_id,
  r_route_id,
  r_service_id,
  r_trip_headsign,
  r_trip_short_name,
  r_direction_id,
  gtfs_vc_int(CASE WHEN plain THEN r_direction_id ELSE gtfs_vc_trim(r_direction_id) END) AS p_direction_id,
  r_block_id,
  r_shape_id,
  r_wheelchair_accessible,
  gtfs_vc_int(CASE WHEN plain THEN r_wheelchair_accessible ELSE gtfs_vc_trim(r_wheelchair_accessible) END) AS p_wheelchair_accessible,
  r_bikes_allowed,
  gtfs_vc_int(CASE WHEN plain THEN r_bikes_allowed ELSE gtfs_vc_trim(r_bikes_allowed) END) AS p_bikes_allowed,
  r_cars_allowed,
  gtfs_vc_int(CASE WHEN plain THEN r_cars_allowed ELSE gtfs_vc_trim(r_cars_allowed) END) AS p_cars_allowed,
  r_safe_duration_factor,
  gtfs_vc_double(CASE WHEN plain THEN r_safe_duration_factor ELSE gtfs_vc_trim(r_safe_duration_factor) END) AS p_safe_duration_factor,
  r_safe_duration_offset,
  gtfs_vc_double(CASE WHEN plain THEN r_safe_duration_offset ELSE gtfs_vc_trim(r_safe_duration_offset) END) AS p_safe_duration_offset
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_trip_id,
    d.fields[p.pos[2]] AS r_route_id,
    d.fields[p.pos[3]] AS r_service_id,
    d.fields[p.pos[4]] AS r_trip_headsign,
    d.fields[p.pos[5]] AS r_trip_short_name,
    d.fields[p.pos[6]] AS r_direction_id,
    d.fields[p.pos[7]] AS r_block_id,
    d.fields[p.pos[8]] AS r_shape_id,
    d.fields[p.pos[9]] AS r_wheelchair_accessible,
    d.fields[p.pos[10]] AS r_bikes_allowed,
    d.fields[p.pos[11]] AS r_cars_allowed,
    d.fields[p.pos[12]] AS r_safe_duration_factor,
    d.fields[p.pos[13]] AS r_safe_duration_offset
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of trips.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_trips() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_trips
  WHERE (r_trip_id IS NULL)
    OR (NOT plain AND contains(r_trip_id, chr(65533)))
    OR (NOT plain AND (contains(r_trip_id, chr(10)) OR contains(r_trip_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_trip_id) <> r_trip_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END, '[^\x20-\x7E]'))
    OR (r_route_id IS NULL)
    OR (NOT plain AND contains(r_route_id, chr(65533)))
    OR (NOT plain AND (contains(r_route_id, chr(10)) OR contains(r_route_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_route_id) <> r_route_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END, '[^\x20-\x7E]'))
    OR (r_service_id IS NULL)
    OR (NOT plain AND contains(r_service_id, chr(65533)))
    OR (NOT plain AND (contains(r_service_id, chr(10)) OR contains(r_service_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_service_id) <> r_service_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END, '[^\x20-\x7E]'))
    OR (r_trip_headsign IS NULL)
    OR (NOT plain AND contains(r_trip_headsign, chr(65533)))
    OR (NOT plain AND (contains(r_trip_headsign, chr(10)) OR contains(r_trip_headsign, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_trip_headsign) <> r_trip_headsign)
    OR (NOT plain AND contains(r_trip_short_name, chr(65533)))
    OR (NOT plain AND (contains(r_trip_short_name, chr(10)) OR contains(r_trip_short_name, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_trip_short_name) <> r_trip_short_name)
    OR (NOT plain AND contains(r_direction_id, chr(65533)))
    OR (NOT plain AND (contains(r_direction_id, chr(10)) OR contains(r_direction_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_direction_id) <> r_direction_id)
    OR (r_direction_id IS NOT NULL AND p_direction_id IS NULL)
    OR (gtfs_validation_enum_name('GtfsTripDirectionId', p_direction_id) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_block_id, chr(65533)))
    OR (NOT plain AND (contains(r_block_id, chr(10)) OR contains(r_block_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_block_id) <> r_block_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_block_id ELSE gtfs_vc_trim(r_block_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_shape_id, chr(65533)))
    OR (NOT plain AND (contains(r_shape_id, chr(10)) OR contains(r_shape_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_id) <> r_shape_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_wheelchair_accessible, chr(65533)))
    OR (NOT plain AND (contains(r_wheelchair_accessible, chr(10)) OR contains(r_wheelchair_accessible, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_wheelchair_accessible) <> r_wheelchair_accessible)
    OR (r_wheelchair_accessible IS NOT NULL AND p_wheelchair_accessible IS NULL)
    OR (gtfs_validation_enum_name('GtfsWheelchairBoarding', p_wheelchair_accessible) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_bikes_allowed, chr(65533)))
    OR (NOT plain AND (contains(r_bikes_allowed, chr(10)) OR contains(r_bikes_allowed, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_bikes_allowed) <> r_bikes_allowed)
    OR (r_bikes_allowed IS NOT NULL AND p_bikes_allowed IS NULL)
    OR (gtfs_validation_enum_name('GtfsBikesAllowed', p_bikes_allowed) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_cars_allowed, chr(65533)))
    OR (NOT plain AND (contains(r_cars_allowed, chr(10)) OR contains(r_cars_allowed, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_cars_allowed) <> r_cars_allowed)
    OR (r_cars_allowed IS NOT NULL AND p_cars_allowed IS NULL)
    OR (gtfs_validation_enum_name('GtfsCarsAllowed', p_cars_allowed) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_safe_duration_factor, chr(65533)))
    OR (NOT plain AND (contains(r_safe_duration_factor, chr(10)) OR contains(r_safe_duration_factor, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_safe_duration_factor) <> r_safe_duration_factor)
    OR (r_safe_duration_factor IS NOT NULL AND p_safe_duration_factor IS NULL)
    OR (NOT plain AND contains(r_safe_duration_offset, chr(65533)))
    OR (NOT plain AND (contains(r_safe_duration_offset, chr(10)) OR contains(r_safe_duration_offset, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_safe_duration_offset) <> r_safe_duration_offset)
    OR (r_safe_duration_offset IS NOT NULL AND p_safe_duration_offset IS NULL)
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id') AS notice
  FROM w WHERE r_trip_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', r_trip_id) AS notice
  FROM w WHERE NOT plain AND contains(r_trip_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', r_trip_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_trip_id, chr(10)) OR contains(r_trip_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', r_trip_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_trip_id) <> r_trip_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id') AS notice
  FROM w WHERE r_route_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', r_route_id) AS notice
  FROM w WHERE NOT plain AND contains(r_route_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', r_route_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_route_id, chr(10)) OR contains(r_route_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', r_route_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_route_id) <> r_route_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'route_id', 'fieldValue', CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id') AS notice
  FROM w WHERE r_service_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND contains(r_service_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_service_id, chr(10)) OR contains(r_service_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_service_id) <> r_service_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_recommended_field' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_headsign') AS notice
  FROM w WHERE r_trip_headsign IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_headsign', 'fieldValue', r_trip_headsign) AS notice
  FROM w WHERE NOT plain AND contains(r_trip_headsign, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_headsign', 'fieldValue', r_trip_headsign) AS notice
  FROM w WHERE NOT plain AND (contains(r_trip_headsign, chr(10)) OR contains(r_trip_headsign, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_headsign', 'fieldValue', r_trip_headsign) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_trip_headsign) <> r_trip_headsign
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_short_name', 'fieldValue', r_trip_short_name) AS notice
  FROM w WHERE NOT plain AND contains(r_trip_short_name, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_short_name', 'fieldValue', r_trip_short_name) AS notice
  FROM w WHERE NOT plain AND (contains(r_trip_short_name, chr(10)) OR contains(r_trip_short_name, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_short_name', 'fieldValue', r_trip_short_name) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_trip_short_name) <> r_trip_short_name
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'direction_id', 'fieldValue', r_direction_id) AS notice
  FROM w WHERE NOT plain AND contains(r_direction_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'direction_id', 'fieldValue', r_direction_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_direction_id, chr(10)) OR contains(r_direction_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'direction_id', 'fieldValue', r_direction_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_direction_id) <> r_direction_id
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'direction_id', 'fieldValue', CASE WHEN plain THEN r_direction_id ELSE gtfs_vc_trim(r_direction_id) END) AS notice
  FROM w WHERE r_direction_id IS NOT NULL AND p_direction_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'direction_id', 'fieldValue', p_direction_id::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsTripDirectionId', p_direction_id) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'block_id', 'fieldValue', r_block_id) AS notice
  FROM w WHERE NOT plain AND contains(r_block_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'block_id', 'fieldValue', r_block_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_block_id, chr(10)) OR contains(r_block_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'block_id', 'fieldValue', r_block_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_block_id) <> r_block_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'block_id', 'fieldValue', CASE WHEN plain THEN r_block_id ELSE gtfs_vc_trim(r_block_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_block_id ELSE gtfs_vc_trim(r_block_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', r_shape_id) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', r_shape_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_id, chr(10)) OR contains(r_shape_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', r_shape_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_id) <> r_shape_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_accessible', 'fieldValue', r_wheelchair_accessible) AS notice
  FROM w WHERE NOT plain AND contains(r_wheelchair_accessible, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_accessible', 'fieldValue', r_wheelchair_accessible) AS notice
  FROM w WHERE NOT plain AND (contains(r_wheelchair_accessible, chr(10)) OR contains(r_wheelchair_accessible, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_accessible', 'fieldValue', r_wheelchair_accessible) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_wheelchair_accessible) <> r_wheelchair_accessible
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_accessible', 'fieldValue', CASE WHEN plain THEN r_wheelchair_accessible ELSE gtfs_vc_trim(r_wheelchair_accessible) END) AS notice
  FROM w WHERE r_wheelchair_accessible IS NOT NULL AND p_wheelchair_accessible IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wheelchair_accessible', 'fieldValue', p_wheelchair_accessible::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsWheelchairBoarding', p_wheelchair_accessible) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'bikes_allowed', 'fieldValue', r_bikes_allowed) AS notice
  FROM w WHERE NOT plain AND contains(r_bikes_allowed, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'bikes_allowed', 'fieldValue', r_bikes_allowed) AS notice
  FROM w WHERE NOT plain AND (contains(r_bikes_allowed, chr(10)) OR contains(r_bikes_allowed, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'bikes_allowed', 'fieldValue', r_bikes_allowed) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_bikes_allowed) <> r_bikes_allowed
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'bikes_allowed', 'fieldValue', CASE WHEN plain THEN r_bikes_allowed ELSE gtfs_vc_trim(r_bikes_allowed) END) AS notice
  FROM w WHERE r_bikes_allowed IS NOT NULL AND p_bikes_allowed IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'bikes_allowed', 'fieldValue', p_bikes_allowed::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsBikesAllowed', p_bikes_allowed) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cars_allowed', 'fieldValue', r_cars_allowed) AS notice
  FROM w WHERE NOT plain AND contains(r_cars_allowed, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cars_allowed', 'fieldValue', r_cars_allowed) AS notice
  FROM w WHERE NOT plain AND (contains(r_cars_allowed, chr(10)) OR contains(r_cars_allowed, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cars_allowed', 'fieldValue', r_cars_allowed) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_cars_allowed) <> r_cars_allowed
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cars_allowed', 'fieldValue', CASE WHEN plain THEN r_cars_allowed ELSE gtfs_vc_trim(r_cars_allowed) END) AS notice
  FROM w WHERE r_cars_allowed IS NOT NULL AND p_cars_allowed IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'cars_allowed', 'fieldValue', p_cars_allowed::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCarsAllowed', p_cars_allowed) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_factor', 'fieldValue', r_safe_duration_factor) AS notice
  FROM w WHERE NOT plain AND contains(r_safe_duration_factor, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_factor', 'fieldValue', r_safe_duration_factor) AS notice
  FROM w WHERE NOT plain AND (contains(r_safe_duration_factor, chr(10)) OR contains(r_safe_duration_factor, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_factor', 'fieldValue', r_safe_duration_factor) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_safe_duration_factor) <> r_safe_duration_factor
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_factor', 'fieldValue', CASE WHEN plain THEN r_safe_duration_factor ELSE gtfs_vc_trim(r_safe_duration_factor) END) AS notice
  FROM w WHERE r_safe_duration_factor IS NOT NULL AND p_safe_duration_factor IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_offset', 'fieldValue', r_safe_duration_offset) AS notice
  FROM w WHERE NOT plain AND contains(r_safe_duration_offset, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_offset', 'fieldValue', r_safe_duration_offset) AS notice
  FROM w WHERE NOT plain AND (contains(r_safe_duration_offset, chr(10)) OR contains(r_safe_duration_offset, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_offset', 'fieldValue', r_safe_duration_offset) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_safe_duration_offset) <> r_safe_duration_offset
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'trips.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'safe_duration_offset', 'fieldValue', CASE WHEN plain THEN r_safe_duration_offset ELSE gtfs_vc_trim(r_safe_duration_offset) END) AS notice
  FROM w WHERE r_safe_duration_offset IS NOT NULL AND p_safe_duration_offset IS NULL
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of trips.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_trips() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END)::VARCHAR AS trip_id,
  (CASE WHEN plain THEN r_route_id ELSE gtfs_vc_trim(r_route_id) END)::VARCHAR AS route_id,
  (CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END)::VARCHAR AS service_id,
  (CASE WHEN plain THEN r_trip_headsign ELSE gtfs_vc_trim(r_trip_headsign) END)::VARCHAR AS trip_headsign,
  (CASE WHEN plain THEN r_trip_short_name ELSE gtfs_vc_trim(r_trip_short_name) END)::VARCHAR AS trip_short_name,
  p_direction_id AS direction_id,
  (CASE WHEN plain THEN r_block_id ELSE gtfs_vc_trim(r_block_id) END)::VARCHAR AS block_id,
  (CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END)::VARCHAR AS shape_id,
  p_wheelchair_accessible AS wheelchair_accessible,
  p_bikes_allowed AS bikes_allowed,
  p_cars_allowed AS cars_allowed,
  p_safe_duration_factor AS safe_duration_factor,
  p_safe_duration_offset AS safe_duration_offset
FROM gtfs_vc_wide_trips w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of stop_times.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_stop_times() AS TABLE
SELECT csv_row_number,
  plain,
  r_trip_id,
  r_arrival_time,
  gtfs_vc_time(CASE WHEN plain THEN r_arrival_time ELSE gtfs_vc_trim(r_arrival_time) END) AS p_arrival_time,
  r_departure_time,
  gtfs_vc_time(CASE WHEN plain THEN r_departure_time ELSE gtfs_vc_trim(r_departure_time) END) AS p_departure_time,
  r_stop_id,
  r_location_group_id,
  r_location_id,
  r_stop_sequence,
  gtfs_vc_int(CASE WHEN plain THEN r_stop_sequence ELSE gtfs_vc_trim(r_stop_sequence) END) AS p_stop_sequence,
  r_stop_headsign,
  r_start_pickup_drop_off_window,
  gtfs_vc_time(CASE WHEN plain THEN r_start_pickup_drop_off_window ELSE gtfs_vc_trim(r_start_pickup_drop_off_window) END) AS p_start_pickup_drop_off_window,
  r_end_pickup_drop_off_window,
  gtfs_vc_time(CASE WHEN plain THEN r_end_pickup_drop_off_window ELSE gtfs_vc_trim(r_end_pickup_drop_off_window) END) AS p_end_pickup_drop_off_window,
  r_pickup_type,
  gtfs_vc_int(CASE WHEN plain THEN r_pickup_type ELSE gtfs_vc_trim(r_pickup_type) END) AS p_pickup_type,
  r_drop_off_type,
  gtfs_vc_int(CASE WHEN plain THEN r_drop_off_type ELSE gtfs_vc_trim(r_drop_off_type) END) AS p_drop_off_type,
  r_continuous_pickup,
  gtfs_vc_int(CASE WHEN plain THEN r_continuous_pickup ELSE gtfs_vc_trim(r_continuous_pickup) END) AS p_continuous_pickup,
  r_continuous_drop_off,
  gtfs_vc_int(CASE WHEN plain THEN r_continuous_drop_off ELSE gtfs_vc_trim(r_continuous_drop_off) END) AS p_continuous_drop_off,
  r_shape_dist_traveled,
  gtfs_vc_double(CASE WHEN plain THEN r_shape_dist_traveled ELSE gtfs_vc_trim(r_shape_dist_traveled) END) AS p_shape_dist_traveled,
  r_timepoint,
  gtfs_vc_int(CASE WHEN plain THEN r_timepoint ELSE gtfs_vc_trim(r_timepoint) END) AS p_timepoint,
  r_pickup_booking_rule_id,
  r_drop_off_booking_rule_id
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_trip_id,
    d.fields[p.pos[2]] AS r_arrival_time,
    d.fields[p.pos[3]] AS r_departure_time,
    d.fields[p.pos[4]] AS r_stop_id,
    d.fields[p.pos[5]] AS r_location_group_id,
    d.fields[p.pos[6]] AS r_location_id,
    d.fields[p.pos[7]] AS r_stop_sequence,
    d.fields[p.pos[8]] AS r_stop_headsign,
    d.fields[p.pos[9]] AS r_start_pickup_drop_off_window,
    d.fields[p.pos[10]] AS r_end_pickup_drop_off_window,
    d.fields[p.pos[11]] AS r_pickup_type,
    d.fields[p.pos[12]] AS r_drop_off_type,
    d.fields[p.pos[13]] AS r_continuous_pickup,
    d.fields[p.pos[14]] AS r_continuous_drop_off,
    d.fields[p.pos[15]] AS r_shape_dist_traveled,
    d.fields[p.pos[16]] AS r_timepoint,
    d.fields[p.pos[17]] AS r_pickup_booking_rule_id,
    d.fields[p.pos[18]] AS r_drop_off_booking_rule_id
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of stop_times.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_stop_times() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_stop_times
  WHERE (r_trip_id IS NULL)
    OR (NOT plain AND contains(r_trip_id, chr(65533)))
    OR (NOT plain AND (contains(r_trip_id, chr(10)) OR contains(r_trip_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_trip_id) <> r_trip_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_arrival_time, chr(65533)))
    OR (NOT plain AND (contains(r_arrival_time, chr(10)) OR contains(r_arrival_time, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_arrival_time) <> r_arrival_time)
    OR (r_arrival_time IS NOT NULL AND p_arrival_time IS NULL)
    OR (NOT plain AND contains(r_departure_time, chr(65533)))
    OR (NOT plain AND (contains(r_departure_time, chr(10)) OR contains(r_departure_time, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_departure_time) <> r_departure_time)
    OR (r_departure_time IS NOT NULL AND p_departure_time IS NULL)
    OR (NOT plain AND contains(r_stop_id, chr(65533)))
    OR (NOT plain AND (contains(r_stop_id, chr(10)) OR contains(r_stop_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_id) <> r_stop_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_location_group_id, chr(65533)))
    OR (NOT plain AND (contains(r_location_group_id, chr(10)) OR contains(r_location_group_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_location_group_id) <> r_location_group_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_location_group_id ELSE gtfs_vc_trim(r_location_group_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_location_id, chr(65533)))
    OR (NOT plain AND (contains(r_location_id, chr(10)) OR contains(r_location_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_location_id) <> r_location_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_location_id ELSE gtfs_vc_trim(r_location_id) END, '[^\x20-\x7E]'))
    OR (r_stop_sequence IS NULL)
    OR (NOT plain AND contains(r_stop_sequence, chr(65533)))
    OR (NOT plain AND (contains(r_stop_sequence, chr(10)) OR contains(r_stop_sequence, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_sequence) <> r_stop_sequence)
    OR (r_stop_sequence IS NOT NULL AND p_stop_sequence IS NULL)
    OR (p_stop_sequence < 0)
    OR (NOT plain AND contains(r_stop_headsign, chr(65533)))
    OR (NOT plain AND (contains(r_stop_headsign, chr(10)) OR contains(r_stop_headsign, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_stop_headsign) <> r_stop_headsign)
    OR (NOT plain AND contains(r_start_pickup_drop_off_window, chr(65533)))
    OR (NOT plain AND (contains(r_start_pickup_drop_off_window, chr(10)) OR contains(r_start_pickup_drop_off_window, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_start_pickup_drop_off_window) <> r_start_pickup_drop_off_window)
    OR (r_start_pickup_drop_off_window IS NOT NULL AND p_start_pickup_drop_off_window IS NULL)
    OR (NOT plain AND contains(r_end_pickup_drop_off_window, chr(65533)))
    OR (NOT plain AND (contains(r_end_pickup_drop_off_window, chr(10)) OR contains(r_end_pickup_drop_off_window, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_end_pickup_drop_off_window) <> r_end_pickup_drop_off_window)
    OR (r_end_pickup_drop_off_window IS NOT NULL AND p_end_pickup_drop_off_window IS NULL)
    OR (NOT plain AND contains(r_pickup_type, chr(65533)))
    OR (NOT plain AND (contains(r_pickup_type, chr(10)) OR contains(r_pickup_type, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_pickup_type) <> r_pickup_type)
    OR (r_pickup_type IS NOT NULL AND p_pickup_type IS NULL)
    OR (gtfs_validation_enum_name('GtfsPickupDropOff', p_pickup_type) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_drop_off_type, chr(65533)))
    OR (NOT plain AND (contains(r_drop_off_type, chr(10)) OR contains(r_drop_off_type, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_drop_off_type) <> r_drop_off_type)
    OR (r_drop_off_type IS NOT NULL AND p_drop_off_type IS NULL)
    OR (gtfs_validation_enum_name('GtfsPickupDropOff', p_drop_off_type) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_continuous_pickup, chr(65533)))
    OR (NOT plain AND (contains(r_continuous_pickup, chr(10)) OR contains(r_continuous_pickup, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_continuous_pickup) <> r_continuous_pickup)
    OR (r_continuous_pickup IS NOT NULL AND p_continuous_pickup IS NULL)
    OR (gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_pickup) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_continuous_drop_off, chr(65533)))
    OR (NOT plain AND (contains(r_continuous_drop_off, chr(10)) OR contains(r_continuous_drop_off, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_continuous_drop_off) <> r_continuous_drop_off)
    OR (r_continuous_drop_off IS NOT NULL AND p_continuous_drop_off IS NULL)
    OR (gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_drop_off) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_shape_dist_traveled, chr(65533)))
    OR (NOT plain AND (contains(r_shape_dist_traveled, chr(10)) OR contains(r_shape_dist_traveled, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_dist_traveled) <> r_shape_dist_traveled)
    OR (r_shape_dist_traveled IS NOT NULL AND p_shape_dist_traveled IS NULL)
    OR (gtfs_vc_cmp0('float', NULL::INTEGER, p_shape_dist_traveled) < 0)
    OR (NOT plain AND contains(r_timepoint, chr(65533)))
    OR (NOT plain AND (contains(r_timepoint, chr(10)) OR contains(r_timepoint, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_timepoint) <> r_timepoint)
    OR (r_timepoint IS NOT NULL AND p_timepoint IS NULL)
    OR (gtfs_validation_enum_name('GtfsStopTimeTimepoint', p_timepoint) = 'UNRECOGNIZED')
    OR (NOT plain AND contains(r_pickup_booking_rule_id, chr(65533)))
    OR (NOT plain AND (contains(r_pickup_booking_rule_id, chr(10)) OR contains(r_pickup_booking_rule_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_pickup_booking_rule_id) <> r_pickup_booking_rule_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_pickup_booking_rule_id ELSE gtfs_vc_trim(r_pickup_booking_rule_id) END, '[^\x20-\x7E]'))
    OR (NOT plain AND contains(r_drop_off_booking_rule_id, chr(65533)))
    OR (NOT plain AND (contains(r_drop_off_booking_rule_id, chr(10)) OR contains(r_drop_off_booking_rule_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_drop_off_booking_rule_id) <> r_drop_off_booking_rule_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_drop_off_booking_rule_id ELSE gtfs_vc_trim(r_drop_off_booking_rule_id) END, '[^\x20-\x7E]'))
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id') AS notice
  FROM w WHERE r_trip_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', r_trip_id) AS notice
  FROM w WHERE NOT plain AND contains(r_trip_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', r_trip_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_trip_id, chr(10)) OR contains(r_trip_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', r_trip_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_trip_id) <> r_trip_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'trip_id', 'fieldValue', CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'arrival_time', 'fieldValue', r_arrival_time) AS notice
  FROM w WHERE NOT plain AND contains(r_arrival_time, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'arrival_time', 'fieldValue', r_arrival_time) AS notice
  FROM w WHERE NOT plain AND (contains(r_arrival_time, chr(10)) OR contains(r_arrival_time, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'arrival_time', 'fieldValue', r_arrival_time) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_arrival_time) <> r_arrival_time
  UNION ALL
  SELECT csv_row_number, 'invalid_time' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'arrival_time', 'fieldValue', CASE WHEN plain THEN r_arrival_time ELSE gtfs_vc_trim(r_arrival_time) END) AS notice
  FROM w WHERE r_arrival_time IS NOT NULL AND p_arrival_time IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'departure_time', 'fieldValue', r_departure_time) AS notice
  FROM w WHERE NOT plain AND contains(r_departure_time, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'departure_time', 'fieldValue', r_departure_time) AS notice
  FROM w WHERE NOT plain AND (contains(r_departure_time, chr(10)) OR contains(r_departure_time, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'departure_time', 'fieldValue', r_departure_time) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_departure_time) <> r_departure_time
  UNION ALL
  SELECT csv_row_number, 'invalid_time' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'departure_time', 'fieldValue', CASE WHEN plain THEN r_departure_time ELSE gtfs_vc_trim(r_departure_time) END) AS notice
  FROM w WHERE r_departure_time IS NOT NULL AND p_departure_time IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', r_stop_id) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', r_stop_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_id, chr(10)) OR contains(r_stop_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', r_stop_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_id) <> r_stop_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_id', 'fieldValue', CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_group_id', 'fieldValue', r_location_group_id) AS notice
  FROM w WHERE NOT plain AND contains(r_location_group_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_group_id', 'fieldValue', r_location_group_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_location_group_id, chr(10)) OR contains(r_location_group_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_group_id', 'fieldValue', r_location_group_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_location_group_id) <> r_location_group_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_group_id', 'fieldValue', CASE WHEN plain THEN r_location_group_id ELSE gtfs_vc_trim(r_location_group_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_location_group_id ELSE gtfs_vc_trim(r_location_group_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_id', 'fieldValue', r_location_id) AS notice
  FROM w WHERE NOT plain AND contains(r_location_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_id', 'fieldValue', r_location_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_location_id, chr(10)) OR contains(r_location_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_id', 'fieldValue', r_location_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_location_id) <> r_location_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'location_id', 'fieldValue', CASE WHEN plain THEN r_location_id ELSE gtfs_vc_trim(r_location_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_location_id ELSE gtfs_vc_trim(r_location_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_sequence') AS notice
  FROM w WHERE r_stop_sequence IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_sequence', 'fieldValue', r_stop_sequence) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_sequence, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_sequence', 'fieldValue', r_stop_sequence) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_sequence, chr(10)) OR contains(r_stop_sequence, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_sequence', 'fieldValue', r_stop_sequence) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_sequence) <> r_stop_sequence
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_sequence', 'fieldValue', CASE WHEN plain THEN r_stop_sequence ELSE gtfs_vc_trim(r_stop_sequence) END) AS notice
  FROM w WHERE r_stop_sequence IS NOT NULL AND p_stop_sequence IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_sequence', 'fieldType', 'non-negative integer', 'fieldValue', to_json(p_stop_sequence::INTEGER)) AS notice
  FROM w WHERE p_stop_sequence < 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_headsign', 'fieldValue', r_stop_headsign) AS notice
  FROM w WHERE NOT plain AND contains(r_stop_headsign, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_headsign', 'fieldValue', r_stop_headsign) AS notice
  FROM w WHERE NOT plain AND (contains(r_stop_headsign, chr(10)) OR contains(r_stop_headsign, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'stop_headsign', 'fieldValue', r_stop_headsign) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_stop_headsign) <> r_stop_headsign
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_pickup_drop_off_window', 'fieldValue', r_start_pickup_drop_off_window) AS notice
  FROM w WHERE NOT plain AND contains(r_start_pickup_drop_off_window, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_pickup_drop_off_window', 'fieldValue', r_start_pickup_drop_off_window) AS notice
  FROM w WHERE NOT plain AND (contains(r_start_pickup_drop_off_window, chr(10)) OR contains(r_start_pickup_drop_off_window, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_pickup_drop_off_window', 'fieldValue', r_start_pickup_drop_off_window) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_start_pickup_drop_off_window) <> r_start_pickup_drop_off_window
  UNION ALL
  SELECT csv_row_number, 'invalid_time' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_pickup_drop_off_window', 'fieldValue', CASE WHEN plain THEN r_start_pickup_drop_off_window ELSE gtfs_vc_trim(r_start_pickup_drop_off_window) END) AS notice
  FROM w WHERE r_start_pickup_drop_off_window IS NOT NULL AND p_start_pickup_drop_off_window IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_pickup_drop_off_window', 'fieldValue', r_end_pickup_drop_off_window) AS notice
  FROM w WHERE NOT plain AND contains(r_end_pickup_drop_off_window, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_pickup_drop_off_window', 'fieldValue', r_end_pickup_drop_off_window) AS notice
  FROM w WHERE NOT plain AND (contains(r_end_pickup_drop_off_window, chr(10)) OR contains(r_end_pickup_drop_off_window, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_pickup_drop_off_window', 'fieldValue', r_end_pickup_drop_off_window) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_end_pickup_drop_off_window) <> r_end_pickup_drop_off_window
  UNION ALL
  SELECT csv_row_number, 'invalid_time' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_pickup_drop_off_window', 'fieldValue', CASE WHEN plain THEN r_end_pickup_drop_off_window ELSE gtfs_vc_trim(r_end_pickup_drop_off_window) END) AS notice
  FROM w WHERE r_end_pickup_drop_off_window IS NOT NULL AND p_end_pickup_drop_off_window IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_type', 'fieldValue', r_pickup_type) AS notice
  FROM w WHERE NOT plain AND contains(r_pickup_type, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_type', 'fieldValue', r_pickup_type) AS notice
  FROM w WHERE NOT plain AND (contains(r_pickup_type, chr(10)) OR contains(r_pickup_type, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_type', 'fieldValue', r_pickup_type) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_pickup_type) <> r_pickup_type
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_type', 'fieldValue', CASE WHEN plain THEN r_pickup_type ELSE gtfs_vc_trim(r_pickup_type) END) AS notice
  FROM w WHERE r_pickup_type IS NOT NULL AND p_pickup_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_type', 'fieldValue', p_pickup_type::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsPickupDropOff', p_pickup_type) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_type', 'fieldValue', r_drop_off_type) AS notice
  FROM w WHERE NOT plain AND contains(r_drop_off_type, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_type', 'fieldValue', r_drop_off_type) AS notice
  FROM w WHERE NOT plain AND (contains(r_drop_off_type, chr(10)) OR contains(r_drop_off_type, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_type', 'fieldValue', r_drop_off_type) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_drop_off_type) <> r_drop_off_type
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_type', 'fieldValue', CASE WHEN plain THEN r_drop_off_type ELSE gtfs_vc_trim(r_drop_off_type) END) AS notice
  FROM w WHERE r_drop_off_type IS NOT NULL AND p_drop_off_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_type', 'fieldValue', p_drop_off_type::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsPickupDropOff', p_drop_off_type) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', r_continuous_pickup) AS notice
  FROM w WHERE NOT plain AND contains(r_continuous_pickup, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', r_continuous_pickup) AS notice
  FROM w WHERE NOT plain AND (contains(r_continuous_pickup, chr(10)) OR contains(r_continuous_pickup, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', r_continuous_pickup) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_continuous_pickup) <> r_continuous_pickup
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', CASE WHEN plain THEN r_continuous_pickup ELSE gtfs_vc_trim(r_continuous_pickup) END) AS notice
  FROM w WHERE r_continuous_pickup IS NOT NULL AND p_continuous_pickup IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_pickup', 'fieldValue', p_continuous_pickup::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_pickup) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', r_continuous_drop_off) AS notice
  FROM w WHERE NOT plain AND contains(r_continuous_drop_off, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', r_continuous_drop_off) AS notice
  FROM w WHERE NOT plain AND (contains(r_continuous_drop_off, chr(10)) OR contains(r_continuous_drop_off, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', r_continuous_drop_off) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_continuous_drop_off) <> r_continuous_drop_off
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', CASE WHEN plain THEN r_continuous_drop_off ELSE gtfs_vc_trim(r_continuous_drop_off) END) AS notice
  FROM w WHERE r_continuous_drop_off IS NOT NULL AND p_continuous_drop_off IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'continuous_drop_off', 'fieldValue', p_continuous_drop_off::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsContinuousPickupDropOff', p_continuous_drop_off) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', r_shape_dist_traveled) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_dist_traveled, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', r_shape_dist_traveled) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_dist_traveled, chr(10)) OR contains(r_shape_dist_traveled, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', r_shape_dist_traveled) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_dist_traveled) <> r_shape_dist_traveled
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', CASE WHEN plain THEN r_shape_dist_traveled ELSE gtfs_vc_trim(r_shape_dist_traveled) END) AS notice
  FROM w WHERE r_shape_dist_traveled IS NOT NULL AND p_shape_dist_traveled IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldType', 'non-negative float', 'fieldValue', to_json(p_shape_dist_traveled)) AS notice
  FROM w WHERE gtfs_vc_cmp0('float', NULL::INTEGER, p_shape_dist_traveled) < 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'timepoint', 'fieldValue', r_timepoint) AS notice
  FROM w WHERE NOT plain AND contains(r_timepoint, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'timepoint', 'fieldValue', r_timepoint) AS notice
  FROM w WHERE NOT plain AND (contains(r_timepoint, chr(10)) OR contains(r_timepoint, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'timepoint', 'fieldValue', r_timepoint) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_timepoint) <> r_timepoint
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'timepoint', 'fieldValue', CASE WHEN plain THEN r_timepoint ELSE gtfs_vc_trim(r_timepoint) END) AS notice
  FROM w WHERE r_timepoint IS NOT NULL AND p_timepoint IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'timepoint', 'fieldValue', p_timepoint::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsStopTimeTimepoint', p_timepoint) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_booking_rule_id', 'fieldValue', r_pickup_booking_rule_id) AS notice
  FROM w WHERE NOT plain AND contains(r_pickup_booking_rule_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_booking_rule_id', 'fieldValue', r_pickup_booking_rule_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_pickup_booking_rule_id, chr(10)) OR contains(r_pickup_booking_rule_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_booking_rule_id', 'fieldValue', r_pickup_booking_rule_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_pickup_booking_rule_id) <> r_pickup_booking_rule_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'pickup_booking_rule_id', 'fieldValue', CASE WHEN plain THEN r_pickup_booking_rule_id ELSE gtfs_vc_trim(r_pickup_booking_rule_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_pickup_booking_rule_id ELSE gtfs_vc_trim(r_pickup_booking_rule_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_booking_rule_id', 'fieldValue', r_drop_off_booking_rule_id) AS notice
  FROM w WHERE NOT plain AND contains(r_drop_off_booking_rule_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_booking_rule_id', 'fieldValue', r_drop_off_booking_rule_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_drop_off_booking_rule_id, chr(10)) OR contains(r_drop_off_booking_rule_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_booking_rule_id', 'fieldValue', r_drop_off_booking_rule_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_drop_off_booking_rule_id) <> r_drop_off_booking_rule_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'stop_times.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'drop_off_booking_rule_id', 'fieldValue', CASE WHEN plain THEN r_drop_off_booking_rule_id ELSE gtfs_vc_trim(r_drop_off_booking_rule_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_drop_off_booking_rule_id ELSE gtfs_vc_trim(r_drop_off_booking_rule_id) END, '[^\x20-\x7E]')
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of stop_times.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_stop_times() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_trip_id ELSE gtfs_vc_trim(r_trip_id) END)::VARCHAR AS trip_id,
  p_arrival_time AS arrival_time,
  p_departure_time AS departure_time,
  (CASE WHEN plain THEN r_stop_id ELSE gtfs_vc_trim(r_stop_id) END)::VARCHAR AS stop_id,
  (CASE WHEN plain THEN r_location_group_id ELSE gtfs_vc_trim(r_location_group_id) END)::VARCHAR AS location_group_id,
  (CASE WHEN plain THEN r_location_id ELSE gtfs_vc_trim(r_location_id) END)::VARCHAR AS location_id,
  p_stop_sequence AS stop_sequence,
  (CASE WHEN plain THEN r_stop_headsign ELSE gtfs_vc_trim(r_stop_headsign) END)::VARCHAR AS stop_headsign,
  p_start_pickup_drop_off_window AS start_pickup_drop_off_window,
  p_end_pickup_drop_off_window AS end_pickup_drop_off_window,
  p_pickup_type AS pickup_type,
  p_drop_off_type AS drop_off_type,
  p_continuous_pickup AS continuous_pickup,
  p_continuous_drop_off AS continuous_drop_off,
  p_shape_dist_traveled AS shape_dist_traveled,
  p_timepoint AS timepoint,
  (CASE WHEN plain THEN r_pickup_booking_rule_id ELSE gtfs_vc_trim(r_pickup_booking_rule_id) END)::VARCHAR AS pickup_booking_rule_id,
  (CASE WHEN plain THEN r_drop_off_booking_rule_id ELSE gtfs_vc_trim(r_drop_off_booking_rule_id) END)::VARCHAR AS drop_off_booking_rule_id
FROM gtfs_vc_wide_stop_times w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of shapes.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_shapes() AS TABLE
SELECT csv_row_number,
  plain,
  r_shape_id,
  r_shape_pt_lat,
  gtfs_vc_double(CASE WHEN plain THEN r_shape_pt_lat ELSE gtfs_vc_trim(r_shape_pt_lat) END) AS p_shape_pt_lat,
  r_shape_pt_lon,
  gtfs_vc_double(CASE WHEN plain THEN r_shape_pt_lon ELSE gtfs_vc_trim(r_shape_pt_lon) END) AS p_shape_pt_lon,
  r_shape_pt_sequence,
  gtfs_vc_int(CASE WHEN plain THEN r_shape_pt_sequence ELSE gtfs_vc_trim(r_shape_pt_sequence) END) AS p_shape_pt_sequence,
  r_shape_dist_traveled,
  gtfs_vc_double(CASE WHEN plain THEN r_shape_dist_traveled ELSE gtfs_vc_trim(r_shape_dist_traveled) END) AS p_shape_dist_traveled
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_shape_id,
    d.fields[p.pos[2]] AS r_shape_pt_lat,
    d.fields[p.pos[3]] AS r_shape_pt_lon,
    d.fields[p.pos[4]] AS r_shape_pt_sequence,
    d.fields[p.pos[5]] AS r_shape_dist_traveled
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of shapes.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_shapes() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_shapes
  WHERE (r_shape_id IS NULL)
    OR (NOT plain AND contains(r_shape_id, chr(65533)))
    OR (NOT plain AND (contains(r_shape_id, chr(10)) OR contains(r_shape_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_id) <> r_shape_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END, '[^\x20-\x7E]'))
    OR (r_shape_pt_lat IS NULL)
    OR (NOT plain AND contains(r_shape_pt_lat, chr(65533)))
    OR (NOT plain AND (contains(r_shape_pt_lat, chr(10)) OR contains(r_shape_pt_lat, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_pt_lat) <> r_shape_pt_lat)
    OR (r_shape_pt_lat IS NOT NULL AND p_shape_pt_lat IS NULL)
    OR (isnan(p_shape_pt_lat) OR NOT (-90 <= p_shape_pt_lat AND p_shape_pt_lat <= 90))
    OR (r_shape_pt_lon IS NULL)
    OR (NOT plain AND contains(r_shape_pt_lon, chr(65533)))
    OR (NOT plain AND (contains(r_shape_pt_lon, chr(10)) OR contains(r_shape_pt_lon, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_pt_lon) <> r_shape_pt_lon)
    OR (r_shape_pt_lon IS NOT NULL AND p_shape_pt_lon IS NULL)
    OR (isnan(p_shape_pt_lon) OR NOT (-180 <= p_shape_pt_lon AND p_shape_pt_lon <= 180))
    OR (r_shape_pt_sequence IS NULL)
    OR (NOT plain AND contains(r_shape_pt_sequence, chr(65533)))
    OR (NOT plain AND (contains(r_shape_pt_sequence, chr(10)) OR contains(r_shape_pt_sequence, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_pt_sequence) <> r_shape_pt_sequence)
    OR (r_shape_pt_sequence IS NOT NULL AND p_shape_pt_sequence IS NULL)
    OR (p_shape_pt_sequence < 0)
    OR (NOT plain AND contains(r_shape_dist_traveled, chr(65533)))
    OR (NOT plain AND (contains(r_shape_dist_traveled, chr(10)) OR contains(r_shape_dist_traveled, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_shape_dist_traveled) <> r_shape_dist_traveled)
    OR (r_shape_dist_traveled IS NOT NULL AND p_shape_dist_traveled IS NULL)
    OR (gtfs_vc_cmp0('float', NULL::INTEGER, p_shape_dist_traveled) < 0)
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id') AS notice
  FROM w WHERE r_shape_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', r_shape_id) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', r_shape_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_id, chr(10)) OR contains(r_shape_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', r_shape_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_id) <> r_shape_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_id', 'fieldValue', CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lat') AS notice
  FROM w WHERE r_shape_pt_lat IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lat', 'fieldValue', r_shape_pt_lat) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_pt_lat, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lat', 'fieldValue', r_shape_pt_lat) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_pt_lat, chr(10)) OR contains(r_shape_pt_lat, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lat', 'fieldValue', r_shape_pt_lat) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_pt_lat) <> r_shape_pt_lat
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lat', 'fieldValue', CASE WHEN plain THEN r_shape_pt_lat ELSE gtfs_vc_trim(r_shape_pt_lat) END) AS notice
  FROM w WHERE r_shape_pt_lat IS NOT NULL AND p_shape_pt_lat IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lat', 'fieldType', 'latitude within [-90, 90]', 'fieldValue', to_json(p_shape_pt_lat)) AS notice
  FROM w WHERE isnan(p_shape_pt_lat) OR NOT (-90 <= p_shape_pt_lat AND p_shape_pt_lat <= 90)
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lon') AS notice
  FROM w WHERE r_shape_pt_lon IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lon', 'fieldValue', r_shape_pt_lon) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_pt_lon, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lon', 'fieldValue', r_shape_pt_lon) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_pt_lon, chr(10)) OR contains(r_shape_pt_lon, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lon', 'fieldValue', r_shape_pt_lon) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_pt_lon) <> r_shape_pt_lon
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lon', 'fieldValue', CASE WHEN plain THEN r_shape_pt_lon ELSE gtfs_vc_trim(r_shape_pt_lon) END) AS notice
  FROM w WHERE r_shape_pt_lon IS NOT NULL AND p_shape_pt_lon IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_lon', 'fieldType', 'longitude within [-180, 180]', 'fieldValue', to_json(p_shape_pt_lon)) AS notice
  FROM w WHERE isnan(p_shape_pt_lon) OR NOT (-180 <= p_shape_pt_lon AND p_shape_pt_lon <= 180)
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_sequence') AS notice
  FROM w WHERE r_shape_pt_sequence IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_sequence', 'fieldValue', r_shape_pt_sequence) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_pt_sequence, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_sequence', 'fieldValue', r_shape_pt_sequence) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_pt_sequence, chr(10)) OR contains(r_shape_pt_sequence, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_sequence', 'fieldValue', r_shape_pt_sequence) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_pt_sequence) <> r_shape_pt_sequence
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_sequence', 'fieldValue', CASE WHEN plain THEN r_shape_pt_sequence ELSE gtfs_vc_trim(r_shape_pt_sequence) END) AS notice
  FROM w WHERE r_shape_pt_sequence IS NOT NULL AND p_shape_pt_sequence IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_pt_sequence', 'fieldType', 'non-negative integer', 'fieldValue', to_json(p_shape_pt_sequence::INTEGER)) AS notice
  FROM w WHERE p_shape_pt_sequence < 0
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', r_shape_dist_traveled) AS notice
  FROM w WHERE NOT plain AND contains(r_shape_dist_traveled, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', r_shape_dist_traveled) AS notice
  FROM w WHERE NOT plain AND (contains(r_shape_dist_traveled, chr(10)) OR contains(r_shape_dist_traveled, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', r_shape_dist_traveled) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_shape_dist_traveled) <> r_shape_dist_traveled
  UNION ALL
  SELECT csv_row_number, 'invalid_float' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldValue', CASE WHEN plain THEN r_shape_dist_traveled ELSE gtfs_vc_trim(r_shape_dist_traveled) END) AS notice
  FROM w WHERE r_shape_dist_traveled IS NOT NULL AND p_shape_dist_traveled IS NULL
  UNION ALL
  SELECT csv_row_number, 'number_out_of_range' AS code,
    json_object('filename', 'shapes.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'shape_dist_traveled', 'fieldType', 'non-negative float', 'fieldValue', to_json(p_shape_dist_traveled)) AS notice
  FROM w WHERE gtfs_vc_cmp0('float', NULL::INTEGER, p_shape_dist_traveled) < 0
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of shapes.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_shapes() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_shape_id ELSE gtfs_vc_trim(r_shape_id) END)::VARCHAR AS shape_id,
  p_shape_pt_lat AS shape_pt_lat,
  p_shape_pt_lon AS shape_pt_lon,
  p_shape_pt_sequence AS shape_pt_sequence,
  p_shape_dist_traveled AS shape_dist_traveled
FROM gtfs_vc_wide_shapes w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of calendar.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_calendar() AS TABLE
SELECT csv_row_number,
  plain,
  r_service_id,
  r_monday,
  gtfs_vc_int(CASE WHEN plain THEN r_monday ELSE gtfs_vc_trim(r_monday) END) AS p_monday,
  r_tuesday,
  gtfs_vc_int(CASE WHEN plain THEN r_tuesday ELSE gtfs_vc_trim(r_tuesday) END) AS p_tuesday,
  r_wednesday,
  gtfs_vc_int(CASE WHEN plain THEN r_wednesday ELSE gtfs_vc_trim(r_wednesday) END) AS p_wednesday,
  r_thursday,
  gtfs_vc_int(CASE WHEN plain THEN r_thursday ELSE gtfs_vc_trim(r_thursday) END) AS p_thursday,
  r_friday,
  gtfs_vc_int(CASE WHEN plain THEN r_friday ELSE gtfs_vc_trim(r_friday) END) AS p_friday,
  r_saturday,
  gtfs_vc_int(CASE WHEN plain THEN r_saturday ELSE gtfs_vc_trim(r_saturday) END) AS p_saturday,
  r_sunday,
  gtfs_vc_int(CASE WHEN plain THEN r_sunday ELSE gtfs_vc_trim(r_sunday) END) AS p_sunday,
  r_start_date,
  gtfs_vc_date(CASE WHEN plain THEN r_start_date ELSE gtfs_vc_trim(r_start_date) END) AS p_start_date,
  r_end_date,
  gtfs_vc_date(CASE WHEN plain THEN r_end_date ELSE gtfs_vc_trim(r_end_date) END) AS p_end_date
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_service_id,
    d.fields[p.pos[2]] AS r_monday,
    d.fields[p.pos[3]] AS r_tuesday,
    d.fields[p.pos[4]] AS r_wednesday,
    d.fields[p.pos[5]] AS r_thursday,
    d.fields[p.pos[6]] AS r_friday,
    d.fields[p.pos[7]] AS r_saturday,
    d.fields[p.pos[8]] AS r_sunday,
    d.fields[p.pos[9]] AS r_start_date,
    d.fields[p.pos[10]] AS r_end_date
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of calendar.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_calendar() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_calendar
  WHERE (r_service_id IS NULL)
    OR (NOT plain AND contains(r_service_id, chr(65533)))
    OR (NOT plain AND (contains(r_service_id, chr(10)) OR contains(r_service_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_service_id) <> r_service_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END, '[^\x20-\x7E]'))
    OR (r_monday IS NULL)
    OR (NOT plain AND contains(r_monday, chr(65533)))
    OR (NOT plain AND (contains(r_monday, chr(10)) OR contains(r_monday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_monday) <> r_monday)
    OR (r_monday IS NOT NULL AND p_monday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_monday) = 'UNRECOGNIZED')
    OR (r_tuesday IS NULL)
    OR (NOT plain AND contains(r_tuesday, chr(65533)))
    OR (NOT plain AND (contains(r_tuesday, chr(10)) OR contains(r_tuesday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_tuesday) <> r_tuesday)
    OR (r_tuesday IS NOT NULL AND p_tuesday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_tuesday) = 'UNRECOGNIZED')
    OR (r_wednesday IS NULL)
    OR (NOT plain AND contains(r_wednesday, chr(65533)))
    OR (NOT plain AND (contains(r_wednesday, chr(10)) OR contains(r_wednesday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_wednesday) <> r_wednesday)
    OR (r_wednesday IS NOT NULL AND p_wednesday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_wednesday) = 'UNRECOGNIZED')
    OR (r_thursday IS NULL)
    OR (NOT plain AND contains(r_thursday, chr(65533)))
    OR (NOT plain AND (contains(r_thursday, chr(10)) OR contains(r_thursday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_thursday) <> r_thursday)
    OR (r_thursday IS NOT NULL AND p_thursday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_thursday) = 'UNRECOGNIZED')
    OR (r_friday IS NULL)
    OR (NOT plain AND contains(r_friday, chr(65533)))
    OR (NOT plain AND (contains(r_friday, chr(10)) OR contains(r_friday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_friday) <> r_friday)
    OR (r_friday IS NOT NULL AND p_friday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_friday) = 'UNRECOGNIZED')
    OR (r_saturday IS NULL)
    OR (NOT plain AND contains(r_saturday, chr(65533)))
    OR (NOT plain AND (contains(r_saturday, chr(10)) OR contains(r_saturday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_saturday) <> r_saturday)
    OR (r_saturday IS NOT NULL AND p_saturday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_saturday) = 'UNRECOGNIZED')
    OR (r_sunday IS NULL)
    OR (NOT plain AND contains(r_sunday, chr(65533)))
    OR (NOT plain AND (contains(r_sunday, chr(10)) OR contains(r_sunday, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_sunday) <> r_sunday)
    OR (r_sunday IS NOT NULL AND p_sunday IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarService', p_sunday) = 'UNRECOGNIZED')
    OR (r_start_date IS NULL)
    OR (NOT plain AND contains(r_start_date, chr(65533)))
    OR (NOT plain AND (contains(r_start_date, chr(10)) OR contains(r_start_date, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_start_date) <> r_start_date)
    OR (r_start_date IS NOT NULL AND p_start_date IS NULL)
    OR (r_end_date IS NULL)
    OR (NOT plain AND contains(r_end_date, chr(65533)))
    OR (NOT plain AND (contains(r_end_date, chr(10)) OR contains(r_end_date, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_end_date) <> r_end_date)
    OR (r_end_date IS NOT NULL AND p_end_date IS NULL)
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id') AS notice
  FROM w WHERE r_service_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND contains(r_service_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_service_id, chr(10)) OR contains(r_service_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_service_id) <> r_service_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'monday') AS notice
  FROM w WHERE r_monday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'monday', 'fieldValue', r_monday) AS notice
  FROM w WHERE NOT plain AND contains(r_monday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'monday', 'fieldValue', r_monday) AS notice
  FROM w WHERE NOT plain AND (contains(r_monday, chr(10)) OR contains(r_monday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'monday', 'fieldValue', r_monday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_monday) <> r_monday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'monday', 'fieldValue', CASE WHEN plain THEN r_monday ELSE gtfs_vc_trim(r_monday) END) AS notice
  FROM w WHERE r_monday IS NOT NULL AND p_monday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'monday', 'fieldValue', p_monday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_monday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tuesday') AS notice
  FROM w WHERE r_tuesday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tuesday', 'fieldValue', r_tuesday) AS notice
  FROM w WHERE NOT plain AND contains(r_tuesday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tuesday', 'fieldValue', r_tuesday) AS notice
  FROM w WHERE NOT plain AND (contains(r_tuesday, chr(10)) OR contains(r_tuesday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tuesday', 'fieldValue', r_tuesday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_tuesday) <> r_tuesday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tuesday', 'fieldValue', CASE WHEN plain THEN r_tuesday ELSE gtfs_vc_trim(r_tuesday) END) AS notice
  FROM w WHERE r_tuesday IS NOT NULL AND p_tuesday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'tuesday', 'fieldValue', p_tuesday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_tuesday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wednesday') AS notice
  FROM w WHERE r_wednesday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wednesday', 'fieldValue', r_wednesday) AS notice
  FROM w WHERE NOT plain AND contains(r_wednesday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wednesday', 'fieldValue', r_wednesday) AS notice
  FROM w WHERE NOT plain AND (contains(r_wednesday, chr(10)) OR contains(r_wednesday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wednesday', 'fieldValue', r_wednesday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_wednesday) <> r_wednesday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wednesday', 'fieldValue', CASE WHEN plain THEN r_wednesday ELSE gtfs_vc_trim(r_wednesday) END) AS notice
  FROM w WHERE r_wednesday IS NOT NULL AND p_wednesday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'wednesday', 'fieldValue', p_wednesday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_wednesday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'thursday') AS notice
  FROM w WHERE r_thursday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'thursday', 'fieldValue', r_thursday) AS notice
  FROM w WHERE NOT plain AND contains(r_thursday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'thursday', 'fieldValue', r_thursday) AS notice
  FROM w WHERE NOT plain AND (contains(r_thursday, chr(10)) OR contains(r_thursday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'thursday', 'fieldValue', r_thursday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_thursday) <> r_thursday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'thursday', 'fieldValue', CASE WHEN plain THEN r_thursday ELSE gtfs_vc_trim(r_thursday) END) AS notice
  FROM w WHERE r_thursday IS NOT NULL AND p_thursday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'thursday', 'fieldValue', p_thursday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_thursday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'friday') AS notice
  FROM w WHERE r_friday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'friday', 'fieldValue', r_friday) AS notice
  FROM w WHERE NOT plain AND contains(r_friday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'friday', 'fieldValue', r_friday) AS notice
  FROM w WHERE NOT plain AND (contains(r_friday, chr(10)) OR contains(r_friday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'friday', 'fieldValue', r_friday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_friday) <> r_friday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'friday', 'fieldValue', CASE WHEN plain THEN r_friday ELSE gtfs_vc_trim(r_friday) END) AS notice
  FROM w WHERE r_friday IS NOT NULL AND p_friday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'friday', 'fieldValue', p_friday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_friday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'saturday') AS notice
  FROM w WHERE r_saturday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'saturday', 'fieldValue', r_saturday) AS notice
  FROM w WHERE NOT plain AND contains(r_saturday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'saturday', 'fieldValue', r_saturday) AS notice
  FROM w WHERE NOT plain AND (contains(r_saturday, chr(10)) OR contains(r_saturday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'saturday', 'fieldValue', r_saturday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_saturday) <> r_saturday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'saturday', 'fieldValue', CASE WHEN plain THEN r_saturday ELSE gtfs_vc_trim(r_saturday) END) AS notice
  FROM w WHERE r_saturday IS NOT NULL AND p_saturday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'saturday', 'fieldValue', p_saturday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_saturday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'sunday') AS notice
  FROM w WHERE r_sunday IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'sunday', 'fieldValue', r_sunday) AS notice
  FROM w WHERE NOT plain AND contains(r_sunday, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'sunday', 'fieldValue', r_sunday) AS notice
  FROM w WHERE NOT plain AND (contains(r_sunday, chr(10)) OR contains(r_sunday, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'sunday', 'fieldValue', r_sunday) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_sunday) <> r_sunday
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'sunday', 'fieldValue', CASE WHEN plain THEN r_sunday ELSE gtfs_vc_trim(r_sunday) END) AS notice
  FROM w WHERE r_sunday IS NOT NULL AND p_sunday IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'sunday', 'fieldValue', p_sunday::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarService', p_sunday) = 'UNRECOGNIZED'
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_date') AS notice
  FROM w WHERE r_start_date IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_date', 'fieldValue', r_start_date) AS notice
  FROM w WHERE NOT plain AND contains(r_start_date, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_date', 'fieldValue', r_start_date) AS notice
  FROM w WHERE NOT plain AND (contains(r_start_date, chr(10)) OR contains(r_start_date, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_date', 'fieldValue', r_start_date) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_start_date) <> r_start_date
  UNION ALL
  SELECT csv_row_number, 'invalid_date' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'start_date', 'fieldValue', CASE WHEN plain THEN r_start_date ELSE gtfs_vc_trim(r_start_date) END) AS notice
  FROM w WHERE r_start_date IS NOT NULL AND p_start_date IS NULL
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_date') AS notice
  FROM w WHERE r_end_date IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_date', 'fieldValue', r_end_date) AS notice
  FROM w WHERE NOT plain AND contains(r_end_date, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_date', 'fieldValue', r_end_date) AS notice
  FROM w WHERE NOT plain AND (contains(r_end_date, chr(10)) OR contains(r_end_date, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_date', 'fieldValue', r_end_date) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_end_date) <> r_end_date
  UNION ALL
  SELECT csv_row_number, 'invalid_date' AS code,
    json_object('filename', 'calendar.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'end_date', 'fieldValue', CASE WHEN plain THEN r_end_date ELSE gtfs_vc_trim(r_end_date) END) AS notice
  FROM w WHERE r_end_date IS NOT NULL AND p_end_date IS NULL
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of calendar.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_calendar() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END)::VARCHAR AS service_id,
  p_monday AS monday,
  p_tuesday AS tuesday,
  p_wednesday AS wednesday,
  p_thursday AS thursday,
  p_friday AS friday,
  p_saturday AS saturday,
  p_sunday AS sunday,
  p_start_date AS start_date,
  p_end_date AS end_date
FROM gtfs_vc_wide_calendar w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- Data rows of calendar_dates.txt with the header's length: the raw value of each schema column (the header's column
-- of that name, NULL without one) and the value Java parses from the trimmed one.
CREATE OR REPLACE MACRO gtfs_vc_wide_build_calendar_dates() AS TABLE
SELECT csv_row_number,
  plain,
  r_service_id,
  r_date,
  gtfs_vc_date(CASE WHEN plain THEN r_date ELSE gtfs_vc_trim(r_date) END) AS p_date,
  r_exception_type,
  gtfs_vc_int(CASE WHEN plain THEN r_exception_type ELSE gtfs_vc_trim(r_exception_type) END) AS p_exception_type
FROM (
  SELECT d.csv_row_number,
    d.plain,
    d.fields[p.pos[1]] AS r_service_id,
    d.fields[p.pos[2]] AS r_date,
    d.fields[p.pos[3]] AS r_exception_type
  FROM gtfs_vc_data_rows() d, gtfs_vc_pos p
  WHERE d.length_ok);
-- RowParser / DefaultFieldValidator notices of the values of calendar_dates.txt (fieldValue: raw for the character
-- checks, trimmed after). One scan keeps the rows with any notice; each check then reads only those.
CREATE OR REPLACE MACRO gtfs_vc_cell_notices_calendar_dates() AS TABLE
WITH w AS MATERIALIZED (
  SELECT * FROM gtfs_vc_wide_calendar_dates
  WHERE (r_service_id IS NULL)
    OR (NOT plain AND contains(r_service_id, chr(65533)))
    OR (NOT plain AND (contains(r_service_id, chr(10)) OR contains(r_service_id, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_service_id) <> r_service_id)
    OR (NOT plain AND regexp_matches(CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END, '[^\x20-\x7E]'))
    OR (r_date IS NULL)
    OR (NOT plain AND contains(r_date, chr(65533)))
    OR (NOT plain AND (contains(r_date, chr(10)) OR contains(r_date, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_date) <> r_date)
    OR (r_date IS NOT NULL AND p_date IS NULL)
    OR (r_exception_type IS NULL)
    OR (NOT plain AND contains(r_exception_type, chr(65533)))
    OR (NOT plain AND (contains(r_exception_type, chr(10)) OR contains(r_exception_type, chr(13))))
    OR (NOT plain AND gtfs_vc_trim(r_exception_type) <> r_exception_type)
    OR (r_exception_type IS NOT NULL AND p_exception_type IS NULL)
    OR (gtfs_validation_enum_name('GtfsCalendarDateExceptionType', p_exception_type) = 'UNRECOGNIZED')
),
n AS (
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id') AS notice
  FROM w WHERE r_service_id IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND contains(r_service_id, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND (contains(r_service_id, chr(10)) OR contains(r_service_id, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', r_service_id) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_service_id) <> r_service_id
  UNION ALL
  SELECT csv_row_number, 'non_ascii_or_non_printable_char' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'service_id', 'fieldValue', CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END) AS notice
  FROM w WHERE NOT plain AND regexp_matches(CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END, '[^\x20-\x7E]')
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'date') AS notice
  FROM w WHERE r_date IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'date', 'fieldValue', r_date) AS notice
  FROM w WHERE NOT plain AND contains(r_date, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'date', 'fieldValue', r_date) AS notice
  FROM w WHERE NOT plain AND (contains(r_date, chr(10)) OR contains(r_date, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'date', 'fieldValue', r_date) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_date) <> r_date
  UNION ALL
  SELECT csv_row_number, 'invalid_date' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'date', 'fieldValue', CASE WHEN plain THEN r_date ELSE gtfs_vc_trim(r_date) END) AS notice
  FROM w WHERE r_date IS NOT NULL AND p_date IS NULL
  UNION ALL
  SELECT csv_row_number, 'missing_required_field' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'exception_type') AS notice
  FROM w WHERE r_exception_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'invalid_character' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'exception_type', 'fieldValue', r_exception_type) AS notice
  FROM w WHERE NOT plain AND contains(r_exception_type, chr(65533))
  UNION ALL
  SELECT csv_row_number, 'new_line_in_value' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'exception_type', 'fieldValue', r_exception_type) AS notice
  FROM w WHERE NOT plain AND (contains(r_exception_type, chr(10)) OR contains(r_exception_type, chr(13)))
  UNION ALL
  SELECT csv_row_number, 'leading_or_trailing_whitespaces' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'exception_type', 'fieldValue', r_exception_type) AS notice
  FROM w WHERE NOT plain AND gtfs_vc_trim(r_exception_type) <> r_exception_type
  UNION ALL
  SELECT csv_row_number, 'invalid_integer' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'exception_type', 'fieldValue', CASE WHEN plain THEN r_exception_type ELSE gtfs_vc_trim(r_exception_type) END) AS notice
  FROM w WHERE r_exception_type IS NOT NULL AND p_exception_type IS NULL
  UNION ALL
  SELECT csv_row_number, 'unexpected_enum_value' AS code,
    json_object('filename', 'calendar_dates.txt', 'csvRowNumber', csv_row_number, 'fieldName', 'exception_type', 'fieldValue', p_exception_type::INTEGER) AS notice
  FROM w WHERE gtfs_validation_enum_name('GtfsCalendarDateExceptionType', p_exception_type) = 'UNRECOGNIZED'
)
SELECT n.csv_row_number, n.code, gtfs_validation_notice(n.notice) AS notice, r.severity = 'ERROR' AS err
FROM n JOIN gtfs_validation_rules() r USING (code);
-- Entities of calendar_dates.txt: rows of the header's length without an ERROR notice of their own (CsvFileLoader).
CREATE OR REPLACE MACRO gtfs_vc_entities_calendar_dates() AS TABLE
SELECT w.csv_row_number,
  (CASE WHEN plain THEN r_service_id ELSE gtfs_vc_trim(r_service_id) END)::VARCHAR AS service_id,
  p_date AS date,
  p_exception_type AS exception_type
FROM gtfs_vc_wide_calendar_dates w
WHERE NOT EXISTS (SELECT 1 FROM gtfs_vc_notices n WHERE n.err AND n.csv_row_number = w.csv_row_number);
-- LOADER-GENERATED-END
