| Code | Severity | Owner | Summary |
|---|---|---|---|
| `bidirectional_exit_gate` | ERROR | stops | Pathway is bidirectional and has mode 7 (exit gate). |
| `big_gap_in_service` | INFO | routescal | A service has a gap of more than 13 days between active service dates. |
| `block_trips_with_overlapping_stop_times` | ERROR | routescal | Trips with the same block id have overlapping stop times. |
| `child_stop_far_from_parent_station` | INFO | stops | A child stop is more than 1km away from the location of its parent station. |
| `child_stop_too_far_from_parent_station` | WARNING | stops | A child stop is more than 10km away from the location of its parent station. |
| `csv_parsing_failed` | ERROR | core | Parsing of a CSV file failed. |
| `decreasing_or_equal_stop_time_distance` | ERROR | stoptimes | Decreasing or equal `shape_dist_traveled` in `stop_times.txt`. |
| `decreasing_shape_distance` | ERROR | shapes | Decreasing `shape_dist_traveled` in `shapes.txt`. |
| `duplicate_key` | ERROR | generated | Duplicated entity. |
| `duplicate_route_name` | WARNING | routescal | Two distinct routes have either the same `route_short_name`, the same `route_long_name`, or the same combination of `route_short_name` and `route_long_name`. |
| `duplicate_trips` | WARNING | stoptimes | Two trips have the same `service_id`, the same stops in the same order and the same arrival and departure times. |
| `duplicated_column` | ERROR | core | Duplicated column in CSV. |
| `empty_column_name` | ERROR | core | A column name is empty. |
| `empty_file` | ERROR | core | A CSV file is empty. |
| `empty_required_file` | ERROR | core | A required file contains headers but no data rows. |
| `empty_row` | WARNING | core | A row in the input file has only spaces. |
| `equal_shape_distance_diff_coordinates` | ERROR | shapes | Two consecutive points have equal `shape_dist_traveled` and different lat/lon coordinates in `shapes.txt` and the distance between the two points is greater than the 1.11m. |
| `equal_shape_distance_diff_coordinates_distance_below_threshold` | WARNING | shapes | Two consecutive points have equal `shape_dist_traveled` and different lat/lon coordinates in `shapes.txt` and the distance between the two points is greater than 0 but less than 1.11m. |
| `equal_shape_distance_same_coordinates` | WARNING | shapes | Two consecutive points have equal `shape_dist_traveled` and the same lat/lon coordinates in `shapes.txt`. |
| `expired_calendar` | WARNING | routescal | Dataset should not contain date ranges for services that have already expired. |
| `fast_travel_between_consecutive_stops` | WARNING | stoptimes | A transit vehicle moves too fast between two consecutive stops. |
| `fast_travel_between_far_stops` | WARNING | stoptimes | A transit vehicle moves too fast between two far stops. |
| `forbidden_arrival_or_departure_time` | ERROR | stoptimes | The arrival or departure times are provided alongside pickup or drop-off windows in `stop_times.txt`. |
| `forbidden_continuous_pickup_drop_off` | ERROR | stoptimes | Continuous pickup or drop-off are forbidden when routes.continuous_pickup or routes.continuous_drop_off are 0, 2 or 3 and stop_times.start_pickup_drop_off_window or stop_times.end_pickup_drop_off_window are defined for any trip of this route. |
| `forbidden_drop_off_type` | ERROR | stoptimes | pickup_drop_off_window fields are forbidden when the drop_off_type is regularly scheduled (0). |
| `forbidden_geography_id` | ERROR | stoptimes | A stop_time entry has more than one geographical id defined. |
| `forbidden_pickup_type` | ERROR | stoptimes | pickup_drop_off_window fields are forbidden when the pickup_type is regularly scheduled (0) or must be coordinated with the driver (3). |
| `forbidden_shape_dist_traveled` | ERROR | stoptimes | A stop_time entry has a `shape_dist_traveled` without a `stop_id` value. |
| `foreign_key_violation` | ERROR | generated, routescal | Wrong foreign key. |
| `inconsistent_route_type_for_block_id` | WARNING | stoptimes | A block should have the same route mode. |
| `invalid_character` | ERROR | core | This field contains invalid characters, such as the replacement character ("�"). |
| `invalid_color` | ERROR | core | A field contains an invalid color value. |
| `invalid_date` | ERROR | core | A field cannot be parsed as date. |
| `invalid_float` | ERROR | core | A field cannot be parsed as a floating point number. |
| `invalid_integer` | ERROR | core | A field cannot be parsed as an integer. |
| `invalid_line_ending` | ERROR | core | A GTFS text file contains a line ending other than LF or CRLF. |
| `invalid_pickup_drop_off_window` | ERROR | stoptimes | The pickup/drop-off window in `stop_times.txt` is invalid. |
| `invalid_row_length` | ERROR | core | Invalid csv row length. |
| `invalid_time` | ERROR | core | A field cannot be parsed as time. |
| `invalid_timezone` | ERROR | core | A field cannot be parsed as a timezone. |
| `invalid_url` | ERROR | core | A field contains a malformed URL. |
| `irrelevant_max_slope_set_for_pathway_mode` | WARNING | stops | A pathway that is not a walkway or a moving sidewalk defines `max_slope`. |
| `leading_or_trailing_whitespaces` | WARNING | core | The value in CSV file has leading or trailing whitespaces. |
| `location_with_unexpected_stop_time` | ERROR | stops | A location in `stops.txt` that is not a stop is referenced by some `stop_times.stop_id`. |
| `location_without_parent_station` | ERROR | stops | A location that must have `parent_station` field does not have it. |
| `missing_bike_allowance` | WARNING | stoptimes | Ferry trips should include bike allowance information. |
| `missing_calendar_and_calendar_date_files` | ERROR | routescal | Missing GTFS files `calendar.txt` and `calendar_dates.txt`. |
| `missing_pickup_or_drop_off_window` | ERROR | stoptimes | Either the start or end pickup/drop-off window is missing in `stop_times.txt`. |
| `missing_recommended_field` | WARNING | core, stops | A recommended field is missing. |
| `missing_recommended_file` | WARNING | shapes | A recommended file is missing. |
| `missing_required_column` | ERROR | core | A required column is missing in the input file. |
| `missing_required_field` | ERROR | core, stoptimes | A required field is missing. |
| `missing_required_file` | ERROR | core | A required file is missing. |
| `missing_stop_name` | ERROR | stops | `stops.stop_name` is required for `location_type` equal to `0`, `1`, or `2`. |
| `missing_stop_times_record` | ERROR | stoptimes | Only one stop_times record is found where two are required. |
| `missing_timepoint_value` | WARNING | stoptimes | `stop_times.timepoint` value is missing for a record. |
| `missing_trip_edge` | ERROR | stoptimes | Missing trip edge `arrival_time` or `departure_time`. |
| `mixed_case_recommended_field` | WARNING | generated | This field has customer-facing text and should use Mixed Case (should contain upper and lower case letters). |
| `new_line_in_value` | ERROR | core | New line or carriage return in a value in CSV file. |
| `non_ascii_or_non_printable_char` | WARNING | core | Non ascii or non printable char in ID field. |
| `number_out_of_range` | ERROR | core | Out of range value. |
| `parent_station_missing_timezone` | INFO | stops | A location has a timezone but its parent station does not. |
| `pathway_dangling_generic_node` | WARNING | stops | A generic node has only one incident location in a pathway graph. |
| `pathway_loop` | WARNING | stops | A pathway starts and ends at the same location. |
| `pathway_to_platform_with_boarding_areas` | ERROR | stops | A pathway has an endpoint that is a platform which has boarding areas. |
| `pathway_to_stop_with_access_outside_of_station_pathways` | ERROR | stops | A pathway has an endpoint that is a stop with stop_access=1, which should be accessible outside of the station’s pathways. |
| `pathway_to_wrong_location_type` | ERROR | stops | A pathway has an endpoint that is a station. |
| `pathway_unreachable_location` | ERROR | stops | A location is not reachable at least in one direction: from the entrances or to the exits. |
| `platform_without_parent_station` | INFO | stops | A platform has no `parent_station` field set. |
| `point_near_origin` | ERROR | generated | A point is too close to origin `(0, 0)`. |
| `point_near_pole` | ERROR | generated | A point is too close to the North or South Pole. |
| `route_both_short_and_long_name_missing` | ERROR | routescal | Both `route_short_name` and `route_long_name` are missing for a route. |
| `route_color_contrast` | WARNING | routescal | Insufficient route color contrast. |
| `route_long_name_contains_short_name` | WARNING | routescal | Long name should not contain short name for a single route. |
| `route_short_name_too_long` | WARNING | routescal | Short name of a route is too long (more than 12 characters). |
| `same_name_and_description_for_route` | WARNING | routescal | Same name and description for route. |
| `same_name_and_description_for_stop` | WARNING | stops | Same name and description for stop. |
| `same_stop_and_route_url` | WARNING | stops | Same `stops.stop_url` and `routes.route_url`. |
| `service_extends_far_in_the_future` | INFO | routescal | A service end date is more than 2 years in the future. |
| `service_has_no_active_day_of_the_week` | WARNING | routescal | A service is not valid for any day of the week. |
| `single_shape_point` | WARNING | shapes | The shape within `shapes.txt` contains a single shape point. |
| `start_and_end_range_equal` | ERROR | generated | Two date or time fields are equal. (cannot fire for these files) |
| `start_and_end_range_out_of_order` | ERROR | generated | Two date or time fields are out of order. |
| `station_with_parent_station` | ERROR | stops | A station has `parent_station` field set. |
| `stations_too_close` | WARNING | stops | Stations are too close to each other. |
| `stop_access_specified_for_incorrect_location` | ERROR | stops | A location that is not a stop has stop_access specified. |
| `stop_access_specified_for_stop_with_no_parent_station` | ERROR | stops | A stop without a value for parent station has stop_access specified. |
| `stop_has_too_many_matches_for_shape` | WARNING | shapes | Stop entry that has many potential matches to the trip's path of travel, as defined by the shape entry in `shapes.txt`. |
| `stop_time_timepoint_without_times` | ERROR | stoptimes | `arrival_time` or `departure_time` not specified for timepoint. |
| `stop_time_with_arrival_before_previous_departure_time` | ERROR | stoptimes | Backwards time travel between stops in `stop_times.txt` |
| `stop_time_with_only_arrival_or_departure_time` | ERROR | stoptimes | Missing `stop_times.arrival_time` or `stop_times.departure_time`. |
| `stop_too_close_to_non_parent_station` | WARNING | stops | A stop is too close to a station that is not its parent station. |
| `stop_too_far_from_shape` | WARNING | shapes | Stop too far from trip shape. |
| `stop_too_far_from_shape_using_user_distance` | WARNING | shapes | Stop time too far from shape. |
| `stop_without_location` | ERROR | stops | `stop_lat` and/or `stop_lon` is missing for stop with `location_type` equal to`0`, `1`, or `2` |
| `stop_without_stop_time` | WARNING | stops | A stop in `stops.txt` is not referenced by any `stop_times.stop_id`. |
| `stops_match_shape_out_of_order` | WARNING | shapes | Two stop entries are different than their arrival-departure order defined by `shapes.txt`. |
| `stops_too_close` | WARNING | stops | Stops are too close to each other. |
| `too_many_consecutive_stop_times_with_same_time` | INFO | stoptimes | More than five consecutive stop-time records have the same fully specified time. |
| `trip_distance_exceeds_shape_distance` | ERROR | shapes | `stop_times.shape_dist_traveled` for a trip exceeds the maximum `shapes.shape_dist_traveled` for the referenced shape, with 11.1m or more between the last shape point and last stop. |
| `trip_distance_exceeds_shape_distance_below_threshold` | WARNING | shapes | `stop_times.shape_dist_traveled` for a trip exceeds the maximum `shapes.shape_dist_traveled` for the referenced shape, with less than 11.1m between the last shape point and last stop. |
| `trip_headsign_matches_intermediate_stop` | INFO | stoptimes | Trip headsign matches the name of an intermediate stop, not the last stop. |
| `trip_with_shape_dist_traveled_but_no_shape_distances` | INFO | shapes | A trip has shape_dist_traveled values in stop_times.txt but the shape referenced by the trip's shape_id does not have shape_dist_traveled values on all of its points in shapes.txt. |
| `unexpected_enum_value` | WARNING | core | An enum has an unexpected value. |
| `unknown_column` | INFO | core | A column name is unknown. |
| `unsorted_stop_times` | INFO | stoptimes | Stop times are not sorted by trip_id and stop_sequence. |
| `unusable_trip` | WARNING | stoptimes | Trips must have more than one stop to be usable. |
| `unused_shape` | WARNING | shapes | Shape is not used in GTFS file `trips.txt`. |
| `unused_station` | WARNING | stops | Unused station. |
| `unused_trip` | WARNING | stoptimes | Trip is not be used in `stop_times.txt` |
| `wrong_parent_location_type` | ERROR | stops | Incorrect type of the parent location. |
