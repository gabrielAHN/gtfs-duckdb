#define DUCKDB_EXTENSION_MAIN

#include "gtfs_extension.hpp"
#include "gtfs_sql.hpp"
#include "duckdb/function/pragma_function.hpp"
#include "duckdb/parser/parser.hpp"
#include "duckdb/parser/statement/create_statement.hpp"
#include "duckdb/parser/parsed_data/create_macro_info.hpp"
#include "duckdb/common/file_system.hpp"
#include "duckdb/common/string_util.hpp"

namespace duckdb {

static bool IsMacro(SQLStatement &statement) {
	if (statement.type != StatementType::CREATE_STATEMENT) {
		return false;
	}
	auto type = statement.Cast<CreateStatement>().info->type;
	return type == CatalogType::MACRO_ENTRY || type == CatalogType::TABLE_MACRO_ENTRY;
}

// DuckDB 2.0 replaced the default Parser constructor and CreateInfo::schema. The browser build still targets
// DuckDB-WASM 1.4, so each helper picks the API that the DuckDB being compiled against provides.
template <class PARSER>
static auto CreateParser(int) -> decltype(PARSER::GetBuiltinParser()) {
	return PARSER::GetBuiltinParser();
}

template <class PARSER>
static PARSER CreateParser(...) {
	return PARSER();
}

template <class INFO>
static auto UseDefaultSchema(INFO &info, int) -> decltype(info.SetSchema(DEFAULT_SCHEMA)) {
	return info.SetSchema(DEFAULT_SCHEMA);
}

template <class INFO>
static void UseDefaultSchema(INFO &info, ...) {
	info.schema = DEFAULT_SCHEMA;
}

static string QuoteLiteral(const string &text) {
	return "'" + StringUtil::Replace(text, "'", "''") + "'";
}

static string DatasetStatements(const char *sql) {
	auto parser = CreateParser<Parser>(0);
	parser.ParseQuery(sql);
	string result;
	for (auto &statement : parser.statements) {
		if (!IsMacro(*statement)) {
			result += statement->query + ";\n";
		}
	}
	return result;
}

static string PrepareDataset(ClientContext &, const FunctionParameters &) {
	return DatasetStatements(GTFS_LOAD_SQL);
}

static string InitializeDataset(ClientContext &, const FunctionParameters &) {
	return DatasetStatements(GTFS_LOAD_SQL) + DatasetStatements(GTFS_INIT_SQL);
}

static string normalize_stops(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_STOPS_SQL;
}

static string normalize_pathways(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_PATHWAYS_SQL;
}

static string empty_pathways(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_PATHWAYS_SQL;
}

static string normalize_routes(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_ROUTES_SQL;
}

static string empty_routes(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_ROUTES_SQL;
}

static string normalize_trips(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_TRIPS_SQL;
}

static string empty_trips(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_TRIPS_SQL;
}

static string normalize_stop_times(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_STOP_TIMES_SQL;
}

static string empty_stop_times(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_STOP_TIMES_SQL;
}

static string normalize_shapes(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_SHAPES_SQL;
}

static string empty_shapes(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_SHAPES_SQL;
}

static string normalize_calendar(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_CALENDAR_SQL;
}

static string empty_calendar(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_CALENDAR_SQL;
}

static string normalize_calendar_dates(ClientContext &, const FunctionParameters &) {
	return GTFS_NORMALIZE_CALENDAR_DATES_SQL;
}

static string empty_calendar_dates(ClientContext &, const FunctionParameters &) {
	return GTFS_EMPTY_CALENDAR_DATES_SQL;
}

static string drop(ClientContext &, const FunctionParameters &) {
	return GTFS_DROP_SQL;
}

static string add_geometry(ClientContext &, const FunctionParameters &) {
	return GTFS_ADD_GEOMETRY_SQL;
}

static string prepare_route_cache(ClientContext &, const FunctionParameters &) {
	return GTFS_PREPARE_ROUTE_CACHE_SQL;
}

static string reset_route_cache(ClientContext &, const FunctionParameters &) {
	return GTFS_RESET_ROUTE_CACHE_SQL;
}

static string route_cache_version(ClientContext &, const FunctionParameters &) {
	return GTFS_ROUTE_CACHE_VERSION_SQL;
}

struct GtfsSourceFile {
	const char *table;
	const char *normalize;
	const char *empty;
};

static const GtfsSourceFile GTFS_SOURCE_FILES[] = {
    {"stops", GTFS_NORMALIZE_STOPS_SQL, nullptr},
    {"pathways", GTFS_NORMALIZE_PATHWAYS_SQL, GTFS_EMPTY_PATHWAYS_SQL},
    {"routes", GTFS_NORMALIZE_ROUTES_SQL, GTFS_EMPTY_ROUTES_SQL},
    {"trips", GTFS_NORMALIZE_TRIPS_SQL, GTFS_EMPTY_TRIPS_SQL},
    {"stop_times", GTFS_NORMALIZE_STOP_TIMES_SQL, GTFS_EMPTY_STOP_TIMES_SQL},
    {"shapes", GTFS_NORMALIZE_SHAPES_SQL, GTFS_EMPTY_SHAPES_SQL},
    {"calendar", GTFS_NORMALIZE_CALENDAR_SQL, GTFS_EMPTY_CALENDAR_SQL},
    {"calendar_dates", GTFS_NORMALIZE_CALENDAR_DATES_SQL, GTFS_EMPTY_CALENDAR_DATES_SQL},
};

static string ImportDataset(ClientContext &context, const FunctionParameters &parameters) {
	auto directory = parameters.values[0].IsNull() ? string() : StringValue::Get(parameters.values[0]);
	auto &fs = FileSystem::GetFileSystem(context);
	string result = DatasetStatements(GTFS_LOAD_SQL) + GTFS_DROP_SQL + "\n";
	for (auto &file : GTFS_SOURCE_FILES) {
		auto name = string(file.table) + ".txt";
		auto path = directory.empty() ? name : fs.JoinPath(directory, name);
		if (!fs.FileExists(path)) {
			if (!file.empty) {
				throw InvalidInputException("gtfs_import: required file %s was not found", path);
			}
			result += string(file.empty) + "\n";
			continue;
		}
		result += "CREATE OR REPLACE TEMP TABLE " + string(file.table) + "_raw AS SELECT * FROM read_csv_auto(" +
		          QuoteLiteral(path) + ", all_varchar=true, null_padding=true, quote='\"', ignore_errors=true);\n";
		result += string(file.normalize) + "\n";
	}
	return result + InitializeDataset(context, parameters);
}

// PRAGMA gtfs_validate(directory[, date]) runs the validate_* statement sections (docs/validation-internals.md):
// schema, begin, one load or missing section per validated file, then finish, whose last statement is the result.
struct GtfsValidatedFile {
	const char *table;
	bool required;
};

static const GtfsValidatedFile GTFS_VALIDATED_FILES[] = {
    {"stops", false},     {"pathways", false}, {"routes", true},    {"trips", true},
    {"stop_times", true}, {"shapes", false},   {"calendar", false}, {"calendar_dates", false},
};

static bool IsIsoDate(const string &text) {
	if (text.size() != 10 || text[4] != '-' || text[7] != '-') {
		return false;
	}
	for (idx_t i = 0; i < text.size(); i++) {
		if (i != 4 && i != 7 && (text[i] < '0' || text[i] > '9')) {
			return false;
		}
	}
	return true;
}

static string ValidateDataset(ClientContext &context, const FunctionParameters &parameters) {
	auto directory = parameters.values[0].IsNull() ? string() : StringValue::Get(parameters.values[0]);
	if (parameters.values.size() > 2) {
		throw InvalidInputException("gtfs_validate takes a directory and an optional date (YYYY-MM-DD)");
	}
	string date = "current_date";
	if (parameters.values.size() == 2 && !parameters.values[1].IsNull()) {
		auto text = StringValue::Get(parameters.values[1]);
		if (!IsIsoDate(text)) {
			throw InvalidInputException("gtfs_validate: the date must be YYYY-MM-DD, got %s", text);
		}
		date = "DATE " + QuoteLiteral(text);
	}
	auto &fs = FileSystem::GetFileSystem(context);
	// Fixed placeholders first; the user-supplied directory and paths last, so their text is never rescanned.
	auto begin = StringUtil::Replace(GTFS_VALIDATE_BEGIN_SQL, "{{DATE}}", date);
	string result = string(GTFS_VALIDATE_SCHEMA_SQL) + "\n" +
	                StringUtil::Replace(begin, "{{DIRECTORY}}", QuoteLiteral(directory)) + "\n";
	for (auto &file : GTFS_VALIDATED_FILES) {
		auto name = string(file.table) + ".txt";
		auto path = directory.empty() ? name : fs.JoinPath(directory, name);
		string section = fs.FileExists(path) ? GTFS_VALIDATE_LOAD_SQL : GTFS_VALIDATE_MISSING_SQL;
		section = StringUtil::Replace(section, "{{TABLE}}", file.table);
		section = StringUtil::Replace(section, "{{FILE}}", QuoteLiteral(name));
		section = StringUtil::Replace(section, "{{REQUIRED}}", file.required ? "true" : "false");
		section = StringUtil::Replace(section, "{{PATH}}", QuoteLiteral(path));
		result += section + "\n";
	}
	return result + GTFS_VALIDATE_FINISH_SQL;
}

static void LoadInternal(ExtensionLoader &loader) {
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_prepare_route_cache", prepare_route_cache));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_reset_route_cache", reset_route_cache));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_route_cache_version", route_cache_version));

	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_stops", normalize_stops));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_pathways", normalize_pathways));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_pathways", empty_pathways));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_routes", normalize_routes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_routes", empty_routes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_trips", normalize_trips));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_trips", empty_trips));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_stop_times", normalize_stop_times));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_stop_times", empty_stop_times));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_shapes", normalize_shapes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_shapes", empty_shapes));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_calendar", normalize_calendar));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_calendar", empty_calendar));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_normalize_calendar_dates", normalize_calendar_dates));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_empty_calendar_dates", empty_calendar_dates));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_drop", drop));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_add_geometry", add_geometry));

	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_prepare", PrepareDataset));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_init", InitializeDataset));
	loader.RegisterFunction(PragmaFunction::PragmaStatement("gtfs_refresh", InitializeDataset));
	loader.RegisterFunction(PragmaFunction::PragmaCall("gtfs_import", ImportDataset, {LogicalType::VARCHAR}));
	loader.RegisterFunction(
	    PragmaFunction::PragmaCall("gtfs_validate", ValidateDataset, {LogicalType::VARCHAR}, LogicalType::VARCHAR));
	for (auto sql : {GTFS_LOAD_SQL, GTFS_INIT_SQL, GTFS_REROUTE_SQL, GTFS_SONIFY_SQL, GTFS_VALIDATE_COMMON_SQL,
	                 GTFS_VALIDATE_REGISTRY_SQL, GTFS_VALIDATE_CORE_SQL, GTFS_VALIDATE_RULES_STOPS_SQL,
	                 GTFS_VALIDATE_RULES_STOP_TIMES_SQL, GTFS_VALIDATE_RULES_ROUTES_CALENDAR_SQL,
	                 GTFS_VALIDATE_RULES_SHAPES_SQL, GTFS_VALIDATE_RULES_GENERATED_SQL}) {
		auto parser = CreateParser<Parser>(0);
		parser.ParseQuery(sql);
		for (auto &statement : parser.statements) {
			if (!IsMacro(*statement)) {
				continue;
			}
			auto &info = statement->Cast<CreateStatement>().info->Cast<CreateMacroInfo>();
			UseDefaultSchema(info, 0);
			info.internal = true;
			loader.RegisterFunction(info);
		}
	}
}

void GtfsExtension::Load(ExtensionLoader &loader) {
	LoadInternal(loader);
}

std::string GtfsExtension::Name() {
	return "gtfs";
}

std::string GtfsExtension::Version() const {
#ifdef EXT_VERSION_GTFS
	return EXT_VERSION_GTFS;
#else
	return "";
#endif
}

} // namespace duckdb

extern "C" {

DUCKDB_CPP_EXTENSION_ENTRY(gtfs, loader) {
	duckdb::LoadInternal(loader);
}
}
