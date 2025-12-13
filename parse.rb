APP_PATH = File.expand_path(File.dirname(__FILE__))

require "#{APP_PATH}/gtfs.rb"

timetables_start_date = '2024-12-15'
timetables_end_date = '2025-12-13'

GovRoGTFSConverter::parse_and_save_for_dates(timetables_start_date, timetables_end_date)